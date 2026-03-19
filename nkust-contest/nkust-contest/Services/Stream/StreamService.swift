import Foundation

protocol StreamService {
    func start()
    func stop()
}

final class MockStreamService: StreamService {
    func start() {
        // TODO: integrate MJPEG stream via URLSession
    }

    func stop() {
        // TODO: stop MJPEG stream
    }
}
