import AVFoundation
import Foundation

@MainActor
final class ConnectionStatusAnnouncer {
    static let shared = ConnectionStatusAnnouncer()

    private let synthesizer = AVSpeechSynthesizer()
    private var lastConnectionByScreen: [String: Bool] = [:]

    private init() {}

    func notifyIfDisconnected(screenID: String, isConnected: Bool, voiceEnabled: Bool) {
        defer { lastConnectionByScreen[screenID] = isConnected }
        guard voiceEnabled else { return }

        let previous = lastConnectionByScreen[screenID]
        let shouldAnnounce = !isConnected && (previous == nil || previous == true)
        guard shouldAnnounce else { return }

        let utterance = AVSpeechUtterance(string: "裝置目前尚未連線，請檢查 Wi-Fi 連線狀態")
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synthesizer.speak(utterance)
    }
}
