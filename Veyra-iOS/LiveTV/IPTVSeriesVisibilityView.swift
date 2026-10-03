import SwiftUI

/// Beheert de zichtbaarheid van Xtream-series, met dezelfde voorkeuren als
/// VOD (films) en Live TV. Zonder dit scherm bestaat er geen manier om
/// `IPTVProviderPreferences.hiddenSeriesCategoryIDs`/`hiddenSeriesItemIDs` in
/// te stellen -- de filtering in `IPTVVODSourceProvider.episodeSources` en de
/// Home-rijen bestond al, maar had niets om op te filteren.
///
/// Zelfde patroon als `IPTVVODVisibilityView`: categorieën en series worden
/// rechtstreeks in deze ene lijst zichtbaar/verborgen gezet, een categorie
/// uitklappen (`DisclosureGroup`) toont haar series direct eronder.
@MainActor
struct IPTVSeriesVisibilityView: View {
    var providerID: UUID? = nil

    @State private var configuration: IPTVStoredConfiguration?
    @State private var categories: [IPTVCategory] = []
    @State private var seriesByCategory: [String: [XtreamSeriesItem]] = [:]
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
                        ProgressView("Series-categorieën laden…")
                    } else if let errorMessage, categories.isEmpty {
                        ContentUnavailableView(
                            "Series konden niet worden geladen",
                            systemImage: "wifi.exclamationmark",
                            description: Text(errorMessage)
                        )
                    } else if categories.isEmpty {
                        ContentUnavailableView("Geen series-categorieën", systemImage: "tv.badge.wifi")
                    } else {
                        VeyraList {
                            ForEach(categories) { category in
                                categorySection(category)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .searchable(text: $searchText, prompt: "Zoek series")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VeyraBackground())
                .navigationTitle("Series beheren")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Alles zichtbaar maken", systemImage: "eye") {
                                var updated = preferences
                                updated.hiddenSeriesCategoryIDs.removeAll()
                                updated.hiddenSeriesItemIDs.removeAll()
                                save(updated)
                            }
                            Button("Alles verbergen", systemImage: "eye.slash") {
                                var updated = preferences
                                updated.hiddenSeriesCategoryIDs = Set(categories.map(\.id))
                                updated.hiddenSeriesItemIDs.removeAll()
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
        let series = filteredSeries(for: category)
        let isExpanded = Binding<Bool>(
            get: { !searchText.isEmpty || expandedCategoryIDs.contains(category.id) },
            set: { expanded in
                if expanded { expandedCategoryIDs.insert(category.id) } else { expandedCategoryIDs.remove(category.id) }
            }
        )
        if searchText.isEmpty || !series.isEmpty {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(series) { item in seriesRow(item) }
            } label: {
                categoryRow(category)
            }
        }
    }

    private func categoryRow(_ category: IPTVCategory) -> some View {
        let isVisible = preferences.isSeriesCategoryVisible(category.id)
        return Button {
            var updated = preferences
            updated.setSeriesCategory(category.id, visible: !isVisible)
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

    private func seriesRow(_ item: XtreamSeriesItem) -> some View {
        let isVisible = preferences.isSeriesItemVisible(String(item.id))
        return Button {
            var updated = preferences
            updated.setSeriesItem(String(item.id), visible: !isVisible)
            save(updated)
        } label: {
            HStack(spacing: 12) {
                VeyraAsyncImage(url: item.coverURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Image(systemName: "tv").foregroundStyle(.secondary) }
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

    private func filteredSeries(for category: IPTVCategory) -> [XtreamSeriesItem] {
        let items = seriesByCategory[category.id] ?? []
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func status(for category: IPTVCategory) -> String {
        guard preferences.isSeriesCategoryVisible(category.id) else { return "Categorie verborgen" }
        let items = seriesByCategory[category.id] ?? []
        let visible = items.filter { preferences.isSeriesItemVisible(String($0.id)) }.count
        return "\(visible) van \(items.count) series zichtbaar"
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
                errorMessage = "Series-beheer is beschikbaar voor een Xtream-provider."
                return
            }
            self.configuration = configuration
            preferences = preferencesStore.load(for: configuration)

            let loadedCategories = try await service.loadXtreamSeriesCategories(configuration: xtream)
            try Task.checkCancellation()
            let series = try await service.loadXtreamSeries(configuration: xtream, categoryID: nil)
            try Task.checkCancellation()

            let grouped = Dictionary(grouping: series) { $0.categoryID ?? "" }
            categories = loadedCategories
            seriesByCategory = grouped
        } catch is CancellationError {
        } catch {
            errorMessage = "Controleer de verbinding met je IPTV-provider en probeer opnieuw."
        }
    }
}
