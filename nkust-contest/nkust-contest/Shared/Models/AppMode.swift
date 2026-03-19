import Foundation

enum AppMode: String, CaseIterable, Identifiable {
    case walkMode = "Walk Mode"
    case recognitionMode = "Recognition Mode"
    case ltcMode = "LTC Mode"
    case dashboard = "Dashboard"

    var id: String { rawValue }
}
