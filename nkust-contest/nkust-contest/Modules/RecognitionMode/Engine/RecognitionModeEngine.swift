import Foundation

protocol RecognitionModeEngine {
    func shouldEscalateToHuman(confidence: Double) -> Bool
}

struct StubRecognitionModeEngine: RecognitionModeEngine {
    func shouldEscalateToHuman(confidence: Double) -> Bool {
        // TODO: implement real confidence threshold policy
        _ = confidence
        return false
    }
}
