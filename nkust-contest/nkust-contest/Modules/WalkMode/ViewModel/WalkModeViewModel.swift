import SwiftUI
import Observation
import UIKit

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
    var latestFrame: UIImage?

    private let service: WalkModeServicing
    private let mockAIService: AIService
    private let liveAIService: AIService
    private let streamService: StreamService
    private var isStreaming = false
    private var currentMode: DataSourceMode = .mock
    private var isAnalyzingFrame = false
    private var isVoiceFeedbackEnabled = true

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
        isVoiceFeedbackEnabled = voiceEnabled
        lastDecision = service.evaluateNavigation(context: buildContext(), voiceEnabled: voiceEnabled)
        updateDirectionByDecision(lastDecision)
    }

    func syncStreaming(mode: DataSourceMode, isConnected: Bool) {
        currentMode = mode
        let shouldUseLiveStream = mode == .live && isConnected
        isUsingLiveStream = shouldUseLiveStream
        debugLog("sync streaming mode=\(mode.rawValue) connected=\(isConnected)")

        if shouldUseLiveStream {
            startStreamingIfNeeded()
        } else {
            stopStreaming()
            connectionStatus = isConnected ? "測試模式（Mock）" : "裝置未連線（可繼續切換模式）"
        }
    }

    func stopStreaming() {
        guard isStreaming else { return }
        debugLog("stop stream")
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
        debugLog("start stream")
        streamService.start()
        isStreaming = true
        connectionStatus = "連線中"
    }

    private func handleIncomingFrame(_ frame: UIImage?) {
        guard isUsingLiveStream else { return }
        guard let frame else {
            debugLog("received nil frame")
            connectionStatus = "等待影像中"
            latestFrame = nil
            return
        }

        lastFrameReceivedAt = Date()
        latestFrame = frame
        connectionStatus = "串流已連線"

        guard !isAnalyzingFrame else { return }
        isAnalyzingFrame = true

        Task { [weak self] in
            guard let self else { return }
            let ai = self.currentMode == .live ? self.liveAIService : self.mockAIService
            let result = await ai.analyzeLocal(frame: frame)
            await MainActor.run {
                let distance = result.estimatedObstacleDistanceMeters ?? 8
                self.obstacle = result.hasObstacle
                    ? ObstacleInfo(description: "前方偵測到障礙物", distance: distance)
                    : .empty
                if result.trafficLightRed == true {
                    self.trafficLight = .redLight
                } else {
                    self.trafficLight = .none
                }
                self.lastDecision = self.service.evaluateNavigation(
                    context: self.buildContext(),
                    voiceEnabled: self.isVoiceFeedbackEnabled
                )
                self.updateDirectionByDecision(self.lastDecision)
                self.isAnalyzingFrame = false
            }
        }
    }

    private func updateDirectionByDecision(_ result: DecisionResult?) {
        guard let result else { return }
        switch result.action {
        case .stop:
            direction = DirectionInfo(instruction: "請停止", detail: "前方風險較高")
        case .moveLeft:
            direction = DirectionInfo(instruction: "請向左修正", detail: "避開前方障礙")
        case .moveRight:
            direction = DirectionInfo(instruction: "請向右修正", detail: "避開前方障礙")
        case .safe:
            direction = DirectionInfo(instruction: "保持直行", detail: "路徑暫時安全")
        }
    }

    private func debugLog(_ message: String) {
        print("[WalkMode] \(message)")
    }

    deinit {
        let stream = streamService
        Task { @MainActor in
            stream.stop()
        }
    }
}
