import SwiftUI

/// Toont de kanalen in een eigen Live TV-map (`LiveTVFolder`) mét een "nu"-
/// balk per kanaal (huidig programma + voortgang) en de mogelijkheid om dat
/// programma via VeyraHub op te nemen -- ondanks dat de kanalen in een map
/// uit meerdere providers kunnen komen. Dat lukt zonder `VeyraEPGStore` (die
/// zelf maar één "actieve" provider tegelijk volgt): `LiveTVFolderEPGLoader`
/// haalt de gids per kanaal los op via zijn eigen `providerName`/`tvgID`.
/// Kanalen zonder `tvgID` (VOD/series, of van vóór dit veld) tonen gewoon
/// geen "nu"-balk. Een tik speelt het kanaal direct af, op dezelfde manier
/// als een IPTV-kanaal vanaf een Home-plank (zie `ShelfItemDestination`) --
/// series worden net als daar eerst naar het seizoen/aflevering-scherm
/// gestuurd.
///
/// Naam/logo van een kanaal zijn hier, net als in het Live TV-gidsscherm,
/// aan te passen via lang indrukken -- en gebruiken bewust dezelfde
/// `ChannelNameOverrideStore`/`ChannelLogoOverrideStore` (gesleuteld op de
/// echte provider-kanaal-ID, `channel.channelID`), dus een wijziging hier
/// geldt overal waar dit kanaal voorkomt, ook in de gids zelf.
struct LiveTVFolderChannelsView: View {
    let folder: LiveTVFolder

    @StateObject private var epgLoader = LiveTVFolderEPGLoader()
    @State private var editingChannel: ShelfIPTVChannel?
    @State private var overrideVersion = 0
    @State private var schedulingChannelID: String?
    @State private var recorderMessage: String?
    @State private var showRecorderAlert = false
    // tvOS: afspelen ging voorheen via `NavigationLink` naar `destination(for:)`,
    // maar dit scherm zit op tvOS altijd genest in de `.sheet` van
    // `LiveTVFoldersListView`/`LiveTVView`. Een sheet rendert op tvOS als klein
    // zwevend kaartje, dus een `NavigationLink`-push blijft beperkt tot dat
    // kaartje in plaats van het hele scherm te vullen -- het gerapporteerde
    // "klein mappop-up" i.p.v. fullscreen. Afspelen gaat daarom op tvOS/iOS
    // via `.fullScreenCover(item:)`; macOS gebruikt een speler-sheet.
    @State private var playingSource: PlayableSource?

