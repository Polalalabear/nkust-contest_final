import UIKit
import CoreML
import Vision

struct DetectedObject: Sendable {
    let label: String
    let confidence: Double
    let bbox: CGRect
}

struct DepthResult: Sendable {
    let roiDepth: Double?
    let normalizedDistance: Double?
    let perObjectNormalizedDistances: [Double]
    let minDepth: Double
    let maxDepth: Double
}

struct SegmentationResult: Sendable {
    let dominantClass: String
    let walkableRatio: Double
    let classHistogram: [String: Double]
}

struct FusionDecision: Sendable {
    let primaryObject: DetectedObject?
    let distanceMeters: Int?
    let isWalkable: Bool
    let command: NavigationAction
    let summary: String
}

struct LocalResult {
    let detections: [DetectedObject]
    let depth: DepthResult?
    let segmentation: SegmentationResult?
    let fusion: FusionDecision
    let obstacleCenterNormalized: CGPoint?
    let trafficLightRed: Bool?

    var hasObstacle: Bool { fusion.primaryObject != nil }
    var confidence: Double { fusion.primaryObject?.confidence ?? 0 }
    var estimatedObstacleDistanceMeters: Int? { fusion.distanceMeters }

    static let mock = LocalResult(
        detections: [],
        depth: nil,
        segmentation: nil,
        fusion: FusionDecision(
            primaryObject: nil,
            distanceMeters: nil,
            isWalkable: true,
            command: .safe,
            summary: "模型正在校準/無有效偵測"
        ),
        obstacleCenterNormalized: nil,
        trafficLightRed: nil
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
    case pixelBufferConversionFailed
    case visionRequestFailed(details: String)
    case featureTypeMismatch(model: String, feature: String, expected: String)
    case unsupportedTensorShape(model: String, feature: String, shape: [NSNumber])

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
        case .pixelBufferConversionFailed:
            return "影像轉換失敗：無法建立推論使用的 CVPixelBuffer。"
        case .visionRequestFailed(let details):
            return "Vision 推論失敗：\(details)"
        case .featureTypeMismatch(let model, let feature, let expected):
            return "\(model) 輸出型別不符：\(feature)，預期 \(expected)"
        case .unsupportedTensorShape(let model, let feature, let shape):
            return "\(model) 輸出 shape 不支援：\(feature) \(shape)"
        }
    }
}

final class CoreMLModelRuntime {
    private let pipeline = LiveModelPipeline()

    func predictLocal(frame: UIImage) async throws -> LocalResult {
        try await pipeline.process(frame: frame)
    }
}

actor LiveModelPipeline {
    private let debugEnabled = AIInferenceDebugConfig.enabled()
    private let yoloRunner = YOLORunner()
    private let midasRunner = MiDaSRunner()
    private let pidNetRunner = PIDNetRunner()
    private let fusion = FusionAggregator()

    func process(frame: UIImage) async throws -> LocalResult {
        let detections = await runYOLO(frame: frame)
        let depth = await runMiDaS(frame: frame, detections: detections)
        let segmentation = await runPIDNet(frame: frame)
        let fused = await fusion.fuse(detections: detections, depth: depth, segmentation: segmentation)
        let center = fused.primaryObject.map { CGPoint(x: $0.bbox.midX, y: $0.bbox.midY) }
        let trafficRed = fused.primaryObject?.label.contains("red_light") == true

        if debugEnabled {
            let top = detections.max(by: { $0.confidence < $1.confidence })?.label ?? "none"
            let depthText = depth.map { "min=\(String(format: "%.3f", $0.minDepth)) max=\(String(format: "%.3f", $0.maxDepth))" } ?? "n/a"
            let segClass = segmentation?.dominantClass ?? "n/a"
            print("[AIFusion][Frame] yoloCount=\(detections.count) top1=\(top) midas=\(depthText) pid=\(segClass)")
            print("[AIFusion][Decision] object=\(fused.primaryObject?.label ?? "none") distance=\(fused.distanceMeters?.description ?? "n/a") walkable=\(fused.isWalkable) command=\(fused.command.rawValue)")
        }

        return LocalResult(
            detections: detections,
            depth: depth,
            segmentation: segmentation,
            fusion: fused,
            obstacleCenterNormalized: center,
            trafficLightRed: trafficRed
        )
    }

    private func runYOLO(frame: UIImage) async -> [DetectedObject] {
        do {
            return try await yoloRunner.predict(frame: frame)
        } catch {
            await reportNonCritical(title: "YOLO 推論失敗", details: error.localizedDescription)
            return []
        }
    }

    private func runMiDaS(frame: UIImage, detections: [DetectedObject]) async -> DepthResult? {
        do {
            return try await midasRunner.predict(frame: frame, detections: detections)
        } catch {
            await reportNonCritical(title: "MiDaS 推論失敗", details: error.localizedDescription)
            return nil
        }
    }

    private func runPIDNet(frame: UIImage) async -> SegmentationResult? {
        do {
            return try await pidNetRunner.predict(frame: frame)
        } catch {
            await reportNonCritical(title: "PIDNet 推論失敗", details: error.localizedDescription)
            return nil
        }
    }

    private func reportNonCritical(title: String, details: String) async {
        await SystemIncidentCenter.shared.report(title: title, details: details, isCritical: false)
    }
}

