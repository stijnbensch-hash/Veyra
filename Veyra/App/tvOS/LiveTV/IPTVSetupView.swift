import SwiftUI

extension Notification.Name {
    static let iptvConfigurationDidChange =
        Notification.Name(
            "veyra.iptv.configurationDidChange"
        )
}

struct IPTVSetupView: View {
    private enum SetupType: String, CaseIterable, Identifiable {
        case xtream = "XTREAM"
        case m3u = "M3U"

        var id: Self {
            self
        }
    }

    @Environment(\.dismiss)
    private var dismiss

    private let providerID: UUID?
    private let createsNewProvider: Bool

    @State private var setupType: SetupType = .xtream

    @State private var displayName = ""

    @State private var serverAddress = ""
    @State private var username = ""
    @State private var password = ""

    @State private var playlistAddress = ""

    @State private var isSaving = false
    @State private var hasExistingConfiguration = false
    @State private var hasLoadedConfiguration = false
    @State private var errorMessage: String?

    private let configurationStore =
        IPTVConfigurationStore()

    init(
        providerID: UUID? = nil,
        createsNewProvider: Bool = false
    ) {
        self.providerID = providerID
        self.createsNewProvider = createsNewProvider
    }

    var body: some View {
        ZStack {
            VeyraBackground()
            .ignoresSafeArea()

            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 32
                ) {
                    header

                    sourcePicker

                    nameField

                    if setupType == .xtream {
                        xtreamFields
                    } else {
                        m3uFields
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.body)
                            .foregroundStyle(.red)
                    }

                    saveButton
                }
                .frame(maxWidth: 900)
                .padding(.horizontal, VeyraSpacing.page)
                .padding(.top, 36)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            loadExistingConfiguration()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("IPTV")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(
                hasExistingConfiguration
                    ? "BRON BEWERKEN"
                    : "BRON TOEVOEGEN"
            )
            .font(.caption)
            .tracking(3)
            .foregroundStyle(
                .cyan.opacity(0.75)
            )

            Text(
                hasExistingConfiguration
                    ? "Wijzig deze IPTV-provider."
                    : "Voeg een IPTV-provider toe via Xtream of M3U."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
    }

    // MARK: - Source Type

