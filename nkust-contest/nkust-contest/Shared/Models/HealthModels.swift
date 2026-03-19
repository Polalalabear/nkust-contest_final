import Foundation

struct DailyHealthRecord: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Int
    let distanceKm: Double
    let standingMinutes: Int

    static func mockWeek() -> [DailyHealthRecord] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            return DailyHealthRecord(
                date: date,
                steps: Int.random(in: 1800...6500),
                distanceKm: Double.random(in: 0.8...5.2),
                standingMinutes: Int.random(in: 30...150)
            )
        }
    }

    static func mockMonth() -> [DailyHealthRecord] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<30).map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            return DailyHealthRecord(
                date: date,
                steps: Int.random(in: 1200...8000),
                distanceKm: Double.random(in: 0.5...6.0),
                standingMinutes: Int.random(in: 20...180)
            )
        }
    }

    static func mockThreeMonths() -> [DailyHealthRecord] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<90).map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            return DailyHealthRecord(
                date: date,
                steps: Int.random(in: 1000...9000),
                distanceKm: Double.random(in: 0.3...7.0),
                standingMinutes: Int.random(in: 15...200)
            )
        }
    }
}

enum HealthMetric: String, CaseIterable, Identifiable {
    case steps = "行走步數"
    case distance = "行走距離"
    case standing = "站立分鐘數"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .steps: "步"
        case .distance: "公里"
        case .standing: "分鐘"
        }
    }

    var icon: String {
        switch self {
        case .steps: "figure.walk"
        case .distance: "map"
        case .standing: "figure.stand"
        }
    }

    func value(from record: DailyHealthRecord) -> Double {
        switch self {
        case .steps: Double(record.steps)
        case .distance: record.distanceKm
        case .standing: Double(record.standingMinutes)
        }
    }

    func formatted(_ val: Double) -> String {
        switch self {
        case .steps: "\(Int(val))"
        case .distance: String(format: "%.1f", val)
        case .standing: "\(Int(val))"
        }
    }
}

enum HealthPeriod: String, CaseIterable, Identifiable {
    case week = "週"
    case month = "當月"
    case threeMonths = "三個月"

    var id: String { rawValue }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case ascending = "升序"
    case descending = "降序"

    var id: String { rawValue }
}

enum ChartStyle: String, CaseIterable, Identifiable {
    case bar = "長條圖"
    case line = "折線圖"
    case pie = "圓餅圖"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bar: "chart.bar.fill"
        case .line: "chart.xyaxis.line"
        case .pie: "chart.pie.fill"
        }
    }
}
