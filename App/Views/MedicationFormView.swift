import SwiftUI
import SwiftData
import PetModel
import ScheduleEngine
import DesignSystem

/// Shell version of the medication form (04-SCREENS.md §5.1): fixed-times
/// daily schedules with the live next-doses preview straight from the engine.
/// The other six patterns plug into the same preview in Phase 2.
struct MedicationFormView: View {
    let pet: Pet

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var strength = ""
    @State private var amountValue = 1.0
    @State private var amountUnit = "tablet"
    @State private var times: [Date] = [defaultTime(hour: 8)]

    private static func defaultTime(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name", text: $name)
                    TextField("Strength (e.g. 75 mg tablet)", text: $strength)
                }

                Section("Amount per dose") {
                    Stepper(value: $amountValue, in: 0.25...20, step: 0.25) {
                        Text(FSFormat.doseAmount(value: amountValue, unit: amountUnit))
                    }
                    TextField("Unit", text: $amountUnit)
                }

                Section("Times — every day") {
                    ForEach(times.indices, id: \.self) { index in
                        DatePicker("Dose \(index + 1)", selection: $times[index],
                                   displayedComponents: .hourAndMinute)
                    }
                    .onDelete { offsets in
                        times.remove(atOffsets: offsets)
                    }
                    Button {
                        times.append(Self.defaultTime(hour: 20))
                    } label: {
                        Label("Add a time", systemImage: "plus")
                    }
                }

                Section("Next doses") {
                    let preview = previewOccurrences()
                    if preview.isEmpty {
                        Text("Add at least one time.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(preview, id: \.scheduledAt) { occ in
                            HStack {
                                Text(occ.scheduledAt, format: .dateTime.weekday(.wide).month().day())
                                Spacer()
                                Text(occ.scheduledAt, style: .time)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Add a medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !times.isEmpty
    }

    private func timeOfDayList() -> [TimeOfDay] {
        let calendar = Calendar.current
        return times.map { date in
            let c = calendar.dateComponents([.hour, .minute], from: date)
            return TimeOfDay(hour: c.hour ?? 8, minute: c.minute ?? 0)
        }
        .sorted()
    }

    private func builtSchedule() -> DoseSchedule {
        .fixedTimes(times: timeOfDayList(), days: .daily,
                    amount: DoseAmount(value: amountValue, unit: amountUnit))
    }

    /// The live preview (04-SCREENS.md §5.1): the engine's actual output for
    /// the next 5 occurrences — what will really happen, before saving.
    private func previewOccurrences() -> [DoseOccurrence] {
        guard !times.isEmpty else { return [] }
        let clock = SystemClock()
        let anchor = clock.calendar.startOfDay(for: clock.now)
        guard let horizon = clock.calendar.date(byAdding: .day, value: 7, to: clock.now) else { return [] }
        let spec = ScheduleSpec(medicationID: UUID(), schedule: builtSchedule(), anchor: anchor)
        let occurrences = ScheduleEngine.occurrences(for: spec, from: clock.now, to: horizon, using: clock)
        return Array(occurrences.prefix(5))
    }

    private func save() {
        let now = Date()
        let clock = SystemClock()
        let anchor = clock.calendar.startOfDay(for: now)

        let med = Medication()
        med.pet = pet
        med.name = name.trimmingCharacters(in: .whitespaces)
        med.strength = strength.trimmingCharacters(in: .whitespaces)
        med.createdAt = now
        med.updatedAt = now

        guard let revision = ScheduleRevision.make(
            schedule: builtSchedule(),
            anchor: anchor,
            createdAt: now
        ) else { return }

        context.insert(med)
        revision.medication = med
        context.insert(revision)
        dismiss()
    }
}
