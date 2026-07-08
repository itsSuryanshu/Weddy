import SwiftUI

struct RootView: View {
    private enum Tab {
        case home
        case settings
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        Group {
            switch selectedTab {
            case .home: HomeView()
            case .settings: SettingsView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                tabBar
                Spacer()
            }
            .padding(.leading, 20)
            .padding(.bottom, 8)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabBarButton(.home, label: "Home", symbol: "house.fill")
            tabBarButton(.settings, label: "Settings", symbol: "gearshape.fill")
        }
        .padding(6)
        .glassButton(tint: .orange, in: Capsule())
    }

    private func tabBarButton(_ tab: Tab, label: String, symbol: String) -> some View {
        let selected = selectedTab == tab
        return Button {
            withAnimation(.smooth(duration: 0.3)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                Text(label)
                    .font(.caption2.bold())
            }
            .foregroundStyle(selected ? Color.orange : Color.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if selected {
                    Capsule().fill(Color.orange.opacity(0.18))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RootView()
}
