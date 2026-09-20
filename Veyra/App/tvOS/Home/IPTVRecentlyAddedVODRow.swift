import SwiftUI
import Foundation

struct IPTVRecentlyAddedVODRow: View {
    @State private var vodItems: [IPTVVODItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAllVODs = false
    @State private var isRefreshing = false

    private let posterWidth: CGFloat = 220

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            headerView

            if isLoading {
                loadingView

            } else if let errorMessage {
                errorView(errorMessage)

            } else if vodItems.isEmpty {
                emptyView

            } else {
                vodsScrollView
            }
        }
        .task {
            await loadVODs()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .iptvConfigurationDidChange
            )
        ) { _ in
            Task {
                await loadVODs(forceRefresh: true)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .iptvHomeRefreshRequested
            )
        ) { _ in
            Task {
                await loadVODs()
            }
        }
        .navigationDestination(
            isPresented: $showAllVODs
        ) {
            AllVODListView(
                vodItems: vodItems
            )
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VeyraSectionHeader(
            title: "IPTV nieuw toegevoegde films",
            subtitle: "Uit je zichtbare VOD-lijsten"
        )
    }

    // MARK: - Loading

    private var loadingView: some View {
        ProgressView(
            "VOD laden…"
        )
    }

    // MARK: - Error

    private func errorView(
        _ message: String
    ) -> some View {
        Text(message)
            .foregroundStyle(.orange)
    }

    // MARK: - Empty

    private var emptyView: some View {
        Text(
            "Geen nieuwe VOD-titels gevonden (controleer zichtbare lijsten in instellingen)."
        )
        .foregroundStyle(.secondary)
        .padding(.vertical, 20)
    }

    // MARK: - Horizontal Row

    private var vodsScrollView: some View {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            LazyHStack(
                alignment: .top,
                spacing: VeyraSpacing.rail
            ) {
                ForEach(
                    vodItems.prefix(20)
                ) { item in
                    vodLink(item)
                }

                toonAllesButton
            }
            .padding(12)
        }
        .scrollClipDisabled()
    }

    // MARK: - VOD Link

    private func vodLink(
        _ item: IPTVVODItem
    ) -> some View {
        NavigationLink {
            PlayerView(
                source: item.playableSource
            )
        } label: {
            VeyraPosterCard(
                title: item.name,
                url: item.posterURL,
                symbol: "film",
                width: posterWidth
            )
        }
        .buttonStyle(
            VeyraFocusButtonStyle(
                radius: VeyraRadius.poster
            )
        )
        .reportsHero(
            VeyraHeroContent(
                id: "iptv-vod:\(item.id)",
                eyebrow: "Film",
                title: item.name,
                overview: nil,
                metadata: [],
                backdropURL: item.posterURL
            )
        )
    }

    // MARK: - Show All

    private var toonAllesButton: some View {
        Button {
            showAllVODs = true
        } label: {
            VeyraPosterCard(
                title: "Toon alles",
                url: nil,
                symbol: "arrow.right.circle",
                width: posterWidth
            )
        }
        .buttonStyle(
            VeyraFocusButtonStyle(
                radius: VeyraRadius.poster
            )
        )
    }

    // MARK: - Load VODs

    @MainActor
    private func loadVODs(
        forceRefresh: Bool = false
    ) async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true

        defer {
            isRefreshing = false
        }

        errorMessage = nil

        do {
            let configStore =
                IPTVConfigurationStore()

            let preferencesStore =
                IPTVProviderPreferencesStore()

            guard
                let configuration =
                    try configStore.load()
            else {
                vodItems = []
                errorMessage =
                    "Geen IPTV-provider ingesteld."
                isLoading = false
                return
            }

            let preferences =
                preferencesStore.load(
                    for: configuration
                )

            let providerKey =
                configuration.providerIdentifier

            let cacheKey =
                "recentlyAdded.vod.\(providerKey)"

            if forceRefresh {
                vodItems = []
            }

            // Eerst cache onmiddellijk tonen.
            if vodItems.isEmpty,
               let cached =
                IPTVDiskCache.read(
                    [IPTVVODItem].self,
                    key: cacheKey
                )?.value
            {
                vodItems =
                    cached.filter {
                        preferences
                            .isVODItemVisible(
                                $0.id
                            )
                    }
            }

            isLoading =
                vodItems.isEmpty

            guard
                case .xtream(
                    let xtreamConfig
                ) = configuration
            else {
                vodItems = []
                errorMessage =
                    "Nieuw toegevoegd werkt alleen met Xtream VOD."
                isLoading = false
                return
            }

            let service =
                IPTVService()

            let allCategories =
                try await service
                    .loadXtreamVODCategories(
                        configuration:
                            xtreamConfig
                    )

            try Task
                .checkCancellation()

            let visibleCategories =
                allCategories.filter {
                    preferences
                        .isVODCategoryVisible(
                            $0.id
                        )
                }

            var allVODs:
                [IPTVVODItem] = []

            // Maximaal vier categorieën tegelijk laden.
            var index = 0

            while index
                    < visibleCategories.count
            {
                try Task
                    .checkCancellation()

                let remaining =
                    visibleCategories.count
                    - index

                let batchSize =
                    min(
                        4,
                        remaining
                    )

                switch batchSize {
                case 4:
                    let category1 =
                        visibleCategories[
                            index
                        ]

                    let category2 =
                        visibleCategories[
                            index + 1
                        ]

                    let category3 =
                        visibleCategories[
                            index + 2
                        ]

                    let category4 =
                        visibleCategories[
                            index + 3
                        ]

                    async let result1 =
                        try? service
                            .loadXtreamVOD(
                                configuration:
                                    xtreamConfig,
                                categoryID:
                                    category1.id
                            )

                    async let result2 =
                        try? service
                            .loadXtreamVOD(
                                configuration:
                                    xtreamConfig,
                                categoryID:
                                    category2.id
                            )

                    async let result3 =
                        try? service
                            .loadXtreamVOD(
                                configuration:
                                    xtreamConfig,
                                categoryID:
                                    category3.id
                            )

                    async let result4 =
                        try? service
                            .loadXtreamVOD(
                                configuration:
                                    xtreamConfig,
                                categoryID:
                                    category4.id
                            )

                    let results =
                        await (
                            result1,
                            result2,
                            result3,
                            result4
                        )

                    appendVisible(
                        results.0 ?? [],
                        to: &allVODs,
                        preferences:
                            preferences
                    )

                    appendVisible(
                        results.1 ?? [],
                        to: &allVODs,
                        preferences:
                            preferences
                    )

                    appendVisible(
                        results.2 ?? [],
                        to: &allVODs,
                        preferences:
                            preferences
                    )

                    appendVisible(
                        results.3 ?? [],
                        to: &allVODs,
                        preferences:
                            preferences
                    )

                case 3:
                    let category1 =
                        visibleCategories[
                            index
                        ]

                    let category2 =
                        visibleCategories[
                            index + 1
                        ]

                    let category3 =
                        visibleCategories[
                            index + 2
                        ]

                    async let result1 =
                        try? service
                            .loadXtreamVOD(
                                configuration:
                                    xtreamConfig,
                                categoryID:
                                    category1.id
                            )

                    async let result2 =
                        try? service
                            .loadXtreamVOD(
                                configuration:
                                    xtreamConfig,
                                categoryID:
                                    category2.id
                            )

                    async let result3 =
                        try? service
                            .loadXtreamVOD(
                                configuration:
                                    xtreamConfig,
                                categoryID:
                                    category3.id
                            )

                    let results =
                        await (
                            result1,
                            result2,
                            result3
                        )

                    appendVisible(
                        results.0 ?? [],
                        to: &allVODs,
                        preferences:
                            preferences
                    )

                    appendVisible(
                        results.1 ?? [],
                        to: &allVODs,
                        preferences:
                            preferences
                    )

                    appendVisible(
                        results.2 ?? [],
                        to: &allVODs,
                        preferences:
                            preferences
                    )

                case 2:
                    let category1 =
                        visibleCategories[
                            index
                        ]

                    let category2 =
                        visibleCategories[
                            index + 1
                        ]

                    async let result1 =
                        try? service
                            .loadXtreamVOD(
                                configuration:
                                    xtreamConfig,
                                categoryID:
                                    category1.id
                            )

                    async let result2 =
                        try? service
                            .loadXtreamVOD(
                                configuration:
                                    xtreamConfig,
                                categoryID:
                                    category2.id
                            )

                    let results =
                        await (
                            result1,
                            result2
                        )

                    appendVisible(
                        results.0 ?? [],
                        to: &allVODs,
                        preferences:
                            preferences
                    )

                    appendVisible(
                        results.1 ?? [],
                        to: &allVODs,
                        preferences:
                            preferences
                    )

                case 1:
                    let category =
                        visibleCategories[
                            index
                        ]

                    let result =
                        try? await service
                            .loadXtreamVOD(
                                configuration:
                                    xtreamConfig,
                                categoryID:
                                    category.id
                            )

                    appendVisible(
                        result ?? [],
                        to: &allVODs,
                        preferences:
                            preferences
                    )

                default:
                    break
                }

                index += batchSize
            }

            try Task
                .checkCancellation()

            // Dubbele items verwijderen.
            var seenIDs =
                Set<String>()

            let uniqueVODs =
                allVODs.filter {
                    seenIDs.insert(
                        $0.id
                    )
                    .inserted
                }

            // Nieuwste stream-ID eerst.
            let sorted =
                uniqueVODs.sorted {
                    let first =
                        streamID(
                            from: $0.id
                        )

                    let second =
                        streamID(
                            from: $1.id
                        )

                    if first != second {
                        return first
                            > second
                    }

                    return $0.name
                        .localizedStandardCompare(
                            $1.name
                        )
                        == .orderedAscending
                }

            vodItems =
                sorted

            // Alleen de 200 nieuwste lokaal cachen.
            let cachedRecentVODs =
                Array(
                    sorted.prefix(200)
                )

            IPTVDiskCache.write(
                cachedRecentVODs,
                key: cacheKey
            )

        } catch is CancellationError {
            return

        } catch {
            if vodItems.isEmpty {
                errorMessage =
                    error
                        .localizedDescription
            }
        }

        isLoading =
            false
    }

    private func appendVisible(
        _ items:
            [IPTVVODItem],
        to destination:
            inout [IPTVVODItem],
        preferences:
            IPTVProviderPreferences
    ) {
        destination.append(
            contentsOf:
                items.filter {
                    preferences
                        .isVODItemVisible(
                            $0.id
                        )
                }
        )
    }

    private func streamID(
        from id:
            String
    ) -> Int {
        guard
            let value =
                id
                    .split(
                        separator: "-"
                    )
                    .last,
            let intID =
                Int(value)
        else {
            return 0
        }

        return intID
    }
}

