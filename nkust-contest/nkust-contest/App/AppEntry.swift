import SwiftUI

@main
struct AppEntry: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environment(appState)
        }
    }
}
