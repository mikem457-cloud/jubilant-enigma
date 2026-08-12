import SwiftUI
import SwiftData
import PetModel
import DesignSystem

struct PetDetailView: View {
    let pet: Pet
    @State private var showingAddMedication = false

    var body: some View {
        List {
            Section("Medications") {
                let meds = (pet.medications ?? []).filter(\.isActive).sorted { $0.name < $1.name }
                if meds.isEmpty {
                    Text("No medications yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(meds) { med in
                    VStack(alignment: .leading, spacing: FSSpace.xs) {
                        Text(med.name).font(.headline)
                        if !med.strength.isEmpty {
                            Text(med.strength)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, FSSpace.xs)
                }
                Button {
                    showingAddMedication = true
                } label: {
                    Label("Add a medication", systemImage: "plus")
                }
            }
        }
        .navigationTitle(pet.name)
        .sheet(isPresented: $showingAddMedication) {
            MedicationFormView(pet: pet)
        }
    }
}