private struct AIInferenceDebugConfig {
    static func enabled() -> Bool {
        UserDefaults.standard.object(forKey: "ai.debug.logs.enabled") as? Bool ?? true
    }
}

private actor CoreMLPackageLoader {
    private var cache: [String: MLModel] = [:]

    func loadModel(named name: String) throws -> MLModel {
        if let model = cache[name] { return model }
        let url = try resolveModelURL(named: name)
        let loaded: MLModel
        if url.pathExtension == "mlpackage" {
            let compiled = try MLModel.compileModel(at: url)
            loaded = try MLModel(contentsOf: compiled)
        } else {
            loaded = try MLModel(contentsOf: url)
        }
        cache[name] = loaded
        logFeatureDescriptions(model: loaded, modelName: name)
        return loaded
    }

    private func resolveModelURL(named name: String) throws -> URL {
        if let compiled = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
            return compiled
        }
        guard let package = Bundle.main.url(forResource: name, withExtension: "mlpackage") else {
            throw CoreMLModelRuntimeError.missingBundledModelPackage(name: name)
        }
        let packagePath = package.path
        let hasSpec = FileManager.default.fileExists(atPath: "\(packagePath)/Data/com.apple.CoreML/model.mlmodel")
        let hasWeights = FileManager.default.fileExists(atPath: "\(packagePath)/Data/com.apple.CoreML/weights")
        guard hasSpec && hasWeights else {
            throw CoreMLModelRuntimeError.unsupportedPackageLayout(name: name)
        }
        return package
    }

    private func logFeatureDescriptions(model: MLModel, modelName: String) {
        guard AIInferenceDebugConfig.enabled() else { return }
        for (name, desc) in model.modelDescription.inputDescriptionsByName {
            print("[AIFusion][ModelSpec] \(modelName) input \(name) type=\(desc.type.rawValue)")
        }
        for (name, desc) in model.modelDescription.outputDescriptionsByName {
            print("[AIFusion][ModelSpec] \(modelName) output \(name) type=\(desc.type.rawValue)")
        }
    }
}

