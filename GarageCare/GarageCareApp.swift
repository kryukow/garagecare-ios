import SwiftData
import SwiftUI
import UIKit

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
                let demo = UIGraphicsImageRenderer(size: CGSize(width: 520, height: 240)).image { context in
                    UIColor.darkGray.setFill(); context.fill(CGRect(x: 0, y: 0, width: 520, height: 240))
                    UIImage(systemName: "car.side.fill")?.withTintColor(.lightGray, renderingMode: .alwaysOriginal)
                        .draw(in: CGRect(x: 140, y: 60, width: 240, height: 120))
                }
                car.imageData = demo.pngData()
                container.mainContext.insert(car)
                for (title, interval) in [("Воздушный фильтр", 15000), ("Тормозные колодки", 40000), ("Масло и фильтр", 10000)] {
                    container.mainContext.insert(MaintenanceTask(vehicleID: car.id, title: title, intervalKm: interval, lastMileage: 140000))
                }
                container.mainContext.insert(MaintenanceTask(vehicleID: car.id, title: "Проверка ремня", intervalKm: 0, lastMileage: 140000))
                try container.mainContext.save()
                UserDefaults.standard.set("list", forKey: "taskLayoutMode")
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

