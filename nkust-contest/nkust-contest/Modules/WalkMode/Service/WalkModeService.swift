import Foundation

@MainActor
protocol WalkModeServicing {
    /// 依目前感測／畫面狀態評估並觸發回饋；回傳本次決策結果供 UI 可選用
    @discardableResult
    func evaluateNavigation(context: DecisionContext, voiceEnabled: Bool) -> DecisionResult
    func replayLastInstruction()
    func toggleMute()
    func startVoiceCommand()
    func triggerSOS()
}

@MainActor
final class DefaultWalkModeService: WalkModeServicing {
    private let decisionEngine: DecisionEngine
    private let feedback: FeedbackManager
    private var userMuted = false

    init(engine: DecisionEngine, feedback: FeedbackManager) {
        self.decisionEngine = engine
        self.feedback = feedback
    }

    convenience init() {
        self.init(engine: DefaultDecisionEngine(), feedback: LiveFeedbackManager())
    }

    func evaluateNavigation(context: DecisionContext, voiceEnabled: Bool) -> DecisionResult {
        let result = decisionEngine.decide(context: context)
        let effectiveVoice = voiceEnabled && !userMuted
        feedback.deliverNavigationFeedback(result, context: context, voiceEnabled: effectiveVoice)
        return result
    }

    func replayLastInstruction() {
        feedback.replayLastInstruction()
    }

    func toggleMute() {
        userMuted.toggle()
        feedback.setMuted(userMuted)
    }

    func startVoiceCommand() {
        // TODO: 整合語音指令輸入（SFSpeechRecognizer 等）
    }

    func triggerSOS() {
        feedback.triggerSOS()
    }
}

@MainActor
final class StubWalkModeService: WalkModeServicing {
    init() {}

    func evaluateNavigation(context: DecisionContext, voiceEnabled: Bool) -> DecisionResult {
        _ = (context, voiceEnabled)
        return DecisionResult(action: .safe)
    }

    func replayLastInstruction() {}

    func toggleMute() {}

    func startVoiceCommand() {}

    func triggerSOS() {}
}
