import SwiftUI
import Observation
import UIKit

@MainActor
@Observable
final class RecognitionModeViewModel {
    var isSuccess: Bool = false
    var resultDescription: String = ""
    var useDeviceCamera: Bool = true
    var isUsingLiveStream: Bool = false
    var lastFrameReceivedAt: Date?
    var latestFrame: UIImage?

    private let service: RecognitionModeServicing
    private let mockAIService: AIService
    private let liveAIService: AIService
    private let streamService: StreamService
    private var isStreaming = false
    private var currentMode: DataSourceMode = .mock
    private var isAnalyzingFrame = false
    private var isVoiceEnabled = true
    private var lastAnnouncedText: String = ""
    private var alertDistanceThresholdMeters: Int = 10

    init(service: RecognitionModeServicing, streamService: StreamService, mockAIService: AIService, liveAIService: AIService) {
        self.service = service
        self.mockAIService = mockAIService
        self.liveAIService = liveAIService
        self.streamService = streamService
        self.streamService.onFrame = { [weak self] frame in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleIncomingFrame(frame)
            }
        }
    }

    convenience init() {
        self.init(
            service: StubRecognitionModeService(),
            streamService: StreamServiceFactory.makeDefault(),
            mockAIService: MockAIService(),
            liveAIService: LiveAIService()
        )
    }

    func requestRecognition() async {
        let message = await service.recognizeCurrentFrame()
        resultDescription = message
        isSuccess = !message.isEmpty
    }

    func syncStreaming(mode: DataSourceMode, isConnected: Bool, alertDistanceThresholdMeters: Int) {
        currentMode = mode
        self.alertDistanceThresholdMeters = max(1, alertDistanceThresholdMeters)
        let shouldUseLiveStream = mode == .live && useDeviceCamera && isConnected
        isUsingLiveStream = shouldUseLiveStream
        debugLog("sync streaming mode=\(mode.rawValue) connected=\(isConnected) useDeviceCamera=\(useDeviceCamera) alertDistance=\(self.alertDistanceThresholdMeters)m")

        if shouldUseLiveStream {
            startStreamingIfNeeded()
        } else {
            stopStreaming()
        }
    }

    func setVoiceEnabled(_ enabled: Bool) {
        isVoiceEnabled = enabled
    }

    func stopStreaming() {
        guard isStreaming else { return }
        debugLog("stop stream")
        streamService.stop()
        isStreaming = false
    }

    private func startStreamingIfNeeded() {
        guard !isStreaming else { return }
        debugLog("start stream")
        streamService.start()
        isStreaming = true
    }

    private func handleIncomingFrame(_ frame: UIImage?) {
        guard isUsingLiveStream else { return }
        guard let frame else {
            debugLog("received nil frame")
            if resultDescription.isEmpty {
                resultDescription = "等待串流畫面中"
            }
            latestFrame = nil
            return
        }

        lastFrameReceivedAt = Date()
        latestFrame = frame

        guard !isAnalyzingFrame else { return }
        isAnalyzingFrame = true

        Task { [weak self] in
            guard let self else { return }
            let ai = self.currentMode == .live ? self.liveAIService : self.mockAIService
            let local = await ai.analyzeLocal(frame: frame)
            await MainActor.run {
                let newDescription: String
                if let distance = local.estimatedObstacleDistanceMeters,
                   local.hasObstacle,
                   distance > self.alertDistanceThresholdMeters {
                    let label = local.fusion.primaryObject?.label ?? "目標"
                    newDescription = "辨識到\(label)約 \(distance) 公尺（超過警示距離 \(self.alertDistanceThresholdMeters) 公尺）"
                } else {
                    newDescription = local.fusion.summary
                }
                self.resultDescription = newDescription
                self.isSuccess = true
                self.announceIfNeeded(text: newDescription)
                self.isAnalyzingFrame = false
            }
        }
    }

    private func announceIfNeeded(text: String) {
        guard isVoiceEnabled else { return }
        guard text != lastAnnouncedText else { return }
        lastAnnouncedText = text
        VoiceAnnouncementCenter.shared.speak(
            text,
            priority: .navigation,
            interruptLowerPriority: false
        )
    }

    deinit {
        let stream = streamService
        Task { @MainActor in
            stream.stop()
        }
    }

    private func debugLog(_ message: String) {
        print("[RecognitionMode] \(message)")
    }
}
