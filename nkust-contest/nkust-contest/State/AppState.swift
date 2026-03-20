import SwiftUI
import Observation
import CoreLocation

@Observable
final class AppState {
    var userRole: UserRole?
    var currentMode: AppMode = .walkMode
    var isVoiceEnabled: Bool = true
    var isMuted: Bool = false

    /// 測試資料模式：是否模擬「裝置已連線」（僅 `dataSourceMode == .mock` 時生效）
    var mockDeviceConnected: Bool = true

    /// 真實資料模式：Firestore `dashboard/caregiver_primary` 最新快照（nil = 尚未取得或監聽停止）
    var liveFirestoreSnapshot: FirestoreDashboardSnapshot?

    var dataSourceMode: DataSourceMode = .mock

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

    static let appVersion = "1.4.0"
    static let buildDate = "2026.03.19"

    // MARK: - 照護者主控台：裝置連線狀態（統一給 Dashboard / 個人資訊）

    /// 全 app 共用：依資料來源判斷「有效裝置連線狀態」（視障者/照護者皆可用）
    var effectiveDeviceConnected: Bool {
        switch dataSourceMode {
        case .mock:
            return mockDeviceConnected
        case .live:
            return liveFirestoreSnapshot?.connected == true
        }
    }

    /// 主控台顯示用：已連線 / 尚未連線
    var caregiverDeviceShowsConnected: Bool {
        effectiveDeviceConnected
    }
}
