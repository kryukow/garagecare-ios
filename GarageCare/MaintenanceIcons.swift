import SwiftUI

/// Stable identifiers for vector maintenance glyphs. The icon itself is never saved as an image.
struct MaintenanceIconDescriptor: Identifiable, Hashable {
    let id: String
    let title: String
    let section: String
}


/// A UI-only grouping: the original iconKey is preserved for old records/backups.
struct MaintenanceSymbolCategory: Identifiable, Hashable {
    let id: String
    let title: String
    let symbolName: String
    let representativeKey: String
}

enum MaintenanceIcons {
    static let catalog: [MaintenanceIconDescriptor] = [
        .init(id: "oil", title: "Моторное масло", section: "Двигатель"),
        .init(id: "oilFilter", title: "Масляный фильтр", section: "Фильтры"),
        .init(id: "airFilter", title: "Воздушный фильтр", section: "Фильтры"),
        .init(id: "cabinFilter", title: "Салонный фильтр", section: "Фильтры"),
        .init(id: "fuelFilter", title: "Топливный фильтр", section: "Фильтры"),
        .init(id: "lpgFilter", title: "Газовый фильтр", section: "Фильтры"),
        .init(id: "spark", title: "Свечи зажигания", section: "Зажигание"),
        .init(id: "ignition", title: "Катушка / провода", section: "Зажигание"),
        .init(id: "battery", title: "Аккумулятор", section: "Электрика"),
        .init(id: "bulb", title: "Лампочки", section: "Электрика"),
        .init(id: "brakePads", title: "Тормозные колодки", section: "Тормоза"),
        .init(id: "brakeDiscs", title: "Тормозные диски", section: "Тормоза"),
        .init(id: "brakeFluid", title: "Тормозная жидкость", section: "Жидкости"),
        .init(id: "coolant", title: "Антифриз", section: "Жидкости"),
        .init(id: "otherFluid", title: "Прочие жидкости", section: "Жидкости"),
        .init(id: "belt", title: "Ремень / ГРМ", section: "Привод"),
        .init(id: "timingChain", title: "Цепь ГРМ", section: "Привод"),
        .init(id: "roller", title: "Ролики", section: "Привод"),
        .init(id: "wiper", title: "Дворники", section: "Кузов"),
        .init(id: "wheel", title: "Колёса / шины", section: "Ходовая"),
        .init(id: "bearing", title: "Подшипник", section: "Ходовая"),
        .init(id: "shock", title: "Амортизатор", section: "Ходовая"),
        .init(id: "spring", title: "Пружина", section: "Ходовая"),
        .init(id: "steering", title: "Рулевое управление", section: "Ходовая"),
        .init(id: "gasket", title: "Прокладки", section: "Двигатель"),
        .init(id: "clutch", title: "Сцепление", section: "Трансмиссия"),
        .init(id: "gearbox", title: "КПП / редуктор", section: "Трансмиссия"),
        .init(id: "exhaust", title: "Выхлоп", section: "Двигатель"),
        .init(id: "fuelSystem", title: "Топливная система", section: "Топливо"),
        .init(id: "lpg", title: "ГБО / газ", section: "Топливо"),
        .init(id: "engine", title: "Двигатель", section: "Двигатель"),
        .init(id: "ac", title: "Кондиционер", section: "Климат"),
        .init(id: "other", title: "Другая работа", section: "Другое")
    ]

    // Legacy work keys remain valid for SwiftData and historical JSON backups.
    // The UI presents a smaller set of consistent SF Symbol categories.

    static let categories: [MaintenanceSymbolCategory] = [
        .init(id: "engine", title: "Двигатель", symbolName: "engine.combustion.fill", representativeKey: "engine"),
        .init(id: "filters", title: "Фильтры", symbolName: "line.3.horizontal.decrease.circle.fill", representativeKey: "airFilter"),
        .init(id: "electrical", title: "Зажигание и электрика", symbolName: "bolt.fill", representativeKey: "spark"),
        .init(id: "brakes", title: "Тормоза", symbolName: "circle.circle.fill", representativeKey: "brakeDiscs"),
        .init(id: "wheels", title: "Колёса и шины", symbolName: "circle.hexagongrid.fill", representativeKey: "wheel"),
        .init(id: "transmission", title: "Трансмиссия и ГРМ", symbolName: "gearshape.2.fill", representativeKey: "belt"),
        .init(id: "suspension", title: "Подвеска и рулевое", symbolName: "car.side.fill", representativeKey: "shock"),
        .init(id: "fluids", title: "Масло и жидкости", symbolName: "drop.fill", representativeKey: "oil"),
        .init(id: "lighting", title: "Освещение", symbolName: "lightbulb.fill", representativeKey: "bulb"),
        .init(id: "fuel", title: "ГБО и топливная система", symbolName: "fuelpump.fill", representativeKey: "lpg"),
        .init(id: "climate", title: "Кондиционер и климат", symbolName: "wind", representativeKey: "ac"),
        .init(id: "other", title: "Прочие работы", symbolName: "wrench.and.screwdriver.fill", representativeKey: "other")
    ]

