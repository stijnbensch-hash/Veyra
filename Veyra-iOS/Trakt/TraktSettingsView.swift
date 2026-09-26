import SwiftUI

struct TraktSettingsView: View {
    @ObservedObject private var store = TraktStore.shared

    @State private var deviceCode: TraktDeviceCode?
    @State private var loginTask: Task<Void, Never>?
    @State private var isLinking = false
    @State private var loginError: String?
    @State private var confirmDisconnect = false
    @State private var disconnecting = false

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
            if store.isConnected {
                connectedSection
            } else {
                connectionSection
            }

            if let message = loginError ?? store.errorMessage {
                Section {
                    Text(message).foregroundStyle(.orange)
                }
            }

            Section {
                NavigationLink("Privacy en Trakt") {
                    TraktPrivacyView()
                }
            }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Trakt")
        .task { await store.refreshIfNeeded() }
        .onDisappear {
            loginTask?.cancel()
            loginTask = nil
            isLinking = false
            deviceCode = nil
        }
        .confirmationDialog("Trakt ontkoppelen?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Ontkoppelen", role: .destructive) {
                disconnecting = true
                Task { await store.disconnect(); disconnecting = false }
            }
        } message: {
            Text("De koppeling en geladen Trakt-gegevens worden van dit toestel verwijderd. Je geschiedenis en lijsten bij Trakt blijven behouden.")
        }
    }

    private var connectionSection: some View {
        Section {
            Text("Koppel vrijwillig je Trakt-account om je kijkgeschiedenis, kijkstatus, watchlist, eigen lijsten en beoordelingen te gebruiken. Films en series blijven zonder koppeling beschikbaar.")
                .foregroundStyle(.secondary)

            if !store.isConfigured {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trakt is nog niet ingesteld op dit toestel.")
                        .foregroundStyle(VeyraColors.cyan)

                    NavigationLink("Trakt-sleutels instellen") {
                        AccountView()
                    }
                }
            } else if let code = deviceCode {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Open de activatiepagina en voer deze code in:")
                    if let activationURL = URL(string: code.activationURL) {
                        Link(code.activationURL, destination: activationURL)
                            .foregroundStyle(VeyraColors.cyan)
                    }
                    Text(code.userCode)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .textSelection(.enabled)
                    ProgressView("Wachten op jouw toestemming…")
                }
                .padding(.vertical, 4)

                Button("Annuleren", role: .destructive) {
                    loginTask?.cancel()
                    loginTask = nil
                    deviceCode = nil
                    isLinking = false
                }
            } else {
                Button(isLinking ? "Code aanvragen…" : "Koppel met Trakt") {
                    beginLinking()
                }
                .disabled(isLinking)
            }
        } header: {
            Text("Trakt-koppeling")
        }
    }

    private var connectedSection: some View {
        Section {
            LabeledContent("Verbonden als", value: store.user?.name ?? store.user?.username ?? "Trakt")

            Toggle("Kijkvoortgang automatisch delen", isOn: $store.scrobblingEnabled)

            Text("Wanneer ingeschakeld deelt Veyra de film of aflevering en het bekeken percentage bij starten, pauzeren en stoppen.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LabeledContent("Verder kijken", value: "\(store.playback.count)")
            LabeledContent("Watchlist", value: "\(store.watchlist.count)")
            LabeledContent("Beoordelingen", value: "\(store.ratings.count)")

            if store.isSyncing {
                HStack {
                    Text("Synchroniseren…")
                    Spacer()
                    ProgressView()
                }
            } else {
                Button("Nu synchroniseren") {
                    Task { await store.refresh() }
                }
            }

            Button(disconnecting ? "Ontkoppelen…" : "Ontkoppelen", role: .destructive) {
                confirmDisconnect = true
            }
            .disabled(disconnecting)
        } header: {
            Text("Trakt")
        }
    }

    private func beginLinking() {
        loginTask?.cancel()
        isLinking = true
        loginError = nil

        loginTask = Task { @MainActor in
            defer { isLinking = false; deviceCode = nil }

            do {
                let code = try await store.client.deviceCode()
                try Task.checkCancellation()
                deviceCode = code
                try await store.client.authorize(code, receivedAt: Date())
                await store.connected()
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled {
                    loginError = error.localizedDescription
                }
            }
        }
    }
}

struct TraktPrivacyView: View {
    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
            Section {
                Text("Trakt is een vrijwillige koppeling. Veyra leest je Trakt-profiel, kijkgeschiedenis, kijkstatus, voortgang, watchlist, eigen lijsten en beoordelingen om ze op dit toestel te tonen.")
                Text("Acties zoals een beoordeling, een wijziging aan een lijst of een markering als bekeken worden naar Trakt verzonden. Automatisch delen van de afgespeelde titel en het bekeken percentage gebeurt alleen als je dat zelf inschakelt.")
                Text("Veyra bewaart de toegangstokens in de beveiligde sleutelhanger van dit toestel. Geladen Trakt-gegevens blijven alleen in het geheugen van de app.")
                Text("Ontkoppelen verwijdert de lokale toegangstokens en geladen gegevens en probeert de toegang bij Trakt in te trekken. Je geschiedenis en lijsten bij Trakt blijven bestaan.")
                Text("Trakt-privacybeleid: https://trakt.tv/privacy")
                    .foregroundStyle(VeyraColors.cyan)
                if let url = AppConfiguration.privacyPolicyURL {
                    Text("Privacybeleid Veyra: \(url.absoluteString)")
                        .foregroundStyle(VeyraColors.cyan)
                }
            }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Privacy en Trakt")
    }
}

#Preview {
    NavigationStack { TraktSettingsView() }
}
