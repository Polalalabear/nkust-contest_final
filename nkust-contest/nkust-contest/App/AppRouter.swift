import SwiftData
import SwiftUI

@MainActor
struct AppRouter: View {
    @Environment(AppState.self) private var appState
    @State private var showMainFlow = false
    @State private var streamHealthCoordinator: StreamHealthCoordinator?
    @State private var isBootstrapping = true
    @State private var didBootstrap = false
    @State private var didApplyBootstrappedSettings = false
    @State private var pendingMonitorTask: Task<Void, Never>?

    var body: some View {
        @Bindable var state = appState
        ZStack {
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
                                },
                                onReconnect: {
                                    streamHealthCoordinator?.forceReconnect()
                                }
                            )
                        }
                    case .caregiver:
                        CaregiverRootContainer(onBack: { appState.userRole = nil })
                    }
                } else {
                    ChooseUserView(isVoiceEnabled: $state.isVoiceEnabled)
                }
            }

            if isBootstrapping {
                launchOverlay
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
            StartupTrace.log("AppStartup", "AppRouter onAppear")
            ensureCoordinator()
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
        .onDisappear {
            pendingMonitorTask?.cancel()
            pendingMonitorTask = nil
        }
        .task {
            if !didBootstrap {
                didBootstrap = true
                startBootstrapFlow()
            }
        }
    }

    /// Deferred creation of StreamHealthCoordinator — avoids MJPEGStreamService
    /// allocation (DispatchQueue + NSObject + Data buffer) during view init,
    /// keeping the first-frame render path allocation-free.
    private func ensureCoordinator() {
        guard streamHealthCoordinator == nil else { return }
        StartupTrace.log("AppStartup", "StreamHealthCoordinator deferred init begin")
        let coordinator = StreamHealthCoordinator()
        coordinator.onStateChange = { [weak appState] state in
            appState?.liveStreamHealthState = state
        }
        streamHealthCoordinator = coordinator
        StartupTrace.log("AppStartup", "StreamHealthCoordinator deferred init end")
    }

    private func startBootstrapFlow() {
        StartupTrace.log("AppStartup", "start bootstrap")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if isBootstrapping {
                didApplyBootstrappedSettings = true
                isBootstrapping = false
                StartupTrace.log("AppStartup", "launch overlay dismissed by timeout")
                syncLiveMonitoring()
            }
        }
    }

    private func syncLiveMonitoring() {
        let shouldMonitor = canStartLiveMonitoring
        StartupTrace.log(
            "ConnectionState",
            "syncLiveMonitoring shouldMonitor=\(shouldMonitor) role=\(String(describing: appState.userRole)) mode=\(appState.dataSourceMode.rawValue) showMainFlow=\(showMainFlow) bootstrapping=\(isBootstrapping)"
        )
        if shouldMonitor {
            pendingMonitorTask?.cancel()
            pendingMonitorTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard canStartLiveMonitoring else { return }
                streamHealthCoordinator?.startMonitoring()
            }
        } else {
            pendingMonitorTask?.cancel()
            pendingMonitorTask = nil

            let enteringMainFlow = showMainFlow
                && appState.userRole == .visuallyImpaired
                && appState.dataSourceMode == .live

            streamHealthCoordinator?.stopMonitoring(preserveHealthState: enteringMainFlow)

            if !enteringMainFlow {
                if appState.dataSourceMode != .live || appState.userRole != .visuallyImpaired {
                    appState.liveStreamHealthState = .disconnected
                }
            }
        }
    }

    private var canStartLiveMonitoring: Bool {
        appState.userRole == .visuallyImpaired
            && appState.dataSourceMode == .live
            && !showMainFlow
            && didApplyBootstrappedSettings
            && !isBootstrapping
    }

    private var launchOverlay: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("啟動中...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .transition(.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("啟動中")
    }
}

@MainActor
private struct CaregiverRootContainer: View {
    let onBack: () -> Void

    var body: some View {
        CaregiverDashboardHost(onBack: onBack)
            .modelContainer(
                for: [PersistedAppSettings.self, PersistedHealthDayRecordEntity.self],
                inMemory: false
            )
    }
}

@MainActor
private struct CaregiverDashboardHost: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    let onBack: () -> Void
    @State private var didLoadPersistedSettings = false

    var body: some View {
        DashboardView(onBack: onBack)
            .task {
                if !didLoadPersistedSettings {
                    didLoadPersistedSettings = true
                    await loadPersistedSettings()
                }
            }
    }

    private func loadPersistedSettings() async {
        StartupTrace.log("AppStartup", "caregiver persistence load begin")
        // Keep first interaction smooth before touching SwiftData.
        try? await Task.sleep(nanoseconds: 250_000_000)
        do {
            let settings = try AppSettingsPersistence.loadOrCreateSettings(in: modelContext)
            AppSettingsPersistence.apply(settings: settings, to: appState)
            StartupTrace.log("AppStartup", "caregiver persistence load end")
        } catch {
            StartupTrace.log("AppStartup", "caregiver persistence load failed")
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
