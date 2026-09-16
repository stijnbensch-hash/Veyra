import SwiftUI

struct PlaybackTestView: View {
    private let testSource = PlayableSource(
        name: "Veyra Test Video",
        url: URL(
            string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        )!,
        kind: .direct
    )

    var body: some View {
        PlayerView(source: testSource)
    }
}

#Preview {
    PlaybackTestView()
}
