import SwiftUI
import Observation
import SwiftData
import MapKit
import CoreLocation
import UIKit

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

    init(service: DashboardServicing? = nil) {
        self.service = service ?? StubDashboardService()
    }

    func callUser() {
        service.callUser()
    }

    func fetchVisUserLocation() {
        isShowingLocation = true
    }

    func showNearestHospital(appState: AppState) {
        let sourceCoordinate = CLLocationCoordinate2D(
            latitude: appState.visUserLatitude,
            longitude: appState.visUserLongitude
        )
        let sourceLocation = CLLocation(latitude: sourceCoordinate.latitude, longitude: sourceCoordinate.longitude)

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "醫院"
        request.region = MKCoordinateRegion(
            center: sourceCoordinate,
            latitudinalMeters: 8_000,
            longitudinalMeters: 8_000
        )

        Task {
            do {
                let response = try await MKLocalSearch(request: request).start()
                let nearest = response.mapItems.min(by: {
                    let l0 = $0.location
                    let l1 = $1.location
                    let d0 = l0.distance(from: sourceLocation)
                    let d1 = l1.distance(from: sourceLocation)
                    return d0 < d1
                })

                guard let nearest else {
                    await SystemIncidentCenter.shared.report(
                        title: "附近醫院搜尋失敗",
                        details: "未找到可用醫院結果。",
                        isCritical: false
                    )
                    return
                }

                let destination = nearest.location.coordinate
                let lat = destination.latitude
                let lon = destination.longitude
                let name = (nearest.name ?? "醫院").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "醫院"

                if let appURL = URL(string: "comgooglemaps://?q=\(name)&center=\(lat),\(lon)&zoom=16"),
                   UIApplication.shared.canOpenURL(appURL) {
                    await UIApplication.shared.open(appURL)
                } else if let webURL = URL(string: "https://www.google.com/maps/search/?api=1&query=\(lat),\(lon)") {
                    await UIApplication.shared.open(webURL)
                }
            } catch {
                await SystemIncidentCenter.shared.report(
                    title: "附近醫院搜尋例外",
                    details: error.localizedDescription,
                    isCritical: false
                )
            }
        }
    }

    /// 依資料來源重新載入；Firebase 暫停期間 live 走本地資料回退。
    func syncDataSource(mode: DataSourceMode, appState: AppState, modelContext: ModelContext) {
        switch mode {
        case .mock:
            FirestoreDashboardSnapshotService.shared.stopListening()
            appState.liveFirestoreSnapshot = nil
            weekRecords = DailyHealthRecord.mockWeek()
            chartDetailRecords = DailyHealthRecord.mockThreeMonths()

        case .live:
            FirestoreDashboardSnapshotService.shared.stopListening()
            appState.liveFirestoreSnapshot = nil
            do {
                try HealthRecordsPersistence.seedIfEmpty(in: modelContext)
                reloadFromSwiftData(modelContext: modelContext)
            } catch {
                weekRecords = DailyHealthRecord.mockWeek()
                chartDetailRecords = DailyHealthRecord.mockThreeMonths()
            }
            // Firebase 暫停：不啟動 Firestore snapshot listener。
            // startFirestoreListening(appState: appState, modelContext: modelContext)
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
