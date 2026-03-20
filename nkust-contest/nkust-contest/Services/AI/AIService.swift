import UIKit
import CoreML

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

final class LiveAIService: AIService {
    private let modelRuntime: CoreMLModelRuntime

    init(modelRuntime: CoreMLModelRuntime = CoreMLModelRuntime()) {
        self.modelRuntime = modelRuntime
    }

    func analyzeLocal(frame: UIImage) async -> LocalResult {
        _ = frame
        do {
            return try await modelRuntime.predictLocal()
        } catch {
            await SystemIncidentCenter.shared.report(
                title: "CoreML 推論失敗",
                details: error.localizedDescription,
                isCritical: true
            )
            return .mock
        }
    }

    func analyzeCloud(frame: UIImage) async -> CloudResult {
        _ = frame
        // Gemini 仍未啟用實際網路呼叫，先回報系統層以便監控。
        await SystemIncidentCenter.shared.report(
            title: "Gemini 尚未接入",
            details: "目前 analyzeCloud 仍為 stub，未發出 API 呼叫。",
            isCritical: false
        )
        return .mock
    }
}

enum CoreMLModelRuntimeError: LocalizedError {
    case missingModel(name: String)
    case unsupportedPackageLayout(name: String)
    case missingModelDirectory(path: String)

    var errorDescription: String? {
        switch self {
        case .missingModel(let name):
            return "找不到模型資源：\(name).mlmodelc / \(name).mlpackage"
        case .unsupportedPackageLayout(let name):
            return "模型包不完整：\(name).mlpackage 缺少 com.apple.CoreML/model.mlmodel 或 weights"
        case .missingModelDirectory(let path):
            return "模型目錄不存在：\(path)"
        }
    }
}

final class CoreMLModelRuntime {
    private let localModelName = "yolo26n"
    private let dataDirectoryRelativePath = "Sources/CoreEngine/Data"

    func predictLocal() async throws -> LocalResult {
        let _ = try resolveModelURL(named: localModelName)

        // TODO: 串入 Vision + 真實輸入前處理／後處理，這裡先保留最小可驗證路徑。
        return LocalResult(hasObstacle: Bool.random())
    }

    private func resolveModelURL(named name: String) throws -> URL {
        if let compiled = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
            return compiled
        }

        if let package = Bundle.main.url(forResource: name, withExtension: "mlpackage"),
           isValidPackageLayout(package) {
            return package
        }

        if let dataDirectory = Bundle.main.resourceURL?.appendingPathComponent(dataDirectoryRelativePath) {
            guard FileManager.default.fileExists(atPath: dataDirectory.path) else {
                throw CoreMLModelRuntimeError.missingModelDirectory(path: dataDirectory.path)
            }

            let package = dataDirectory.appendingPathComponent("\(name).mlpackage")
            if FileManager.default.fileExists(atPath: package.path) {
                guard isValidPackageLayout(package) else {
                    throw CoreMLModelRuntimeError.unsupportedPackageLayout(name: name)
                }
                return package
            }
        }

        throw CoreMLModelRuntimeError.missingModel(name: name)
    }

    private func isValidPackageLayout(_ packageURL: URL) -> Bool {
        let packagePath = packageURL.path
        let hasSpec = FileManager.default.fileExists(atPath: "\(packagePath)/com.apple.CoreML/model.mlmodel")
        let hasWeights = FileManager.default.fileExists(atPath: "\(packagePath)/com.apple.CoreML/weights")
        return hasSpec && hasWeights
    }
}
