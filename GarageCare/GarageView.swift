import PhotosUI
import SwiftData
import SwiftUI

struct GarageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query(sort: \MaintenanceTask.createdAt) private var tasks: [MaintenanceTask]

    @AppStorage("warningKm") private var warningKm = 1_000
    @AppStorage("warningDays") private var warningDays = 7

    @AppStorage("graphiteSelectedVehicle") private var selectedVehicleID = ""
    @State private var showingGallery = false
    @State private var editingMileage = false
    @State private var editingDeadlines = false
    @State private var showingAddVehicle = false
    private var selectedVehicle: Vehicle? { vehicles.first { $0.id.uuidString == selectedVehicleID } ?? vehicles.first }

    @State private var vehicleToDelete: Vehicle?
    @State private var saveError: String?

    private var upcomingWorks: [UpcomingWork] {
        tasks.compactMap { task in
            guard (selectedVehicle == nil || task.vehicleID == selectedVehicle?.id),
                  task.intervalKm > 0 || task.intervalMonths > 0 || task.intervalEngineHours > 0,
                  let vehicle = vehicles.first(where: { $0.id == task.vehicleID }) else {
                return nil
            }
            return UpcomingWork(task: task, vehicle: vehicle)
        }
        .sorted { lhs, rhs in
            let lhsState = lhs.task.state(
                currentMileage: lhs.vehicle.currentMileage,
                warningKm: warningKm,
                warningDays: warningDays,
                currentEngineHours: lhs.vehicle.engineHours
            )
            let rhsState = rhs.task.state(
                currentMileage: rhs.vehicle.currentMileage,
                warningKm: warningKm,
                warningDays: warningDays,
                currentEngineHours: rhs.vehicle.engineHours
            )

            if lhsState.sortPriority != rhsState.sortPriority {
                return lhsState.sortPriority < rhsState.sortPriority
            }

            return lhs.task.displayProgress(currentMileage: lhs.vehicle.currentMileage, currentEngineHours: lhs.vehicle.engineHours)
                > rhs.task.displayProgress(currentMileage: rhs.vehicle.currentMileage, currentEngineHours: rhs.vehicle.engineHours)
        }
        .prefix(4)
        .map { $0 }
    }

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
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("МОЙ ГАРАЖ")
                                        .font(.caption.weight(.bold))
                                        .tracking(1.5)
                                        .foregroundStyle(Color.garageGreen)
                                    Text(vehicles.count == 1 ? "1 автомобиль" : "\(vehicles.count) авто")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 2)
                            .padding(.bottom, 2)

                            if let vehicle = selectedVehicle {
                                HStack {
                                    Menu {
                                        ForEach(vehicles) { car in
                                            Button(car.displayName) { selectedVehicleID = car.id.uuidString }
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Text(vehicle.displayName).font(.system(size: 27, weight: .light))
                                            if vehicles.count > 1 { Image(systemName: "chevron.down").font(.caption2) }
                                        }.foregroundStyle(.primary)
                                    }
                                    Spacer()
                                    NavigationLink { VehicleDetailView(vehicle: vehicle) } label: {
                                        Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                                    }.accessibilityLabel("Паспорт и обслуживание автомобиля")
                                }
                                .contextMenu { Button("Удалить автомобиль", role: .destructive) { vehicleToDelete = vehicle } }
                                GarageRoadScene().id(vehicle.id)
                                HStack {
                                    Text("• ЛИЧНЫЙ АВТОПАРК")
                                    Spacer()
                                    if vehicle.year > 0 { Text(String(vehicle.year)) }
                                }.font(.system(size: 9, design: .monospaced)).tracking(1.1).foregroundStyle(.secondary)
                                VehicleDeadlinesCard(vehicle: vehicle) { editingDeadlines = true }
                                GarageMileageSlab(vehicle: vehicle) { editingMileage = true }
                            }

                            if !upcomingWorks.isEmpty {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("БЛИЖАЙШИЕ РАБОТЫ")
                                            .font(.caption.weight(.bold))
                                            .tracking(1.4)
                                            .foregroundStyle(Color.garageGreen)
                                        Text("Что потребует внимания раньше всего")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.top, 8)

                                ForEach(upcomingWorks) { item in
                                    NavigationLink {
                                        TaskDetailView(vehicle: item.vehicle, task: item.task)
                                    } label: {
                                        UpcomingWorkRow(
                                            item: item,
                                            warningKm: warningKm,
                                            warningDays: warningDays
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Button { showingGallery = true } label: {
                                Label("Иконки работ · тест набора", systemImage: "square.grid.3x3")
                                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            }.buttonStyle(.plain).accessibilityIdentifier("garage.iconGallery")
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 28)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Мой гараж")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddVehicle = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Добавить автомобиль")
                }
            }
            .sheet(isPresented: $showingGallery) { GarageIconGallery() }
            .sheet(isPresented: $editingMileage) {
                if let vehicle = selectedVehicle { UpdateMileageView(vehicle: vehicle, tasks: tasks.filter { $0.vehicleID == vehicle.id }) }
            }
            .sheet(isPresented: $editingDeadlines) {
                if let vehicle = selectedVehicle { VehicleDeadlinesEditor(vehicle: vehicle) }
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

private struct VehicleCard: View {
    let vehicle: Vehicle

    var body: some View {
        HStack(spacing: 14) {
            vehicleImage
                .frame(width: 112, height: 88)
                .background(Color.garageSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 6) {
                    Text(vehicle.displayName.isEmpty ? "Автомобиль" : vehicle.displayName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 2)
                    if vehicle.year > 0 {
                        Text(String(vehicle.year))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.055), in: Capsule())
                    }
                }

                HStack(spacing: 7) {
                    Image(systemName: "road.lanes")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.garageGreen)

                    Text(Formatters.mileage(vehicle.currentMileage))
                        .monospacedDigit()
                }
                .font(.subheadline.weight(.medium))

                GarageDeadlineLabels(vehicle: vehicle)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .garageCard(cornerRadius: 24)
    }

    @ViewBuilder
    private var vehicleImage: some View {
        if let data = vehicle.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color.garageGreen.opacity(0.20), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "car.side.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(19)
                    .foregroundStyle(Color.garageGreen)
            }
        }
    }
}

