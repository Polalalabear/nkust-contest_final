import Foundation

protocol FeedbackService {
    func speak(_ message: String)
    func vibrate(pattern: String)
}

final class MockFeedbackService: FeedbackService {
    func speak(_ message: String) {
        // TODO: integrate AVSpeechSynthesizer
        _ = message
    }

    func vibrate(pattern: String) {
        // TODO: integrate CoreHaptics
        _ = pattern
    }
}
