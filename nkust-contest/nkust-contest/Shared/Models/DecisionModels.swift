import Foundation

enum NavigationAction: String {
    case stop = "STOP"
    case moveLeft = "MOVE LEFT"
    case moveRight = "MOVE RIGHT"
    case safe = "SAFE"
}

struct ObstacleInfo {
    let description: String
    let distance: Int

    static let mock = ObstacleInfo(description: "前方有障礙物", distance: 5)
    static let empty = ObstacleInfo(description: "", distance: 0)
}

struct DirectionInfo {
    let instruction: String
    let detail: String

    static let mock = DirectionInfo(instruction: "繼續直行", detail: "")
    static let turnRight = DirectionInfo(instruction: "請向右轉", detail: "")
}

struct TrafficLightInfo {
    let isRed: Bool
    let instruction: String

    static let redLight = TrafficLightInfo(isRed: true, instruction: "請在原地停留")
    static let none = TrafficLightInfo(isRed: false, instruction: "")
}

struct DecisionContext {
    let obstacleDetected: Bool
}

struct DecisionResult {
    let action: NavigationAction
}

struct ContactInfo: Identifiable {
    let id: UUID
    let name: String
    let isAvailable: Bool
}
