import SwiftData
import SwiftUI

@main
struct GarageCareApp: App {
    private let modelContainer: ModelContainer = {
        let schema = Schema([
            Vehicle.self,
            MaintenanceTask.self,
            ServiceRecord.self,
            MileageEntry.self,
            FuelEntry.self
        ])

        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            }
            #endif
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Не удалось открыть базу данных: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                GarageUITestRoot()
            } else {
                RootView()
            }
            #else
            RootView()
            #endif
        }
        .modelContainer(modelContainer)
    }
}