    private var sourcePicker: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("TYPE")
                .font(.caption)
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.75)
                )

            // .segmented: deze rij wordt direct gevolgd door xtreamFields/
            // m3uFields, die in-/uitklappen op basis van setupType zelf. Zie
            // de zelfde fix + toelichting in MetadataSettingsView.swift.
            Picker(
                "IPTV-type",
                selection: $setupType
            ) {
                ForEach(
                    SetupType.allCases
                ) { type in
                    Text(type.rawValue)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Name

    private var nameField: some View {
        inputSection(
            title: "NAAM"
        ) {
            TextField(
                "Bijvoorbeeld Mijn IPTV",
                text: $displayName
            )
        }
    }

    // MARK: - Xtream

    private var xtreamFields: some View {
        VStack(
            alignment: .leading,
            spacing: 24
        ) {
            inputSection(
                title: "SERVER"
            ) {
                TextField(
                    "https://provider.example.com:1234",
                    text: $serverAddress
                )
            }

            inputSection(
                title: "GEBRUIKERSNAAM"
            ) {
                TextField(
                    "Gebruikersnaam",
                    text: $username
                )
            }

            inputSection(
                title: "WACHTWOORD"
            ) {
                SecureField(
                    "Wachtwoord",
                    text: $password
                )
            }

            Text(
                "Gebruik alleen het serveradres. Veyra bouwt de Xtream API- en stream-URL's zelf op."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - M3U

    private var m3uFields: some View {
        VStack(
            alignment: .leading,
            spacing: 24
        ) {
            inputSection(
                title: "M3U PLAYLIST"
            ) {
                TextField(
                    "https://provider.example.com/playlist.m3u",
                    text: $playlistAddress
                )
            }

            Text(
                "De volledige M3U-URL wordt veilig in de Keychain bewaard."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Input

    private func inputSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(title)
                .font(.caption)
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.75)
                )

            content()
                .font(.title3)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveConfiguration()
        } label: {
            HStack(spacing: 12) {
                if isSaving {
                    ProgressView()
                }

                Text(
                    isSaving
                        ? "OPSLAAN…"
                        : "OPSLAAN"
                )
                .fontWeight(.semibold)
            }
            .frame(minWidth: 220)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSaving)
        .padding(.top, 8)
    }

    // MARK: - Save

    private func saveConfiguration() {
        errorMessage = nil
        isSaving = true

        defer {
            isSaving = false
        }

        do {
            let configuration =
                try makeConfiguration()

            if createsNewProvider {
                try configurationStore
                    .addProvider(
                        configuration
                    )
            } else if let providerID {
                try configurationStore
                    .updateProvider(
                        id: providerID,
                        configuration:
                            configuration
                    )
            } else {
                try configurationStore.save(
                    configuration
                )
            }

            NotificationCenter.default.post(
                name: .iptvConfigurationDidChange,
                object: nil
            )

            dismiss()
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    private func makeConfiguration()
        throws -> IPTVStoredConfiguration
    {
        switch setupType {
        case .xtream:
            return try makeXtreamConfiguration()

        case .m3u:
            return try makeM3UConfiguration()
        }
    }

    private func makeXtreamConfiguration()
        throws -> IPTVStoredConfiguration
    {
        let name =
            try validatedDisplayName()

        guard
            let serverURL =
                httpURL(
                    from: serverAddress
                )
        else {
            throw IPTVSetupError
                .invalidServerURL
        }

        let trimmedUsername =
            username.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let trimmedPassword =
            password.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmedUsername.isEmpty else {
            throw IPTVSetupError
                .missingUsername
        }

        guard !trimmedPassword.isEmpty else {
            throw IPTVSetupError
                .missingPassword
        }

        return .xtream(
            XtreamConfiguration(
                displayName: name,
                serverURL: serverURL,
                username: trimmedUsername,
                password: trimmedPassword
            )
        )
    }

    private func makeM3UConfiguration()
        throws -> IPTVStoredConfiguration
    {
        let name =
            try validatedDisplayName()

        guard
            let playlistURL =
                httpURL(
                    from: playlistAddress
                )
        else {
            throw IPTVSetupError
                .invalidPlaylistURL
        }

        return .m3u(
            M3UConfiguration(
                displayName: name,
                playlistURL: playlistURL
            )
        )
    }

    private func validatedDisplayName()
        throws -> String
    {
        let trimmed =
            displayName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmed.isEmpty else {
            throw IPTVSetupError
                .missingDisplayName
        }

        return trimmed
    }

    // MARK: - Existing Configuration

    private func loadExistingConfiguration() {
        guard !hasLoadedConfiguration else {
            return
        }

        hasLoadedConfiguration = true

        if createsNewProvider {
            hasExistingConfiguration = false
            return
        }

        do {
            let configuration:
                IPTVStoredConfiguration?

            if let providerID {
                configuration =
                    try configurationStore
                        .loadProvider(
                            id: providerID
                        )?
                        .configuration
            } else {
                configuration =
                    try configurationStore.load()
            }

            guard let configuration else {
                hasExistingConfiguration = false
                return
            }

            hasExistingConfiguration = true

            populateFields(
                from: configuration
            )

            errorMessage = nil
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    private func populateFields(
        from configuration:
            IPTVStoredConfiguration
    ) {
        switch configuration {
        case .xtream(let configuration):
            setupType = .xtream

            displayName =
                configuration.displayName

            serverAddress =
                configuration
                    .serverURL
                    .absoluteString

            username =
                configuration.username

            password =
                configuration.password

            playlistAddress = ""

        case .m3u(let configuration):
            setupType = .m3u

            displayName =
                configuration.displayName

            playlistAddress =
                configuration
                    .playlistURL
                    .absoluteString

            serverAddress = ""
            username = ""
            password = ""
        }
    }

    // MARK: - URL Validation

    private func httpURL(
        from value: String
    ) -> URL? {
        let trimmed =
            value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            var components =
                URLComponents(
                    string: trimmed
                ),
            let scheme =
                components.scheme?
                    .lowercased(),
            scheme == "http" ||
                scheme == "https",
            components.host != nil
        else {
            return nil
        }

        components.fragment = nil

        return components.url
    }
}

enum IPTVSetupError: LocalizedError {
    case missingDisplayName
    case invalidServerURL
    case invalidPlaylistURL
    case missingUsername
    case missingPassword

    var errorDescription: String? {
        switch self {
        case .missingDisplayName:
            return
                "Geef deze IPTV-provider een naam."

        case .invalidServerURL:
            return
                "Voer een geldig Xtream-serveradres in."

        case .invalidPlaylistURL:
            return
                "Voer een geldige M3U-URL in."

        case .missingUsername:
            return
                "Voer je Xtream-gebruikersnaam in."

        case .missingPassword:
            return
                "Voer je Xtream-wachtwoord in."
        }
    }
}

#Preview {
    IPTVSetupView(
        createsNewProvider: true
    )
}
