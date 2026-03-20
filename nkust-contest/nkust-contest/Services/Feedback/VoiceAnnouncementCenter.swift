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
    private let delegateProxy = VoiceSynthDelegateProxy()
    private var activePriority: VoicePriority?
    private var pendingCompletions: [ObjectIdentifier: CheckedContinuation<Void, Never>] = [:]

    private init() {
        delegateProxy.onUtteranceFinished = { [weak self] utterance in
            Task { @MainActor [weak self] in
                self?.resolveCompletion(for: utterance)
            }
        }
        synthesizer.delegate = delegateProxy
    }

    func speak(_ text: String, priority: VoicePriority, interruptLowerPriority: Bool = true) {
        guard !text.isEmpty else { return }

        if !canSpeak(for: priority, interruptLowerPriority: interruptLowerPriority) {
            return
        }

        if synthesizer.isSpeaking, interruptLowerPriority {
            synthesizer.stopSpeaking(at: .immediate)
        }

        activePriority = priority
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synthesizer.speak(utterance)
    }

    func speakAndWait(_ text: String, priority: VoicePriority, interruptLowerPriority: Bool = true) async -> Bool {
        guard !text.isEmpty else { return false }
        guard canSpeak(for: priority, interruptLowerPriority: interruptLowerPriority) else { return false }

        if synthesizer.isSpeaking, interruptLowerPriority {
            synthesizer.stopSpeaking(at: .immediate)
        }

        activePriority = priority
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            pendingCompletions[ObjectIdentifier(utterance)] = continuation
            synthesizer.speak(utterance)
        }

        return true
    }

    private func canSpeak(for priority: VoicePriority, interruptLowerPriority: Bool) -> Bool {
        if synthesizer.isSpeaking {
            if let activePriority, activePriority.rawValue > priority.rawValue {
                return false
            }
            if !interruptLowerPriority {
                return false
            }
        }
        return true
    }

    private func resolveCompletion(for utterance: AVSpeechUtterance) {
        activePriority = nil
        let key = ObjectIdentifier(utterance)
        if let continuation = pendingCompletions.removeValue(forKey: key) {
            continuation.resume()
        }
    }

    func stopAll() {
        synthesizer.stopSpeaking(at: .immediate)
        activePriority = nil
    }
}

private final class VoiceSynthDelegateProxy: NSObject, AVSpeechSynthesizerDelegate {
    var onUtteranceFinished: ((AVSpeechUtterance) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        _ = synthesizer
        onUtteranceFinished?(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        _ = synthesizer
        onUtteranceFinished?(utterance)
    }
}
