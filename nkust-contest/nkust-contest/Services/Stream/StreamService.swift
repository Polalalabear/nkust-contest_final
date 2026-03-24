import Foundation
import UIKit

enum StreamHealthState: String, Equatable {
    case disconnected
    case connecting
    case connected
    case stale
}

protocol StreamService: AnyObject {
    var onFrame: ((UIImage?) -> Void)? { get set }
    var onHealthChange: ((StreamHealthState) -> Void)? { get set }
    func start()
    func stop()
}

/// 階段規則：仍保留 mock/live gate；live 階段允許真機 MJPEG。
enum StreamDevelopmentPhase {
    case mockOnly
    case realDeviceAllowed

    /// 目前已進入「測試實機串流」階段：mock/live 由上層流程控制啟停。
    static let current: StreamDevelopmentPhase = .realDeviceAllowed
}

enum StreamServiceFactory {
    static func makeDefault() -> StreamService {
        switch StreamDevelopmentPhase.current {
        case .mockOnly:
            return MockStreamService()
        case .realDeviceAllowed:
            return MJPEGStreamService()
        }
    }
}

final class MockStreamService: StreamService {
    var onFrame: ((UIImage?) -> Void)?
    var onHealthChange: ((StreamHealthState) -> Void)?

    func start() {
        // 開發階段仍走 mock，避免誤連真機。
        onHealthChange?(.connected)
        onFrame?(nil)
    }

    func stop() {
        onHealthChange?(.disconnected)
    }
}

/// 真實 MJPEG 串流服務（URLSession + 手動解析 JPEG frame）。
/// 注意：依階段規則，預設不會被 `StreamServiceFactory.makeDefault()` 啟用。
final class MJPEGStreamService: NSObject, StreamService {
    var onFrame: ((UIImage?) -> Void)?
    var onHealthChange: ((StreamHealthState) -> Void)?

    private let streamURL: URL
    private let staleTimeout: TimeInterval
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private let processingQueue = DispatchQueue(label: "mjpeg.stream.processing", qos: .utility)
    private var buffer = Data()
    private var boundaryMarker: Data?
    private let maxBufferBytes = 2_000_000
    private var lastFrameAt: Date?
    private var stateSinceAt: Date = Date()
    private var streamHealthState: StreamHealthState = .disconnected
    private var healthTimer: DispatchSourceTimer?
    private var didReceiveFirstFrame = false

    init(
        url: URL = URL(string: "http://192.168.4.1/stream")!,
        staleTimeout: TimeInterval = 2.5
    ) {
        self.streamURL = url
        self.staleTimeout = staleTimeout
    }

    func start() {
        guard task == nil else { return }
        debugLog("start stream request \(streamURL.absoluteString)")
        transition(to: .connecting, reason: "start() invoked")
        startHealthMonitorIfNeeded()

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 60 * 5

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session
        let task = session.dataTask(with: streamURL)
        self.task = task
        task.resume()
    }

    func stop() {
        debugLog("stop stream request")
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        stopHealthMonitor()
        transition(to: .disconnected, reason: "stop() invoked")
        processingQueue.async { [weak self] in
            self?.buffer.removeAll(keepingCapacity: false)
            self?.boundaryMarker = nil
            self?.lastFrameAt = nil
            self?.didReceiveFirstFrame = false
        }
    }