    /// No migration: both automatic and manually saved legacy icon keys resolve to a
    /// predictable category. A user choosing a category stores its existing representative key.
    static func categoryID(for key: String) -> String {
        switch key {
        case "engine", "gasket", "exhaust": return "engine"
        case "oilFilter", "airFilter", "cabinFilter", "fuelFilter", "lpgFilter": return "filters"
        case "spark", "ignition", "battery": return "electrical"
        case "brakePads", "brakeDiscs": return "brakes"
        case "wheel", "bearing": return "wheels"
        case "belt", "timingChain", "roller", "clutch", "gearbox": return "transmission"
        case "shock", "spring", "steering": return "suspension"
        case "oil", "brakeFluid", "coolant", "otherFluid": return "fluids"
        case "bulb": return "lighting"
        case "fuelSystem", "lpg": return "fuel"
        case "ac": return "climate"
        default: return "other"
        }
    }

    static func category(for key: String) -> MaintenanceSymbolCategory {
        let categoryID = categoryID(for: key)
        return categories.first(where: { $0.id == categoryID })!
    }

    static func descriptor(for key: String) -> MaintenanceIconDescriptor? {
        catalog.first(where: { $0.id == key })
    }

    static func resolved(title: String, manualKey: String?) -> String {
        if let manualKey, descriptor(for: manualKey) != nil { return manualKey }
        return suggested(for: title)
    }

    /// Ordered from specific subjects to generic ones: "масляный фильтр" must not become "масло".
    /// No network, AI service or user data is needed for recognition.
    static func suggested(for title: String) -> String {
        let locale = Locale(identifier: "ru_RU")
        func normalized(_ value: String) -> String {
            value.folding(options: [.caseInsensitive, .diacriticInsensitive],
                          locale: locale).lowercased()
        }
        let text = normalized(title)
        // Normalize BOTH sides: diacritic folding also changes Cyrillic "й" to "и".
        func has(_ needles: String...) -> Bool {
            needles.contains { text.contains(normalized($0)) }
        }
        if has("cabin filter", "pollenfilter", "innenraumfilter") ||
           (has("салон", "cabin") && has("фильтр", "filter")) { return "cabinFilter" }
        if (has("газ", "гбо", "lpg", "cng", "gas") && has("фильтр", "filter")) { return "lpgFilter" }
        if has("маслян", "масляный фильтр", "oil filter", "olfilter") { return "oilFilter" }
        if has("воздушн", "air filter", "luftfilter") { return "airFilter" }
        if has("топливн", "fuel filter", "kraftstofffilter", "dieselfilter") &&
            has("фильтр", "filter") { return "fuelFilter" }
        if has("цепь грм", "цепи грм", "цепь", "timing chain", "steuerkette") { return "timingChain" }
        if has("ролик", "натяжител", "spannrolle", "idler pulley") { return "roller" }
        if has("ремень", "грм", "belt", "riemen", "zahnriemen") { return "belt" }
        if has("тормозн", "brake", "bremse") && has("жидк", "fluid", "flussigkeit") { return "brakeFluid" }
        if has("колодк", "pads", "belage", "bremsbelag") { return "brakePads" }
        if has("тормозн", "brake", "brems") && has("диск", "disc", "scheib") { return "brakeDiscs" }
        if has("антифриз", "охлаждающ", "coolant", "kuhlmittel", "frostschutz") { return "coolant" }
        if has("гур", "жидк", "fluid", "hydraulikol", "servo oil") { return "otherFluid" }
        if has("свеч", "spark plug", "zundkerz") { return "spark" }
        if has("катуш", "бронепровод", "высоковольтн", "ignition coil", "zundspul", "zundkabel") { return "ignition" }
        if has("аккумулятор", "battery", "batterie", "акб") { return "battery" }
        if has("ламп", "освещен", "light bulb", "scheinwerfer", "leuchtmittel", "фар") { return "bulb" }
        if has("дворник", "щетк стекл", "щёток стекл", "wiper", "wischer") { return "wiper" }
        if has("подшипник", "bearing", "radlager") { return "bearing" }
        if has("амортизатор", "стойк", "shock", "dampfer", "federbein") { return "shock" }
        if has("пружин", "spring", "feder") { return "spring" }
        if has("шин", "колес", "колёс", "резин", "tire", "tyre", "reifen", "radwechsel") { return "wheel" }
        if has("рулев", "рейк", "наконечник", "spurstange", "lenkung") { return "steering" }
        if has("проклад", "сальник", "уплотн", "gasket", "dichtung") { return "gasket" }
        if has("сцеплен", "clutch", "kupplung") { return "clutch" }
        if has("коробк", "кпп", "редуктор", "getriebe", "gearbox") { return "gearbox" }
        if has("выхлоп", "глушител", "катализатор", "exhaust", "auspuff") { return "exhaust" }
        if has("форсунк", "бензонасос", "топливн", "fuel pump", "injector", "einspritz") { return "fuelSystem" }
        if has("гбо", "lpg", "cng", "газов", "газовая", "verdampfer") { return "lpg" }
        if has("кондиционер", "климат", "компрессор", "air conditioning", "klimaanlage") { return "ac" }
        if has("масло", "oil", "motorol", "ölwechsel", "масл") { return "oil" }
        if has("двигател", "мотор", "engine", "motor") { return "engine" }
        if has("тормоз", "brake", "brems") { return "brakePads" }
        if has("фильтр", "filter") { return "airFilter" }
        return "other"
    }
}


