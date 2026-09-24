// VeyraBentoFanartCard.swift — gedeeld (tvOS + iOS)
// Invoerveld voor de fanart.tv API-sleutel (Instellingen > Account). De sleutel staat in de sleutelhanger
// en zet echte banners aan in de kleine "Verder kijken"-kaartjes op Home.

import SwiftUI

struct FanartConfigurationCard: View {
    @State private var apiKey = ""
    @State private var configured = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(VeyraColors.cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text("fanart.tv")
                    Text("Brede banners voor Verder kijken")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(configured ? "Ingesteld" : "Optioneel")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(configured ? VeyraColors.cyan : .secondary)
            }

            Text("Persoonlijke API-sleutel van fanart.tv (gratis, te vinden op fanart.tv/get-an-api-key). Zonder sleutel gebruikt Veyra de TMDB-achtergrond.")
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField(configured ? "Nieuwe fanart.tv API-sleutel" : "fanart.tv API-sleutel", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Opslaan") { save() }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if configured {
                Button("Sleutel verwijderen", role: .destructive) { remove() }
            }

            if let message {
                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(configured ? VeyraColors.cyan : .orange)
            }
        }
        .padding(.vertical, 6)
        .onAppear { configured = AppConfiguration.fanartAPIKey != nil }
    }

    private func save() {
        let value = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        do {
            try AppConfiguration.setFanartAPIKey(value)
            apiKey = ""
            configured = AppConfiguration.fanartAPIKey != nil
            message = configured ? "Sleutel veilig opgeslagen. Herstart Veyra om de banners te laden." : "De sleutel kon niet worden opgeslagen."
        } catch {
            configured = AppConfiguration.fanartAPIKey != nil
            message = "Opslaan van de sleutel is niet gelukt."
        }
    }

    private func remove() {
        do {
            try AppConfiguration.setFanartAPIKey(nil)
            configured = AppConfiguration.fanartAPIKey != nil
            message = configured ? "De sleutel kon niet worden verwijderd." : "Sleutel verwijderd."
        } catch {
            message = "Verwijderen van de sleutel is niet gelukt."
        }
    }
}
