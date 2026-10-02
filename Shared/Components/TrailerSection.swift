import SwiftUI
#if os(tvOS)
import UIKit
#endif

/// Toont alleen een trailer als TMDB een afspeelbare YouTube-verwijzing heeft.
/// Staat op film- en seriedetails direct onder de cast.
struct TrailerSection: View {
    let item: MediaItem
    /// Fase 4 (TMDB-spec, append_to_response): hergebruikt een al opgehaalde `videos`-respons
    /// i.p.v. zelf nog een `/videos`-aanvraag te doen -- `.none` (default) betekent
    /// gewoon zelf ophalen, zoals voorheen.
    var preloadedTrailer: TMDBPreload<TMDBVideo?> = .none

    @State private var trailer: TMDBVideo?
    @State private var selectedYoutubeKey: String?
    @State private var isPresentingPlayer = false
    @State private var showUnavailableAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            if let trailer {
                VeyraSectionHeader(title: "Trailer")
                    #if !os(tvOS)
                    .padding(.horizontal)
                    #endif

                Button {
                    play(trailer)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        thumbnail(for: trailer)

                        Text(trailer.name.isEmpty ? "Trailer" : trailer.name)
                            .font(titleFont)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(width: thumbnailWidth)
                    .contentShape(Rectangle())
                }
                #if os(tvOS)
                .buttonStyle(VeyraPosterFocusStyle(cornerRadius: 16))
                #else
                .buttonStyle(.plain)
                #endif
                .accessibilityLabel("Speel " + (trailer.name.isEmpty ? "trailer" : trailer.name) + " af")
                .padding(.horizontal)
            }
        }
        .veyraTrailerPresentation(isPresented: $isPresentingPlayer, youtubeKey: selectedYoutubeKey)
        #if os(tvOS)
        .alert("Trailer niet beschikbaar", isPresented: $showUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Installeer de YouTube-app op Apple TV om deze trailer te bekijken.")
        }
        #endif
        .task(id: "\(item.type.rawValue)|\(item.tmdbID ?? 0)|\(preloadedTrailer.stageKey)") {
            switch preloadedTrailer {
            case .value(let preloaded):
                trailer = preloaded
            case .pending:
                break // de aanroeper is bezig met een gecombineerde aanvraag -- even wachten.
            case .none:
                trailer = nil
                let result = await MetadataTrailerService.trailer(for: item)
                guard !Task.isCancelled else { return }
                trailer = result
            }
        }
    }

    private func thumbnail(for trailer: TMDBVideo) -> some View {
        VeyraAsyncImage(url: URL(string: "https://img.youtube.com/vi/\(trailer.key)/hqdefault.jpg")) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    VeyraColors.surface
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .frame(width: thumbnailWidth, height: thumbnailHeight)
        .clipped()
        .overlay {
            Image(systemName: "play.circle.fill")
                .font(.system(size: playIconSize))
                .foregroundStyle(.white, .black.opacity(0.65))
                .shadow(color: .black.opacity(0.5), radius: 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func play(_ trailer: TMDBVideo) {
        #if os(tvOS)
        guard let url = URL(string: "youtube://www.youtube.com/watch?v=\(trailer.key)"),
              UIApplication.shared.canOpenURL(url) else {
            showUnavailableAlert = true
            return
        }
        Task {
            if !(await UIApplication.shared.open(url)) {
                showUnavailableAlert = true
            }
        }
        #else
        selectedYoutubeKey = trailer.key
        isPresentingPlayer = true
        #endif
    }

    private var thumbnailWidth: CGFloat {
        #if os(tvOS)
        420
        #elseif os(macOS)
        340
        #else
        280
        #endif
    }

    private var thumbnailHeight: CGFloat { thumbnailWidth * 9 / 16 }

    private var playIconSize: CGFloat {
        #if os(tvOS)
        68
        #else
        48
        #endif
    }

    private var titleFont: Font {
        #if os(tvOS)
        .system(size: 20, weight: .semibold)
        #else
        .subheadline.weight(.semibold)
        #endif
    }

    private var sectionSpacing: CGFloat {
        #if os(tvOS)
        20
        #else
        12
        #endif
    }
}
