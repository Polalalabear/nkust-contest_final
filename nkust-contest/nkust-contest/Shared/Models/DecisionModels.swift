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

    /// 距離 8 公尺：配合 DefaultDecisionEngine 會得到「向右修正」類決策，與方向卡示意一致
    static let mock = ObstacleInfo(description: "前方有障礙物", distance: 8)
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

struct DecisionContext: Equatable {
    /// 是否偵測到前方障礙（含距離資訊有效時）
    var obstacleDetected: Bool
    /// 與障礙物距離（公尺），僅在 obstacleDetected 時有意義
    var obstacleDistanceMeters: Int
    /// 號誌為紅燈時為 true
    var trafficLightRed: Bool

    init(
        obstacleDetected: Bool = false,
        obstacleDistanceMeters: Int = 0,
        trafficLightRed: Bool = false
    ) {
        self.obstacleDetected = obstacleDetected
        self.obstacleDistanceMeters = obstacleDistanceMeters
        self.trafficLightRed = trafficLightRed
    }
}

struct DecisionResult: Equatable {
    let action: NavigationAction
}

struct ContactInfo: Identifiable {
    let id: UUID
    let name: String
    let isAvailable: Bool
}
