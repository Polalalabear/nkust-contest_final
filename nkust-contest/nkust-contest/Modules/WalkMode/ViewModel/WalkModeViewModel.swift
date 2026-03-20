import SwiftUI
import Observation

@MainActor
@Observable
final class WalkModeViewModel {
    var obstacle: ObstacleInfo = .mock
    var direction: DirectionInfo = .turnRight
    var trafficLight: TrafficLightInfo = .none
    var connectionStatus: String = "已連接"
    var batteryLevel: String = "72%"
    var lastDecision: DecisionResult?
    var isUsingLiveStream: Bool = false
    var lastFrameReceivedAt: Date?

    private let service: WalkModeServicing
    private let mockAIService: AIService
    private let liveAIService: AIService
    private let streamService: StreamService
    private var isStreaming = false
    private var currentMode: DataSourceMode = .mock
    private var isAnalyzingFrame = false

    init(
        service: WalkModeServicing,
        streamService: StreamService,
        mockAIService: AIService,
        liveAIService: AIService
    ) {
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
            service: DefaultWalkModeService(),
            streamService: StreamServiceFactory.makeDefault(),
            mockAIService: MockAIService(),
            liveAIService: LiveAIService()
        )
    }

    func buildContext() -> DecisionContext {
        DecisionContext(
            obstacleDetected: !obstacle.description.isEmpty,
            obstacleDistanceMeters: obstacle.distance,
            trafficLightRed: trafficLight.isRed
        )
    }

    /// 依目前 UI 狀態重新決策並觸發語音／觸覺（進入畫面或語音開關變更時呼叫）
    func refreshNavigation(voiceEnabled: Bool) {
        lastDecision = service.evaluateNavigation(context: buildContext(), voiceEnabled: voiceEnabled)
    }

    func syncStreaming(mode: DataSourceMode) {
        currentMode = mode
        let shouldUseLiveStream = mode == .live
        isUsingLiveStream = shouldUseLiveStream

        if shouldUseLiveStream {
            startStreamingIfNeeded()
        } else {
            stopStreaming()
            connectionStatus = "測試模式（Mock）"
        }
    }

    func stopStreaming() {
        guard isStreaming else { return }
        streamService.stop()
        isStreaming = false
    }

    func handleSingleTap() {
        service.replayLastInstruction()
    }

    func handleDoubleTap() {
        service.toggleMute()
    }

    func handleLongPress() {
        service.startVoiceCommand()
    }

    func handleVeryLongPress() {
        service.triggerSOS()
    }

    private func startStreamingIfNeeded() {
        guard !isStreaming else { return }
        streamService.start()
        isStreaming = true
        connectionStatus = "連線中"
    }

    private func handleIncomingFrame(_ frame: UIImage?) {
        guard isUsingLiveStream else { return }
        guard let frame else {
            connectionStatus = "等待影像中"
            return
        }

        lastFrameReceivedAt = Date()
        connectionStatus = "串流已連線"

        guard !isAnalyzingFrame else { return }
        isAnalyzingFrame = true

        Task { [weak self] in
            guard let self else { return }
            let ai = self.currentMode == .live ? self.liveAIService : self.mockAIService
            let result = await ai.analyzeLocal(frame: frame)
            await MainActor.run {
                self.obstacle = result.hasObstacle ? .mock : .empty
                self.isAnalyzingFrame = false
            }
        }
    }

    deinit {
        let stream = streamService
        Task { @MainActor in
            stream.stop()
        }
    }
}
