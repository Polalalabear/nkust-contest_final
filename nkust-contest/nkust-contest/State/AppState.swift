import SwiftUI
import Observation

@Observable
final class AppState {
    var userRole: UserRole?
    var currentMode: AppMode = .walkMode
    var isVoiceEnabled: Bool = true
    var isMuted: Bool = false

    var deviceConnected: Bool = true
    var deviceBattery: Int = 72
    var phoneBattery: Int = 93
    var isLocationSharing: Bool = true
}
