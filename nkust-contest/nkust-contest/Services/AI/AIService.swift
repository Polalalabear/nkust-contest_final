import UIKit

struct LocalResult {
    let hasObstacle: Bool

    static let mock = LocalResult(hasObstacle: false)
}

struct CloudResult {
    let summary: String

    static let mock = CloudResult(summary: "")
}

protocol AIService {
    func analyzeLocal(frame: UIImage) async -> LocalResult
    func analyzeCloud(frame: UIImage) async -> CloudResult
}

final class MockAIService: AIService {
    func analyzeLocal(frame: UIImage) async -> LocalResult {
        // TODO: integrate CoreML
        _ = frame
        return .mock
    }

    func analyzeCloud(frame: UIImage) async -> CloudResult {
        // TODO: integrate Gemini API
        _ = frame
        return .mock
    }
}