// MARK: - Custom tvOS Button Style

private struct VeyraVODButtonStyle:
    ButtonStyle
{
    func makeBody(
        configuration:
            Configuration
    ) -> some View {
        configuration.label
            .background(
                Color.clear
            )
            .opacity(
                configuration
                    .isPressed
                    ? 0.82
                    : 1
            )
    }
}

// MARK: - All VOD List

struct AllVODListView: View {
    let vodItems:
        [IPTVVODItem]

    @FocusState
    private var focusedVODID:
        String?

    private let posterWidth:
        CGFloat = 220

    private let posterHeight:
        CGFloat = 330

    private let columns = [
        GridItem(
            .adaptive(
                minimum: 235
            ),
            spacing: 28
        )
    ]

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 22
            ) {
                headerView

                LazyVGrid(
                    columns: columns,
                    spacing: 36
                ) {
                    ForEach(
                        vodItems
                    ) { item in
                        vodGridCell(
                            item
                        )
                    }
                }
                .padding(
                    .horizontal
                )
            }
            .padding(
                .vertical
            )
        }
        .navigationTitle(
            "IPTV nieuw toegevoegde films"
        )
    }

    private var headerView:
        some View
    {
        Label(
            "IPTV NIEUW TOEGEVOEGDE FILMS",
            systemImage:
                "sparkles"
        )
        .font(
            .system(
                size: 25,
                weight: .bold
            )
        )
        .tracking(2)
        .foregroundStyle(
            .cyan
        )
        .padding(
            .horizontal
        )
    }

    private func vodGridCell(
        _ item:
            IPTVVODItem
    ) -> some View {
        let isFocused =
            focusedVODID
            == item.id

        return NavigationLink {
            PlayerView(
                source:
                    item
                        .playableSource
            )

        } label: {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                AsyncImage(
                    url:
                        item.posterURL
                ) { phase in
                    switch phase {
                    case .success(
                        let image
                    ):
                        image
                            .resizable()
                            .scaledToFill()

                    case .empty:
                        ZStack {
                            Color.white
                                .opacity(
                                    0.04
                                )

                            ProgressView()
                        }

                    case .failure:
                        posterFallback

                    @unknown default:
                        posterFallback
                    }
                }
                .frame(
                    width:
                        posterWidth,
                    height:
                        posterHeight
                )
                .clipped()
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style:
                            .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style:
                            .continuous
                    )
                    .strokeBorder(
                        isFocused
                            ? Color.cyan
                            : Color.clear,
                        lineWidth:
                            isFocused
                            ? 3
                            : 0
                    )
                )
                .scaleEffect(
                    isFocused
                        ? 1.04
                        : 1
                )
                .animation(
                    .easeOut(
                        duration:
                            0.14
                    ),
                    value:
                        isFocused
                )

                Text(
                    item.name
                )
                .font(
                    .system(
                        size: 20,
                        weight:
                            .semibold
                    )
                )
                .foregroundStyle(
                    .white
                )
                .lineLimit(2)
                .frame(
                    width:
                        posterWidth,
                    alignment:
                        .leading
                )
            }
            .frame(
                width:
                    posterWidth,
                alignment:
                    .topLeading
            )
        }
        .buttonStyle(
            VeyraVODButtonStyle()
        )
        .focused(
            $focusedVODID,
            equals:
                item.id
        )
        .focusEffectDisabled()
    }

    private var posterFallback:
        some View
    {
        ZStack {
            Color.white
                .opacity(0.04)

            Image(
                systemName:
                    "film"
            )
            .font(
                .system(
                    size: 58
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
    }
}

#Preview {
    NavigationStack {
        IPTVRecentlyAddedVODRow()
            .padding()
            .background(
                Color.black
            )
    }
}
