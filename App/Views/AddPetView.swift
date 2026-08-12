import SwiftUI
import SwiftData
import PetModel

struct AddPetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var species: Species = .dog

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Species", selection: $species) {
                    ForEach(Species.allCases, id: \.self) { s in
                        Text(label(for: s)).tag(s)
                    }
                }
            }
            .navigationTitle("Add a pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let now = Date()
        let pet = Pet()
        pet.name = name.trimmingCharacters(in: .whitespaces)
        pet.species = species
        pet.createdAt = now
        pet.updatedAt = now
        context.insert(pet)
        dismiss()
    }

    private func label(for species: Species) -> String {
        switch species {
        case .dog: "Dog"
        case .cat: "Cat"
        case .rabbit: "Rabbit"
        case .ferret: "Ferret"
        case .bird: "Bird"
        case .reptile: "Reptile"
        case .horse: "Horse"
        case .other: "Other"
        }
    }
}
