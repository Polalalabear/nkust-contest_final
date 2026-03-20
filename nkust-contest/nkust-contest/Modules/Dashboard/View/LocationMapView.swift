import SwiftUI
import MapKit

struct LocationMapView: View {
    @Environment(AppState.self) private var appState
    @State private var position: MapCameraPosition = .automatic
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                Annotation("使用者位置", coordinate: CLLocationCoordinate2D(latitude: 24.1632, longitude: 120.6403)) {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                        .background(Circle().fill(.white).frame(width: 36, height: 36))
                }
            }
            .mapStyle(.standard)
            .navigationTitle("地圖")
            .toolbar {
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
        }
    }
}

#Preview {
    LocationMapView()
}
