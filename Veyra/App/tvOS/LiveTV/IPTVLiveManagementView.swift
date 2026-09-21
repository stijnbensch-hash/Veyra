import SwiftUI

struct IPTVLiveManagementView: View {
    @State private var configuration:
        IPTVStoredConfiguration?

    @State private var categories:
        [IPTVLiveManagementCategory] = []

    @State private var m3uChannels:
        [IPTVChannel] = []

    @State private var preferences =
        IPTVProviderPreferences()

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var confirmationMessage: String?

    @State private var selectedCategoryID: String?
    @State private var showChannels = false

    @FocusState
    private var focusedControl:
        LiveManagementFocus?

    private let configurationStore =
        IPTVConfigurationStore()

    private let preferencesStore =
        IPTVProviderPreferencesStore()

    private let service =
        IPTVService()

    var body: some View {
        ZStack {
            background

            VStack(
                alignment: .leading,
                spacing: 30
            ) {
                header

                if configuration != nil,
                   !categories.isEmpty {
                    bulkVisibilityControls
                }

                if let confirmationMessage {
                    Text(confirmationMessage)
                        .font(
                            .system(
                                size: 17,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            .cyan.opacity(0.85)
                        )
                }

                content

                Spacer(minLength: 0)
            }
            .padding(.horizontal, VeyraSpacing.page)
            .padding(.top, 36)
            .padding(.bottom, 50)
        }
        .task {
            await load()
        }
        .onAppear {
            reloadPreferences()
        }
        .navigationDestination(
            isPresented: $showChannels
        ) {
            if let category =
                selectedCategory
            {
                IPTVChannelManagementView(
                    configuration:
                        configuration!,
                    category:
                        category,
                    m3uChannels:
                        m3uChannels
                )
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        VeyraBackground()
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("Live TV beheren")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("CATEGORIEËN & KANALEN")
                .font(.caption)
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.75)
                )
        }
    }

    // MARK: - Bulk controls

    private var bulkVisibilityControls:
        some View
    {
        HStack(spacing: 18) {
            bulkControl(
                focus:
                    .showAll,
                title:
                    "ALLES ZICHTBAAR",
                systemImage:
                    "eye.fill"
            ) {
                setAllLiveVisible()
            }

            bulkControl(
                focus:
                    .hideAll,
                title:
                    "ALLES ONZICHTBAAR",
                systemImage:
                    "eye.slash.fill"
            ) {
                setAllLiveHidden()
            }
        }
        .focusSection()
    }

