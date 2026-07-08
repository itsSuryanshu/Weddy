import SwiftUI

struct HomeView: View {
    @State private var manager = LiveActivityManager.shared
    /// nil = mirror the live weather; otherwise browse a specific scene.
    @State private var previewScene: PupScene?
    @State private var previewLayout = SceneLayout.makeInitial(for: .clearDay)
    @State private var isShowingChangePrimarySheet = false
    @State private var isShowingAddLocationSheet = false

    /// In-app preview wanders much faster than the Live Activity so the
    /// scene feels alive while you watch it — every few seconds the dog
    /// hops to a new spot and the butterflies flutter ahead of it.
    private let previewTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private var displayedScene: PupScene {
        previewScene ?? manager.scene
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
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let location = addedLocations[index]
                                Task { await manager.removeLocation(id: location.id) }
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingChangePrimarySheet = true
                    } label: {
                        Image(systemName: "mappin.and.ellipse")
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                addLocationButton
            }
            .sheet(isPresented: $isShowingChangePrimarySheet) {
                LocationPickerView(
                    mode: .replacePrimary,
                    currentSelection: manager.primaryLocation?.selection ?? .gps
                ) { selection in
                    Task { await manager.setPrimaryLocation(selection) }
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
            .task {
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
        PupSceneView(scene: displayedScene, layout: previewLayout, minHeight: 120)
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var scenePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                sceneChip(nil, label: "Live", symbol: "location.fill")
                ForEach(PupScene.allCases, id: \.self) { scene in
                    sceneChip(scene, label: scene.label, symbol: scene.symbolName)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func sceneChip(_ scene: PupScene?, label: String, symbol: String) -> some View {
        let selected = previewScene == scene
        return Button {
            withAnimation(.smooth(duration: 0.8)) {
                previewScene = scene
                previewLayout = SceneLayout.wander(from: previewLayout,
                                                   scene: scene ?? manager.scene)
            }
        } label: {
            Label(label, systemImage: symbol)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color(.secondarySystemBackground),
                            in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
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

    private var addLocationButton: some View {
        Button {
            isShowingAddLocationSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.orange)
                .frame(width: 56, height: 56)
        }
        .modifier(GlassButtonModifier())
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .accessibilityLabel("Add location")
        .disabled(manager.trackedLocations.count >= LiveActivityManager.maxTrackedLocations)
        .opacity(manager.trackedLocations.count >= LiveActivityManager.maxTrackedLocations ? 0.4 : 1)
    }
}

/// Liquid Glass wasn't introduced until iOS 26; the app supports back to 17,
/// so older runtimes fall back to a tinted material that reads the same way.
private struct GlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(.orange.opacity(0.6)).interactive(), in: .circle)
        } else {
            content
                .background(.orange.opacity(0.35), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.orange.opacity(0.5), lineWidth: 1))
                .shadow(radius: 4, y: 2)
        }
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
