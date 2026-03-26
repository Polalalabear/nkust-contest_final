import Foundation
import UIKit

protocol DashboardServicing {
    func callUser(phoneNumber: String)
    func sendVoiceMessage()
    func viewLogs()
}

final class StubDashboardService: DashboardServicing {
    func callUser(phoneNumber: String) {
        let sanitized = phoneNumber.filter { $0.isNumber || $0 == "+" }
        guard !sanitized.isEmpty,
              let url = URL(string: "tel://\(sanitized)"),
              UIApplication.shared.canOpenURL(url) else {
            print("[DashboardService] cannot place call for number: \(phoneNumber)")
            return
        }
        UIApplication.shared.open(url)
    }

    func sendVoiceMessage() {
        // TODO: connect voice message action
    }

    func viewLogs() {
        // TODO: connect log retrieval action
    }
}
