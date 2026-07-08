import SwiftUI

struct SettingsView: View {
    @State private var manager = LiveActivityManager.shared
    @State private var isShowingChangePrimarySheet = false

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
                        Button("Change") {
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
            }
            .navigationTitle("Settings")
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
