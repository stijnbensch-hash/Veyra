import SwiftUI

struct IPTVSetupView: View {
    private enum SetupType: String, CaseIterable, Identifiable {
        case xtream = "Xtream"
        case m3u = "M3U"
        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss

    private let providerID: UUID?
    private let createsNewProvider: Bool

    @State private var setupType: SetupType = .xtream
    @State private var displayName = ""
    @State private var serverAddress = ""
    @State private var username = ""
    @State private var password = ""
    @State private var playlistAddress = ""
    @State private var isSaving = false
    @State private var hasLoadedConfiguration = false
    @State private var errorMessage: String?

    private let configurationStore = IPTVConfigurationStore()

    init(providerID: UUID? = nil, createsNewProvider: Bool = false) {
        self.providerID = providerID
        self.createsNewProvider = createsNewProvider
    }

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            Form {
            Section {
                Picker("Type", selection: $setupType) {
                    ForEach(SetupType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Naam (bijv. Mijn IPTV)", text: $displayName)
                    .textInputAutocapitalization(.words)
            }

            if setupType == .xtream {
                Section {
                    TextField("https://provider.example.com:1234", text: $serverAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Gebruikersnaam", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Wachtwoord", text: $password)
                } header: {
                    Text("Server")
                } footer: {
                    Text("Veyra bouwt de Xtream API- en stream-URL's zelf op vanaf het serveradres.")
                }
            } else {
                Section {
                    TextField("https://provider.example.com/playlist.m3u", text: $playlistAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("M3U playlist")
                } footer: {
                    Text("De volledige M3U-URL wordt veilig in de sleutelhanger bewaard.")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(providerID == nil && createsNewProvider ? "Bron toevoegen" : "Bron bewerken")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuleren") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Opslaan") { saveConfiguration() }
                }
            }
        }
        .onAppear { loadExistingConfiguration() }
    }

    private func saveConfiguration() {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            let configuration = try makeConfiguration()

            if createsNewProvider {
                try configurationStore.addProvider(configuration)
            } else if let providerID {
                try configurationStore.updateProvider(id: providerID, configuration: configuration)
            } else {
                try configurationStore.save(configuration)
            }

            NotificationCenter.default.post(name: .iptvConfigurationDidChange, object: nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeConfiguration() throws -> IPTVStoredConfiguration {
        switch setupType {
        case .xtream:
            return try makeXtreamConfiguration()
        case .m3u:
            return try makeM3UConfiguration()
        }
    }

    private func makeXtreamConfiguration() throws -> IPTVStoredConfiguration {
        let name = try validatedDisplayName()

        guard let serverURL = httpURL(from: serverAddress) else {
            throw IPTVSetupError.invalidServerURL
        }

        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty else { throw IPTVSetupError.missingUsername }
        guard !trimmedPassword.isEmpty else { throw IPTVSetupError.missingPassword }

        return .xtream(
            XtreamConfiguration(
                displayName: name,
                serverURL: serverURL,
                username: trimmedUsername,
                password: trimmedPassword
            )
        )
    }

    private func makeM3UConfiguration() throws -> IPTVStoredConfiguration {
        let name = try validatedDisplayName()

        guard let playlistURL = httpURL(from: playlistAddress) else {
            throw IPTVSetupError.invalidPlaylistURL
        }

        return .m3u(M3UConfiguration(displayName: name, playlistURL: playlistURL))
    }

    private func validatedDisplayName() throws -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw IPTVSetupError.missingDisplayName }
        return trimmed
    }

    private func loadExistingConfiguration() {
        guard !hasLoadedConfiguration else { return }
        hasLoadedConfiguration = true

        if createsNewProvider { return }

        do {
            let configuration: IPTVStoredConfiguration?

            if let providerID {
                configuration = try configurationStore.loadProvider(id: providerID)?.configuration
            } else {
                configuration = try configurationStore.load()
            }

            guard let configuration else { return }

            populateFields(from: configuration)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func populateFields(from configuration: IPTVStoredConfiguration) {
        switch configuration {
        case .xtream(let configuration):
            setupType = .xtream
            displayName = configuration.displayName
            serverAddress = configuration.serverURL.absoluteString
            username = configuration.username
            password = configuration.password

        case .m3u(let configuration):
            setupType = .m3u
            displayName = configuration.displayName
            playlistAddress = configuration.playlistURL.absoluteString
        }
    }

    private func httpURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            var components = URLComponents(string: trimmed),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            components.host != nil
        else {
            return nil
        }

        components.fragment = nil
        return components.url
    }
}

private enum IPTVSetupError: LocalizedError {
    case missingDisplayName
    case invalidServerURL
    case invalidPlaylistURL
    case missingUsername
    case missingPassword

    var errorDescription: String? {
        switch self {
        case .missingDisplayName: return "Geef deze IPTV-provider een naam."
        case .invalidServerURL: return "Voer een geldig Xtream-serveradres in."
        case .invalidPlaylistURL: return "Voer een geldige M3U-URL in."
        case .missingUsername: return "Voer je Xtream-gebruikersnaam in."
        case .missingPassword: return "Voer je Xtream-wachtwoord in."
        }
    }
}

#Preview {
    NavigationStack { IPTVSetupView(createsNewProvider: true) }
}
