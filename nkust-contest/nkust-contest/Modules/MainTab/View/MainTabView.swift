import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedPage: Int = 1
    @State private var pendingWrapTask: Task<Void, Never>?
    var onBack: () -> Void

    private let pageCount = 3

    var body: some View {
        @Bindable var state = appState
        TabView(
            selection: Binding(
                get: { selectedPage },
                set: { newValue in
                    if !appState.effectiveDeviceConnected, newValue != 1 {
                        debugLog("blocked page switch because device disconnected; force walk mode")
                        selectedPage = 1
                        appState.currentMode = .walkMode
                        return
                    }
                    if selectedPage != newValue {
                        debugLog("page changed \(selectedPage) -> \(newValue)")
                    }
                    selectedPage = newValue
                }
            )
        ) {
            LTCModeView(isVoiceEnabled: $state.isVoiceEnabled, onBack: onBack, streamingEnabled: false)
                .tag(0)
                .id("ltc-leading-sentinel")

            WalkModeView(isVoiceEnabled: $state.isVoiceEnabled, onBack: onBack)
                .tag(1)
                .id("walk-main")

            RecognitionModeView(isVoiceEnabled: $state.isVoiceEnabled, onBack: onBack)
                .tag(2)
                .id("recognition-main")

            LTCModeView(isVoiceEnabled: $state.isVoiceEnabled, onBack: onBack)
                .tag(3)
                .id("ltc-main")

            WalkModeView(isVoiceEnabled: $state.isVoiceEnabled, onBack: onBack, streamingEnabled: false)
                .tag(4)
                .id("walk-trailing-sentinel")
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .ignoresSafeArea()
        .onChange(of: selectedPage) { oldValue, newValue in
            handleCyclicScroll(from: oldValue, to: newValue)
        }
        .onDisappear {
            pendingWrapTask?.cancel()
            pendingWrapTask = nil
            VoiceAnnouncementCenter.shared.stopAll()
        }
    }

    private func handleCyclicScroll(from oldValue: Int, to newValue: Int) {
        if newValue == 0 {
            scheduleWrapJump(from: 0, to: 3)
        } else if newValue == 4 {
            scheduleWrapJump(from: 4, to: 1)
        }

        let modeMap: [Int: AppMode] = [1: .walkMode, 2: .recognitionMode, 3: .ltcMode]
        if let mode = modeMap[newValue] {
            appState.currentMode = mode
            debugLog("current mode -> \(mode.title)")
        }
    }

    private func scheduleWrapJump(from sentinelPage: Int, to targetPage: Int) {
        pendingWrapTask?.cancel()
        pendingWrapTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            guard selectedPage == sentinelPage else { return }
            debugLog("wrap jump \(sentinelPage) -> \(targetPage)")
            withAnimation(.none) {
                selectedPage = targetPage
            }
        }
    }

    private func debugLog(_ message: String) {
        print("[MainTab] \(message)")
    }
}

#Preview {
    MainTabView(onBack: {})
        .environment(AppState())
}
