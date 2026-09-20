import Combine
import Foundation
import SwiftUI

/// Wat op dit moment in de tvOS Home-hero getoond moet worden: hetzij een
/// item dat de gebruiker met de afstandsbediening focust in een rij eronder,
/// hetzij (wanneer niets gefocust is) de automatisch wisselende trending-hero.
struct VeyraHeroContent: Identifiable, Equatable {
    let id: String
    let eyebrow: String
    let title: String
    let overview: String?
    let metadata: [String]
    let backdropURL: URL?
}

/// Gedeelde staat: welk item heeft momenteel focus in een van de Home-rijen.
/// Rijen melden zich via `focus(_:token:)`/`clear(token:)`, meestal via de
/// `.reportsHero(...)` modifier hieronder. Alleen de laatste focuswissel telt,
/// en een bron wist de hero alleen als ze zelf nog de actieve bron is —
/// dat voorkomt geflikker wanneer focus binnen dezelfde tick doorspringt.
@MainActor
final class VeyraHeroSpotlight: ObservableObject {
    static let shared = VeyraHeroSpotlight()

    @Published private(set) var focused: VeyraHeroContent?
    private var currentToken: UUID?

    private init() {}

    func focus(_ content: VeyraHeroContent, token: UUID) {
        currentToken = token
        focused = content
    }

    func clear(token: UUID) {
        guard currentToken == token else { return }
        currentToken = nil
        focused = nil
    }
}

private struct VeyraHeroReporter: ViewModifier {
    let content: VeyraHeroContent?

    @FocusState private var isFocused: Bool
    @State private var token = UUID()

    func body(content wrapped: Content) -> some View {
        wrapped
            .focused($isFocused)
            .onChange(of: isFocused) { _, focused in
                guard let content else { return }

                if focused {
                    VeyraHeroSpotlight.shared.focus(content, token: token)
                } else {
                    VeyraHeroSpotlight.shared.clear(token: token)
                }
            }
    }
}

extension View {
    /// Meldt dit item aan als bron voor de Home-hero zodra het op tvOS
    /// focus krijgt. Geef `nil` door zolang er nog geen geschikte
    /// hero-inhoud is (bv. artwork nog aan het laden) — dan blijft de
    /// hero ongewijzigd.
    func reportsHero(_ content: VeyraHeroContent?) -> some View {
        modifier(VeyraHeroReporter(content: content))
    }

    /// Zoals `reportsHero(_:)`, maar voor rijen waarvan het item zelf geen
    /// kant-en-klare brede achtergrondfoto heeft (bv. Trakt-kalenderitems):
    /// zoekt die zelf op via TMDB zodra het item focus krijgt.
    func reportsHero(
        tmdbID: Int?,
        isMovie: Bool,
        eyebrow: String,
        title: String,
        id contentID: String,
        overview: String? = nil,
        metadata: [String] = []
    ) -> some View {
        modifier(
            VeyraHeroTMDBReporter(
                tmdbID: tmdbID,
                isMovie: isMovie,
                eyebrow: eyebrow,
                title: title,
                contentID: contentID,
                overview: overview,
                metadata: metadata
            )
        )
    }
}

private struct VeyraHeroTMDBReporter: ViewModifier {
    let tmdbID: Int?
    let isMovie: Bool
    let eyebrow: String
    let title: String
    let contentID: String
    let overview: String?
    let metadata: [String]

    @State private var backdropURL: URL?

    func body(content: Content) -> some View {
        content
            .reportsHero(
                VeyraHeroContent(
                    id: contentID,
                    eyebrow: eyebrow,
                    title: title,
                    overview: overview,
                    metadata: metadata,
                    backdropURL: backdropURL
                )
            )
            .task(id: tmdbID) {
                guard let tmdbID, tmdbID > 0 else {
                    backdropURL = nil
                    return
                }
                backdropURL = await VeyraHeroBackdropLookup.backdropURL(tmdbID: tmdbID, isMovie: isMovie)
            }
    }
}

/// Kleine, op zichzelf staande TMDB-opzoeking voor een brede achtergrondfoto,
/// enkel gebruikt om de hero bij te werken zodra een rij-item focus krijgt.
/// Gebruikt dezelfde TMDB-sleutel als de rest van de app.
enum VeyraHeroBackdropLookup {
    private struct Response: Decodable {
        let backdropPath: String?

        enum CodingKeys: String, CodingKey {
            case backdropPath = "backdrop_path"
        }
    }

    static func backdropURL(tmdbID: Int, isMovie: Bool) async -> URL? {
        guard
            tmdbID > 0,
            let token = AppConfiguration.tmdbReadAccessToken,
            let url = URL(string: "https://api.themoviedb.org/3/\(isMovie ? "movie" : "tv")/\(tmdbID)")
        else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(Response.self, from: data)

            guard let path = decoded.backdropPath, !path.isEmpty else {
                return nil
            }

            return URL(string: "https://image.tmdb.org/t/p/w1280" + path)
        } catch {
            return nil
        }
    }
}
