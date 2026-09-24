import SwiftUI

/// tvOS-scherm om het logo én de naam van één zender aan te passen —
/// bereikbaar door lang op een zenderlogo te drukken (contextmenu:
/// "Logo/naam aanpassen…") in `LiveTVView` en `IPTVLiveManagementView`.
///
/// Vier duidelijk gescheiden groepen, elk met een eigen icoon in de
/// koptekst: Naam, Logo (met de terugzetknop er meteen bij, niet los
/// onderaan het scherm), Zoeken in de logo-database, en Eigen logo-URL. Er
/// is op tvOS bewust geen fotobibliotheek-optie (PhotosPicker bestaat niet
/// op tvOS) — die staat wel op iOS. Beide keuzes worden opgeslagen via
/// `ChannelLogoOverrideStore`/`ChannelNameOverrideStore` en gelden overal
/// waar deze zender voorkomt.
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
                VeyraBackground().ignoresSafeArea()

                List {
                    nameSection
                    logoSection
                    searchSection
                    customURLSection
                }
                .frame(maxWidth: 1000)
            }
            .navigationTitle(currentNameOverride ?? channelName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten") { dismiss() }
                }
            }
        }
    }

    // MARK: - Naam

    private var nameSection: some View {
        Section {
            VeyraSettingsCardRowLabel(icon: "textformat", title: "Zendernaam") {
                TextField("Zendernaam", text: $nameText)
                    .multilineTextAlignment(.trailing)
            }

            Button {
                saveName()
            } label: {
                VeyraSettingsCardRowLabel(icon: "checkmark.circle", title: "Naam opslaan")
            }
            .veyraCardRow()
            .disabled(isNameUnchanged || trimmedName.isEmpty)

            if currentNameOverride != nil {
                Button(role: .destructive) {
                    ChannelNameOverrideStore.removeOverride(forChannelID: channelID)
                    nameText = channelName
                    onSaved()
                } label: {
                    VeyraSettingsCardRowLabel(icon: "arrow.uturn.backward", title: "Terugzetten naar origineel")
                }
                .veyraCardRow()
            }
        } header: {
            Label("Naam", systemImage: "textformat")
        }
    }

    // MARK: - Logo

    private var logoSection: some View {
        Section {
            currentLogoPreview

            if currentOverrideURL != nil {
                Button(role: .destructive) {
                    ChannelLogoOverrideStore.removeOverride(forChannelID: channelID)
                    onSaved()
                } label: {
                    VeyraSettingsCardRowLabel(icon: "arrow.uturn.backward", title: "Terugzetten naar standaardlogo")
                }
                .veyraCardRow()
            }
        } header: {
            Label("Logo", systemImage: "photo")
        }
    }

    private var currentLogoPreview: some View {
        AsyncImage(url: currentOverrideURL) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFit()
            } else {
                Image(systemName: "tv").foregroundStyle(.secondary)
            }
        }
        .frame(width: 90, height: 60)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Zoeken

    private var searchSection: some View {
        Section {
            VeyraSettingsCardRowLabel(icon: "magnifyingglass", title: "Zoeken") {
                TextField("bv. \"BBC One\"", text: $query)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { Task { await search() } }
            }

            if isSearching {
                HStack(spacing: 12) {
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
            Label("Zoeken in logo-databases (iptv-org + tv-logos)", systemImage: "magnifyingglass")
        }
    }

    private func resultRow(_ result: IPTVOrgLogoResult) -> some View {
        Button {
            apply(url: result.logoURL)
        } label: {
            HStack(spacing: 16) {
                AsyncImage(url: result.logoURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        Color.white.opacity(0.06)
                    }
                }
                .frame(width: 70, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.channelName)
                    if let subtitle = resultSubtitle(result) {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .veyraCardRow()
    }

    private func resultSubtitle(_ result: IPTVOrgLogoResult) -> String? {
        switch (result.country, result.source) {
        case (let country?, let source):
            return "\(country) · \(source)"
        case (nil, let source):
            return source
        }
    }

    // MARK: - Eigen URL

    private var customURLSection: some View {
        Section {
            VeyraSettingsCardRowLabel(icon: "link", title: "Logo-URL") {
                TextField("https://…/logo.png", text: $customURLString)
                    .multilineTextAlignment(.trailing)
            }

            Button {
                applyCustomURL()
            } label: {
                VeyraSettingsCardRowLabel(icon: "checkmark.circle", title: "Eigen URL gebruiken")
            }
            .veyraCardRow()
            .disabled(URL(string: customURLString.trimmingCharacters(in: .whitespaces))?.host == nil)
        } header: {
            Label("Eigen logo-URL", systemImage: "link")
        }
    }

    // MARK: - Naam-acties

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

    // MARK: - Logo-acties

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
}

#Preview {
    ChannelLogoPickerView(channelID: "preview", channelName: "BBC One", currentOverrideURL: nil, currentNameOverride: nil)
}
