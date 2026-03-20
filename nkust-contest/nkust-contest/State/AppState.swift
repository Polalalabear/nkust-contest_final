import SwiftUI
import Observation
import CoreLocation

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

    var caregiverName: String = "王小明"
    var caregiverRelationship: String = "子女"
    var caregiverEmergencyPhone: String = "0912-345-678"

    var visUserLatitude: Double = 22.6273
    var visUserLongitude: Double = 120.3014

    // Preferences
    var showCharts: Bool = true
    var preferredChartStyle: ChartStyle = .bar
    var isDarkMode: Bool = false

    static let appVersion = "1.3.0"
    static let buildDate = "2026.03.19"
}
