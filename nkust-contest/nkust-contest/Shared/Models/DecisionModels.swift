import Foundation

enum NavigationAction: String {
    case stop = "STOP"
    case moveLeft = "MOVE LEFT"
    case moveRight = "MOVE RIGHT"
    case safe = "SAFE"
}

struct DecisionContext {
    let obstacleDetected: Bool
}

struct DecisionResult {
    let action: NavigationAction
}