private actor YOLORunner {
    private let loader = CoreMLPackageLoader()
    private var visionModel: VNCoreMLModel?

    func predict(frame: UIImage) async throws -> [DetectedObject] {
        let model = try await loader.loadModel(named: "yolo26n")
        let vnModel: VNCoreMLModel
        if let visionModel {
            vnModel = visionModel
        } else {
            let loaded = try VNCoreMLModel(for: model)
            visionModel = loaded
            vnModel = loaded
        }
        let cgImage = try imageToCGImage(frame)
        let transform = LetterboxTransform(
            sourceWidth: CGFloat(cgImage.width),
            sourceHeight: CGFloat(cgImage.height),
            targetWidth: 640,
            targetHeight: 640
        )
        let raw = try await runVision(cgImage: cgImage, model: vnModel)
        let labels = YoloLabelMap.labels
        return raw.compactMap { item in
            guard item.confidence >= 0.35 else { return nil }
            let classIndex = max(0, min(labels.count - 1, Int(item.classID)))
            let label = labels.indices.contains(classIndex) ? labels[classIndex] : "class_\(Int(item.classID))"
            let normalized = normalizeBox(item.x1, item.y1, item.x2, item.y2, transform: transform)
            return DetectedObject(label: label, confidence: item.confidence, bbox: normalized)
        }.sorted(by: { $0.confidence > $1.confidence })
    }

    private func runVision(cgImage: CGImage, model: VNCoreMLModel) async throws -> [(x1: Double, y1: Double, x2: Double, y2: Double, confidence: Double, classID: Double)] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error {
                    continuation.resume(throwing: CoreMLModelRuntimeError.visionRequestFailed(details: error.localizedDescription))
                    return
                }
                if let featureValues = request.results as? [VNCoreMLFeatureValueObservation],
                   let first = featureValues.first?.featureValue.multiArrayValue {
                    let rows = MultiArrayReader.rows(of: first, columns: 6)
                    continuation.resume(returning: rows.map { ($0[0], $0[1], $0[2], $0[3], $0[4], $0[5]) })
                    return
                }
                continuation.resume(returning: [])
            }
            request.imageCropAndScaleOption = .scaleFit
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: CoreMLModelRuntimeError.visionRequestFailed(details: error.localizedDescription))
            }
        }
    }

    private func imageToCGImage(_ image: UIImage) throws -> CGImage {
        if let cgImage = image.cgImage { return cgImage }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        guard let cgImage = rendered.cgImage else {
            throw CoreMLModelRuntimeError.frameConversionFailed
        }
        return cgImage
    }

    private func normalizeBox(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, transform: LetterboxTransform) -> CGRect {
        let maxRaw = max(abs(x1), abs(y1), abs(x2), abs(y2))
        let divisor = maxRaw > 1.5 ? 640.0 : 1.0
        let nx1 = max(0, min(1, x1 / divisor))
        let ny1 = max(0, min(1, y1 / divisor))
        let nx2 = max(0, min(1, x2 / divisor))
        let ny2 = max(0, min(1, y2 / divisor))
        let minX = min(nx1, nx2)
        let minY = min(ny1, ny2)
        let width = max(0.001, abs(nx2 - nx1))
        let height = max(0.001, abs(ny2 - ny1))
        let modelRect = CGRect(x: minX, y: minY, width: width, height: height)
        return transform.modelRectToImageRect(modelRect)
    }
}

private actor MiDaSRunner {
    private let loader = CoreMLPackageLoader()

    func predict(frame: UIImage, detections: [DetectedObject]) async throws -> DepthResult {
        let model = try await loader.loadModel(named: "midas_v21_small_256")
        let inputFeatureName = model.modelDescription.inputDescriptionsByName.keys.first ?? "image"
        let outputFeatureName = model.modelDescription.outputDescriptionsByName.keys.first ?? "var_587"
        let prepared = try ImageTensorBuilder.makeNormalizedCHWLetterboxed(from: frame, width: 256, height: 256)
        let input = prepared.tensor
        let output = try await model.prediction(from: try MLDictionaryFeatureProvider(dictionary: [inputFeatureName: input]))
        guard let depthMap = output.featureValue(for: outputFeatureName)?.multiArrayValue else {
            throw CoreMLModelRuntimeError.featureTypeMismatch(model: "MiDaS", feature: outputFeatureName, expected: "MLMultiArray")
        }
        let all = MultiArrayReader.sampleDepth(in: depthMap, normalizedROI: prepared.transform.validRectInModelNormalized)
        guard let minDepth = all.min(), let maxDepth = all.max(), maxDepth > minDepth else {
            return DepthResult(roiDepth: nil, normalizedDistance: nil, perObjectNormalizedDistances: [], minDepth: 0, maxDepth: 0)
        }

        let primaryROI = detections.max(by: { $0.confidence < $1.confidence })?.bbox
        let roiDepth = primaryROI.flatMap { roi in
            let modelROI = prepared.transform.imageRectToModelRect(roi)
            let sampled = MultiArrayReader.sampleDepth(in: depthMap, normalizedROI: modelROI)
            return sampled.isEmpty ? nil : sampled.reduce(0, +) / Double(sampled.count)
        }

        let normalizedDistance: Double? = roiDepth.flatMap { depth in
            normalizeInverseDepth(depth, minDepth: minDepth, maxDepth: maxDepth)
        }

        let perObject = detections.map { detected in
            let modelROI = prepared.transform.imageRectToModelRect(detected.bbox)
            let sampled = MultiArrayReader.sampleDepth(in: depthMap, normalizedROI: modelROI)
            guard !sampled.isEmpty else { return -1.0 }
            let meanDepth = sampled.reduce(0, +) / Double(sampled.count)
            return normalizeInverseDepth(meanDepth, minDepth: minDepth, maxDepth: maxDepth) ?? -1.0
        }

        return DepthResult(
            roiDepth: roiDepth,
            normalizedDistance: normalizedDistance,
            perObjectNormalizedDistances: perObject,
            minDepth: minDepth,
            maxDepth: maxDepth
        )
    }

    private func normalizeInverseDepth(_ depth: Double, minDepth: Double, maxDepth: Double) -> Double? {
        guard maxDepth > minDepth else { return nil }
        // MiDaS is inverse-depth like; smaller value usually farther.
        let normalizedDepth = (depth - minDepth) / (maxDepth - minDepth)
        return max(0, min(1, 1 - normalizedDepth))
    }
}

