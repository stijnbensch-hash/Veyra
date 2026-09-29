// VeyraTrailerAutoplayView.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Passieve, gedempte YouTube-trailer-achtergrond voor de "hero-trailer": geen
// bediening, geen YouTube-chrome, enkel een geluidloze visuele voorvertoning
// die achter de hero verschijnt zodra de kijker even op de Afspelen-knop rust
// (tvOS) of het detailscherm een moment open staat (iOS/macOS). Losse, lichte
// WKWebView-embed -- zelfde aanpak als de bestaande volledige-schermtrailer
// (`Veyra-iOS/Playback/TrailerPlayerView.swift`), maar dan gedempt/gelust en
// zonder interactie.

import SwiftUI
#if os(iOS) || os(macOS)
import WebKit
#endif

struct VeyraTrailerAutoplayView: View {
    let youtubeKey: String

    var body: some View {
#if os(iOS) || os(macOS)
        VeyraTrailerAutoplayWebView(youtubeKey: youtubeKey)
            .allowsHitTesting(false)
#else
        // tvOS heeft geen WebKit/WKWebView beschikbaar voor apps (het
        // framework staat niet eens in de linker-lijst van het tvOS-target
        // in Xcode) -- de hero-trailer-achtergrond blijft daarom beperkt
        // tot iOS/iPadOS en macOS. Zie `MovieDetailView.swift` (tvOS): de
        // dwell-detectie roept dit type nog wel aan, maar toont hierdoor
        // niets i.p.v. te crashen of niet te compileren.
        EmptyView()
#endif
    }
}

private func veyraTrailerEmbedURL(youtubeKey: String) -> URL? {
    URL(string:
        "https://www.youtube.com/embed/\(youtubeKey)"
        + "?playsinline=1&autoplay=1&mute=1&controls=0&modestbranding=1&rel=0"
        + "&loop=1&playlist=\(youtubeKey)&iv_load_policy=3&disablekb=1"
    )
}

#if os(macOS)
private struct VeyraTrailerAutoplayWebView: NSViewRepresentable {
    let youtubeKey: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let url = veyraTrailerEmbedURL(youtubeKey: youtubeKey), webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }
}
#elseif os(iOS)
private struct VeyraTrailerAutoplayWebView: UIViewRepresentable {
    let youtubeKey: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = veyraTrailerEmbedURL(youtubeKey: youtubeKey) else { return }
        guard webView.url != url else { return }
        var request = URLRequest(url: url)
        if let bundleID = Bundle.main.bundleIdentifier {
            request.setValue("https://\(bundleID.lowercased())", forHTTPHeaderField: "Referer")
        }
        webView.load(request)
    }
}
#endif
