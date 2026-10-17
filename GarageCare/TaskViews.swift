import SwiftData
import SwiftUI

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle
    let task: MaintenanceTask

    @AppStorage("warningKm") private var warningKm = 1_000
    @AppStorage("warningEngineHours") private var warningEngineHours = 10.0

    @State private var records: [ServiceRecord] = []
    @State private var activeSheet: ActiveSheet?
    @State private var showingDeleteAlert = false

    private enum ActiveSheet: Int, Identifiable {
        case editor
        case completion

        var id: Int { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statusCard

                detailCard(title: "Интервал") {
                    LabeledContent("По пробегу") {
                        Text(task.intervalKm > 0 ? Formatters.mileage(task.intervalKm) : "Не задан")
                    }

                    Divider()

                    LabeledContent("По моточасам") {
                        Text(task.intervalEngineHours > 0 ? Formatters.engineHours(task.intervalEngineHours) : "Не задан")
                    }

                    Divider()

                    LabeledContent("Последняя работа") {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Formatters.mileage(task.lastMileage))
                            if task.lastEngineHours > 0 || task.intervalEngineHours > 0 {
                                Text(Formatters.engineHours(task.lastEngineHours))
                                    .foregroundStyle(.secondary)
                            }
                            Text(Formatters.russianDate(task.lastDate))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !task.notes.isEmpty {
                    detailCard(title: "Заметка") {
                        Text(task.notes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                detailCard(title: "История") {
                    if records.isEmpty {
                        Text("Выполненных работ пока нет")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(records) { record in
                                ServiceRecordRow(record: record)

                                if record.id != records.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                Button("Удалить работу", role: .destructive) {
                    showingDeleteAlert = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.garageRed.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.garageRed.opacity(0.16), lineWidth: 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color.garageBackground)
        .navigationTitle(task.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Изменить") {
                    activeSheet = .editor
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                activeSheet = .completion
            } label: {
                Label("Отметить выполненной", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.garageGreen)
            .foregroundStyle(Color.garageOnAccent)
            .padding()
            .background(.ultraThinMaterial)
        }
        .sheet(item: $activeSheet, onDismiss: loadRecords) { sheet in
            switch sheet {
            case .editor:
                TaskEditorView(vehicle: vehicle, task: task)
            case .completion:
                CompleteTaskView(vehicle: vehicle, task: task)
            }
        }
        .alert("Удалить работу?", isPresented: $showingDeleteAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                deleteTask()
            }
        } message: {
            Text("Связанная с ней история тоже будет удалена.")
        }
        .task {
            loadRecords()
        }
    }

    @ViewBuilder
    private func detailCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .garageCard(cornerRadius: 20)
    }

    private var statusCard: some View {
        let state = task.state(
            currentMileage: vehicle.currentMileage,
            currentEngineHours: vehicle.currentEngineHours,
            warningKm: warningKm,
            warningEngineHours: warningEngineHours
        )
        let safeProgress = task.displayProgress(
            currentMileage: vehicle.currentMileage,
            currentEngineHours: vehicle.currentEngineHours
        )
        let statusColor = task.displayColor(
            currentMileage: vehicle.currentMileage,
            currentEngineHours: vehicle.currentEngineHours,
            warningKm: warningKm,
            warningEngineHours: warningEngineHours
        )

        return VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                GarageStatusPill(
                    title: state.title.uppercased(),
                    color: statusColor,
                    systemImage: state == .overdue
                        ? "exclamationmark.triangle.fill"
                        : (state == .good ? "checkmark" : nil)
                )

                Spacer()

                if state != .notConfigured {
                    Text("\(Int((safeProgress * 100).rounded()))%")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(statusColor)
                }
            }

            GarageProgressBar(progress: safeProgress, color: statusColor)

            if task.intervalKm == 0 && task.intervalEngineHours == 0 {
                Text("Задай пробег или моточасы — после этого появится расчёт ресурса.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if let km = task.kilometersRemaining(currentMileage: vehicle.currentMileage) {
                        HStack(spacing: 7) {
                            Image(systemName: "road.lanes")
                                .foregroundStyle(statusColor)
                            Text(
                                km >= 0
                                    ? "Осталось \(Formatters.mileage(km))"
                                    : "Просрочено на \(Formatters.mileage(abs(km)))"
                            )
                        }
                    }

                    if let hours = task.engineHoursRemaining(currentEngineHours: vehicle.currentEngineHours) {
                        HStack(spacing: 7) {
                            Image(systemName: "gauge.with.dots.needle.50percent")
                                .foregroundStyle(statusColor)
                            Text(
                                hours >= 0
                                    ? "Осталось \(Formatters.engineHours(hours))"
                                    : "Просрочено на \(Formatters.engineHours(abs(hours)))"
                            )
                        }
                    }
                }
                .font(.subheadline.weight(.medium))
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [statusColor.opacity(0.10), Color.garageSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(statusColor.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 16, y: 8)
    }

    private func loadRecords() {
        let taskID = task.id
        let descriptor = FetchDescriptor<ServiceRecord>(
            predicate: #Predicate<ServiceRecord> { record in
                record.taskID == taskID
            }
        )

        do {
            records = try modelContext.fetch(descriptor)
                .sorted { $0.date > $1.date }
        } catch {
            records = []
        }
    }

    private func deleteTask() {
        loadRecords()
        NotificationManager.shared.cancelNotifications(for: task)
        records.forEach { modelContext.delete($0) }
        modelContext.delete(task)
        try? modelContext.save()
        dismiss()
    }
}

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let vehicle: Vehicle
    let task: MaintenanceTask?

    @AppStorage("warningKm") private var warningKm = 1_000
    @AppStorage("warningEngineHours") private var warningEngineHours = 10.0

    @State private var title: String
    @State private var intervalKm: String
    @State private var intervalEngineHours: String
    @State private var lastMileage: String
    @State private var lastEngineHours: String
    @State private var lastDate: Date
    @State private var notes: String

    init(vehicle: Vehicle, task: MaintenanceTask? = nil) {
        self.vehicle = vehicle
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _intervalKm = State(initialValue: task.map { $0.intervalKm > 0 ? String($0.intervalKm) : "" } ?? "")
        _intervalEngineHours = State(initialValue: task.map {
            $0.intervalEngineHours > 0 ? String(format: "%.1f", $0.intervalEngineHours) : ""
        } ?? "")
        _lastMileage = State(initialValue: String(task?.lastMileage ?? vehicle.currentMileage))
        let baselineHours = task?.lastEngineHours ?? vehicle.currentEngineHours
        _lastEngineHours = State(initialValue: baselineHours > 0 ? String(format: "%.1f", baselineHours) : "")
        _lastDate = State(initialValue: task?.lastDate ?? .now)
        _notes = State(initialValue: task?.notes ?? "")
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(lastMileage.filter(\.isNumber)) != nil &&
        ((Int(intervalKm.filter(\.isNumber)) ?? 0) > 0 ||
         (Double(intervalEngineHours.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Работа") {
                    TextField("Название", text: $title)
                }

                Section {
                    LabeledContent("Километры") {
                        TextField("Не задано", text: $intervalKm)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Моточасы") {
                        TextField("Не задано", text: $intervalEngineHours)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Интервал")
                } footer: {
                    Text("Можно задать пробег, моточасы или оба условия. Сработает первое достигнутое условие.")
                }

                Section("Последний раз выполнено") {
                    LabeledContent("Пробег") {
                        TextField("Пробег", text: $lastMileage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    if !intervalEngineHours.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        vehicle.currentEngineHours > 0 ||
                        !lastEngineHours.isEmpty {
                        LabeledContent("Моточасы") {
                            TextField("Не заданы", text: $lastEngineHours)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    DatePicker("Дата", selection: $lastDate, displayedComponents: .date)
                }

                Section("Заметка") {
                    TextField("Масло, артикулы, допуски и другое", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .garageKeyboardDismiss()
            .scrollContentBackground(.hidden)
            .background(Color.garageBackground)
            .navigationTitle(task == nil ? "Новая работа" : "Изменить работу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let kmInterval = Int(intervalKm.filter(\.isNumber)) ?? 0
        let hoursInterval = Double(intervalEngineHours.replacingOccurrences(of: ",", with: ".")) ?? 0
        let mileage = Int(lastMileage.filter(\.isNumber)) ?? vehicle.currentMileage
        let engineHours = Double(lastEngineHours.replacingOccurrences(of: ",", with: ".")) ?? 0

        let savedTask: MaintenanceTask
        if let task {
            task.title = cleanTitle
            task.intervalKm = kmInterval
            task.intervalMonths = 0
            task.intervalEngineHours = hoursInterval
            task.lastMileage = mileage
            task.lastEngineHours = engineHours
            task.lastDate = lastDate
            task.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            savedTask = task
        } else {
            let newTask = MaintenanceTask(
                vehicleID: vehicle.id,
                title: cleanTitle,
                intervalKm: kmInterval,
                intervalMonths: 0,
                intervalEngineHours: hoursInterval,
                lastMileage: mileage,
                lastEngineHours: engineHours,
                lastDate: lastDate,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(newTask)
            savedTask = newTask
        }
        try? modelContext.save()
        NotificationManager.shared.refresh(
            vehicle: vehicle,
            tasks: [savedTask],
            warningKm: warningKm,
            warningEngineHours: warningEngineHours
        )
        dismiss()
    }
}

private struct CompleteTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let vehicle: Vehicle
    let task: MaintenanceTask

    @AppStorage("warningKm") private var warningKm = 1_000
    @AppStorage("warningEngineHours") private var warningEngineHours = 10.0
    @AppStorage("mileageReminderDays") private var mileageReminderDays = 30
    @State private var mileage: String
    @State private var engineHours: String
    @State private var date = Date.now
    @State private var cost = ""
    @State private var currency = "EUR"
    @State private var notes = ""
    @State private var errorMessage: String?

    init(vehicle: Vehicle, task: MaintenanceTask) {
        self.vehicle = vehicle
        self.task = task
        _mileage = State(initialValue: String(vehicle.currentMileage))
        _engineHours = State(
            initialValue: vehicle.currentEngineHours > 0
                ? String(format: "%.1f", vehicle.currentEngineHours)
                : (task.lastEngineHours > 0 ? String(format: "%.1f", task.lastEngineHours) : "")
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(task.title) {
                    LabeledContent("Пробег") {
                        TextField("Пробег", text: $mileage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    if task.intervalEngineHours > 0 {
                        LabeledContent("Моточасы") {
                            TextField("Моточасы", text: $engineHours)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                }

                Section("Расходы") {
                    TextField("Сумма (необязательно)", text: $cost)
                        .keyboardType(.decimalPad)
                    Picker("Валюта", selection: $currency) {
                        Text("EUR").tag("EUR")
                        Text("UAH").tag("UAH")
                        Text("USD").tag("USD")
                        Text("RUB").tag("RUB")
                    }
                }

                Section("Заметка") {
                    TextField("Что установлено или сделано", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .garageKeyboardDismiss()
            .scrollContentBackground(.hidden)
            .background(Color.garageBackground)
            .navigationTitle("Работа выполнена")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                }
            }
        }
    }

    private func save() {
        guard let mileageValue = Int(mileage.filter(\.isNumber)) else {
            errorMessage = "Введи пробег цифрами."
            return
        }
        guard mileageValue >= task.lastMileage else {
            errorMessage = "Пробег не может быть меньше предыдущей работы."
            return
        }

        let normalizedCost = cost.replacingOccurrences(of: ",", with: ".")
        let engineHoursValue = Double(engineHours.replacingOccurrences(of: ",", with: ".")) ?? task.lastEngineHours

        if task.intervalEngineHours > 0, engineHoursValue < task.lastEngineHours {
            errorMessage = "Моточасы не могут быть меньше предыдущего значения."
            return
        }

        let record = ServiceRecord(
            vehicleID: vehicle.id,
            taskID: task.id,
            title: task.title,
            mileage: mileageValue,
            engineHours: engineHoursValue,
            date: date,
            cost: Double(normalizedCost) ?? 0,
            currency: currency,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(record)
        task.lastMileage = mileageValue
        task.lastEngineHours = engineHoursValue
        task.lastDate = date

        let updatedVehicleMileage = mileageValue > vehicle.currentMileage
        let updatedEngineHours = engineHoursValue > vehicle.currentEngineHours
        if updatedVehicleMileage || updatedEngineHours {
            vehicle.currentMileage = max(vehicle.currentMileage, mileageValue)
            vehicle.currentEngineHours = max(vehicle.currentEngineHours, engineHoursValue)
            modelContext.insert(
                MileageEntry(
                    vehicleID: vehicle.id,
                    mileage: vehicle.currentMileage,
                    engineHours: vehicle.currentEngineHours,
                    date: date
                )
            )
        }

        try? modelContext.save()
        NotificationManager.shared.refresh(
            vehicle: vehicle,
            tasks: [task],
            warningKm: warningKm,
            warningEngineHours: warningEngineHours
        )
        if updatedVehicleMileage || updatedEngineHours {
            NotificationManager.shared.scheduleMileageEntryReminder(
                vehicle: vehicle,
                lastUpdate: date,
                afterDays: mileageReminderDays
            )
        }
        dismiss()
    }
}

struct ServiceRecordRow: View {
    let record: ServiceRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.title)
                    .font(.headline)
                Spacer()
                Text(Formatters.russianDate(record.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text(Formatters.mileage(record.mileage))
                if record.engineHours > 0 {
                    Text(Formatters.engineHours(record.engineHours))
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if record.cost > 0 {
                Text(record.cost, format: .currency(code: record.currency))
                    .font(.subheadline.bold())
            }

            if !record.notes.isEmpty {
                Text(record.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
