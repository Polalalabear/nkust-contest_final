public enum NavigationAction: String, Equatable {
    case stop
    case moveLeft
    case moveRight
    case safe
}

public struct CellRisk: Equatable {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }
}

public struct GridRiskInput: Equatable {
    public let cells: [CellRisk]

    public init(cells: [CellRisk]) {
        self.cells = cells
    }
}

public struct RiskScore: Equatable {
    public let left: Double
    public let center: Double
    public let right: Double
    public let total: Double

    public init(left: Double, center: Double, right: Double) {
        self.left = left
        self.center = center
        self.right = right
        self.total = left + center + right
    }
}

public struct DecisionResult: Equatable {
    public let score: RiskScore
    public let action: NavigationAction

    public init(score: RiskScore, action: NavigationAction) {
        self.score = score
        self.action = action
    }
}

public enum DecisionEngineError: Error, Equatable {
    case invalidGridSize(expected: Int, got: Int)
}

public struct DecisionEngine {
    // 3x3 index map:
    // [0,1,2]
    // [3,4,5]
    // [6,7,8]
    private let leftIndexes = [0, 3, 6]
    private let centerIndexes = [1, 4, 7]
    private let rightIndexes = [2, 5, 8]

    private let stopThreshold: Double
    private let cautionThreshold: Double
    private let sideDifferenceThreshold: Double

    public init(
        stopThreshold: Double = 6.0,
        cautionThreshold: Double = 2.0,
        sideDifferenceThreshold: Double = 1.0
    ) {
        self.stopThreshold = stopThreshold
        self.cautionThreshold = cautionThreshold
        self.sideDifferenceThreshold = sideDifferenceThreshold
    }

    public func evaluate(_ input: GridRiskInput) throws -> DecisionResult {
        guard input.cells.count == 9 else {
            throw DecisionEngineError.invalidGridSize(expected: 9, got: input.cells.count)
        }

        let left = sumRisk(input.cells, indexes: leftIndexes)
        let center = sumRisk(input.cells, indexes: centerIndexes)
        let right = sumRisk(input.cells, indexes: rightIndexes)
        let score = RiskScore(left: left, center: center, right: right)

        let action: NavigationAction
        if center >= stopThreshold {
            action = .stop
        } else if left - right >= sideDifferenceThreshold, left >= cautionThreshold {
            action = .moveRight
        } else if right - left >= sideDifferenceThreshold, right >= cautionThreshold {
            action = .moveLeft
        } else {
            action = .safe
        }

        return DecisionResult(score: score, action: action)
    }

    private func sumRisk(_ cells: [CellRisk], indexes: [Int]) -> Double {
        indexes.reduce(0.0) { partial, idx in
            partial + cells[idx].value
        }
    }
}
