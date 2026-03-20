import Foundation

protocol FeedbackManager {
    func deliverNavigationFeedback(_ result: DecisionResult, context: DecisionContext, voiceEnabled: Bool)
    func replayLastInstruction()
    func setMuted(_ muted: Bool)
    func triggerSOS()
}

final class StubFeedbackManager: FeedbackManager {
    func deliverNavigationFeedback(_ result: DecisionResult, context: DecisionContext, voiceEnabled: Bool) {
        _ = (result, context, voiceEnabled)
    }

    func replayLastInstruction() {}

    func setMuted(_ muted: Bool) {
        _ = muted
    }

    func triggerSOS() {}
}
