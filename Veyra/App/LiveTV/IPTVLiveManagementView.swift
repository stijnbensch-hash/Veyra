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

    private let configurationStore =
        IPTVConfigurationStore()

    private let preferencesStore =
        IPTVProviderPreferencesStore()

    private let service =
        IPTVService()

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
                spacing: 30
            ) {
                header

                content

                Spacer()
            }
            .padding(70)
        }
        .task {
            await load()
        }
        .onAppear {
            reloadPreferences()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("LIVE TV BEHEREN")
                .font(
                    .system(
                        size: 50,
                        weight: .light
                    )
                )
                .tracking(8)
                .foregroundStyle(.white)

            Text(
                "CATEGORIEËN & KANALEN"
            )
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

                Button("OPNIEUW") {
                    Task {
                        await load()
                    }
                }
            }
        } else if categories.isEmpty {
            Text(
                "Geen Live TV-categorieën gevonden."
            )
            .foregroundStyle(.secondary)
        } else {
            ScrollView(.vertical) {
                LazyVStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    ForEach(categories) { category in
                        categoryRow(category)
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Category Row

    private func categoryRow(
        _ category:
            IPTVLiveManagementCategory
    ) -> some View {
        HStack(spacing: 24) {
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
                    .foregroundStyle(.white)

                Text(
                    categorySubtitle(
                        category
                    )
                )
                .font(.body)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(
                "Zichtbaar",
                isOn: categoryVisibilityBinding(
                    category
                )
            )
            .labelsHidden()

            NavigationLink {
                if let configuration {
                    IPTVChannelManagementView(
                        configuration:
                            configuration,
                        category:
                            category,
                        m3uChannels:
                            m3uChannels
                    )
                }
            } label: {
                Text("KANALEN")
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(
            maxWidth: 1000,
            minHeight: 120
        )
        .background(
            RoundedRectangle(
                cornerRadius: 20
            )
            .fill(
                Color.white.opacity(0.06)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20
            )
            .stroke(
                preferences
                    .isLiveCategoryVisible(
                        category.id
                    )
                    ? Color.cyan.opacity(0.22)
                    : Color.white.opacity(0.08),
                lineWidth: 1
            )
        )
        .opacity(
            preferences
                .isLiveCategoryVisible(
                    category.id
                )
                ? 1.0
                : 0.55
        )
    }

    private func categorySubtitle(
        _ category:
            IPTVLiveManagementCategory
    ) -> String {
        if let channelCount =
            category.channelCount
        {
            return "\(channelCount) kanalen"
        }

        return "Kanalen beheren"
    }

    // MARK: - Visibility

    private func categoryVisibilityBinding(
        _ category:
            IPTVLiveManagementCategory
    ) -> Binding<Bool> {
        Binding(
            get: {
                preferences
                    .isLiveCategoryVisible(
                        category.id
                    )
            },
            set: { visible in
                setCategoryVisibility(
                    category,
                    visible: visible
                )
            }
        )
    }

    private func setCategoryVisibility(
        _ category:
            IPTVLiveManagementCategory,
        visible: Bool
    ) {
        guard let configuration else {
            return
        }

        preferences.setLiveCategory(
            category.id,
            visible: visible
        )

        do {
            try preferencesStore.save(
                preferences,
                for: configuration
            )

            errorMessage = nil
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

        do {
            guard
                let configuration =
                    try configurationStore.load()
            else {
                self.configuration = nil
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

                categories =
                    loadedCategories.map {
                        IPTVLiveManagementCategory(
                            id: $0.id,
                            name: $0.name,
                            sourceType: .xtream,
                            channelCount: nil
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

                m3uChannels = channels

                categories =
                    makeM3UCategories(
                        channels
                    )
            }
        } catch {
            categories = []
            m3uChannels = []

            errorMessage =
                error.localizedDescription
        }

        isLoading = false
    }

    private func reloadPreferences() {
        guard let configuration else {
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
                channel.iptvPreferenceGroupName
            }

        return grouped
            .map { groupName, channels in
                IPTVLiveManagementCategory(
                    id:
                        IPTVChannel
                            .iptvPreferenceGroupID(
                                groupName
                            ),
                    name: groupName,
                    sourceType: .m3u,
                    channelCount:
                        channels.count
                )
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare(
                    $1.name
                ) == .orderedAscending
            }
    }
}

// MARK: - Category Model

struct IPTVLiveManagementCategory:
    Identifiable,
    Hashable
{
    let id: String
    let name: String
    let sourceType: IPTVSourceType
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

    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service =
        IPTVService()

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

                content

                Spacer()
            }
            .padding(70)
        }
        .task {
            await loadChannels()
        }
    }

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text(category.name)
                .font(
                    .system(
                        size: 46,
                        weight: .light
                    )
                )
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
            .foregroundStyle(.secondary)
        } else {
            ScrollView(.vertical) {
                LazyVStack(
                    alignment: .leading,
                    spacing: 14
                ) {
                    ForEach(channels) { channel in
                        channelRow(channel)
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }

    private func channelRow(
        _ channel: IPTVChannel
    ) -> some View {
        HStack(spacing: 20) {
            channelLogo(channel)

            Text(channel.name)
                .font(
                    .system(
                        size: 22,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

            Toggle(
                "Zichtbaar",
                isOn:
                    channelVisibilityBinding(
                        channel
                    )
            )
            .labelsHidden()
        }
        .padding(20)
        .frame(
            maxWidth: 1000,
            minHeight: 100
        )
        .background(
            RoundedRectangle(
                cornerRadius: 18
            )
            .fill(
                Color.white.opacity(0.05)
            )
        )
        .opacity(
            preferences
                .isLiveChannelVisible(
                    channel.id
                )
                ? 1.0
                : 0.50
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
                    .padding(8)

            case .empty:
                ProgressView()

            case .failure:
                Image(
                    systemName: "tv"
                )
                .foregroundStyle(.secondary)

            @unknown default:
                Image(
                    systemName: "tv"
                )
                .foregroundStyle(.secondary)
            }
        }
        .frame(
            width: 100,
            height: 65
        )
        .background(
            Color.white.opacity(0.05)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12
            )
        )
    }

    private func channelVisibilityBinding(
        _ channel: IPTVChannel
    ) -> Binding<Bool> {
        Binding(
            get: {
                preferences
                    .isLiveChannelVisible(
                        channel.id
                    )
            },
            set: { visible in
                setChannelVisibility(
                    channel,
                    visible: visible
                )
            }
        )
    }

    private func setChannelVisibility(
        _ channel: IPTVChannel,
        visible: Bool
    ) {
        preferences.setLiveChannel(
            channel.id,
            visible: visible
        )

        do {
            try preferencesStore.save(
                preferences,
                for: configuration
            )

            errorMessage = nil
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    @MainActor
    private func loadChannels() async {
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
                    m3uChannels
                        .filter {
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

// MARK: - M3U Group Helpers

extension IPTVChannel {
    var iptvPreferenceGroupName: String {
        let value =
            group?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard
            let value,
            !value.isEmpty
        else {
            return "Overig"
        }

        return value
    }

    static func iptvPreferenceGroupID(
        _ groupName: String
    ) -> String {
        "m3u-group:\(groupName)"
    }
}

#Preview {
    NavigationStack {
        IPTVLiveManagementView()
    }
}
