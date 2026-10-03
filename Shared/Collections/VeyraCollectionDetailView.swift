// VeyraCollectionDetailView.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Collection Detail (Fase 5, spec §24): Collection Stage (§8) bovenaan + Collection Journey
// (§25/§26) eronder. Progress/volgende-film (§27/§28), "Ga verder" gebruikt de bestaande
// `SourceSelectionView`/playback-flow en kiest zelf GEEN bron (spec §29). Volledig bekeken toont
// "COLLECTIE VOLTOOID" + optioneel "OPNIEUW BEKIJKEN", zonder watch history te resetten (spec §30).
// Leest de collectie live via `VeyraCollectionStore` (op id, niet een kopie) zodat wijzigingen
// (film toegevoegd/verwijderd elders) meteen zichtbaar blijven (spec §57).
//
// Fase 7 (spec §34): officiële TMDB-collecties gebruiken DEZELFDE Stage/Journey-componenten als
// eigen collecties -- vandaar `VeyraCollectionDetailSource` i.p.v. enkel een `VeyraCollection.ID`.
// Een officiële collectie is niet-persistent (komt rechtstreeks van TMDB); enkel "Bewaar als eigen
// collectie" (spec §35/§36) schrijft 'm naar `VeyraCollectionStore`, de rest van het beheermenu
// (hernoemen/films beheren/verwijderen) is dan ook enkel zichtbaar voor eigen collecties.

import SwiftUI

/// Welke collectie `VeyraCollectionDetailView` toont: een eigen (opgeslagen) collectie, of een
/// officiële TMDB-collectie die rechtstreeks opgehaald wordt (nooit een hardcoded lijst, spec §33).
enum VeyraCollectionDetailSource: Hashable {
    case own(VeyraCollection.ID)
    case official(tmdbCollectionID: Int, name: String)
}

struct VeyraCollectionDetailView: View {
    let source: VeyraCollectionDetailSource

    @ObservedObject private var store = VeyraCollectionStore.shared
    @ObservedObject private var traktStore = TraktStore.shared
    @State private var resolvedItems: [VeyraResolvedCollectionItem] = []
    @State private var officialDescription: String?
    @State private var isLoading = true
    @State private var playItem: MediaItem?
    @State private var detailItem: MediaItem?
    @State private var showEdit = false
    @State private var showManageItems = false
    @State private var showDeleteConfirm = false
    @State private var showChronologyEditor = false
    @State private var savedOwnCollection: VeyraCollection?
    @Environment(\.dismiss) private var dismiss

    private var ownCollectionID: VeyraCollection.ID? {
        if case .own(let id) = source { return id }
        return nil
    }
    private var collection: VeyraCollection? { ownCollectionID.flatMap { store.collection($0) } }
    private var isOfficial: Bool { ownCollectionID == nil }

    private var displayName: String {
        if case .official(_, let name) = source { return name }
        return collection?.name ?? ""
    }
    private var displayDescription: String? {
        isOfficial ? officialDescription : collection?.collectionDescription
    }
    /// Officiële collecties hebben geen eigen `sortMode` -- releasedatum is de natuurlijke
    /// volgorde voor een filmreeks (spec §34), vandaar ook de tijdlijn in plaats van een lijst.
    private var sortMode: VeyraCollectionSortMode { collection?.sortMode ?? .releaseDate }

    private var orderedResolved: [VeyraResolvedCollectionItem] {
        switch sortMode {
        case .manual:
            return resolvedItems.sorted { $0.manualSortIndex < $1.manualSortIndex }
        case .dateAdded:
            return resolvedItems.sorted { $0.addedAt < $1.addedAt }
        case .title:
            return resolvedItems.sorted {
                $0.media.title.localizedCaseInsensitiveCompare($1.media.title) == .orderedAscending
            }
        case .releaseDate:
            return resolvedItems.sorted {
                (releaseDateValue($0.media.releaseDate) ?? .distantFuture) < (releaseDateValue($1.media.releaseDate) ?? .distantFuture)
            }
        case .chronological:
            // Spec §36: nooit gegokt -- zolang niet elk item een `chronologyIndex` heeft, valt dit
            // terug op de handmatige volgorde (de "Chronologie instellen"-prompt in `journey()`
            // maakt dat voor de gebruiker duidelijk i.p.v. stilzwijgend iets te verzinnen).
            return resolvedItems.sorted {
                ($0.chronologyIndex ?? $0.manualSortIndex) < ($1.chronologyIndex ?? $1.manualSortIndex)
            }
        }
    }

