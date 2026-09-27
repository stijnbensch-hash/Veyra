import SwiftUI

/// Channel guide shown over live playback. It uses the same store as the main
/// Live TV guide, so favorite changes and programme data stay in sync.
struct LivePlayerChannelPanel: View {
    enum Filter: Hashable {
        case guide
        case favorites
    }

    @ObservedObject var guide: VeyraEPGStore
    let currentSource: PlayableSource?
    let onSelect: (VeyraGuideChannel) -> Void
    let onClose: () -> Void

    @State private var filter: Filter
    @FocusState private var focused: FocusTarget?

    private enum FocusTarget: Hashable {
        case tab(Filter)
        case channel(String)
        case favorite(String)
        case close
    }

    init(
        guide: VeyraEPGStore,
        currentSource: PlayableSource?,
        initialFilter: Filter,
        onSelect: @escaping (VeyraGuideChannel) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.guide = guide
        self.currentSource = currentSource
        self.onSelect = onSelect
        self.onClose = onClose
        _filter = State(initialValue: initialFilter)
    }

    private var rows: [VeyraGuideChannel] {
        filter == .favorites ? guide.favoriteRows : guide.channels
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("LIVE TV")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(VeyraColors.cyan)
                    Text("Programmagids")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                }

                Spacer()

                Button { filter = .guide } label: {
                    Label("Gids", systemImage: "list.bullet.rectangle")
                        .font(.system(size: 20, weight: .semibold))
                        .padding(.horizontal, 22).padding(.vertical, 13)
                        .background(filter == .guide ? VeyraColors.cyan.opacity(0.28) : .clear,
                                    in: Capsule())
                }
                .focused($focused, equals: .tab(.guide))

                Button { filter = .favorites } label: {
                    Label("Favorieten", systemImage: "star.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .padding(.horizontal, 22).padding(.vertical, 13)
                        .background(filter == .favorites ? VeyraColors.red.opacity(0.28) : .clear,
                                    in: Capsule())
                }
                .focused($focused, equals: .tab(.favorites))

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 54, height: 54)
                }
                .focused($focused, equals: .close)
                .accessibilityLabel("Gids sluiten")
            }
            .buttonStyle(VeyraFocusButtonStyle(radius: VeyraRadius.pill))
            .focusSection()

            if guide.loadingChannels && guide.channels.isEmpty {
                HStack(spacing: 16) {
                    ProgressView()
                    Text("Zenders laden…")
                }
                .font(.system(size: 22))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rows.isEmpty {
                Text(filter == .favorites
                     ? "Nog geen favoriete zenders. Voeg een ster toe in de gids."
                     : "Er zijn geen zenders beschikbaar.")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(rows) { row in
                            channelRow(row)
                        }
                    }
                    .padding(10)
                }
                .focusSection()
            }
        }
        .padding(30)
        .frame(width: 1510, height: 760)
        .veyraGlass(backgroundOpacity: 0.78)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                focused = .tab(filter)
            }
        }
    }

    private func channelRow(_ row: VeyraGuideChannel) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let programmes = guide.programmes(for: row)
            let current = programmes.first { $0.isOnAir(at: now) }
            let next = programmes.first { $0.start >= (current?.end ?? now) }
            let isCurrent = row.channel.streamURL == currentSource?.url
            let isFavorite = guide.favorites.contains(row.id)

            HStack(spacing: 12) {
                Button { onSelect(row) } label: {
                    HStack(spacing: 22) {
                        AsyncImage(url: ChannelLogoOverrideStore.logoURL(
                            forChannelID: row.channel.id) ?? row.channel.logoURL
                        ) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFit()
                            } else {
                                Image(systemName: "tv")
                                    .resizable().scaledToFit()
                                    .foregroundStyle(VeyraColors.ice.opacity(0.65))
                            }
                        }
                        .frame(width: 92, height: 56)

                        Text(ChannelNameOverrideStore.effectiveName(
                            channelID: row.channel.id,
                            defaultName: row.channel.name
                        ))
                        .font(.system(size: 22, weight: .semibold))
                        .lineLimit(1)
                        .frame(width: 260, alignment: .leading)

                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 12) {
                                Text("NU")
                                    .foregroundStyle(VeyraColors.cyan)
                                Text(current?.title ?? "Geen programmainformatie")
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                if let current {
                                    Text("\(clock(current.start))–\(clock(current.end))")
                                        .monospacedDigit()
                                        .foregroundStyle(.white.opacity(0.72))
                                }
                            }
                            if let next {
                                HStack(spacing: 12) {
                                    Text("HIERNA")
                                        .foregroundStyle(VeyraColors.cyan.opacity(0.78))
                                    Text(next.title).lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text(clock(next.start))
                                        .monospacedDigit()
                                        .foregroundStyle(.white.opacity(0.62))
                                }
                                .font(.system(size: 16))
                            }
                        }
                        .font(.system(size: 19, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 92)
                    .background(isCurrent ? VeyraColors.cyan.opacity(0.22) : .white.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 15))
                }
                .focused($focused, equals: .channel(row.id))

                Button {
                    if filter == .favorites && isFavorite {
                        focused = .tab(.favorites)
                    }
                    guide.toggleFavorite(row)
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? VeyraColors.cyan : .white.opacity(0.72))
                        .font(.system(size: 24))
                        .frame(width: 65, height: 65)
                }
                .focused($focused, equals: .favorite(row.id))
                .accessibilityLabel(isFavorite ? "Verwijder uit favorieten" : "Voeg toe aan favorieten")
            }
            .buttonStyle(VeyraFocusButtonStyle())
        }
    }

    private func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
