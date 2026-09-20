import Foundation

@MainActor
private final class MockScores: SportsScoreProvider {
    var shouldFail = false
    var event: SportsMatch?
    func matches(league: SportsLeague, date: Date) async throws -> [SportsMatch] {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return event?.league.id == league.id ? [event!] : []
    }
}

@main
struct SportsChecks {
    @MainActor static func main() async throws {
        func fixture(_ name: String, _ state: String, _ completed: Bool, score: String = "0") throws -> ESPNScoreboard {
            let json = """
            {"events":[{"id":"1","date":"2026-09-18T00:15Z","status":{"type":{"name":"\(name)","state":"\(state)","completed":\(completed),"shortDetail":"Status"}},"competitions":[{"competitors":[{"homeAway":"away","team":{"id":"1","displayName":"Away","abbreviation":"AWY"},"score":"\(score)"},{"homeAway":"home","team":{"id":"2","displayName":"Home"},"score":"\(score)"}]}]}]}
            """
            return try JSONDecoder().decode(ESPNScoreboard.self, from: Data(json.utf8))
        }
        let nfl = SportsLeague.all[3]
        let scheduled = try fixture("STATUS_SCHEDULED", "pre", false).matches(league: nfl)[0]
        precondition(!scheduled.showsScore, "Scheduled zero scores must stay hidden")
        precondition(scheduled.home.name == "Home", "Do not depend on competitor order")
        let finished = try fixture("STATUS_FINAL", "post", true, score: "21").matches(league: nfl)[0]
        precondition(finished.showsScore && finished.homeScore == "21")
        let postponed = try fixture("STATUS_POSTPONED", "pre", false).matches(league: nfl)[0]
        precondition(postponed.phase == .postponed && !postponed.showsScore)
        let live = try fixture("STATUS_IN_PROGRESS", "in", false).matches(league: nfl)[0]
        precondition(live.phase == .live && live.showsScore)
        let college = try fixture("STATUS_SCHEDULED", "pre", false).matches(league: SportsLeague.all[4])[0]
        precondition(college.home.id != scheduled.home.id, "Unrelated sport leagues must not share favorite IDs")
        let domestic = try fixture("STATUS_SCHEDULED", "pre", false).matches(league: SportsLeague.all[0])[0]
        let european = try fixture("STATUS_SCHEDULED", "pre", false).matches(league: SportsLeague.all[1])[0]
        precondition(domestic.home.id == european.home.id, "Soccer favorites follow teams between leagues")
        let suite = "Veyra.SportsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let provider = MockScores()
        provider.event = live
        let store = SportsStore(provider: provider, defaults: defaults)
        await store.refresh(date: live.date, force: true)
        precondition(store.matches.count == 1 && store.failedLeagues.isEmpty)
        store.toggle(live.home)
        precondition(SportsStore(provider: provider, defaults: defaults).favorites.contains(live.home.id))
        provider.shouldFail = true
        await store.refresh(date: live.date, force: true)
        precondition(store.matches.count == 1 && store.failedLeagues.count == 6, "Keep last known scores on failure and mark stale")
        await store.refresh(date: live.date.addingTimeInterval(86400), force: true)
        precondition(store.matches.isEmpty, "Do not show yesterday's data as today's scores")
        if CommandLine.arguments.contains("--live") {
            for league in SportsLeague.all {
                let matches = try await ESPNScoreProvider().matches(league: league, date: Date())
                precondition(matches.allSatisfy { Calendar.current.isDateInToday($0.date) })
                print("Live feed \(league.name): \(matches.count) wedstrijden vandaag")
            }
        }
        print("Sports checks passed: states, team identity, favorites, failure recovery, date isolation")
    }
}
