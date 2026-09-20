import Foundation

// Test-only configuration: never reads a real API key or contacts OpenSubtitles.
enum AppConfiguration { nonisolated static let openSubtitlesAPIKey: String? = "test-only" }
final class SubtitleMockProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems ?? []
        precondition(params.first(where: { $0.name == "languages" })?.value == "fr")
        precondition(params.first(where: { $0.name == "imdb_id" })?.value == "12345")
        let body = #"{"data":[{"id":"1","attributes":{"language":"fr","release":"Test release","files":[{"file_id":7,"file_name":"test.srt"}]}}]}"#
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@main struct SubtitlePreferencesChecks {
    static func main() async throws {
        let suite = "Veyra.SubtitleTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        precondition(SubtitlePreferences.language(defaults: defaults) == .nl)
        defaults.set("fr", forKey: SubtitlePreferences.languageKey)
        precondition(SubtitlePreferences.language(defaults: defaults) == .fr)
        precondition(SubtitleLanguage.nl.matches("DUT"))
        precondition(SubtitleLanguage.fr.matches("fra"))
        precondition(!SubtitleLanguage.nl.matches("fr"))
        precondition(!SubtitleLanguage.nl.matches(nil))
        defaults.set("invalid", forKey: SubtitlePreferences.languageKey)
        precondition(SubtitlePreferences.language(defaults: defaults) == .nl)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SubtitleMockProtocol.self]
        let client = OpenSubtitlesClient(session: URLSession(configuration: config))
        let results = try await client.search(imdbID: "tt12345", type: .movie, seasonNumber: nil, episodeNumber: nil, languages: ["fr"])
        precondition(results.count == 1 && results.first?.language == "fr" && results.first?.fileID == 7)
        print("PASS subtitle defaults, persistence, language aliases, invalid preference fallback and OpenSubtitles language request/result (mock network).")
    }
}
