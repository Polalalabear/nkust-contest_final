import Foundation
import SwiftData

enum AppSettingsPersistence {
    private static let singletonKey = "app_settings_singleton"
    @MainActor private static var pendingSaveTask: Task<Void, Never>?

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
        appState.visUserPhone = settings.visUserPhone ?? "0912-000-000"
        appState.blackScreenTestEnabled = settings.blackScreenTestEnabled ?? false
        let persistedVoiceInterval = settings.voiceAlertIntervalSeconds ?? 2
        appState.voiceAlertIntervalSeconds = min(max(1, persistedVoiceInterval), 5)
        let persistedDistance = settings.modelAlertDistanceMeters ?? 10
        appState.modelAlertDistanceMeters = min(max(2, persistedDistance), 15)
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
        settings.visUserPhone = appState.visUserPhone
        settings.blackScreenTestEnabled = appState.blackScreenTestEnabled
        settings.voiceAlertIntervalSeconds = appState.voiceAlertIntervalSeconds
        settings.modelAlertDistanceMeters = appState.modelAlertDistanceMeters
        try context.save()
    }

    /// Debounced save to reduce SwiftData sync pressure on main thread.
    @MainActor
    static func scheduleSave(
        from appState: AppState,
        context: ModelContext,
        debounceNs: UInt64 = 350_000_000
    ) {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: debounceNs)
            guard !Task.isCancelled else { return }
            try? save(from: appState, context: context)
        }
    }

    @MainActor
    static func cancelScheduledSave() {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
    }
}