    private func emit(frame: UIImage?) {
        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(frame)
        }
    }

    private func debugLog(_ message: String) {
        print("[MJPEGStream] \(message)")
    }

    private func connectionLog(_ message: String) {
        print("[ConnectionState] \(message)")
    }

    private func transition(to newState: StreamHealthState, reason: String) {
        guard newState != streamHealthState else { return }
        let previous = streamHealthState
        streamHealthState = newState
        stateSinceAt = Date()
        connectionLog("stream health transition \(previous.rawValue) -> \(newState.rawValue) (\(reason))")
        DispatchQueue.main.async { [weak self] in
            self?.onHealthChange?(newState)
        }
    }

    private func startHealthMonitorIfNeeded() {
        guard healthTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: processingQueue)
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
        timer.setEventHandler { [weak self] in
            self?.checkStreamStaleness()
        }
        healthTimer = timer
        timer.resume()
    }

    private func stopHealthMonitor() {
        healthTimer?.cancel()
        healthTimer = nil
    }

    private func checkStreamStaleness() {
        guard task != nil else { return }
        let now = Date()
        if let lastFrameAt {
            let elapsed = now.timeIntervalSince(lastFrameAt)
            if elapsed > staleTimeout {
                debugLog("timeout stale elapsed=\(String(format: "%.2f", elapsed))s")
                transition(to: .stale, reason: "frame timeout > \(String(format: "%.1f", staleTimeout))s")
            }
            return
        }

        if now.timeIntervalSince(stateSinceAt) > staleTimeout {
            debugLog("timeout stale while connecting")
            transition(to: .stale, reason: "connecting timeout > \(String(format: "%.1f", staleTimeout))s")
        }
    }

    private func parseBufferIntoJPEGFrames() {
        if let boundaryMarker {
            parseMultipartFrames(with: boundaryMarker)
            return
        }

        // Fallback：若 response header 沒帶 boundary，改用 JPEG magic number 解析。
        let jpegStart = Data([0xFF, 0xD8])
        let jpegEnd = Data([0xFF, 0xD9])

        while true {
            guard let startRange = buffer.range(of: jpegStart) else {
                // 避免 buffer 無限增長
                if buffer.count > maxBufferBytes {
                    buffer.removeAll(keepingCapacity: true)
                }
                return
            }

            guard let endRange = buffer.range(of: jpegEnd, options: [], in: startRange.lowerBound..<buffer.endIndex) else {
                if startRange.lowerBound > 0 {
                    buffer.removeSubrange(0..<startRange.lowerBound)
                }
                return
            }

            let frameEnd = buffer.index(endRange.lowerBound, offsetBy: jpegEnd.count)
            let frameData = buffer[startRange.lowerBound..<frameEnd]
            let image = UIImage(data: frameData)
            if image != nil {
                didReceiveValidFrame()
            }
            emit(frame: image)

            buffer.removeSubrange(0..<frameEnd)
        }
    }

    private func parseMultipartFrames(with boundary: Data) {
        while true {
            guard let currentBoundary = buffer.range(of: boundary) else {
                trimBufferIfNeeded()
                return
            }

            let partStart = currentBoundary.upperBound
            guard let nextBoundary = buffer.range(of: boundary, options: [], in: partStart..<buffer.endIndex) else {
                if currentBoundary.lowerBound > 0 {
                    buffer.removeSubrange(0..<currentBoundary.lowerBound)
                }
                trimBufferIfNeeded()
                return
            }

            let partData = Data(buffer[partStart..<nextBoundary.lowerBound])
            if let jpeg = extractJPEG(fromMultipartPart: partData),
               let image = UIImage(data: jpeg) {
                didReceiveValidFrame()
                emit(frame: image)
            }

            buffer.removeSubrange(0..<nextBoundary.lowerBound)
        }
    }

    private func extractJPEG(fromMultipartPart part: Data) -> Data? {
        // multipart 每段通常是 headers + CRLFCRLF + JPEG bytes
        let separator = Data([0x0D, 0x0A, 0x0D, 0x0A]) // \r\n\r\n
        if let headerEnd = part.range(of: separator)?.upperBound {
            let body = Data(part[headerEnd..<part.endIndex])
            if let jpeg = extractJPEGByMarker(from: body) {
                return jpeg
            }
        }
        return extractJPEGByMarker(from: part)
    }

    private func extractJPEGByMarker(from data: Data) -> Data? {
        let jpegStart = Data([0xFF, 0xD8])
        let jpegEnd = Data([0xFF, 0xD9])
        guard let start = data.range(of: jpegStart),
              let end = data.range(of: jpegEnd, options: [], in: start.lowerBound..<data.endIndex) else {
            return nil
        }
        let frameEnd = data.index(end.lowerBound, offsetBy: jpegEnd.count)
        return Data(data[start.lowerBound..<frameEnd])
    }

    private func trimBufferIfNeeded() {
        if buffer.count > maxBufferBytes {
            buffer.removeAll(keepingCapacity: true)
        }
    }

    private func didReceiveValidFrame() {
        let now = Date()
        lastFrameAt = now
        if !didReceiveFirstFrame {
            didReceiveFirstFrame = true
            debugLog("first frame received")
        }
        transition(to: .connected, reason: "valid frame received")
    }
}

extension MJPEGStreamService: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
        _ = session
        _ = dataTask
        if let http = response as? HTTPURLResponse {
            debugLog("connected status=\(http.statusCode)")
        } else {
            debugLog("connected with non-http response")
        }
        processingQueue.async { [weak self] in
            guard let self else { return }
            self.buffer.removeAll(keepingCapacity: true)
            self.boundaryMarker = self.extractBoundaryMarker(from: response)
            self.debugLog("boundary parser enabled=\(self.boundaryMarker != nil)")
        }
        return .allow
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        _ = session
        _ = dataTask
        processingQueue.async { [weak self] in
            guard let self else { return }
            self.buffer.append(data)
            self.parseBufferIntoJPEGFrames()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        _ = session
        _ = task
        self.task = nil

        // 失敗時僅回傳 nil frame，不 crash、不做激進重試。
        if let error {
            debugLog("stream finished with error: \(error.localizedDescription)")
            transition(to: .disconnected, reason: "didCompleteWithError")
            emit(frame: nil)
        } else {
            debugLog("stream finished normally")
            transition(to: .disconnected, reason: "stream ended")
        }
    }
}

@MainActor
final class StreamHealthCoordinator {
    var onStateChange: ((StreamHealthState) -> Void)?

    private let monitorService: StreamService
    private var isMonitoring = false
    private var currentState: StreamHealthState = .disconnected

    init(monitorService: StreamService = MJPEGStreamService()) {
        self.monitorService = monitorService
        self.monitorService.onHealthChange = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.apply(state: state)
            }
        }
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        print("[ConnectionState] coordinator start monitoring")
        monitorService.start()
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        print("[ConnectionState] coordinator stop monitoring")
        monitorService.stop()
        apply(state: .disconnected)
    }

    private func apply(state: StreamHealthState) {
        guard state != currentState else { return }
        let old = currentState
        currentState = state
        print("[ConnectionState] coordinator transition \(old.rawValue) -> \(state.rawValue)")
        onStateChange?(state)
    }
}

private extension MJPEGStreamService {
    func extractBoundaryMarker(from response: URLResponse) -> Data? {
        guard let http = response as? HTTPURLResponse else { return nil }
        guard let contentType = http.value(forHTTPHeaderField: "Content-Type")?
            .lowercased(),
            contentType.contains("multipart/x-mixed-replace") else {
            return nil
        }

        guard let boundaryRange = contentType.range(of: "boundary=") else {
            return nil
        }
        var rawBoundary = String(contentType[boundaryRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if rawBoundary.hasPrefix("\""), rawBoundary.hasSuffix("\""), rawBoundary.count >= 2 {
            rawBoundary.removeFirst()
            rawBoundary.removeLast()
        }
        guard !rawBoundary.isEmpty else { return nil }

        let marker = rawBoundary.hasPrefix("--") ? rawBoundary : "--\(rawBoundary)"
        return marker.data(using: .utf8)
    }
}
