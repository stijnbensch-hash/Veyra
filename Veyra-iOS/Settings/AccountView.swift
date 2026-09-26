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
                    NavigationLink("Taal en ondertitelvoorkeuren") {
                        SubtitlePreferencesView()
                    }
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
                    TraktConfigurationCard()
                } header: {
                    Text("Trakt API-sleutels")
                } footer: {
                    Text("Alleen nodig om zelf een Trakt-koppeling mogelijk te maken — dezelfde sleutels als op je andere Veyra-toestellen.")
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

private struct TraktConfigurationCard: View {
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var configured = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(VeyraColors.cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Trakt")
                    Text("Nodig om je Trakt-account te kunnen koppelen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(configured ? "Ingesteld" : "Sleutels nodig")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(configured ? VeyraColors.cyan : .red)
            }

            Text("Dezelfde Trakt Client ID en Client Secret als op je andere Veyra-toestellen (te vinden in je Trakt API-app op trakt.tv/oauth/applications).")
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField(configured ? "Nieuwe Trakt Client ID" : "Trakt Client ID", text: $clientID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField(configured ? "Nieuw Trakt Client Secret" : "Trakt Client Secret", text: $clientSecret)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Opslaan") { save() }
                .disabled(
                    clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

            if let message {
                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(configured ? VeyraColors.cyan : .orange)
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            configured = AppConfiguration.traktClientID != nil && AppConfiguration.traktClientSecret != nil
        }
    }

    private func save() {
        let id = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !secret.isEmpty else { return }

        do {
            try AppConfiguration.setTraktClientID(id)
            try AppConfiguration.setTraktClientSecret(secret)
            clientID = ""
            clientSecret = ""
            configured = AppConfiguration.traktClientID != nil && AppConfiguration.traktClientSecret != nil
            message = configured ? "Sleutels veilig opgeslagen. Koppel nu je Trakt-account bij Instellingen." : "De sleutels konden niet worden opgeslagen."
        } catch {
            configured = AppConfiguration.traktClientID != nil && AppConfiguration.traktClientSecret != nil
            message = "Opslaan van de sleutels is niet gelukt."
        }
    }
}

#Preview {
    NavigationStack { AccountView() }
}