private actor PIDNetRunner {
    private let loader = CoreMLPackageLoader()

    func predict(frame: UIImage) async throws -> SegmentationResult {
        let model = try await loader.loadModel(named: "PIDNet_S_Cityscapes_val")
        let inputFeatureName = model.modelDescription.inputDescriptionsByName.keys.first ?? "image"
        let outputFeatureName = model.modelDescription.outputDescriptionsByName.keys.first ?? "var_420"
        let prepared = try ImageTensorBuilder.makeNormalizedCHWLetterboxed(from: frame, width: 2048, height: 1024)
        let input = prepared.tensor
        let output = try await model.prediction(from: try MLDictionaryFeatureProvider(dictionary: [inputFeatureName: input]))
        guard let logits = output.featureValue(for: outputFeatureName)?.multiArrayValue else {
            throw CoreMLModelRuntimeError.featureTypeMismatch(model: "PIDNet", feature: outputFeatureName, expected: "MLMultiArray")
        }
        let histogram = MultiArrayReader.semanticHistogram(
            from: logits,
            classLabels: PIDNetLabels.classes,
            validROI: prepared.transform.validRectInModelNormalized
        )
        let dominant = histogram.max(by: { $0.value < $1.value })?.key ?? "unknown"
        let walkable = (histogram["road"] ?? 0) + (histogram["sidewalk"] ?? 0)
        return SegmentationResult(dominantClass: dominant, walkableRatio: walkable, classHistogram: histogram)
    }
}

private struct LetterboxTransform: Sendable {
    let sourceWidth: CGFloat
    let sourceHeight: CGFloat
    let targetWidth: CGFloat
    let targetHeight: CGFloat
    let scale: CGFloat
    let padX: CGFloat
    let padY: CGFloat

    init(sourceWidth: CGFloat, sourceHeight: CGFloat, targetWidth: CGFloat, targetHeight: CGFloat) {
        self.sourceWidth = max(1, sourceWidth)
        self.sourceHeight = max(1, sourceHeight)
        self.targetWidth = max(1, targetWidth)
        self.targetHeight = max(1, targetHeight)
        self.scale = min(self.targetWidth / self.sourceWidth, self.targetHeight / self.sourceHeight)
        let scaledWidth = self.sourceWidth * self.scale
        let scaledHeight = self.sourceHeight * self.scale
        self.padX = (self.targetWidth - scaledWidth) / 2
        self.padY = (self.targetHeight - scaledHeight) / 2
    }

    var validRectInModelNormalized: CGRect {
        let width = (sourceWidth * scale) / targetWidth
        let height = (sourceHeight * scale) / targetHeight
        let x = padX / targetWidth
        let y = padY / targetHeight
        return CGRect(x: x, y: y, width: width, height: height)
    }

    func modelRectToImageRect(_ rect: CGRect) -> CGRect {
        let x = ((rect.minX * targetWidth) - padX) / scale / sourceWidth
        let y = ((rect.minY * targetHeight) - padY) / scale / sourceHeight
        let width = (rect.width * targetWidth) / scale / sourceWidth
        let height = (rect.height * targetHeight) / scale / sourceHeight
        return clampNormalized(CGRect(x: x, y: y, width: width, height: height))
    }

