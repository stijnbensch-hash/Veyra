import SwiftUI

@MainActor
struct VeyraRecentLiveTVHomeView: View {
    @StateObject
    private var guide = VeyraEPGStore()

    @Environment(\.scenePhase)
    private var scenePhase

    @State
    private var selectedSource: PlayableSource?

    @FocusState
    private var focusedChannelID: String?

    private var recentChannels: [VeyraGuideChannel] {
        let order = Dictionary(
            uniqueKeysWithValues:
                guide.recent.enumerated().map {
                    ($1, $0)
                }
        )

        return Array(
            guide.channels
                .filter {
                    order[$0.id] != nil
                }
                .sorted {
                    (order[$0.id] ?? Int.max)
                        <
                    (order[$1.id] ?? Int.max)
                }
                .prefix(5)
        )
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            header

            if guide.loadingChannels
                && recentChannels.isEmpty
            {
                loadingView
            } else if recentChannels.isEmpty {
                emptyView
            } else {
                TimelineView(
                    .periodic(
                        from: .now,
                        by: 30
                    )
                ) { context in
                    guideRows(
                        now: context.date
                    )
                }
            }
        }
        .task {
            guide.reloadID = UUID()
            await guide.reload()
        }
        .onChange(
            of: scenePhase
        ) { _, phase in
            guard phase == .active else {
                return
            }

            Task {
                guide.reloadID = UUID()
                await guide.reload()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .iptvConfigurationDidChange
            )
        ) { _ in
            Task {
                guide.reloadID = UUID()
                await guide.reload()
            }
        }
        .navigationDestination(
            item: $selectedSource
        ) { source in
            PlayerView(
                source: source,
                item: MediaItem(
                    title: source.name,
                    type: .liveTV
                )
            )
        }
    }

    private var header: some View {
        VeyraSectionHeader(
            title: "TV-gids",
            subtitle: "Recent bekeken zenders"
        )
    }

    private var loadingView: some View {
        HStack(spacing: 14) {
            ProgressView()

            Text("TV-gids laden…")
                .font(
                    .system(
                        size: 21
                    )
                )
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 110)
    }

    private var emptyView: some View {
        HStack(spacing: 16) {
            Image(systemName: "tv")
                .font(
                    .system(
                        size: 30
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(0.65)
                )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text("Nog geen recente zenders")
                    .font(
                        .system(
                            size: 22,
                            weight: .semibold
                        )
                    )

                Text(
                    "Bekijk een Live TV-kanaal en het verschijnt hier automatisch."
                )
                .font(
                    .system(
                        size: 18
                    )
                )
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 22)
    }

    private func guideRows(
        now: Date
    ) -> some View {
        VStack(spacing: 10) {
            ForEach(recentChannels) { row in
                channelRow(
                    row,
                    now: now
                )
            }
        }
    }

    private func channelRow(
        _ row: VeyraGuideChannel,
        now: Date
    ) -> some View {
        let focused =
            focusedChannelID == row.id

        return HStack(spacing: 10) {
            channelTile(row)

            programmeStrip(
                row,
                now: now
            )
        }
        .frame(height: 100)
        .padding(4)
        .background(
            RoundedRectangle(
                cornerRadius: VeyraRadius.card,
                style: .continuous
            )
            .fill(
                focused
                    ? VeyraColors.cyan.opacity(0.14)
                    : VeyraColors.surface.opacity(0.68)
            )
        )
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(
                cornerRadius: VeyraRadius.card,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: VeyraRadius.card,
                style: .continuous
            )
            .strokeBorder(
                focused
                    ? VeyraColors.cyan
                    : .white.opacity(0.10),
                lineWidth:
                    focused ? 2 : 0
            )
        }
        .contentShape(
            RoundedRectangle(
                cornerRadius: VeyraRadius.card,
                style: .continuous
            )
        )
        .focusable(true)
        .focused(
            $focusedChannelID,
            equals: row.id
        )
        .focusEffectDisabled()
        .onTapGesture {
            selectedSource =
                guide.play(row)
        }
        .scaleEffect(
            focused ? 1.012 : 1
        )
        .shadow(
            color:
                focused
                    ? VeyraColors.cyan.opacity(0.26)
                    : .clear,
            radius:
                focused ? 12 : 0
        )
        .animation(
            .easeOut(duration: 0.14),
            value: focused
        )
    }

    private func channelTile(
        _ row: VeyraGuideChannel
    ) -> some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .fill(
                Color.white.opacity(0.07)
            )

            AsyncImage(
                url: ChannelLogoOverrideStore.effectiveLogoURL(
                    channelID: row.channel.id, defaultLogoURL: row.channel.logoURL
                )
            ) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)

                case .empty:
                    ProgressView()
                        .scaleEffect(0.7)

                case .failure:
                    channelPlaceholder(row)

                @unknown default:
                    channelPlaceholder(row)
                }
            }
        }
        .frame(
            width: 150,
            height: 92
        )
    }

    private func channelPlaceholder(
        _ row: VeyraGuideChannel
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "tv")
                .font(
                    .system(
                        size: 27,
                        weight: .medium
                    )
                )

            Text(row.channel.name)
                .font(
                    .system(
                        size: 13,
                        weight: .semibold
                    )
                )
                .lineLimit(1)
        }
        .foregroundStyle(
            .cyan.opacity(0.72)
        )
        .padding(8)
    }

    private func programmeStrip(
        _ row: VeyraGuideChannel,
        now: Date
    ) -> some View {
        GeometryReader { geometry in
            let programmes =
                visibleProgrammes(
                    for: row,
                    now: now
                )

            if programmes.isEmpty {
                noProgrammeView
            } else {
                HStack(spacing: 8) {
                    ForEach(programmes) { programme in
                        programmeCell(
                            programme,
                            now: now,
                            isFirst:
                                programme.id
                                == programmes.first?.id,
                            availableWidth:
                                geometry.size.width
                        )
                    }

                    Spacer(minLength: 0)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .leading
                )
                .clipped()
            }
        }
    }

    private var noProgrammeView: some View {
        HStack {
            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                Text("Geen programma-informatie")
                    .font(
                        .system(
                            size: 19,
                            weight: .semibold
                        )
                    )

                Text("EPG niet beschikbaar")
                    .font(
                        .system(
                            size: 14
                        )
                    )
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .fill(
                Color.white.opacity(0.055)
            )
        )
    }

    private func visibleProgrammes(
        for row: VeyraGuideChannel,
        now: Date
    ) -> [VeyraEPGProgramme] {
        let programmes =
            guide.programmes(for: row)
                .sorted {
                    $0.start < $1.start
                }

        guard !programmes.isEmpty else {
            return []
        }

        if let currentIndex =
            programmes.firstIndex(
                where: {
                    $0.isOnAir(at: now)
                }
            )
        {
            let endIndex =
                min(
                    programmes.count,
                    currentIndex + 5
                )

            return Array(
                programmes[
                    currentIndex..<endIndex
                ]
            )
        }

        return Array(
            programmes
                .filter {
                    $0.start > now
                }
                .prefix(5)
        )
    }

    private func programmeCell(
        _ programme: VeyraEPGProgramme,
        now: Date,
        isFirst: Bool,
        availableWidth: CGFloat
    ) -> some View {
        let isLive =
            programme.isOnAir(at: now)

        let width =
            programmeWidth(
                programme,
                availableWidth: availableWidth,
                isFirst: isFirst
            )

        return ZStack(
            alignment: .leading
        ) {
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .fill(
                Color.white.opacity(
                    isLive ? 0.12 : 0.065
                )
            )

            if isLive {
                GeometryReader { geometry in
                    RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                    .fill(
                        Color.white.opacity(0.10)
                    )
                    .frame(
                        width:
                            geometry.size.width
                            * programmeProgress(
                                programme,
                                now: now
                            )
                    )
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                )
            }

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                HStack(spacing: 8) {
                    Text(
                        time(programme.start)
                    )
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(0.60)
                    )

                    if isLive {
                        Text("NU")
                            .font(
                                .system(
                                    size: 11,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(.cyan)
                    }
                }

                Text(programme.title)
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .frame(
            width: width,
            height: 92
        )
        .overlay(
            alignment: .bottomLeading
        ) {
            if isLive {
                GeometryReader { geometry in
                    Capsule()
                        .fill(Color.cyan)
                        .frame(
                            width:
                                max(
                                    0,
                                    geometry.size.width
                                    * programmeProgress(
                                        programme,
                                        now: now
                                    )
                                ),
                            height: 3
                        )
                }
                .frame(height: 3)
                .padding(.horizontal, 12)
                .padding(.bottom, 7)
            }
        }
    }

    private func programmeWidth(
        _ programme: VeyraEPGProgramme,
        availableWidth: CGFloat,
        isFirst: Bool
    ) -> CGFloat {
        let duration =
            max(
                300,
                programme.end.timeIntervalSince(
                    programme.start
                )
            )

        let hours =
            duration / 3600

        let baseWidth =
            max(
                190,
                availableWidth * 0.25
            )

        let calculated =
            baseWidth
            * max(
                0.75,
                min(hours, 2.4)
            )

        if isFirst {
            return min(
                max(calculated, 260),
                520
            )
        }

        return min(
            max(calculated, 190),
            440
        )
    }

    private func programmeProgress(
        _ programme: VeyraEPGProgramme,
        now: Date
    ) -> CGFloat {
        let duration =
            programme.end.timeIntervalSince(
                programme.start
            )

        guard duration > 0 else {
            return 0
        }

        let elapsed =
            now.timeIntervalSince(
                programme.start
            )

        return CGFloat(
            min(
                max(
                    elapsed / duration,
                    0
                ),
                1
            )
        )
    }

    private func time(
        _ date: Date
    ) -> String {
        Self.timeFormatter.string(
            from: date
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()

        formatter.locale =
            Locale(
                identifier: "nl_BE"
            )

        formatter.timeZone =
            .autoupdatingCurrent

        formatter.dateFormat = "HH:mm"

        return formatter
    }()
}

#Preview {
    NavigationStack {
        ScrollView(
            .vertical,
            showsIndicators: false
        ) {
            VeyraRecentLiveTVHomeView()
                .padding(60)
        }
        .background(
            Color.black
                .ignoresSafeArea()
        )
    }
}
