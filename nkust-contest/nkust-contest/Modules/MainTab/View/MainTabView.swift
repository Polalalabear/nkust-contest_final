import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedPage: Int = 1
    var onBack: () -> Void

    private let pageCount = 3

    var body: some View {
        @Bindable var state = appState
        TabView(selection: $selectedPage) {
            LTCModeView(isVoiceEnabled: $state.isVoiceEnabled, onBack: onBack)
                .tag(0)

            WalkModeView(isVoiceEnabled: $state.isVoiceEnabled, onBack: onBack)
                .tag(1)

            RecognitionModeView(isVoiceEnabled: $state.isVoiceEnabled, onBack: onBack)
                .tag(2)

            LTCModeView(isVoiceEnabled: $state.isVoiceEnabled, onBack: onBack)
                .tag(3)

            WalkModeView(isVoiceEnabled: $state.isVoiceEnabled, onBack: onBack)
                .tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .ignoresSafeArea()
        .onChange(of: selectedPage) { oldValue, newValue in
            handleCyclicScroll(from: oldValue, to: newValue)
        }
    }

    private func handleCyclicScroll(from oldValue: Int, to newValue: Int) {
        if newValue == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                selectedPage = 3
            }
        } else if newValue == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                selectedPage = 1
            }
        }

        let modeMap: [Int: AppMode] = [1: .walkMode, 2: .recognitionMode, 3: .ltcMode]
        if let mode = modeMap[newValue] {
            appState.currentMode = mode
        }
    }
}

#Preview {
    MainTabView(onBack: {})
        .environment(AppState())
}
