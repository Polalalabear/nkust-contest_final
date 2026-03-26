import Foundation
import SwiftData
import SwiftUI

enum StartupTrace {
    private static let launchUptimeNs = DispatchTime.now().uptimeNanoseconds

    static func log(_ category: String, _ message: String) {
        let nowNs = DispatchTime.now().uptimeNanoseconds
        let deltaNs: UInt64 = nowNs >= launchUptimeNs ? (nowNs - launchUptimeNs) : 0
        let deltaMs = Double(deltaNs) / 1_000_000
        let thread = Thread.isMainThread ? "main" : "bg"
        let composed = String(format: "[%@][+%.3fms][%@] %@", category, deltaMs, thread, message)
        print(composed)
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        StartupTrace.log("AppStartup", "didFinishLaunching begin")
        // Firebase 暫停：離線模式下不進行雲端初始化。
        _ = application
        _ = launchOptions
        StartupTrace.log("AppStartup", "didFinishLaunching end")
        return true
    }
}

@main
struct AppEntry: App {
    @State private var appState = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        StartupTrace.log("AppStartup", "AppEntry init begin")
        ensureApplicationSupportDirectoryExists()
        StartupTrace.log("AppStartup", "AppEntry init end")
    }

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environment(appState)
                .onAppear {
                    StartupTrace.log("AppStartup", "WindowGroup root onAppear")
                }
        }
    }

    private func ensureApplicationSupportDirectoryExists() {
        StartupTrace.log("AppStartup", "ensureApplicationSupportDirectoryExists begin")
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            StartupTrace.log("AppStartup", "application support URL missing")
            return
        }

        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: appSupportURL.path, isDirectory: &isDirectory)
        if exists && isDirectory.boolValue {
            StartupTrace.log("AppStartup", "application support directory exists")
            return
        }

        try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        StartupTrace.log("AppStartup", "application support directory created")
    }
}
