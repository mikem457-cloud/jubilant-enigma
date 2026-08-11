import SwiftUI
import SwiftData
import PetModel
import ScheduleEngine
import DesignSystem

/// The medication form (04-SCREENS.md §5.1): six of the seven schedule
/// patterns with the live next-doses preview straight from the engine, plus
/// end policies (ongoing / after N doses / on a date). The taper builder is
/// its own flow and arrives with Phase 2.
struct MedicationFormView: View {
    let pet: Pet

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var strength = ""
    @State private var amountValue = 1.0
    @State private var amountUnit = "tablet"

    @State private var pattern: PatternChoice = .everyDay
    @State private var times: [Date] = [defaultTime(hour: 8)]
    @State private var selectedWeekdays: Set<Weekday> = [.monday]
    @State private var everyN = 2
    @State private var monthDay = 1
    @State private var intervalHours = 12
    @State private var prnGapHours = 6
    @State private var prnHasDailyCap = false
    @State private var prnMaxPerDay = 3

    @State private var endChoice: EndChoice = .ongoing
    @State private var endDosesCount = 14
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()

    @State private var preview: [DoseOccurrence] = []

    enum PatternChoice: String, CaseIterable, Identifiable {
        case everyDay = "Every day"
        case weekdays = "Days of the week"
        case everyNDays = "Every N days"
        case monthly = "Monthly"
        case interval = "Every N hours"
        case asNeeded = "As needed"
        var id: String { rawValue }
    }

    enum EndChoice: String, CaseIterable, Identifiable {
        case ongoing = "Ongoing"
        case afterDoses = "After a number of doses"
        case onDate = "On a date"
        var id: String { rawValue }
    }

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

                Section {
                    Picker("Repeats", selection: $pattern) {
                        ForEach(PatternChoice.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: pattern) {
                        if times.isEmpty {
                            times = [Self.defaultTime(hour: 9)]
                        }
                    }
                    patternFields
                } header: {
                    Text("Schedule")
                } footer: {
                    Text("Tap Repeats to choose: every day, days of the week, every N days, monthly, every N hours, or as needed.")
                }

                if pattern != .asNeeded {
                    Section("Ends") {
                        Picker("Ends", selection: $endChoice) {
                            ForEach(EndChoice.allCases) { c in
                                Text(c.rawValue).tag(c)
                            }
                        }
                        .pickerStyle(.menu)
                        if endChoice == .afterDoses {
                            Stepper("After \(endDosesCount) dose\(endDosesCount == 1 ? "" : "s")",
                                    value: $endDosesCount, in: 1...365)
                        }
                        if endChoice == .onDate {
                            DatePicker("Last day", selection: $endDate, displayedComponents: .date)
                        }
                    }
                }

                Section(pattern == .asNeeded ? "Availability" : "Next doses") {
                    previewSection
                }
            }
            .navigationTitle("Add a medication")
            .navigationBarTitleDisplayMode(.inline)
            // The engine runs only when a schedule-shaping input changes —
            // never on name/strength keystrokes, which only redraw the form.
            .onAppear { preview = previewOccurrences() }
            .onChange(of: previewKey) { preview = previewOccurrences() }
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

    // MARK: - Pattern-specific fields

