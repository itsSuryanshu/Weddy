import SwiftUI

struct RootView: View {
    /// Named AppTab so it doesn't shadow SwiftUI's `Tab` builder type.
    private enum AppTab: Int, Hashable {
        case home
        case settings
        /// Occupies the system search slot on iOS 26; acts as a button,
        /// never an actual destination.
        case add

        var title: String {
            switch self {
            case .home: "Home"
            case .settings: "Settings"
            case .add: "Add"
            }
        }

        var symbol: String {
            switch self {
            case .home: "house.fill"
            case .settings: "gearshape.fill"
            case .add: "plus"
            }
        }

        /// Tabs shown in the legacy custom capsule bar.
        static let barTabs: [AppTab] = [.home, .settings]
    }

    @State private var selectedTab: AppTab = .home
    /// Tab currently under the finger while press-sliding across the
    /// legacy custom bar.
    @State private var pressedTab: AppTab?
    @State private var manager = LiveActivityManager.shared
    @State private var isShowingAddLocationSheet = false
    @Namespace private var tabSelectionNamespace

    private let tabWidth: CGFloat = 84
    private let tabSpacing: CGFloat = 4
    private let barPadding: CGFloat = 6

    private var isAtLocationLimit: Bool {
        manager.trackedLocations.count >= LiveActivityManager.maxTrackedLocations
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                nativeTabView
            } else {
                legacyTabView
            }
        }
        .sheet(isPresented: $isShowingAddLocationSheet) {
            LocationPickerView(
                mode: .add,
                alreadyTrackedIDs: Set(manager.trackedLocations.map(\.id))
            ) { selection in
                Task { await manager.addLocation(selection) }
            }
        }
    }

    // MARK: - iOS 26: native Liquid Glass bar

    /// The Health-app layout: a search-role tab gets pulled out into its
    /// own trailing glass circle and the remaining tabs left-align. The
    /// "search" slot is hijacked as the Add button — selecting it opens
    /// the sheet and selection bounces straight back.
    @available(iOS 26.0, *)
    private var nativeTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.symbol,
                value: AppTab.home) {
                HomeView()
            }

            Tab(AppTab.settings.title, systemImage: AppTab.settings.symbol,
                value: AppTab.settings) {
                SettingsView()
            }

            Tab(AppTab.add.title, systemImage: AppTab.add.symbol,
                value: AppTab.add, role: .search) {
                Color.clear
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == .add {
                selectedTab = oldValue
                if !isAtLocationLimit {
                    isShowingAddLocationSheet = true
                }
            }
        }
    }

    // MARK: - iOS 17–25: custom capsule bar fallback

    private var legacyTabView: some View {
        Group {
            switch selectedTab {
            case .home, .add: HomeView()
            case .settings: SettingsView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                tabBar
                Spacer()
                addLocationButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    private var tabBar: some View {
        HStack(spacing: tabSpacing) {
            ForEach(AppTab.barTabs, id: \.rawValue) { tab in
                tabLabel(tab)
                    .frame(width: tabWidth)
            }
        }
        .padding(barPadding)
        .glassButton(in: Capsule())
        .gesture(tabDragGesture)
    }

    private func tabLabel(_ tab: AppTab) -> some View {
        let highlighted = (pressedTab ?? selectedTab) == tab
        return VStack(spacing: 2) {
            Image(systemName: tab.symbol)
                .font(.system(size: 20, weight: .semibold))
            Text(tab.title)
                .font(.caption2.bold())
        }
        .foregroundStyle(highlighted ? Color.primary : Color.secondary)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            if highlighted {
                Capsule()
                    .fill(.thinMaterial)
                    .scaleEffect(pressedTab != nil ? 1.08 : 1)
                    .matchedGeometryEffect(id: "tabSelection",
                                           in: tabSelectionNamespace)
            }
        }
    }

    /// minimumDistance of 0 makes this double as the tap handler: press
    /// down anywhere on the bar and the selector jumps under the finger,
    /// slides with it, and commits on release.
    private var tabDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let tab = tab(at: value.location.x)
                if pressedTab != tab {
                    withAnimation(.smooth(duration: 0.25)) { pressedTab = tab }
                }
            }
            .onEnded { value in
                let tab = tab(at: value.location.x)
                withAnimation(.smooth(duration: 0.3)) {
                    selectedTab = tab
                    pressedTab = nil
                }
            }
    }

    private func tab(at x: CGFloat) -> AppTab {
        let slot = Int((x - barPadding) / (tabWidth + tabSpacing))
        let clamped = min(max(slot, 0), AppTab.barTabs.count - 1)
        return AppTab.barTabs[clamped]
    }

    private var addLocationButton: some View {
        Button {
            isShowingAddLocationSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
        }
        .glassButton(tint: .orange, in: Circle())
        .overlay {
            // Specular highlight across the top for extra shine.
            Circle()
                .fill(LinearGradient(colors: [.white.opacity(0.45), .clear],
                                     startPoint: .top,
                                     endPoint: .center))
                .padding(2)
                .allowsHitTesting(false)
        }
        .overlay {
            Circle()
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.9),
                                            .white.opacity(0.1),
                                            .clear,
                                            .white.opacity(0.4)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing),
                    lineWidth: 1.5
                )
                .allowsHitTesting(false)
        }
        .shadow(color: .orange.opacity(0.45), radius: 10, y: 4)
        .accessibilityLabel("Add location")
        .disabled(isAtLocationLimit)
        .opacity(isAtLocationLimit ? 0.4 : 1)
    }
}

#Preview {
    RootView()
}
