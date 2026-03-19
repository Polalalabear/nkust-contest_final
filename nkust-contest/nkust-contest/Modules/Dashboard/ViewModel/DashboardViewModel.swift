import SwiftUI
import Observation

@Observable
final class DashboardViewModel {
    var steps: Int = 3279
    var distance: Double = 2.7
    var standingMinutes: Int = 93

    private let service: DashboardServicing

    init(service: DashboardServicing = StubDashboardService()) {
        self.service = service
    }

    func callUser() {
        service.callUser()
    }

    func sendVoiceMessage() {
        service.sendVoiceMessage()
    }

    func viewLogs() {
        service.viewLogs()
    }
}
