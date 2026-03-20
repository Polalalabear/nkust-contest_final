import AVFoundation
import CoreHaptics
import Foundation
import UIKit

/// 實際語音（AVSpeechSynthesizer）+ 觸覺回饋（CoreHaptics 自訂節奏）。
@MainActor
final class LiveFeedbackManager: FeedbackManager {
    private let synthesizer = AVSpeechSynthesizer()
    private let fallbackNotificationGen = UINotificationFeedbackGenerator()
    private let fallbackLightImpact = UIImpactFeedbackGenerator(style: .light)
    private let fallbackHeavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private var hapticEngine: CHHapticEngine?
    private var supportsHaptics = false

    private var isMuted = false
    private var lastSpokenText: String = ""

    init() {
        fallbackNotificationGen.prepare()
        fallbackLightImpact.prepare()
        fallbackHeavyImpact.prepare()
        configureHaptics()
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
        playSOSPattern()
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
        play(events: [
            hapticContinuous(start: 0.0, duration: 0.42, intensity: 1.0, sharpness: 0.62),
            hapticTransient(start: 0.02, intensity: 1.0, sharpness: 0.7)
        ]) {
            self.fallbackNotificationGen.notificationOccurred(.error)
            self.fallbackHeavyImpact.impactOccurred(intensity: 1.0)
        }
    }

    private func hapticMoveLeft() {
        play(events: [
            hapticTransient(start: 0.0, intensity: 0.8, sharpness: 0.4),
            hapticTransient(start: 0.13, intensity: 0.8, sharpness: 0.4)
        ]) {
            self.fallbackLightImpact.impactOccurred(intensity: 0.9)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                self?.fallbackLightImpact.impactOccurred(intensity: 0.9)
            }
        }
    }

    private func hapticMoveRight() {
        play(events: [
            hapticTransient(start: 0.0, intensity: 0.72, sharpness: 0.35),
            hapticTransient(start: 0.24, intensity: 0.95, sharpness: 0.62)
        ]) {
            self.fallbackLightImpact.impactOccurred(intensity: 0.85)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                self?.fallbackHeavyImpact.impactOccurred(intensity: 0.95)
            }
        }
    }

    private func playSOSPattern() {
        play(events: [
            hapticContinuous(start: 0.0, duration: 0.28, intensity: 1.0, sharpness: 0.6),
            hapticTransient(start: 0.34, intensity: 1.0, sharpness: 0.7),
            hapticTransient(start: 0.52, intensity: 1.0, sharpness: 0.7)
        ]) {
            self.fallbackHeavyImpact.impactOccurred(intensity: 1.0)
            self.fallbackNotificationGen.notificationOccurred(.error)
        }
    }

    private func configureHaptics() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        guard supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.isAutoShutdownEnabled = true
            try hapticEngine?.start()
        } catch {
            supportsHaptics = false
            hapticEngine = nil
        }
    }

    private func play(events: [CHHapticEvent], fallback: () -> Void) {
        guard supportsHaptics else {
            fallback()
            return
        }
        do {
            if hapticEngine == nil {
                configureHaptics()
            }
            guard let hapticEngine else {
                fallback()
                return
            }
            try? hapticEngine.start()
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            fallback()
        }
    }

    private func hapticTransient(start: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: start
        )
    }

    private func hapticContinuous(start: TimeInterval, duration: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: start,
            duration: duration
        )
    }
}
