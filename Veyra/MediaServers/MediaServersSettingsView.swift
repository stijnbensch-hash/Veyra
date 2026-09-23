import SwiftUI

// MARK: - Media servers overview

@MainActor
struct MediaServersSettingsView:
    View
{
    @State private var selectedServer:
        MediaServerAccount?

    @State private var pendingDeleteServer:
        MediaServerAccount?

    @State private var showAddServer =
        false

    @FocusState
    private var focusedServerID:
        UUID?

    @FocusState
    private var focusedDeleteServerID:
        UUID?

    @FocusState
    private var addButtonFocused:
        Bool

    @StateObject private var viewModel = MediaServersViewModel()

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 32
                ) {
                    header
                    addServerButton
                    existingServersSection
                }
                .frame(
                    maxWidth: 1180,
                    alignment: .leading
                )
                .padding(.horizontal, 70)
                .padding(.top, 50)
                .padding(.bottom, 70)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            viewModel.reload()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .veyraMediaServerConfigurationDidChange
            )
        ) { _ in
            viewModel.reload()
        }
        .navigationDestination(
            item: $selectedServer
        ) { server in
            MediaServerEditView(server: server)
        }
        .navigationDestination(
            isPresented: $showAddServer
        ) {
            MediaServerAddView()
        }
        .confirmationDialog(
            "Mediaserver verwijderen?",
            isPresented: deleteDialogBinding,
            titleVisibility: .visible
        ) {
            Button(
                "Verwijderen",
                role: .destructive
            ) {
                deletePendingServer()
            }

            Button(
                "Annuleren",
                role: .cancel
            ) {
                pendingDeleteServer = nil
            }
        } message: {
            if let pendingDeleteServer {
                Text(
                    "\(pendingDeleteServer.name) wordt uit Veyra verwijderd."
                )
            }
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteServer != nil },
            set: { value in
                if !value {
                    pendingDeleteServer = nil
                }
            }
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 22) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.cyan)
                .frame(width: 4, height: 66)

            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                Text("Mediaservers")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(
                    "Koppel je eigen mediaserver, zoals Jellyfin."
                )
                .font(.system(size: 26))
                .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()
        }
    }

    // MARK: - Add button

    private var addServerButton: some View {
        let focused = addButtonFocused

        return HStack(spacing: 12) {
            Image(systemName: "plus")

            Text("SERVER TOEVOEGEN")
                .font(.system(size: 22, weight: .semibold))
                .tracking(2)
        }
        .foregroundStyle(focused ? .white : .cyan)
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.cyan.opacity(focused ? 0.24 : 0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    focused ? Color.cyan : Color.cyan.opacity(0.25),
                    lineWidth: focused ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused($addButtonFocused)
        .focusEffectDisabled()
        .onTapGesture {
            showAddServer = true
        }
    }

    // MARK: - Existing servers

    @ViewBuilder
    private var existingServersSection: some View {
        Text("GEKOPPELDE SERVERS")
            .font(.system(size: 26, weight: .semibold))
            .tracking(3)
            .foregroundStyle(.cyan)

        if viewModel.servers.isEmpty {
            emptyState
        } else {
            VStack(spacing: 12) {
                ForEach(viewModel.servers) { server in
                    serverRow(server)
                }
            }
        }
    }

    private func serverRow(
        _ server: MediaServerAccount
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            serverMainControl(server)
            serverDeleteControl(server)
        }
    }

    private func serverMainControl(
        _ server: MediaServerAccount
    ) -> some View {
        let isFocused = focusedServerID == server.id

        return HStack(alignment: .center, spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cyan.opacity(isFocused ? 0.20 : 0.10))

                Image(systemName: server.kind.symbol)
                    .font(.system(size: 39, weight: .light))
                    .foregroundStyle(isFocused ? .white : .cyan)
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text(server.name)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(server.kind.displayName.uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.cyan)
                }

                Text("\(server.username) · \(server.host)")
                    .font(.system(size: 21))
                    .foregroundStyle(.white.opacity(isFocused ? 0.85 : 0.62))
                    .lineLimit(1)
            }

            Spacer()

            Text("Details")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(isFocused ? .white : .cyan)

            Image(systemName: "chevron.right")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(isFocused ? .white : .cyan.opacity(0.60))
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    isFocused
                        ? Color.cyan.opacity(0.18)
                        : Color(red: 0.03, green: 0.09, blue: 0.14)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    isFocused ? Color.cyan : Color.cyan.opacity(0.12),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused($focusedServerID, equals: server.id)
        .focusEffectDisabled()
        .onTapGesture {
            selectedServer = server
        }
    }

    private func serverDeleteControl(
        _ server: MediaServerAccount
    ) -> some View {
        let isFocused = focusedDeleteServerID == server.id

        return VStack(spacing: 8) {
            Image(systemName: "trash")
                .font(.system(size: 32, weight: .medium))

            Text("VERWIJDER")
                .font(.system(size: 18, weight: .semibold))
                .tracking(1)
        }
        .foregroundStyle(isFocused ? .white : .red.opacity(0.85))
        .frame(width: 130, height: 116)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    isFocused
                        ? Color.red.opacity(0.20)
                        : Color(red: 0.03, green: 0.09, blue: 0.14)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isFocused ? Color.red : Color.red.opacity(0.25),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused($focusedDeleteServerID, equals: server.id)
        .focusEffectDisabled()
        .onTapGesture {
            pendingDeleteServer = server
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Geen mediaservers gekoppeld")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)

            Text(
                "Voeg je Jellyfin-server toe om je eigen bibliotheek in Veyra te bekijken."
            )
            .font(.system(size: 22))
            .foregroundStyle(.white.opacity(0.62))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.03, green: 0.09, blue: 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.cyan.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Data

    private func deletePendingServer() {
        guard let server = pendingDeleteServer else {
            return
        }

        viewModel.remove(id: server.id)
        pendingDeleteServer = nil
    }
}

// MARK: - Add media server

@MainActor
struct MediaServerAddView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    @State private var selectedKind: MediaServerKind = .jellyfin

    @State private var name = ""
    @State private var serverURLText = ""
    @State private var username = ""
    @State private var password = ""

    @State private var isConnecting = false
    @State private var errorMessage: String?

    @FocusState
    private var connectFocused: Bool

    private let store = MediaServerStore()

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Server toevoegen")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(
                        "Koppel een mediaserver om je eigen bibliotheek te bekijken."
                    )
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.62))

                    fieldTitle("SERVERTYPE")
                    serverKindPicker

                    if selectedKind.isAvailable {
                        fieldTitle("NAAM")

                        TextField(
                            selectedKind.displayName,
                            text: $name
                        )
                        .textFieldStyle(.plain)
                        .font(.system(size: 22))
                        .padding(18)
                        .background(inputBackground)

                        fieldTitle("SERVER-URL")

                        TextField(
                            "https://jouw-server:8096",
                            text: $serverURLText
                        )
                        .textFieldStyle(.plain)
                        .font(.system(size: 21, design: .monospaced))
                        .padding(18)
                        .background(inputBackground)
                        #if !os(tvOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif

                        fieldTitle("GEBRUIKERSNAAM")

                        TextField(
                            "Gebruikersnaam",
                            text: $username
                        )
                        .textFieldStyle(.plain)
                        .font(.system(size: 22))
                        .padding(18)
                        .background(inputBackground)
                        #if !os(tvOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif

                        fieldTitle("WACHTWOORD")

                        SecureField(
                            "Wachtwoord",
                            text: $password
                        )
                        .textFieldStyle(.plain)
                        .font(.system(size: 22))
                        .padding(18)
                        .background(inputBackground)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 20))
                                .foregroundStyle(.orange)
                        }

                        connectButton
                    } else {
                        comingSoonNote
                    }
                }
                .frame(maxWidth: 900, alignment: .leading)
                .padding(.horizontal, VeyraSpacing.page)
                .padding(.top, 36)
                .padding(.bottom, 50)
            }
        }
    }

    // MARK: - Server type picker

    private var serverKindPicker: some View {
        HStack(spacing: 16) {
            ForEach(MediaServerKind.allCases, id: \.self) { kind in
                serverKindTile(kind)
            }
        }
    }

    private func serverKindTile(
        _ kind: MediaServerKind
    ) -> some View {
        let isSelected = selectedKind == kind

        return VStack(spacing: 10) {
            Image(systemName: kind.symbol)
                .font(.system(size: 30, weight: .light))

            Text(kind.displayName)
                .font(.system(size: 19, weight: .semibold))

            if !kind.isAvailable {
                Text("BINNENKORT")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .foregroundStyle(
            kind.isAvailable
                ? (isSelected ? .white : .cyan)
                : .white.opacity(0.35)
        )
        .frame(maxWidth: .infinity, minHeight: 104)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    isSelected && kind.isAvailable
                        ? Color.cyan.opacity(0.22)
                        : Color.white.opacity(0.05)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isSelected && kind.isAvailable
                        ? Color.cyan
                        : Color.white.opacity(0.10),
                    lineWidth: isSelected && kind.isAvailable ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .opacity(kind.isAvailable ? 1 : 0.7)
        .onTapGesture {
            guard kind.isAvailable else { return }
            selectedKind = kind
            if name.isEmpty {
                name = kind.displayName
            }
        }
    }

    private var comingSoonNote: some View {
        Text(
            "\(selectedKind.displayName) wordt binnenkort ondersteund. Kies Jellyfin om nu een server te koppelen."
        )
        .font(.system(size: 20))
        .foregroundStyle(.white.opacity(0.62))
    }

    // MARK: - Shared field chrome

    private func fieldTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold))
            .tracking(2)
            .foregroundStyle(.cyan)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.cyan.opacity(0.18), lineWidth: 1)
            )
    }

    // MARK: - Connect button

    private var connectButton: some View {
        let focused = connectFocused

        return HStack(spacing: 12) {
            if isConnecting {
                ProgressView()
                    .tint(focused ? .white : .cyan)
            }

            Text(isConnecting ? "VERBINDEN…" : "VERBINDEN")
                .font(.system(size: 21, weight: .semibold))
                .tracking(2)
        }
        .foregroundStyle(focused ? .white : .cyan)
        .padding(.horizontal, 24)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.cyan.opacity(focused ? 0.24 : 0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    focused ? Color.cyan : Color.cyan.opacity(0.25),
                    lineWidth: focused ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused($connectFocused)
        .focusEffectDisabled()
        .opacity(isConnecting ? 0.7 : 1)
        .onTapGesture {
            guard !isConnecting else { return }
            connect()
        }
    }

    // MARK: - Connect

    private func connect() {
        errorMessage = nil

        let trimmedName =
            name.trimmingCharacters(in: .whitespacesAndNewlines)

        let trimmedUsername =
            username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let url = validatedServerURL(serverURLText)
        else {
            errorMessage = "Vul een geldige server-URL in."
            return
        }

        guard !trimmedUsername.isEmpty else {
            errorMessage = "Vul een gebruikersnaam in."
            return
        }

        isConnecting = true

        Task {
            do {
                let client = JellyfinClient()

                let result = try await client.authenticate(
                    serverURL: url,
                    username: trimmedUsername,
                    password: password
                )

                let server = MediaServerAccount(
                    name: trimmedName.isEmpty
                        ? selectedKind.displayName
                        : trimmedName,
                    kind: selectedKind,
                    serverURL: url,
                    username: trimmedUsername,
                    userID: result.userID,
                    accessToken: result.accessToken,
                    isVeyraHub: result.isVeyraHub
                )

                try store.add(server)

                await MainActor.run {
                    isConnecting = false
                    notifyMediaServerChange()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage =
                        (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Edit media server

@MainActor
struct MediaServerEditView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    @State private var server: MediaServerAccount
    @State private var password = ""

    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var saveMessage: String?

    @FocusState
    private var reconnectFocused: Bool

    private let store = MediaServerStore()

    init(server: MediaServerAccount) {
        _server = State(initialValue: server)
    }

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                VStack(alignment: .leading, spacing: 24) {
                    Text(server.name)
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Beheer deze mediaserver.")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.62))

                    if server.kind == .jellyfin {
                        NavigationLink {
                            JellyfinLibrariesView(account: server)
                        } label: {
                            VeyraActionLabel(
                                title: "Bibliotheek bekijken",
                                symbol: "rectangle.stack.badge.play"
                            )
                        }
                        .buttonStyle(VeyraFocusButtonStyle(primary: true))
                    }

                    fieldTitle("TYPE")

                    Text(server.kind.displayName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.cyan)

                    fieldTitle("NAAM")

                    TextField("Naam", text: $server.name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22))
                        .padding(18)
                        .background(inputBackground)

                    fieldTitle("SERVER-URL")

                    Text(server.serverURL.absoluteString)
                        .font(.system(size: 21, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(inputBackground)

                    fieldTitle("GEBRUIKERSNAAM")

                    TextField("Gebruikersnaam", text: $server.username)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22))
                        .padding(18)
                        .background(inputBackground)
                        #if !os(tvOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif

                    fieldTitle("WACHTWOORD (om opnieuw te verbinden)")

                    SecureField("Laat leeg om ongewijzigd te laten", text: $password)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22))
                        .padding(18)
                        .background(inputBackground)

                    if let saveMessage {
                        Text(saveMessage)
                            .font(.system(size: 20))
                            .foregroundStyle(VeyraColors.cyan)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 20))
                            .foregroundStyle(.orange)
                    }

                    actionButtons
                }
                .frame(maxWidth: 900, alignment: .leading)
                .padding(.horizontal, VeyraSpacing.page)
                .padding(.top, 36)
                .padding(.bottom, 50)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            reconnectButton
        }
    }

    private var reconnectButton: some View {
        let focused = reconnectFocused

        return HStack(spacing: 12) {
            if isConnecting {
                ProgressView()
                    .tint(focused ? .white : .cyan)
            }

            Text(isConnecting ? "OPSLAAN…" : "OPSLAAN")
                .font(.system(size: 21, weight: .semibold))
                .tracking(2)
        }
        .foregroundStyle(focused ? .white : .cyan)
        .padding(.horizontal, 24)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.cyan.opacity(focused ? 0.24 : 0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    focused ? Color.cyan : Color.cyan.opacity(0.25),
                    lineWidth: focused ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused($reconnectFocused)
        .focusEffectDisabled()
        .opacity(isConnecting ? 0.7 : 1)
        .onTapGesture {
            guard !isConnecting else { return }
            save()
        }
    }

    private func fieldTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold))
            .tracking(2)
            .foregroundStyle(.cyan)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.cyan.opacity(0.18), lineWidth: 1)
            )
    }

    // MARK: - Save

    private func save() {
        errorMessage = nil
        saveMessage = nil

        let trimmedName =
            server.name.trimmingCharacters(in: .whitespacesAndNewlines)

        let trimmedUsername =
            server.username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Naam mag niet leeg zijn."
            return
        }

        guard !trimmedUsername.isEmpty else {
            errorMessage = "Gebruikersnaam mag niet leeg zijn."
            return
        }

        server.name = trimmedName
        server.username = trimmedUsername

        guard !password.isEmpty else {
            persist()
            return
        }

        isConnecting = true

        Task {
            do {
                let client = JellyfinClient()

                let result = try await client.authenticate(
                    serverURL: server.serverURL,
                    username: trimmedUsername,
                    password: password
                )

                await MainActor.run {
                    server.userID = result.userID
                    server.accessToken = result.accessToken
                    server.isVeyraHub = result.isVeyraHub
                    isConnecting = false
                    persist()
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage =
                        (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                }
            }
        }
    }

    private func persist() {
        do {
            try store.update(server)

            saveMessage = "Mediaserver opgeslagen."
            password = ""

            notifyMediaServerChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
