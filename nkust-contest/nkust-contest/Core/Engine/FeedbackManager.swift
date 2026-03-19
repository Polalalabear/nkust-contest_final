import Foundation

protocol FeedbackManager {
    func replayLastInstruction()
    func setMuted(_ muted: Bool)
    func triggerSOS()
}

final class StubFeedbackManager: FeedbackManager {
    func replayLastInstruction() {
        // TODO: integrate haptic + voice output
    }

    func setMuted(_ muted: Bool) {
        // TODO: integrate audio mute control
        _ = muted
    }

    func triggerSOS() {
        // TODO: integrate SOS flow
    }
}
