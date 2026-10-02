import SwiftUI

/// "Artwork aanpassen" (artwork-engine-spec §56/§57/§68/§69): per-titel handmatige keuze uit de
/// echte TMDB-candidates voor ClearLogo/Poster/Achtergrond. Candidates worden pas geladen
/// wanneer dit scherm opent (§68), nooit standaard vooraf. Simpeler dan het Collections-
/// equivalent (`VeyraCollectionClearLogoPickerView`): tikken past meteen toe, geen apart
/// "Toepassen" nodig — net als het mockup in §57 ("GEBRUIK AUTOMATISCH" als losse knop per
/// sectie, candidates ernaast).
struct VeyraArtworkPickerView: View {
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss

    @State private var candidates: [ArtworkCandidate] = []
    @State private var loading = true
    @State private var currentOverrides: [VeyraArtworkType: VeyraArtworkOverride] = [:]
    // §66: als de override voor deze titel elders wijzigt (ander scherm, of een VeyraHub-sync
    // vanaf een ander apparaat, §64) terwijl deze picker al open staat, moet de selectiering
    // meeveranderen -- zonder de candidates (duur, TMDB-netwerk) opnieuw op te halen.
    @ObservedObject private var artworkRefresh = ArtworkRefreshSignal.shared

    private let store = VeyraArtworkOverrideStore()

    private var mediaKind: ShelfMediaKind { item.type == .series ? .series : .movie }

    private var canonicalKey: String? {
        guard let tmdbID = item.tmdbID else { return nil }
        return VeyraArtworkOverrideStore.canonicalKey(tmdbID: tmdbID, kind: mediaKind)
    }

    var body: some View {
        content
            .navigationTitle("Artwork aanpassen")
            .task { await load() }
            .onChange(of: artworkRefresh.generation) { _, _ in refreshOverrides() }
    }

    @ViewBuilder
    private var content: some View {
        #if os(tvOS)
        ZStack {
            VeyraBackground().ignoresSafeArea()
            form
        }
        #else
        form
        #endif
    }

    private var form: some View {
        Form {
            if item.tmdbID == nil {
                Section {
                    Text("Geen TMDB-ID bekend voor deze titel — artwork aanpassen is hier niet mogelijk.")
                        .foregroundStyle(.secondary)
                }
            } else if loading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else {
                ForEach(VeyraArtworkType.allCases) { type in
                    section(for: type)
                }
            }
        }
        .frame(maxWidth: 1000)
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Sluiten") { dismiss() } }
        }
        #endif
    }

    @ViewBuilder
    private func section(for type: VeyraArtworkType) -> some View {
        let items = candidates.filter { $0.type == type }

        Section {
            Button("Gebruik automatisch") { clear(type) }
                .disabled(currentOverrides[type] == nil)

            if items.isEmpty {
                Text("Geen alternatieven gevonden.").foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items) { candidate in
                            thumbnail(candidate)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text(type.title)
        }
    }

    @ViewBuilder
    private func thumbnail(_ candidate: ArtworkCandidate) -> some View {
        let isSelected = currentOverrides[candidate.type]?.providerPath == candidate.providerPath

        Button {
            select(candidate)
        } label: {
            ZStack {
                Color.white.opacity(0.08)
                AsyncImage(url: candidate.url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: candidate.type == .clearLogo ? .fit : .fill)
                            .padding(candidate.type == .clearLogo ? 8 : 0)
                    } else {
                        Color.clear
                    }
                }
            }
            .frame(width: candidate.type == .backdrop ? 220 : 110, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? VeyraColors.cyan : .clear, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }

    private func select(_ candidate: ArtworkCandidate) {
        guard let canonicalKey else { return }
        store.setOverride(candidate.override, canonicalKey: canonicalKey)
        currentOverrides[candidate.type] = candidate.override
    }

    private func clear(_ type: VeyraArtworkType) {
        guard let canonicalKey else { return }
        store.clearOverride(canonicalKey: canonicalKey, type: type)
        currentOverrides[type] = nil
    }

    // Enkel aangeroepen bij het openen van dit scherm, niet vooraf (§68).
    private func load() async {
        defer { loading = false }
        refreshOverrides()
        candidates = await ArtworkCandidateService.candidates(for: item)
    }

    private func refreshOverrides() {
        guard let canonicalKey else { return }
        for type in VeyraArtworkType.allCases {
            currentOverrides[type] = store.override(canonicalKey: canonicalKey, type: type)
        }
    }
}
