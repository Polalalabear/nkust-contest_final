import Foundation

protocol LTCModeEngine {
    func nextIndex(current: Int, total: Int, direction: SwipeDirection) -> Int
}

enum SwipeDirection {
    case up
    case down
}

struct StubLTCModeEngine: LTCModeEngine {
    func nextIndex(current: Int, total: Int, direction: SwipeDirection) -> Int {
        // TODO: refine traversal strategy for accessibility use
        _ = direction
        guard total > 0 else { return 0 }
        return min(max(current, 0), total - 1)
    }
}
