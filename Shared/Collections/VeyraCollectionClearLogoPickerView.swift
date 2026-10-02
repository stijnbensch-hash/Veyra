// VeyraCollectionClearLogoPickerView.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Kies een eigen clearlogo voor een collectie (titel-logo i.p.v. tekst op kaarten/Stage), met
// dezelfde vier-modi-opzet als `VeyraCollectionFanartPickerView` (spec §45-§57): Automatisch /
// Uit collectie / Eigen afbeelding. Geen "Zoek fanart"-modus zoals bij de fanart-picker -- TMDB
// biedt geen doorzoekbare clearlogo-bron per collectienaam, enkel per film (vandaar "Uit
// collectie": haalt het TMDB-clearlogo van elk deel op). Geen positie/zoom-sliders: logo's worden
// altijd volledig/gecentreerd getoond (`scaledToFit`), geen crop nodig. Bewaart in dezelfde
// `VeyraCollectionArtworkStore`-map als fanart (gewoon een andere bestandsnaam/referentie-veld).

import SwiftUI
#if os(iOS)
import PhotosUI
#endif
#if os(macOS)
import UniformTypeIdentifiers
import AppKit
#endif

struct VeyraCollectionClearLogoPickerView: View {
    let collectionID: VeyraCollection.ID

    @ObservedObject private var store = VeyraCollectionStore.shared
    @Environment(\.dismiss) private var dismiss

    /// nil = nog niets gewijzigd; .some(nil) = "automatisch" gekozen; .some(ref) = nieuw logo.
    @State private var stagedReference: String?? = nil
    @State private var resolvedItems: [VeyraResolvedCollectionItem] = []
    @State private var logoCandidates: [URL] = []
    @State private var loadingCandidates = false
    @State private var candidatesLoaded = false
    @State private var urlText = ""
    #if os(iOS)
    @State private var photo: PhotosPickerItem?
    #endif
    #if os(macOS)
    @State private var showFileImporter = false
    #endif

    private var collection: VeyraCollection? { store.collections.first { $0.id == collectionID } }

    private var previewURL: URL? {
        if let staged = stagedReference {
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
                ZStack {
                    Color.white.opacity(0.08)
                    if let previewURL {
                        AsyncImage(url: previewURL) { phase in
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
                Text("Voorbeeld")
            }

            Section {
                Button("Gebruik titel-tekst (geen logo)") { stagedReference = .some(nil) }
            } header: {
                Text("Automatisch")
            } footer: {
                Text("Toont de collectienaam als tekst i.p.v. een logo.")
            }

            Section {
                Button(loadingCandidates ? "Laden…" : "Haal logo's op uit collectie") { Task { await loadCandidates() } }
                    .disabled(loadingCandidates || resolvedItems.isEmpty)
                if candidatesLoaded && logoCandidates.isEmpty {
                    Text("Geen logo's gevonden.").foregroundStyle(.secondary)
                }
                if !logoCandidates.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(logoCandidates, id: \.self) { url in
                                logoThumbnail(url) { stagedReference = .some(url.absoluteString) }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Uit collectie")
            } footer: {
                Text("TMDB-clearlogo van elke film in de collectie.")
            }

            Section {
                TextField("Eigen logo (https-adres)", text: $urlText)
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
                Button("Kies een afbeelding…") { showFileImporter = true }
                #endif
            } header: {
                Text("Eigen afbeelding")
            } footer: {
                Text("Bij voorkeur een transparante afbeelding (PNG).")
            }
        }
        .navigationTitle("Clearlogo")
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

    @ViewBuilder
    private func logoThumbnail(_ url: URL, onTap: @escaping () -> Void) -> some View {
        ZStack {
            Color.white.opacity(0.08)
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase { image.resizable().scaledToFit().padding(8) } else { Color.clear }
            }
        }
        .frame(width: 160, height: 90)
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
        guard let staged = stagedReference else { dismiss(); return }
        store.update(collectionID, clearLogoReference: .some(staged))
        dismiss()
    }

    private func loadResolvedItems() async {
        guard let collection else { return }
        resolvedItems = await VeyraCollectionMetadataResolver.resolve(collection.items)
    }

    // Enkel aangeroepen op expliciet verzoek van de gebruiker (knop), niet automatisch bij het
    // openen van het scherm -- zelfde voorzichtigheid als elders met per-film TMDB-aanvragen.
    private func loadCandidates() async {
        loadingCandidates = true
        var urls: [URL] = []
        await withTaskGroup(of: URL?.self) { group in
            for resolved in resolvedItems {
                group.addTask { await ArtworkResolver.shared.clearLogoURL(for: resolved.media) }
            }
            for await url in group { if let url { urls.append(url) } }
        }
        var seen = Set<URL>()
        logoCandidates = urls.filter { seen.insert($0).inserted }
        candidatesLoaded = true
        loadingCandidates = false
    }

    #if os(iOS)
    private func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data), let png = image.pngData(),
              let name = VeyraCollectionArtworkStore.saveImage(png) else { return }
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
              let png = bitmap.representation(using: .png, properties: [:]),
              let name = VeyraCollectionArtworkStore.saveImage(png) else { return }
        stagedReference = .some(name)
    }
    #endif
}
