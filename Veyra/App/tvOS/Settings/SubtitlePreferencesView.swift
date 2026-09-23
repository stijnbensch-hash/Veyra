import SwiftUI

struct SubtitlePreferencesView: View {
    @AppStorage(SubtitlePreferences.languageKey) private var language = "nl"

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    ForEach(SubtitleLanguage.allCases) { option in
                        Button {
                            language = option.rawValue
                        } label: {
                            HStack {
                                Text(option.title)
                                Spacer()
                                if language == option.rawValue {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Standaardtaal")
                } footer: {
                    Text("De speler kiest deze taal bij een nieuwe stream. Tijdens het kijken kun je altijd een ander beschikbaar spoor kiezen of ondertitels uitzetten.")
                }

                Section {
                    OpenSubtitlesConfigurationCard()
                } header: {
                    Text("OpenSubtitles")
                }
            }
            .frame(maxWidth: 1000)
        }
        .navigationTitle("Ondertitels")
    }
}

struct OpenSubtitlesConfigurationCard: View {
    @AppStorage("openSubtitlesEnabled")
    private var enabled = false

    @State
    private var apiKey = ""

    @State
    private var configured = false

    @State
    private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "captions.bubble.fill")
                    .foregroundStyle(VeyraColors.cyan)

                VStack(alignment: .leading, spacing: 3) {
                    Text("OpenSubtitles")
                    Text("Online ondertitels voor films en afleveringen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VeyraPosterBadge(
                    title: configured ? (enabled ? "Actief" : "Ingesteld") : "API-sleutel nodig",
                    symbol: configured ? "checkmark.circle.fill" : "key.fill",
                    accent: configured ? VeyraColors.cyan : VeyraColors.red,
                    fontSize: 13
                )
            }

            Toggle("Online ondertitels gebruiken", isOn: $enabled)
                .disabled(!configured)

            Text("Veyra zoekt hiermee ondertitels in je standaardtaal wanneer een stream die taal niet bevat. Vanuit de speler kun je ook handmatig zoeken. OpenSubtitles ontvangt hiervoor de IMDb-identificatie en, bij series, het seizoen en afleveringsnummer.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("De API-sleutel wordt lokaal in de beveiligde sleutelhanger van deze Apple TV opgeslagen.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.52))

            SecureField(
                configured
                    ? "Nieuwe OpenSubtitles API-sleutel"
                    : "OpenSubtitles API-sleutel",
                text: $apiKey
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {
                saveAPIKey()
            } label: {
                Label("Opslaan en inschakelen", systemImage: "key.fill")
            }
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(configured ? VeyraColors.ice : .orange)
            }
        }
        .onAppear {
            configured = AppConfiguration.openSubtitlesAPIKey != nil
        }
    }

    private func saveAPIKey() {
        let value = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        do {
            try AppConfiguration.setOpenSubtitlesAPIKey(value)
            apiKey = ""
            configured = AppConfiguration.openSubtitlesAPIKey != nil
            enabled = configured
            message = configured
                ? "API-sleutel veilig opgeslagen. OpenSubtitles is ingeschakeld."
                : "De API-sleutel kon niet worden gecontroleerd."
        } catch {
            configured = AppConfiguration.openSubtitlesAPIKey != nil
            message = "Opslaan van de API-sleutel is niet gelukt."
        }
    }
}

#Preview {
    NavigationStack { SubtitlePreferencesView() }
}
