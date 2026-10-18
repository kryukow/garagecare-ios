import SwiftUI

/// Stable identifiers for vector maintenance glyphs. The icon itself is never saved as an image.
struct MaintenanceIconDescriptor: Identifiable, Hashable {
    let id: String
    let title: String
    let section: String
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

    static let sections = [
        "Двигатель", "Фильтры", "Зажигание", "Электрика", "Тормоза",
        "Жидкости", "Привод", "Ходовая", "Трансмиссия", "Кузов",
        "Топливо", "Климат", "Другое"
    ]

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
        let text = title.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                 locale: Locale(identifier: "ru_RU")).lowercased()
        func has(_ needles: String...) -> Bool { needles.contains { text.contains($0) } }
        if has("салонн", "cabin filter", "pollenfilter", "innenraumfilter") { return "cabinFilter" }
        if has("газовый фильтр", "фильтр гбо", "фильтр газа", "lpg filter", "gasfilter") { return "lpgFilter" }
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

/// An all-vector, one-weight solid/outline hybrid. Each automotive component has its
/// own silhouette. Drawing uses a fixed 64x64 coordinate system for consistent scale.
struct MaintenanceGlyph: View {
    let key: String
    var color: Color = .garageGreen

    var body: some View {
        Canvas { context, size in
            var ctx = context
            ctx.scaleBy(x: size.width / 64, y: size.height / 64)
            MaintenanceGlyphPainter.paint(MaintenanceIcons.descriptor(for: key)?.id ?? "other",
                                         context: &ctx, color: color)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct MaintenanceGlyphTile: View {
    let key: String
    var color: Color = .garageGreen
    var side: CGFloat = 44

    var body: some View {
        MaintenanceGlyph(key: key, color: color)
            .frame(width: side * 0.72, height: side * 0.72)
            .frame(width: side, height: side)
            .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: side * 0.26,
                                                                  style: .continuous))
            .accessibilityHidden(true)
    }
}

private enum MaintenanceGlyphPainter {
    static func paint(_ key: String, context c: inout GraphicsContext, color: Color) {
        let white = Color.primary.opacity(0.91)
        let accent = color
        func stroke(_ p: Path, _ col: Color = .primary, _ width: CGFloat = 4) {
            c.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: width,
                                                             lineCap: .round, lineJoin: .round))
        }
        func fill(_ p: Path, _ col: Color) { c.fill(p, with: .color(col)) }
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat = 5) -> Path {
            Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius)
        }
        func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h))
        }
        func poly(_ pts: [CGPoint], close: Bool = false) -> Path {
            var p = Path()
            if let first = pts.first {
                p.move(to: first)
                for point in pts.dropFirst() { p.addLine(to: point) }
                if close { p.closeSubpath() }
            }
            return p
        }
        func l(_ values: [CGFloat], _ col: Color = .primary, _ width: CGFloat = 4) {
            var pts: [CGPoint] = []
            for i in stride(from: 0, to: values.count - 1, by: 2) {
                pts.append(CGPoint(x: values[i], y: values[i + 1]))
            }
            stroke(poly(pts), col, width)
        }
        func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ col: Color = .primary, _ width: CGFloat = 4) {
            stroke(oval(x-radius, y-radius, radius*2, radius*2), col, width)
        }
        func dots(_ centers: [(CGFloat, CGFloat)], _ rad: CGFloat, _ col: Color) {
            for (x,y) in centers { fill(oval(x-rad,y-rad,rad*2,rad*2),col) }
        }
        switch key {
        case "oil":
            fill(poly([CGPoint(x: 10,y: 24),CGPoint(x: 36,y: 24),CGPoint(x: 44,y: 32),
                       CGPoint(x: 54,y: 23),CGPoint(x: 58,y: 27),CGPoint(x: 44,y: 46),
                       CGPoint(x: 12,y: 46)],close:true),accent)
            stroke(r(7,23,8,25,3),white)
            l([12,23,12,16,29,16,33,20],white,3.5)
            fill(oval(48,44,10,13),white)
        case "oilFilter":
            fill(r(19,16,27,37,6),accent)
            stroke(oval(19,11,27,11),white,3.5)
            l([24,25,24,45,32,25,32,45,40,25,40,45],white,2.8)
            l([21,54,45,54],white,3)
        case "airFilter", "cabinFilter":
            stroke(r(10,12,44,41,4),white,4)
            for x in stride(from: CGFloat(17), through: 46, by: 7) { l([x,18,x,46],accent,4) }
            if key == "cabinFilter" {
                fill(oval(36,35,22,22),Color.black.opacity(0.93))
                circle(47,46,4,white,2.8)
                l([47,42,43,36,39,39,43,45,37,48,40,54,47,50,54,55,57,50,51,46,58,43,55,37,49,42],accent,2.7)
            }
        case "fuelFilter", "lpgFilter":
            fill(r(19,13,26,40,7),accent)
            stroke(r(19,13,26,40,7),white,3.5)
            l([32,5,32,13,32,53,32,60],white,4)
            l([24,27,40,27,24,40,40,40],Color.black.opacity(0.55),3)
            if key == "lpgFilter" { circle(32,33,6,white,2.5) }
        case "spark":
            l([12,53,20,45,29,35,41,21,47,14],white,7)
            l([20,45,29,35],accent,10)
            l([41,21,47,14,52,19],white,3)
            l([49,11,56,7,54,20,61,20],accent,3)
            l([7,56,13,60,18,53],white,3)
        case "ignition":
            fill(r(10,13,28,28,5),accent)
            stroke(r(10,13,28,28,5),white,3.3)
            l([17,13,17,7,31,13,31,7],white,3)
            l([38,20,53,13,53,34,45,45],white,3)
            l([45,45,40,53,50,53,50,59],accent,4)
            dots([(17,46),(29,46)],3,white)
        case "battery":
            fill(r(8,20,48,34,4),accent)
            stroke(r(8,20,48,34,4),white,3.5)
            fill(r(15,13,11,7,2),white)
            fill(r(39,13,11,7,2),white)
            l([18,37,28,37,23,32,23,42],Color.black.opacity(0.82),3)
            l([39,37,49,37],Color.black.opacity(0.82),3)
        case "bulb":
            fill(oval(18,8,28,31),accent)
            l([24,37,25,44,39,44,40,37],white,4)
            stroke(r(25,44,14,10,3),white,4)
            l([28,59,36,59],white,3)
            l([8,16,13,20,56,16,51,20,32,3,32,7],white,3)
        case "brakePads":
            circle(27,32,19,white,3.5)
            circle(27,32,9,accent,3.5)
            fill(r(43,15,16,36,6),accent)
            l([45,16,47,10,56,10],white,3)
            dots([(27,14),(27,50),(9,32)],2,white)
        case "brakeDiscs":
            circle(32,32,25,white,4)
            circle(32,32,12,accent,3.8)
            circle(32,32,4,white,3)
            dots([(32,11),(32,53),(11,32),(53,32),(17,17),(47,17),(17,47),(47,47)],2.5,accent)
        case "brakeFluid":
            fill(r(19,22,28,34,4),accent)
            stroke(r(19,22,28,34,4),white,3)
            stroke(r(24,12,18,10,2),white,3)
            fill(oval(28,31,9,15),white)
            l([16,58,50,58],white,3)
        case "coolant":
            stroke(r(14,16,36,42,5),white,3.5)
            fill(r(19,29,26,24,3),accent)
            l([23,16,23,8,40,8,40,16],white,3.5)
            l([32,32,32,47,25,35,39,44,25,44,39,35],white,2.6)
        case "otherFluid":
            fill(poly([CGPoint(x: 32,y: 7),CGPoint(x: 49,y: 32),CGPoint(x: 53,y: 42),
                       CGPoint(x: 45,y: 55),CGPoint(x: 20,y: 55),CGPoint(x: 11,y: 42),
                       CGPoint(x: 16,y: 28)],close:true),accent)
            l([18,42,23,49,32,51],white,3)
        case "belt":
            stroke(oval(7,18,50,28),white,5)
            stroke(oval(14,24,14,14),accent,3)
            stroke(oval(37,24,14,14),accent,3)
            l([21,18,44,18,21,46,44,46],accent,2.6)
        case "timingChain":
            stroke(oval(8,13,48,38),white,4)
            circle(21,32,8,accent,3)
            circle(44,32,8,accent,3)
            dots([(11,23),(13,43),(33,12),(53,20),(52,43),(31,52)],2.8,accent)
        case "roller":
            circle(19,32,13,white,4)
            circle(45,32,13,white,4)
            circle(19,32,5,accent,3)
            circle(45,32,5,accent,3)
            l([19,19,45,19,19,45,45,45],accent,2.8)
        case "wiper":
            stroke(poly([CGPoint(x: 8,y: 36),CGPoint(x: 15,y: 16),
                         CGPoint(x: 49,y: 16),CGPoint(x: 56,y: 36)]),white,4)
            l([13,48,48,33],accent,5)
            l([28,41,39,54],white,3)
        case "wheel":
            circle(32,32,26,white,5)
            circle(32,32,17,accent,3)
            circle(32,32,6,white,3)
            for i in 0..<5 {
                let angle=Double(i)*2*Double.pi/5-Double.pi/2
                l([32+10*cos(angle),32+10*sin(angle),32+19*cos(angle),32+19*sin(angle)],accent,4)
            }
        case "bearing":
            circle(32,32,25,white,4)
            circle(32,32,11,white,4)
            for i in 0..<8 {
                let angle=Double(i)*Double.pi/4
                fill(oval(32+18*cos(angle)-3,32+18*sin(angle)-3,6,6),accent)
            }
        case "shock":
            l([12,53,22,43,43,22,53,12],white,6)
            stroke(r(23,24,19,18,4),accent,5)
            circle(10,55,6,white,3)
            circle(55,10,6,white,3)
        case "spring":
            l([20,7,44,7,21,18,43,26,21,35,43,44,20,54,44,57],accent,5)
            l([20,6,44,6,20,58,44,58],white,3)
        case "steering":
            circle(32,32,25,white,4.5)
            circle(32,32,6,accent,3.5)
            l([32,26,32,12,26,33,11,27,38,33,53,27,27,37,23,54,37,37,41,54],accent,3.6)
        case "gasket":
            stroke(r(9,9,46,46,10),white,5)
            stroke(r(22,22,20,20,7),accent,4)
            dots([(16,16),(48,16),(16,48),(48,48)],3.5,accent)
        case "clutch":
            circle(32,32,25,white,4)
            circle(32,32,10,accent,4)
            for i in 0..<8 {
                let a=Double(i)*Double.pi/4
                l([32+14*cos(a),32+14*sin(a),32+23*cos(a),32+23*sin(a)],white,3)
            }
        case "gearbox":
            fill(r(17,16,30,33,6),accent)
            stroke(r(17,16,30,33,6),white,3)
            l([6,32,17,32,47,32,58,32],white,5)
            circle(28,32,6,Color.black.opacity(0.8),3)
            circle(42,32,3,white,2)
            l([23,53,41,53],white,3)
        case "exhaust":
            stroke(r(19,20,29,24,8),white,4)
            l([7,32,19,32,48,32,58,24],accent,5)
            l([58,24,61,21],white,3)
        case "fuelSystem":
            fill(r(14,13,30,43,5),accent)
            stroke(r(14,13,30,43,5),white,3)
            l([23,25,36,25,30,39],Color.black.opacity(0.8),3)
            l([43,20,52,20,56,26,56,43,49,48],white,3)
        case "lpg":
            stroke(oval(8,17,48,32),white,4)
            l([12,33,3,33,56,33,62,33],accent,3)
            stroke(r(20,21,25,23,10),accent,4)
            l([24,33,30,37,39,29],white,3)
        case "engine":
            fill(r(12,21,40,29,5),accent)
            stroke(r(12,21,40,29,5),white,3)
            l([18,21,18,12,36,12,36,21,5,29,12,29,52,29,59,35,59,46,52,46],white,3)
            l([23,36,39,36],Color.black.opacity(0.85),4)
        case "ac":
            l([32,8,32,56,8,32,56,32,15,15,49,49,49,15,15,49],accent,4)
            l([26,13,32,19,38,13,26,51,32,45,38,51],white,3)
        default:
            dots([(16,32),(32,32),(48,32)],5,accent)
        }
    }
}

