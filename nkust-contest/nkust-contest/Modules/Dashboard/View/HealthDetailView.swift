import SwiftUI
import Charts

struct HealthDetailView: View {
    @Environment(AppState.self) private var appState

    let metric: HealthMetric
    let records: [DailyHealthRecord]

    @State private var selectedPeriod: HealthPeriod = .week
    @State private var sortOrder: SortOrder = .descending

    private var filteredRecords: [DailyHealthRecord] {
        let data: [DailyHealthRecord]
        switch selectedPeriod {
        case .week: data = Array(records.prefix(7))
        case .month: data = Array(records.prefix(30))
        case .threeMonths: data = records
        }
        return sortOrder == .descending
            ? data.sorted { $0.date > $1.date }
            : data.sorted { $0.date < $1.date }
    }

    private var chartRecords: [DailyHealthRecord] {
        switch selectedPeriod {
        case .week: Array(records.prefix(7))
        case .month: Array(records.prefix(30))
        case .threeMonths: records
        }
    }

    private var average: Double {
        guard !filteredRecords.isEmpty else { return 0 }
        let total = filteredRecords.reduce(0.0) { $0 + metric.value(from: $1) }
        return total / Double(filteredRecords.count)
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 4) {
                    Text("平均")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(metric.formatted(average))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        Text(metric.unit)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if appState.showCharts {
                Section("圖表") {
                    HealthChartView(
                        records: chartRecords,
                        metric: metric,
                        chartStyle: appState.preferredChartStyle
                    )
                    .padding(.vertical, 4)
                }
            }

            Section {
                Picker("期間", selection: $selectedPeriod) {
                    ForEach(HealthPeriod.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)

                Picker("排序", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("每日紀錄") {
                ForEach(filteredRecords) { record in
                    HStack {
                        Text(record.date.shortMD)
                            .font(.subheadline)
                        Spacer()
                        Text("\(metric.formatted(metric.value(from: record))) \(metric.unit)")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(metric.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HealthDetailView(
            metric: .steps,
            records: DailyHealthRecord.mockThreeMonths()
        )
        .environment(AppState())
    }
}
