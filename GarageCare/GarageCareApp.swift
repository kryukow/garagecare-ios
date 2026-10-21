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
            if ProcessInfo.processInfo.arguments.contains("--graphite-preview") {
                let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
                let car = Vehicle(make: "Audi", model: "A6 Avant", year: 2018, currentMileage: 148200)
                car.huDueDate = Calendar.current.date(byAdding: .month, value: 8, to: .now)
                car.insuranceNextDebitDate = Calendar.current.date(byAdding: .month, value: 2, to: .now)
                container.mainContext.insert(car)
                for (title, interval) in [("Воздушный фильтр", 15000), ("Тормозные колодки", 40000), ("Масло и фильтр", 10000)] {
                    container.mainContext.insert(MaintenanceTask(vehicleID: car.id, title: title, intervalKm: interval, lastMileage: 140000))
                }
                try container.mainContext.save()
                UserDefaults.standard.set("dark", forKey: "appearanceMode")
                return container
            }
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