/// The original picker is intentionally explicit: saved manual choices win over title inference.
struct MaintenanceIconPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String?
    let title: String

    private let columns = [GridItem(.adaptive(minimum: 93), spacing: 12)]

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
                                Text("Подбирать по названию работы")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selection == nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.garageGreen) }
                        }
                        .padding(12)
                        .garageCard(cornerRadius: 17)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("maintenance.icon.auto")

                    ForEach(MaintenanceIcons.sections, id: \.self) { section in
                        let members = MaintenanceIcons.catalog.filter { $0.section == section }
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.uppercased())
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(members) { item in
                                    Button {
                                        selection = item.id
                                        dismiss()
                                    } label: {
                                        VStack(spacing: 8) {
                                            ZStack(alignment: .topTrailing) {
                                                MaintenanceGlyphTile(key: item.id, side: 57)
                                                if selection == item.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(Color.garageGreen)
                                                        .background(.black, in: Circle())
                                                        .offset(x: 7, y: -5)
                                                }
                                            }
                                            Text(item.title)
                                                .font(.caption2.weight(.medium))
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                                .frame(maxWidth: .infinity)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 100)
                                        .padding(.horizontal, 3)
                                        .background(Color.garageSurface, in: RoundedRectangle(cornerRadius: 15))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(item.title)
                                    .accessibilityIdentifier("maintenance.icon.\(item.id)")
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.garageBackground)
            .navigationTitle("Иконка работы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}
