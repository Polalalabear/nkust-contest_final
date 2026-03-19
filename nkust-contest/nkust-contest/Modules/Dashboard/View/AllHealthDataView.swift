import SwiftUI

struct AllHealthDataView: View {
    @State private var records = DailyHealthRecord.mockThreeMonths()
    @State private var selectedDate: Date? = nil
    @State private var displayedMonth: Date = Date()
    @State private var selectedPeriod: HealthPeriod = .month
    @State private var sortOrder: SortOrder = .descending

    private let calendar = Calendar.current

    private var filteredRecords: [DailyHealthRecord] {
        let cutoff: Date
        let today = calendar.startOfDay(for: Date())
        switch selectedPeriod {
        case .week:
            cutoff = calendar.date(byAdding: .day, value: -7, to: today)!
        case .month:
            cutoff = calendar.date(byAdding: .month, value: -1, to: today)!
        case .threeMonths:
            cutoff = calendar.date(byAdding: .month, value: -3, to: today)!
        }
        let data = records.filter { $0.date >= cutoff }
        return sortOrder == .descending
            ? data.sorted { $0.date > $1.date }
            : data.sorted { $0.date < $1.date }
    }

    private var averageSteps: Double {
        guard !filteredRecords.isEmpty else { return 0 }
        return Double(filteredRecords.reduce(0) { $0 + $1.steps }) / Double(filteredRecords.count)
    }

    private var averageDistance: Double {
        guard !filteredRecords.isEmpty else { return 0 }
        return filteredRecords.reduce(0.0) { $0 + $1.distanceKm } / Double(filteredRecords.count)
    }

    private var averageStanding: Double {
        guard !filteredRecords.isEmpty else { return 0 }
        return Double(filteredRecords.reduce(0) { $0 + $1.standingMinutes }) / Double(filteredRecords.count)
    }

    private func record(for date: Date) -> DailyHealthRecord? {
        let day = calendar.startOfDay(for: date)
        return records.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    var body: some View {
        List {
            calendarSection
            periodAndSortSection
            averagesSection

            if let date = selectedDate, let rec = record(for: date) {
                dailyDetailSection(rec)
            }

            dailyListSection
        }
        .navigationTitle("所有健康資料")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        Section {
            VStack(spacing: 12) {
                monthNavigator
                weekdayHeader
                calendarGrid
            }
            .padding(.vertical, 8)
        }
    }

    private var monthNavigator: some View {
        HStack {
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)!
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(displayedMonth, format: .dateTime.year().month())
                .font(.headline)

            Spacer()

            Button {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var weekdayHeader: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return HStack {
            ForEach(symbols, id: \.self) { s in
                Text(s)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let days = daysInMonth(for: displayedMonth)
        let firstWeekday = calendar.component(.weekday, from: days.first ?? Date())
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
            ForEach(0..<leadingBlanks, id: \.self) { _ in
                Text("")
                    .frame(height: 36)
            }
            ForEach(days, id: \.self) { day in
                let hasData = record(for: day) != nil
                let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false

                Button {
                    selectedDate = day
                } label: {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.subheadline)
                        .fontWeight(isSelected ? .bold : .regular)
                        .foregroundStyle(isSelected ? .white : (hasData ? .primary : .secondary))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            Circle()
                                .fill(isSelected ? .orange : (hasData ? .orange.opacity(0.15) : .clear))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func daysInMonth(for date: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: monthStart) }
    }

    // MARK: - Filters

    private var periodAndSortSection: some View {
        Section {
            Picker("期間", selection: $selectedPeriod) {
                ForEach(HealthPeriod.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("排序", selection: $sortOrder) {
                ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Averages

    private var averagesSection: some View {
        Section("\(selectedPeriod.rawValue)平均") {
            averageRow(icon: "figure.walk", label: "步數", value: "\(Int(averageSteps))", unit: "步")
            averageRow(icon: "map", label: "距離", value: String(format: "%.1f", averageDistance), unit: "公里")
            averageRow(icon: "figure.stand", label: "站立", value: "\(Int(averageStanding))", unit: "分鐘")
        }
    }

    private func averageRow(icon: String, label: String, value: String, unit: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 28)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Daily Detail

    private func dailyDetailSection(_ rec: DailyHealthRecord) -> some View {
        Section("\(rec.date, format: .dateTime.month().day().weekday()) 詳細") {
            detailRow(icon: "figure.walk", label: "步數", value: "\(rec.steps)", unit: "步")
            detailRow(icon: "map", label: "距離", value: String(format: "%.1f", rec.distanceKm), unit: "公里")
            detailRow(icon: "figure.stand", label: "站立", value: "\(rec.standingMinutes)", unit: "分鐘")
        }
    }

    private func detailRow(icon: String, label: String, value: String, unit: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 28)
            Text(label)
            Spacer()
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Daily List

    private var dailyListSection: some View {
        Section("每日紀錄") {
            ForEach(filteredRecords) { rec in
                VStack(alignment: .leading, spacing: 6) {
                    Text(rec.date, format: .dateTime.month().day().weekday())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        miniStat(icon: "figure.walk", value: "\(rec.steps)", unit: "步")
                        miniStat(icon: "map", value: String(format: "%.1f", rec.distanceKm), unit: "km")
                        miniStat(icon: "figure.stand", value: "\(rec.standingMinutes)", unit: "分")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func miniStat(icon: String, value: String, unit: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        AllHealthDataView()
    }
}
