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

                    HStack(spacing: 24) {
                        Button("Sluiten") {
                            dismiss()
                        }
                        .buttonStyle(.card)

                        Button("Opnieuw proberen") {
                            Task { await viewModel.retry() }
                        }
                        .buttonStyle(.card)
                    }
                    .padding(.top, 12)
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
                    sourceMetadata: source.metadata,
                    onRequestExit: {
                        dismiss()
                    },
                    onPlayNextEpisode: { next in
                        // Stop de tracker/engine van de HUIDIGE aflevering
                        // hier expliciet, i.p.v. te wachten op onDisappear
                        // (dat bij een push naar de volgende afspeler niet
                        // betrouwbaar/direct afgaat) — anders wordt de
                        // net afgelopen aflevering niet als "bekeken"
                        // geregistreerd bij Trakt wanneer je op "Volgende"
                        // drukt i.p.v. de aflevering te laten uitspelen.
                        viewModel.stopForDisappear()
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
