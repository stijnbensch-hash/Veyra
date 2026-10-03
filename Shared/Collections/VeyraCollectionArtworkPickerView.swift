// VeyraCollectionArtworkPickerView.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Artwork" voor een eigen collectie -- op uitdrukkelijk verzoek samengevoegd uit de vroegere
// losse `VeyraCollectionFanartPickerView`/`VeyraCollectionClearLogoPickerView` tot ÉÉN scherm met
// dezelfde opzet als Movie/Series' "Artwork aanpassen" (`VeyraArtworkPickerView`): secties per
// type, elk met een "Gebruik automatisch"-knop en een rij TMDB-candidates om uit te kiezen.
// Anders dan die film/series-picker houdt dit scherm WEL de Collections-eigen mogelijkheid om
// een eigen afbeelding toe te voegen (https-adres / foto's / bestand) -- vandaar geen 1-op-1
// hergebruik van dat bestand, want TMDB-candidates alleen volstaan hier niet (een eigen collectie
// heeft geen eigen TMDB-ID, en zelfs een officiële collectie heeft geen logo-candidates).
//
// Twee secties:
//   Achtergrond -- positie/zoom (spec §55/§59), Automatisch, TMDB-afbeeldingen (enkel officiële
//   collecties, `tmdbCollectionID`), Uit collectie (backdrop per film), Zoek fanart
//   (collectienaam-zoekertje, spec §45-§57), Eigen afbeelding.
//   ClearLogo -- Automatisch (titel-tekst), Uit collectie (TMDB-clearlogo per film -- geen
//   "Zoek"/TMDB-sectie: TMDB heeft geen doorzoekbare clearlogo-bron per collectie, en de
//   collectie-images-endpoint zelf heeft geen `logos`-veld), Eigen afbeelding.
//
// Bewaart beide in dezelfde `VeyraCollectionArtworkStore`-map (gewoon een ander referentieveld),
// via één gezamenlijke "Toepassen"-knop die zowel achtergrond als clearlogo in één keer opslaat.

import SwiftUI
#if os(iOS)
import PhotosUI
#endif
#if os(macOS)
import UniformTypeIdentifiers
import AppKit
#endif

struct VeyraCollectionArtworkPickerView: View {
    let collectionID: VeyraCollection.ID

    @ObservedObject private var store = VeyraCollectionStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var resolvedItems: [VeyraResolvedCollectionItem] = []

    // MARK: Achtergrond

    /// nil = nog niets gewijzigd t.o.v. de opgeslagen collectie; .some(nil) = "automatisch"
    /// gekozen; .some(ref) = een nieuwe eigen afbeelding/url gekozen. Pas bij "Toepassen" bewaard.
    @State private var stagedArtwork: String?? = nil
    @State private var position: VeyraArtworkPosition
    @State private var tmdbArtworkCandidates: [ArtworkCandidate] = []
    @State private var searchText = ""
    @State private var searchResults: [BentoCollectionEntry] = []
    @State private var searching = false
    @State private var searched = false
    @State private var artworkURLText = ""
    #if os(iOS)
    @State private var artworkPhoto: PhotosPickerItem?
    #endif
    #if os(macOS)
    @State private var showArtworkFileImporter = false
    #endif

    // MARK: ClearLogo

    @State private var stagedLogo: String?? = nil
    @State private var logoCandidates: [URL] = []
    @State private var loadingLogoCandidates = false
    @State private var logoCandidatesLoaded = false
    @State private var logoURLText = ""
    #if os(iOS)
    @State private var logoPhoto: PhotosPickerItem?
    #endif
    #if os(macOS)
    @State private var showLogoFileImporter = false
    #endif

    init(collectionID: VeyraCollection.ID) {
        self.collectionID = collectionID
        let existing = VeyraCollectionStore.shared.collections.first { $0.id == collectionID }
        _position = State(initialValue: existing?.artworkPosition ?? VeyraArtworkPosition())
    }

    private var collection: VeyraCollection? { store.collections.first { $0.id == collectionID } }

    private var artworkPreviewURL: URL? {
        if let staged = stagedArtwork {
            guard let ref = staged, !ref.isEmpty else { return resolvedItems.first?.media.backdropURL }
            if ref.hasPrefix("http") { return URL(string: ref) }
            let local = VeyraCollectionArtworkStore.imagesDirectory.appendingPathComponent(ref)
            if FileManager.default.fileExists(atPath: local.path) { return URL(fileURLWithPath: local.path) }
            return nil
        }
        guard let collection else { return nil }
        return VeyraCollectionArtworkResolver.resolvedURL(for: collection, fallback: resolvedItems.first?.media.backdropURL)
    }

