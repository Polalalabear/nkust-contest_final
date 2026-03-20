import Foundation

/// Firestore 文件 `dashboard/caregiver_primary` 的欄位對應（見 README 契約）
struct FirestoreDashboardSnapshot: Equatable {
    var connected: Bool
    var deviceBattery: Int
    var phoneBattery: Int?
    var isLocationSharing: Bool?
    var steps: Int?
    var distanceKm: Double?
    var standingMinutes: Int?
}

enum FirestoreDashboardPaths {
    /// 單一文件：裝置連線 + 電量 + 可選當日健康摘要
    nonisolated static let caregiverPrimaryDocument = "dashboard/caregiver_primary"
}
