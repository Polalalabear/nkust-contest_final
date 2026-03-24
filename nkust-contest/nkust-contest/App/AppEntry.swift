import FirebaseCore
import Foundation
import SwiftData
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct AppEntry: App {
    @State private var appState = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        ensureApplicationSupportDirectoryExists()
    }

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environment(appState)
                .modelContainer(
                    for: [PersistedAppSettings.self, PersistedHealthDayRecordEntity.self],
                    inMemory: false
                )
        }
    }

    private func ensureApplicationSupportDirectoryExists() {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: appSupportURL.path, isDirectory: &isDirectory)
        if exists && isDirectory.boolValue {
            return
        }

        try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
    }
}
