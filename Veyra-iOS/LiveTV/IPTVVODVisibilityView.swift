import SwiftUI

/// Edits the same per-provider VOD-visibility preferences used by tvOS.
///
/// Categorieën én titels worden rechtstreeks in deze ene lijst
/// zichtbaar/verborgen gezet -- een tik op een rij wisselt meteen de
/// zichtbaarheid, geen apart "titelmenu" meer nodig zoals voorheen
/// (`IPTVVODTitleVisibilityView`, bereikt via een `NavigationLink`-push).
/// Een categorie uitklappen (`DisclosureGroup`, geen navigatie) toont haar
/// titels direct eronder, met dezelfde tik-om-te-wisselen-rij -- net als
/// bij Live TV.
@MainActor
struct IPTVVODVisibilityView: View {
    var providerID: UUID? = nil

    @State private var configuration: IPTVStoredConfiguration?
    @State private var categories: [IPTVCategory] = []
    @State private var itemsByCategory: [String: [IPTVVODItem]] = [:]
    @State private var preferences = IPTVProviderPreferences()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var expandedCategoryIDs: Set<String> = []
    @State private var searchText = ""

    private let configurationStore = IPTVConfigurationStore()
    private let preferencesStore = IPTVProviderPreferencesStore()
    private let service = IPTVService()

    var body: some View {
        VeyraDynamicBackgroundScope {
            Group {
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
                        VeyraList {
                            ForEach(categories) { category in
                                categorySection(category)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .searchable(text: $searchText, prompt: "Zoek titels")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VeyraBackground())
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
                        } label: { Image(systemName: "ellipsis.circle") }
                        .disabled(categories.isEmpty)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                            .accessibilityLabel("Categorieën nu vernieuwen")
                    }
                }
                .task { await load() }
                .onReceive(NotificationCenter.default.publisher(for: .iptvConfigurationDidChange)) { _ in
                    if let configuration { preferences = preferencesStore.load(for: configuration) }
                }
            }

        }
    }

    @ViewBuilder
    private func categorySection(_ category: IPTVCategory) -> some View {
        let items = filteredItems(for: category)
        let isExpanded = Binding<Bool>(
            get: { !searchText.isEmpty || expandedCategoryIDs.contains(category.id) },
            set: { expanded in
                if expanded { expandedCategoryIDs.insert(category.id) } else { expandedCategoryIDs.remove(category.id) }
            }
        )
        if searchText.isEmpty || !items.isEmpty {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(items) { item in itemRow(item) }
            } label: {
                categoryRow(category)
            }
        }
    }

    private func categoryRow(_ category: IPTVCategory) -> some View {
        let isVisible = preferences.isVODCategoryVisible(category.id)
        return Button {
            var updated = preferences
            updated.setVODCategory(category.id, visible: !isVisible)
            save(updated)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(category.name).foregroundStyle(.primary)
                    Text(status(for: category)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isVisible ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isVisible ? VeyraColors.cyan : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func itemRow(_ item: IPTVVODItem) -> some View {
        let isVisible = preferences.isVODItemVisible(item.id)
        return Button {
            var updated = preferences
            updated.setVODItem(item.id, visible: !isVisible)
            save(updated)
        } label: {
            HStack(spacing: 12) {
                VeyraAsyncImage(url: item.posterURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Image(systemName: "film").foregroundStyle(.secondary) }
                }
                .frame(width: 40, height: 56)
                .clipped()
                Text(item.name).lineLimit(2).foregroundStyle(.primary)
                Spacer()
                Image(systemName: isVisible ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isVisible ? VeyraColors.cyan : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func filteredItems(for category: IPTVCategory) -> [IPTVVODItem] {
        let items = itemsByCategory[category.id] ?? []
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func status(for category: IPTVCategory) -> String {
        guard preferences.isVODCategoryVisible(category.id) else { return "Categorie verborgen" }
        let items = itemsByCategory[category.id] ?? []
        let visible = items.filter { preferences.isVODItemVisible($0.id) }.count
        return "\(visible) van \(items.count) titels zichtbaar"
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
            let configuration: IPTVStoredConfiguration?
            if let providerID {
                configuration = try configurationStore.loadProvider(id: providerID)?.configuration
            } else {
                configuration = try configurationStore.load()
            }
            guard let configuration, case .xtream(let xtream) = configuration else {
                errorMessage = "VOD-beheer is beschikbaar voor een Xtream-provider."
                return
            }
            self.configuration = configuration
            preferences = preferencesStore.load(for: configuration)

            let loadedCategories = try await service.loadXtreamVODCategories(configuration: xtream)
            try Task.checkCancellation()
            let items = try await service.loadXtreamVOD(configuration: xtream, categoryID: nil)
            try Task.checkCancellation()

            let grouped = Dictionary(grouping: items) { $0.categoryID ?? "" }
            categories = loadedCategories
            itemsByCategory = grouped
        } catch is CancellationError {
        } catch {
            errorMessage = "Controleer de verbinding met je IPTV-provider en probeer opnieuw."
        }
    }
}
