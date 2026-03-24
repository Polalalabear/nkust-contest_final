import UIKit
import CoreML
import Vision

struct LocalResult {
    let hasObstacle: Bool
    let confidence: Double
    let estimatedObstacleDistanceMeters: Int?
    let trafficLightRed: Bool?
    let obstacleCenterNormalized: CGPoint?

    static let mock = LocalResult(
        hasObstacle: false,
        confidence: 0,
        estimatedObstacleDistanceMeters: nil,
        trafficLightRed: nil,
        obstacleCenterNormalized: nil
    )
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
        do {
            return try await modelRuntime.predictLocal(frame: frame)
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
    case missingBundledModelPackage(name: String)
    case frameConversionFailed
    case visionRequestFailed(details: String)

    var errorDescription: String? {
        switch self {
        case .missingModel(let name):
            return "找不到模型資源：\(name).mlmodelc / \(name).mlpackage"
        case .unsupportedPackageLayout(let name):
            return "模型包不完整：\(name).mlpackage 缺少 Data/com.apple.CoreML/model.mlmodel 或 weights"
        case .missingBundledModelPackage(let name):
            return "Bundle 內找不到模型包：\(name).mlpackage（請確認已加入 Copy Bundle Resources）"
        case .frameConversionFailed:
            return "影像格式轉換失敗：無法取得可供 Vision 推論的 CGImage。"
        case .visionRequestFailed(let details):
            return "Vision 推論失敗：\(details)"
        }
    }
}

final class CoreMLModelRuntime {
    private let localModelName = "yolo26n"
    private var cachedModelURL: URL?
    private var cachedVisionModel: VNCoreMLModel?

    func predictLocal(frame: UIImage) async throws -> LocalResult {
        let modelURL = try resolveModelURL(named: localModelName)
        let cgImage = try resolveCGImage(from: frame)
        let visionModel = try resolveVisionModel(modelURL: modelURL)
        let detections = try await runVisionInference(cgImage: cgImage, model: visionModel)

        guard let nearest = detections.max(by: { $0.area < $1.area }) else {
            return LocalResult(
                hasObstacle: false,
                confidence: 0,
                estimatedObstacleDistanceMeters: nil,
                trafficLightRed: nil,
                obstacleCenterNormalized: nil
            )
        }

        let confidence = nearest.confidence
        let estimatedDistance = estimateDistanceMeters(from: nearest.area)
        return LocalResult(
            hasObstacle: confidence >= 0.35,
            confidence: confidence,
            estimatedObstacleDistanceMeters: estimatedDistance,
            trafficLightRed: nil,
            obstacleCenterNormalized: nearest.center
        )
    }

    private func resolveModelURL(named name: String) throws -> URL {
        if let compiled = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
            return compiled
        }

        guard let package = Bundle.main.url(forResource: name, withExtension: "mlpackage") else {
            throw CoreMLModelRuntimeError.missingBundledModelPackage(name: name)
        }
        guard isValidPackageLayout(package) else {
            throw CoreMLModelRuntimeError.unsupportedPackageLayout(name: name)
        }
        return package

        // 保留在上方路徑分支已覆蓋，此行不會觸發；作為防禦式回退。
        // throw CoreMLModelRuntimeError.missingModel(name: name)
    }

    private func isValidPackageLayout(_ packageURL: URL) -> Bool {
        let packagePath = packageURL.path
        let hasSpec = FileManager.default.fileExists(atPath: "\(packagePath)/Data/com.apple.CoreML/model.mlmodel")
        let hasWeights = FileManager.default.fileExists(atPath: "\(packagePath)/Data/com.apple.CoreML/weights")
        return hasSpec && hasWeights
    }

    private func resolveVisionModel(modelURL: URL) throws -> VNCoreMLModel {
        if let cachedModelURL, let cachedVisionModel, cachedModelURL == modelURL {
            return cachedVisionModel
        }

        let loadedModel: MLModel
        if modelURL.pathExtension == "mlpackage" {
            let compiledURL = try MLModel.compileModel(at: modelURL)
            loadedModel = try MLModel(contentsOf: compiledURL)
        } else {
            loadedModel = try MLModel(contentsOf: modelURL)
        }

        let vnModel = try VNCoreMLModel(for: loadedModel)
        cachedModelURL = modelURL
        cachedVisionModel = vnModel
        return vnModel
    }

