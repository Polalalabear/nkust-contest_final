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
    private var lastSpokenText: String = ""
    private var lastSpokenPriority: VoicePriority = .navigation
    private var alertIntervalSeconds: TimeInterval = 2
    private var lastSpokenAtByPriority: [VoicePriority: Date] = [:]

    private init() {
        delegateProxy.onUtteranceFinished = { [weak self] utterance in
            Task { @MainActor [weak self] in
                self?.resolveCompletion(for: utterance)
            }
        }
        synthesizer.delegate = delegateProxy
    }

    func speak(
        _ text: String,
        priority: VoicePriority,
        interruptLowerPriority: Bool = true,
        bypassThrottle: Bool = false
    ) {
        guard !text.isEmpty else { return }
        guard bypassThrottle || !isThrottled(priority: priority) else { return }

        if !canSpeak(for: priority, interruptLowerPriority: interruptLowerPriority) {
            return
        }

        if synthesizer.isSpeaking, interruptLowerPriority {
            synthesizer.stopSpeaking(at: .immediate)
        }

        lastSpokenText = text
        lastSpokenPriority = priority
        lastSpokenAtByPriority[priority] = Date()
        activePriority = priority
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synthesizer.speak(utterance)
    }

    func speakAndWait(
        _ text: String,
        priority: VoicePriority,
        interruptLowerPriority: Bool = true,
        bypassThrottle: Bool = false
    ) async -> Bool {
        guard !text.isEmpty else { return false }
        guard bypassThrottle || !isThrottled(priority: priority) else { return false }
        guard canSpeak(for: priority, interruptLowerPriority: interruptLowerPriority) else { return false }

        if synthesizer.isSpeaking, interruptLowerPriority {
            synthesizer.stopSpeaking(at: .immediate)
        }

        lastSpokenText = text
        lastSpokenPriority = priority
        lastSpokenAtByPriority[priority] = Date()
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

    func replayLastSpoken(interruptLowerPriority: Bool = true) {
        guard !lastSpokenText.isEmpty else { return }
        speak(
            lastSpokenText,
            priority: lastSpokenPriority,
            interruptLowerPriority: interruptLowerPriority,
            bypassThrottle: true
        )
    }

    func setAlertInterval(seconds: Int) {
        alertIntervalSeconds = TimeInterval(min(max(1, seconds), 5))
    }

    func announceVoiceToggle(isEnabled: Bool) {
        speak(
            isEnabled ? "語音已開啟" : "語音已關閉",
            priority: .connectionAlert,
            interruptLowerPriority: true,
            bypassThrottle: true
        )
    }

    private func isThrottled(priority: VoicePriority) -> Bool {
        guard priority == .navigation || priority == .connectionAlert else { return false }
        guard let lastAt = lastSpokenAtByPriority[priority] else { return false }
        return Date().timeIntervalSince(lastAt) < alertIntervalSeconds
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
