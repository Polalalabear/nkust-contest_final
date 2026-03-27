import SwiftUI
import Observation
import SwiftData
import MapKit
import CoreLocation
import UIKit

@MainActor
@Observable
final class DashboardViewModel {
    enum LocationRefreshResult {
        case success
        case permissionRequired
        case failed
    }

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
    private var syncTask: Task<Void, Never>?
    private var locationAgent: OneShotLocationAgent?

    init(service: DashboardServicing? = nil) {
        self.service = service ?? StubDashboardService()
    }

    func callUser(phoneNumber: String) {
        service.callUser(phoneNumber: phoneNumber)
    }

    func fetchVisUserLocation() {
        isShowingLocation = true
    }

    func copyVisUserLocation(appState: AppState) async -> LocationRefreshResult {
        let coordinate: CLLocationCoordinate2D
        do {
            let latest = try await requestCurrentLocation()
            coordinate = latest
            appState.visUserLatitude = latest.latitude
            appState.visUserLongitude = latest.longitude
            appState.isLocationSharing = true
        } catch OneShotLocationAgent.LocationError.permissionDenied {
            appState.isLocationSharing = false
            return .permissionRequired
        } catch {
            return .failed
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let address = await resolveAddress(from: location)
        let latlon = String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
        let payload = "\(address)\n\(latlon)"
        UIPasteboard.general.string = payload
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        print("[Dashboard] copied location payload: \(payload)")
        return .success
    }

    func showNearestHospital(appState: AppState) {
        Task {
            let sourceCoordinate: CLLocationCoordinate2D
            do {
                let latest = try await requestCurrentLocation()
                sourceCoordinate = latest
                appState.visUserLatitude = latest.latitude
                appState.visUserLongitude = latest.longitude
                appState.isLocationSharing = true
            } catch OneShotLocationAgent.LocationError.permissionDenied {
                appState.isLocationSharing = false
                await SystemIncidentCenter.shared.report(
                    title: "附近醫院搜尋失敗",
                    details: "尚未取得定位權限，請先開啟位置存取。",
                    isCritical: false
                )
                return
            } catch {
                await SystemIncidentCenter.shared.report(
                    title: "附近醫院搜尋失敗",
                    details: "目前無法取得當下定位。",
                    isCritical: false
                )
                return
            }

            let sourceLocation = CLLocation(latitude: sourceCoordinate.latitude, longitude: sourceCoordinate.longitude)

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "醫院"
            request.region = MKCoordinateRegion(
                center: sourceCoordinate,
                latitudinalMeters: 8_000,
                longitudinalMeters: 8_000
            )

            do {
                let response = try await MKLocalSearch(request: request).start()
                let hospitals = response.mapItems.filter(isHospitalMapItem(_:))
                let candidates = hospitals.isEmpty ? response.mapItems : hospitals
                let nearest = candidates.min(by: {
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
                let destinationText = "\(lat),\(lon)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "\(lat),\(lon)"
                if let appURL = URL(string: "comgooglemaps://?daddr=\(destinationText)&directionsmode=driving&q=\(name)"),
                   UIApplication.shared.canOpenURL(appURL) {
                    await UIApplication.shared.open(appURL)
                } else if let webURL = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(destinationText)&travelmode=driving") {
                    await UIApplication.shared.open(webURL)
                } else {
                    nearest.openInMaps(launchOptions: [
                        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                    ])
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
        syncTask?.cancel()
        StartupTrace.log("DashboardLoad", "syncDataSource scheduled mode=\(mode.rawValue)")
        syncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            StartupTrace.log("DashboardLoad", "syncDataSource begin mode=\(mode.rawValue)")
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
            StartupTrace.log("DashboardLoad", "syncDataSource end mode=\(mode.rawValue)")
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

    private func resolveAddress(from location: CLLocation) async -> String {
        if #available(iOS 26.0, *) {
            do {
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    return "地址未知"
                }
                let items = try await request.mapItems
                if let first = items.first {
                    if let address = first.address {
                        let fullAddress = address.fullAddress.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        if !fullAddress.isEmpty {
                            return fullAddress
                        }
                        if let shortAddressRaw = address.shortAddress {
                            let shortAddress = shortAddressRaw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                            if !shortAddress.isEmpty {
                                return shortAddress
                            }
                        }
                    }
                    if let name = first.name, !name.isEmpty {
                        return name
                    }
                }
            } catch {
                return "地址未知"
            }
            return "地址未知"
        } else {
            do {
                let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
                guard let placemark = placemarks.first else {
                    return "地址未知"
                }
                let parts = [
                    placemark.country,
                    placemark.administrativeArea,
                    placemark.locality,
                    placemark.subLocality,
                    placemark.thoroughfare,
                    placemark.subThoroughfare
                ]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                let address = parts.joined()
                return address.isEmpty ? "地址未知" : address
            } catch {
                return "地址未知"
            }
        }
    }

    private func isHospitalMapItem(_ item: MKMapItem) -> Bool {
        if item.pointOfInterestCategory == .hospital {
            return true
        }
        let name = (item.name ?? "").lowercased()
        return name.contains("醫院") || name.contains("hospital") || name.contains("medical")
    }

    private func requestCurrentLocation() async throws -> CLLocationCoordinate2D {
        let agent = OneShotLocationAgent()
        locationAgent = agent
        defer { locationAgent = nil }
        return try await agent.requestLocation()
    }

}

@MainActor
private final class OneShotLocationAgent: NSObject, CLLocationManagerDelegate {
    enum LocationError: Error {
        case permissionDenied
        case unavailable
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var timeoutTask: Task<Void, Never>?
    private let recencyThreshold: TimeInterval = 20

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() async throws -> CLLocationCoordinate2D {
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            throw LocationError.permissionDenied
        }

        if let cached = manager.location,
           abs(cached.timestamp.timeIntervalSinceNow) <= recencyThreshold,
           cached.horizontalAccuracy >= 0 {
            return cached.coordinate
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.startUpdatingLocation()
                manager.requestLocation()
            }
            timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                self?.finish(with: .failure(LocationError.unavailable))
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
            manager.requestLocation()
        } else if status == .denied || status == .restricted {
            finish(with: .failure(LocationError.permissionDenied))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let valid = locations
            .filter { $0.horizontalAccuracy >= 0 && abs($0.timestamp.timeIntervalSinceNow) <= recencyThreshold }
            .sorted { $0.timestamp > $1.timestamp }
        guard let latest = valid.first else {
            finish(with: .failure(LocationError.unavailable))
            return
        }
        finish(with: .success(latest.coordinate))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError, clError.code == .locationUnknown {
            // Transient; wait for the next update until timeout.
            return
        }
        finish(with: .failure(LocationError.unavailable))
    }

    private func finish(with result: Result<CLLocationCoordinate2D, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
