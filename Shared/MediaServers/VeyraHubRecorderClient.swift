import Foundation

/// Schedules and manages recordings on Veyra's own recorder through an
/// existing VeyraHub session. It does not connect to Strand Recorder. The
/// recorder stores the stream address privately so a scheduled recording
/// can start after the app closes.
struct VeyraHubRecorderClient {
    let account: MediaServerAccount
    var session: URLSession = .shared

    // MARK: - Schedule

    func schedule(
        title: String,
        channel: String,
        streamURL: URL,
        start: Date,
        end: Date
    ) async throws {
        var request = request(path: "recordings", method: "POST")

        let payload = ScheduleRequest(
            title: title,
            channel: channel,
            url: streamURL.absoluteString,
            start: start,
            end: end
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)

        _ = try await send(request)
    }

    // MARK: - Manage

    /// Every recording the signed-in account can see: its own, or every
    /// account's when signed in as the hub's admin — the hub decides that
    /// server-side, this just reflects what it returns.
    func recordings() async throws -> [VeyraHubRecording] {
        let (data, _) = try await send(request(path: "recordings", method: "GET"))
        return try decode(RecordingsResponse.self, from: data).recordings
    }

    func stopRecording(id: String) async throws {
        _ = try await send(request(path: "recordings/\(id)/stop", method: "POST"))
    }

    /// Deletes a recording and its file. Used both for the user-initiated
    /// "Verwijder"/"Annuleer" action and for the automatic cleanup after
    /// playback when "Verwijder automatisch na kijken" is on (see
    /// `VeyraHubRecorderCleanupTracker`).
    func deleteRecording(id: String) async throws {
        _ = try await send(request(path: "recordings/\(id)", method: "DELETE"))
    }

    /// A playable URL for a completed recording's file. The session token
    /// travels as a query parameter (like Jellyfin's own "api_key") rather
    /// than a header, because this URL is handed directly to the player —
    /// see `Hub.requireSessionAllowQueryToken` on the VeyraHub side.
    func fileURL(id: String) -> URL {
        var components = URLComponents(
            url: account.serverURL
                .appendingPathComponent("v1")
                .appendingPathComponent("recorder")
                .appendingPathComponent("recordings")
                .appendingPathComponent(id)
                .appendingPathComponent("file"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "access_token", value: account.accessToken)]
        return components?.url ?? account.serverURL
    }

    // MARK: - Networking

    private func request(path: String, method: String) -> URLRequest {
        let url = account.serverURL
            .appendingPathComponent("v1")
            .appendingPathComponent("recorder")
            .appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        if method == "POST" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    @discardableResult
    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RecorderError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw RecorderError.server(http.statusCode)
        }
        return (data, http)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw RecorderError.invalidResponse
        }
    }

    private struct ScheduleRequest: Encodable {
        let title: String
        let channel: String
        let url: String
        let start: Date
        let end: Date
    }

    private struct RecordingsResponse: Decodable {
        let recordings: [VeyraHubRecording]
    }

    enum RecorderError: LocalizedError {
        case invalidResponse
        case server(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "De recorder gaf geen geldig antwoord."
            case .server(let status):
                return "De recorder kon de aanvraag niet verwerken (HTTP \(status))."
            }
        }
    }
}

/// Mirrors VeyraHub Recorder's `publicRecording` JSON shape exactly
/// (id/ownerID/title/channel/start/end/status/bytes/error/createdAt/
/// scanStatus/adBreaks) — see `recorder/main.go` on the VeyraHub side.
struct VeyraHubRecording: Decodable, Identifiable, Hashable {
    let id: String
    let ownerID: String
    let title: String
    let channel: String?
    let start: Date
    let end: Date
    let status: String
    let bytes: Int64?
    let error: String?
    let createdAt: Date
    let scanStatus: String?
    let adBreaks: [AdBreak]?

    struct AdBreak: Decodable, Hashable {
        let startSeconds: Double
        let endSeconds: Double
    }

    var isScheduled: Bool { status == "scheduled" }
    var isRecording: Bool { status == "recording" }
    var isCompleted: Bool { status == "completed" }
    var isFailed: Bool { status == "failed" }
}