    private var watchedCount: Int { orderedResolved.filter { traktStore.isWatched($0.media) }.count }
    private var isFullyWatched: Bool { !orderedResolved.isEmpty && watchedCount == orderedResolved.count }
    private var nextItem: VeyraResolvedCollectionItem? { orderedResolved.first { !traktStore.isWatched($0.media) } }

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    stage()
                    if isLoading {
                        ProgressView()
                    } else if orderedResolved.isEmpty {
                        emptyState
                    } else {
                        journey()
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, verticalPaddingTop)
                .padding(.bottom, verticalPadding)
            }
        }
        .task(id: source) { await load() }
        .navigationDestination(item: $playItem) { item in
            SourceSelectionView(item: item)
        }
        .navigationDestination(item: $detailItem) { item in
            MovieDetailView(movie: item)
        }
        .navigationDestination(item: $savedOwnCollection) { saved in
            VeyraCollectionDetailView(source: .own(saved.id))
        }
        .toolbar {
            if isOfficial {
                // Spec §35/§36: officiële collectie -> persoonlijke kopie, origineel blijft onaangetast.
                ToolbarItem {
                    Button {
                        saveAsOwnCollection()
                    } label: {
                        Label("Bewaar als eigen collectie", systemImage: "square.and.arrow.down")
                    }
                }
            } else {
                ToolbarItem {
                    Menu {
                        Button {
                            showEdit = true
                        } label: {
                            Label("Bewerk collectie", systemImage: "pencil")
                        }
                        Button {
                            showManageItems = true
                        } label: {
                            Label("Beheer films", systemImage: "list.bullet")
                        }
                        if sortMode == .chronological, let ownCollectionID {
                            Button {
                                store.seedChronologyIfNeeded(ownCollectionID)
                                showChronologyEditor = true
                            } label: {
                                Label("Chronologie instellen", systemImage: "list.number")
                            }
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Verwijder collectie", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            if let collection {
                NavigationStack { VeyraCreateCollectionSheet(editing: collection) }
            }
        }
        #if os(tvOS)
        .navigationDestination(isPresented: $showManageItems) {
            if let ownCollectionID { VeyraCollectionManageItemsView(collectionID: ownCollectionID) }
        }
        .navigationDestination(isPresented: $showChronologyEditor) {
            if let ownCollectionID { VeyraChronologyEditorView(collectionID: ownCollectionID) }
        }
        #else
        .sheet(isPresented: $showManageItems) {
            if let ownCollectionID {
                NavigationStack { VeyraCollectionManageItemsView(collectionID: ownCollectionID) }
            }
        }
        .sheet(isPresented: $showChronologyEditor) {
            if let ownCollectionID {
                NavigationStack { VeyraChronologyEditorView(collectionID: ownCollectionID) }
            }
        }
        #endif
        // Spec §23: verwijderen van een eigen collectie vraagt altijd bevestiging; de films
        // zelf blijven gewoon beschikbaar in Veyra (enkel de collectie-membership verdwijnt).
        .confirmationDialog(
            "Collectie verwijderen?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Verwijderen", role: .destructive) {
                if let ownCollectionID { store.delete(ownCollectionID) }
                dismiss()
            }
            Button("Annuleren", role: .cancel) {}
        } message: {
            Text("\"\(displayName)\" wordt verwijderd. De films zelf blijven beschikbaar in Veyra.")
        }
    }

    private func load() async {
        isLoading = true
        switch source {
        case .own(let id):
            guard let collection = store.collection(id) else { isLoading = false; return }
            resolvedItems = await VeyraCollectionMetadataResolver.resolve(collection.items)
        case .official(let tmdbID, _):
            let result = await VeyraOfficialCollectionResolver.resolve(tmdbCollectionID: tmdbID)
            officialDescription = result.description
            resolvedItems = result.items
        }
        isLoading = false
    }

    // Spec §35/§36: maakt een persoonlijke kopie van de officiële collectie; verwijzing naar
    // `tmdbCollectionID` blijft bewaard (`VeyraCollectionStore.saveAsOwnCollection`), zodat de
    // link met de officiële collectie herkenbaar blijft, maar het origineel zelf wijzigt nooit.
    private func saveAsOwnCollection() {
        guard case .official(let tmdbID, let name) = source else { return }
        let items = orderedResolved.map { VeyraCollectionItem(item: $0.media, manualSortIndex: $0.manualSortIndex) }
        savedOwnCollection = store.saveAsOwnCollection(name: "\(name) — Mijn collectie", tmdbCollectionID: tmdbID, items: items)
    }

    private func releaseDateValue(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    private func year(_ raw: String?) -> String? {
        guard let raw, raw.count >= 4 else { return nil }
        return String(raw.prefix(4))
    }

    // MARK: - Collection Stage (spec §8)

    // Tekst/voortgang/actie staan ONDER de afbeelding i.p.v. als overlay erop, zodat de fanart
    // volledig zichtbaar blijft en de tekst nooit over het beeld heen leest.
    @ViewBuilder
    private func stage() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            stageTitleView
                .frame(maxWidth: .infinity, alignment: .center)

            ZStack(alignment: .topTrailing) {
                stageBackground
                // Klein rood Veyra-accentje (spec §52), puur decoratief.
                Circle().fill(VeyraColors.red.opacity(0.5)).frame(width: 10, height: 10).padding(16)
            }
            .frame(height: stageHeight)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(VeyraFrame.resting, lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 10) {
                if let description = displayDescription, !description.isEmpty {
                    Text(description)
                        .font(.system(size: stageSubtitleSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if !orderedResolved.isEmpty {
                    Text(isFullyWatched
                         ? "COLLECTIE VOLTOOID · \(watchedCount)/\(orderedResolved.count) bekeken"
                         : "\(orderedResolved.count) films · \(watchedCount) bekeken")
                        .font(.system(size: stageMetaSize, weight: .semibold))
                        .foregroundStyle(VeyraColors.cyan)
                    progressBar
                }
                nextOrReplayAction
            }
            .padding(.horizontal, stagePadding)
        }
    }

    // Collecties hebben zelf geen TMDB-clearlogo -- hergebruikt daarom het clearlogo van het
    // meest prominente/eerste deel in de collectie (zelfde `VeyraClearLogo`/`ClearLogoService`
    // als Movie/Series Detail), met de collectienaam als tekst-fallback zolang er geen logo is.
    @ViewBuilder
    private var stageTitleView: some View {
        // Expliciet gekozen clearlogo gaat voor de automatische per-film TMDB-lookup -- zelfde
        // voorrang als een per-titel artwork-override bij Movie/Series Detail (ArtworkResolver):
        // een bewuste keuze voor DEZE collectie wint ook van de globale "Altijd tekst"-instelling.
        // "ClearLogo + tekst" liet dat tweede deel van die instelling hier tot nu toe nog niet
        // meedoen (de titel verscheen dan nooit mee onder een eigen gekozen logo) -- nu wel,
        // zelfde gedrag als `VeyraClearLogo` bij Movie/Series Detail.
        if let collection, let customLogoURL = VeyraCollectionClearLogoResolver.resolvedURL(for: collection) {
            let showTextAlongsideLogo = ArtworkSettingsStore().load().titleDisplay == .clearLogoPlusText
            VStack(spacing: 6) {
                VeyraAsyncImage(url: customLogoURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                            .frame(maxWidth: stageLogoMaxWidth, maxHeight: stageLogoMaxHeight)
                    } else {
                        Text(displayName)
                            .font(.system(size: stageTitleSize, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                }
                if showTextAlongsideLogo {
                    Text(displayName)
                        .font(.system(size: stageTitleSize, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
            }
        } else if let item = orderedResolved.first?.media {
            VeyraClearLogo(item: item, fallbackTitle: displayName, maxWidth: stageLogoMaxWidth,
                           maxHeight: stageLogoMaxHeight, font: .system(size: stageTitleSize, weight: .bold),
                           alignment: .center)
        } else {
            Text(displayName)
                .font(.system(size: stageTitleSize, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
    }

    // Spec §7: zelfde artwork-identiteit als de browser/Home-kaarten, via de centrale resolver
    // i.p.v. hier zelf opnieuw een backdrop te kiezen.
    private var stageArtworkURL: URL? {
        // Was eerder: geeft voor een nog niet-bewaarde officiële TMDB-collectie altijd `nil`
        // terug (`collection` is dan `nil`), zelfs als er wel een backdrop van het meest
        // prominente deel beschikbaar is -- die backdrop (de `fallback`) werd dus nooit gebruikt.
        guard let collection else { return orderedResolved.first?.media.backdropURL }
        return VeyraCollectionArtworkResolver.resolvedURL(for: collection, fallback: orderedResolved.first?.media.backdropURL)
    }

    @ViewBuilder
    private var stageBackground: some View {
        if let url = stageArtworkURL {
            GeometryReader { geo in
                VeyraAsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        let position = collection?.artworkPosition ?? VeyraArtworkPosition()
                        // Expliciet op `geo.size` geframed VOOR de zoom/offset (i.p.v. enkel
                        // erna, op de hele `VeyraAsyncImage`) -- zo vult de afbeelding altijd
                        // gegarandeerd het volledige kader, ook al stuurt `VeyraAsyncImage`'s
                        // eigen `ZStack`-wrapper de size-proposal niet altijd betrouwbaar door
                        // naar deze closure heen.
                        image.resizable().scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(max(position.zoom, 1))
                            .offset(x: (0.5 - position.x) * geo.size.width, y: (0.5 - position.y) * geo.size.height)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        placeholderGradient
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
        } else {
            placeholderGradient
        }
    }

    private var placeholderGradient: some View {
        LinearGradient(colors: [VeyraColors.surface, VeyraColors.background],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule().fill(VeyraColors.cyan).frame(width: geo.size.width * progressFraction)
            }
        }
        .frame(height: 6)
        .frame(maxWidth: progressBarMaxWidth)
    }

    private var progressFraction: CGFloat {
        guard !orderedResolved.isEmpty else { return 0 }
        return CGFloat(watchedCount) / CGFloat(orderedResolved.count)
    }

    @ViewBuilder
    private var nextOrReplayAction: some View {
        if isFullyWatched, let first = orderedResolved.first {
            // Spec §30: optioneel opnieuw bekijken -- reset NOOIT automatisch de watch history.
            actionButton(title: "OPNIEUW BEKIJKEN", symbol: "arrow.counterclockwise") { playItem = first.media }
                .padding(.top, 8)
        } else if let nextItem {
            VStack(alignment: .leading, spacing: 6) {
                Text("VOLGENDE")
                    .font(.system(size: stageMetaSize, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.7))
                Text(nextItem.media.title)
                    .font(.system(size: stageSubtitleSize, weight: .semibold))
                    .foregroundStyle(.white)
                actionButton(title: "GA VERDER", symbol: "play.fill") { playItem = nextItem.media }
            }
        }
    }

    @ViewBuilder
    private func actionButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        #if os(tvOS)
        Button(action: action) {
            VeyraActionLabel(title: title, symbol: symbol, compact: true)
        }
        .buttonStyle(VeyraFocusButtonStyle(primary: true))
        #else
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(VeyraColors.cyan)
        .controlSize(.small)
        #endif
    }

    // MARK: - Collection Journey (spec §25/§26)

    @ViewBuilder
    private func journey() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("VOLGORDE")
                .font(.system(size: journeyHeaderSize, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(VeyraColors.cyan.opacity(0.85))

            if sortMode == .chronological, let ownCollectionID, !store.hasChronology(ownCollectionID) {
                // Spec §38: geen gegokte volgorde tonen -- expliciet vragen om chronologie in te
                // stellen.
                chronologyMissingPrompt(ownCollectionID)
            } else if sortMode == .releaseDate || sortMode == .chronological {
                // Chronologisch gebruikt dezelfde tijdlijn-weergave als releasedatum, maar met
                // volgnummers i.p.v. jaartallen (geen gegokte/misleidende jaren, spec §40).
                timeline
            } else {
                // Handmatig/titel/toevoegvolgorde: genummerde lijst.
                numberedList
            }
        }
    }

    @ViewBuilder
    private func chronologyMissingPrompt(_ ownCollectionID: VeyraCollection.ID) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Geen chronologische volgorde beschikbaar.")
                .font(.system(size: journeyStatusSize + 2))
                .foregroundStyle(.secondary)
            actionButton(title: "CHRONOLOGIE INSTELLEN", symbol: "list.number") {
                store.seedChronologyIfNeeded(ownCollectionID)
                showChronologyEditor = true
            }
        }
    }

    private var timeline: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: journeyGap) {
                ForEach(Array(orderedResolved.enumerated()), id: \.element.id) { index, resolved in
                    journeyCard(resolved, index: index)
                }
            }
            // Zonder deze padding + `.scrollClipDisabled()` knipt de ScrollView de
            // focus-schaal/-ring van de eerste (en laatste) kaart af aan de rand --
            // zelfde terugkerend probleem als bij `VeyraArtworkPickerView`.
            .padding(.horizontal, 6)
        }
        .scrollClipDisabled()
    }

    private var numberedList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(orderedResolved.enumerated()), id: \.element.id) { index, resolved in
                numberedRow(resolved, index: index)
            }
        }
    }

    @ViewBuilder
    private func journeyCard(_ resolved: VeyraResolvedCollectionItem, index: Int) -> some View {
        let watched = traktStore.isWatched(resolved.media)
        let isNext = nextItem?.id == resolved.id
        // Chronologisch toont een volgnummer i.p.v. een (mogelijk misleidend) releasejaar.
        let label = sortMode == .chronological ? String(format: "%02d", index + 1) : (year(resolved.media.releaseDate) ?? "")
        Button {
            playItem = resolved.media
        } label: {
            VStack(spacing: 8) {
                Text(label)
                    .font(.system(size: journeyYearSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                Circle()
                    .fill(watched ? VeyraColors.cyan.opacity(0.35) : (isNext ? VeyraColors.cyan : Color.white.opacity(0.15)))
                    .frame(width: 12, height: 12)
                journeyPosterFocusRing { posterImage(resolved.media.posterURL) }
                Text(resolved.media.title)
                    .font(.system(size: journeyTitleSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(width: journeyCardWidth, alignment: .leading)
                statusLabel(watched: watched, isNext: isNext)
            }
        }
        #if os(tvOS)
        .buttonStyle(VeyraStreamingTileStyle())
        #else
        .buttonStyle(.plain)
        #endif
        .contextMenu { itemContextMenu(resolved) }
    }

    // tvOS geeft een `Button` zonder dit standaard een witte "kaart"-achtergrond bij focus --
    // `VeyraStreamingTileStyle()` schakelt die uit, dit tekent in plaats daarvan Veyra's eigen
    // cyaan focus-kader rond de poster (focus = altijd cyaan, spec §5).
    @ViewBuilder
    private func journeyPosterFocusRing<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if os(tvOS)
        VeyraJourneyPosterFocusRing { content() }
        #else
        content()
        #endif
    }

    // Spec §21: "Verwijder uit collectie" raakt ALLEEN de membership, nooit de film zelf, watch
    // history of Trakt-status.
    @ViewBuilder
    private func itemContextMenu(_ resolved: VeyraResolvedCollectionItem) -> some View {
        Button {
            detailItem = resolved.media
        } label: {
            Label("Open details", systemImage: "info.circle")
        }
        Button {
            playItem = resolved.media
        } label: {
            Label("Afspelen", systemImage: "play.fill")
        }
        if let ownCollectionID {
            Divider()
            Button(role: .destructive) {
                store.removeItem(resolved.collectionItemID, from: ownCollectionID)
                resolvedItems.removeAll { $0.collectionItemID == resolved.collectionItemID }
            } label: {
                Label("Verwijder uit collectie", systemImage: "minus.circle")
            }
        }
    }

    @ViewBuilder
    private func numberedRow(_ resolved: VeyraResolvedCollectionItem, index: Int) -> some View {
        let watched = traktStore.isWatched(resolved.media)
        let isNext = nextItem?.id == resolved.id
        Button {
            playItem = resolved.media
        } label: {
            HStack(spacing: 14) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: journeyTitleSize, weight: .bold))
                    .foregroundStyle(isNext ? VeyraColors.cyan : .secondary)
                    .frame(width: 36, alignment: .leading)
                journeyPosterFocusRing { posterImage(resolved.media.posterURL, small: true) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(resolved.media.title)
                        .font(.system(size: journeyTitleSize, weight: .semibold))
                        .foregroundStyle(.white)
                    statusLabel(watched: watched, isNext: isNext)
                }
                Spacer()
                if watched {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(VeyraColors.cyan)
                }
            }
            .padding(.vertical, 6)
        }
        #if os(tvOS)
        .buttonStyle(VeyraStreamingTileStyle())
        #else
        .buttonStyle(.plain)
        #endif
        .contextMenu { itemContextMenu(resolved) }
    }

    private func statusLabel(watched: Bool, isNext: Bool) -> some View {
        Text(watched ? "BEKEKEN" : (isNext ? "VOLGENDE" : "ONBEKEKEN"))
            .font(.system(size: journeyStatusSize, weight: .bold))
            .tracking(1)
            // Rood betekent hier NIET "onbekeken" (spec §25) -- onbekeken blijft neutraal grijs,
            // enkel "volgende" krijgt cyaan.
            .foregroundStyle(watched || !isNext ? .secondary : VeyraColors.cyan)
    }

    @ViewBuilder
    private func posterImage(_ url: URL?, small: Bool = false) -> some View {
        let w: CGFloat = small ? posterSmallWidth : posterWidth
        let h: CGFloat = small ? posterSmallHeight : posterHeight
        VeyraAsyncImage(url: url) { phase in
            if case .success(let image) = phase { image.resizable().scaledToFill() }
            else { VeyraColors.surface }
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var emptyState: some View {
        // Spec §64: lege collectie. Films toevoegen gebeurt via "Toevoegen aan collectie" op een
        // filmpagina (Fase 3) -- een eigen zoek/toevoeg-flow hier komt in Fase 6 (Beheer).
        VStack(alignment: .leading, spacing: 6) {
            Text("Nog geen films")
                .font(.system(size: stageSubtitleSize, weight: .semibold))
                .foregroundStyle(.white)
            Text("Voeg films toe via \"Toevoegen aan collectie\" op een filmpagina.")
                .font(.system(size: journeyStatusSize))
                .foregroundStyle(.secondary)
        }
    }

    #if os(tvOS)
    private let horizontalPadding: CGFloat = 48
    private let verticalPadding: CGFloat = 36
    private let verticalPaddingTop: CGFloat = -24
    private let sectionSpacing: CGFloat = 32
    private let stageHeight: CGFloat = 340
    private let stagePadding: CGFloat = 32
    private let stageTitleSize: CGFloat = 34
    private let stageSubtitleSize: CGFloat = 20
    private let stageMetaSize: CGFloat = 18
    private let stageLogoMaxWidth: CGFloat = 520
    private let stageLogoMaxHeight: CGFloat = 110
    private let progressBarMaxWidth: CGFloat = 420
    private let journeyHeaderSize: CGFloat = 20
    private let journeyGap: CGFloat = 24
    private let journeyYearSize: CGFloat = 20
    private let journeyTitleSize: CGFloat = 18
    private let journeyStatusSize: CGFloat = 13
    private let journeyCardWidth: CGFloat = 195
    private let posterWidth: CGFloat = 195
    private let posterHeight: CGFloat = 288
    private let posterSmallWidth: CGFloat = 68
    private let posterSmallHeight: CGFloat = 100
    #else
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 16
    private let verticalPaddingTop: CGFloat = 16
    private let sectionSpacing: CGFloat = 20
    private let stageHeight: CGFloat = 220
    private let stagePadding: CGFloat = 18
    private let stageTitleSize: CGFloat = 24
    private let stageSubtitleSize: CGFloat = 15
    private let stageMetaSize: CGFloat = 13
    private let stageLogoMaxWidth: CGFloat = 320
    private let stageLogoMaxHeight: CGFloat = 70
    private let progressBarMaxWidth: CGFloat = 260
    private let journeyHeaderSize: CGFloat = 13
    private let journeyGap: CGFloat = 14
    private let journeyYearSize: CGFloat = 12
    private let journeyTitleSize: CGFloat = 14
    private let journeyStatusSize: CGFloat = 10
    private let journeyCardWidth: CGFloat = 100
    private let posterWidth: CGFloat = 100
    private let posterHeight: CGFloat = 148
    private let posterSmallWidth: CGFloat = 44
    private let posterSmallHeight: CGFloat = 64
    #endif
}

#if os(tvOS)
/// Cyaan focus-kader rond een poster in de Collection Journey (spec §5) -- gebruikt i.c.m.
/// `VeyraStreamingTileStyle()` op de omliggende `Button`, die tvOS' eigen witte focus-kaart
/// uitschakelt.
private struct VeyraJourneyPosterFocusRing<Content: View>: View {
    @Environment(\.isFocused) private var isFocused
    @ViewBuilder let content: Content
    var body: some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(VeyraFrame.active, lineWidth: 3)
                    .opacity(isFocused ? 1 : 0)
            )
            .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.4) : .clear, radius: 14)
            .scaleEffect(isFocused ? 1.05 : 1)
            .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}
#endif

