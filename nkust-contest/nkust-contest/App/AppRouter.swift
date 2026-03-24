import SwiftData
import SwiftUI

@MainActor
struct AppRouter: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var showMainFlow = false
    @State private var streamHealthCoordinator = StreamHealthCoordinator()

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
                            onStart: {
                                if appState.effectiveDeviceConnected {
                                    showMainFlow = true
                                }
                            }
                        )
                    }
                case .caregiver:
                    DashboardView(onBack: { appState.userRole = nil })
                }
            } else {
                ChooseUserView(isVoiceEnabled: $state.isVoiceEnabled)
            }
        }
        .animation(.easeInOut, value: appState.userRole)
        .animation(.easeInOut, value: showMainFlow)
        .onChange(of: appState.effectiveDeviceConnected) { _, connected in
            if !connected {
                showMainFlow = false
            }
        }
        .onAppear {
            streamHealthCoordinator.onStateChange = { state in
                appState.liveStreamHealthState = state
            }
            syncLiveMonitoring()
        }
        .onChange(of: appState.userRole) { _, _ in
            syncLiveMonitoring()
        }
        .onChange(of: appState.dataSourceMode) { _, _ in
            syncLiveMonitoring()
        }
        .onChange(of: showMainFlow) { _, _ in
            syncLiveMonitoring()
        }
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

    private func syncLiveMonitoring() {
        let shouldMonitor = appState.userRole == .visuallyImpaired && appState.dataSourceMode == .live
        if shouldMonitor {
            streamHealthCoordinator.startMonitoring()
        } else {
            streamHealthCoordinator.stopMonitoring()
            appState.liveStreamHealthState = .disconnected
        }
    }
}

@MainActor
private struct AppRouterPreviewHost: View {
    var body: some View {
        AppRouter()
            .environment(AppState())
            .modelContainer(
                for: [PersistedAppSettings.self, PersistedHealthDayRecordEntity.self],
                inMemory: false
            )
    }
}

#Preview {
    AppRouterPreviewHost()
}