private struct UpcomingWork: Identifiable {
    let task: MaintenanceTask
    let vehicle: Vehicle

    var id: UUID { task.id }
}

private struct UpcomingWorkRow: View {
    let item: UpcomingWork
    let warningKm: Int
    let warningDays: Int

    private var state: DueState {
        item.task.state(
            currentMileage: item.vehicle.currentMileage,
            warningKm: warningKm,
            warningDays: warningDays,
            currentEngineHours: item.vehicle.engineHours
        )
    }

    private var color: Color {
        item.task.displayColor(
            currentMileage: item.vehicle.currentMileage,
            warningKm: warningKm,
            warningDays: warningDays,
            currentEngineHours: item.vehicle.engineHours
        )
    }

    var body: some View {
        HStack(spacing: 13) {
            MaintenanceGlyphTile(key: MaintenanceIcons.resolved(title: item.task.title, manualKey: item.task.iconKey), color: color, side: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.task.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(item.vehicle.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    if let km = item.task.kilometersRemaining(currentMileage: item.vehicle.currentMileage) {
                        Label(
                            km >= 0 ? Formatters.mileage(km) : "Просрочено \(Formatters.mileage(abs(km)))",
                            systemImage: "road.lanes"
                        )
                    }

                    if let hours = item.task.engineHoursRemaining(currentEngineHours: item.vehicle.engineHours) {
                        Label(String(format: hours >= 0 ? "%.1f мч" : "−%.1f мч", abs(hours)), systemImage: "gauge.with.dots.needle.50percent")
                    }
                    if let days = item.task.daysRemaining() {
                        Label(
                            days >= 0 ? "\(days) дн." : "−\(abs(days)) дн.",
                            systemImage: "calendar"
                        )
                    }
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(color)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.garageStroke).frame(height: 0.5) }

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
