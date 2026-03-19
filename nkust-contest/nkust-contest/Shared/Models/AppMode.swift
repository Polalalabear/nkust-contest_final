import Foundation

enum UserRole: String, CaseIterable, Identifiable {
    case visuallyImpaired = "視障者"
    case caregiver = "照護者"

    var id: String { rawValue }
}

enum AppMode: Int, CaseIterable, Identifiable {
    case walkMode = 0
    case recognitionMode = 1
    case ltcMode = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .walkMode: "行走模式"
        case .recognitionMode: "辨識模式"
        case .ltcMode: "長照模式"
        }
    }

    var swipeHint: (left: String, right: String) {
        switch self {
        case .walkMode:
            ("向左滑動切換至 長照模式", "向右滑動切換至 辨識模式")
        case .recognitionMode:
            ("向左滑動切換至 行走模式", "向右滑動切換至 長照模式")
        case .ltcMode:
            ("向左滑動切換至 辨識模式", "向右滑動切換至 行走模式")
        }
    }
}
