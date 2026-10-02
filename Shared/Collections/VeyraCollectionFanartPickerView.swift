// VeyraCollectionFanartPickerView.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Fanart-picker voor een eigen collectie (spec §45-§57): vier modi (Automatisch / Uit collectie /
// Zoek fanart / Eigen afbeelding), positie/zoom-sliders (spec §55, vereenvoudigd tot een
// focal-point-offset i.p.v. een drag-cropper) en een staging-stap (spec §57: eerst kiezen/
// bekijken, pas bij "Toepassen" écht opslaan via `store.update`). Hergebruikt bewust dezelfde
// bronnen als de bestaande Home-banner-editor (`VeyraCollectionEditorView` in VeyraBentoCatalog.swift):
// `VeyraCatalogSource().searchCollections`/`PhotosPicker`/vrij https-veld, maar bewaart in de eigen
// `VeyraCollectionArtworkStore`-map (zie dat bestand) zodat de twee losstaande "Collections"-systemen
// elkaars bestanden niet overschrijven.

import SwiftUI
#if os(iOS)
import PhotosUI
#endif
#if os(macOS)
import UniformTypeIdentifiers
import AppKit
#endif

struct VeyraCollectionFanartPickerView: View {
    let collectionID: VeyraCollection.ID

    @ObservedObject private var store = VeyraCollectionStore.shared
    @Environment(\.dismiss) private var dismiss

    /// nil = nog niets gewijzigd t.o.v. de opgeslagen collectie; .some(nil) = "automatisch" gekozen;
    /// .some(ref) = een nieuwe eigen afbeelding/url gekozen. Pas bij "Toepassen" effectief opgeslagen.
    @State private var stagedReference: String?? = nil
    @State private var position: VeyraArtworkPosition

    @State private var resolvedItems: [VeyraResolvedCollectionItem] = []
    @State private var searchText = ""
    @State private var searchResults: [BentoCollectionEntry] = []
    @State private var searching = false
    @State private var searched = false
    @State private var urlText = ""
    #if os(iOS)
    @State private var photo: PhotosPickerItem?
    #endif
    #if os(macOS)
    @State private var showFileImporter = false
    #endif

    init(collectionID: VeyraCollection.ID) {
        self.collectionID = collectionID
        let existing = VeyraCollectionStore.shared.collections.first { $0.id == collectionID }
        _position = State(initialValue: existing?.artworkPosition ?? VeyraArtworkPosition())
    }

    private var collection: VeyraCollection? { store.collections.first { $0.id == collectionID } }

    private var previewURL: URL? {
        if let staged = stagedReference {
            guard let ref = staged, !ref.isEmpty else { return resolvedItems.first?.media.backdropURL }
            if ref.hasPrefix("http") { return URL(string: ref) }
            let local = VeyraCollectionArtworkStore.imagesDirectory.appendingPathComponent(ref)
            if FileManager.default.fileExists(atPath: local.path) { return URL(fileURLWithPath: local.path) }
            return nil
        }
        guard let collection else { return nil }
        return VeyraCollectionArtworkResolver.resolvedURL(for: collection, fallback: resolvedItems.first?.media.backdropURL)
    }

    var body: some View {
        content
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
        Form {
            Section {
                GeometryReader { geo in
                    VeyraAsyncImage(url: previewURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                                .scaleEffect(position.zoom)
                                .offset(x: (0.5 - position.x) * geo.size.width, y: (0.5 - position.y) * geo.size.height)
                        } else {
                            Color.white.opacity(0.08)
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
                Text("Voorbeeld")
            }

            Section {
                Button("Gebruik automatische fanart") { stagedReference = .some(nil) }
            } header: {
                Text("Automatisch")
            } footer: {
                Text("Backdrop van het meest prominente deel in de collectie.")
            }

            if !resolvedItems.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(resolvedItems) { resolved in
                                if let url = resolved.media.backdropURL {
                                    thumbnail(url) { stagedReference = .some(url.absoluteString) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
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
                                    thumbnail(url) { stagedReference = .some(url.absoluteString) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Zoek fanart")
            }

            Section {
                TextField("Eigen afbeelding (https-adres)", text: $urlText)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                Button("Dit adres gebruiken") { useURLText() }
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)
                #if os(iOS)
                PhotosPicker("Kies een foto uit Foto's", selection: $photo, matching: .images)
                #endif
                #if os(macOS)
                // Spec §58/§81: natieve file picker op macOS i.p.v. een eigen bestandsdialoog.
                Button("Kies een afbeelding…") { showFileImporter = true }
                #endif
            } header: {
                Text("Eigen afbeelding")
            }
        }
        .navigationTitle("Fanart")
        .task { await loadResolvedItems() }
        #if os(iOS)
        .onChange(of: photo) { _, item in
            Task { await importPhoto(item) }
        }
        #endif
        #if os(macOS)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image]) { result in
            importFile(result)
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
        Color.white.opacity(0.08)
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

    private func useURLText() {
        let text = urlText.trimmingCharacters(in: .whitespaces)
        guard text.lowercased().hasPrefix("http") else { return }
        stagedReference = .some(text)
        urlText = ""
    }

    private func apply() {
        if let staged = stagedReference {
            store.update(collectionID, artworkReference: .some(staged), artworkPosition: .some(position))
        } else {
            store.update(collectionID, artworkPosition: .some(position))
        }
        dismiss()
    }

    private func loadResolvedItems() async {
        guard let collection else { return }
        resolvedItems = await VeyraCollectionMetadataResolver.resolve(collection.items)
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
    private func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.85),
              let name = VeyraCollectionArtworkStore.saveImage(jpeg) else { return }
        stagedReference = .some(name)
        photo = nil
    }
    #endif

    #if os(macOS)
    private func importFile(_ result: Result<URL, Error>) {
        guard let url = try? result.get() else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]),
              let name = VeyraCollectionArtworkStore.saveImage(jpeg) else { return }
        stagedReference = .some(name)
    }
    #endif
}
