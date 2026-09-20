import SwiftUI

/// tvOS-scherm om het logo van één zender aan te passen — bereikbaar door
/// lang op een zenderlogo te drukken (contextmenu: "Logo aanpassen…") in
/// `LiveTVView` en `IPTVLiveManagementView`.
///
/// Twee bronnen: zoeken in de gratis iptv-org logo-database
/// (`IPTVOrgLogoDirectory`), of zelf een afbeeldings-URL opgeven. Er is op
/// tvOS bewust geen fotobibliotheek-optie (PhotosPicker bestaat niet op
/// tvOS) — die staat wel op iOS. De keuze wordt opgeslagen via
/// `ChannelLogoOverrideStore` en geldt overal waar deze zender voorkomt.
struct ChannelLogoPickerView: View {
    let channelID: String
    let channelName: String
    let currentOverrideURL: URL?

    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [IPTVOrgLogoResult] = []
    @State private var isSearching = false
    @State private var searchError: String?

    @State private var customURLString = ""

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraBackground().ignoresSafeArea()

                List {
                    Section {
                        currentLogoPreview
                    } header: {
                        Text("Huidig logo")
                    }

                    Section {
                        TextField("Zoek zendernaam (bv. \"BBC One\")", text: $query)
                            .onSubmit { Task { await search() } }

                        if isSearching {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("Zoeken in iptv-org…").foregroundStyle(.secondary)
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
                        Text("Zoeken in logo-database (iptv-org)")
                    } footer: {
                        Text("Gratis, doorzoekbare verzameling zenderlogo's van het open-source iptv-org-project.")
                    }

                    Section {
                        TextField("https://…/logo.png", text: $customURLString)
                        Button("Eigen URL gebruiken") {
                            applyCustomURL()
                        }
                        .disabled(URL(string: customURLString.trimmingCharacters(in: .whitespaces))?.host == nil)
                    } header: {
                        Text("Eigen logo-URL")
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
            }
            .navigationTitle(channelName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten") { dismiss() }
                }
            }
        }
    }

    private var currentLogoPreview: some View {
        HStack(spacing: 20) {
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

            Text(currentOverrideURL == nil ? "Standaardlogo van de provider/EPG." : "Eigen logo ingesteld.")
                .foregroundStyle(.secondary)
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
                    if let country = result.country {
                        Text(country).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
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

        do {
            results = try await IPTVOrgLogoDirectory.shared.search(query: trimmed)
        } catch {
            results = []
            searchError = "Kon de logo-database niet bereiken. Controleer de internetverbinding."
        }
    }
}

#Preview {
    ChannelLogoPickerView(channelID: "preview", channelName: "BBC One", currentOverrideURL: nil)
}
