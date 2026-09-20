import SwiftUI

struct LiveTVView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case live = "LIVE TV"
        case vod = "VOD"

        var id: Self {
            self
        }
    }

    @State private var configuration:
        IPTVStoredConfiguration?

    @State private var preferences =
        IPTVProviderPreferences()

    @State private var section: Section = .live

    @State private var liveCategories:
        [IPTVCategory] = []

    @State private var vodCategories:
        [IPTVCategory] = []

    @State private var liveChannels:
        [IPTVChannel] = []

    @State private var vodItems:
        [IPTVVODItem] = []

    @State private var selectedLiveCategory:
        IPTVCategory?

    @State private var selectedVODCategory:
        IPTVCategory?

    @State private var selectedSource:
        PlayableSource?

    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service =
        IPTVService()

    private let configurationStore =
        IPTVConfigurationStore()

    private let preferencesStore =
        IPTVProviderPreferencesStore()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(
                        red: 0.01,
                        green: 0.04,
                        blue: 0.07
                    ),
                    Color(
                        red: 0.02,
                        green: 0.10,
                        blue: 0.16
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 28
            ) {
                header

                if configuration == nil {
                    configurationRequired
                } else {
                    content
                }
            }
            .padding(70)
        }
        .task {
            await loadConfiguration()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .iptvConfigurationDidChange
            )
        ) { _ in
            Task {
                await loadConfiguration()
            }
        }
        .navigationDestination(
            item: $selectedSource
        ) { source in
            PlayerView(
                source: source
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("LIVE TV")
                .font(
                    .system(
                        size: 54,
                        weight: .light
                    )
                )
                .tracking(12)
                .foregroundStyle(.white)

            Text(sourceLabel)
                .font(.caption)
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.75)
                )
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isXtream {
            Picker(
                "IPTV-inhoud",
                selection: $section
            ) {
                ForEach(
                    Section.allCases
                ) { section in
                    Text(section.rawValue)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 600)

            if section == .live {
                xtreamLiveContent
            } else {
                xtreamVODContent
            }
        } else {
            m3uContent
        }
    }

    // MARK: - M3U

    @ViewBuilder
    private var m3uContent: some View {
        if isLoading {
            loadingView(
                text: "Zenders laden…"
            )
        } else if let errorMessage {
            errorView(errorMessage)
        } else if liveChannels.isEmpty {
            emptyView(
                text: "Geen zichtbare zenders"
            )
        } else {
            liveChannelRow
        }
    }

    // MARK: - Xtream Live

    @ViewBuilder
    private var xtreamLiveContent:
        some View
    {
        if isLoading &&
            liveCategories.isEmpty
        {
            loadingView(
                text: "Live TV laden…"
            )
        } else if let errorMessage {
            errorView(errorMessage)
        } else if selectedLiveCategory == nil {
            if liveCategories.isEmpty {
                emptyView(
                    text: "Geen zichtbare Live TV-categorieën"
                )
            } else {
                categorySection(
                    title: "LIVE TV CATEGORIEËN",
                    categories: liveCategories
                ) { category in
                    Task {
                        await selectLiveCategory(
                            category
                        )
                    }
                }
            }
        } else {
            VStack(
                alignment: .leading,
                spacing: 22
            ) {
                backToCategoriesButton {
                    selectedLiveCategory = nil
                    liveChannels = []
                    errorMessage = nil
                }

                if let selectedLiveCategory {
                    Text(
                        selectedLiveCategory.name
                            .uppercased()
                    )
                    .font(
                        .system(
                            size: 24,
                            weight: .semibold
                        )
                    )
                    .tracking(3)
                    .foregroundStyle(
                        .cyan.opacity(0.85)
                    )
                }

                if isLoading {
                    loadingView(
                        text: "Zenders laden…"
                    )
                } else if liveChannels.isEmpty {
                    emptyView(
                        text: "Geen zichtbare zenders"
                    )
                } else {
                    liveChannelRow
                }
            }
        }
    }

    // MARK: - Xtream VOD

    @ViewBuilder
    private var xtreamVODContent:
        some View
    {
        if isLoading &&
            vodCategories.isEmpty
        {
            loadingView(
                text: "VOD laden…"
            )
        } else if let errorMessage {
            errorView(errorMessage)
        } else if selectedVODCategory == nil {
            if vodCategories.isEmpty {
                emptyView(
                    text: "Geen zichtbare VOD-categorieën"
                )
            } else {
                categorySection(
                    title: "VOD CATEGORIEËN",
                    categories: vodCategories
                ) { category in
                    Task {
                        await selectVODCategory(
                            category
                        )
                    }
                }
            }
        } else {
            VStack(
                alignment: .leading,
                spacing: 22
            ) {
                backToCategoriesButton {
                    selectedVODCategory = nil
                    vodItems = []
                    errorMessage = nil
                }

                if let selectedVODCategory {
                    Text(
                        selectedVODCategory.name
                            .uppercased()
                    )
                    .font(
                        .system(
                            size: 24,
                            weight: .semibold
                        )
                    )
                    .tracking(3)
                    .foregroundStyle(
                        .cyan.opacity(0.85)
                    )
                }

                if isLoading {
                    loadingView(
                        text: "VOD laden…"
                    )
                } else if vodItems.isEmpty {
                    emptyView(
                        text: "Geen zichtbare VOD gevonden"
                    )
                } else {
                    vodRow
                }
            }
        }
    }

    // MARK: - Categories

    private func categorySection(
        title: String,
        categories: [IPTVCategory],
        action: @escaping (IPTVCategory) -> Void
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            Text(title)
                .font(
                    .system(
                        size: 24,
                        weight: .semibold
                    )
                )
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.85)
                )

            ScrollView(.horizontal) {
                LazyHStack(spacing: 22) {
                    ForEach(categories) { category in
                        Button {
                            action(category)
                        } label: {
                            Text(category.name)
                                .font(
                                    .system(
                                        size: 22,
                                        weight: .semibold
                                    )
                                )
                                .lineLimit(2)
                                .frame(
                                    width: 260,
                                    height: 110
                                )
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Live Channel Row

    private var liveChannelRow: some View {
        ScrollView(.horizontal) {
            LazyHStack(
                alignment: .top,
                spacing: 30
            ) {
                ForEach(liveChannels) { channel in
                    liveChannelCard(channel)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 20)
        }
        .frame(height: 300)
    }

    private func liveChannelCard(
        _ channel: IPTVChannel
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Button {
                selectedSource =
                    service.playableSource(
                        for: channel
                    )
            } label: {
                channelLogo(channel)
            }
            .buttonStyle(.card)

            Text(channel.name)
                .font(
                    .system(
                        size: 22,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(0.85)
                )
                .lineLimit(2)
                .frame(
                    width: 250,
                    alignment: .leading
                )
        }
        .frame(
            width: 250,
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private func channelLogo(
        _ channel: IPTVChannel
    ) -> some View {
        AsyncImage(
            url: channel.logoURL
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .padding(18)

            case .empty:
                ZStack {
                    channelPlaceholder
                    ProgressView()
                }

            case .failure:
                channelPlaceholder

            @unknown default:
                channelPlaceholder
            }
        }
        .frame(
            width: 250,
            height: 150
        )
        .background(
            Color.white.opacity(0.06)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    private var channelPlaceholder:
        some View
    {
        ZStack {
            Color.white.opacity(0.05)

            Image(systemName: "tv")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - VOD Row

    private var vodRow: some View {
        ScrollView(.horizontal) {
            LazyHStack(
                alignment: .top,
                spacing: 35
            ) {
                ForEach(vodItems) { item in
                    vodCard(item)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 20)
        }
        .frame(height: 520)
    }

    private func vodCard(
        _ item: IPTVVODItem
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            Button {
                selectedSource =
                    service.playableSource(
                        for: item
                    )
            } label: {
                vodPoster(item)
            }
            .buttonStyle(.card)

            Text(item.name)
                .font(
                    .system(
                        size: 26,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(0.85)
                )
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(
                    width: 260,
                    alignment: .leading
                )
                .frame(
                    minHeight: 64,
                    alignment: .topLeading
                )
        }
        .frame(
            width: 260,
            height: 480,
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private func vodPoster(
        _ item: IPTVVODItem
    ) -> some View {
        AsyncImage(
            url: item.posterURL
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()

            case .empty:
                ZStack {
                    vodPlaceholder
                    ProgressView()
                }

            case .failure:
                vodPlaceholder

            @unknown default:
                vodPlaceholder
            }
        }
        .frame(
            width: 260,
            height: 390
        )
        .clipped()
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    private var vodPlaceholder:
        some View
    {
        ZStack {
            Color.white.opacity(0.08)

            Image(systemName: "film")
                .font(.system(size: 55))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - No Configuration

    @ViewBuilder
    private var configurationRequired:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            Image(systemName: "tv")
                .font(
                    .system(
                        size: 48,
                        weight: .light
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(0.75)
                )

            Text("Geen IPTV-bron ingesteld")
                .font(.title2)

            Text(
                "Configureer IPTV via Instellingen → IPTV."
            )
            .foregroundStyle(.secondary)
        }

        Spacer()
    }

    // MARK: - Shared UI

    private func loadingView(
        text: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            ProgressView()

            Text(text)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(
        _ message: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            Text("IPTV kon niet worden geladen")
                .font(.title2)

            Text(message)
                .foregroundStyle(.secondary)

            Button("OPNIEUW") {
                Task {
                    await loadConfiguration()
                }
            }
        }
    }

    private func emptyView(
        text: String
    ) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
    }

    private func backToCategoriesButton(
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(
                "Categorieën",
                systemImage: "chevron.left"
            )
        }
        .buttonStyle(.bordered)
    }

    // MARK: - State

    private var isXtream: Bool {
        guard let configuration else {
            return false
        }

        if case .xtream = configuration {
            return true
        }

        return false
    }

    private var sourceLabel: String {
        guard let configuration else {
            return "IPTV"
        }

        switch configuration {
        case .m3u(let configuration):
            return "\(configuration.displayName.uppercased()) · M3U"

        case .xtream(let configuration):
            return "\(configuration.displayName.uppercased()) · XTREAM"
        }
    }

    // MARK: - Filtering

    private func visibleM3UChannels(
        _ channels: [IPTVChannel]
    ) -> [IPTVChannel] {
        channels.filter { channel in
            let categoryID =
                IPTVChannel
                    .iptvPreferenceGroupID(
                        channel
                            .iptvPreferenceGroupName
                    )

            return preferences
                .isLiveCategoryVisible(
                    categoryID
                )
                &&
                preferences
                    .isLiveChannelVisible(
                        channel.id
                    )
        }
    }

    // MARK: - Loading

    @MainActor
    private func loadConfiguration() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        liveCategories = []
        vodCategories = []
        liveChannels = []
        vodItems = []

        selectedLiveCategory = nil
        selectedVODCategory = nil
        selectedSource = nil

        defer {
            isLoading = false
        }

        do {
            configuration =
                try configurationStore.load()

            guard let configuration else {
                preferences =
                    IPTVProviderPreferences()

                return
            }

            preferences =
                preferencesStore.load(
                    for: configuration
                )

            switch configuration {
            case .m3u(let configuration):
                let channels =
                    try await service
                        .loadM3UChannels(
                            configuration:
                                configuration
                        )

                liveChannels =
                    visibleM3UChannels(
                        channels
                    )

            case .xtream(let configuration):
                async let live =
                    service
                        .loadXtreamLiveCategories(
                            configuration:
                                configuration
                        )

                async let vod =
                    service
                        .loadXtreamVODCategories(
                            configuration:
                                configuration
                        )

                let results =
                    try await (live, vod)

                liveCategories =
                    results.0.filter {
                        preferences
                            .isLiveCategoryVisible(
                                $0.id
                            )
                    }

                vodCategories =
                    results.1.filter {
                        preferences
                            .isVODCategoryVisible(
                                $0.id
                            )
                    }
            }
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    @MainActor
    private func selectLiveCategory(
        _ category: IPTVCategory
    ) async {
        guard
            case .xtream(let configuration) =
                configuration
        else {
            return
        }

        selectedLiveCategory = category
        liveChannels = []

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let channels =
                try await service
                    .loadXtreamLiveChannels(
                        configuration:
                            configuration,
                        categoryID:
                            category.id
                    )

            liveChannels =
                channels.filter {
                    preferences
                        .isLiveChannelVisible(
                            $0.id
                        )
                }
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    @MainActor
    private func selectVODCategory(
        _ category: IPTVCategory
    ) async {
        guard
            case .xtream(let configuration) =
                configuration
        else {
            return
        }

        selectedVODCategory = category
        vodItems = []

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let items =
                try await service
                    .loadXtreamVOD(
                        configuration:
                            configuration,
                        categoryID:
                            category.id
                    )

            vodItems =
                items.filter {
                    preferences
                        .isVODItemVisible(
                            $0.id
                        )
                }
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        LiveTVView()
    }
}
