import Foundation
import Combine

final class DashboardViewModel: ObservableObject {
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
