import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    private enum SettingsAlert: Identifiable {
        case confirmImport
        case message(String)

        var id: String {
            switch self {
            case .confirmImport:
                return "confirmImport"
            case .message(let text):
                return "message-\(text)"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext

    @Query private var vehicles: [Vehicle]
    @Query private var tasks: [MaintenanceTask]
    @Query private var records: [ServiceRecord]
    @Query private var mileageEntries: [MileageEntry]
    @Query private var fuelEntries: [FuelEntry]

    @AppStorage("warningKm") private var warningKm = 1_000
    @AppStorage("warningEngineHours") private var warningEngineHours = 10.0
    @AppStorage("mileageReminderDays") private var mileageReminderDays = 30
    @AppStorage("appearanceMode") private var appearanceMode = AppAppearance.system.rawValue

    @State private var notificationsAllowed = false
    @State private var exportDocument = BackupDocument()
    @State private var csvDocument = CSVDocument()
    @State private var showingExporter = false
    @State private var showingCSVExporter = false
    @State private var showingImporter = false
    @State private var importedPayload: BackupPayload?
    @State private var activeAlert: SettingsAlert?

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        "За \(Formatters.mileage(warningKm))",
                        value: $warningKm,
                        in: 0...10_000,
                        step: 250
                    )

                    Stepper(
                        "За \(Formatters.engineHours(warningEngineHours))",
                        value: $warningEngineHours,
                        in: 0...100,
                        step: 5
                    )
                } header: {
                    Text("Предупреждать заранее")
                } footer: {
                    Text("Расчёт обновляется после внесения нового пробега или моточасов.")
                }

                Section("Ввод пробега") {
                    Stepper(
                        mileageReminderDays == 0
                            ? "Напоминание выключено"
                            : "Напоминать через \(mileageReminderDays) дн.",
                        value: $mileageReminderDays,
                        in: 0...90,
                        step: 5
                    )
                }

                Section("Оформление") {
                    Picker("Тема", selection: $appearanceMode) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Уведомления") {
                    Button {
                        Task {
                            notificationsAllowed = await NotificationManager.shared.requestAuthorization()

                            if notificationsAllowed {
                                refreshAllNotifications()
                            }
                        }
                    } label: {
                        Label("Разрешить уведомления", systemImage: "bell.badge")
                    }

                    if notificationsAllowed {
                        Label("Уведомления разрешены", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.garageGreen)
                    }
                }

                Section {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Создать копию в iCloud Drive", systemImage: "icloud.and.arrow.up")
                    }

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Восстановить из файла", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        prepareCSVExport()
                    } label: {
                        Label("Экспортировать историю CSV", systemImage: "tablecells")
                    }
                } header: {
                    Text("Резервная копия")
                } footer: {
                    Text("Системное окно «Файлы» позволит сохранить копию в iCloud Drive или локально. В копию входят автомобили, работы, пробег, заправки, расходы и фотографии.")
                }

                Section("О приложении") {
                    LabeledContent("Название", value: "Мой гараж")
                    LabeledContent("Версия", value: appVersion)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.garageBackground)
            .navigationTitle("Настройки")
            .task {
                notificationsAllowed = await NotificationManager.shared.authorizationGranted()
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "GarageCare-backup.json"
            ) { result in
                switch result {
                case .success:
                    activeAlert = .message("Резервная копия сохранена.")
                case .failure(let error):
                    activeAlert = .message("Не удалось экспортировать: \(error.localizedDescription)")
                }
            }
            .fileExporter(
                isPresented: $showingCSVExporter,
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "GarageCare-history.csv"
            ) { result in
                if case .failure(let error) = result {
                    activeAlert = .message("Не удалось экспортировать CSV: \(error.localizedDescription)")
                }
            }
            .sheet(isPresented: $showingImporter) {
                BackupFilePicker { result in
                    showingImporter = false

                    // Сначала полностью закрываем системный проводник,
                    // затем читаем файл и показываем подтверждение восстановления.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        switch result {
                        case .success(let url):
                            importFile(.success(url))
                        case .failure(let error):
                            importFile(.failure(error))
                        }
                    }
                }
                .ignoresSafeArea()
            }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .confirmImport:
                    return Alert(
                        title: Text("Восстановить резервную копию?"),
                        message: Text("Текущие данные приложения будут заменены данными из файла."),
                        primaryButton: .destructive(Text("Заменить данные")) {
                            restoreImportedData()
                        },
                        secondaryButton: .cancel(Text("Отмена")) {
                            importedPayload = nil
                        }
                    )

                case .message(let text):
                    return Alert(
                        title: Text("Сообщение"),
                        message: Text(text),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
    }

    private func prepareCSVExport() {
        csvDocument = CSVDocument(
            text: HistoryCSVExporter.makeCSV(
                vehicles: vehicles,
                records: records,
                fuelEntries: fuelEntries
            )
        )
        showingCSVExporter = true
    }

    private func prepareExport() {
        let payload = BackupPayload(
            version: 3,
            exportedAt: .now,
            vehicles: vehicles.map(VehicleSnapshot.init),
            tasks: tasks.map(TaskSnapshot.init),
            records: records.map(RecordSnapshot.init),
            mileageEntries: mileageEntries.map(MileageSnapshot.init),
            fuelEntries: fuelEntries.map(FuelSnapshot.init)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            exportDocument = BackupDocument(data: try encoder.encode(payload))
            showingExporter = true
        } catch {
            activeAlert = .message("Не удалось подготовить копию: \(error.localizedDescription)")
        }
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()

            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let payload = try decoder.decode(BackupPayload.self, from: data)

            guard (1...3).contains(payload.version) else {
                activeAlert = .message("Эта версия резервной копии не поддерживается.")
                return
            }

            importedPayload = payload
            activeAlert = .confirmImport
        } catch {
            activeAlert = .message("Не удалось прочитать файл: \(error.localizedDescription)")
        }
    }

    private func restoreImportedData() {
        guard let payload = importedPayload else { return }

        fuelEntries.forEach { modelContext.delete($0) }
        mileageEntries.forEach { modelContext.delete($0) }
        records.forEach { modelContext.delete($0) }
        tasks.forEach { modelContext.delete($0) }
        vehicles.forEach { modelContext.delete($0) }

        payload.vehicles.forEach { value in
            modelContext.insert(
                Vehicle(
                    id: value.id,
                    make: value.make,
                    model: value.model,
                    year: value.year,
                    vin: value.vin,
                    currentMileage: value.currentMileage,
                    currentEngineHours: value.currentEngineHours ?? 0,
                    notes: value.notes,
                    expectedFuelConsumption: value.expectedFuelConsumption ?? 0,
                    imageData: value.imageData,
                    createdAt: value.createdAt
                )
            )
        }

        payload.tasks.forEach { value in
            modelContext.insert(
                MaintenanceTask(
                    id: value.id,
                    vehicleID: value.vehicleID,
                    title: value.title,
                    intervalKm: value.intervalKm,
                    intervalMonths: 0,
                    intervalEngineHours: value.intervalEngineHours ?? 0,
                    lastMileage: value.lastMileage,
                    lastEngineHours: value.lastEngineHours ?? 0,
                    lastDate: value.lastDate,
                    notes: value.notes,
                    createdAt: value.createdAt
                )
            )
        }

        payload.records.forEach { value in
            modelContext.insert(
                ServiceRecord(
                    id: value.id,
                    vehicleID: value.vehicleID,
                    taskID: value.taskID,
                    title: value.title,
                    mileage: value.mileage,
                    engineHours: value.engineHours ?? 0,
                    date: value.date,
                    cost: value.cost,
                    currency: value.currency,
                    notes: value.notes
                )
            )
        }

        payload.mileageEntries.forEach { value in
            modelContext.insert(
                MileageEntry(
                    id: value.id,
                    vehicleID: value.vehicleID,
                    mileage: value.mileage,
                    engineHours: value.engineHours ?? 0,
                    date: value.date
                )
            )
        }

        (payload.fuelEntries ?? []).forEach { value in
            modelContext.insert(
                FuelEntry(
                    id: value.id,
                    vehicleID: value.vehicleID,
                    date: value.date,
                    mileage: value.mileage,
                    liters: value.liters,
                    amount: value.amount,
                    currency: value.currency,
                    isFullTank: value.isFullTank,
                    notes: value.notes
                )
            )
        }

        do {
            try modelContext.save()
            importedPayload = nil
            activeAlert = .message("Данные восстановлены.")
        } catch {
            activeAlert = .message("Не удалось восстановить данные: \(error.localizedDescription)")
        }
    }

    private func refreshAllNotifications() {
        for vehicle in vehicles {
            NotificationManager.shared.refresh(
                vehicle: vehicle,
                tasks: tasks.filter { $0.vehicleID == vehicle.id },
                warningKm: warningKm,
                warningEngineHours: warningEngineHours
            )

            let lastUpdate = mileageEntries
                .filter { $0.vehicleID == vehicle.id }
                .map(\.date)
                .max() ?? .now

            NotificationManager.shared.scheduleMileageEntryReminder(
                vehicle: vehicle,
                lastUpdate: lastUpdate,
                afterDays: mileageReminderDays
            )
        }
    }
}


private struct BackupFilePicker: UIViewControllerRepresentable {
    let completion: (Result<URL, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.json, .plainText, .data],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let completion: (Result<URL, Error>) -> Void

        init(completion: @escaping (Result<URL, Error>) -> Void) {
            self.completion = completion
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            guard let url = urls.first else {
                completion(.failure(BackupImportError.noFileSelected))
                return
            }
            completion(.success(url))
        }
    }
}

private enum BackupImportError: LocalizedError {
    case noFileSelected

    var errorDescription: String? {
        switch self {
        case .noFileSelected:
            return "Файл не выбран."
        }
    }
}