    func imageRectToModelRect(_ rect: CGRect) -> CGRect {
        let x = ((rect.minX * sourceWidth * scale) + padX) / targetWidth
        let y = ((rect.minY * sourceHeight * scale) + padY) / targetHeight
        let width = (rect.width * sourceWidth * scale) / targetWidth
        let height = (rect.height * sourceHeight * scale) / targetHeight
        return clampNormalized(CGRect(x: x, y: y, width: width, height: height))
    }

    private func clampNormalized(_ rect: CGRect) -> CGRect {
        let minX = max(0, min(1, rect.minX))
        let minY = max(0, min(1, rect.minY))
        let maxX = max(minX, min(1, rect.maxX))
        let maxY = max(minY, min(1, rect.maxY))
        return CGRect(x: minX, y: minY, width: max(0.001, maxX - minX), height: max(0.001, maxY - minY))
    }
}

private actor FusionAggregator {
    private let walkableStopThreshold = 0.25
    private let headZoneTopThreshold = 0.42
    private let headZoneMinX = 1.0 / 3.0
    private let headZoneMaxX = 2.0 / 3.0
    private let headStopDistanceMeters = 2
    private let antiLoopRepeatThreshold = 8

    private var lastLateralAction: NavigationAction?
    private var repeatedLateralCount: Int = 0
    private var lastLateralDistance: Int?

    func fuse(
        detections: [DetectedObject],
        depth: DepthResult?,
        segmentation: SegmentationResult?
    ) -> FusionDecision {
        let primary = selectPrimaryObject(detections: detections, depth: depth, segmentation: segmentation)
        let walkableRatio = segmentation?.walkableRatio ?? 0.5
        let isWalkable = walkableRatio >= 0.45

        let distance = primary.flatMap { selected in
            estimatedDistanceMeters(for: selected.object, index: selected.index, depth: depth)
        }
        let hasHeadCollisionRisk = hasHeadRisk(candidates: detections, depth: depth)

        let command: NavigationAction
        if hasHeadCollisionRisk {
            command = .stop
        } else if primary == nil {
            command = commandWhenNoDetection(depth: depth, isWalkable: isWalkable, walkableRatio: walkableRatio)
        } else if !isWalkable {
            command = .stop
        } else if let distance, distance <= 2 {
            command = .stop
        } else if let distance, distance <= 5 {
            command = primary.map { lateralAvoidanceAction(for: $0.object) } ?? .safe
        } else if let distance, distance <= 12 {
            command = primary.map { lateralAvoidanceAction(for: $0.object) } ?? .safe
        } else {
            command = .safe
        }
        let stabilizedCommand = antiLoopAdjusted(command: command, distance: distance)

        let summary: String
        if hasHeadCollisionRisk {
            summary = "前上方偵測到近距離障礙，請立即停止並留意頭部碰撞風險"
        } else if let primary {
            let distanceText = distance.map { "\($0) 公尺" } ?? "未知距離"
            let segText = segmentation?.dominantClass ?? "語意未知"
            let walkText = isWalkable ? "可通行" : "有障礙風險"
            summary = "前方\(primary.object.label)約 \(distanceText)，\(segText)，\(walkText)，建議\(chineseActionText(stabilizedCommand))"
        } else {
            summary = "模型正在校準/無有效偵測"
        }

        return FusionDecision(
            primaryObject: primary?.object,
            distanceMeters: distance,
            isWalkable: isWalkable,
            command: stabilizedCommand,
            summary: summary
        )
    }

    private func chineseActionText(_ action: NavigationAction) -> String {
        switch action {
        case .stop: return "停止"
        case .moveLeft: return "向左修正"
        case .moveRight: return "向右修正"
        case .safe: return "保持直行"
        }
    }

    private func commandWhenNoDetection(depth: DepthResult?, isWalkable: Bool, walkableRatio: Double) -> NavigationAction {
        if !isWalkable && walkableRatio < walkableStopThreshold {
            return .stop
        }
        if let normalized = depth?.normalizedDistance, normalizedToMeters(normalized) <= 2 {
            return .stop
        }
        return .safe
    }

    private func fallbackDistance(from bbox: CGRect?) -> Int? {
        guard let bbox else { return nil }
        let area = bbox.width * bbox.height
        if area >= 0.35 { return 1 }
        if area >= 0.20 { return 3 }
        if area >= 0.10 { return 6 }
        return 10
    }

    private struct Candidate {
        let index: Int
        let object: DetectedObject
        let distanceMeters: Int?
        let riskScore: Double
    }

    private func selectPrimaryObject(
        detections: [DetectedObject],
        depth: DepthResult?,
        segmentation: SegmentationResult?
    ) -> Candidate? {
        guard !detections.isEmpty else { return nil }
        let walkableRatio = segmentation?.walkableRatio ?? 0.5
        let allCandidates = detections.enumerated().map { idx, object in
            let distance = estimatedDistanceMeters(for: object, index: idx, depth: depth)
            let risk = riskScore(for: object, distanceMeters: distance, walkableRatio: walkableRatio)
            return Candidate(index: idx, object: object, distanceMeters: distance, riskScore: risk)
        }

        // Phase 2: prioritize center column (top/middle/bottom center cells).
        let centerCandidates = allCandidates.filter { candidate in
            let centerX = candidate.object.bbox.midX
            return centerX >= (1.0 / 3.0) && centerX < (2.0 / 3.0)
        }
        let pool = centerCandidates.isEmpty ? allCandidates : centerCandidates
        return pool.sorted(by: candidateComparator).first
    }

    private func candidateComparator(lhs: Candidate, rhs: Candidate) -> Bool {
        let lDistance = lhs.distanceMeters ?? Int.max
        let rDistance = rhs.distanceMeters ?? Int.max
        if lDistance != rDistance { return lDistance < rDistance }
        if lhs.riskScore != rhs.riskScore { return lhs.riskScore > rhs.riskScore }
        return lhs.object.confidence > rhs.object.confidence
    }

    private func estimatedDistanceMeters(for object: DetectedObject, index: Int, depth: DepthResult?) -> Int? {
        guard let depth else { return fallbackDistance(from: object.bbox) }
        if depth.perObjectNormalizedDistances.indices.contains(index) {
            let normalized = depth.perObjectNormalizedDistances[index]
            if normalized >= 0 {
                return normalizedToMeters(normalized)
            }
        }
        if let normalized = depth.normalizedDistance {
            return normalizedToMeters(normalized)
        }
        return fallbackDistance(from: object.bbox)
    }

    private func normalizedToMeters(_ normalized: Double) -> Int {
        // 0...1 to 0.8m...12m
        let meters = 0.8 + (normalized * 11.2)
        return Int(max(1, min(12, round(meters))))
    }

    private func riskScore(for object: DetectedObject, distanceMeters: Int?, walkableRatio: Double) -> Double {
        let distanceRisk: Double
        if let distanceMeters {
            distanceRisk = max(0, 12 - Double(distanceMeters)) / 12.0
        } else {
            distanceRisk = 0.35
        }
        let classRisk = classRiskWeight(for: object.label)
        let walkableRisk = max(0, 0.45 - walkableRatio) * 2.0
        return (distanceRisk * 0.6) + (classRisk * 0.3) + (walkableRisk * 0.1)
    }

    private func classRiskWeight(for label: String) -> Double {
        let high = ["car", "truck", "bus", "motorcycle", "bicycle", "person", "train"]
        let medium = ["traffic_light", "stop_sign", "bench", "dog"]
        if high.contains(label) { return 1.0 }
        if medium.contains(label) { return 0.6 }
        return 0.4
    }

    private func lateralAvoidanceAction(for object: DetectedObject) -> NavigationAction {
        let centerX = object.bbox.midX
        if centerX < 0.45 {
            // Obstacle is on left side: steer right.
            return .moveRight
        }
        if centerX > 0.55 {
            // Obstacle is on right side: steer left.
            return .moveLeft
        }
        // Obstacle is in center lane: default to left first to break "always right" tendency.
        return .moveLeft
    }

    private func hasHeadRisk(candidates: [DetectedObject], depth: DepthResult?) -> Bool {
        for (index, object) in candidates.enumerated() {
            guard isInHeadZone(object.bbox) else { continue }
            if let distance = estimatedDistanceMeters(for: object, index: index, depth: depth),
               distance <= headStopDistanceMeters {
                return true
            }
            if depth == nil || depth?.perObjectNormalizedDistances.indices.contains(index) == false {
                // Without reliable depth, keep conservative behavior for upper-center obstacles.
                return true
            }
        }
        return false
    }

    private func isInHeadZone(_ bbox: CGRect) -> Bool {
        let centerX = bbox.midX
        let centerY = bbox.midY
        return centerX >= headZoneMinX && centerX < headZoneMaxX && centerY <= headZoneTopThreshold
    }

    private func antiLoopAdjusted(command: NavigationAction, distance: Int?) -> NavigationAction {
        switch command {
        case .moveLeft, .moveRight:
            if command == lastLateralAction {
                repeatedLateralCount += 1
            } else {
                repeatedLateralCount = 1
                lastLateralAction = command
            }

            defer { lastLateralDistance = distance }

            if repeatedLateralCount >= antiLoopRepeatThreshold {
                let previousDistance = lastLateralDistance ?? Int.max
                let currentDistance = distance ?? Int.max
                // If repeated same-side steering doesn't improve distance, force stop.
                if currentDistance >= previousDistance {
                    repeatedLateralCount = 0
                    return .stop
                }
            }
            return command
        case .stop, .safe:
            repeatedLateralCount = 0
            lastLateralAction = nil
            lastLateralDistance = distance
            return command
        }
    }
}

