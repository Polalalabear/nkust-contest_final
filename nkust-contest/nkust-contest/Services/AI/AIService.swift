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
    private let debug = AIInferenceDebugConfig.shared
    private lazy var yoloRunner = try? YOLORunner()
    private lazy var midasRunner = try? MiDaSRunner()
    private lazy var pidNetRunner = try? PIDNetRunner()
    private let fusion = FusionAggregator()

    func process(frame: UIImage) async throws -> LocalResult {
        let detections = await runYOLO(frame: frame)
        let depth = await runMiDaS(frame: frame, detections: detections)
        let segmentation = await runPIDNet(frame: frame)
        let fused = fusion.fuse(detections: detections, depth: depth, segmentation: segmentation)
        let center = fused.primaryObject.map { CGPoint(x: $0.bbox.midX, y: $0.bbox.midY) }
        let trafficRed = fused.primaryObject?.label.contains("red_light") == true

        if debug.enabled {
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
        guard let runner = yoloRunner else {
            await reportNonCritical(title: "YOLO 初始化失敗", details: "模型 runner 無法建立，使用 fallback。")
            return []
        }
        do {
            return try await runner.predict(frame: frame)
        } catch {
            await reportNonCritical(title: "YOLO 推論失敗", details: error.localizedDescription)
            return []
        }
    }

    private func runMiDaS(frame: UIImage, detections: [DetectedObject]) async -> DepthResult? {
        guard let runner = midasRunner else {
            await reportNonCritical(title: "MiDaS 初始化失敗", details: "模型 runner 無法建立，使用 fallback。")
            return nil
        }
        do {
            return try runner.predict(frame: frame, detections: detections)
        } catch {
            await reportNonCritical(title: "MiDaS 推論失敗", details: error.localizedDescription)
            return nil
        }
    }

    private func runPIDNet(frame: UIImage) async -> SegmentationResult? {
        guard let runner = pidNetRunner else {
            await reportNonCritical(title: "PIDNet 初始化失敗", details: "模型 runner 無法建立，使用 fallback。")
            return nil
        }
        do {
            return try runner.predict(frame: frame)
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
    static let shared = AIInferenceDebugConfig()
    let enabled: Bool

    init() {
        enabled = UserDefaults.standard.object(forKey: "ai.debug.logs.enabled") as? Bool ?? true
    }
}

private final class CoreMLPackageLoader {
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
        guard AIInferenceDebugConfig.shared.enabled else { return }
        for (name, desc) in model.modelDescription.inputDescriptionsByName {
            print("[AIFusion][ModelSpec] \(modelName) input \(name) type=\(desc.type.rawValue)")
        }
        for (name, desc) in model.modelDescription.outputDescriptionsByName {
            print("[AIFusion][ModelSpec] \(modelName) output \(name) type=\(desc.type.rawValue)")
        }
    }
}

private final class YOLORunner {
    private let loader = CoreMLPackageLoader()
    private var visionModel: VNCoreMLModel?

    func predict(frame: UIImage) async throws -> [DetectedObject] {
        let model = try loader.loadModel(named: "yolo26n")
        let vnModel: VNCoreMLModel
        if let visionModel {
            vnModel = visionModel
        } else {
            let loaded = try VNCoreMLModel(for: model)
            visionModel = loaded
            vnModel = loaded
        }
        let cgImage = try imageToCGImage(frame)
        let raw = try await runVision(cgImage: cgImage, model: vnModel)
        let labels = YoloLabelMap.labels
        return raw.compactMap { item in
            guard item.confidence >= 0.35 else { return nil }
            let classIndex = max(0, min(labels.count - 1, Int(item.classID)))
            let label = labels.indices.contains(classIndex) ? labels[classIndex] : "class_\(Int(item.classID))"
            let normalized = normalizeBox(item.x1, item.y1, item.x2, item.y2)
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
            request.imageCropAndScaleOption = .scaleFill
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

    private func normalizeBox(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> CGRect {
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
        return CGRect(x: minX, y: minY, width: width, height: height)
    }
}

private final class MiDaSRunner {
    private let loader = CoreMLPackageLoader()

    func predict(frame: UIImage, detections: [DetectedObject]) throws -> DepthResult {
        let model = try loader.loadModel(named: "midas_v21_small_256")
        let inputFeatureName = model.modelDescription.inputDescriptionsByName.keys.first ?? "image"
        let outputFeatureName = model.modelDescription.outputDescriptionsByName.keys.first ?? "var_587"
        let input = try ImageTensorBuilder.makeNormalizedCHW(from: frame, width: 256, height: 256)
        let output = try model.prediction(from: try MLDictionaryFeatureProvider(dictionary: [inputFeatureName: input]))
        guard let depthMap = output.featureValue(for: outputFeatureName)?.multiArrayValue else {
            throw CoreMLModelRuntimeError.featureTypeMismatch(model: "MiDaS", feature: outputFeatureName, expected: "MLMultiArray")
        }
        let all = MultiArrayReader.allValues(of: depthMap)
        guard let minDepth = all.min(), let maxDepth = all.max(), maxDepth > minDepth else {
            return DepthResult(roiDepth: nil, normalizedDistance: nil, minDepth: 0, maxDepth: 0)
        }

        let primaryROI = detections.max(by: { $0.confidence < $1.confidence })?.bbox
        let roiDepth = primaryROI.flatMap { roi in
            let sampled = MultiArrayReader.sampleDepth(in: depthMap, normalizedROI: roi)
            return sampled.isEmpty ? nil : sampled.reduce(0, +) / Double(sampled.count)
        }

        let normalizedDistance: Double? = roiDepth.map { depth in
            // MiDaS is inverse-depth like; smaller value usually farther.
            let normalizedDepth = (depth - minDepth) / (maxDepth - minDepth)
            return max(0, min(1, 1 - normalizedDepth))
        }

        return DepthResult(roiDepth: roiDepth, normalizedDistance: normalizedDistance, minDepth: minDepth, maxDepth: maxDepth)
    }
}

private final class PIDNetRunner {
    private let loader = CoreMLPackageLoader()

    func predict(frame: UIImage) throws -> SegmentationResult {
        let model = try loader.loadModel(named: "PIDNet_S_Cityscapes_val")
        let inputFeatureName = model.modelDescription.inputDescriptionsByName.keys.first ?? "image"
        let outputFeatureName = model.modelDescription.outputDescriptionsByName.keys.first ?? "var_420"
        let input = try ImageTensorBuilder.makeNormalizedCHW(from: frame, width: 2048, height: 1024)
        let output = try model.prediction(from: try MLDictionaryFeatureProvider(dictionary: [inputFeatureName: input]))
        guard let logits = output.featureValue(for: outputFeatureName)?.multiArrayValue else {
            throw CoreMLModelRuntimeError.featureTypeMismatch(model: "PIDNet", feature: outputFeatureName, expected: "MLMultiArray")
        }
        let histogram = MultiArrayReader.semanticHistogram(from: logits, classLabels: PIDNetLabels.classes)
        let dominant = histogram.max(by: { $0.value < $1.value })?.key ?? "unknown"
        let walkable = (histogram["road"] ?? 0) + (histogram["sidewalk"] ?? 0)
        return SegmentationResult(dominantClass: dominant, walkableRatio: walkable, classHistogram: histogram)
    }
}

private struct FusionAggregator {
    func fuse(
        detections: [DetectedObject],
        depth: DepthResult?,
        segmentation: SegmentationResult?
    ) -> FusionDecision {
        let primary = detections.max(by: { $0.confidence < $1.confidence })
        let walkableRatio = segmentation?.walkableRatio ?? 0.5
        let isWalkable = walkableRatio >= 0.45

        let distance: Int? = depth?.normalizedDistance.map { normalized in
            // 0...1 to 0.8m...12m
            let meters = 0.8 + (normalized * 11.2)
            return Int(max(1, min(12, round(meters))))
        } ?? fallbackDistance(from: primary?.bbox)

        let command: NavigationAction
        if primary == nil {
            command = .safe
        } else if !isWalkable {
            command = .stop
        } else if let distance, distance <= 2 {
            command = .stop
        } else if let distance, distance <= 5 {
            command = .moveLeft
        } else if let distance, distance <= 12 {
            command = .moveRight
        } else {
            command = .safe
        }

        let summary: String
        if let primary {
            let distanceText = distance.map { "\($0) 公尺" } ?? "未知距離"
            let segText = segmentation?.dominantClass ?? "語意未知"
            let walkText = isWalkable ? "可通行" : "有障礙風險"
            summary = "前方\(primary.label)約 \(distanceText)，\(segText)，\(walkText)"
        } else {
            summary = "模型正在校準/無有效偵測"
        }

        return FusionDecision(
            primaryObject: primary,
            distanceMeters: distance,
            isWalkable: isWalkable,
            command: command,
            summary: summary
        )
    }

    private func fallbackDistance(from bbox: CGRect?) -> Int? {
        guard let bbox else { return nil }
        let area = bbox.width * bbox.height
        if area >= 0.35 { return 1 }
        if area >= 0.20 { return 3 }
        if area >= 0.10 { return 6 }
        return 10
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

    static func semanticHistogram(from logits: MLMultiArray, classLabels: [String]) -> [String: Double] {
        let shape = logits.shape.map(\.intValue)
        guard shape.count == 4 else { return [:] } // [1, C, H, W]
        let classes = shape[1]
        let height = shape[2]
        let width = shape[3]
        let values = allValues(of: logits)
        var counts = Array(repeating: 0, count: classes)
        let pixels = height * width

        for p in 0..<pixels {
            var bestClass = 0
            var bestValue = -Double.greatestFiniteMagnitude
            for c in 0..<classes {
                let index = c * pixels + p
                guard values.indices.contains(index) else { continue }
                let v = values[index]
                if v > bestValue {
                    bestValue = v
                    bestClass = c
                }
            }
            counts[bestClass] += 1
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
    static func makeNormalizedCHW(from image: UIImage, width: Int, height: Int) throws -> MLMultiArray {
        guard let pixelBuffer = ImagePixelBufferBuilder.makePixelBuffer(from: image, width: width, height: height) else {
            throw CoreMLModelRuntimeError.pixelBufferConversionFailed
        }
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
        return array
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
