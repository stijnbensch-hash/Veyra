import SwiftUI
import WebKit

/// Speelt een YouTube-trailer af via een ingesloten WebKit-embed. TMDB geeft
/// enkel een YouTube-videosleutel terug (geen rechtstreekse streambron), dus
/// deze trailer gebruikt een eigen, lichte webweergave los van de
/// AetherEngine-afspeelpijplijn die voor de echte content wordt gebruikt.
private struct TrailerWebView: UIViewRepresentable {
    let youtubeKey: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(
            string: "https://www.youtube.com/embed/\(youtubeKey)?playsinline=1&autoplay=1&rel=0"
        ) else { return }
        guard webView.url != url else { return }
        var request = URLRequest(url: url)
        if let bundleID = Bundle.main.bundleIdentifier {
            request.setValue("https://\(bundleID.lowercased())", forHTTPHeaderField: "Referer")
        }
        webView.load(request)
    }
}

/// Volledig-scherm trailerweergave, gepresenteerd via `.fullScreenCover`
/// vanaf de trailerssectie op een detailscherm.
struct TrailerSheet: View {
    let youtubeKey: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .padding()
            }
            .background(.black)

            TrailerWebView(youtubeKey: youtubeKey)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
