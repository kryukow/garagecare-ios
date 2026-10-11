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
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Не удалось открыть базу данных: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}

