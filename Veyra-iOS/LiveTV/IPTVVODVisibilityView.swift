import SwiftUI

/// Manages Xtream VOD visibility with the same preferences as tvOS.
@MainActor
struct IPTVVODVisibilityView: View {
    @State private var configuration: IPTVStoredConfiguration?
    @State private var categories: [IPTVCategory] = []
    @State private var preferences = IPTVProviderPreferences()
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let configurationStore = IPTVConfigurationStore()
    private let preferencesStore = IPTVProviderPreferencesStore()
    private let service = IPTVService()

    var body: some View {
        Group {
            if isLoading && categories.isEmpty {
                ProgressView("VOD-categorieën laden…")
            } else if let errorMessage, categories.isEmpty {
                ContentUnavailableView(
                    "VOD kon niet worden geladen",
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
            } else if categories.isEmpty {
                ContentUnavailableView("Geen VOD-categorieën", systemImage: "film")
            } else {
                List(categories) { category in
                    NavigationLink {
                        IPTVVODTitleVisibilityView(
                            category: category,
                            configuration: configuration,
                            preferences: $preferences,
                            onSave: save
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.name)
                                .foregroundStyle(.primary)
                            Text(preferences.isVODCategoryVisible(category.id)
                                 ? "Zichtbaar" : "Verborgen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VeyraColors.background)
        .navigationTitle("VOD beheren")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Alles zichtbaar maken", systemImage: "eye") {
                        var updated = preferences
                        updated.hiddenVODCategoryIDs.removeAll()
                        updated.hiddenVODItemIDs.removeAll()
                        save(updated)
                    }
                    Button("Alles verbergen", systemImage: "eye.slash") {
                        var updated = preferences
                        updated.hiddenVODCategoryIDs = Set(categories.map(\.id))
                        updated.hiddenVODItemIDs.removeAll()
                        save(updated)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(categories.isEmpty)
            }
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .iptvConfigurationDidChange)) { _ in
            if let configuration {
                preferences = preferencesStore.load(for: configuration)
            }
        }
    }

    private func save(_ updated: IPTVProviderPreferences) {
        guard let configuration else { return }
        do {
            try preferencesStore.save(updated, for: configuration)
            preferences = updated
            errorMessage = nil
            NotificationCenter.default.post(name: .iptvConfigurationDidChange, object: nil)
        } catch {
            errorMessage = "De zichtbaarheid kon niet worden opgeslagen."
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let configuration = try configurationStore.load(),
                  case .xtream(let xtream) = configuration
            else {
                errorMessage = "VOD-beheer is beschikbaar voor een Xtream-provider."
                return
            }
            self.configuration = configuration
            preferences = preferencesStore.load(for: configuration)
            categories = try await service.loadXtreamVODCategories(configuration: xtream)
        } catch is CancellationError {
        } catch {
            errorMessage = "Controleer de verbinding met je IPTV-provider en probeer opnieuw."
        }
    }
}

@MainActor
private struct IPTVVODTitleVisibilityView: View {
    let category: IPTVCategory
    let configuration: IPTVStoredConfiguration?
    @Binding var preferences: IPTVProviderPreferences
    let onSave: (IPTVProviderPreferences) -> Void

    @State private var items: [IPTVVODItem] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = IPTVService()

    private var filteredItems: [IPTVVODItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            Section {
                Toggle(
                    "Categorie zichtbaar",
                    isOn: Binding(
                        get: { preferences.isVODCategoryVisible(category.id) },
                        set: { visible in
                            var updated = preferences
                            updated.setVODCategory(category.id, visible: visible)
                            onSave(updated)
                        }
                    )
                )
                .tint(VeyraColors.cyan)
            } footer: {
                Text("Een verborgen categorie verbergt al haar titels. De keuzes per titel blijven bewaard.")
            }

            Section("Titels") {
                if isLoading && items.isEmpty {
                    ProgressView("Titels laden…")
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                } else if items.isEmpty {
                    Text("Geen titels gevonden.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredItems) { item in
                        Toggle(
                            isOn: Binding(
                                get: { preferences.isVODItemVisible(item.id) },
                                set: { visible in
                                    var updated = preferences
                                    updated.setVODItem(item.id, visible: visible)
                                    onSave(updated)
                                }
                            )
                        ) {
                            HStack(spacing: 12) {
                                AsyncImage(url: item.posterURL) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Image(systemName: "film").foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 40, height: 56)
                                .clipped()
                                Text(item.name)
                                    .lineLimit(2)
                            }
                        }
                        .tint(VeyraColors.cyan)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(VeyraColors.background)
        .navigationTitle(category.name)
        .searchable(text: $searchText, prompt: "Zoek titels")
        .task { await loadItems() }
    }

    private func loadItems() async {
        guard let configuration, case .xtream(let xtream) = configuration else {
            errorMessage = "Geen Xtream-provider geselecteerd."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await service.loadXtreamVOD(
                configuration: xtream, categoryID: category.id
            )
        } catch is CancellationError {
        } catch {
            errorMessage = "De titels konden niet worden geladen."
        }
    }
}
