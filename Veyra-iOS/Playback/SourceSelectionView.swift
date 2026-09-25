import SwiftUI

struct SourceSelectionView: View {
    let item: MediaItem

    @StateObject private var viewModel: SourceSelectionViewModel
    @ObservedObject private var traktStore = TraktStore.shared
    @State private var selectedSource: PlayableSource?
    @State private var selectedFilter: SourceFilter = .all

    // "Eerste bron automatisch selecteren" (Afspelen-instellingen).
    @AppStorage(PlaybackSettingsDefaults.autoSelectFirstSourceKey)
    private var autoSelectFirstSource = false

    init(item: MediaItem) {
        self.item = item
        _viewModel = StateObject(wrappedValue: SourceSelectionViewModel(item: item))
    }

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if !viewModel.sources.isEmpty {
                    filterBar
                }

                List {
                    if viewModel.isLoadingAddons && viewModel.sources.isEmpty {
                        HStack {
                            ProgressView()
                            Text("Bronnen zoeken…")
                        }
                    } else if filteredSources.isEmpty && viewModel.hasLoaded {
                        ContentUnavailableView(
                            emptyMessage,
                            systemImage: "play.slash"
                        )
                    } else {
                        ForEach(filteredSources) { resolved in
                            Button {
                                selectedSource = resolved.source
                            } label: {
                                sourceRow(resolved)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }

                        if viewModel.isLoadingIPTV {
                            HStack {
                                ProgressView()
                                Text("IPTV-bronnen worden toegevoegd…")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadSources() }
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
        }
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

        // IPTV VOD beschikbaar bij films én series/afleveringen.
        if item.type == .movie || item.type == .series {
            let hasIPTV = viewModel.sources.contains { $0.source.kind == .iptvVOD }
            if hasIPTV || viewModel.isLoadingIPTV {
                result.append(.iptv)
            }
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

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filters, id: \.id) { filter in
                    filterChip(filter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(VeyraColors.background)
    }

    /// Paars/indigo tint voor filterknoppen van bronnen die via VeyraHub
    /// binnenkomen — duidelijk anders dan het gewone cyaan, zodat zo'n knop
    /// meteen herkenbaar is als "komt van de mediaserver", ook naast een
    /// gelijknamige, rechtstreekse addon-knop.
    private static let hubTint = Color(red: 0.62, green: 0.42, blue: 1.0)

    private func filterChip(_ filter: SourceFilter) -> some View {
        let isSelected = selectedFilter == filter

        let isHubFilter: Bool = {
            if case .origin(_, let isHub) = filter { return isHub }
            return false
        }()

        let tint = isHubFilter ? Self.hubTint : VeyraColors.cyan

        return Button {
            selectedFilter = filter
        } label: {
            HStack(spacing: 6) {
                if isHubFilter {
                    Image(systemName: "server.rack")
                        .font(.caption.weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(filterTitle(filter))
                        .font(.subheadline.weight(isSelected ? .semibold : .medium))

                    if isHubFilter {
                        Text("VEYRAHUB")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .opacity(0.75)
                    }
                }
            }
            .foregroundStyle(isSelected ? Color.black : tint)
            .padding(.horizontal, 16)
            .padding(.vertical, isHubFilter ? 6 : 8)
            .background(
                Capsule()
                    .fill(isSelected ? tint : tint.opacity(0.12))
            )
            .overlay {
                if isHubFilter {
                    Capsule().strokeBorder(tint.opacity(isSelected ? 0 : 0.5), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func filterTitle(_ filter: SourceFilter) -> String {
        switch filter {
        case .all: return "Alle"
        case .iptv: return "IPTV"
        case .origin(let name, _): return name
        }
    }

    // MARK: - Row

    private func sourceRow(_ resolved: ResolvedSource) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(VeyraColors.cyan.opacity(0.08))
                Image(systemName: sourceIconName(resolved.source))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(VeyraColors.cyan)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(resolved.source.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(sourceBadges(for: resolved)) { badge in
                        sourceBadgeChip(badge)
                    }
                }

                // Geen regelbeperking — anders knipt SwiftUI een tweede/derde
                // regel (kwaliteit, codec, HDR, grootte…) halverwege af met
                // een "…", wat er rommelig uitziet. tvOS toont deze tekst ook
                // altijd volledig.
                if let description = resolved.source.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(resolved.source.kind == .iptvVOD ? "IPTV VOD" : resolved.originName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VeyraColors.cyan)
            }

            Spacer(minLength: 12)

            Image(systemName: "play.fill")
                .font(.subheadline)
                .foregroundStyle(VeyraColors.cyan)
                .padding(.top, 10)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(VeyraColors.cyan.opacity(0.10), lineWidth: 1)
        )
    }

    private func sourceBadges(for resolved: ResolvedSource) -> [SourceBadge] {
        SourceBadgeStore.shared.badges(matching: [
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
    private func sourceBadgeChip(_ badge: SourceBadge) -> some View {
        sourceBadgeChipContent(badge)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Color(sourceBadgeHex: badge.tagColor) ?? VeyraColors.cyan.opacity(0.6))
            )
            .overlay(
                Capsule().strokeBorder(Color(sourceBadgeHex: badge.borderColor) ?? .clear, lineWidth: 1)
            )
    }

    @ViewBuilder
    private func sourceBadgeChipContent(_ badge: SourceBadge) -> some View {
        if let imageURL = badge.imageURL {
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    sourceBadgeFallback(badge)
                }
            }
            .frame(height: 10)
        } else {
            sourceBadgeFallback(badge)
        }
    }

    private func sourceBadgeFallback(_ badge: SourceBadge) -> some View {
        Text(badge.name)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color(sourceBadgeHex: badge.textColor) ?? .white)
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
