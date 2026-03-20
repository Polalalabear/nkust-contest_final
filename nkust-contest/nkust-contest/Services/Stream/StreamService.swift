import Foundation
import UIKit

protocol StreamService: AnyObject {
    var onFrame: ((UIImage?) -> Void)? { get set }
    func start()
    func stop()
}

/// 階段規則：目前預設只能使用 Mock；下一階段才允許真機 MJPEG。
enum StreamDevelopmentPhase {
    case mockOnly
    case realDeviceAllowed

    static let current: StreamDevelopmentPhase = .mockOnly
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
    private var buffer = Data()

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
        buffer.removeAll(keepingCapacity: false)
    }

    private func emit(frame: UIImage?) {
        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(frame)
        }
    }

    private func parseBufferIntoJPEGFrames() {
        // MJPEG 實務上可透過 boundary 或 JPEG magic number；此處使用 SOI/EOI 解析。
        let jpegStart = Data([0xFF, 0xD8])
        let jpegEnd = Data([0xFF, 0xD9])

        while true {
            guard let startRange = buffer.range(of: jpegStart) else {
                // 避免 buffer 無限增長
                if buffer.count > 1_500_000 {
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
}

extension MJPEGStreamService: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
        _ = session
        _ = dataTask
        _ = response
        buffer.removeAll(keepingCapacity: true)
        return .allow
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        _ = session
        _ = dataTask
        buffer.append(data)
        parseBufferIntoJPEGFrames()
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
