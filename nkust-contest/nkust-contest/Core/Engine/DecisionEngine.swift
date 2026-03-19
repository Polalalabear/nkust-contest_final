import Foundation

protocol DecisionEngine {
    func decide(context: DecisionContext) -> DecisionResult
}

struct StubDecisionEngine: DecisionEngine {
    func decide(context: DecisionContext) -> DecisionResult {
        // TODO: implement real decision logic
        _ = context
        return DecisionResult(action: .safe)
    }
}
