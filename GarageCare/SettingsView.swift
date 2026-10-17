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
    @AppStorage("warningDays") private var warningDays = 7
    @AppStorage("warningEngineHours") private var warningEngineHours = 10.0
    @AppStorage("mileageReminderDays") private var mileageReminderDays = 30
    @AppStorage("appearanceMode") private var appearanceMode = AppAppearance.system.rawValue

    @State private var notificationsAllowed = false
    @State private var exportDocument = BackupDocument()
    @State private var csvDocument = CSVDocument()
    @State private var pdfDocument = PDFDocument()
    @State private var showingPDFExporter = false
    @State private var showingExporter = false
    @State private var showingCSVExporter = false
    @State private var showingImporter = false
    @State private var importedPayload: BackupPayload?
    @State private var activeAlert: SettingsAlert?

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.4.2"
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
                        "За \(warningDays) дн.",
                        value: $warningDays,
                        in: 0...60
                    )
                    Stepper(
                        "За \(Formatters.engineHours(warningEngineHours))",
                        value: $warningEngineHours,
                        in: 0...200,
                        step: 5
                    )
                } header: {
                    Text("Предупреждать заранее")
                } footer: {
                    Text("Расчёт по пробегу обновляется после внесения нового показания одометра.")
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
                        Label("Уведомлен…4545 tokens truncated… uiViewController: UIDocumentPickerViewController, context: Context) {}

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
