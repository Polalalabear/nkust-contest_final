import Foundation

protocol DecisionEngine {
    func decide(context: DecisionContext) -> DecisionResult
}

// MARK: - 真實決策邏輯（純規則、無框架依賴）

/// 依 PRD：紅燈 / 極近障礙 → STOP；中距離 → 轉向提示；其餘 → SAFE
struct DefaultDecisionEngine: DecisionEngine {
    /// 小於等於此距離（公尺）視為立即危險
    private let stopDistanceMeters: Int
    /// 小於等於此距離需方向修正（左）
    private let moveLeftMaxMeters: Int
    /// 此距離內需方向修正（右）
    private let moveRightMaxMeters: Int

    init(
        stopDistanceMeters: Int = 2,
        moveLeftMaxMeters: Int = 5,
        moveRightMaxMeters: Int = 12
    ) {
        self.stopDistanceMeters = stopDistanceMeters
        self.moveLeftMaxMeters = moveLeftMaxMeters
        self.moveRightMaxMeters = moveRightMaxMeters
    }

    func decide(context: DecisionContext) -> DecisionResult {
        if context.trafficLightRed {
            return DecisionResult(action: .stop)
        }

        guard context.obstacleDetected else {
            return DecisionResult(action: .safe)
        }

        let d = context.obstacleDistanceMeters

        if d <= stopDistanceMeters {
            return DecisionResult(action: .stop)
        }
        if d <= moveLeftMaxMeters {
            return DecisionResult(action: .moveLeft)
        }
        if d <= moveRightMaxMeters {
            return DecisionResult(action: .moveRight)
        }

        return DecisionResult(action: .safe)
    }
}

struct StubDecisionEngine: DecisionEngine {
    func decide(context: DecisionContext) -> DecisionResult {
        _ = context
        return DecisionResult(action: .safe)
    }
}
