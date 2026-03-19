import Foundation
import Combine

final class WalkModeViewModel: ObservableObject {
    @Published var connectionStatus: String = "Disconnected"
    @Published var batteryLevel: String = "Unknown"

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
