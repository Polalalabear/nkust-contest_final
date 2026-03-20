import SwiftUI
import Observation

@MainActor
@Observable
final class RecognitionModeViewModel {
    var isSuccess: Bool = false
    var resultDescription: String = ""
    var useDeviceCamera: Bool = true
    var isUsingLiveStream: Bool = false
    var lastFrameReceivedAt: Date?

    private let service: RecognitionModeServicing
    private let streamService: StreamService
    private var isStreaming = false

    init(
        service: RecognitionModeServicing = StubRecognitionModeService(),
        streamService: StreamService = StreamServiceFactory.makeDefault()
    ) {
        self.service = service
        self.streamService = streamService
        self.streamService.onFrame = { [weak self] frame in
            guard let self else { return }
            if frame != nil {
                self.lastFrameReceivedAt = Date()
            }
        }
    }

    func requestRecognition() async {
        let message = await service.recognizeCurrentFrame()
        resultDescription = message
        isSuccess = !message.isEmpty
    }

    func syncStreaming(mode: DataSourceMode) {
        let shouldUseLiveStream = mode == .live && useDeviceCamera
        isUsingLiveStream = shouldUseLiveStream

        if shouldUseLiveStream {
            startStreamingIfNeeded()
        } else {
            stopStreaming()
        }
    }

    func stopStreaming() {
        guard isStreaming else { return }
        streamService.stop()
        isStreaming = false
    }

    private func startStreamingIfNeeded() {
        guard !isStreaming else { return }
        streamService.start()
        isStreaming = true
    }

    deinit {
        streamService.stop()
    }
}
