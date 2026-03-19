import Foundation

protocol RecognitionModeServicing {
    func recognizeCurrentFrame() async -> String
}

final class StubRecognitionModeService: RecognitionModeServicing {
    func recognizeCurrentFrame() async -> String {
        // TODO: connect camera frame and AI pipeline
        return ""
    }
}