    var body: some View {
        List(folder.channels) { channel in
            rowContent(for: channel)
                .contextMenu {
                    Button {
                        editingChannel = channel
                    } label: {
                        Label("Naam/logo aanpassen…", systemImage: "photo.badge.plus")
                    }

                    if let now = epgLoader.currentProgramme(for: channel), channel.streamURL != nil {
                        Button {
                            Task { await scheduleRecording(for: channel, programme: now) }
                        } label: {
                            Label("Opnemen: \(now.title)", systemImage: "record.circle")
                        }
                    }
                }
        }
        .navigationTitle(folder.title)
        .task { await epgLoader.load(channels: folder.channels) }
        .sheet(item: $editingChannel) { channel in
            ChannelLogoPickerView(
                channelID: channel.channelID,
                channelName: channel.name,
                currentOverrideURL: ChannelLogoOverrideStore.logoURL(forChannelID: channel.channelID),
                currentNameOverride: ChannelNameOverrideStore.name(forChannelID: channel.channelID)
            ) {
                overrideVersion += 1
            }
        }
        #if os(macOS)
        .sheet(item: $playingSource) { source in
            PlayerView(source: source)
        }
        #else
        .fullScreenCover(item: $playingSource) { source in
            PlayerView(source: source)
        }
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .channelOverrideChanged)) { _ in
            overrideVersion += 1
        }
        .alert("VeyraHub Recorder", isPresented: $showRecorderAlert) {
            Button("OK") {}
        } message: {
            Text(recorderMessage ?? "")
        }
    }

    /// Enkelvoudige rij: series openen als normale, in-stack detailpagina
    /// (`NavigationLink`, want dat is geen afspelen); een direct afspeelbaar
    /// kanaal zet `playingSource`, wat de spelerpresentatie hierboven opent
    /// -- zie de toelichting bij `playingSource` voor waarom dit niet meer
    /// via `NavigationLink` naar een spelerscherm gaat.
    @ViewBuilder
    private func rowContent(for channel: ShelfIPTVChannel) -> some View {
        if channel.kind == .series, let seriesID = Int(channel.channelID) {
            NavigationLink {
                ShelfIPTVSeriesEpisodesView(
                    seriesID: seriesID,
                    providerName: channel.providerName,
                    title: effectiveName(for: channel),
                    posterURL: effectiveLogoURL(for: channel)
                )
            } label: {
                rowLabel(for: channel)
            }
            #if os(tvOS)
            // Zonder eigen stijl toont tvOS bij focus een effen witte
            // rij-achtergrond ("witte kader"); `.liveTVFolderRow()` geeft
            // in plaats daarvan alleen bij focus een cyaan/rode gloed --
            // in rust volledig onzichtbaar (geen dubbel kader met de
            // buitenste kaderrand van dit scherm).
            .liveTVFolderRow()
            #endif
        } else {
            Button {
                play(channel)
            } label: {
                rowLabel(for: channel)
            }
            #if os(tvOS)
            .liveTVFolderRow()
            #else
            .buttonStyle(.plain)
            #endif
        }
    }

    private func play(_ channel: ShelfIPTVChannel) {
        guard let streamURL = channel.streamURL else { return }
        playingSource = PlayableSource(
            name: effectiveName(for: channel),
            description: channel.group,
            url: streamURL,
            kind: .liveTV,
            providerName: channel.providerName,
            epgChannelID: channel.tvgID,
            epgProgrammes: channel.tvgID.flatMap {
                epgLoader.programmesByTvgID[$0]
            } ?? []
        )
    }

    @ViewBuilder
    private func rowLabel(for channel: ShelfIPTVChannel) -> some View {
        HStack(spacing: 14) {
            VeyraAsyncImage(url: effectiveLogoURL(for: channel)) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "tv").foregroundStyle(.secondary)
                }
            }
            .frame(width: 60, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(effectiveName(for: channel))
                Text(channel.providerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let now = epgLoader.currentProgramme(for: channel) {
                    Text(now.title)
                        .font(.caption)
                        .foregroundStyle(VeyraHomeStyle.cyan)
                        .lineLimit(1)
                    VeyraHairline(progress: progress(of: now), height: 3)
                }
            }

            Spacer()
        }
    }

    private func effectiveName(for channel: ShelfIPTVChannel) -> String {
        _ = overrideVersion
        return ChannelNameOverrideStore.effectiveName(channelID: channel.channelID, defaultName: channel.name)
    }

    private func effectiveLogoURL(for channel: ShelfIPTVChannel) -> URL? {
        _ = overrideVersion
        return ChannelLogoOverrideStore.effectiveLogoURL(channelID: channel.channelID, defaultLogoURL: channel.logoURL)
    }

    private func progress(of programme: VeyraEPGProgramme, at date: Date = .now) -> Double {
        let total = programme.end.timeIntervalSince(programme.start)
        guard total > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(programme.start)
        return min(max(elapsed / total, 0), 1)
    }

    // MARK: - VeyraHub Recorder

    private func scheduleRecording(for channel: ShelfIPTVChannel, programme: VeyraEPGProgramme) async {
        guard let streamURL = channel.streamURL else { return }
        guard let hub = MediaServerStore().load().first(where: { $0.isVeyraHub }) else {
            recorderMessage = "Voeg VeyraHub eerst toe bij Mediaservers."
            showRecorderAlert = true
            return
        }

        schedulingChannelID = channel.id
        defer { schedulingChannelID = nil }

        do {
            try await VeyraHubRecorderClient(account: hub).schedule(
                title: programme.title,
                channel: effectiveName(for: channel),
                streamURL: streamURL,
                start: programme.start,
                end: programme.end
            )
            recorderMessage = "Opname gepland in VeyraHub."
        } catch {
            recorderMessage = error.localizedDescription
        }
        showRecorderAlert = true
    }
}
