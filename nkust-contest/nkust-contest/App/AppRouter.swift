import SwiftData
import SwiftUI

struct AppRouter: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var showMainFlow = false

    var body: some View {
        @Bindable var state = appState
        Group {
            if let role = appState.userRole {
                switch role {
                case .visuallyImpaired:
                    if showMainFlow {
                        MainTabView(onBack: {
                            showMainFlow = false
                        })
                    } else {
                        DeviceInfoView(
                            isVoiceEnabled: $state.isVoiceEnabled,
                            onBack: { appState.userRole = nil },
                            onStart: { showMainFlow = true }
                        )
                    }
                case .caregiver:
                    DashboardView()
                }
            } else {
                ChooseUserView(isVoiceEnabled: $state.isVoiceEnabled)
            }
        }
        .animation(.easeInOut, value: appState.userRole)
        .animation(.easeInOut, value: showMainFlow)
        .task {
            await bootstrapPersistence()
        }
    }

    @MainActor
    private func bootstrapPersistence() async {
        do {
            try HealthRecordsPersistence.seedIfEmpty(in: modelContext)
            let settings = try AppSettingsPersistence.loadOrCreateSettings(in: modelContext)
            AppSettingsPersistence.apply(settings: settings, to: appState)
        } catch {
            // 首次啟動或容器異常時仍允許進入 app
        }
    }
}

#Preview {
    AppRouter()
        .environment(AppState())
        .modelContainer(
            for: [PersistedAppSettings.self, PersistedHealthDayRecordEntity.self],
            inMemory: false
        )
}