    private func runVisionInference(
        cgImage: CGImage,
        model: VNCoreMLModel
    ) async throws -> [DetectionCandidate] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error {
                    continuation.resume(throwing: CoreMLModelRuntimeError.visionRequestFailed(details: error.localizedDescription))
                    return
                }

                if let objects = request.results as? [VNRecognizedObjectObservation] {
                    let mapped = objects.map {
                        DetectionCandidate(
                            confidence: Double($0.confidence),
                            area: $0.boundingBox.area,
                            center: CGPoint(x: $0.boundingBox.midX, y: $0.boundingBox.midY)
                        )
                    }
                    continuation.resume(returning: mapped)
                    return
                }

                if let classifications = request.results as? [VNClassificationObservation] {
                    let mapped = classifications.map { item in
                        DetectionCandidate(confidence: Double(item.confidence), area: 0.08, center: nil)
                    }
                    continuation.resume(returning: mapped)
                    return
                }

                if let featureValues = request.results as? [VNCoreMLFeatureValueObservation] {
                    let mapped = self.mapFeatureValueObservations(featureValues)
                    continuation.resume(returning: mapped)
                    return
                }

                // 部分模型會回傳非 bbox/classification 結果，視為本幀「無可用偵測」而非錯誤。
                continuation.resume(returning: [])
            }

            request.imageCropAndScaleOption = .scaleFill
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: CoreMLModelRuntimeError.visionRequestFailed(details: error.localizedDescription))
            }
        }
    }

    private func resolveCGImage(from image: UIImage) throws -> CGImage {
        if let cgImage = image.cgImage {
            return cgImage
        }

        let renderer = UIGraphicsImageRenderer(size: image.size)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }

        guard let cgImage = rendered.cgImage else {
            throw CoreMLModelRuntimeError.frameConversionFailed
        }
        return cgImage
    }

    private func mapFeatureValueObservations(_ observations: [VNCoreMLFeatureValueObservation]) -> [DetectionCandidate] {
        var candidates: [DetectionCandidate] = []

        for observation in observations {
            let featureValue = observation.featureValue

            if let multiArray = featureValue.multiArrayValue {
                let values = extractNumericValues(from: multiArray)
                if let maxValue = values.max(), maxValue > 0 {
                    candidates.append(
                        DetectionCandidate(
                            confidence: maxValue,
                            area: 0.08,
                            center: nil
                        )
                    )
                }
                continue
            }

            if featureValue.type == .double {
                let confidence = featureValue.doubleValue
                if confidence > 0 {
                    candidates.append(DetectionCandidate(confidence: confidence, area: 0.08, center: nil))
                }
                continue
            }

            if featureValue.type == .int64 {
                let confidence = Double(featureValue.int64Value)
                if confidence > 0 {
                    candidates.append(DetectionCandidate(confidence: confidence, area: 0.08, center: nil))
                }
            }
        }

        return candidates
    }

    private func extractNumericValues(from multiArray: MLMultiArray) -> [Double] {
        let pointer = multiArray.dataPointer
        let count = multiArray.count
        switch multiArray.dataType {
        case .double:
            let typed = pointer.bindMemory(to: Double.self, capacity: count)
            return Array(UnsafeBufferPointer(start: typed, count: count))
        case .float32:
            let typed = pointer.bindMemory(to: Float.self, capacity: count)
            return Array(UnsafeBufferPointer(start: typed, count: count)).map(Double.init)
        case .float16:
            let typed = pointer.bindMemory(to: UInt16.self, capacity: count)
            return Array(UnsafeBufferPointer(start: typed, count: count)).map { Double(Float16(bitPattern: $0)) }
        case .int32:
            let typed = pointer.bindMemory(to: Int32.self, capacity: count)
            return Array(UnsafeBufferPointer(start: typed, count: count)).map(Double.init)
        case .int8:
            let typed = pointer.bindMemory(to: Int8.self, capacity: count)
            return Array(UnsafeBufferPointer(start: typed, count: count)).map(Double.init)
        @unknown default:
            return []
        }
    }

    /// 用 bbox 面積粗估距離（僅作導航決策先期接線，後續可替換成模型真實距離輸出）
    private func estimateDistanceMeters(from area: CGFloat) -> Int {
        if area >= 0.35 { return 1 }
        if area >= 0.20 { return 3 }
        if area >= 0.10 { return 6 }
        return 10
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}

private struct DetectionCandidate {
    let confidence: Double
    let area: CGFloat
    let center: CGPoint?
}
