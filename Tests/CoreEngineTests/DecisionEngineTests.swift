import XCTest
@testable import CoreEngine

final class DecisionEngineTests: XCTestCase {
    func testReturnsStopWhenCenterRiskIsHigh() throws {
        let engine = DecisionEngine()
        let result = try engine.evaluate(
            GridRiskInput(cells: [
                CellRisk(0), CellRisk(2.5), CellRisk(0),
                CellRisk(0), CellRisk(2.0), CellRisk(0),
                CellRisk(0), CellRisk(2.0), CellRisk(0)
            ])
        )

        XCTAssertEqual(result.action, .stop)
        XCTAssertEqual(result.score.center, 6.5, accuracy: 0.0001)
    }

    func testReturnsMoveRightWhenLeftSideRiskDominates() throws {
        let engine = DecisionEngine()
        let result = try engine.evaluate(
            GridRiskInput(cells: [
                CellRisk(1.5), CellRisk(0), CellRisk(0.2),
                CellRisk(1.0), CellRisk(0), CellRisk(0.2),
                CellRisk(1.0), CellRisk(0), CellRisk(0.1)
            ])
        )

        XCTAssertEqual(result.action, .moveRight)
    }

    func testReturnsMoveLeftWhenRightSideRiskDominates() throws {
        let engine = DecisionEngine()
        let result = try engine.evaluate(
            GridRiskInput(cells: [
                CellRisk(0.2), CellRisk(0), CellRisk(1.5),
                CellRisk(0.2), CellRisk(0), CellRisk(1.0),
                CellRisk(0.1), CellRisk(0), CellRisk(1.0)
            ])
        )

        XCTAssertEqual(result.action, .moveLeft)
    }

    func testReturnsSafeWhenRiskIsLowAndBalanced() throws {
        let engine = DecisionEngine()
        let result = try engine.evaluate(
            GridRiskInput(cells: [
                CellRisk(0.3), CellRisk(0.2), CellRisk(0.3),
                CellRisk(0.2), CellRisk(0.2), CellRisk(0.2),
                CellRisk(0.3), CellRisk(0.2), CellRisk(0.3)
            ])
        )

        XCTAssertEqual(result.action, .safe)
    }

    func testThrowsForInvalidGridSize() throws {
        let engine = DecisionEngine()

        XCTAssertThrowsError(try engine.evaluate(GridRiskInput(cells: [CellRisk(0.5)]))) { error in
            XCTAssertEqual(error as? DecisionEngineError, .invalidGridSize(expected: 9, got: 1))
        }
    }
}
