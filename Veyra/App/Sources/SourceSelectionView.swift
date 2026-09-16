import SwiftUI

struct SourceSelectionView: View {
    let item: MediaItem

    @State private var sources: [PlayableSource] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let provider = MockMediaSourceProvider()

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

            VStack(alignment: .leading, spacing: 35) {
                Text("SELECT SOURCE")
                    .font(.system(size: 46, weight: .light))
                    .tracking(10)
                    .foregroundStyle(.white)

                Text(item.title)
                    .font(.title2)
                    .foregroundStyle(.secondary)

                if isLoading {
                    ProgressView("Finding sources…")
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                } else if sources.isEmpty {
                    Text("No sources available")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(sources) { source in
                            NavigationLink {
                                PlayerView(source: source)
                            } label: {
                                HStack(spacing: 24) {
                                    Image(systemName: "play.fill")

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(source.name)
                                            .font(.title3)

                                        Text(source.kind.rawValue.uppercased())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .frame(width: 700)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(70)
        }
        .task {
            await loadSources()
        }
    }

    @MainActor
    private func loadSources() async {
        isLoading = true
        errorMessage = nil

        do {
            sources = try await provider.sources(for: item)
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
                type: .movie
            )
        )
    }
}