/// Drawn by iOS, not custom paths or generated PNGs. The rendering weight,
/// corner geometry, and baseline are supplied consistently by SF Symbols.
struct MaintenanceGlyph: View {
    let key: String
    var color: Color = .garageGreen

    var body: some View {
        Image(systemName: MaintenanceIcons.category(for: key).symbolName)
            .font(.system(size: 25, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}

struct MaintenanceGlyphTile: View {
    let key: String
    var color: Color = .garageGreen
    var side: CGFloat = 44

    var body: some View {
        Image(systemName: MaintenanceIcons.category(for: key).symbolName)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .frame(width: side * 0.48, height: side * 0.48)
            .frame(width: side, height: side)
            .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: side * 0.26,
                                                                  style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Choose one of the 12 categories or restore auto-inference by work title.
/// Legacy manually selected part keys remain accepted and highlight their category.
struct MaintenanceIconPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String?
    let title: String

    private let columns = [GridItem(.adaptive(minimum: 118), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button {
                        selection = nil
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            MaintenanceGlyphTile(key: MaintenanceIcons.suggested(for: title), side: 48)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Автоматически")
                                    .font(.headline)
                                Text("По названию работы")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selection == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.garageGreen)
                            }
                        }
                        .padding(12)
                        .garageCard(cornerRadius: 17)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("maintenance.icon.auto")

                    Text("КАТЕГОРИИ ОБСЛУЖИВАНИЯ")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(MaintenanceIcons.categories) { item in
                            Button {
                                selection = item.representativeKey
                                dismiss()
                            } label: {
                                VStack(spacing: 9) {
                                    ZStack(alignment: .topTrailing) {
                                        MaintenanceGlyphTile(key: item.representativeKey, side: 58)
                                        if let selection,
                                           MaintenanceIcons.categoryID(for: selection) == item.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.garageGreen)
                                                .background(Color.black, in: Circle())
                                                .offset(x: 7, y: -5)
                                        }
                                    }
                                    Text(item.title)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.85)
                                        .frame(maxWidth: .infinity)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 103)
                                .padding(.horizontal, 4)
                                .background(Color.garageSurface,
                                            in: RoundedRectangle(cornerRadius: 15))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.title)
                            .accessibilityIdentifier("maintenance.icon.\(item.id)")
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.garageBackground)
            .navigationTitle("Символ работы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}
