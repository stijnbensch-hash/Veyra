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
        case origin(String)

        var id: String {
            switch self {
            case .all: return "all"
            case .iptv: return "iptv"
            case .origin(let name): return "origin:\(name)"
            }
        }
    }

    /// IPTV en "Alle" staan altijd vooraan; daarna een knop per addon-
    /// of mediaserverbron (bv. "AIOStreams", "VeyraHub") — automatisch
    /// afgeleid uit wat er daadwerkelijk geladen is, net als op tvOS.
    private var filters: [SourceFilter] {
        var result: [SourceFilter] = [.all]

        // IPTV VOD beschikbaar bij films én series/afleveringen.
        if item.type == .movie || item.type == .series {
            let hasIPTV = viewModel.sources.contains { $0.source.kind == .iptvVOD }
            if hasIPTV || viewModel.isLoadingIPTV {
                result.append(.iptv)
            }
        }

        var names: [String] = []
        for resolved in viewModel.sources {
            guard resolved.source.kind != .iptvVOD else { continue }

            let name = resolved.originName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }

            let alreadyExists = names.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
            if !alreadyExists {
                names.append(name)
            }
        }

        names.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        result.append(contentsOf: names.map { .origin($0) })

        return result
    }

    private var filteredSources: [ResolvedSource] {
        switch selectedFilter {
        case .all:
            return viewModel.sources

        case .iptv:
            return viewModel.sources.filter { $0.source.kind == .iptvVOD }

        case .origin(let selectedName):
            return viewModel.sources.filter {
                $0.source.kind != .iptvVOD
                    && $0.originName.caseInsensitiveCompare(selectedName) == .orderedSame
            }
        }
    }

    private var emptyMessage: String {
        switch selectedFilter {
        case .all: return "Geen afspeelbronnen gevonden"
        case .iptv: return "Geen IPTV-bronnen gevonden"
        case .origin(let name): return "Geen bronnen gevonden via \(name)"
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

    private func filterChip(_ filter: SourceFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            selectedFilter = filter
        } label: {
            Text(filterTitle(filter))
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.black : VeyraColors.cyan)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? VeyraColors.cyan : VeyraColors.cyan.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    private func filterTitle(_ filter: SourceFilter) -> String {
        switch filter {
        case .all: return "Alle"
        case .iptv: return "IPTV"
        case .origin(let name): return name
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
                Text(resolved.source.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

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
