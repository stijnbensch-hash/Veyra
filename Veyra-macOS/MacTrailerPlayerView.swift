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
        guard view.url != url else { return }
        var request = URLRequest(url: url)
        if let bundleID = Bundle.main.bundleIdentifier {
            request.setValue("https://\(bundleID.lowercased())", forHTTPHeaderField: "Referer")
        }
        view.load(request)
    }
}

struct TrailerSheet: View {
    let youtubeKey: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Sluiten", systemImage: "xmark") { dismiss() }
                    .padding(12)
            }
            MacTrailerWebView(youtubeKey: youtubeKey)
        }
        .frame(minWidth: 800, minHeight: 450)
    }
}
