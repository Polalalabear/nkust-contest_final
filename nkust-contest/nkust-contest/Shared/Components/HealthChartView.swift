import SwiftUI
import Charts

struct HealthChartView: View {
    let records: [DailyHealthRecord]
    let metric: HealthMetric
    let chartStyle: ChartStyle

    private var chartData: [(label: String, value: Double)] {
        records.sorted { $0.date < $1.date }.map { rec in
            (rec.date.shortMD, metric.value(from: rec))
        }
    }

    var body: some View {
        chartContent
            .frame(height: 200)
    }

    @ViewBuilder
    private var chartContent: some View {
        switch chartStyle {
        case .bar:
            barChart
        case .line:
            lineChart
        case .pie:
            pieChart
        }
    }

    private var barChart: some View {
        Chart(chartData, id: \.label) { item in
            BarMark(
                x: .value("日期", item.label),
                y: .value(metric.rawValue, item.value)
            )
            .foregroundStyle(.orange.gradient)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5))
        }
    }

    private var lineChart: some View {
        Chart(chartData, id: \.label) { item in
            LineMark(
                x: .value("日期", item.label),
                y: .value(metric.rawValue, item.value)
            )
            .foregroundStyle(.orange)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("日期", item.label),
                y: .value(metric.rawValue, item.value)
            )
            .foregroundStyle(.orange.opacity(0.1))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5))
        }
    }

    private var pieChart: some View {
        let grouped = groupedForPie()
        return Chart(grouped, id: \.label) { item in
            SectorMark(
                angle: .value(metric.rawValue, item.value),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .foregroundStyle(by: .value("區間", item.label))
            .cornerRadius(4)
        }
        .chartLegend(position: .bottom, spacing: 8)
    }

    private func groupedForPie() -> [(label: String, value: Double)] {
        let sorted = records.sorted { $0.date < $1.date }
        let count = sorted.count
        guard count > 0 else { return [] }

        let chunkSize = max(count / 4, 1)
        var result: [(label: String, value: Double)] = []

        for i in stride(from: 0, to: count, by: chunkSize) {
            let end = min(i + chunkSize, count)
            let chunk = sorted[i..<end]
            let avg = chunk.reduce(0.0) { $0 + metric.value(from: $1) } / Double(chunk.count)
            let startDate = chunk.first!.date.shortMD
            let endDate = chunk.last!.date.shortMD
            let label = (startDate == endDate) ? startDate : "\(startDate)–\(endDate)"
            result.append((label: label, value: avg))
        }
        return result
    }
}

#Preview {
    HealthChartView(
        records: DailyHealthRecord.mockWeek(),
        metric: .steps,
        chartStyle: .bar
    )
    .padding()
}
