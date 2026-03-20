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
    private let streamService: StreamService
    private var isStreaming = false

    init(service: WalkModeServicing, streamService: StreamService) {
        self.service = service
        self.streamService = streamService
        self.streamService.onFrame = { [weak self] frame in
            guard let self else { return }
            if frame != nil {
                self.lastFrameReceivedAt = Date()
                self.connectionStatus = "串流已連線"
            } else if self.isUsingLiveStream {
                self.connectionStatus = "等待影像中"
            }
        }
    }

    convenience init() {
        self.init(
            service: DefaultWalkModeService(),
            streamService: StreamServiceFactory.makeDefault()
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

    deinit {
        streamService.stop()
    }
}
