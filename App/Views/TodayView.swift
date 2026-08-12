import SwiftUI
import SwiftData
import PetModel
import ScheduleEngine
import DesignSystem

/// The app (04-SCREENS.md §2). This shell version computes today's occurrences
/// live from ScheduleEngine and supports one-tap logging. Sections, snooze,
/// undo, and PRN rows arrive with ReminderKit in Phase 2.
struct TodayView: View {
    @Query(sort: \Medication.name) private var medications: [Medication]
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Group {
                let items = todayItems()
                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing due today",
                        systemImage: "checkmark.seal",
                        description: Text("Add a pet and a medication to see doses here.")
                    )
                } else {
                    List(items) { item in
                        DoseRow(item: item) {
                            log(item)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Today")
        }
    }

    private func todayItems() -> [DoseItem] {
        let clock = SystemClock()
        let calendar = clock.calendar
        let dayStart = calendar.startOfDay(for: clock.now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        var items: [DoseItem] = []
        for med in medications where med.isActive {
            let specs = med.scheduleSpecs()
            guard !specs.isEmpty else { continue }
            let occurrences = ScheduleEngine.occurrences(
                forRevisions: specs,
                from: dayStart, to: dayEnd,
                lastCompleted: lastCompleted(of: med),
                using: clock
            )
            for occurrence in occurrences {
                let log = (med.logs ?? []).first { $0.scheduledAt == occurrence.scheduledAt }
                items.append(DoseItem(medication: med, occurrence: occurrence, log: log))
            }
        }
        return items.sorted { $0.occurrence.scheduledAt < $1.occurrence.scheduledAt }
    }

    private func lastCompleted(of med: Medication) -> Date? {
        (med.logs ?? [])
            .filter { $0.outcome == .given || $0.outcome == .partial }
            .map(\.actualAt)
            .max()
    }

    private func log(_ item: DoseItem) {
        let now = Date()
        let entry = DoseLog()
        entry.medication = item.medication
        entry.scheduledAt = item.occurrence.scheduledAt
        entry.outcome = .given
        entry.actualAt = now
        entry.createdAt = now
        entry.updatedAt = now
        context.insert(entry)
    }
}

struct DoseItem: Identifiable {
    let medication: Medication
    let occurrence: DoseOccurrence
    let log: DoseLog?

    var id: String {
        "\(medication.id.uuidString)-\(occurrence.scheduledAt.timeIntervalSince1970)"
    }
}

private struct DoseRow: View {
    let item: DoseItem
    let onLog: () -> Void

    var body: some View {
        HStack(spacing: FSSpace.md) {
            VStack(alignment: .leading, spacing: FSSpace.xs) {
                Text(item.medication.pet?.name ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.medication.name)
                    .font(.headline)
                if let stage = item.occurrence.stageLabel {
                    Text(stage)
                        .font(.caption)
                        .foregroundStyle(Color.fsBrandSteel)
                }
                Text(amountText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.occurrence.scheduledAt, style: .time)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            if item.log != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.fsSage)
                    .accessibilityLabel("Logged")
            } else {
                Button(action: onLog) {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(Color.fsBrandNavy)
                }
                .buttonStyle(.plain)
                .frame(minWidth: FSMetrics.minHitTarget, minHeight: FSMetrics.minHitTarget)
                .accessibilityLabel("Log \(item.medication.name) as given")
            }
        }
        .padding(.vertical, FSSpace.xs)
    }

    private var amountText: String {
        FSFormat.doseAmount(value: item.occurrence.amount.value, unit: item.occurrence.amount.unit)
    }
}
