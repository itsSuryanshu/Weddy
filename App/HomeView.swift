import SwiftUI

struct HomeView: View {
    @State private var manager = LiveActivityManager.shared
    /// nil = mirror the live weather; otherwise browse a specific scene.
    @State private var previewScene: PupScene?
    @State private var previewLayout = SceneLayout.makeInitial(for: .clearDay)
    @State private var isShowingLocationPicker = false

    /// In-app preview wanders much faster than the Live Activity so the
    /// scene feels alive while you watch it — every few seconds the dog
    /// hops to a new spot and the butterflies flutter ahead of it.
    private let previewTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private var displayedScene: PupScene {
        previewScene ?? manager.scene
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    scenePreview
                    scenePicker
                    weatherCard
                    activityStatus
                    if let error = manager.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("PupWeather")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingLocationPicker = true
                    } label: {
                        Image(systemName: "mappin.and.ellipse")
                    }
                }
            }
            .sheet(isPresented: $isShowingLocationPicker) {
                LocationPickerView(currentSelection: manager.selectedLocation) { selection in
                    Task { await manager.selectLocation(selection) }
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

    private var weatherCard: some View {
        HStack(spacing: 14) {
            Image(systemName: manager.scene.symbolName)
                .font(.system(size: 34))
                .symbolRenderingMode(.multicolor)
            VStack(alignment: .leading, spacing: 2) {
                if let weather = manager.currentWeather {
                    Text("\(Int(weather.temperatureC.rounded()))°C · \(weather.scene.label)")
                        .font(.title3.bold())
                } else {
                    Text(manager.isRefreshing ? "Fetching weather…" : "No weather yet")
                        .font(.title3.bold())
                }
                if let place = manager.placeName {
                    Text(place).font(.subheadline).foregroundStyle(.secondary)
                }
                if let refreshed = manager.lastRefresh {
                    Text("Updated \(refreshed.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if manager.isRefreshing {
                ProgressView()
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
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

#Preview {
    HomeView()
}
