import PhotosUI
import SwiftData
import SwiftUI

struct GarageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    @AppStorage("graphiteSelectedVehicle") private var selectedVehicleID = ""
    @State private var showingAddVehicle = false
    private var selectedVehicle: Vehicle? { vehicles.first { $0.id.uuidString == selectedVehicleID } ?? vehicles.first }

    @State private var vehicleToDelete: Vehicle?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                GarageScreenBackground()

                if vehicles.isEmpty {
                    VStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Color.garageGreen.opacity(0.12))
                                .frame(width: 92, height: 92)
                            Image(systemName: "car.side.fill")
                                .font(.system(size: 39, weight: .semibold))
                                .foregroundStyle(Color.garageGreen)
                        }

                        VStack(spacing: 6) {
                            Text("Гараж пуст")
                                .font(.title2.bold())
                            Text("Добавь автомобиль и следи за обслуживанием в одном месте.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            showingAddVehicle = true
                        } label: {
                            Label("Добавить автомобиль", systemImage: "plus")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.garageGreen)
                        .foregroundStyle(Color.garageOnAccent)
                        .frame(maxWidth: 290)
                    }
                    .padding(28)
                } else {
                    if let vehicle = selectedVehicle {
                        VehicleDetailView(
                            vehicle: vehicle, garageVehicles: vehicles,
                            selectVehicle: { selectedVehicleID = $0.id.uuidString },
                            addVehicle: { showingAddVehicle = true },
                            deleteVehicle: { vehicleToDelete = vehicle }
                        ).id(vehicle.id)
                    }

                }
            }
            .navigationTitle("Мой гараж")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if vehicles.isEmpty {
                        Button { showingAddVehicle = true } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Добавить автомобиль")
                    }
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                AddVehicleView()
            }
            .alert("Удалить автомобиль?", isPresented: Binding(
                get: { vehicleToDelete != nil },
                set: { if !$0 { vehicleToDelete = nil } }
            )) {
                Button("Отмена", role: .cancel) {
                    vehicleToDelete = nil
                }
                Button("Удалить", role: .destructive) {
                    guard let vehicleToDelete else { return }
                    delete(vehicleToDelete)
                    self.vehicleToDelete = nil
                }
            } message: {
                Text("Будут удалены все связанные работы, пробег и заправки.")
            }
            .alert("Ошибка удаления", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private func delete(_ vehicle: Vehicle) {
        let vehicleID = vehicle.id
        let taskDescriptor = FetchDescriptor<MaintenanceTask>(
            predicate: #Predicate { $0.vehicleID == vehicleID }
        )
        let recordDescriptor = FetchDescriptor<ServiceRecord>(
            predicate: #Predicate { $0.vehicleID == vehicleID }
        )
        let mileageDescriptor = FetchDescriptor<MileageEntry>(
            predicate: #Predicate { $0.vehicleID == vehicleID }
        )
        let fuelDescriptor = FetchDescriptor<FuelEntry>(
            predicate: #Predicate { $0.vehicleID == vehicleID }
        )

        do {
            let vehicleTasks = try modelContext.fetch(taskDescriptor)
            let vehicleRecords = try modelContext.fetch(recordDescriptor)
            let vehicleMileage = try modelContext.fetch(mileageDescriptor)
            let vehicleFuel = try modelContext.fetch(fuelDescriptor)
            vehicleTasks.forEach { modelContext.delete($0) }
            vehicleRecords.forEach { modelContext.delete($0) }
            vehicleMileage.forEach { modelContext.delete($0) }
            vehicleFuel.forEach { modelContext.delete($0) }
            modelContext.delete(vehicle)
            try modelContext.save()
            NotificationManager.shared.cancelNotifications(for: vehicle, tasks: vehicleTasks)
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }
}

private struct AddVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var make = ""
    @State private var model = ""
    @State private var year = ""
    @State private var vin = ""
    @State private var mileage = ""
    @State private var engineHours = ""
    @State private var notes = ""
    @State private var expectedConsumption = ""
    @State private var imageData: Data?
    @State private var extraPhotoData: Data?
    @State private var photoLoading = false
    @State private var addTemplates = true
    @State private var errorMessage: String?

    private var canSave: Bool {
        !make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(mileage.filter(\.isNumber)) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Автомобиль") {
                    TextField("Марка автомобиля", text: $make)
                    TextField("Модель автомобиля", text: $model)
                    TextField("Год", text: $year)
                        .keyboardType(.numberPad)
                    TextField("VIN (необязательно)", text: $vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Текущий пробег, км", text: $mileage)
                        .keyboardType(.numberPad)
                    LabeledContent("Моточасы") {
                        TextField("Не заданы", text: $engineHours)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    TextField("л/100 км", text: $expectedConsumption)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Ожидаемый расход")
                } footer: {
                    Text("Необязательно. Будет показан как ориентир, пока приложение не рассчитает фактический расход по заправкам.")
                }

                ServicePhotoField(title: "Фото автомобиля", data: $imageData, additionalData: $extraPhotoData, isLoading: $photoLoading)

                Section {
                    Toggle("Добавить список типовых работ", isOn: $addTemplates)
                } footer: {
                    Text("Интервалы останутся пустыми — задай их по регламенту именно своего автомобиля.")
                }

                Section("Заметка") {
                    TextField("Комплектация, двигатель и другое", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .garageKeyboardDismiss()
            .scrollContentBackground(.hidden)
            .background(Color.garageBackground)
            .navigationTitle("Новый автомобиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(!canSave || photoLoading)
                }
            }

        }
    }

    private func save() {
        guard let mileageValue = Int(mileage.filter(\.isNumber)) else { return }
        let normalizedExpected = expectedConsumption.replacingOccurrences(of: ",", with: ".")
        let normalizedHours = engineHours.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let hoursValue = normalizedHours.isEmpty ? 0.0 : Double(normalizedHours), hoursValue.isFinite, hoursValue >= 0 else {
            errorMessage = "Проверь моточасы двигателя."
            return
        }
        let vehicle = Vehicle(
            make: make.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            year: Int(year.filter(\.isNumber)) ?? Calendar.current.component(.year, from: .now),
            vin: vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            currentMileage: mileageValue,
            engineHours: hoursValue,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            expectedFuelConsumption: Double(normalizedExpected) ?? 0,
            imageData: imageData,
            extraPhotoData: extraPhotoData
        )
        modelContext.insert(vehicle)
        modelContext.insert(MileageEntry(vehicleID: vehicle.id, mileage: mileageValue, engineHours: hoursValue))

        if addTemplates {
            [
                "Моторное масло и фильтр",
                "Воздушный фильтр",
                "Салонный фильтр",
                "Свечи зажигания",
                "Тормозная жидкость",
                "Ремень / цепь ГРМ"
            ].forEach { title in
                modelContext.insert(MaintenanceTask(
                    vehicleID: vehicle.id,
                    title: title,
                    intervalMonths: 0,
                    lastEngineHours: hoursValue,
                    lastMileage: mileageValue
                ))
            }
        }

        do { try modelContext.save(); dismiss() }
        catch { modelContext.rollback(); errorMessage = "Не удалось сохранить автомобиль: \(error.localizedDescription)" }
    }
}


private extension DueState {
    var sortPriority: Int {
        switch self {
        case .overdue: 0
        case .soon: 1
        case .good: 2
        case .notConfigured: 3
        }
    }
}
