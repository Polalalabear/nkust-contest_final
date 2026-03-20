import AVFoundation
import Foundation

enum VoicePriority: Int {
    case low = 10
    case navigation = 30
    case connectionAlert = 60
    case sos = 100
}

@MainActor
final class VoiceAnnouncementCenter {
    static let shared = VoiceAnnouncementCenter()

    private let synthesizer = AVSpeechSynthesizer()
    private var activePriority: VoicePriority?

    private init() {}

    func speak(_ text: String, priority: VoicePriority, interruptLowerPriority: Bool = true) {
        guard !text.isEmpty else { return }

        if synthesizer.isSpeaking {
            if let activePriority, activePriority.rawValue > priority.rawValue {
                return
            }
            if interruptLowerPriority {
                synthesizer.stopSpeaking(at: .immediate)
            } else {
                return
            }
        }

        activePriority = priority
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synthesizer.speak(utterance)
    }

    func stopAll() {
        synthesizer.stopSpeaking(at: .immediate)
        activePriority = nil
    }
}
