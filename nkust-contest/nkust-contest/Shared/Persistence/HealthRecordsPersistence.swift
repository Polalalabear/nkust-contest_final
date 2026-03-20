import Foundation
import SwiftData

enum HealthRecordsPersistence {
    @MainActor
    static func fetchLastDays(_ days: Int, in context: ModelContext) throws -> [DailyHealthRecord] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        let desc = FetchDescriptor<PersistedHealthDayRecordEntity>(
            sortBy: [SortDescriptor(\.dayStart, order: .reverse)]
        )
        let rows = try context.fetch(desc)
        let filtered = rows.filter { $0.dayStart >= start }.prefix(days)
        return filtered.map {
            DailyHealthRecord(
                date: $0.dayStart,
                steps: $0.steps,
                distanceKm: $0.distanceKm,
                standingMinutes: $0.standingMinutes
            )
        }
    }

    @MainActor
    static func upsertToday(
        steps: Int,
        distanceKm: Double,
        standingMinutes: Int,
        in context: ModelContext
    ) throws {
        let cal = Calendar.current
        let day = cal.startOfDay(for: Date())
        let desc = FetchDescriptor<PersistedHealthDayRecordEntity>(
            sortBy: [SortDescriptor(\.dayStart, order: .reverse)]
        )
        let rows = try context.fetch(desc)
        if let existing = rows.first(where: { cal.isDate($0.dayStart, inSameDayAs: day) }) {
            existing.steps = steps
            existing.distanceKm = distanceKm
            existing.standingMinutes = standingMinutes
        } else {
            context.insert(PersistedHealthDayRecordEntity(
                dayStart: day,
                steps: steps,
                distanceKm: distanceKm,
                standingMinutes: standingMinutes
            ))
        }
        try context.save()
    }

    @MainActor
    static func seedIfEmpty(in context: ModelContext) throws {
        let desc = FetchDescriptor<PersistedHealthDayRecordEntity>()
        let count = try context.fetchCount(desc)
        guard count == 0 else { return }
        for rec in DailyHealthRecord.mockThreeMonths() {
            context.insert(PersistedHealthDayRecordEntity(
                dayStart: rec.date,
                steps: rec.steps,
                distanceKm: rec.distanceKm,
                standingMinutes: rec.standingMinutes
            ))
        }
        try context.save()
    }
}
