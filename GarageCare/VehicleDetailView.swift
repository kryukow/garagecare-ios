import PhotosUI
import SwiftData
import SwiftUI

struct VehicleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var vehicle: Vehicle
    @Query private var tasks: [MaintenanceTask]

    @AppStorage("warningKm") private var warningKm = 1_000
    @AppStorage("warningEngineHours") private var warningEngineHours = 10.0
    @AppStorage("taskLayoutMode") private var taskLayoutMode = "grid"

    private enum ActiveModal: String, Identifiable {
        case mileage
        case addTask
        case editVehicle

        var id: String { rawValue }
    }

    @State private var activeModal: ActiveModal?
    @State private var selectedTask: MaintenanceTask?

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        let vehicleID = vehicle.id
        _tasks = Query(
            filter: #Predicate<MaintenanceTask> { $0.vehicleID == vehicleID },
            sort: [SortDescriptor(\MaintenanceTask.createdAt)]
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                GarageScreenBackground()

                ScrollView(.vertical) {
                    VStack(spacing: 18) {
                        VehicleHero(vehicle: vehicle)

                        mileageCard

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
                                ForEach(tasks) { task in
                                    Button {
                                        selectedTask = task
                                    } label: {
                                        TaskListRow(
                                            task: task,
                                            currentMileage: vehicle.currentMileage,
                                            currentEngineHours: vehicle.currentEngineHours,
                                            warningKm: warningKm,
                                            warningEngineHours: warningEngineHours
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
                                            currentEngineHours: vehicle.currentEngineHours,
                                            warningKm: warningKm,
                                            warningEngineHours: warningEngineHours
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
            }
        }
    }

    private var mileageCard: some View {
        Button {
            activeModal = .mileage
        } label: {
            ZStack(alignment: .trailing) {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.garageGreen.opacity(0.035),
                        Color.garageGreen.opacity(0.13)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 175)
                .allowsHitTesting(false)

                HStack(spacing: 14) {
                    Image(systemName: "road.lanes")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(Color.garageGreen)
                        .frame(width: 54, height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.garageGreen.opacity(0.11))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.garageGreen.opacity(0.16), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("ТЕКУЩИЙ ПРОБЕГ")
                            .font(.caption2.weight(.bold))
                            .tracking(1.0)
                            .foregroundStyle(.secondary)

                        Text(Formatters.mileage(vehicle.currentMileage))
                            .font(.title2.bold())
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 2)
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .garageCard(cornerRadius: 22)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Обновить пробег и моточасы")
    }

}

private struct VehicleHero: View {
    let vehicle: Vehicle

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { proxy in
                vehicleImage
                    .frame(width: proxy.size.width, height: 218)
                    .clipped()
            }
            .frame(height: 218)

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.82)],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(vehicle.displayName.isEmpty ? "Автомобиль" : vehicle.displayName)
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    HStack(spacing: 9) {
                        if vehicle.year > 0 {
                            Text(String(vehicle.year))
                        }
                        if !vehicle.vin.isEmpty {
                            Text("VIN • \(String(vehicle.vin.suffix(6)))")
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                GarageStatusPill(
                    title: "АКТИВЕН",
                    color: .garageGreen,
                    systemImage: "checkmark"
                )
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: 218, maxHeight: 218)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.30), radius: 20, y: 10)
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
                    colors: [Color.garageSurfaceRaised, Color.garageBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    colors: [Color.garageGreen.opacity(0.20), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "car.side.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.garageGreen)
                    .padding(48)
            }
        }
    }
}

private struct TaskCard: View {
    let task: MaintenanceTask
    let currentMileage: Int
    let currentEngineHours: Double
    let warningKm: Int
    let warningEngineHours: Double

    private var state: DueState {
        task.state(
            currentMileage: currentMileage,
            currentEngineHours: currentEngineHours,
            warningKm: warningKm,
            warningEngineHours: warningEngineHours
        )
    }

    private var progress: Double {
        task.displayProgress(
            currentMileage: currentMileage,
            currentEngineHours: currentEngineHours
        )
    }

