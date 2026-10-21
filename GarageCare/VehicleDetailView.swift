import PhotosUI
import SwiftData
import SwiftUI

struct VehicleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var vehicle: Vehicle
    @Query private var tasks: [MaintenanceTask]

    @AppStorage("warningKm") private var warningKm = 1_000
    @AppStorage("warningDays") private var warningDays = 7
    @AppStorage("taskLayoutMode") private var taskLayoutMode = "list"
    @AppStorage("taskListSortMode") private var taskListSortMode = TaskListSortMode.urgency.rawValue

    private enum ActiveModal: String, Identifiable {
        case mileage
        case addTask
        case editVehicle
        case deadlines

        var id: String { rawValue }
    }

    @State private var activeModal: ActiveModal?
    @State private var selectedTask: MaintenanceTask?
    @State private var showingVehiclePhotos = false
    @State private var selectedVehiclePhoto = 0

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        let vehicleID = vehicle.id
        _tasks = Query(
            filter: #Predicate<MaintenanceTask> { $0.vehicleID == vehicleID },
            sort: [SortDescriptor(\MaintenanceTask.createdAt)]
        )
    }

    private var sortedTasks: [MaintenanceTask] {
        TaskListSorter.sorted(
            tasks,
            mode: TaskListSortMode(rawValue: taskListSortMode) ?? .urgency,
            mileage: vehicle.currentMileage,
            engineHours: vehicle.engineHours,
            warningKm: warningKm,
            warningDays: warningDays
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                GarageScreenBackground()

                ScrollView(.vertical) {
                    VStack(spacing: 18) {
                        VehicleHero(vehicle: vehicle, onPhotoTap: {
                            if !GaragePhotoArchive.images(
                                primary: vehicle.imageData, additional: vehicle.extraPhotoData
                            ).isEmpty {
                                selectedVehiclePhoto = 0
                                showingVehiclePhotos = true
                            }
                        }, onMileageTap: {
                            activeModal = .mileage
                        })

                        VehicleDeadlinesCard(vehicle: vehicle) {
                            activeModal = .deadlines
                        }


                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("РЕГЛАМЕНТ")
                                    .font(.caption.weight(.bold))
                                    .tracking(1.4)
                                    .foregroundStyle(Color.garageGreen)
                                Text(tasks.isEmpty ? "Работ пока нет" : "\(tasks.count) работ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            HStack(spacing: 8) {
                                if taskLayoutMode == "list" {
                                    Menu {
                                        ForEach(TaskListSortMode.allCases) { mode in
                                            Button {
                                                withAnimation(.easeInOut(duration: 0.18)) {
                                                    taskListSortMode = mode.rawValue
                                                }
                                            } label: {
                                                if taskListSortMode == mode.rawValue {
                                                    Label(mode.title, systemImage: "checkmark")
                                                } else {
                                                    Text(mode.title)
                                                }
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(Color.garageGreen)
                                            .frame(width: 42, height: 40)
                                            .background(
                                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                    .fill(Color.garageGreen.opacity(0.10))
                                            )
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                    .stroke(Color.garageGreen.opacity(0.15), lineWidth: 1)
                                            }
                                    }
                                    .accessibilityLabel("Сортировка работ: \(TaskListSortMode(rawValue: taskListSortMode)?.title ?? "Сначала ближайшие")")
                                }

                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        taskLayoutMode = taskLayoutMode == "grid" ? "list" : "grid"
                                    }
                                } label: {
                                    Image(systemName: taskLayoutMode == "grid" ? "list.bullet" : "square.grid.2x2.fill")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Color.garageGreen)
                                        .frame(width: 42, height: 40)
                                        .background(
                                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                .fill(Color.garageGreen.opacity(0.10))
                                        )
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                .stroke(Color.garageGreen.opacity(0.15), lineWidth: 1)
                                        }
                                }
                                .accessibilityLabel(taskLayoutMode == "grid" ? "Показать списком" : "Показать плитками")

                                Button {
                                    activeModal = .addTask
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.headline.bold())
                                        .foregroundStyle(Color.garageOnAccent)
                                        .frame(width: 60, height: 40)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color.garageGreen)
                                        )
                                        .shadow(color: Color.garageGreen.opacity(0.24), radius: 9, y: 3)
                                }
                                .accessibilityLabel("Добавить работу")
                            }
                        }

                        if tasks.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.system(size: 34))
                                    .foregroundStyle(Color.garageGreen)
                                Text("Нет регламентных работ")
                                    .font(.headline)
                                Text("Добавь замену масла, фильтров или любую свою работу.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 210)
                            .padding(20)
                            .garageCard(cornerRadius: 22)
                        } else if taskLayoutMode == "list" {
                            LazyVStack(spacing: 10) {
                                ForEach(sortedTasks) { task in
                                    Button {
                                        selectedTask = task
                                    } label: {
                                        TaskListRow(
                                            task: task,
                                            currentMileage: vehicle.currentMileage,
                                            currentEngineHours: vehicle.engineHours,
                                            warningKm: warningKm,
                                            warningDays: warningDays
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(minimum: 0), spacing: 12),
                                    GridItem(.flexible(minimum: 0), spacing: 12)
                                ],
                                spacing: 12
                            ) {
                                ForEach(tasks) { task in
                                    Button {
                                        selectedTask = task
                                    } label: {
                                        TaskCard(
                                            task: task,
                                            currentMileage: vehicle.currentMileage,
                                            currentEngineHours: vehicle.engineHours,
                                            warningKm: warningKm,
                                            warningDays: warningDays
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .contentShape(Rectangle())
                                }
                            }
                        }
                    }
                    .frame(width: max(proxy.size.width - 32, 1))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle(vehicle.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeModal = .editVehicle
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Изменить автомобиль")
            }
        }
        .sheet(item: $selectedTask) { task in
            NavigationStack {
                TaskDetailView(vehicle: vehicle, task: task)
            }
        }
        .fullScreenCover(item: $activeModal) { modal in
            switch modal {
            case .mileage:
                UpdateMileageView(vehicle: vehicle, tasks: tasks)
            case .addTask:
                TaskEditorView(vehicle: vehicle)
            case .editVehicle:
                EditVehicleView(vehicle: vehicle)
            case .deadlines:
                VehicleDeadlinesEditor(vehicle: vehicle)
            }
        }
        .fullScreenCover(isPresented: $showingVehiclePhotos) {
            GaragePhotoViewer(
                images: GaragePhotoArchive.images(primary: vehicle.imageData, additional: vehicle.extraPhotoData),
                selectedIndex: $selectedVehiclePhoto
            )
        }
    }

}

