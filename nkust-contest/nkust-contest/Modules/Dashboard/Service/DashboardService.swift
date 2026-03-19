import Foundation

protocol DashboardServicing {
    func callUser()
    func sendVoiceMessage()
    func viewLogs()
}

final class StubDashboardService: DashboardServicing {
    func callUser() {
        // TODO: connect remote call action
    }

    func sendVoiceMessage() {
        // TODO: connect voice message action
    }

    func viewLogs() {
        // TODO: connect log retrieval action
    }
}
