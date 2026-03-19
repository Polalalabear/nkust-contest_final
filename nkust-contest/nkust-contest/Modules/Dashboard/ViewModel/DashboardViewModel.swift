import SwiftUI
import Observation

@Observable
final class DashboardViewModel {
    var weekRecords: [DailyHealthRecord] = DailyHealthRecord.mockWeek()

    var todaySteps: Int { weekRecords.first?.steps ?? 0 }
    var todayDistance: Double { weekRecords.first?.distanceKm ?? 0 }
    var todayStanding: Int { weekRecords.first?.standingMinutes ?? 0 }

    private let service: DashboardServicing

    init(service: DashboardServicing = StubDashboardService()) {
        self.service = service
    }

    func callUser() {
        service.callUser()
    }
}
