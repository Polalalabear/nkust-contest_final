import SwiftUI
import Observation

@Observable
final class WalkModeViewModel {
    var obstacle: ObstacleInfo = .mock
    var direction: DirectionInfo = .turnRight
    var trafficLight: TrafficLightInfo = .none
    var connectionStatus: String = "已連接"
    var batteryLevel: String = "72%"

    private let service: WalkModeServicing

    init(service: WalkModeServicing = StubWalkModeService()) {
        self.service = service
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
