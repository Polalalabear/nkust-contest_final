import Foundation
import os

struct SystemIncident: Sendable {
    let title: String
    let details: String
    let isCritical: Bool
    let timestamp: Date
}

extension Notification.Name {
    static let systemIncidentReported = Notification.Name("systemIncidentReported")
}

actor SystemIncidentCenter {
    static let shared = SystemIncidentCenter()
    private let logger = Logger(subsystem: "nkust-contest", category: "system-incident")

    func report(title: String, details: String, isCritical: Bool = true) async {
        let incident = SystemIncident(
            title: title,
            details: details,
            isCritical: isCritical,
            timestamp: Date()
        )

        if isCritical {
            logger.fault("\(title, privacy: .public): \(details, privacy: .public)")
        } else {
            logger.error("\(title, privacy: .public): \(details, privacy: .public)")
        }

        await MainActor.run {
            NotificationCenter.default.post(
                name: .systemIncidentReported,
                object: incident
            )
        }
    }
}
