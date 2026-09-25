import Foundation

/// Schedules Veyra's own recorder through an existing VeyraHub session.
/// It does not connect to Strand Recorder. The recorder stores the stream
/// address privately so a scheduled recording can start after the app closes.
struct VeyraHubRecorderClient {
    let account: MediaServerAccount
    var session: URLSession = .shared

    func schedule(
        title: String,
        channel: String,
        streamURL: URL,
        start: Date,
        end: Date
    ) async throws {
        let url = account.serverURL
            .appendingPathComponent("v1")
            .appendingPathComponent("recorder")
            .appendingPathComponent("recordings")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RecorderError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw RecorderError.server(http.statusCode)
        }
    }

    private struct ScheduleRequest: Encodable {
        let title: String
        let channel: String
        let url: String
        let start: Date
        let end: Date
    }

    enum RecorderError: LocalizedError {
        case invalidResponse
        case server(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "De recorder gaf geen geldig antwoord."
            case .server(let status):
                return "De recorder kon de opname niet plannen (HTTP \(status))."
            }
        }
    }
}
