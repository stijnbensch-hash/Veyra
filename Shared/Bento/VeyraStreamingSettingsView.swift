// VeyraStreamingSettingsView.swift
// Instellingen > Home > Streamingdiensten: verwijderen, toevoegen (regio of addon-catalogus), volgorde, eigen logo.

import SwiftUI
#if os(iOS)
import PhotosUI
#endif

struct VeyraStreamingSettingsView: View {
    @State private var entries: [BentoStreamingEntry] = []
    @State private var loading = true

    var body: some View {
        Form {
            Section {
                if loading {
                    ProgressView()
                } else if entries.isEmpty {
                    Text("Nog geen streamingdiensten.").foregroundStyle(.secondary)
                }
                // Volgorde bepaal je hier rechtstreeks in de lijst (sleepbalkje op
                // iOS via "Bewerken", knoppen op tvOS) i.p.v. in het deelmenu van
                // een losse dienst. Op tvOS staan de op/neer-knoppen bewust NAAST
                // de NavigationLink (niet erin genest) -- een Button genest in het
                // label van een NavigationLink krijgt op tvOS geen eigen
                // remote-focus en zou dus onbruikbaar zijn.
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 14) {
                        #if !os(iOS)
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                        #endif
                        NavigationLink {
                            VeyraStreamingEditorView(entryID: entry.id, entries: $entries)
                        } label: {
                            row(entry)
                        }
                        #if !os(iOS)
                        Spacer()
                        VStack(spacing: 6) {
                            Button { moveEntry(index, by: -1) } label: {
                                Image(systemName: "chevron.up")
                            }.disabled(index == 0)
                            Button { moveEntry(index, by: 1) } label: {
                                Image(systemName: "chevron.down")
                            }.disabled(index >= entries.count - 1)
                        }
                        .buttonStyle(.plain)
                        #endif
                    }
                }
                .onMove { offsets, destination in
                    entries.move(fromOffsets: offsets, toOffset: destination)
                    VeyraStreamingStore.save(entries)
                }
            } header: {
                Text("Streamingdiensten op Home")
            } footer: {
                Text("Kies een dienst om de naam of het logo aan te passen, of om hem te verwijderen.")
            }

            Section {
                NavigationLink("Diensten in jouw regio") {
                    VeyraStreamingProviderPickerView(entries: $entries)
                }
                NavigationLink("Catalogi uit addons / VeyraHub") {
                    VeyraStreamingAddonPickerView(entries: $entries)
                }
            } header: {
                Text("Toevoegen")
            } footer: {
                Text("Addon-catalogi (bv. AIOMetadata) komen ook via VeyraHub op je andere apparaten.")
            }

