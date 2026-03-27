import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedPage: Int = 1
    @State private var pendingWrapTask: Task<Void, Never>?
    @State private var pendingModeAnnounceTask: Task<Void, Never>?
    @State private var lastTripleTapAt: Date?
    var onBack: () -> Void

    private let pageCount = 3

    var body: some View {
        @Bindable var state = appState
        GeometryReader { proxy in
            ZStack {
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
                if appState.blackScreenTestEnabled {
                    Color.black
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .simultaneousGesture(
                SpatialTapGesture(count: 2).onEnded { value in
                    guard shouldHandleBlindGesture(at: value.location, screenHeight: proxy.size.height) else { return }
                    let now = Date()
                    if let lastTripleTapAt, now.timeIntervalSince(lastTripleTapAt) < 0.45 {
                        return
                    }
                    guard appState.isVoiceEnabled else { return }
                    VoiceAnnouncementCenter.shared.replayLastSpoken()
                },
                including: .all
            )
            .simultaneousGesture(
                SpatialTapGesture(count: 3).onEnded { value in
                    guard shouldHandleBlindGesture(at: value.location, screenHeight: proxy.size.height) else { return }
                    lastTripleTapAt = Date()
                    state.isVoiceEnabled.toggle()
                    VoiceAnnouncementCenter.shared.announceVoiceToggle(isEnabled: state.isVoiceEnabled)
                },
                including: .all
            )
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .ignoresSafeArea()
        .onChange(of: selectedPage) { oldValue, newValue in
            handleCyclicScroll(from: oldValue, to: newValue)
        }
        .onAppear {
            VoiceAnnouncementCenter.shared.stopAll()
            announceCurrentModeImmediatelyIfNeeded()
        }
        .onDisappear {
            pendingWrapTask?.cancel()
            pendingWrapTask = nil
            pendingModeAnnounceTask?.cancel()
            pendingModeAnnounceTask = nil
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
            scheduleModeAnnouncement(mode)
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

    private func scheduleModeAnnouncement(_ mode: AppMode) {
        pendingModeAnnounceTask?.cancel()
        pendingModeAnnounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            VoiceAnnouncementCenter.shared.speak(
                "已切換至\(mode.title)",
                priority: .navigation,
                interruptLowerPriority: true,
                bypassThrottle: true
            )
        }
    }

    private func shouldHandleBlindGesture(at location: CGPoint, screenHeight: CGFloat) -> Bool {
        guard screenHeight > 0 else { return false }
        return location.y >= screenHeight / 3.0
    }

    private func announceCurrentModeImmediatelyIfNeeded() {
        let modeMap: [Int: AppMode] = [1: .walkMode, 2: .recognitionMode, 3: .ltcMode]
        guard let mode = modeMap[selectedPage] else { return }
        VoiceAnnouncementCenter.shared.speak(
            "現在在\(mode.title)",
            priority: .navigation,
            interruptLowerPriority: true,
            bypassThrottle: true
        )
    }
}

#Preview {
    MainTabView(onBack: {})
        .environment(AppState())
}