private enum MultiArrayReader {
    static func rows(of array: MLMultiArray, columns: Int) -> [[Double]] {
        let all = allValues(of: array)
        guard columns > 0 else { return [] }
        let rowCount = all.count / columns
        return (0..<rowCount).map { row in
            let start = row * columns
            let end = start + columns
            return Array(all[start..<end])
        }
    }

    static func allValues(of multiArray: MLMultiArray) -> [Double] {
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

    static func sampleDepth(in array: MLMultiArray, normalizedROI: CGRect) -> [Double] {
        let shape = array.shape.map(\.intValue)
        guard shape.count == 3 else { return [] } // [1, H, W]
        let height = shape[1]
        let width = shape[2]
        let minX = max(0, min(width - 1, Int(Double(width) * normalizedROI.minX)))
        let maxX = max(minX, min(width - 1, Int(Double(width) * normalizedROI.maxX)))
        let minY = max(0, min(height - 1, Int(Double(height) * normalizedROI.minY)))
        let maxY = max(minY, min(height - 1, Int(Double(height) * normalizedROI.maxY)))
        let values = allValues(of: array)
        var sampled: [Double] = []
        sampled.reserveCapacity(max(1, (maxX - minX + 1) * (maxY - minY + 1)))
        for y in minY...maxY {
            for x in minX...maxX {
                let idx = y * width + x
                if values.indices.contains(idx) {
                    sampled.append(values[idx])
                }
            }
        }
        return sampled
    }

    static func semanticHistogram(from logits: MLMultiArray, classLabels: [String], validROI: CGRect? = nil) -> [String: Double] {
        let shape = logits.shape.map(\.intValue)
        guard shape.count == 4 else { return [:] } // [1, C, H, W]
        let classes = shape[1]
        let height = shape[2]
        let width = shape[3]
        let values = allValues(of: logits)
        var counts = Array(repeating: 0, count: classes)
        let minX = validROI.map { max(0, min(width - 1, Int(CGFloat(width) * $0.minX))) } ?? 0
        let maxX = validROI.map { max(minX, min(width - 1, Int(CGFloat(width) * $0.maxX))) } ?? max(0, width - 1)
        let minY = validROI.map { max(0, min(height - 1, Int(CGFloat(height) * $0.minY))) } ?? 0
        let maxY = validROI.map { max(minY, min(height - 1, Int(CGFloat(height) * $0.maxY))) } ?? max(0, height - 1)
        let pixels = max(1, (maxX - minX + 1) * (maxY - minY + 1))

        for y in minY...maxY {
            for x in minX...maxX {
                let p = y * width + x
                var bestClass = 0
                var bestValue = -Double.greatestFiniteMagnitude
                for c in 0..<classes {
                    let index = c * height * width + p
                    guard values.indices.contains(index) else { continue }
                    let v = values[index]
                    if v > bestValue {
                        bestValue = v
                        bestClass = c
                    }
                }
                counts[bestClass] += 1
            }
        }

        let total = Double(max(1, pixels))
        var histogram: [String: Double] = [:]
        for idx in 0..<classes {
            let label = classLabels.indices.contains(idx) ? classLabels[idx] : "class_\(idx)"
            histogram[label] = Double(counts[idx]) / total
        }
        return histogram
    }
}

private enum ImageTensorBuilder {
    struct PreparedImageTensor {
        let tensor: MLMultiArray
        let transform: LetterboxTransform
    }

