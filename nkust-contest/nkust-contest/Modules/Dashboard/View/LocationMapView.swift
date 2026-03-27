import SwiftUI
import MapKit
import CoreLocation

struct LocationMapView: View {
    @Environment(AppState.self) private var appState
    @State private var position: MapCameraPosition = .automatic
    @State private var showProfile = false
    var onBack: (() -> Void)?
    @State private var liveCoordinate: CLLocationCoordinate2D?
    @State private var locationAgent = LiveLocationAgent()

    private var shownCoordinate: CLLocationCoordinate2D {
        if appState.dataSourceMode == .live {
            if let liveCoordinate { return liveCoordinate }
            return CLLocationCoordinate2D(latitude: appState.visUserLatitude, longitude: appState.visUserLongitude)
        }
        return CLLocationCoordinate2D(latitude: 24.1632, longitude: 120.6403)
    }

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                Annotation("使用者位置", coordinate: shownCoordinate) {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                        .background(Circle().fill(.white).frame(width: 36, height: 36))
                }
            }
            .mapStyle(.standard)
            .navigationTitle("地圖")
            .toolbar {
                if let onBack {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("返回")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("個人資訊")
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileSheetView()
                    .preferredColorScheme(appState.isDarkMode ? .dark : .light)
            }
            .onAppear {
                applyDataMode(appState.dataSourceMode)
            }
            .onChange(of: appState.dataSourceMode) { _, mode in
                applyDataMode(mode)
            }
            .onDisappear {
                locationAgent.stop()
            }
        }
    }

    private func applyDataMode(_ mode: DataSourceMode) {
        guard mode == .live else {
            locationAgent.stop()
            liveCoordinate = nil
            position = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 24.1632, longitude: 120.6403),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
            return
        }

        locationAgent.onLocation = { coordinate in
            liveCoordinate = coordinate
            appState.visUserLatitude = coordinate.latitude
            appState.visUserLongitude = coordinate.longitude
            appState.isLocationSharing = true
            position = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )
            )
        }
        locationAgent.start()
    }
}

@MainActor
private final class LiveLocationAgent: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onLocation: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        onLocation?(latest.coordinate)
    }
}

#Preview {
    LocationMapView()
}
