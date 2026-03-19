import Foundation

protocol WalkModeEngine {
    func buildContext() -> DecisionContext
}

struct StubWalkModeEngine: WalkModeEngine {
    func buildContext() -> DecisionContext {
        // TODO: map sensor/model outputs to decision context
        return DecisionContext(obstacleDetected: false)
    }
}
