import Foundation

@MainActor
final class ConnectionStatusAnnouncer {
    static let shared = ConnectionStatusAnnouncer()

    private var screenConnection: [String: Bool] = [:]
    private var screenVoiceEnabled: [String: Bool] = [:]
    private var reminderTasks: [String: Task<Void, Never>] = [:]

    private init() {}

    func notifyIfDisconnected(screenID: String, isConnected: Bool, voiceEnabled: Bool) {
        let previousConnected = screenConnection[screenID]
        screenConnection[screenID] = isConnected
        screenVoiceEnabled[screenID] = voiceEnabled

        if previousConnected == nil, voiceEnabled {
            VoiceAnnouncementCenter.shared.speak(
                isConnected ? "裝置已連線" : "裝置目前尚未連線",
                priority: .connectionAlert,
                interruptLowerPriority: true,
                bypassThrottle: true
            )
        }

        let switchedToConnected = previousConnected == false && isConnected
        if switchedToConnected && voiceEnabled {
            VoiceAnnouncementCenter.shared.speak(
                "裝置已連線",
                priority: .connectionAlert,
                interruptLowerPriority: true,
                bypassThrottle: true
            )
        }
        refreshReminderLoop(for: screenID)
    }

    func stopReminders(screenID: String) {
        reminderTasks[screenID]?.cancel()
        reminderTasks[screenID] = nil
        screenConnection.removeValue(forKey: screenID)
        screenVoiceEnabled.removeValue(forKey: screenID)
    }

    private func refreshReminderLoop(for screenID: String) {
        let connected = screenConnection[screenID] ?? true
        let voiceEnabled = screenVoiceEnabled[screenID] ?? false

        guard !connected, voiceEnabled else {
            reminderTasks[screenID]?.cancel()
            reminderTasks[screenID] = nil
            return
        }

        guard reminderTasks[screenID] == nil else { return }
        reminderTasks[screenID] = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard (self.screenConnection[screenID] == false) && (self.screenVoiceEnabled[screenID] == true) else {
                    break
                }

                let spoken = await VoiceAnnouncementCenter.shared.speakAndWait(
                    "裝置目前尚未連線，請檢查 Wi-Fi 連線狀態",
                    priority: .connectionAlert,
                    interruptLowerPriority: true
                )

                if !spoken {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                }

                // 需求：語音結束後開始計時，每 5 秒再提醒。
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
            self.reminderTasks[screenID] = nil
        }
    }
}
