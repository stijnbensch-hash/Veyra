import SwiftUI

struct MediaServersSettingsView: View {
    @StateObject private var viewModel = MediaServersViewModel()
    @State private var showAddSheet = false
    @State private var editingServer: MediaServerAccount?

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
            Section("VeyraHub-synchronisatie") {
                if viewModel.servers.contains(where: \.isVeyraHub) {
                    Label("VeyraHub toegevoegd", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(VeyraColors.cyan)
                    Text("Veyra synchroniseert instellingen, brongegevens en API-sleutels automatisch via deze server.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Verbind VeyraHub op dit toestel met hetzelfde serveradres en account als op je andere Veyra-toestellen. Daarna start de synchronisatie automatisch.")
                        .foregroundStyle(.secondary)
                    Button("VeyraHub verbinden") { showAddSheet = true }
                }
            }

            if viewModel.servers.isEmpty {
                ContentUnavailableView(
                    "Geen mediaservers",
                    systemImage: "play.tv",
                    description: Text("Voeg VeyraHub of een Jellyfin-server toe.")
                )
            } else {
                Section {
                    ForEach(viewModel.servers) { server in
                        Button {
                            editingServer = server
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        statusDot(for: server.id)
                                        Text(server.name).foregroundStyle(.primary)
                                    }
                                    Text("\(server.kind.displayName) · \(server.host)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .swipeActions {
                            Button("Verwijderen", role: .destructive) {
                                viewModel.remove(id: server.id)
                            }
                        }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Mediaservers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: viewModel.reload) {
            NavigationStack { MediaServerAddView(viewModel: viewModel) }
        }
        .sheet(item: $editingServer, onDismiss: viewModel.reload) { server in
            NavigationStack { MediaServerEditView(server: server, viewModel: viewModel) }
        }
        .onAppear(perform: viewModel.reload)
        .onReceive(NotificationCenter.default.publisher(for: .veyraMediaServerConfigurationDidChange)) { _ in viewModel.reload() }
        .task {
            // Periodiek herchecken zolang dit scherm open staat, zodat het
            // online/offline-bolletje bijblijft zonder dat de gebruiker
            // handmatig hoeft te verversen. Stopt vanzelf zodra het scherm
            // verdwijnt (SwiftUI annuleert `.task` dan).
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                viewModel.refreshStatus()
            }
        }
    }

    /// Klein bolletje: groen (online), rood (offline), grijs zolang de
    /// eerste controle nog loopt.
    private func statusDot(for serverID: UUID) -> some View {
        let color: Color
        switch viewModel.onlineStatus[serverID] {
        case .some(true): color = .green
        case .some(false): color = .red
        case .none: color = .secondary.opacity(0.4)
        }

        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Add server

private struct MediaServerAddView: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: MediaServersViewModel

    @State private var selectedKind: MediaServerKind = .jellyfin
    @State private var name = ""
    @State private var serverAddress = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            Form {
            Section("Type") {
                Picker("Server", selection: $selectedKind) {
                    ForEach(MediaServerKind.allCases, id: \.self) { kind in
                        HStack {
                            Text(kind.displayName)

                            if !kind.isAvailable {
                                Spacer()
                                Text("BINNENKORT")
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(kind)
                        .disabled(!kind.isAvailable)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Text("Voor VeyraHub kies je Jellyfin en gebruik je het serveradres en account waarmee je op je andere Veyra-toestellen bent ingelogd.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if selectedKind.isAvailable {
                Section("Server") {
                    TextField("Naam (bijv. Thuis Jellyfin)", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("https://server.example.com:8096", text: $serverAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Gebruikersnaam", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Wachtwoord", text: $password)
                }
            } else {
                Section {
                    Text("\(selectedKind.displayName)-ondersteuning komt binnenkort.")
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Server toevoegen")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuleren") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isConnecting {
                    ProgressView()
                } else {
                    Button("Verbinden") { connect() }
                        .disabled(!selectedKind.isAvailable)
                }
            }
        }
    }

    private func connect() {
        errorMessage = nil

        guard let url = validatedServerURL(serverAddress) else {
            errorMessage = "Voer een geldig serveradres in."
            return
        }

        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty else {
            errorMessage = "Voer een gebruikersnaam in."
            return
        }

        isConnecting = true

        Task {
            defer { isConnecting = false }

            do {
                let client = JellyfinClient()
                let result = try await client.authenticate(
                    serverURL: url,
                    username: trimmedUsername,
                    password: trimmedPassword
                )

                let account = MediaServerAccount(
                    name: trimmedName.isEmpty ? (result.serverName ?? "Jellyfin") : trimmedName,
                    kind: .jellyfin,
                    serverURL: url,
                    username: trimmedUsername,
                    userID: result.userID,
                    accessToken: result.accessToken,
                    isVeyraHub: result.isVeyraHub
                )

                try viewModel.add(account)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Edit server

private struct MediaServerEditView: View {
    @Environment(\.dismiss) private var dismiss

    let server: MediaServerAccount
    let viewModel: MediaServersViewModel

    @State private var name: String
    @State private var errorMessage: String?

    init(server: MediaServerAccount, viewModel: MediaServersViewModel) {
        self.server = server
        self.viewModel = viewModel
        _name = State(initialValue: server.name)
    }

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            Form {
            Section("Server") {
                TextField("Naam", text: $name)
                    .textInputAutocapitalization(.words)

                LabeledContent("Type", value: server.kind.displayName)
                LabeledContent("Adres", value: server.host)
                LabeledContent("Gebruiker", value: server.username)
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Server bewerken")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuleren") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Opslaan") { save() }
            }
        }
    }

    private func save() {
        var updated = server
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.name = trimmedName.isEmpty ? server.name : trimmedName

        do {
            try viewModel.update(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { MediaServersSettingsView() }
}
