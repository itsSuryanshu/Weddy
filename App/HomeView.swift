import SwiftUI

struct HomeView: View {
    @State private var manager = LiveActivityManager.shared
    /// nil = mirror the live weather; otherwise browse a specific condition.
    @State private var previewCondition: PupCondition?
    @State private var previewNight = false
    @State private var previewLayout = SceneLayout.makeInitial(for: .clearDay)

    /// Committed badge scale, seeded from the manager and written back on
    /// every drag end.
    @State private var badgeScale: Double = 1.0
    /// Non-nil while the resize handle is being dragged.
    @State private var liveScale: Double?
    @State private var dragStartScale: Double?
    /// Measured preview size; the 30%-area cap is computed against it.
    @State private var previewSize: CGSize = .zero

    private var effectiveScale: Double { liveScale ?? badgeScale }

    private var previewTemperatureC: Double {
        manager.primaryLocation.flatMap { manager.weatherByLocation[$0.id]?.temperatureC } ?? 20
    }

    /// In-app preview wanders much faster than the Live Activity so the
    /// scene feels alive while you watch it — every few seconds the dog
    /// hops to a new spot and the butterflies flutter ahead of it.
    private let previewTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private var displayedScene: PupScene {
        previewCondition.map { PupScene.scene(for: $0, night: previewNight) } ?? manager.scene
    }

    private var addedLocations: [TrackedLocation] {
        manager.trackedLocations
            .filter { !$0.isPrimary }
            .sorted { $0.addedAt < $1.addedAt }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 20) {
                        scenePreview
                        scenePicker
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if let primary = manager.primaryLocation {
                    Section {
                        LocationCard(location: primary, manager: manager)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                if !addedLocations.isEmpty {
                    Section("Other Locations") {
                        ForEach(addedLocations) { location in
                            LocationCard(location: location, manager: manager)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    // Declared first = pinned to the trailing
                                    // edge, so Hide lands to Delete's left.
                                    Button(role: .destructive) {
                                        Task { await manager.removeLocation(id: location.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        Task { await manager.setHidden(!location.isHidden, for: location.id) }
                                    } label: {
                                        Label(location.isHidden ? "Unhide" : "Hide",
                                              systemImage: location.isHidden ? "eye" : "eye.slash")
                                    }
                                    .tint(.indigo)
                                }
                        }
                    }
                }

                Section {
                    activityStatus
                    if let error = manager.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.leading)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .navigationTitle("PupWeather")
            .task {
                badgeScale = manager.badgeScale
                await manager.ensureActivityRunning()
            }
            .refreshable { await manager.ensureActivityRunning() }
            .onReceive(previewTimer) { _ in
                withAnimation(.smooth(duration: 1.6)) {
                    previewLayout = SceneLayout.wander(from: previewLayout,
                                                       scene: displayedScene)
                }
            }
        }
    }

    private var scenePreview: some View {
        PupSceneView(scene: displayedScene, layout: previewLayout, minHeight: 120,
                     reservedTrailingWidth: WeatherBadgeMetrics.reservedWidth(
                         temperatureC: previewTemperatureC,
                         label: displayedScene.label,
                         scale: effectiveScale))
            .frame(height: 120)
            .overlay(alignment: .bottomTrailing) { badgeEditor }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .onGeometryChange(for: CGSize.self, of: { $0.size }) { previewSize = $0 }
    }

    /// The Live Activity's weather badge, permanently in edit mode: a dashed
    /// box around the text with a glass resize handle on its top-left corner.
    /// Only the text ships to the Lock Screen — the chrome is app-only.
    private var badgeEditor: some View {
        WeatherBadge(scene: displayedScene,
                     temperatureC: previewTemperatureC,
                     scale: effectiveScale)
            .padding(6)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.white.opacity(0.85),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            .overlay(alignment: .topLeading) {
                resizeHandle.offset(x: -14, y: -14)
            }
            // Hit-slop so the offset handle keeps a full touch target, plus
            // the same corner margins the widget uses.
            .padding([.top, .leading], 16)
            .padding(.trailing, WeatherBadgeMetrics.trailingMargin)
            .padding(.bottom, WeatherBadgeMetrics.bottomMargin)
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
            .glassButton(in: Circle())
            .contentShape(Circle().inset(by: -8))
            .gesture(resizeGesture)
    }

    /// Proportional resize anchored bottom-right: the overlay alignment pins
    /// that corner, so scaling alone grows the box up-and-left toward the
    /// handle. Dragging the handle away from the anchor (up-left) grows it,
    /// toward the anchor shrinks it, via the diagonal-length ratio.
    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let start = dragStartScale ?? badgeScale
                dragStartScale = start
                let intrinsic = WeatherBadgeMetrics.intrinsicSize(
                    temperatureC: previewTemperatureC, label: displayedScene.label)
                let startBox = CGSize(width: intrinsic.width * start + 12,
                                      height: intrinsic.height * start + 12)
                let newWidth = max(startBox.width - value.translation.width, 1)
                let newHeight = max(startBox.height - value.translation.height, 1)
                let ratio = hypot(newWidth, newHeight) / hypot(startBox.width, startBox.height)
                liveScale = WeatherBadgeMetrics.clamped(start * ratio, in: previewSize)
            }
            .onEnded { _ in
                if let final = liveScale { badgeScale = final }
                liveScale = nil
                dragStartScale = nil
                Task { await manager.setBadgeScale(badgeScale) }
            }
    }

