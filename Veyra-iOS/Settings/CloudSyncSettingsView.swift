import SwiftUI

/// "Gegevens en opslag" — status en beheer van `CloudSettingsSync`
/// (instellingen/planken/hero/addons via iCloud sleutel-waardeopslag) en
/// van de aparte iCloud Keychain-sync voor IPTV-providergegevens.
struct CloudSyncSettingsView: View {
    @ObservedObject private var sync = CloudSettingsSync.shared

    @State private var iptvProviderCount = 0
    @State private var isWorking = false
    @State private var actionMessage: String?
    @State private var showResetConfirmation = false

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
                Section {
                    Toggle(
                        "Synchroniseren via iCloud",
                        isOn: Binding(
                            get: { sync.isEnabled },
                            set: { sync.setEnabled($0) }
                        )
                    )
                } footer: {
                    Text("Wanneer dit uitstaat, blijven je instellingen alleen op dit apparaat. Een eerder gesynchroniseerde kopie in iCloud wordt niet automatisch gewist.")
                }

                if sync.isEnabled {
                    Section {
                        ForEach(sync.categories) { category in
                            categoryRow(category)
                        }
                    } header: {
                        Text("Instellingen")
                    } footer: {
                        Text("Aantal instellingen dat lokaal op dit apparaat staat, tegenover het aantal dat momenteel in iCloud staat.")
                    }

                    Section {
                        HStack {
                            Text("IPTV-providers")
                            Spacer()
                            Text("\(iptvProviderCount)")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Inloggegevens")
                    } footer: {
                        Text("Xtream- en M3U-inloggegevens gaan niet via deze functie mee, maar via Apple's eigen versleutelde iCloud-sleutelhanger — daarom is hiervoor geen los aantal 'in iCloud' te tonen.")
                    }

                    Section {
                        storageMeter
                    } header: {
                        Text("Opslag")
                    } footer: {
                        Text("Schatting op basis van wat dit apparaat zou versturen. iCloud biedt geen manier om het werkelijk gebruikte aandeel op te vragen; de limiet van Apple's sleutel-waardeopslag is 1 MB.")
                    }

                    Section {
                        Button {
                            performAction(actionMessage: "Verstuurd naar iCloud.") {
                                sync.forcePushAll()
                            }
                        } label: {
                            Label("Stuur naar iCloud", systemImage: "icloud.and.arrow.up")
                        }
                        .disabled(isWorking)

                        Button {
                            performAction(actionMessage: "Opgehaald uit iCloud.") {
                                sync.forcePullAll()
                            }
                        } label: {
                            Label("Haal op uit iCloud", systemImage: "icloud.and.arrow.down")
                        }
                        .disabled(isWorking)
                    } footer: {
                        if let lastSyncDate = sync.lastSyncDate {
                            Text("Laatst gesynchroniseerd: \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))")
                        } else {
                            Text("Nog niet gesynchroniseerd op dit apparaat.")
                        }
                    }

                    if let actionMessage {
                        Section {
                            Text(actionMessage)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            showResetConfirmation = true
                        } label: {
                            Label("Reset iCloud-kopie", systemImage: "trash")
                        }
                        .disabled(isWorking)
                    } footer: {
                        Text("Wist alleen wat in iCloud staat. De instellingen op dit apparaat blijven ongewijzigd.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Gegevens en opslag")
        .onAppear {
            sync.refreshStatus()
            iptvProviderCount = (try? IPTVConfigurationStore().loadProviders().count) ?? 0
        }
        .confirmationDialog(
            "iCloud-kopie resetten?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Resetten", role: .destructive) {
                performAction(actionMessage: "iCloud-kopie gereset.") {
                    sync.forgetCloudCopy()
                }
            }
            Button("Annuleren", role: .cancel) {}
        } message: {
            Text("Dit verwijdert de gesynchroniseerde instellingen uit iCloud. Andere apparaten sturen hun eigen instellingen opnieuw op zodra ze weer online zijn.")
        }
    }

    private func categoryRow(_ category: CloudSyncCategory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                Text(category.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(category.localCount) lokaal")
                    .font(.caption)
                Text("\(category.cloudCount) in iCloud")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var storageMeter: some View {
        let fraction = min(1, Double(sync.estimatedTotalBytes) / Double(CloudSettingsSync.storeByteLimit))
        let isNearLimit = fraction > 0.8

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formattedBytes(sync.estimatedTotalBytes))
                Spacer()
                Text("van \(formattedBytes(CloudSettingsSync.storeByteLimit))")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            ProgressView(value: fraction)
                .tint(isNearLimit ? .orange : VeyraColors.cyan)

            if isNearLimit {
                Label("Bijna vol — overweeg minder categorieën te synchroniseren.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedBytes(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    private func performAction(actionMessage message: String, _ action: @escaping () -> Void) {
        isWorking = true
        action()
        actionMessage = message
        isWorking = false
    }
}

#Preview {
    NavigationStack { CloudSyncSettingsView() }
}
