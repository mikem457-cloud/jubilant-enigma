import SwiftUI
import SwiftData
import PetModel
import DesignSystem

struct PetsView: View {
    @Query(sort: \Pet.sortOrder) private var pets: [Pet]
    @State private var showingAddPet = false

    var body: some View {
        NavigationStack {
            Group {
                if pets.isEmpty {
                    ContentUnavailableView {
                        Label("No pets yet", systemImage: "pawprint")
                    } description: {
                        Text("Add your pet to start tracking medications.")
                    } actions: {
                        Button("Add a pet") { showingAddPet = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(pets.filter { !$0.isArchived }) { pet in
                            NavigationLink(value: pet.id) {
                                PetRow(pet: pet)
                            }
                        }
                    }
                    .navigationDestination(for: UUID.self) { petID in
                        if let pet = pets.first(where: { $0.id == petID }) {
                            PetDetailView(pet: pet)
                        }
                    }
                }
            }
            .navigationTitle("Pets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddPet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a pet")
                }
            }
            .sheet(isPresented: $showingAddPet) {
                AddPetView()
            }
        }
    }
}

private struct PetRow: View {
    let pet: Pet

    var body: some View {
        HStack(spacing: FSSpace.md) {
            Image(systemName: pet.species == .cat ? "cat.fill" : "dog.fill")
                .font(.title3)
                .foregroundStyle(Color.fsBrandSteel)
            VStack(alignment: .leading, spacing: FSSpace.xs) {
                Text(pet.name).font(.headline)
                let activeMeds = (pet.medications ?? []).filter(\.isActive)
                Text(activeMeds.isEmpty
                     ? "No active medications"
                     : "^[\(activeMeds.count) active medication](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, FSSpace.xs)
    }
}
