import Foundation

/// Auto-schedules upcoming episodes for an active "neem hele serie op" rule
/// (see `SeriesRecordingDefaults`). Called whenever `VeyraEPGStore` loads a
/// fresh EPG window, so a newly-announced episode gets picked up the next
/// time the guide refreshes without the person having to open the guide
/// themselves.
///
/// Safe to call repeatedly and with data that was already scanned before:
/// VeyraHub Recorder de-duplicates an identical (owner, stream URL, start,
/// end) schedule request server-side, so re-submitting an episode that's
/// already scheduled/recording is a no-op there.
enum VeyraHubRecorderScheduler {
    @MainActor
    static func scheduleUpcomingEpisodes(
        programmeIndex: [String: [VeyraEPGProgramme]],
        channels: [VeyraGuideChannel]
    ) async {
        let rules = SeriesRecordingDefaults.loadRules()
        guard !rules.isEmpty else { return }
        guard let hub = MediaServerStore().load().first(where: { $0.isVeyraHub }) else { return }

        let channelsByID = Dictionary(uniqueKeysWithValues: channels.map { ($0.id, $0) })
        let client = VeyraHubRecorderClient(account: hub)
        let now = Date()

        for rule in rules {
            guard let row = channelsByID[rule.channelID] else { continue }
            await scheduleMatches(
                for: rule, row: row, programmeIndex: programmeIndex, client: client, now: now
            )
        }
    }

    @MainActor
    private static func scheduleMatches(
        for rule: SeriesRecordingRule,
        row: VeyraGuideChannel,
        programmeIndex: [String: [VeyraEPGProgramme]],
        client: VeyraHubRecorderClient,
        now: Date
    ) async {
        let tvgID = row.channel.tvgID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let programmes = programmeIndex[tvgID] ?? []
        let channelName = ChannelNameOverrideStore.effectiveName(
            channelID: row.channel.id, defaultName: row.channel.name
        )

        for programme in programmes where programme.end > now
            && programme.title.caseInsensitiveCompare(rule.title) == .orderedSame {
            do {
                try await client.schedule(
                    title: programme.title,
                    channel: channelName,
                    streamURL: row.channel.streamURL,
                    start: programme.start,
                    end: programme.end
                )
            } catch {
                print("[VeyraHubRecorderScheduler] auto-opname mislukt voor \(programme.title): \(error.localizedDescription)")
            }
        }
    }
}