private struct VehicleHero: View {
    let vehicle: Vehicle
    let onPhotoTap: () -> Void
    let onMileageTap: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.displayName).font(.title2.weight(.light))
                    if vehicle.year > 0 { Text(String(vehicle.year)).font(.caption.monospaced()).foregroundStyle(.secondary) }
                }
                Spacer()
                if vehicle.imageData != nil || vehicle.extraPhotoData != nil {
                    Button(action: onPhotoTap) { Image(systemName: "photo.on.rectangle").frame(width: 44, height: 44) }
                        .accessibilityLabel("Фотографии автомобиля")
                }
            }
            GarageRoadScene()
            GarageMileageSlab(vehicle: vehicle, edit: onMileageTap)
        }
    }
}

struct GarageMileageSlab: View {
    let vehicle: Vehicle
    let edit: () -> Void
    var body: some View {
        Button(action: edit) {
            HStack(spacing: 10) {
                Text("ПРОБЕГ").font(.system(size: 10, design: .monospaced)).tracking(1.4).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(vehicle.currentMileage.formatted(.number.grouping(.automatic).locale(Locale(identifier: "ru_RU"))))
                    .font(.system(size: 36, weight: .ultraLight)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                Text("км").font(.caption2.monospaced()).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "pencil").foregroundStyle(.secondary)
            }.foregroundStyle(.primary).padding(18).garageCard(cornerRadius: 20)
        }.buttonStyle(.plain).accessibilityLabel("Пробег \(vehicle.currentMileage) километров. Изменить")
    }
}

private struct TaskCard: View {
    let task: MaintenanceTask
    let currentMileage: Int
    let currentEngineHours: Double
    let warningKm: Int
    let warningDays: Int

    private var state: DueState {
        task.state(
            currentMileage: currentMileage,
            warningKm: warningKm,
            warningDays: warningDays,
            currentEngineHours: currentEngineHours
        )
    }

