import Foundation

private final class MockIntroDBProtocol: URLProtocol {
    static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        let body = Data("""
        {
          "intro": [
            {"start_ms": null, "end_ms": 90000},
            {"start_ms": 180000, "end_ms": 240000}
          ],
          "recap": [{"start_ms": 10000, "end_ms": 30000}]
        }
        """.utf8)
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}

@main
struct IntroDBChecks {
    static func main() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockIntroDBProtocol.self]
        let client = IntroDBClient(session: URLSession(configuration: configuration))

        let segments = await client.segments(
            tmdbID: nil, imdbID: "tt0903747",
            season: 1, episode: 1, durationSeconds: .infinity
        )
        precondition(segments.intros.count == 2)
        precondition(segments.intros[0].contains(0))
        precondition(segments.intros[1].contains(200))
        precondition(!segments.intros[1].contains(250))
        precondition(segments.recaps.first?.contains(20) == true)

        let request = MockIntroDBProtocol.requests.first!
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
        precondition(query.contains(URLQueryItem(name: "imdb_id", value: "tt0903747")))
        precondition(!query.contains(where: { $0.name == "duration_ms" }))

        _ = await client.segments(
            tmdbID: nil, imdbID: "tt0903747",
            season: 1, episode: 1, durationSeconds: nil
        )
        precondition(MockIntroDBProtocol.requests.count == 1)
        print("PASS IMDb-opzoeking, meerdere introsegmenten en cache")
    }
}
