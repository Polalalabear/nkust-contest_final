import Foundation

protocol WalkModeEngine {
    func buildContext() -> DecisionContext
}

struct StubWalkModeEngine: WalkModeEngine {
    func buildContext() -> DecisionContext {
        DecisionContext()
    }
}
