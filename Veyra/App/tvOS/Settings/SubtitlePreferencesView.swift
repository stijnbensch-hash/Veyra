import SwiftUI

struct SubtitlePreferencesView: View {
    @AppStorage(SubtitlePreferences.languageKey) private var language = "nl"

    var body: some View {
        ZStack {
            VeyraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Ondertitels").font(VeyraTypography.hero)
                    Text("Standaardtaal").font(VeyraTypography.section)
                    Text("De speler kiest deze taal bij een nieuwe stream. Tijdens het kijken kun je altijd een ander beschikbaar spoor kiezen of ondertitels uitzetten.")
                        .foregroundStyle(VeyraColors.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 270))], spacing: 18) {
                        ForEach(SubtitleLanguage.allCases) { option in
                            Button { language = option.rawValue } label: {
                                HStack {
                                    Text(option.title)
                                    Spacer()
                                    if language == option.rawValue { Image(systemName: "checkmark") }
                                }.padding(20)
                            }.buttonStyle(VeyraFocusButtonStyle())
                        }
                    }
                    OpenSubtitlesConfigurationCard()
                }.font(.system(size: 24)).frame(maxWidth: 1400).padding(60)
            }
        }
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
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 18) {
                Image(systemName: "captions.bubble.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(VeyraColors.cyan)

                VStack(alignment: .leading, spacing: 5) {
                    Text("OpenSubtitles")
                        .font(VeyraTypography.section)

                    Text("Online ondertitels voor films en afleveringen")
                        .font(.system(size: 19))
                        .foregroundStyle(VeyraColors.secondary)
                }

                Spacer()

                VeyraPosterBadge(
                    title: configured ? (enabled ? "Actief" : "Ingesteld") : "API-sleutel nodig",
                    symbol: configured ? "checkmark.circle.fill" : "key.fill",
                    accent: configured ? VeyraColors.cyan : VeyraColors.red,
                    fontSize: 14
                )
            }

            Toggle("Online ondertitels gebruiken", isOn: $enabled)
                .disabled(!configured)

            Text("Veyra zoekt hiermee ondertitels in je standaardtaal wanneer een stream die taal niet bevat. Vanuit de speler kun je ook handmatig zoeken. OpenSubtitles ontvangt hiervoor de IMDb-identificatie en, bij series, het seizoen en afleveringsnummer.")
                .foregroundStyle(VeyraColors.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("De API-sleutel wordt lokaal in de beveiligde sleutelhanger van deze Apple TV opgeslagen.")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.52))

            HStack(spacing: 18) {
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
                    Label(
                        "Opslaan en inschakelen",
                        systemImage: "key.fill"
                    )
                    .font(.system(size: 21, weight: .bold))
                    .padding(.horizontal, 22)
                    .frame(height: 60)
                }
                .buttonStyle(
                    VeyraFocusButtonStyle(primary: true)
                )
                .disabled(
                    apiKey.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )
            }

            if let message {
                Text(message)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(
                        configured
                            ? VeyraColors.ice
                            : .orange
                    )
            }
        }
        .padding(30)
        .veyraGlass()
        .onAppear {
            configured =
                AppConfiguration
                    .openSubtitlesAPIKey
                != nil
        }
    }

    private func saveAPIKey() {
        let value =
            apiKey.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !value.isEmpty else {
            return
        }

        do {
            try AppConfiguration
                .setOpenSubtitlesAPIKey(
                    value
                )

            apiKey = ""
            configured =
                AppConfiguration
                    .openSubtitlesAPIKey
                != nil

            enabled = configured

            message = configured
                ? "API-sleutel veilig opgeslagen. OpenSubtitles is ingeschakeld."
                : "De API-sleutel kon niet worden gecontroleerd."

        } catch {
            configured =
                AppConfiguration
                    .openSubtitlesAPIKey
                != nil
            message =
                "Opslaan van de API-sleutel is niet gelukt."
        }
    }
}
