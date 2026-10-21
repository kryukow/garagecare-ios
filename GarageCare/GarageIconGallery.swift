import SwiftUI

/// A local sandbox: changes here never alter saved service records.
struct GarageIconGallery: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = "Воздушный фильтр"
    @State private var manual: String?
    private var resolved: String { MaintenanceIcons.resolved(title: title, manualKey: manual) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Введите название работы — символ подберётся автоматически. Нажатие на любой символ включает ручной выбор в этом примере.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    TextField("Название работы", text: $title).textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("maintenance.gallery.title")
                    HStack(spacing: 14) {
                        MaintenanceGlyphTile(key: resolved, side: 58)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(MaintenanceIcons.descriptor(for: resolved)?.title ?? "Другая работа")
                            Text(manual == nil ? "Автоматический выбор" : "Ручной выбор").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button("Вернуть автоподбор") { manual = nil }.frame(minHeight: 44)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 14) {
                        ForEach(MaintenanceIcons.catalog) { item in
                            Button { manual = item.id } label: {
                                VStack(spacing: 8) {
                                    MaintenanceGlyphTile(key: item.id, side: 52)
                                    Text(item.title).font(.caption2).multilineTextAlignment(.center).frame(height: 32)
                                }.frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .garageCard(cornerRadius: 15)
                                    .overlay { RoundedRectangle(cornerRadius: 15).stroke(resolved == item.id ? Color.garageGreen : .clear, lineWidth: 1) }
                            }.buttonStyle(.plain).accessibilityLabel(item.title)
                        }
                    }
                }.padding(20)
            }.garageKeyboardDismiss().background(Color.garageBackground)
                .navigationTitle("Иконки работ · 33").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Закрыть") { dismiss() } } }
        }.tint(.garageGreen)
    }
}
