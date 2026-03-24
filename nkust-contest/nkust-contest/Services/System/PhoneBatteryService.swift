import Foundation
import UIKit

@MainActor
final class PhoneBatteryService {
    static let shared = PhoneBatteryService()

    private var isMonitoring = false
    private var levelObserver: NSObjectProtocol?
    private var stateObserver: NSObjectProtocol?

    private init() {}

    func start(appState: AppState) {
        guard !isMonitoring else {
            refresh(appState: appState)
            return
        }
        isMonitoring = true
        UIDevice.current.isBatteryMonitoringEnabled = true

        levelObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak appState] _ in
            guard let self, let appState else { return }
            Task { @MainActor in
                self.refresh(appState: appState)
            }
        }

        stateObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak appState] _ in
            guard let self, let appState else { return }
            Task { @MainActor in
                self.refresh(appState: appState)
            }
        }

        refresh(appState: appState)
    }

    private func refresh(appState: AppState) {
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else { return }
        let percent = Int((level * 100).rounded())
        appState.phoneBattery = min(max(percent, 0), 100)
    }
}
