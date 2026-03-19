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
                        MainTabView()
                    } else {
                        DeviceInfoView(
                            isVoiceEnabled: $state.isVoiceEnabled,
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
