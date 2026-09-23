import PhotosUI
import SwiftUI

/// iOS-scherm om het logo én de naam van één zender aan te passen —
/// bereikbaar door lang op een zenderlogo te drukken (contextmenu: "Logo
/// aanpassen…") in `LiveTVView` en `RecentLiveTVRow`.
///
/// Logo: zoeken in de gratis iptv-org logo-database
/// (`IPTVOrgLogoDirectory`), een eigen afbeeldings-URL, of een foto uit de
/// fotobibliotheek van het toestel. Naam: vrije tekst. Beide keuzes worden
/// opgeslagen via `ChannelLogoOverrideStore`/`ChannelNameOverrideStore` en
/// gelden overal waar deze zender voorkomt.
struct ChannelLogoPickerView: View {
    let channelID: String
    let channelName: String
    let currentOverrideURL: URL?
    let currentNameOverride: String?

    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [IPTVOrgLogoResult] = []
    @State private var isSearching = false
    @State private var searchError: String?

    @State private var customURLString = ""

    @State private var photoSelection: PhotosPickerItem?
    @State private var isImportingPhoto = false
    @State private var photoError: String?

    @State private var nameText: String

    init(
        channelID: String,
        channelName: String,
        currentOverrideURL: URL?,
        currentNameOverride: String? = nil,
        onSaved: @escaping () -> Void = {}
    ) {
        self.channelID = channelID
        self.channelName = channelName
        self.currentOverrideURL = currentOverrideURL
        self.currentNameOverride = currentNameOverride
        self.onSaved = onSaved
        _nameText = State(initialValue: currentNameOverride ?? channelName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraColors.background.ignoresSafeArea()

                List {
                    Section {
                        TextField("Zendernaam", text: $nameText)
                            .textInputAutocapitalization(.words)
                        Button("Naam opslaan") {
                            saveName()
                        }
                        .disabled(isNameUnchanged || trimmedName.isEmpty)

                        if currentNameOverride != nil {
                            Button("Naam herstellen naar origineel", role: .destructive) {
                                ChannelNameOverrideStore.removeOverride(forChannelID: channelID)
                                nameText = channelName
                                onSaved()
                            }
                        }
                    } header: {
                        Text("Naam")
                    } footer: {
                        Text("Geldt overal waar deze zender wordt getoond, ook in de speler.")
                    }

                    Section {
                        currentLogoPreview
                    } header: {
                        Text("Huidig logo")
                    }

                    Section {
                        TextField("Zoek zendernaam (bv. \"BBC One\")", text: $query)
                            .textInputAutocapitalization(.words)
                            .onChange(of: query) { _, _ in Task { await search() } }

                        if isSearching {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Zoeken in iptv-org + tv-logos…").foregroundStyle(.secondary)
                            }
                        } else if let searchError {
                            Text(searchError).foregroundStyle(.red)
                        } else if !results.isEmpty {
                            ForEach(results) { result in
                                resultRow(result)
                            }
                        } else if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text("Geen logo's gevonden voor \"\(query)\".").foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Zoeken in logo-databases (iptv-org + tv-logos)")
                    } footer: {
                        Text("Gratis, doorzoekbare verzameling zenderlogo's van de open-source projecten iptv-org en tv-logo/tv-logos.")
                    }

                    Section {
                        TextField("https://…/logo.png", text: $customURLString)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)

                        Button("Eigen URL gebruiken") {
                            applyCustomURL()
                        }
                        .disabled(URL(string: customURLString.trimmingCharacters(in: .whitespaces))?.host == nil)
                    } header: {
                        Text("Eigen logo-URL")
                    }

                    Section {
                        PhotosPicker(selection: $photoSelection, matching: .images) {
                            Label("Kies foto uit bibliotheek", systemImage: "photo.on.rectangle")
                        }

                        if isImportingPhoto {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Foto verwerken…").foregroundStyle(.secondary)
                            }
                        } else if let photoError {
                            Text(photoError).foregroundStyle(.red)
                        }
                    } header: {
                        Text("Eigen foto")
                    }

                    if currentOverrideURL != nil {
                        Section {
                            Button("Terugzetten naar standaardlogo", role: .destructive) {
                                ChannelLogoOverrideStore.removeOverride(forChannelID: channelID)
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(currentNameOverride ?? channelName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten") { dismiss() }
                }
            }
            .onChange(of: photoSelection) { _, newValue in
                guard let newValue else { return }
                Task { await importPhoto(newValue) }
            }
        }
    }

    private var trimmedName: String {
        nameText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameUnchanged: Bool {
        trimmedName == (currentNameOverride ?? channelName)
    }

    private func saveName() {
        guard !trimmedName.isEmpty else { return }
        ChannelNameOverrideStore.setName(trimmedName, forChannelID: channelID)
        onSaved()
    }

    private var currentLogoPreview: some View {
        HStack(spacing: 16) {
            AsyncImage(url: currentOverrideURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "tv").foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 44)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(currentOverrideURL == nil ? "Standaardlogo van de provider/EPG." : "Eigen logo ingesteld.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func resultRow(_ result: IPTVOrgLogoResult) -> some View {
        Button {
            apply(url: result.logoURL)
        } label: {
            HStack(spacing: 14) {
                AsyncImage(url: result.logoURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        Color.white.opacity(0.06)
                    }
                }
                .frame(width: 54, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.channelName).foregroundStyle(.primary)
                    if let subtitle = resultSubtitle(result) {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
        }
    }

    private func resultSubtitle(_ result: IPTVOrgLogoResult) -> String? {
        switch (result.country, result.source) {
        case (let country?, let source):
            return "\(country) · \(source)"
        case (nil, let source):
            return source
        }
    }

    private func applyCustomURL() {
        let trimmed = customURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.host != nil else { return }
        apply(url: url)
    }

    private func apply(url: URL) {
        ChannelLogoOverrideStore.setLogoURL(url, forChannelID: channelID)
        onSaved()
        dismiss()
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }

        isSearching = true
        searchError = nil
        defer { isSearching = false }

        // Beide bronnen apart afvangen i.p.v. één gezamenlijke throw: als
        // er maar één van de twee databases bereikbaar is, tonen we die
        // resultaten gewoon, i.p.v. helemaal niets te tonen.
        async let iptvOrgResults = try? IPTVOrgLogoDirectory.shared.search(query: trimmed)
        async let tvLogosResults = try? TVLogoRepoDirectory.shared.search(query: trimmed)
        let (fromIPTVOrg, fromTVLogos) = await (iptvOrgResults, tvLogosResults)

        if fromIPTVOrg == nil, fromTVLogos == nil {
            results = []
            searchError = "Kon de logo-databases niet bereiken. Controleer de internetverbinding."
        } else {
            results = ((fromIPTVOrg ?? []) + (fromTVLogos ?? [])).sorted { $0.channelName < $1.channelName }
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        isImportingPhoto = true
        photoError = nil
        defer { isImportingPhoto = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                photoError = "Kon de gekozen foto niet laden."
                return
            }
            guard let fileURL = ChannelLogoOverrideStore.saveLocalLogo(data, forChannelID: channelID) else {
                photoError = "Opslaan van de foto is niet gelukt."
                return
            }
            apply(url: fileURL)
        } catch {
            photoError = "Kon de gekozen foto niet laden."
        }
    }
}

#Preview {
    ChannelLogoPickerView(channelID: "preview", channelName: "BBC One", currentOverrideURL: nil, currentNameOverride: nil)
}
