import Foundation
import SwiftData

enum AppSettingsPersistence {
    private static let singletonKey = "app_settings_singleton"

    @MainActor
    static func loadOrCreateSettings(in context: ModelContext) throws -> PersistedAppSettings {
        var desc = FetchDescriptor<PersistedAppSettings>(
            predicate: #Predicate<PersistedAppSettings> { $0.singletonId == "app_settings_singleton" }
        )
        desc.fetchLimit = 1
        if let existing = try context.fetch(desc).first {
            return existing
        }
        let created = PersistedAppSettings(singletonId: singletonKey)
        context.insert(created)
        try context.save()
        return created
    }

    @MainActor
    static func apply(settings: PersistedAppSettings, to appState: AppState) {
        appState.dataSourceMode = DataSourceMode(rawValue: settings.dataSourceModeRaw) ?? .mock
        appState.mockDeviceConnected = settings.mockDeviceConnected
        appState.showCharts = settings.showCharts
        appState.isDarkMode = settings.isDarkMode
        appState.preferredChartStyle = ChartStyle(rawValue: settings.preferredChartStyleRaw) ?? .bar
        appState.caregiverName = settings.caregiverName
        appState.caregiverRelationship = settings.caregiverRelationship
        appState.caregiverEmergencyPhone = settings.caregiverEmergencyPhone
    }

    @MainActor
    static func save(from appState: AppState, context: ModelContext) throws {
        let settings = try loadOrCreateSettings(in: context)
        settings.dataSourceModeRaw = appState.dataSourceMode.rawValue
        settings.mockDeviceConnected = appState.mockDeviceConnected
        settings.showCharts = appState.showCharts
        settings.isDarkMode = appState.isDarkMode
        settings.preferredChartStyleRaw = appState.preferredChartStyle.rawValue
        settings.caregiverName = appState.caregiverName
        settings.caregiverRelationship = appState.caregiverRelationship
        settings.caregiverEmergencyPhone = appState.caregiverEmergencyPhone
        try context.save()
    }
}