            Section {
                Button("Standaardlijst herstellen") { reset() }
            }
        }
        .navigationTitle("Streamingdiensten")
        #if os(iOS)
        .toolbar { EditButton() }
        #endif
        .task { await load() }
    }

    private func row(_ entry: BentoStreamingEntry) -> some View {
        HStack(spacing: 14) {
            logo(entry)
                .frame(width: 84, height: 48)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                Text(entry.isAddon ? "Addon-catalogus" : "Streamingdienst")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    #if !os(iOS)
    private func moveEntry(_ index: Int, by offset: Int) {
        let target = index + offset
        guard entries.indices.contains(index), entries.indices.contains(target) else { return }
        entries.swapAt(index, target)
        VeyraStreamingStore.save(entries)
    }
    #endif

    @ViewBuilder
    private func logo(_ entry: BentoStreamingEntry) -> some View {
        let url = VeyraStreamingStore.logoURL(for: entry)
            ?? entry.logoPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w154\($0)") }
        AsyncImage(url: url) { phase in
            if let image = phase.image { image.resizable().scaledToFit().padding(4) } else { Color.clear }
        }
    }

    private func load() async {
        loading = true
        if let custom = VeyraStreamingStore.load() {
            entries = custom
        } else {
            entries = await VeyraCatalogSource().defaultStreamingEntries()
        }
        loading = false
    }

    private func reset() {
        VeyraStreamingStore.reset()
        Task { await load() }
    }
}

// MARK: - Toevoegen

struct VeyraStreamingProviderPickerView: View {
    @Binding var entries: [BentoStreamingEntry]
    @State private var options: [BentoStreamingEntry] = []
    @State private var loading = true

    // Landkiezer: standaard je algemene kijkregio, maar je kunt hier een
    // ander land kiezen om diensten van DAT land toe te voegen -- dit
    // wijzigt alleen wat je hier ziet, niet je algemene regio-instelling.
    // Diensten van meerdere landen kun je zo naast elkaar toevoegen; de
    // lijst wordt nooit vervangen, alleen aangevuld (`add(_:)` hieronder).
    @State private var countries: [(code: String, name: String)] = []
    @State private var selectedCountryCode: String = VeyraCatalogSource.currentRegion
    @State private var loadingCountries = true

    private var available: [BentoStreamingEntry] {
        options.filter { option in !entries.contains(where: { $0.id == option.id }) }
    }

    private var selectedCountryName: String {
        countries.first { $0.code == selectedCountryCode }?.name ?? selectedCountryCode
    }

    var body: some View {
        Form {
            Section {
                if loadingCountries {
                    ProgressView()
                } else {
                    Picker("Land", selection: $selectedCountryCode) {
                        ForEach(countries, id: \.code) { country in
                            Text(country.name).tag(country.code)
                        }
                    }
                }
            } header: {
                Text("Land")
            } footer: {
                Text("Je algemene kijkregio (bij de algemene instellingen) blijft ongewijzigd -- dit kiest alleen uit welk land je hier diensten toevoegt.")
            }

            Section {
                if loading {
                    ProgressView()
                } else if available.isEmpty {
                    Text("Alle diensten in \(selectedCountryName) staan al op Home.").foregroundStyle(.secondary)
                }
                ForEach(available) { option in
                    Button { add(option) } label: {
                        HStack {
                            AsyncImage(url: option.logoPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w92\($0)") }) { phase in
                                if let image = phase.image { image.resizable().scaledToFill() } else { Color.white.opacity(0.1) }
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text(option.name)
                            Spacer()
                            Image(systemName: "plus.circle").foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Diensten in \(selectedCountryName)")
            } footer: {
                Text("Toevoegen vult je bestaande lijst op Home aan -- niets wordt vervangen.")
            }
        }
        .navigationTitle("Diensten in jouw regio")
        .task {
            countries = await VeyraCatalogSource().availableProviderCountries()
            loadingCountries = false
            await loadProviders()
        }
        .onChange(of: selectedCountryCode) { _, _ in
            Task { await loadProviders() }
        }
    }

    private func loadProviders() async {
        loading = true
        options = await VeyraCatalogSource().selectableProviders(region: selectedCountryCode)
        loading = false
    }

    private func add(_ option: BentoStreamingEntry) {
        guard !entries.contains(where: { $0.id == option.id }) else { return }
        // `option` komt uit `selectableProviders(region: selectedCountryCode)`, dus
        // die is al voor dit land opgehaald -- expliciet meegeven zodat de inhoud
        // van deze dienst later met de JUISTE `watch_region` wordt opgevraagd
        // i.p.v. altijd de algemene kijkregio (zie `BentoStreamingEntry.watchRegion`).
        var entry = option
        entry.watchRegion = selectedCountryCode
        entries.append(entry)
        VeyraStreamingStore.save(entries)
    }
}

struct VeyraStreamingAddonPickerView: View {
    @Binding var entries: [BentoStreamingEntry]

    private struct AddonGroup: Identifiable {
        let id: UUID
        let name: String
        let catalogs: [AIOMetadataCatalog]
    }

    @State private var groups: [AddonGroup] = []
    @State private var loading = true

    var body: some View {
        Form {
            if loading {
                Section { ProgressView() }
            } else if groups.isEmpty {
                Section {
                    Text("Geen addons met catalogi gevonden. Installeer een metadata-addon (bv. AIOMetadata) onder Addons.")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(groups) { group in
                Section {
                    ForEach(group.catalogs, id: \.uniqueID) { catalog in
                        let entry = BentoStreamingEntry(addonID: group.id, catalogType: catalog.type, catalogID: catalog.id,
                                                        name: catalog.displayName)
                        if !entries.contains(where: { $0.id == entry.id }) {
                            Button { add(entry) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(catalog.displayName)
                                        Text(catalog.type == "series" ? "Series" : "Films")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text(group.name)
                }
            }
        }
        .navigationTitle("Addon-catalogi")
        .task { await load() }
    }

    private func load() async {
        loading = true
        var result: [AddonGroup] = []
        for addon in AddonStore().load() where addon.isEnabled && addon.kind == .aioMetadata {
            guard let manifest = try? await AIOMetadataClient(baseURL: addon.baseURL).manifest() else { continue }
            let catalogs = (manifest.catalogs ?? []).filter { $0.type == "movie" || $0.type == "series" }
            if !catalogs.isEmpty { result.append(AddonGroup(id: addon.id, name: addon.name, catalogs: catalogs)) }
        }
        groups = result
        loading = false
    }

    private func add(_ entry: BentoStreamingEntry) {
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.append(entry)
        VeyraStreamingStore.save(entries)
    }
}

// MARK: - Eén dienst aanpassen

struct VeyraStreamingEditorView: View {
    let entryID: String
    @Binding var entries: [BentoStreamingEntry]

    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    #if os(iOS)
    @State private var photo: PhotosPickerItem?
    #endif

    private var index: Int? { entries.firstIndex { $0.id == entryID } }

    var body: some View {
        Form {
            if let index {
                Section {
                    TextField("Naam", text: nameBinding(index))
                } header: {
                    Text("Naam")
                }

                Section {
                    preview(entries[index])
                        .frame(maxWidth: .infinity)
                        .frame(height: 110)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

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

                    Button("Standaardlogo herstellen") { setLogo(nil) }
                        .disabled(entries[index].customLogo == nil)
                } header: {
                    Text("Logo")
                } footer: {
                    Text("Een https-adres wordt ook op je andere apparaten gebruikt; een foto blijft op dit apparaat.")
                }

                Section {
                    Button("Verwijderen", role: .destructive) { remove(index) }
                }
            }
        }
        .navigationTitle("Streamingdienst")
        #if os(iOS)
        .onChange(of: photo) { _, item in
            Task { await importPhoto(item) }
        }
        #endif
    }

    @ViewBuilder
    private func preview(_ entry: BentoStreamingEntry) -> some View {
        let url = VeyraStreamingStore.logoURL(for: entry)
            ?? entry.logoPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w154\($0)") }
        AsyncImage(url: url) { phase in
            if let image = phase.image { image.resizable().scaledToFit().padding(14) } else { Text(entry.name).font(.title3.bold()) }
        }
    }

    private func nameBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { entries.indices.contains(index) ? entries[index].name : "" },
            set: { newValue in
                guard entries.indices.contains(index) else { return }
                entries[index].name = newValue
                VeyraStreamingStore.save(entries)
            })
    }

    private func setLogo(_ value: String?) {
        guard let index else { return }
        entries[index].customLogo = value
        VeyraStreamingStore.save(entries)
    }

    private func useURLText() {
        let text = urlText.trimmingCharacters(in: .whitespaces)
        guard text.lowercased().hasPrefix("http") else { return }
        setLogo(text)
        urlText = ""
    }

    private func remove(_ index: Int) {
        guard entries.indices.contains(index) else { return }
        entries.remove(at: index)
        VeyraStreamingStore.save(entries)
        dismiss()
    }

    #if os(iOS)
    private func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data), let png = image.pngData(),
              let name = VeyraCollectionsStore.saveImage(png) else { return }
        setLogo(name)
        photo = nil
    }
    #endif
}
