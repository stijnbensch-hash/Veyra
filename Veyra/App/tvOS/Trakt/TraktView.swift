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
        ZStack {
            VeyraBackground().ignoresSafeArea()

            if store.isConnected {
                connectedContent
            } else {
                connectionContent
            }
        }
        .navigationTitle("Trakt")
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

    // MARK: - Niet gekoppeld

    private var connectionContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Je kijkwereld, op één plek")
                    .font(.title2)
                Text("Koppel vrijwillig je Trakt-account om je kijkgeschiedenis, kijkstatus, watchlist, eigen lijsten en beoordelingen te gebruiken. Films en series blijven zonder koppeling beschikbaar.")
                    .foregroundStyle(.secondary)
                Text("Automatisch delen van kijkvoortgang staat uit. Je kunt dit na het koppelen zelf inschakelen.")
                    .foregroundStyle(.secondary)
                if !store.isConfigured {
                    Text("Trakt is nog niet ingesteld voor deze versie van Veyra.")
                        .foregroundStyle(VeyraColors.cyan)
                } else if let code = deviceCode {
                    Text("Open op je telefoon of computer:")
                    Text(code.activationURL).foregroundStyle(VeyraColors.cyan)
                    Text(code.userCode).font(.system(size: 58, weight: .bold, design: .monospaced))
                        .accessibilityLabel("Koppelcode: \(code.userCode.map(String.init).joined(separator: " "))")
                    ProgressView("Wachten op jouw toestemming…")
                    linkButton(title: "Annuleren", icon: "xmark") {
                        loginTask?.cancel(); loginTask = nil; deviceCode = nil; isLinking = false
                    }
                } else {
                    linkButton(title: isLinking ? "Code aanvragen…" : "Koppel met Trakt", icon: "link") {
                        beginLinking()
                    }
                    .disabled(isLinking)
                }
                if let message = loginError ?? store.errorMessage {
                    Text(message).foregroundStyle(VeyraColors.red).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 1400, alignment: .leading)
            .padding(.horizontal, VeyraSpacing.page)
            .padding(.top, 36)
            .padding(.bottom, 50)
        }
    }

    private func linkButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold))
                Text(title).font(.system(size: 24, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(VeyraFocusButtonStyle(radius: 18))
    }

    // MARK: - Verbonden

    private var connectedContent: some View {
        List {
            Section {
                VeyraSettingsCardRowLabel(
                    icon: "checkmark.circle",
                    title: "Verbonden met \(store.user?.name ?? store.user?.username ?? "Trakt")"
                ) { EmptyView() }

                VeyraSettingsToggleRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Kijkvoortgang automatisch delen",
                    subtitle: "Deelt film/aflevering en bekeken percentage bij starten, pauzeren en stoppen",
                    isOn: $store.scrobblingEnabled
                )
            } header: {
                Text("Trakt-account")
            }

            Section {
                NavigationLink {
                    TraktLibraryView(kind: .playback)
                } label: {
                    VeyraSettingsCardRowLabel(icon: "play.circle", title: "Verder kijken") {
                        VeyraSettingsCardRowValue(value: "\(store.playback.count)")
                    }
                }
                .veyraCardRow()

                NavigationLink {
                    TraktLibraryView(kind: .watchlist)
                } label: {
                    VeyraSettingsCardRowLabel(icon: "bookmark", title: "Watchlist") {
                        VeyraSettingsCardRowValue(value: "\(store.watchlist.count)")
                    }
                }
                .veyraCardRow()

                NavigationLink {
                    TraktLibraryView(kind: .history)
                } label: {
                    VeyraSettingsCardRowLabel(icon: "clock.arrow.circlepath", title: "Kijkgeschiedenis") {
                        VeyraSettingsCardRowValue(value: nil)
                    }
                }
                .veyraCardRow()

                NavigationLink {
                    TraktLibraryView(kind: .ratings)
                } label: {
                    VeyraSettingsCardRowLabel(icon: "star", title: "Beoordelingen") {
                        VeyraSettingsCardRowValue(value: "\(store.ratings.count)")
                    }
                }
                .veyraCardRow()
            } header: {
                Text("Bibliotheek")
            }

            Section {
                ForEach(store.lists) { list in
                    NavigationLink {
                        TraktListView(list: list)
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "list.bullet", title: list.name) {
                            VeyraSettingsCardRowValue(value: "\(list.itemCount ?? 0) titels")
                        }
                    }
                    .veyraCardRow()
                }

                HStack(spacing: 18) {
                    TextField("Naam van nieuwe privélijst", text: $newListName)

                    Button {
                        creatingList = true
                        Task {
                            do { try await store.createList(name: newListName); newListName = "" }
                            catch { loginError = error.localizedDescription }
                            creatingList = false
                        }
                    } label: {
                        Image(systemName: creatingList ? "hourglass" : "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(VeyraColors.cyan)
                    }
                    .buttonStyle(.plain)
                    .disabled(creatingList || newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .listRowBackground(Color.clear)
            } header: {
                Text("Mijn lijsten")
            }

            Section {
                Button {
                    Task { await store.refresh() }
                } label: {
                    VeyraSettingsCardRowLabel(
                        icon: "arrow.clockwise",
                        title: store.isSyncing ? "Synchroniseren…" : "Nu synchroniseren"
                    ) { EmptyView() }
                }
                .veyraCardRow()
                .disabled(store.isSyncing)

                NavigationLink {
                    TraktPrivacyView()
                } label: {
                    VeyraSettingsCardRowLabel(icon: "hand.raised", title: "Privacy en Trakt") {
                        VeyraSettingsCardRowValue(value: nil)
                    }
                }
                .veyraCardRow()

                Button {
                    confirmDisconnect = true
                } label: {
                    VeyraSettingsCardRowLabel(
                        icon: "xmark.circle",
                        title: disconnecting ? "Ontkoppelen…" : "Ontkoppelen"
                    ) { EmptyView() }
                }
                .veyraCardRow()
                .disabled(disconnecting)
            } header: {
                Text("Beheer")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let date = store.lastWatchedSync {
                        Text("Bekeken-status: \(store.watchedMovies.count) films · \(store.watchedShows.count) series · bijgewerkt \(date.formatted(date: .omitted, time: .shortened))")
                            .foregroundStyle(VeyraColors.cyan)
                    } else {
                        Text("Bekeken-status nog niet opgehaald. Kies Synchroniseren om opnieuw te proberen.")
                    }
                    if let date = store.lastSync {
                        Text("Laatst bijgewerkt: \(date.formatted(date: .abbreviated, time: .shortened))")
                    }
                    if let message = loginError ?? store.errorMessage {
                        Text(message).foregroundStyle(VeyraColors.red)
                    }
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: 1000)
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
                    .foregroundStyle(VeyraColors.cyan)
                if let url = AppConfiguration.privacyPolicyURL {
                    Text("Privacybeleid Veyra: \(url.absoluteString)").foregroundStyle(VeyraColors.cyan)
                }
            }
            .frame(maxWidth: 1300, alignment: .leading)
            .padding(.horizontal, VeyraSpacing.page)
            .padding(.top, 36)
            .padding(.bottom, 50)
        }
        .background(VeyraBackground())
    }
}
