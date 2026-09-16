import Foundation

struct MockMediaSourceProvider: MediaSourceProvider {
    let name = "Veyra Demo"

    func sources(for item: MediaItem) async throws -> [PlayableSource] {
        guard let url = URL(
            string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        ) else {
            return []
        }

        return [
            PlayableSource(
                name: "\(item.title) — Demo Stream",
                url: url,
                kind: .direct
            )
        ]
    }
}
