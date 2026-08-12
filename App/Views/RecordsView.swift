import SwiftUI

struct RecordsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Records",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Scan and search vet documents here. Arrives in Phase 3.")
            )
            .navigationTitle("Records")
        }
    }
}