    private var statusColor: Color {
        task.displayColor(
            currentMileage: currentMileage,
            currentEngineHours: currentEngineHours,
            warningKm: warningKm,
            warningEngineHours: warningEngineHours
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
                if let hours = task.engineHoursRemaining(currentEngineHours: currentEngineHours) {
                    Text(
                        hours >= 0
                            ? "\(Formatters.engineHours(hours)) осталось"
                            : "+\(Formatters.engineHours(abs(hours))) просрочено"
                    )
                }
                if task.intervalKm == 0 && task.intervalEngineHours == 0 {
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
    let warningEngineHours: Double

    private var state: DueState {
        task.state(
            currentMileage: currentMileage,
            currentEngineHours: currentEngineHours,
            warningKm: warningKm,
            warningEngineHours: warningEngineHours
        )
    }

    private var progress: Double {
        task.displayProgress(
            currentMileage: currentMileage,
            currentEngineHours: currentEngineHours
        )
    }

    private var color: Color {
        task.displayColor(
            currentMileage: currentMileage,
            currentEngineHours: currentEngineHours,
            warningKm: warningKm,
            warningEngineHours: warningEngineHours
        )
    }

    var body: some View {
        HStack(spacing: 13) {
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

                    if let hours = task.engineHoursRemaining(currentEngineHours: currentEngineHours) {
                        Label(
                            hours >= 0 ? Formatters.engineHours(hours) : "−\(Formatters.engineHours(abs(hours)))",
                            systemImage: "gauge.with.dots.needle.50percent"
                        )
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
        .padding(14)
        .background(
            LinearGradient(
                colors: [color.opacity(0.065), Color.garageSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(color.opacity(0.13), lineWidth: 1)
        }
    }
}

private struct UpdateMileageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let vehicle: Vehicle
    let tasks: [MaintenanceTask]

    @AppStorage("warningKm") private var warningKm = 1_000
    @AppStorage("warningEngineHours") private var warningEngineHours = 10.0
    @AppStorage("mileageReminderDays") private var mileageReminderDays = 30
    @State private var mileage = ""
    @State private var engineHours = ""
    @State private var date = Date.now
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Новые показания") {
                    LabeledContent("Пробег") {
                        TextField("Километры", text: $mileage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Моточасы") {
                        TextField("Не заданы", text: $engineHours)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
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
            .scrollContentBackground(.hidden)
            .background(Color.garageBackground)
            .navigationTitle("Обновить показания")
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
                engineHours = vehicle.currentEngineHours > 0
                    ? String(format: "%.1f", vehicle.currentEngineHours)
                    : ""
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

        let normalizedHours = engineHours.replacingOccurrences(of: ",", with: ".")
        let hoursValue = normalizedHours.isEmpty
            ? vehicle.currentEngineHours
            : (Double(normalizedHours) ?? -1)

        guard hoursValue >= vehicle.currentEngineHours else {
            errorMessage = "Моточасы не могут быть меньше текущего значения."
            return
        }

        vehicle.currentMileage = value
        vehicle.currentEngineHours = hoursValue
        modelContext.insert(
            MileageEntry(
                vehicleID: vehicle.id,
                mileage: value,
                engineHours: hoursValue,
                date: date
            )
        )
        try? modelContext.save()
        NotificationManager.shared.refresh(
            vehicle: vehicle,
            tasks: tasks,
            warningKm: warningKm,
            warningEngineHours: warningEngineHours
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
    @State private var photoItem: PhotosPickerItem?
    @State private var expectedConsumption = ""

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
                }

                Section {
                    TextField("л/100 км", text: $expectedConsumption)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Ожидаемый расход")
                } footer: {
                    Text("Необязательно. Используется как ориентир до появления фактической статистики по заправкам.")
                }

                Section("Фото") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Выбрать фото", systemImage: "photo")
                    }
                    if vehicle.imageData != nil {
                        Button("Удалить фото", role: .destructive) {
                            vehicle.imageData = nil
                        }
                    }
                }

                Section("Заметка") {
                    TextField("Текст", text: $vehicle.notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.garageBackground)
            .navigationTitle("Автомобиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        let normalized = expectedConsumption.replacingOccurrences(of: ",", with: ".")
                        vehicle.expectedFuelConsumption = Double(normalized) ?? 0
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                expectedConsumption = vehicle.expectedFuelConsumption > 0
                    ? String(format: "%.1f", vehicle.expectedFuelConsumption)
                    : ""
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        vehicle.imageData = data
                    }
                }
            }
        }
    }
}
