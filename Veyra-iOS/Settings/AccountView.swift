import SwiftUI

struct AccountView: View {
    @ObservedObject private var trakt = TraktStore.shared

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
                Section {
                    Text("Beheer je profiel, koppelingen en API-sleutels.")
                        .foregroundStyle(.secondary)
                }

                Section("Trakt-account") {
                    NavigationLink {
                        TraktSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(VeyraColors.cyan)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Trakt")
                                Text("Kijkgeschiedenis, voortgang en lijsten")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(trakt.isConnected ? "Verbonden" : "Niet gekoppeld")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(trakt.isConnected ? VeyraColors.cyan : .secondary)
                        }
                    }
                }

                Section("Ondertitels") {
                    OpenSubtitlesConfigurationCard()
                }

                Section {
                    TMDBConfigurationCard()
                } header: {
                    Text("TMDB")
                } footer: {
                    Text("Nodig voor filmposters, series en metadata in Veyra.")
                }

                Section {
                    FanartConfigurationCard()
                } header: {
                    Text("fanart.tv")
                } footer: {
                    Text("Optioneel: echte banners in de kleine Verder kijken-kaartjes op Home.")
                }

                Section {
                    MDBListConfigurationCard()
                } header: {
                    Text("MDBList")
                } footer: {
                    Text("Popcornmeter en Letterboxd komen via MDBList (mdblist.com). Vul hier een gratis API-sleutel in om die twee scores te tonen bij Instellingen → Metadata → Ratings.")
                }

            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Account")
    }
}

private struct TMDBConfigurationCard: View {
    @State private var apiKey = ""
    @State private var configured = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "film.stack")
                    .foregroundStyle(VeyraColors.cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text("TMDB")
                    Text("Filmposters, series en metadata")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(configured ? "Ingesteld" : "Sleutel nodig")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(configured ? VeyraColors.cyan : .red)
            }

            SecureField(configured ? "Nieuwe TMDB read access token" : "TMDB read access token", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Opslaan") { save() }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let message {
                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(configured ? VeyraColors.cyan : .orange)
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            configured = AppConfiguration.tmdbReadAccessToken != nil
        }
    }

    private func save() {
        let value = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        do {
            try AppConfiguration.setTMDBReadAccessToken(value)
            apiKey = ""
            configured = AppConfiguration.tmdbReadAccessToken != nil
            message = configured ? "Sleutel veilig opgeslagen." : "De sleutel kon niet worden opgeslagen."
        } catch {
            configured = AppConfiguration.tmdbReadAccessToken != nil
            message = "Opslaan van de sleutel is niet gelukt."
        }
    }
}

#Preview {
    NavigationStack { AccountView() }
}
