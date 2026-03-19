import SwiftUI
import Charts

struct HealthChartView: View {
    let records: [DailyHealthRecord]
    let metric: HealthMetric
    @Binding var chartStyle: ChartStyle

    private var chartData: [(label: String, value: Double)] {
        records.sorted { $0.date < $1.date }.map { rec in
            let label = rec.date.formatted(.dateTime.month(.abbreviated).day())
            return (label, metric.value(from: rec))
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            chartStylePicker
            chartContent
                .frame(height: 200)
        }
    }

    private var chartStylePicker: some View {
        Picker("圖表類型", selection: $chartStyle) {
            ForEach(ChartStyle.allCases) { style in
                Label(style.rawValue, systemImage: style.icon).tag(style)
            }
        }
        .pickerStyle(.segmented)
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
            let startDate = chunk.first!.date.formatted(.dateTime.month(.abbreviated).day())
            let endDate = chunk.last!.date.formatted(.dateTime.month(.abbreviated).day())
            result.append((label: "\(startDate)–\(endDate)", value: avg))
        }
        return result
    }
}

#Preview {
    HealthChartView(
        records: DailyHealthRecord.mockWeek(),
        metric: .steps,
        chartStyle: .constant(.bar)
    )
    .padding()
}
