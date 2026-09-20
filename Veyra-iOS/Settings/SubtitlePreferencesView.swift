import SwiftUI

struct SubtitlePreferencesView: View {
    @AppStorage(SubtitlePreferences.languageKey) private var language = "nl"

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
            Section {
                ForEach(SubtitleLanguage.allCases) { option in
                    Button {
                        language = option.rawValue
                    } label: {
                        HStack {
                            Text(option.title).foregroundStyle(.primary)
                            Spacer()
                            if language == option.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(VeyraColors.cyan)
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
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Ondertitels")
    }
}

struct OpenSubtitlesConfigurationCard: View {
    @AppStorage("openSubtitlesEnabled") private var enabled = false

    @State private var apiKey = ""
    @State private var configured = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "captions.bubble.fill")
                    .foregroundStyle(VeyraColors.cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text("OpenSubtitles")
                    Text("Online ondertitels voor films en afleveringen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(configured ? (enabled ? "Actief" : "Ingesteld") : "API-sleutel nodig")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(configured ? VeyraColors.cyan : .red)
            }

            Toggle("Online ondertitels gebruiken", isOn: $enabled)
                .disabled(!configured)

            Text("De API-sleutel wordt lokaal in de beveiligde sleutelhanger van dit toestel opgeslagen.")
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField(configured ? "Nieuwe OpenSubtitles API-sleutel" : "OpenSubtitles API-sleutel", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Opslaan en inschakelen") {
                saveAPIKey()
            }
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let message {
                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(configured ? VeyraColors.cyan : .orange)
            }
        }
        .padding(.vertical, 6)
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