    private var progress: Double {
        task.displayProgress(currentMileage: currentMileage, currentEngineHours: currentEngineHours)
    }

    private var statusColor: Color {
        task.displayColor(
            currentMileage: currentMileage,
            warningKm: warningKm,
            warningDays: warningDays,
            currentEngineHours: currentEngineHours
        )
    }

    private var statusIcon: String {
        switch state {
        case .overdue: "exclamationmark.triangle.fill"
        case .soon: "clock.fill"
        case .good: "checkmark.circle.fill"
        case .notConfigured: "slider.horizontal.3"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 8) {
                MaintenanceGlyphTile(key: MaintenanceIcons.resolved(title: task.title, manualKey: task.iconKey), color: statusColor, side: 36)
                Text(task.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)

                Image(systemName: statusIcon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)
            }

            GarageProgressBar(progress: progress, color: statusColor)

            HStack {
                Text(state.title.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(statusColor)

                Spacer(minLength: 4)

                if state != .notConfigured {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                if let km = task.kilometersRemaining(currentMileage: currentMileage) {
                    Text(km >= 0 ? "\(Formatters.mileage(km)) осталось" : "+\(Formatters.mileage(abs(km))) просрочено")
                }
                if let days = task.daysRemaining() {
                    Text(days >= 0 ? "\(days) дн. осталось" : "+\(abs(days)) дн. просрочено")
                }
                if let hours = task.engineHoursRemaining(currentEngineHours: currentEngineHours) {
                    Text(String(format: hours >= 0 ? "%.1f мч осталось" : "+%.1f мч просрочено", abs(hours)))
                }
                if task.intervalKm == 0 && task.intervalMonths == 0 && task.intervalEngineHours == 0 {
                    Text("Интервал не задан")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 164, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [statusColor.opacity(0.075), Color.garageSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(statusColor.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.20), radius: 12, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct TaskListRow: View {
    let task: MaintenanceTask
    let currentMileage: Int
    let currentEngineHours: Double
    let warningKm: Int
    let warningDays: Int

    private var state: DueState {
        task.state(
            currentMileage: currentMileage,
            warningKm: warningKm,
            warningDays: warningDays,
            currentEngineHours: currentEngineHours
        )
    }

    private var progress: Double {
        task.displayProgress(currentMileage: currentMileage, currentEngineHours: currentEngineHours)
    }

    private var color: Color {
        task.displayColor(
            currentMileage: currentMileage,
            warningKm: warningKm,
            warningDays: warningDays,
            currentEngineHours: currentEngineHours
        )
    }

    var body: some View {
        HStack(spacing: 13) {
            MaintenanceGlyphTile(key: MaintenanceIcons.resolved(title: task.title, manualKey: task.iconKey), color: color, side: 44)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(task.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer()

                    GarageStatusPill(
                        title: state.title.uppercased(),
                        color: color
                    )
                }

                GarageProgressBar(progress: progress, color: color)

                HStack(spacing: 14) {
                    if let km = task.kilometersRemaining(currentMileage: currentMileage) {
                        Label(
                            km >= 0 ? "\(Formatters.mileage(km)) осталось" : "+\(Formatters.mileage(abs(km)))",
                            systemImage: "road.lanes"
                        )
                    }

                    if let days = task.daysRemaining() {
                        Label(
                            days >= 0 ? "\(days) дн." : "−\(abs(days)) дн.",
                            systemImage: "calendar"
                        )
                    }

                    if let hours = task.engineHoursRemaining(currentEngineHours: currentEngineHours) {
                        Label(String(format: hours >= 0 ? "%.1f мч" : "−%.1f мч", abs(hours)), systemImage: "gauge.with.dots.needle.50percent")
                    }
                    if state == .notConfigured {
                        Label("Интервал не задан", systemImage: "slider.horizontal.3")
                    }
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 17)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.garageStroke).frame(height: 0.5) }

    }
}

struct UpdateMileageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let vehicle: Vehicle
    let tasks: [MaintenanceTask]

    @AppStorage("warningKm") private var warningKm = 1_000
    @AppStorage("warningDays") private var warningDays = 7
    @AppStorage("mileageReminderDays") private var mileageReminderDays = 30
    @State private var mileage = ""
    @State private var engineHours = ""
    @State private var date = Date.now
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Новый пробег") {
                    LabeledContent("Пробег, км") {
                        TextField("Пробег", text: $mileage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if vehicle.engineHours > 0 || tasks.contains(where: { $0.intervalEngineHours > 0 }) {
                        LabeledContent("Моточасы, мч") {
                            TextField("Не заданы", text: $engineHours)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .garageKeyboardDismiss()
            .scrollContentBackground(.hidden)
            .background(Color.garageBackground)
            .navigationTitle("Обновить пробег")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                }
            }
            .onAppear {
                mileage = String(vehicle.currentMileage)
                engineHours = vehicle.engineHours > 0 ? String(format: "%.1f", vehicle.engineHours) : ""
            }
        }
    }

    private func save() {
        guard let value = Int(mileage.filter(\.isNumber)) else {
            errorMessage = "Введи пробег цифрами."
            return
        }
        guard value >= vehicle.currentMileage else {
            errorMessage = "Новый пробег не может быть меньше текущего."
            return
        }

        let normalizedHours = engineHours.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        let hours = normalizedHours.isEmpty ? vehicle.engineHours : (Double(normalizedHours) ?? -1)
        guard hours.isFinite, hours >= vehicle.engineHours else {
            errorMessage = "Моточасы не могут уменьшаться."
            return
        }
        vehicle.currentMileage = value
        vehicle.engineHours = hours
        modelContext.insert(MileageEntry(vehicleID: vehicle.id, mileage: value, engineHours: hours, date: date))
        do { try modelContext.save() }
        catch {
            modelContext.rollback()
            errorMessage = "Ошибка сохранения: \(error.localizedDescription)"
            return
        }
        NotificationManager.shared.refresh(
            vehicle: vehicle,
            tasks: tasks,
            warningKm: warningKm,
            warningDays: warningDays
        )
        NotificationManager.shared.scheduleMileageEntryReminder(
            vehicle: vehicle,
            lastUpdate: date,
            afterDays: mileageReminderDays
        )
        dismiss()
    }
}

private struct EditVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var vehicle: Vehicle
    @State private var imageData: Data?
    @State private var extraPhotoData: Data?
    @State private var photoLoading = false
    @State private var expectedConsumption = ""
    @State private var engineHours = ""
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Автомобиль") {
                    TextField("Марка", text: $vehicle.make)
                    TextField("Модель", text: $vehicle.model)
                    TextField("VIN", text: $vehicle.vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Stepper("Год: \(vehicle.year)", value: $vehicle.year, in: 1900...2100)
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
                    Text("Необязательно. Используется как ориентир до появления фактической статистики по заправкам.")
                }

                ServicePhotoField(
                    title: "Фото автомобиля", data: $imageData,
                    additionalData: $extraPhotoData, isLoading: $photoLoading
                )

                Section("Заметка") {
                    TextField("Текст", text: $vehicle.notes, axis: .vertical)
                        .lineLimit(2...6)
                }
                if let saveError { Text(saveError).foregroundStyle(.red) }
            }
            .garageKeyboardDismiss()
            .scrollContentBackground(.hidden)
            .background(Color.garageBackground)
            .navigationTitle("Автомобиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        guard !photoLoading else { return }
                        let normalized = expectedConsumption.replacingOccurrences(of: ",", with: ".")
                        vehicle.expectedFuelConsumption = Double(normalized) ?? 0
                        let normalizedHours = engineHours.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                        let hours = normalizedHours.isEmpty ? vehicle.engineHours : (Double(normalizedHours) ?? -1)
                        guard hours.isFinite, hours >= vehicle.engineHours else {
                            saveError = "Моточасы не могут уменьшаться или быть отрицательными."
                            return
                        }
                        vehicle.engineHours = hours
                        vehicle.imageData = imageData
                        vehicle.extraPhotoData = extraPhotoData
                        do { try modelContext.save(); dismiss() }
                        catch { saveError = error.localizedDescription }
                    }
                }
            }
            .onAppear {
                expectedConsumption = vehicle.expectedFuelConsumption > 0
                    ? String(format: "%.1f", vehicle.expectedFuelConsumption)
                    : ""
                engineHours = vehicle.engineHours > 0 ? String(format: "%.1f", vehicle.engineHours) : ""
                imageData = vehicle.imageData
                extraPhotoData = vehicle.extraPhotoData
            }
        }
    }
}
