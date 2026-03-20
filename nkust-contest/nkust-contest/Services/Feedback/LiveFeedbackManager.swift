import AVFoundation
import Foundation
import UIKit

/// 實際語音（AVSpeechSynthesizer）+ 觸覺回饋（UIKit Haptics）。
/// CoreHaptics 進階節奏可後續取代短震動組合 — 見 TODO。
@MainActor
final class LiveFeedbackManager: FeedbackManager {
    private let synthesizer = AVSpeechSynthesizer()
    private let notificationGen = UINotificationFeedbackGenerator()
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)

    private var isMuted = false
    private var lastSpokenText: String = ""

    init() {
        notificationGen.prepare()
        lightImpact.prepare()
        heavyImpact.prepare()
    }

    func deliverNavigationFeedback(_ result: DecisionResult, context: DecisionContext, voiceEnabled: Bool) {
        let text = Self.spokenPhrase(for: result.action, context: context)
        lastSpokenText = text

        switch result.action {
        case .stop:
            hapticStop()
        case .moveLeft:
            hapticMoveLeft()
        case .moveRight:
            hapticMoveRight()
        case .safe:
            break
        }

        let shouldSpeak = voiceEnabled && !isMuted && !text.isEmpty
        if shouldSpeak {
            speak(text)
        }
    }

    func replayLastInstruction() {
        guard !isMuted, !lastSpokenText.isEmpty else { return }
        speak(lastSpokenText)
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        if muted {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    func triggerSOS() {
        heavyImpact.impactOccurred(intensity: 1.0)
        notificationGen.notificationOccurred(.error)
        if !isMuted {
            speak("緊急求助，已通知照護者")
        }
    }

    // MARK: - Phrases

    private static func spokenPhrase(for action: NavigationAction, context: DecisionContext) -> String {
        switch action {
        case .stop:
            if context.trafficLightRed {
                return "紅燈，請在原地停留"
            }
            if context.obstacleDetected {
                return "前方約 \(context.obstacleDistanceMeters) 公尺有障礙，請停止"
            }
            return "請停止"
        case .moveLeft:
            return "請向左修正路徑"
        case .moveRight:
            return "請向右修正路徑"
        case .safe:
            return ""
        }
    }

    // MARK: - Speech

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synthesizer.speak(utterance)
    }

    // MARK: - Haptics（對應 PRD：強震動／短-短／短-長）

    private func hapticStop() {
        notificationGen.notificationOccurred(.error)
        heavyImpact.impactOccurred(intensity: 1.0)
        // TODO: 改為 CoreHaptics 自訂「強烈持續」pattern 以更精準對齊 PRD
    }

    private func hapticMoveLeft() {
        lightImpact.impactOccurred(intensity: 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.lightImpact.impactOccurred(intensity: 0.9)
        }
    }

    private func hapticMoveRight() {
        lightImpact.impactOccurred(intensity: 0.85)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            self?.heavyImpact.impactOccurred(intensity: 0.95)
        }
    }
}
