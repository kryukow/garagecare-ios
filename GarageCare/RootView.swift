import SwiftUI

struct RootView: View {
    @AppStorage("appearanceMode") private var appearanceMode = AppAppearance.dark.rawValue
    @State private var selected = 0
    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceMode) ?? .dark }
    private let titles = ["Гараж", "История", "Заправки", "Настройки"]
    private let symbols = ["car", "clock.arrow.circlepath", "fuelpump", "slider.horizontal.3"]
    var body: some View {
        TabView(selection: $selected) {
            GarageView().tag(0).toolbar(.hidden, for: .tabBar)
            HistoryView().tag(1).toolbar(.hidden, for: .tabBar)
            FuelTabView().tag(2).toolbar(.hidden, for: .tabBar)
            SettingsView().tag(3).toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<4) { index in
                    Button { selected = index } label: {
                        VStack(spacing: 8) {
                            Image(systemName: symbols[index]).font(.system(size: 20, weight: .light)).frame(height: 24)
                            Text(titles[index]).font(.system(size: 10))
                        }.foregroundStyle(selected == index ? Color.primary : Color.secondary)
                            .frame(maxWidth: .infinity).frame(height: 64)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(titles[index])
                        .accessibilityAddTraits(selected == index ? .isSelected : [])
                }
            }.padding(6).garageCard(cornerRadius: 25)
                .padding(.horizontal, 12).padding(.bottom, 4)
                .background(Color.garageBackground.opacity(0.95))
        }
        .tint(.garageGreen)
        .preferredColorScheme(appearance.colorScheme)
        .environment(\.locale, Locale(identifier: "ru_RU"))
    }
}
