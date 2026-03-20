import FirebaseFirestore
import Foundation

/// 監聽 Firestore 照護者儀表板快照；失敗時回報 nil（不 crash）
@MainActor
final class FirestoreDashboardSnapshotService {
    static let shared = FirestoreDashboardSnapshotService()

    private var registration: ListenerRegistration?
    private let db = Firestore.firestore()

    private init() {}

    func startListening(
        documentPath: String,
        onUpdate: @escaping (FirestoreDashboardSnapshot?) -> Void
    ) {
        stopListening()
        let doc = db.document(documentPath)
        registration = doc.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                if let error {
                    onUpdate(nil)
                    self.stopListening()
                    await SystemIncidentCenter.shared.report(
                        title: "Firestore 監聽失敗",
                        details: error.localizedDescription,
                        isCritical: false
                    )
                    return
                }
                guard let data = snapshot?.data() else {
                    onUpdate(nil)
                    return
                }
                let snap = FirestoreDashboardSnapshot(
                    connected: data["connected"] as? Bool ?? false,
                    deviceBattery: data["deviceBattery"] as? Int ?? 0,
                    phoneBattery: data["phoneBattery"] as? Int,
                    isLocationSharing: data["isLocationSharing"] as? Bool,
                    steps: data["steps"] as? Int,
                    distanceKm: data["distanceKm"] as? Double,
                    standingMinutes: data["standingMinutes"] as? Int
                )
                onUpdate(snap)
            }
        }
    }

    func stopListening() {
        registration?.remove()
        registration = nil
    }
}
