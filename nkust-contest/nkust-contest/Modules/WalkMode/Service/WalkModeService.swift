import Foundation

protocol WalkModeServicing {
    func replayLastInstruction()
    func toggleMute()
    func startVoiceCommand()
    func triggerSOS()
}

final class StubWalkModeService: WalkModeServicing {
    func replayLastInstruction() {
        // TODO: integrate feedback replay
    }

    func toggleMute() {
        // TODO: integrate temporary mute
    }

    func startVoiceCommand() {
        // TODO: integrate voice command input
    }

    func triggerSOS() {
        // TODO: integrate SOS dispatch
    }
}
