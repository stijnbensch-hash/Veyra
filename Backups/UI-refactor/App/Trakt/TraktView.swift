import SwiftUI

struct TraktView: View {
    @ObservedObject private var store = TraktStore.shared
    @State private var deviceCode: TraktDeviceCode?
    @State private var loginTask: Task<Void, Never>?
    @State private var isLinking = false
    @State private var loginError: String?
    @State private var newListName = ""
    @State private var creatingList = false
    @State private var disconnecting = false
    @State private var confirmDisconnect = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("TRAKT")
                    .font(.system(size: 48, weight: .light))
                    .tracking(8)
                if store.isConnected {
                    connectedContent
                } else {
                    connectionContent
                }
                if let message = loginError ?? store.errorMessage {
                    Text(message).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                NavigationLink("Privacy en Trakt") { TraktPrivacyView() }
            }
            .frame(maxWidth: 1400, alignment: .leading)
            .padding(70)
        }
        .background(Color(red: 0.01, green: 0.04, blue: 0.07).ignoresSafeArea())
        .task { await store.refreshIfNeeded() }
        .onDisappear { loginTask?.cancel(); loginTask = nil; isLinking = false; deviceCode = nil }
        .confirmationDialog("Trakt ontkoppelen?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Ontkoppelen", role: .destructive) {
                disconnecting = true
                Task { await store.disconnect(); disconnecting = false }
            }
        } message: {
            Text("De koppeling en geladen Trakt-gegevens worden van deze Apple TV verwijderd. Je geschiedenis en lijsten bij Trakt blijven behouden.")
        }
    }

    private var connectionContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Je kijkwereld, op één plek")
                .font(.title2)
            Text("Koppel vrijwillig je Trakt-account om je kijkgeschiedenis, kijkstatus, watchlist, eigen lijsten en beoordelingen te gebruiken. Films en series blijven zonder koppeling beschikbaar.")
                .foregroundStyle(.secondary)
            Text("Automatisch delen van kijkvoortgang staat uit. Je kunt dit na het koppelen zelf inschakelen.")
                .foregroundStyle(.secondary)
            if !store.isConfigured {
                Text("Trakt is nog niet ingesteld voor deze versie van Veyra.")
                    .foregroundStyle(.cyan)
            } else if let code = deviceCode {
                Text("Open op je telefoon of computer:")
                Text(code.verificationUrl).foregroundStyle(.cyan)
                Text(code.userCode).font(.system(size: 58, weight: .bold, design: .monospaced))
                    .accessibilityLabel("Koppelcode: \(code.userCode.map(String.init).joined(separator: " "))")
                ProgressView("Wachten op jouw toestemming…")
                Button("Annuleren") { loginTask?.cancel(); loginTask = nil; deviceCode = nil; isLinking = false }
            } else {
                Button(isLinking ? "Code aanvragen…" : "Koppel met Trakt") { beginLinking() }
                    .disabled(isLinking)
            }
        }
    }

    private var connectedContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Verbonden met \(store.user?.name ?? store.user?.username ?? "Trakt")")
                .font(.title2).foregroundStyle(.cyan)
            Toggle("Kijkvoortgang automatisch delen met Trakt", isOn: $store.scrobblingEnabled)
            Text("Wanneer ingeschakeld deelt Veyra de film of aflevering en het bekeken percentage bij starten, pauzeren en stoppen. Je zichtbaarheid wordt bepaald door je Trakt-instellingen.")
                .font(.callout).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
                NavigationLink("Verder kijken (\(store.playback.count))") {
                    TraktLibraryView(kind: .playback)
                }
                NavigationLink("Watchlist (\(store.watchlist.count))") {
                    TraktLibraryView(kind: .watchlist)
                }
                NavigationLink("Kijkgeschiedenis") { TraktLibraryView(kind: .history) }
                NavigationLink("Beoordelingen (\(store.ratings.count))") { TraktLibraryView(kind: .ratings) }
            }
            Text("MIJN LIJSTEN").font(.headline).tracking(3).padding(.top, 20)
            ForEach(store.lists) { list in
                NavigationLink("\(list.name) · \(list.itemCount ?? 0) titels") {
                    TraktListView(list: list)
                }
            }
            HStack(spacing: 24) {
                TextField("Naam van nieuwe privélijst", text: $newListName)
                Button("Aanmaken") {
                    creatingList = true
                    Task {
                        do { try await store.createList(name: newListName); newListName = "" }
                        catch { loginError = error.localizedDescription }
                        creatingList = false
                    }
                }
                .disabled(creatingList || newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            HStack(spacing: 24) {
                Button(store.isSyncing ? "Synchroniseren…" : "Nu synchroniseren") { Task { await store.refresh() } }
                    .disabled(store.isSyncing)
                Button(disconnecting ? "Ontkoppelen…" : "Ontkoppelen", role: .destructive) { confirmDisconnect = true }
                    .disabled(disconnecting)
            }
            if let date = store.lastSync {
                Text("Laatst bijgewerkt: \(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
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
            } catch is CancellationError { }
            catch { if !Task.isCancelled { loginError = error.localizedDescription } }
        }
    }
}

struct TraktPrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("Privacy en Trakt").font(.largeTitle)
                Text("Trakt is een vrijwillige koppeling. Veyra leest je Trakt-profiel, kijkgeschiedenis, kijkstatus, voortgang, watchlist, eigen lijsten en beoordelingen om ze op deze Apple TV te tonen.")
                Text("Acties zoals een beoordeling, een wijziging aan een lijst of een markering als bekeken worden naar Trakt verzonden. Automatisch delen van de afgespeelde titel en het bekeken percentage gebeurt alleen als je dat zelf inschakelt.")
                Text("Veyra bewaart de toegangstokens in de beveiligde sleutelhanger van deze Apple TV. Geladen Trakt-gegevens blijven alleen in het geheugen van de app. Veyra stuurt geen streamadressen of Trakt-wachtwoord naar Trakt en gebruikt deze koppeling niet voor advertenties.")
                Text("Ontkoppelen verwijdert de lokale toegangstokens en geladen gegevens en probeert de toegang bij Trakt in te trekken. Je geschiedenis en lijsten bij Trakt blijven bestaan. Je kunt ze in Trakt beheren of verwijderen. De zichtbaarheid van je activiteit volgt je instellingen bij Trakt.")
                Text("Trakt-privacybeleid: https://trakt.tv/privacy")
                    .foregroundStyle(.cyan)
                if let url = AppConfiguration.privacyPolicyURL {
                    Text("Privacybeleid Veyra: \(url.absoluteString)").foregroundStyle(.cyan)
                }
            }.frame(maxWidth: 1300, alignment: .leading).padding(70)
        }
        .background(Color(red: 0.01, green: 0.04, blue: 0.07).ignoresSafeArea())
    }
}