    private func bulkControl(
        focus: LiveManagementFocus,
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        let isFocused =
            focusedControl == focus

        return Label(
            title,
            systemImage: systemImage
        )
        .font(
            .system(
                size: 19,
                weight: .semibold
            )
        )
        .foregroundStyle(
            isFocused
                ? .white
                : .cyan
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(
                isFocused
                    ? Color.cyan.opacity(0.18)
                    : Color.cyan.opacity(0.07)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .strokeBorder(
                isFocused
                    ? Color.cyan
                    : Color.cyan.opacity(0.20),
                lineWidth:
                    isFocused ? 2 : 1
            )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused(
            $focusedControl,
            equals: focus
        )
        .focusEffectDisabled()
        .onTapGesture {
            action()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(
                "Live TV laden…"
            )
            .font(.title3)

        } else if let errorMessage {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                Text(
                    "Live TV kon niet worden geladen"
                )
                .font(.title2)

                Text(errorMessage)
                    .foregroundStyle(
                        .secondary
                    )

                retryControl
            }

        } else if categories.isEmpty {
            Text(
                "Geen Live TV-categorieën gevonden."
            )
            .foregroundStyle(.secondary)

        } else {
            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                LazyVStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    ForEach(categories) {
                        category in

                        categoryRow(
                            category
                        )
                    }
                }
                .padding(.vertical, 10)
                .focusSection()
            }
        }
    }

    private var retryControl:
        some View
    {
        let isFocused =
            focusedControl == .retry

        return Text("OPNIEUW")
            .font(
                .system(
                    size: 18,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                isFocused
                    ? .white
                    : .cyan
            )
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(
                    cornerRadius: 12
                )
                .fill(
                    isFocused
                        ? Color.cyan.opacity(0.18)
                        : Color.cyan.opacity(0.07)
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 12
                )
                .stroke(
                    isFocused
                        ? Color.cyan
                        : Color.cyan.opacity(0.18),
                    lineWidth:
                        isFocused ? 2 : 1
                )
            )
            .contentShape(Rectangle())
            .focusable(true)
            .focused(
                $focusedControl,
                equals: .retry
            )
            .focusEffectDisabled()
            .onTapGesture {
                Task {
                    await load()
                }
            }
    }

    // MARK: - Category

    private func categoryRow(
        _ category:
            IPTVLiveManagementCategory
    ) -> some View {
        let visible =
            preferences
                .isLiveCategoryVisible(
                    category.id
                )

        return HStack(spacing: 14) {
            categoryVisibilityControl(
                category,
                visible: visible
            )

            categoryChannelsControl(
                category
            )
        }
        .frame(maxWidth: 1000)
        .opacity(
            visible
                ? 1
                : 0.62
        )
    }

    private func categoryVisibilityControl(
        _ category:
            IPTVLiveManagementCategory,
        visible: Bool
    ) -> some View {
        let focus =
            LiveManagementFocus
                .category(
                    category.id
                )

        let isFocused =
            focusedControl == focus

        return HStack(spacing: 24) {
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Text(category.name)
                    .font(
                        .system(
                            size: 24,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        .white
                    )

                Text(
                    categorySubtitle(
                        category
                    )
                )
                .font(.body)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Label(
                visible
                    ? "ZICHTBAAR"
                    : "ONZICHTBAAR",
                systemImage:
                    visible
                    ? "eye.fill"
                    : "eye.slash.fill"
            )
            .font(
                .system(
                    size: 17,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                isFocused
                    ? .white
                    : (
                        visible
                            ? .cyan
                            : .secondary
                    )
            )
        }
        .padding(24)
        .frame(
            maxWidth: .infinity,
            minHeight: 120,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .fill(
                isFocused
                    ? Color.cyan.opacity(0.16)
                    : Color.white.opacity(0.035)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .strokeBorder(
                isFocused
                    ? Color.cyan
                    : (
                        visible
                            ? Color.cyan.opacity(0.18)
                            : Color.white.opacity(0.07)
                    ),
                lineWidth:
                    isFocused ? 2 : 1
            )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused(
            $focusedControl,
            equals: focus
        )
        .focusEffectDisabled()
        .onTapGesture {
            setCategoryVisibility(
                category,
                visible: !visible
            )
        }
    }

    private func categoryChannelsControl(
        _ category:
            IPTVLiveManagementCategory
    ) -> some View {
        let focus =
            LiveManagementFocus
                .channels(
                    category.id
                )

        let isFocused =
            focusedControl == focus

        return VStack(spacing: 8) {
            Image(
                systemName:
                    "list.bullet"
            )
            .font(
                .system(
                    size: 24,
                    weight: .semibold
                )
            )

            Text("KANALEN")
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )
        }
        .foregroundStyle(
            isFocused
                ? .white
                : .cyan
        )
        .frame(
            width: 130,
            height: 120
        )
        .background(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .fill(
                isFocused
                    ? Color.cyan.opacity(0.16)
                    : Color.cyan.opacity(0.06)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .strokeBorder(
                isFocused
                    ? Color.cyan
                    : Color.cyan.opacity(0.18),
                lineWidth:
                    isFocused ? 2 : 1
            )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused(
            $focusedControl,
            equals: focus
        )
        .focusEffectDisabled()
        .onTapGesture {
            selectedCategoryID =
                category.id

            showChannels =
                true
        }
    }

    private func categorySubtitle(
        _ category:
            IPTVLiveManagementCategory
    ) -> String {
        if let count =
            category.channelCount
        {
            return
                "\(count) kanalen"
        }

        return
            "Kanalen beheren"
    }

    private var selectedCategory:
        IPTVLiveManagementCategory?
    {
        guard
            let selectedCategoryID
        else {
            return nil
        }

        return categories.first {
            $0.id ==
                selectedCategoryID
        }
    }

    // MARK: - Visibility

    private func setCategoryVisibility(
        _ category:
            IPTVLiveManagementCategory,
        visible: Bool
    ) {
        guard
            let configuration
        else {
            return
        }

        var updated =
            preferences

        updated.setLiveCategory(
            category.id,
            visible: visible
        )

        savePreferences(
            updated,
            configuration:
                configuration
        )
    }

    private func setAllLiveVisible() {
        guard
            let configuration
        else {
            return
        }

        var updated =
            preferences

        updated
            .hiddenLiveCategoryIDs
            .removeAll()

        updated
            .hiddenLiveChannelIDs
            .removeAll()

        savePreferences(
            updated,
            configuration:
                configuration
        )

        confirmationMessage =
            "Alle Live TV-categorieën en kanalen zijn zichtbaar."
    }

    private func setAllLiveHidden() {
        guard
            let configuration
        else {
            return
        }

        var updated =
            preferences

        updated.hiddenLiveCategoryIDs =
            Set(
                categories.map(\.id)
            )

        updated
            .hiddenLiveChannelIDs
            .removeAll()

        savePreferences(
            updated,
            configuration:
                configuration
        )

        confirmationMessage =
            "Alle Live TV-categorieën zijn verborgen."
    }

    private func savePreferences(
        _ updated:
            IPTVProviderPreferences,
        configuration:
            IPTVStoredConfiguration
    ) {
        do {
            try preferencesStore.save(
                updated,
                for: configuration
            )

            preferences =
                updated

            errorMessage =
                nil

            NotificationCenter.default.post(
                name:
                    .iptvConfigurationDidChange,
                object: nil
            )

        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        confirmationMessage = nil

        do {
            guard
                let configuration =
                    try configurationStore
                        .load()
            else {
                self.configuration =
                    nil

                categories = []
                m3uChannels = []

                isLoading = false
                return
            }

            self.configuration =
                configuration

            preferences =
                preferencesStore.load(
                    for: configuration
                )

            switch configuration {
            case .xtream(
                let xtreamConfiguration
            ):
                let loadedCategories =
                    try await service
                        .loadXtreamLiveCategories(
                            configuration:
                                xtreamConfiguration
                        )

                try Task
                    .checkCancellation()

                categories =
                    loadedCategories.map {
                        IPTVLiveManagementCategory(
                            id: $0.id,
                            name: $0.name,
                            sourceType:
                                .xtream,
                            channelCount:
                                nil
                        )
                    }

                m3uChannels = []

            case .m3u(
                let m3uConfiguration
            ):
                let channels =
                    try await service
                        .loadM3UChannels(
                            configuration:
                                m3uConfiguration
                        )

                try Task
                    .checkCancellation()

                m3uChannels =
                    channels

                categories =
                    makeM3UCategories(
                        channels
                    )
            }

        } catch is CancellationError {
        } catch {
            categories = []
            m3uChannels = []

            errorMessage =
                error.localizedDescription
        }

        isLoading = false
    }

    private func reloadPreferences() {
        guard
            let configuration
        else {
            return
        }

        preferences =
            preferencesStore.load(
                for: configuration
            )
    }

    private func makeM3UCategories(
        _ channels: [IPTVChannel]
    ) -> [IPTVLiveManagementCategory] {
        let grouped =
            Dictionary(
                grouping: channels
            ) { channel in
                channel
                    .iptvPreferenceGroupName
            }

        return grouped
            .map {
                groupName,
                channels in

                IPTVLiveManagementCategory(
                    id:
                        IPTVChannel
                            .iptvPreferenceGroupID(
                                groupName
                            ),
                    name: groupName,
                    sourceType:
                        .m3u,
                    channelCount:
                        channels.count
                )
            }
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    )
                    == .orderedAscending
            }
    }
}

// MARK: - Focus

private enum LiveManagementFocus:
    Hashable
{
    case showAll
    case hideAll
    case retry
    case category(String)
    case channels(String)
}

// MARK: - Category Model

struct IPTVLiveManagementCategory:
    Identifiable,
    Hashable
{
    let id: String
    let name: String
    let sourceType:
        IPTVSourceType
    let channelCount: Int?
}

// MARK: - Channel Management

private struct IPTVChannelManagementView:
    View
{
    let configuration:
        IPTVStoredConfiguration

    let category:
        IPTVLiveManagementCategory

    let m3uChannels:
        [IPTVChannel]

    @State private var channels:
        [IPTVChannel] = []

    @State private var preferences =
        IPTVProviderPreferences()

    @State private var isLoading =
        false

    @State private var errorMessage:
        String?

    @FocusState
    private var focusedChannelID:
        String?

    // Logo aanpassen: lang drukken op een zenderlogo opent
    // `ChannelLogoPickerView`. Zie `LiveTVView.swift` voor dezelfde aanpak.
    @State private var editingLogoChannel: IPTVChannel?
    @State private var logoOverrideVersion = 0

    private let service =
        IPTVService()

    private let preferencesStore =
        IPTVProviderPreferencesStore()

    var body: some View {
        ZStack {
            background

            VStack(
                alignment: .leading,
                spacing: 28
            ) {
                header
                content

                Spacer(minLength: 0)
            }
            .padding(.horizontal, VeyraSpacing.page)
            .padding(.top, 36)
            .padding(.bottom, 50)
        }
        .task {
            await loadChannels()
        }
        .onReceive(NotificationCenter.default.publisher(for: .channelOverrideChanged)) { _ in
            logoOverrideVersion += 1
        }
        .sheet(item: $editingLogoChannel) { channel in
            ChannelLogoPickerView(
                channelID: channel.id,
                channelName: channel.name,
                currentOverrideURL: ChannelLogoOverrideStore.logoURL(forChannelID: channel.id),
                currentNameOverride: ChannelNameOverrideStore.name(forChannelID: channel.id)
            ) {
                logoOverrideVersion += 1
            }
        }
    }

    private var background:
        some View
    {
        VeyraBackground()
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text(category.name)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("KANALEN")
                .font(.caption)
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.75)
                )
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(
                "Kanalen laden…"
            )

        } else if let errorMessage {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                Text(
                    "Kanalen konden niet worden geladen"
                )
                .font(.title2)

                Text(errorMessage)
                    .foregroundStyle(
                        .secondary
                    )
            }

        } else if channels.isEmpty {
            Text(
                "Geen kanalen gevonden."
            )
            .foregroundStyle(
                .secondary
            )

        } else {
            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                LazyVStack(
                    alignment: .leading,
                    spacing: 14
                ) {
                    ForEach(channels) {
                        channel in

                        channelControl(
                            channel
                        )
                    }
                }
                .padding(.vertical, 10)
                .focusSection()
            }
        }
    }

    private func channelControl(
        _ channel:
            IPTVChannel
    ) -> some View {
        let isFocused =
            focusedChannelID ==
                channel.id

        let visible =
            preferences
                .isLiveChannelVisible(
                    channel.id
                )

        return HStack(spacing: 20) {
            channelLogo(
                channel
            )

            Text(
                ChannelNameOverrideStore.effectiveName(
                    channelID: channel.id, defaultName: channel.name
                )
            )
                .font(
                    .system(
                        size: 22,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .white
                )
                .lineLimit(2)

            Spacer()

            Label(
                visible
                    ? "ZICHTBAAR"
                    : "ONZICHTBAAR",
                systemImage:
                    visible
                    ? "eye.fill"
                    : "eye.slash.fill"
            )
            .font(
                .system(
                    size: 17,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                isFocused
                    ? .white
                    : (
                        visible
                            ? .cyan
                            : .secondary
                    )
            )
        }
        .padding(20)
        .frame(
            maxWidth: 1000,
            minHeight: 100
        )
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                isFocused
                    ? Color.cyan.opacity(0.16)
                    : Color.white.opacity(0.035)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .strokeBorder(
                isFocused
                    ? Color.cyan
                    : Color.clear,
                lineWidth:
                    isFocused ? 2 : 0
            )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused(
            $focusedChannelID,
            equals: channel.id
        )
        .focusEffectDisabled()
        .opacity(
            visible
                ? 1
                : 0.58
        )
        .onTapGesture {
            setChannelVisibility(
                channel,
                visible: !visible
            )
        }
        .contextMenu {
            Button {
                editingLogoChannel = channel
            } label: {
                Label("Logo/naam aanpassen…", systemImage: "photo.badge.plus")
            }

            if ChannelLogoOverrideStore.logoURL(forChannelID: channel.id) != nil {
                Button(role: .destructive) {
                    ChannelLogoOverrideStore.removeOverride(forChannelID: channel.id)
                    logoOverrideVersion += 1
                } label: {
                    Label("Standaardlogo herstellen", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }

    @ViewBuilder
    private func channelLogo(
        _ channel: IPTVChannel
    ) -> some View {
        AsyncImage(
            url: ChannelLogoOverrideStore.effectiveLogoURL(
                channelID: channel.id, defaultLogoURL: channel.logoURL
            )
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .padding(8)

            case .empty:
                ProgressView()

            case .failure:
                Image(
                    systemName: "tv"
                )
                .foregroundStyle(
                    .secondary
                )

            @unknown default:
                Image(
                    systemName: "tv"
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .id(logoOverrideVersion)
        .frame(
            width: 100,
            height: 65
        )
        .background(
            Color.white.opacity(0.04)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12
            )
        )
    }

    private func setChannelVisibility(
        _ channel: IPTVChannel,
        visible: Bool
    ) {
        var updated =
            preferences

        updated.setLiveChannel(
            channel.id,
            visible: visible
        )

        do {
            try preferencesStore.save(
                updated,
                for: configuration
            )

            preferences =
                updated

            errorMessage = nil

            NotificationCenter.default.post(
                name:
                    .iptvConfigurationDidChange,
                object: nil
            )

        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    @MainActor
    private func loadChannels()
        async
    {
        isLoading = true
        errorMessage = nil

        preferences =
            preferencesStore.load(
                for: configuration
            )

        do {
            switch configuration {
            case .xtream(
                let xtreamConfiguration
            ):
                channels =
                    try await service
                        .loadXtreamLiveChannels(
                            configuration:
                                xtreamConfiguration,
                            categoryID:
                                category.id
                        )

            case .m3u:
                channels =
                    m3uChannels.filter {
                        $0.iptvPreferenceGroupName
                            == category.name
                    }
            }

        } catch {
            channels = []

            errorMessage =
                error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        IPTVLiveManagementView()
    }
}
