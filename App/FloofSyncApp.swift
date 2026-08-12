import SwiftUI
import SwiftData
import PetModel

@main
struct FloofSyncApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let configuration = ModelConfiguration(schema: schema)
            container = try ModelContainer(
                for: schema,
                migrationPlan: FloofSyncMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            // A store that can't open is unrecoverable at runtime; failing loud
            // beats silently running on a throwaway in-memory store.
            fatalError("Failed to open the data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
