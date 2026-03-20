import Foundation

/// 照護者主控台資料來源：測試假資料 vs 真實後端（Firestore）+ 本地快取（SwiftData）
enum DataSourceMode: String, CaseIterable, Identifiable {
    case mock = "mock"
    case live = "live"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .mock: "測試資料"
        case .live: "真實資料"
        }
    }
}
