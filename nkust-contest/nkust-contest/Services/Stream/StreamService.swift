import Foundation
import UIKit

protocol StreamService: AnyObject {
    var onFrame: ((UIImage?) -> Void)? { get set }
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

    func start() {
        // 開發階段仍走 mock，避免誤連真機。
        onFrame?(nil)
    }

    func stop() {
        // no-op
    }
}

/// 真實 MJPEG 串流服務（URLSession + 手動解析 JPEG frame）。
/// 注意：依階段規則，預設不會被 `StreamServiceFactory.makeDefault()` 啟用。
final class MJPEGStreamService: NSObject, StreamService {
    var onFrame: ((UIImage?) -> Void)?

    private let streamURL: URL
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private let processingQueue = DispatchQueue(label: "mjpeg.stream.processing", qos: .utility)
    private var buffer = Data()
    private var boundaryMarker: Data?
    private let maxBufferBytes = 2_000_000

    init(url: URL = URL(string: "http://192.168.4.1/stream")!) {
        self.streamURL = url
    }

    func start() {
        guard task == nil else { return }

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
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        processingQueue.async { [weak self] in
            self?.buffer.removeAll(keepingCapacity: false)
            self?.boundaryMarker = nil
        }
    }

    private func emit(frame: UIImage?) {
        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(frame)
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
}

extension MJPEGStreamService: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
        _ = session
        _ = dataTask
        processingQueue.async { [weak self] in
            guard let self else { return }
            self.buffer.removeAll(keepingCapacity: true)
            self.boundaryMarker = self.extractBoundaryMarker(from: response)
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
        if error != nil {
            emit(frame: nil)
        }
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
