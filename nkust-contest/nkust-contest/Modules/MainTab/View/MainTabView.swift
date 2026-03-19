import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: AppMode = .walkMode

    var body: some View {
        @Bindable var state = appState
        TabView(selection: $selectedTab) {
            WalkModeView(isVoiceEnabled: $state.isVoiceEnabled)
                .tag(AppMode.walkMode)

            RecognitionModeView(isVoiceEnabled: $state.isVoiceEnabled)
                .tag(AppMode.recognitionMode)

            LTCModeView(isVoiceEnabled: $state.isVoiceEnabled)
                .tag(AppMode.ltcMode)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .ignoresSafeArea()
        .onChange(of: selectedTab) { _, newValue in
            appState.currentMode = newValue
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
