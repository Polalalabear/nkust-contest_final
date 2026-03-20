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

    private let service: WalkModeServicing

    init(service: WalkModeServicing) {
        self.service = service
    }

    convenience init() {
        self.init(service: DefaultWalkModeService())
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
}
