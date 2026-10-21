import SwiftUI

struct RootView: View {
    @AppStorage("appearanceMode") private var appearanceMode = AppAppearance.dark.rawValue
    @State private var selected = 0
    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceMode) ?? .dark }
    private let titles = ["Гараж", "История", "Заправки", "Настройки"]
    private let symbols = ["car", "clock.arrow.circlepath", "fuelpump", "slider.horizontal.3"]
    var body: some View {
        ZStack {
            GarageScreenBackground()
            TabView(selection: $selected) {
                GarageView().tabItem { Label("Гараж", systemImage: "car") }.tag(0).garageRootChrome()
                HistoryView().tabItem { Label("История", systemImage: "clock.arrow.circlepath") }.tag(1).garageRootChrome()
                FuelTabView().tabItem { Label("Заправки", systemImage: "fuelpump") }.tag(2).garageRootChrome()
                SettingsView().tabItem { Label("Настройки", systemImage: "slider.horizontal.3") }.tag(3).garageRootChrome()
            }
            // Reserve scrollable space, while keeping the viewport behind the floating bar.
            .contentMargins(.bottom, 100, for: .scrollContent)
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 0) {
                ForEach(0..<4) { index in
                    Button { selected = index } label: {
                        VStack(spacing: 8) {
                            Image(systemName: symbols[index]).font(.system(size: 20, weight: .light)).frame(height: 24)
                            Text(titles[index]).font(.system(size: 10))
                        }.foregroundStyle(selected == index ? Color.primary : Color.secondary)
                            .frame(maxWidth: .infinity).frame(height: 64).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(titles[index])
                        .accessibilityAddTraits(selected == index ? .isSelected : [])
                }
            }
            .padding(6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25))
            .overlay { RoundedRectangle(cornerRadius: 25).stroke(Color.garageStroke, lineWidth: 0.7).allowsHitTesting(false) }
            .padding(.horizontal, 12).padding(.bottom, 4)
            .background {
                Rectangle().fill(.ultraThinMaterial)
                    .mask(LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                    .padding(.top, -28).ignoresSafeArea(edges: .bottom).allowsHitTesting(false)
            }
        }
        .tint(.garageGreen)
        .preferredColorScheme(appearance.colorScheme)
        .environment(\.locale, Locale(identifier: "ru_RU"))
    }
}

private extension View {
    func garageRootChrome() -> some View {
        toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}