    private var scenePicker: some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Scene", selection: $previewCondition) {
                    Label("Live", systemImage: "location.fill")
                        .tag(nil as PupCondition?)
                    ForEach(PupCondition.allCases, id: \.self) { condition in
                        Label(condition.label, systemImage: condition.symbolName)
                            .tag(condition as PupCondition?)
                    }
                }
            } label: {
                dropdownLabel(previewCondition?.label ?? "Live",
                              symbol: previewCondition?.symbolName ?? "location.fill")
            }

            Menu {
                Picker("Time of day", selection: $previewNight) {
                    Label("Day", systemImage: "sun.max.fill").tag(false)
                    Label("Night", systemImage: "moon.stars.fill").tag(true)
                }
            } label: {
                dropdownLabel(displayedScene.isNight ? "Night" : "Day",
                              symbol: displayedScene.isNight ? "moon.stars.fill" : "sun.max.fill")
            }
            .disabled(previewCondition == nil)
            .opacity(previewCondition == nil ? 0.5 : 1)
        }
        .onChange(of: previewCondition) { animatePreviewChange() }
        .onChange(of: previewNight) { animatePreviewChange() }
    }

    private func dropdownLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.subheadline.bold())
            Spacer(minLength: 4)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: Capsule())
        .foregroundStyle(.primary)
        .contentShape(Capsule())
    }

    private func animatePreviewChange() {
        withAnimation(.smooth(duration: 0.8)) {
            previewLayout = SceneLayout.wander(from: previewLayout,
                                               scene: displayedScene)
        }
    }

    private var activityStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Live Activity status").font(.headline)
            Label(
                manager.activitiesEnabled ? "Enabled in Settings" : "Disabled in Settings",
                systemImage: manager.activitiesEnabled ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .foregroundStyle(manager.activitiesEnabled ? .green : .red)
            Text("Running activities: \(manager.activityCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(manager.isActivityRunning
                 ? "The pup wanders to a new spot every couple of minutes."
                 : "Open the app with Live Activities enabled to restore the Lock Screen pup.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let status = manager.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

}

/// One tracked location's weather + Live Activity status. Reads its state
/// from the manager's per-location dictionaries rather than singular
/// properties, since multiple of these can be on screen at once.
private struct LocationCard: View {
    let location: TrackedLocation
    let manager: LiveActivityManager

    private var id: String { location.id }
    private var weather: CurrentWeather? { manager.weatherByLocation[id] }
    private var isRefreshing: Bool { manager.refreshingIDs.contains(id) }
    private var isRunning: Bool { manager.isActivityRunning(for: id) }

    private var title: String {
        switch location.selection {
        case .gps: return manager.placeNameByLocation[id] ?? "Current Location"
        case .manual(let city): return city.displayName
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Image(systemName: (weather?.scene ?? .clearDay).symbolName)
                    .font(.system(size: 34))
                    .symbolRenderingMode(.multicolor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    if let weather {
                        Text("\(Int(weather.temperatureC.rounded()))°C · \(weather.scene.label)")
                            .font(.title3.bold())
                    } else {
                        Text(isRefreshing ? "Fetching weather…" : "No weather yet")
                            .font(.title3.bold())
                    }
                    if let refreshed = manager.lastRefreshByLocation[id] {
                        Text("Updated \(refreshed.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if isRefreshing {
                    ProgressView()
                } else if location.isHidden {
                    // Unhiding lives in the same swipe menu as Hide, so the
                    // card only signals the state instead of offering Resume.
                    Label("Hidden", systemImage: "eye.slash")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                } else if !isRunning {
                    Button("Resume") {
                        Task { await manager.ensureActivityRunning(for: location) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            if let errorMessage = manager.errorByLocation[id] {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    HomeView()
}
