import SwiftUI

struct SettingsView: View {
    @State private var manager = LiveActivityManager.shared
    @State private var isShowingChangePrimarySheet = false
    @State private var sceneStyle: SceneRenderStyle = .normal
    @State private var locationPosition: LocationLabelPosition = .bottomLeft

    private var currentLocationLabel: String {
        guard let primary = manager.primaryLocation else { return "Not set" }
        switch primary.selection {
        case .gps: return manager.placeNameByLocation[primary.id] ?? "Current Location"
        case .manual(let city): return city.displayName
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("General") {
                    HStack {
                        Text("Location")
                        Spacer()
                        Text(currentLocationLabel)
                            .foregroundStyle(.secondary)
                        Button("Edit") {
                            isShowingChangePrimarySheet = true
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .glassButton(tint: .orange, in: Capsule())
                    }
                }
                Section("Appearance") {
                    Picker("Scene Style", selection: $sceneStyle) {
                        ForEach(SceneRenderStyle.allCases, id: \.self) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("Location Position", selection: $locationPosition) {
                        ForEach(LocationLabelPosition.allCases, id: \.self) { position in
                            Text(position.label).tag(position)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Settings")
            .task {
                sceneStyle = manager.sceneStyle
                locationPosition = manager.locationPosition
            }
            .onChange(of: sceneStyle) { _, newStyle in
                Task { await manager.setSceneStyle(newStyle) }
            }
            .onChange(of: locationPosition) { _, newPosition in
                Task { await manager.setLocationPosition(newPosition) }
            }
            .sheet(isPresented: $isShowingChangePrimarySheet) {
                LocationPickerView(
                    mode: .replacePrimary,
                    currentSelection: manager.primaryLocation?.selection ?? .gps
                ) { selection in
                    Task { await manager.setPrimaryLocation(selection) }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
