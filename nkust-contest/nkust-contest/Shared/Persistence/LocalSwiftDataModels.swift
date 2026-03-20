import Foundation
import SwiftData

// MARK: - 單例設定列（固定 id 方便 fetch）

@Model
final class PersistedAppSettings {
    /// 固定主鍵，全 app 僅一筆
    @Attribute(.unique) var singletonId: String
    var dataSourceModeRaw: String
    var mockDeviceConnected: Bool
    var showCharts: Bool
    var isDarkMode: Bool
    var preferredChartStyleRaw: String
    var caregiverName: String
    var caregiverRelationship: String
    var caregiverEmergencyPhone: String

    init(
        singletonId: String = "app_settings_singleton",
        dataSourceModeRaw: String = DataSourceMode.mock.rawValue,
        mockDeviceConnected: Bool = true,
        showCharts: Bool = true,
        isDarkMode: Bool = false,
        preferredChartStyleRaw: String = ChartStyle.bar.rawValue,
        caregiverName: String = "王小明",
        caregiverRelationship: String = "子女",
        caregiverEmergencyPhone: String = "0912-345-678"
    ) {
        self.singletonId = singletonId
        self.dataSourceModeRaw = dataSourceModeRaw
        self.mockDeviceConnected = mockDeviceConnected
        self.showCharts = showCharts
        self.isDarkMode = isDarkMode
        self.preferredChartStyleRaw = preferredChartStyleRaw
        self.caregiverName = caregiverName
        self.caregiverRelationship = caregiverRelationship
        self.caregiverEmergencyPhone = caregiverEmergencyPhone
    }
}

// MARK: - 每日健康紀錄（本地快取／真實模式寫入）

@Model
final class PersistedHealthDayRecordEntity {
    /// 當日 00:00（以 Calendar 對齊）
    @Attribute(.unique) var dayStart: Date
    var steps: Int
    var distanceKm: Double
    var standingMinutes: Int

    init(dayStart: Date, steps: Int, distanceKm: Double, standingMinutes: Int) {
        self.dayStart = dayStart
        self.steps = steps
        self.distanceKm = distanceKm
        self.standingMinutes = standingMinutes
    }
}
