import SwiftUI

struct SourceSelectionView: View {
    let item: MediaItem

    @State private var sources: [PlayableSource] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.04, blue: 0.07),
                    Color(red: 0.02, green: 0.10, blue: 0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("SELECT SOURCE")
                        .font(.system(size: 42, weight: .light))
                        .tracking(9)
                        .foregroundStyle(.white)

                    Text(item.title)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.65))
                }

                if isLoading {
                    Spacer()

                    HStack {
                        Spacer()

                        ProgressView("Finding sources…")
                            .font(.title3)

                        Spacer()
                    }

                    Spacer()
                } else if let errorMessage {
                    Spacer()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Unable to load sources")
                            .font(.title2)
                            .foregroundStyle(.white)

                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                } else if sources.isEmpty {
                    Spacer()

                    Text("No sources available")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Spacer()
                } else {
                    Text("\(sources.count) SOURCES")
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

            VStack(alignment: .leading, spacing: 8) {
                Text(source.name)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(source.kind.rawValue.uppercased())
                    .font(.caption)
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.5))
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
                .fill(.white.opacity(0.06))
        )
    }

    @MainActor
    private func loadSources() async {
        isLoading = true
        errorMessage = nil

        guard let baseURL = AppConfiguration.aioStreamsBaseURL else {
            errorMessage = "No media provider is configured."
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
                title: "Test Movie",
                type: .movie,
                imdbID: "tt0000000"
            )
        )
    }
}
