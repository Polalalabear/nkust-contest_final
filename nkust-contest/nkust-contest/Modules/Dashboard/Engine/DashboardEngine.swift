import Foundation

protocol DashboardEngine {
    func buildStatusSummary() -> String
}

struct StubDashboardEngine: DashboardEngine {
    func buildStatusSummary() -> String {
        // TODO: map runtime system status into summary
        return ""
    }
}
