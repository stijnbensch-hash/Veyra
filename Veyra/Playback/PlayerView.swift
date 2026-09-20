import SwiftUI
import AetherEngine

struct PlayerView: View {
    @Environment(\.veyraPlayerVisibility)
    private var setPlayerVisible

    @Environment(\.dismiss)
    private var dismiss

    let source: PlayableSource

    var item: MediaItem? = nil

    var resumeProgress: Double? = nil

    @Environment(\.scenePhase)
    private var scenePhase

    @StateObject
    private var viewModel: PlaybackViewModel

    @State
    private var nextEpisodeRequest: MediaItem?

    init(source: PlayableSource, item: MediaItem? = nil, resumeProgress: Double? = nil) {
        self.source = source
        self.item = item
        self.resumeProgress = resumeProgress
        _viewModel = StateObject(
            wrappedValue: PlaybackViewModel(
                source: source,
                item: item,
                resumeProgress: resumeProgress
            )
        )
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let playbackError = viewModel.playbackError {
                VStack(
                    spacing: 20
                ) {
                    Text(
                        "Afspelen niet mogelijk"
                    )
                    .font(
                        .system(
                            size: 34,
                            weight: .bold
                        )
                    )

                    Text(
                        playbackError
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .font(
                        .system(
                            size: 22
                        )
                    )
                }
                .padding(50)

            } else if let playbackEngine = viewModel.playbackEngine {
                AetherPlayerSurface(
                    engine:
                        playbackEngine.engine
                )
                .ignoresSafeArea()

                PlayerSubtitleControls(
                    engine:
                        playbackEngine.engine,
                    title:
                        item?.title,
                    item: item,
                    onRequestExit: {
                        dismiss()
                    },
                    onPlayNextEpisode: { next in
                        nextEpisodeRequest = next
                    }
                )
                .ignoresSafeArea()

            } else {
                VStack(
                    spacing: 16
                ) {
                    ProgressView()

                    Text(
                        "Veyra Player starten…"
                    )
                    .font(
                        .system(
                            size: 26
                        )
                    )
                }
            }
        }
        .onAppear {
            setPlayerVisible(true)
        }
        .task {
            await viewModel.startPlayback()
        }
        .onDisappear {
            setPlayerVisible(false)
            viewModel.stopForDisappear()
        }
        .onChange(
            of: scenePhase
        ) { _, phase in
            viewModel.handleScenePhaseChange(phase)
        }
        .navigationDestination(item: $nextEpisodeRequest) { next in
            SourceSelectionView(item: next)
        }
    }
}
