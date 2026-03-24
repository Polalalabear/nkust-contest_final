import SwiftData
import SwiftUI

@MainActor
struct AppRouter: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var showMainFlow = false
    @State private var streamHealthCoordinator = StreamHealthCoordinator()
    @State private var isBootstrapping = true
    @State private var hasBootstrapped = false

    var body: some View {
        @Bindable var state = appState
        ZStack {
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

            if isBootstrapping {
                LaunchLoadingView()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut, value: appState.userRole)
        .animation(.easeInOut, value: showMainFlow)
        .animation(.easeInOut(duration: 0.2), value: isBootstrapping)
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
            startBootstrapIfNeeded()
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
    }

    @MainActor
    private func bootstrapPersistence() async {
        print("[AppStartup] bootstrap persistence begin")
        do {
            if let settings = try AppSettingsPersistence.loadIfExists(in: modelContext) {
                AppSettingsPersistence.apply(settings: settings, to: appState)
                print("[AppStartup] bootstrap settings applied")
            } else {
                print("[AppStartup] bootstrap no persisted settings")
            }
        } catch {
            print("[AppStartup] bootstrap failed: \(error.localizedDescription)")
        }
        print("[AppStartup] bootstrap persistence end")
    }

    @MainActor
    private func enterAppAsSoonAsPossible() async {
        try? await Task.sleep(nanoseconds: 250_000_000)
        isBootstrapping = false
        print("[AppStartup] launch overlay dismissed")
    }

    private func startBootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        print("[AppStartup] start bootstrap")

        // 保底：即使啟動流程異常，也在 1 秒內放行 UI，不被 loading 永久阻塞。
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if isBootstrapping {
                isBootstrapping = false
                print("[AppStartup] fallback timeout -> dismiss overlay")
            }
        }

        Task { @MainActor in
            await enterAppAsSoonAsPossible()
            // 先讓使用者進入 App，再做設定回填，避免實機慢速 SwiftData 讀取卡住首屏。
            Task(priority: .utility) { @MainActor in
                await bootstrapPersistence()
            }
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

private struct LaunchLoadingView: View {
    var body: some View {
        ZStack {
            Color(white: 0.12)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("載入中...")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("應用程式載入中")
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
