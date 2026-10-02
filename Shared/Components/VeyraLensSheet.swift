// VeyraLensSheet.swift — iOS (tvOS heeft dit al als "Info"-tab, zie
// `PlayerSubtitleControls.metadataTabContent`)
// "Veyra Lens": dezelfde contextknop in de speler ongeacht wat er speelt --
// film -> cast + overzicht, serie -> aflevering-info + cast, Live TV ->
// huidig/volgend programma, sport -> wedstrijdinformatie. Bewust geen eigen
// databron: hergebruikt `LivePlayerEPGTimeline` (Live TV) en
// `VeyraMatchCenterOverlay` (sport) die al elders in de speler/Home
// gebruikt worden, en haalt zelf enkel titel/overzicht/cast van TMDB op
// voor films en series (zie ook de tvOS Info-tab, zelfde aanpak).

import SwiftUI

struct VeyraLensSheet: View {
    let item: MediaItem?
    let source: PlayableSource
    var sportEvent: SportEvent? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var posterURL: URL?
    @State private var infoLine: String?
    @State private var cast: [TMDBCastMember] = []
    @State private var loaded = false

    private var episodeLabel: String? {
        guard item?.type == .series, let season = item?.seasonNumber, let episode = item?.episodeNumber else { return nil }
        return "S\(season)E\(episode)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let sportEvent {
                        VeyraMatchCenterOverlay(event: sportEvent, now: .now)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if source.kind == .liveTV {
                        LivePlayerEPGTimeline(source: source)
                            .padding(16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        titleContent
                    }
                }
                .padding(20)
            }
            .background(VeyraColors.background.ignoresSafeArea())
            .navigationTitle("Info")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sluit") { dismiss() }
                }
            }
            #endif
        }
        .preferredColorScheme(.dark)
        .task {
            guard !loaded, sportEvent == nil, source.kind != .liveTV else { return }
            loaded = true
            await load()
        }
    }

    private var titleContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                AsyncImage(url: posterURL ?? item?.posterURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        ZStack { VeyraColors.surface; Image(systemName: "photo").foregroundStyle(.secondary) }
                    }
                }
                .frame(width: 110, height: 165)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    if let title = item?.title, !title.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(title).font(.system(size: 19, weight: .bold))
                            if let episodeLabel {
                                Text(episodeLabel).font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(VeyraColors.cyan)
                            }
                        }
                    }
                    if let infoLine {
                        Text(infoLine).font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                Spacer(minLength: 0)
            }

            if let overview = item?.overview, !overview.isEmpty {
                Text(overview).font(.system(size: 15)).foregroundStyle(.white.opacity(0.8)).lineSpacing(2)
            }

            if !cast.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CAST").font(.system(size: 12, weight: .semibold)).tracking(1.5)
                        .foregroundStyle(.secondary)
                    VeyraLensCastRow(cast: cast)
                }
            }
        }
    }

    @MainActor
    private func load() async {
        if let item, let credits = await CreditsService.credits(for: item) {
            cast = credits.cast
        }

        guard let base = item, base.tmdbID != nil else { return }

        // Fase 1 (metadata-policy-spec §14/§18/§19): poster via de centrale
        // `MetadataRepository` i.p.v. hier een eigen, ongecachete TMDB-detail-
        // aanroep -- respecteert zo ook een gekozen AIOMetadata-addon, met
        // dezelfde TMDB-terugval.
        let kind: ShelfMediaKind = base.type == .series ? .series : .movie
        let enriched = await MetadataRepository.shared.enrichedArtwork(for: base, kind: kind)
        posterURL = enriched.posterURL
        if base.type != .series {
            infoLine = tmdbYear(enriched.releaseDate)
        }
    }

    private func tmdbYear(_ dateString: String?) -> String? {
        guard let dateString, dateString.count >= 4 else { return nil }
        return String(dateString.prefix(4))
    }
}