    private var logoPreviewURL: URL? {
        if let staged = stagedLogo {
            guard let ref = staged, !ref.isEmpty else { return nil }
            if ref.hasPrefix("http") { return URL(string: ref) }
            let local = VeyraCollectionArtworkStore.imagesDirectory.appendingPathComponent(ref)
            if FileManager.default.fileExists(atPath: local.path) { return URL(fileURLWithPath: local.path) }
            return nil
        }
        guard let collection else { return nil }
        return VeyraCollectionClearLogoResolver.resolvedURL(for: collection)
    }

    var body: some View {
        VeyraDynamicBackgroundScope {
            content
        }
    }

    // tvOS: zie VeyraCreateCollectionSheet.swift -- Form krijgt daar geen eigen donkere
    // achtergrond, dus zonder `VeyraBackground()` erachter blijft de systeem-standaard (wit)
    // zichtbaar.
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
        VeyraForm {
            artworkSection
            logoSection
        }
        .navigationTitle("Artwork")
        .task { await loadResolvedItems() }
        .task { await loadTMDBArtworkCandidates() }
        #if os(iOS)
        .onChange(of: artworkPhoto) { _, item in Task { await importArtworkPhoto(item) } }
        .onChange(of: logoPhoto) { _, item in Task { await importLogoPhoto(item) } }
        #endif
        #if os(macOS)
        .fileImporter(isPresented: $showArtworkFileImporter, allowedContentTypes: [.image]) { result in
            importArtworkFile(result)
        }
        .fileImporter(isPresented: $showLogoFileImporter, allowedContentTypes: [.image]) { result in
            importLogoFile(result)
        }
        #endif
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuleren") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Toepassen") { apply() } }
        }
        #else
        .toolbar {
            Button("Annuleren") { dismiss() }
            Button("Toepassen") { apply() }
        }
        #endif
    }

    // MARK: - Achtergrond

    @ViewBuilder
    private var artworkSection: some View {
        Section {
            GeometryReader { geo in
                VeyraAsyncImage(url: artworkPreviewURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                            .scaleEffect(position.zoom)
                            .offset(x: (0.5 - position.x) * geo.size.width, y: (0.5 - position.y) * geo.size.height)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                positionControl("Zoom", value: $position.zoom, range: 1.0...2.0)
                positionControl("Horizontaal", value: $position.x, range: 0...1)
                positionControl("Verticaal", value: $position.y, range: 0...1)
            }
        } header: {
            Text("Achtergrond")
        }

        Section {
            Button("Gebruik automatisch") { stagedArtwork = .some(nil) }
        } header: {
            Text("Automatisch")
        } footer: {
            Text("Backdrop van het meest prominente deel in de collectie.")
        }

        if !tmdbArtworkCandidates.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(tmdbArtworkCandidates) { candidate in
                            thumbnail(candidate.url) { stagedArtwork = .some(candidate.url.absoluteString) }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
            } header: {
                Text("TMDB-afbeeldingen")
            } footer: {
                Text("Posters en achtergronden van deze collectie zelf op TMDB.")
            }
        }

        if !resolvedItems.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(resolvedItems) { resolved in
                            if let url = resolved.media.backdropURL {
                                thumbnail(url) { stagedArtwork = .some(url.absoluteString) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
            } header: {
                Text("Uit collectie")
            }
        }

        Section {
            #if os(tvOS)
            TextField("Zoeken", text: $searchText)
            #else
            TextField("Zoeken", text: $searchText)
                .textInputAutocapitalization(.never)
            #endif
            Button(searching ? "Zoeken…" : "Zoek fanart") { Task { await search() } }
                .disabled(searching || searchText.trimmingCharacters(in: .whitespaces).isEmpty)
            if searched && searchResults.isEmpty {
                Text("Geen resultaten gevonden.").foregroundStyle(.secondary)
            }
            if !searchResults.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(searchResults) { entry in
                            if let url = VeyraCollectionsStore.imageURL(for: entry) {
                                thumbnail(url) { stagedArtwork = .some(url.absoluteString) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
            }
        } header: {
            Text("Zoek fanart")
        }

        Section {
            TextField("Eigen afbeelding (https-adres)", text: $artworkURLText)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
            Button("Dit adres gebruiken") { useArtworkURLText() }
                .disabled(artworkURLText.trimmingCharacters(in: .whitespaces).isEmpty)
            #if os(iOS)
            PhotosPicker("Kies een foto uit Foto's", selection: $artworkPhoto, matching: .images)
            #endif
            #if os(macOS)
            Button("Kies een afbeelding…") { showArtworkFileImporter = true }
            #endif
        } header: {
            Text("Eigen afbeelding")
        }
    }

    // MARK: - ClearLogo

    @ViewBuilder
    private var logoSection: some View {
        Section {
            ZStack {
                if let logoPreviewURL {
                    VeyraAsyncImage(url: logoPreviewURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit().padding(20)
                        } else {
                            Color.clear
                        }
                    }
                } else {
                    Text("Geen logo -- titel-tekst wordt gebruikt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } header: {
            Text("ClearLogo")
        }

        Section {
            Button("Gebruik titel-tekst (geen logo)") { stagedLogo = .some(nil) }
        } header: {
            Text("Automatisch")
        } footer: {
            Text("Toont de collectienaam als tekst i.p.v. een logo.")
        }

        Section {
            Button(loadingLogoCandidates ? "Laden…" : "Haal logo's op uit collectie") { Task { await loadLogoCandidates() } }
                .disabled(loadingLogoCandidates || resolvedItems.isEmpty)
            if logoCandidatesLoaded && logoCandidates.isEmpty {
                Text("Geen logo's gevonden.").foregroundStyle(.secondary)
            }
            if !logoCandidates.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(logoCandidates, id: \.self) { url in
                            logoThumbnail(url) { stagedLogo = .some(url.absoluteString) }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
            }
        } header: {
            Text("Uit collectie")
        } footer: {
            Text("TMDB-clearlogo van elke film in de collectie.")
        }

        Section {
            TextField("Eigen logo (https-adres)", text: $logoURLText)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
            Button("Dit adres gebruiken") { useLogoURLText() }
                .disabled(logoURLText.trimmingCharacters(in: .whitespaces).isEmpty)
            #if os(iOS)
            PhotosPicker("Kies een foto uit Foto's", selection: $logoPhoto, matching: .images)
            #endif
            #if os(macOS)
            Button("Kies een afbeelding…") { showLogoFileImporter = true }
            #endif
        } header: {
            Text("Eigen afbeelding")
        } footer: {
            Text("Bij voorkeur een transparante afbeelding (PNG).")
        }
    }

    // MARK: - Gedeeld

    // tvOS heeft geen `Slider` -- remote-vriendelijke stap-knoppen in plaats daarvan (spec §39/§79).
    @ViewBuilder
    private func positionControl(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        Text(label).font(.caption).foregroundStyle(.secondary)
        #if os(tvOS)
        HStack(spacing: 16) {
            Button {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - 0.05)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(VeyraStreamingTileStyle())

            Text(String(format: "%.0f%%", (value.wrappedValue - range.lowerBound) / (range.upperBound - range.lowerBound) * 100))
                .font(.caption.monospacedDigit())
                .frame(width: 60)

            Button {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + 0.05)
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .buttonStyle(VeyraStreamingTileStyle())
        }
        #else
        Slider(value: value, in: range)
        #endif
    }

    @ViewBuilder
    private func thumbnail(_ url: URL, onTap: @escaping () -> Void) -> some View {
        Color.clear
            .frame(width: 180, height: 180 * 9 / 16)
            .overlay {
                VeyraAsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Color.clear }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private func logoThumbnail(_ url: URL, onTap: @escaping () -> Void) -> some View {
        VeyraAsyncImage(url: url) { phase in
            if case .success(let image) = phase { image.resizable().scaledToFit().padding(8) } else { Color.clear }
        }
        .frame(width: 160, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private func useArtworkURLText() {
        let text = artworkURLText.trimmingCharacters(in: .whitespaces)
        guard text.lowercased().hasPrefix("http") else { return }
        stagedArtwork = .some(text)
        artworkURLText = ""
    }

    private func useLogoURLText() {
        let text = logoURLText.trimmingCharacters(in: .whitespaces)
        guard text.lowercased().hasPrefix("http") else { return }
        stagedLogo = .some(text)
        logoURLText = ""
    }

    private func apply() {
        // `stagedArtwork`/`stagedLogo` zijn al precies het `String??` type dat `update`
        // verwacht (nil = ongewijzigd laten, .some(nil) = automatisch, .some(ref) = nieuw) --
        // rechtstreeks doorgeven i.p.v. opnieuw inpakken. Positie wordt altijd bewaard, ook
        // zonder nieuwe achtergrond (zelfde gedrag als de oude fanart-picker).
        store.update(
            collectionID,
            artworkReference: stagedArtwork,
            artworkPosition: .some(position),
            clearLogoReference: stagedLogo
        )
        dismiss()
    }

    private func loadResolvedItems() async {
        guard let collection else { return }
        resolvedItems = await VeyraCollectionMetadataResolver.resolve(collection.items)
    }

    /// Enkel voor een OFFICIËLE TMDB-collectie (`tmdbCollectionID`) -- een eigen collectie heeft
    /// geen eigen TMDB-ID om candidates voor op te halen.
    private func loadTMDBArtworkCandidates() async {
        guard let tmdbCollectionID = collection?.tmdbCollectionID else { return }
        tmdbArtworkCandidates = await ArtworkCandidateService.candidates(forTMDBCollectionID: tmdbCollectionID)
    }

    // Enkel aangeroepen op expliciet verzoek van de gebruiker (knop), niet automatisch bij het
    // openen van het scherm -- zelfde voorzichtigheid als elders met per-film TMDB-aanvragen.
    private func loadLogoCandidates() async {
        loadingLogoCandidates = true
        var urls: [URL] = []
        await withTaskGroup(of: URL?.self) { group in
            for resolved in resolvedItems {
                group.addTask { await ArtworkResolver.shared.clearLogoURL(for: resolved.media) }
            }
            for await url in group { if let url { urls.append(url) } }
        }
        var seen = Set<URL>()
        let deduped = urls.filter { seen.insert($0).inserted }
        // Zelfde check als de film/series-Artwork-picker: sommige TMDB-clearlogo's zijn
        // in werkelijkheid geen transparante PNG maar een plat beeld met een
        // ondoorzichtige achtergrond gebakken in de pixels -- die hier ook wegfilteren
        // i.p.v. ze als wit kaartje te tonen.
        logoCandidates = await Self.filteringOutOpaqueLogoURLs(deduped)
        logoCandidatesLoaded = true
        loadingLogoCandidates = false
    }

    private static func filteringOutOpaqueLogoURLs(_ urls: [URL]) async -> [URL] {
        guard !urls.isEmpty else { return urls }
        var transparent: Set<URL> = []
        await withTaskGroup(of: (URL, Bool).self) { group in
            for url in urls {
                group.addTask {
                    guard let decoded = try? await VeyraArtworkLoader.shared.load(url, pixels: 200) else {
                        return (url, true)
                    }
                    switch decoded.image.alphaInfo {
                    case .none, .noneSkipFirst, .noneSkipLast: return (url, false)
                    default: return (url, true)
                    }
                }
            }
            for await (url, isTransparent) in group where isTransparent {
                transparent.insert(url)
            }
        }
        return urls.filter { transparent.contains($0) }
    }

    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        searching = true
        searchResults = await VeyraCatalogSource().searchCollections(query)
        searched = true
        searching = false
    }

    #if os(iOS)
    private func importArtworkPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.85),
              let name = VeyraCollectionArtworkStore.saveImage(jpeg) else { return }
        stagedArtwork = .some(name)
        artworkPhoto = nil
    }

    private func importLogoPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data), let png = image.pngData(),
              let name = VeyraCollectionArtworkStore.saveImage(png) else { return }
        stagedLogo = .some(name)
        logoPhoto = nil
    }
    #endif

    #if os(macOS)
    private func importArtworkFile(_ result: Result<URL, Error>) {
        guard let url = try? result.get() else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]),
              let name = VeyraCollectionArtworkStore.saveImage(jpeg) else { return }
        stagedArtwork = .some(name)
    }

    private func importLogoFile(_ result: Result<URL, Error>) {
        guard let url = try? result.get() else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]),
              let name = VeyraCollectionArtworkStore.saveImage(png) else { return }
        stagedLogo = .some(name)
    }
    #endif
}
