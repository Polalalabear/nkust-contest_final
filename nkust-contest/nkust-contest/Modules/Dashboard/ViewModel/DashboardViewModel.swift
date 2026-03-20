import SwiftUI
import Observation
import SwiftData

@MainActor
@Observable
final class DashboardViewModel {
    /// 主控台圖表用（最近 7 天）
    var weekRecords: [DailyHealthRecord] = DailyHealthRecord.mockWeek()
    /// 詳情 / 全部健康資料用（最多 90 天）
    var chartDetailRecords: [DailyHealthRecord] = DailyHealthRecord.mockThreeMonths()

    var isShowingLocation = false
    var isShowingHospital = false

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

    func fetchVisUserLocation() {
        isShowingLocation = true
    }

    func showNearestHospital() {
        isShowingHospital = true
    }

    /// 依資料來源重新載入；真實模式會啟動 Firestore 監聽並合併 SwiftData
    func syncDataSource(mode: DataSourceMode, appState: AppState, modelContext: ModelContext) {
        switch mode {
        case .mock:
            FirestoreDashboardSnapshotService.shared.stopListening()
            appState.liveFirestoreSnapshot = nil
            weekRecords = DailyHealthRecord.mockWeek()
            chartDetailRecords = DailyHealthRecord.mockThreeMonths()

        case .live:
            FirestoreDashboardSnapshotService.shared.stopListening()
            do {
                try HealthRecordsPersistence.seedIfEmpty(in: modelContext)
                reloadFromSwiftData(modelContext: modelContext)
            } catch {
                weekRecords = DailyHealthRecord.mockWeek()
                chartDetailRecords = DailyHealthRecord.mockThreeMonths()
            }
            startFirestoreListening(appState: appState, modelContext: modelContext)
        }
    }

    private func reloadFromSwiftData(modelContext: ModelContext) {
        do {
            let last7 = try HealthRecordsPersistence.fetchLastDays(7, in: modelContext)
            weekRecords = last7.isEmpty ? DailyHealthRecord.mockWeek() : last7.sorted { $0.date > $1.date }

            let last90 = try HealthRecordsPersistence.fetchLastDays(90, in: modelContext)
            chartDetailRecords = last90.isEmpty ? DailyHealthRecord.mockThreeMonths() : last90
        } catch {
            weekRecords = DailyHealthRecord.mockWeek()
            chartDetailRecords = DailyHealthRecord.mockThreeMonths()
        }
    }

    private func startFirestoreListening(appState: AppState, modelContext: ModelContext) {
        FirestoreDashboardSnapshotService.shared.startListening(
            documentPath: FirestoreDashboardPaths.caregiverPrimaryDocument
        ) { [weak self] snap in
            guard let self else { return }
            appState.liveFirestoreSnapshot = snap
            if let snap {
                appState.deviceBattery = snap.deviceBattery
                if let pb = snap.phoneBattery {
                    appState.phoneBattery = pb
                }
                if let loc = snap.isLocationSharing {
                    appState.isLocationSharing = loc
                }
                if let steps = snap.steps, let dist = snap.distanceKm, let stand = snap.standingMinutes {
                    try? HealthRecordsPersistence.upsertToday(
                        steps: steps,
                        distanceKm: dist,
                        standingMinutes: stand,
                        in: modelContext
                    )
                }
            }
            self.reloadFromSwiftData(modelContext: modelContext)
        }
    }
}
