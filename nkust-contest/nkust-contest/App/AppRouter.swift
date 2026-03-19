import SwiftUI

struct AppRouter: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Walk Mode") {
                    WalkModeView()
                }
                NavigationLink("Recognition Mode") {
                    RecognitionModeView()
                }
                NavigationLink("LTC Mode") {
                    LTCModeView()
                }
                NavigationLink("Dashboard") {
                    DashboardView()
                }
            }
            .navigationTitle("Navigation System")
        }
    }
}

#Preview {
    AppRouter()
}