    static func makeNormalizedCHW(from image: UIImage, width: Int, height: Int) throws -> MLMultiArray {
        try makeNormalizedCHWLetterboxed(from: image, width: width, height: height).tensor
    }

    static func makeNormalizedCHWLetterboxed(from image: UIImage, width: Int, height: Int) throws -> PreparedImageTensor {
        guard let prepared = ImagePixelBufferBuilder.makePixelBufferLetterboxed(from: image, width: width, height: height) else {
            throw CoreMLModelRuntimeError.pixelBufferConversionFailed
        }
        let pixelBuffer = prepared.pixelBuffer
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw CoreMLModelRuntimeError.pixelBufferConversionFailed
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        let array = try MLMultiArray(
            shape: [NSNumber(value: 1), NSNumber(value: 3), NSNumber(value: height), NSNumber(value: width)],
            dataType: .float32
        )
        let fptr = UnsafeMutablePointer<Float32>(OpaquePointer(array.dataPointer))
        let strideHW = height * width

        for y in 0..<height {
            let row = ptr.advanced(by: y * bytesPerRow)
            for x in 0..<width {
                let px = row.advanced(by: x * 4)
                let r = Float(px[2]) / 255.0
                let g = Float(px[1]) / 255.0
                let b = Float(px[0]) / 255.0
                let index = y * width + x
                fptr[index] = r
                fptr[strideHW + index] = g
                fptr[(2 * strideHW) + index] = b
            }
        }
        return PreparedImageTensor(tensor: array, transform: prepared.transform)
    }
}

private enum ImagePixelBufferBuilder {
    static func makePixelBuffer(from image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)
        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        return pixelBuffer
    }

