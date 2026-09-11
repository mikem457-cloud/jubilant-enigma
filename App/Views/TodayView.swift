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
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                let result = todayResult()
                if result.items.isEmpty && result.invalidMedicationNames.isEmpty {
                    ContentUnavailableView(
                        "Nothing due today",
                        systemImage: "checkmark.seal",
                        description: Text("Add a pet and a medication to see doses here.")
                    )
                } else {
                    List {
                        if !result.invalidMedicationNames.isEmpty {
                            Section("Needs attention") {
                                ForEach(result.invalidMedicationNames, id: \.self) { name in
                                    Label("\(name) has unreadable schedule data. Review this medication before giving a dose.",
                                          systemImage: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        Section("Doses") {
                            ForEach(result.items) { item in
                                DoseRow(item: item) {
                                    log(item)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Today")
            .alert("Couldn’t save dose", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private func todayResult() -> TodayResult {
        let clock = SystemClock()
        let calendar = clock.calendar
        let dayStart = calendar.startOfDay(for: clock.now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return TodayResult(items: [], invalidMedicationNames: [])
        }

        var items: [DoseItem] = []
        var invalidMedicationNames: [String] = []
        for med in medications where med.isActive {
            let specs = med.scheduleSpecs()
            guard !specs.isEmpty, specs.count == (med.revisions ?? []).count else {
                invalidMedicationNames.append(med.name.isEmpty ? "Unnamed medication" : med.name)
                continue
            }
            let allCompletedLogs = completedLogs(of: med)
            for (index, spec) in specs.enumerated() {
                let nextEffectiveFrom = index + 1 < specs.count ? specs[index + 1].effectiveFrom : nil
                let start = max(dayStart, spec.effectiveFrom)
                let end = min(dayEnd, nextEffectiveFrom ?? dayEnd)
                guard start < end else { continue }

                // Dose-count limits restart with each immutable schedule revision.
                let revisionLogs = allCompletedLogs.filter { log in
                    guard log.actualAt >= spec.effectiveFrom else { return false }
                    if let nextEffectiveFrom {
                        return log.actualAt < nextEffectiveFrom
                    }
                    return true
                }
                let occurrences = ScheduleEngine.occurrences(
                    for: spec,
                    from: start, to: end,
                    lastCompleted: revisionLogs.map(\.actualAt).max(),
                    priorDoseCount: max(0, revisionLogs.count - 1),
                    prnDosesToday: revisionLogs.filter {
                        $0.actualAt >= dayStart && $0.actualAt < dayEnd
                    }.count,
                    using: clock
                )
                for occurrence in occurrences {
                    let log = (med.logs ?? []).first { $0.scheduledAt == occurrence.scheduledAt }
                    items.append(DoseItem(medication: med, occurrence: occurrence, log: log))
                }
            }
        }
        return TodayResult(
            items: items.sorted { $0.occurrence.scheduledAt < $1.occurrence.scheduledAt },
            invalidMedicationNames: invalidMedicationNames.sorted()
        )
    }

    private func completedLogs(of med: Medication) -> [DoseLog] {
        let completed = (med.logs ?? [])
            .filter { $0.outcome == .given || $0.outcome == .partial }
        // A local double tap or a later CloudKit merge must not count the same
        // scheduled administration twice toward a finite course or PRN cap.
        let grouped = Dictionary(grouping: completed) { log in
            log.scheduledAt.map { "scheduled:\($0.timeIntervalSinceReferenceDate)" }
                ?? "unscheduled:\(log.id.uuidString)"
        }
        return grouped.values.compactMap { logs in
            logs.max { $0.actualAt < $1.actualAt }
        }
    }

    private func log(_ item: DoseItem) {
        guard item.log == nil else { return }
        guard !(item.isAsNeeded && item.occurrence.scheduledAt > Date()) else {
            errorMessage = "This as-needed medication is not available yet because its minimum interval or daily limit has not been satisfied."
            return
        }
        guard !(item.medication.logs ?? []).contains(where: { $0.scheduledAt == item.occurrence.scheduledAt }) else {
            return
        }
        let now = Date()
        let entry = DoseLog()
        entry.medication = item.medication
        entry.scheduledAt = item.occurrence.scheduledAt
        entry.outcome = .given
        entry.actualAt = now
        entry.amountValue = item.occurrence.amount.value
        entry.amountUnit = item.occurrence.amount.unit
        entry.createdAt = now
        entry.updatedAt = now
        let previousInventory = item.medication.inventory?.unitsOnHand
        if let inventory = item.medication.inventory, inventory.trackingEnabled {
            inventory.unitsOnHand = max(0, inventory.unitsOnHand - item.occurrence.amount.value)
            inventory.updatedAt = now
        }
        context.insert(entry)
        do {
            try context.save()
        } catch {
            if let previousInventory, let inventory = item.medication.inventory {
                inventory.unitsOnHand = previousInventory
            }
            context.delete(entry)
            errorMessage = error.localizedDescription
        }
    }
}

private struct TodayResult {
    let items: [DoseItem]
    let invalidMedicationNames: [String]
}

struct DoseItem: Identifiable {
    let medication: Medication
    let occurrence: DoseOccurrence
    let log: DoseLog?

    var isAsNeeded: Bool {
        guard let revision = medication.scheduleSpecs().last(where: {
            $0.effectiveFrom <= occurrence.scheduledAt
        }) else { return false }
        if case .asNeeded = revision.schedule { return true }
        return false
    }

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
