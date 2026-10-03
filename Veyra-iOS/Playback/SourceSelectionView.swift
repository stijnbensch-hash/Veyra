import SwiftUI

@MainActor
struct SourceSelectionView: View {
    let item: MediaItem
    @Environment(\.veyraEpisodeReturn) private var inheritedEpisodeReturn

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SourceSelectionViewModel
    @ObservedObject private var traktStore = TraktStore.shared
    @ObservedObject private var badgeStore = SourceBadgeStore.shared
    @State private var selectedSource: PlayableSource?
    @State private var selectedFilter: SourceFilter = .all
    @State private var hoveredFilterID: String?
    @State private var hoveredSourceID: UUID?

    // "Eerste bron automatisch selecteren" (Afspelen-instellingen).
    @AppStorage(PlaybackSettingsDefaults.autoSelectFirstSourceKey)
    private var autoSelectFirstSource = false

    init(item: MediaItem) {
        self.item = item
        _viewModel = StateObject(wrappedValue: SourceSelectionViewModel(item: item))
    }

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= 720

            ZStack {
                VeyraBackground()

                VStack(alignment: .leading, spacing: isWide ? 22 : 16) {
                    sourceHeader(isWide: isWide)
                    filterBar(isWide: isWide)
                    sourceContent(isWide: isWide)
                }
                .padding(.horizontal, isWide ? 32 : 16)
                .padding(.top, isWide ? 26 : 14)
                .padding(.bottom, 12)
                .frame(maxWidth: 1280)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle("Selecteer bron")
        .sourceSelectionInlineTitle()
        .task { await viewModel.loadSources() }
        .onReceive(NotificationCenter.default.publisher(for: .iptvConfigurationDidChange)) { _ in
            Task { await viewModel.loadSources() }
        }
        .onChange(of: viewModel.hasLoaded) { _, hasLoaded in
            guard hasLoaded, autoSelectFirstSource, selectedSource == nil,
                  let first = viewModel.sources.first
            else { return }
            selectedSource = first.source
        }
        .onChange(of: viewModel.sources) { _, _ in
            // Als het huidige filter geen bronnen meer oplevert (bv. na een
            // herlaadbeurt) val terug op "Alle" in plaats van een lege lijst
            // te tonen voor een filter dat niet meer bestaat.
            guard !filters.contains(selectedFilter) else { return }
            selectedFilter = .all
        }
        .navigationDestination(item: $selectedSource) { source in
            PlayerView(
                source: source,
                item: item,
                resumeProgress: traktStore.progress(for: item)
            )
            .environment(\.veyraEpisodeReturn, inheritedEpisodeReturn ?? { selectedSource = nil })
        }
        .onChange(of: selectedSource) { previous, current in
            guard previous != nil, current == nil,
                  item.type == .series, item.seasonNumber != nil,
                  item.episodeNumber != nil else { return }
            Task { @MainActor in
                await Task.yield()
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func sourceHeader(isWide: Bool) -> some View {
        if isWide {
            HStack(alignment: .center, spacing: 24) {
                headerLabels(isWide: true)
                Spacer(minLength: 16)
                mediaLogo(isWide: true)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                headerLabels(isWide: false)
                mediaLogo(isWide: false)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func headerLabels(isWide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Selecteer bron")
                .font(.system(size: isWide ? 38 : 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(mediaDescription)
                .font(.system(size: isWide ? 16 : 14))
                .foregroundStyle(.white.opacity(0.58))
        }
    }

    private func mediaLogo(isWide: Bool) -> some View {
        VeyraClearLogo(
            item: item,
            fallbackTitle: item.title,
            maxWidth: isWide ? 380 : 220,
            maxHeight: isWide ? 92 : 58,
            font: .system(size: isWide ? 28 : 22, weight: .semibold, design: .rounded),
            alignment: .trailing
        )
        .frame(width: isWide ? 380 : 220, height: isWide ? 92 : 58, alignment: .trailing)
        .accessibilityLabel(item.title)
    }

    // MARK: - Filter

    private enum SourceFilter: Hashable {
        case all
        case iptv
        case origin(name: String, isHub: Bool)

        var id: String {
            switch self {
            case .all: return "all"
            case .iptv: return "iptv"
            case .origin(let name, let isHub): return "origin:\(name):\(isHub)"
            }
        }
    }

    /// IPTV en "Alle" staan altijd vooraan; daarna een knop per addon-
    /// of mediaserverbron. Eenzelfde addonnaam levert twéé aparte knoppen
    /// op zodra er zowel een rechtstreekse als een VeyraHub-versie van
    /// bestaat, apart gestyled (zie filterChip), in plaats van ze onder
    /// één knop samen te voegen — net als op tvOS.
    private var filters: [SourceFilter] {
        var result: [SourceFilter] = [.all]

        // De tvOS-filterbalk toont IPTV ook terwijl die bronnen nog laden.
        if item.type == .movie || item.type == .series {
            result.append(.iptv)
        }

        var comboSeen = Set<String>()
        var combos: [(name: String, isHub: Bool)] = []

        for resolved in viewModel.sources {
            guard resolved.source.kind != .iptvVOD else { continue }

            let name = resolved.originName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }

            let key = "\(name.lowercased())|\(resolved.isFromHub)"
            guard !comboSeen.contains(key) else { continue }
            comboSeen.insert(key)

            combos.append((name: name, isHub: resolved.isFromHub))
        }

        combos.sort {
            let nameOrder = $0.name.localizedStandardCompare($1.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            // Bij gelijke naam komt de gewone addon-knop eerst, de
            // VeyraHub-variant erna.
            return !$0.isHub && $1.isHub
        }

        result.append(contentsOf: combos.map { .origin(name: $0.name, isHub: $0.isHub) })

        return result
    }

    private var filteredSources: [ResolvedSource] {
        switch selectedFilter {
        case .all:
            return viewModel.sources

        case .iptv:
            return viewModel.sources.filter { $0.source.kind == .iptvVOD }

        case .origin(let selectedName, let selectedIsHub):
            return viewModel.sources.filter {
                $0.source.kind != .iptvVOD
                    && $0.isFromHub == selectedIsHub
                    && $0.originName.caseInsensitiveCompare(selectedName) == .orderedSame
            }
        }
    }

    private var emptyMessage: String {
        switch selectedFilter {
        case .all: return "Geen afspeelbronnen gevonden"
        case .iptv: return "Geen IPTV-bronnen gevonden"
        case .origin(let name, let isHub):
            return isHub
                ? "Geen bronnen via VeyraHub gevonden voor \(name)"
                : "Geen bronnen gevonden via \(name)"
        }
    }

    private func filterBar(isWide: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: isWide ? 12 : 8) {
                ForEach(filters, id: \.id) { filter in
                    filterChip(filter, isWide: isWide)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 6)
        }
        .scrollClipDisabled()
    }

    /// Paars/indigo tint voor filterknoppen van bronnen die via VeyraHub
    /// binnenkomen — duidelijk anders dan het gewone cyaan, zodat zo'n knop
    /// meteen herkenbaar is als "komt van de mediaserver", ook naast een
    /// gelijknamige, rechtstreekse addon-knop.
    private static let hubFrameResting = LinearGradient(
        colors: [Color(red: 0.62, green: 0.42, blue: 1).opacity(0.55),
                 .white.opacity(0.10), Color(red: 0.38, green: 0.2, blue: 0.85).opacity(0.4)],
        startPoint: .leading, endPoint: .trailing
    )
    private static let hubFrameFill = LinearGradient(
        colors: [Color(red: 0.62, green: 0.42, blue: 1).opacity(0.30),
                 Color(red: 0.62, green: 0.42, blue: 1).opacity(0.08),
                 Color(red: 0.38, green: 0.2, blue: 0.85).opacity(0.22)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    private static let hubFrameActive = LinearGradient(
        colors: [.white, Color(red: 0.72, green: 0.55, blue: 1),
                 Color(red: 0.46, green: 0.26, blue: 0.95).opacity(0.85)],
        startPoint: .leading, endPoint: .trailing
    )

    private func filterChip(_ filter: SourceFilter, isWide: Bool) -> some View {
        let isSelected = selectedFilter == filter
        let isHighlighted = isSelected || hoveredFilterID == filter.id

        let isHubFilter: Bool = {
            if case .origin(_, let isHub) = filter { return isHub }
            return false
        }()

        return Button {
            selectedFilter = filter
        } label: {
            HStack(spacing: 8) {
                if isHubFilter {
                    Image(systemName: "server.rack")
                        .font(.system(size: isWide ? 15 : 13, weight: .semibold))
                }

                VStack(spacing: 2) {
                    Text(filterTitle(filter))
                        .font(.system(size: isWide ? 18 : 15,
                                      weight: isSelected ? .bold : .semibold))

                    if isHubFilter {
                        Text("VEYRAHUB")
                            .font(.system(size: isWide ? 10 : 9, weight: .bold))
                            .tracking(1.3)
                            .opacity(0.8)
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, isWide ? 22 : 15)
            .padding(.vertical, isHubFilter ? (isWide ? 9 : 7) : (isWide ? 12 : 10))
            .background(
                isHighlighted
                    ? (isHubFilter ? AnyShapeStyle(Self.hubFrameFill) : AnyShapeStyle(VeyraFrame.fill))
                    : AnyShapeStyle(Color.clear),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    isHubFilter
                        ? AnyShapeStyle(isHighlighted ? Self.hubFrameActive : Self.hubFrameResting)
                        : AnyShapeStyle(isHighlighted ? VeyraFrame.active : VeyraFrame.resting),
                    lineWidth: isHighlighted ? 2 : 1.5
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { hoveredFilterID = filter.id }
            else if hoveredFilterID == filter.id { hoveredFilterID = nil }
        }
    }

    private func filterTitle(_ filter: SourceFilter) -> String {
        switch filter {
        case .all: return "Alle"
        case .iptv: return "IPTV"
        case .origin(let name, _): return name
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func sourceContent(isWide: Bool) -> some View {
        if viewModel.sources.isEmpty && (viewModel.isLoadingAddons || viewModel.isLoadingIPTV) {
            HStack(spacing: 12) {
                ProgressView()
                Text(viewModel.isLoadingAddons ? "Beschikbare bronnen zoeken…" : "IPTV-bronnen zoeken…")
                    .foregroundStyle(.white.opacity(0.72))
            }
            .font(.system(size: isWide ? 18 : 15))
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if filteredSources.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                if selectedFilter == .iptv && viewModel.isLoadingIPTV {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("IPTV-bronnen worden gezocht…")
                    }
                } else {
                    Text(emptyMessage)
                }

                if viewModel.hasLoaded {
                    Button("Opnieuw zoeken", systemImage: "arrow.clockwise") {
                        Task { await viewModel.loadSources() }
                    }
                    .buttonStyle(.bordered)
                    .tint(VeyraColors.cyan)
                }
            }
            .font(.system(size: isWide ? 19 : 16, weight: .medium))
            .foregroundStyle(.white.opacity(0.78))
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: isWide ? 16 : 12) {
                    ForEach(filteredSources) { resolved in
                        sourceRow(resolved, isWide: isWide)
                    }

                    if selectedFilter == .all && viewModel.isLoadingIPTV {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("IPTV-bronnen worden nog toegevoegd…")
                                .font(.system(size: isWide ? 15 : 13))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .padding(.vertical, 10)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 3)
            }
        }
    }

    // MARK: - Row

    private func sourceRow(_ resolved: ResolvedSource, isWide: Bool) -> some View {
        let isHovered = hoveredSourceID == resolved.source.id
        let badges = sourceBadges(for: resolved)

        return Button {
            selectedSource = resolved.source
        } label: {
            HStack(alignment: .top, spacing: isWide ? 20 : 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(VeyraColors.cyan.opacity(0.08))
                    Image(systemName: sourceIconName(resolved.source))
                        .font(.system(size: isWide ? 28 : 21, weight: .medium))
                        .foregroundStyle(.cyan)
                }
                .frame(width: isWide ? 64 : 46, height: isWide ? 64 : 46)

                VStack(alignment: .leading, spacing: isWide ? 9 : 7) {
                    Text(resolved.source.name)
                        .font(.system(size: isWide ? 22 : 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    if let description = resolved.source.description?
                        .trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
                        Text(description)
                            .font(.system(size: isWide ? 16 : 13))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineSpacing(isWide ? 4 : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(sourceFooter(resolved))
                        .font(.system(size: isWide ? 13 : 11, weight: .semibold))
                        .foregroundStyle(.cyan.opacity(0.85))

                    if !badges.isEmpty {
                        SourceBadgeFlowLayout(spacing: isWide ? 9 : 6) {
                            ForEach(badges) { badge in
                                sourceBadgeChip(badge, isWide: isWide)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 3)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "play.fill")
                    .font(.system(size: isWide ? 21 : 16, weight: .semibold))
                    .foregroundStyle(isHovered ? .white : .cyan)
                    .padding(.top, 9)
            }
            .padding(.horizontal, isWide ? 22 : 13)
            .padding(.vertical, isWide ? 21 : 14)
            .frame(maxWidth: .infinity, minHeight: isWide ? 110 : 94, alignment: .leading)
            .background(
                VeyraRadius.posterShape
                    .fill(isHovered ? Color.cyan.opacity(0.14) : Color.white.opacity(0.035))
            )
            .overlay(
                VeyraRadius.posterShape
                    .strokeBorder(isHovered ? Color.cyan : Color.cyan.opacity(0.10),
                                  lineWidth: isHovered ? 2 : 1)
            )
            .contentShape(VeyraRadius.posterShape)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { hoveredSourceID = resolved.source.id }
            else if hoveredSourceID == resolved.source.id { hoveredSourceID = nil }
        }
    }

    private func sourceBadges(for resolved: ResolvedSource) -> [SourceBadge] {
        badgeStore.badges(matching: [
            resolved.originName,
            resolved.source.providerName ?? "",
            resolved.source.name,
            resolved.source.description ?? ""
        ])
    }

    /// De pil-achtergrond/rand (`tagColor`/`borderColor`) hoort bij de badge
    /// zelf, niet alleen bij de tekst-terugval — een geladen afbeelding komt
    /// dus ook binnenin dezelfde pil te zitten, net als in het bronpakket
    /// bedoeld is (`tagStyle`: "filled and bordered" / "bordered").
    private func sourceBadgeChip(_ badge: SourceBadge, isWide: Bool) -> some View {
        sourceBadgeChipContent(badge, isWide: isWide)
            .padding(.horizontal, isWide ? 11 : 8)
            .padding(.vertical, isWide ? 5 : 4)
            .background(
                Capsule().fill(Color(sourceBadgeHex: badge.tagColor) ?? VeyraColors.cyan.opacity(0.6))
            )
            .overlay(
                Capsule().strokeBorder(Color(sourceBadgeHex: badge.borderColor) ?? .clear, lineWidth: 1.3)
            )
            .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func sourceBadgeChipContent(_ badge: SourceBadge, isWide: Bool) -> some View {
        if let imageURL = badge.imageURL {
            VeyraAsyncImage(url: imageURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    sourceBadgeFallback(badge, isWide: isWide)
                }
            }
            .frame(height: isWide ? 22 : 17)
        } else {
            sourceBadgeFallback(badge, isWide: isWide)
        }
    }

    private func sourceBadgeFallback(_ badge: SourceBadge, isWide: Bool) -> some View {
        Text(badge.name)
            .font(.system(size: isWide ? 17 : 12, weight: .bold))
            .foregroundStyle(Color(sourceBadgeHex: badge.textColor) ?? .white)
    }

    private var mediaDescription: String {
        switch item.type {
        case .movie:
            return "Beschikbare filmbronnen"
        case .series:
            if let season = item.seasonNumber, let episode = item.episodeNumber {
                return "Seizoen \(season) · Aflevering \(episode)"
            }
            return "Beschikbare seriebronnen"
        case .liveTV, .iptvSeries:
            return "Beschikbare livebron"
        }
    }

    private func sourceFooter(_ resolved: ResolvedSource) -> String {
        if resolved.source.kind == .iptvVOD {
            if let providerName = resolved.source.providerName,
               !providerName.isEmpty {
                return "IPTV VOD · \(providerName)"
            }
            return "IPTV VOD"
        }
        if resolved.isFromHub { return "\(resolved.originName) · via VeyraHub" }
        return resolved.originName
    }

    private func sourceIconName(_ source: PlayableSource) -> String {
        switch source.kind {
        case .iptvVOD: return "tv.and.hifispeaker.fill"
        case .usenet: return "externaldrive.fill"
        case .debrid: return "cloud.fill"
        case .liveTV: return "antenna.radiowaves.left.and.right"
        case .direct: return "play.rectangle.fill"
        }
    }
}

/// De tvOS-badges staan op een eigen regel; op smalle schermen lopen ze door
/// naar een volgende regel zodat alle passende badges zichtbaar blijven.
private struct SourceBadgeFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let proposedWidth = proposal.width ?? .greatestFiniteMagnitude
        let availableWidth = proposedWidth.isFinite ? max(0, proposedWidth) : .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > availableWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }

        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > bounds.width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                          proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private extension View {
    @ViewBuilder
    func sourceSelectionInlineTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
