#if DEBUG
import SwiftData
import SwiftUI

/// UI tests use an isolated, in-memory garage and never the user's database.
struct GarageUITestRoot: View {
    @Environment(\.modelContext) private var context
    @State private var vehicle: Vehicle?
    @State private var task: MaintenanceTask?

    var body: some View {
        Group {
            if let vehicle, let task {
                if ProcessInfo.processInfo.arguments.contains("--completion") {
                    CompleteTaskView(vehicle: vehicle, task: task)
                } else {
                    TaskEditorView(vehicle: vehicle)
                }
            }
        }
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .task {
            guard vehicle == nil else { return }
            let car = Vehicle(make: "Test", model: "Car", year: 2020, currentMileage: 100_000)
            let work = MaintenanceTask(vehicleID: car.id, title: "Масло", intervalKm: 10_000, lastMileage: 100_000)
            context.insert(car)
            context.insert(work)
            vehicle = car
            task = work
        }
    }
}
#endif
