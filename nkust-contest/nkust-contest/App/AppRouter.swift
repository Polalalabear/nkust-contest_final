import SwiftUI

struct AppRouter: View {
    @Environment(AppState.self) private var appState
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
    }
}

#Preview {
    AppRouter()
        .environment(AppState())
}
