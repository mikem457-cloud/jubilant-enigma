import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Contacts & Emergency — Phase 2", systemImage: "cross.case")
                    Label("Grooming & Feeding — Phase 3", systemImage: "scissors")
                    Label("Settings — Phase 2", systemImage: "gearshape")
                }
                .foregroundStyle(.secondary)

                Section("About") {
                    LabeledContent("Version", value: "0.2.0")
                    Text("FloofSync is a record-keeping and reminder tool. It is not veterinary advice. Always follow your veterinarian's instructions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("More")
        }
    }
}