    static func makePixelBufferLetterboxed(from image: UIImage, width: Int, height: Int) -> (pixelBuffer: CVPixelBuffer, transform: LetterboxTransform)? {
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }

        let sourceWidth = image.size.width > 0 ? image.size.width : CGFloat(width)
        let sourceHeight = image.size.height > 0 ? image.size.height : CGFloat(height)
        let transform = LetterboxTransform(
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            targetWidth: CGFloat(width),
            targetHeight: CGFloat(height)
        )

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)

        let drawRect = CGRect(
            x: transform.padX,
            y: transform.padY,
            width: sourceWidth * transform.scale,
            height: sourceHeight * transform.scale
        )
        UIGraphicsPushContext(context)
        image.draw(in: drawRect)
        UIGraphicsPopContext()
        return (pixelBuffer, transform)
    }
}

private enum PIDNetLabels {
    static let classes = [
        "road", "sidewalk", "building", "wall", "fence", "pole", "traffic_light",
        "traffic_sign", "vegetation", "terrain", "sky", "person", "rider", "car",
        "truck", "bus", "train", "motorcycle", "bicycle"
    ]
}

private enum YoloLabelMap {
    static let labels = [
        "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
        "traffic_light", "fire_hydrant", "stop_sign", "parking_meter", "bench", "bird", "cat", "dog",
        "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella", "handbag",
        "tie", "suitcase", "frisbee", "skis", "snowboard", "sports_ball", "kite", "baseball_bat",
        "baseball_glove", "skateboard", "surfboard", "tennis_racket", "bottle", "wine_glass", "cup", "fork",
        "knife", "spoon", "bowl", "banana", "apple", "sandwich", "orange", "broccoli", "carrot", "hot_dog",
        "pizza", "donut", "cake", "chair", "couch", "potted_plant", "bed", "dining_table", "toilet", "tv",
        "laptop", "mouse", "remote", "keyboard", "cell_phone", "microwave", "oven", "toaster", "sink",
        "refrigerator", "book", "clock", "vase", "scissors", "teddy_bear", "hair_drier", "toothbrush"
    ]
}
