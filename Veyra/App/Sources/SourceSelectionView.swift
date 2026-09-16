import SwiftUI

struct SourceSelectionView: View {
    let item: MediaItem

    @State private var sources: [PlayableSource] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            background

            LinearGradient(
                colors: [
                    .black.opacity(0.35),
                    Color(red: 0.01, green: 0.04, blue: 0.07).opacity(0.88),
                    Color(red: 0.01, green: 0.04, blue: 0.07)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("KIES BRON")
                        .font(.system(size: 42, weight: .light))
                        .tracking(9)
                        .foregroundStyle(.white)

                    Text(item.title)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.72))
                }

                if isLoading {
                    Spacer()

                    HStack {
                        Spacer()

                        ProgressView("Bronnen zoeken…")
                            .font(.title3)

                        Spacer()
                    }

                    Spacer()
                } else if let errorMessage {
                    Spacer()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Bronnen konden niet worden geladen")
                            .font(.title2)
                            .foregroundStyle(.white)

                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                } else if sources.isEmpty {
                    Spacer()

                    Text("Geen bronnen beschikbaar")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Spacer()
                } else {
                    Text("\(sources.count) BRONNEN")
                        .font(.caption)
                        .tracking(3)
                        .foregroundStyle(.cyan.opacity(0.75))

                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(sources) { source in
                                NavigationLink {
                                    PlayerView(source: source)
                                } label: {
                                    sourceCard(source)
                                }
                                .buttonStyle(.card)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 70)
            .padding(.vertical, 50)
        }
        .task {
            await loadSources()
        }
    }

    @ViewBuilder
    private var background: some View {
        if let backdropURL = item.backdropURL {
            AsyncImage(url: backdropURL) { phase in
                switch phase {
                case .empty:
                    baseBackground

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()

                case .failure:
                    baseBackground

                @unknown default:
                    baseBackground
                }
            }
        } else {
            baseBackground
        }
    }

    private var baseBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.01, green: 0.04, blue: 0.07),
                Color(red: 0.02, green: 0.10, blue: 0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func sourceCard(
        _ source: PlayableSource
    ) -> some View {
        HStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.cyan.opacity(0.12))

                Image(systemName: "play.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.cyan)
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 12) {
                Text(source.name)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)

                if let metadata = source.metadata {
                    metadataBadges(metadata)

                    if let releaseName = metadata.releaseName {
                        Text(releaseName)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                    }

                    HStack(spacing: 18) {
                        if !metadata.languages.isEmpty {
                            Label(
                                metadata.languages.joined(separator: " · "),
                                systemImage: "captions.bubble"
                            )
                        }

                        if !metadata.audio.isEmpty {
                            Label(
                                metadata.audio.joined(separator: " · "),
                                systemImage: "speaker.wave.2"
                            )
                        }

                        if let providerName = metadata.providerName {
                            Label(
                                providerName,
                                systemImage: "server.rack"
                            )
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                } else if let description = source.description {
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(maxWidth: 1050, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.black.opacity(0.38))
        )
    }

    @ViewBuilder
    private func metadataBadges(
        _ metadata: SourceMetadata
    ) -> some View {
        HStack(spacing: 10) {
            if let resolution = metadata.resolution {
                metadataBadge(resolution)
            }

            if let quality = metadata.quality {
                metadataBadge(quality)
            }

            if let videoCodec = metadata.videoCodec {
                metadataBadge(videoCodec)
            }

            ForEach(metadata.dynamicRange, id: \.self) { value in
                metadataBadge(value)
            }

            if let size = metadata.size {
                metadataBadge(size)
            }

            if let bitrate = metadata.bitrate {
                metadataBadge(bitrate)
            }
        }
    }

    private func metadataBadge(
        _ text: String
    ) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.cyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(.cyan.opacity(0.12))
            )
    }

    @MainActor
    private func loadSources() async {
        isLoading = true
        errorMessage = nil

        guard let baseURL = AppConfiguration.aioStreamsBaseURL else {
            errorMessage = "Er is geen mediabron geconfigureerd."
            isLoading = false
            return
        }

        let provider = AIOStreamsProvider(
            baseURL: baseURL
        )

        do {
            sources = try await provider.sources(
                for: item
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SourceSelectionView(
            item: MediaItem(
                title: "Testfilm",
                type: .movie,
                imdbID: "tt0000000"
            )
        )
    }
}
