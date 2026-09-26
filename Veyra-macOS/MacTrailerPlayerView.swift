import SwiftUI
import WebKit

private struct MacTrailerWebView: NSViewRepresentable {
    let youtubeKey: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        return WKWebView(frame: .zero, configuration: configuration)
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        guard let url = URL(string: "https://www.youtube.com/embed/\(youtubeKey)?autoplay=1&rel=0") else { return }
        if view.url != url { view.load(URLRequest(url: url)) }
    }
}

struct TrailerSheet: View {
    let youtubeKey: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MacTrailerWebView(youtubeKey: youtubeKey)
            .frame(minWidth: 800, minHeight: 450)
            .overlay(alignment: .topTrailing) {
                Button("Sluiten", systemImage: "xmark") { dismiss() }
                    .padding()
            }
    }
}
