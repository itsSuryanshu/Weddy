import SwiftUI

struct LocationPickerView: View {
    let currentSelection: LocationSelection
    let onSelect: (LocationSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [GeocodedCity] = []
    @State private var isSearching = false
    @State private var searchError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onSelect(.gps)
                        dismiss()
                    } label: {
                        HStack {
                            Label("Current Location (GPS)", systemImage: "location.fill")
                            Spacer()
                            if case .gps = currentSelection {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section {
                    if let searchError {
                        Text(searchError).font(.footnote).foregroundStyle(.red)
                    } else if isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if query.trimmingCharacters(in: .whitespaces).count >= 2 && results.isEmpty {
                        Text("No cities found for \"\(query)\"").foregroundStyle(.secondary)
                    }
                    ForEach(results) { city in
                        Button {
                            onSelect(.manual(city))
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(city.displayName).foregroundStyle(.primary)
                                    Spacer()
                                    if case .manual(let selected) = currentSelection, selected.id == city.id {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                                if !city.disambiguationLine.isEmpty {
                                    Text(city.disambiguationLine)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search for a city")
            .task(id: query) { await performSearch() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            searchError = nil
            isSearching = false
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        isSearching = true
        searchError = nil
        do {
            let cities = try await GeocodingService.search(query: trimmed)
            if Task.isCancelled { return }
            results = cities
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            results = []
            searchError = "Search failed: \(error.localizedDescription)"
        }
        isSearching = false
    }
}

#Preview {
    LocationPickerView(currentSelection: .gps) { _ in }
}