    @ViewBuilder
    private var patternFields: some View {
        switch pattern {
        case .everyDay:
            timesEditor

        case .weekdays:
            WeekdayPicker(selection: $selectedWeekdays)
            timesEditor

        case .everyNDays:
            Stepper("Every \(everyN) days", value: $everyN, in: 2...60)
            timesEditor

        case .monthly:
            Picker("Day of the month", selection: $monthDay) {
                ForEach(1...31, id: \.self) { d in
                    Text("Day \(d)").tag(d)
                }
            }
            if monthDay > 28 {
                Text("In shorter months this lands on the last day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            DatePicker("Time", selection: $times[0], displayedComponents: .hourAndMinute)

        case .interval:
            Stepper("Every \(intervalHours) hours", value: $intervalHours, in: 1...72)
            Text("The first dose is scheduled from when you save; each later dose follows the previous one you log.")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .asNeeded:
            Stepper("At least \(prnGapHours) hours apart", value: $prnGapHours, in: 1...48)
            Toggle("Daily limit", isOn: $prnHasDailyCap)
            if prnHasDailyCap {
                Stepper("At most \(prnMaxPerDay) per day", value: $prnMaxPerDay, in: 1...12)
            }
        }
    }

    private var timesEditor: some View {
        Group {
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
    }

    /// Everything that shapes the generated schedule. When this is unchanged,
    /// the cached preview stays valid.
    private struct PreviewKey: Equatable {
        var pattern: PatternChoice
        var times: [Date]
        var weekdays: Set<Weekday>
        var everyN: Int
        var monthDay: Int
        var intervalHours: Int
        var amountValue: Double
        var endChoice: EndChoice
        var endDosesCount: Int
        var endDate: Date
    }

    private var previewKey: PreviewKey {
        PreviewKey(pattern: pattern, times: times, weekdays: selectedWeekdays,
                   everyN: everyN, monthDay: monthDay, intervalHours: intervalHours,
                   amountValue: amountValue, endChoice: endChoice,
                   endDosesCount: endDosesCount, endDate: endDate)
    }

    @ViewBuilder
    private var previewSection: some View {
        if pattern == .asNeeded {
            Text("Shown on Today as available whenever \(prnGapHours) hours have passed since the last dose\(prnHasDailyCap ? ", up to \(prnMaxPerDay) per day" : "").")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if preview.isEmpty {
            Text(times.isEmpty ? "Add at least one time." : "No upcoming doses with these settings.")
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

    // MARK: - Building the schedule

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch pattern {
        case .everyDay, .everyNDays: return !times.isEmpty
        case .weekdays: return !times.isEmpty && !selectedWeekdays.isEmpty
        case .monthly, .interval, .asNeeded: return true
        }
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
        let amount = DoseAmount(value: amountValue, unit: amountUnit)
        switch pattern {
        case .everyDay:
            return .fixedTimes(times: timeOfDayList(), days: .daily, amount: amount)
        case .weekdays:
            return .fixedTimes(times: timeOfDayList(), days: .weekdays(selectedWeekdays), amount: amount)
        case .everyNDays:
            return .everyNDays(n: everyN, times: timeOfDayList(), amount: amount)
        case .monthly:
            let t = timeOfDayList().first ?? TimeOfDay(hour: 9, minute: 0)
            return .monthly(day: monthDay, time: t, amount: amount)
        case .interval:
            return .interval(hours: Double(intervalHours), amount: amount)
        case .asNeeded:
            return .asNeeded(minimumGapHours: Double(prnGapHours),
                             maxPerDay: prnHasDailyCap ? prnMaxPerDay : nil,
                             amount: amount)
        }
    }

    private func builtEndPolicy() -> EndPolicy {
        guard pattern != .asNeeded else { return .openEnded }
        switch endChoice {
        case .ongoing:
            return .openEnded
        case .afterDoses:
            return .afterTotalDoses(endDosesCount)
        case .onDate:
            return .onDate(DateOnly(of: endDate, in: Calendar.current))
        }
    }

    private func anchorDate(clock: SystemClock) -> Date {
        // Interval chains from its anchor instant; calendar patterns anchor to
        // the start of today so today's remaining times are included.
        pattern == .interval ? clock.now : clock.calendar.startOfDay(for: clock.now)
    }

    /// The live preview (04-SCREENS.md §5.1): the engine's actual output for
    /// the next 5 occurrences — what will really happen, before saving.
    private func previewOccurrences() -> [DoseOccurrence] {
        let clock = SystemClock()
        // Far enough out that monthly and every-N-days always show 5 entries.
        guard let horizon = clock.calendar.date(byAdding: .day, value: 185, to: clock.now) else { return [] }
        let spec = ScheduleSpec(
            medicationID: UUID(),
            schedule: builtSchedule(),
            anchor: anchorDate(clock: clock),
            endPolicy: builtEndPolicy()
        )
        let occurrences = ScheduleEngine.occurrences(for: spec, from: clock.now, to: horizon, using: clock)
        return Array(occurrences.prefix(5))
    }

    private func save() {
        let now = Date()
        let clock = SystemClock()

        let med = Medication()
        med.pet = pet
        med.name = name.trimmingCharacters(in: .whitespaces)
        med.strength = strength.trimmingCharacters(in: .whitespaces)
        med.createdAt = now
        med.updatedAt = now

        guard let revision = ScheduleRevision.make(
            schedule: builtSchedule(),
            anchor: anchorDate(clock: clock),
            endPolicy: builtEndPolicy(),
            createdAt: now
        ) else { return }

        context.insert(med)
        revision.medication = med
        context.insert(revision)
        dismiss()
    }
}

// MARK: - Weekday picker

private struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    private static let order: [(Weekday, String)] = [
        (.sunday, "S"), (.monday, "M"), (.tuesday, "T"), (.wednesday, "W"),
        (.thursday, "T"), (.friday, "F"), (.saturday, "S"),
    ]

    private static let fullNames: [Weekday: String] = [
        .sunday: "Sunday", .monday: "Monday", .tuesday: "Tuesday",
        .wednesday: "Wednesday", .thursday: "Thursday", .friday: "Friday",
        .saturday: "Saturday",
    ]

    var body: some View {
        HStack(spacing: FSSpace.sm) {
            ForEach(Self.order, id: \.0) { day, letter in
                let isOn = selection.contains(day)
                Button {
                    if isOn {
                        selection.remove(day)
                    } else {
                        selection.insert(day)
                    }
                } label: {
                    Text(letter)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(isOn ? Color.fsBrandNavy : Color(.systemGray5))
                        .foregroundStyle(isOn ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Self.fullNames[day] ?? "")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, FSSpace.xs)
    }
}
