import SwiftUI
import AetherEngine

struct PlayerView: View {
    let source: PlayableSource
    var item: MediaItem? = nil
    var resumeProgress: Double? = nil

    var body: some View {
        if source.kind == .liveTV {
            LiveTVPlayerRoot(source: source, item: item)
        } else {
            PlayerSessionView(source: source, item: item, resumeProgress: resumeProgress)
        }
    }
}

/// Keeps the guide and favorite order alive while individual channel playback
/// sessions are replaced. A channel change never pushes another player onto
/// the navigation stack.
@MainActor
private struct LiveTVPlayerRoot: View {
    @StateObject private var guide = VeyraEPGStore()
    @State private var activeSource: PlayableSource
    let initialItem: MediaItem?
    let initialSourceID: UUID

    init(source: PlayableSource, item: MediaItem?) {
        _activeSource = State(initialValue: source)
        initialItem = item
        initialSourceID = source.id
    }

    var body: some View {
        ZStack {
            PlayerSessionView(
                source: activeSource,
                item: activeSource.id == initialSourceID
                    ? (initialItem ?? MediaItem(title: activeSource.name, type: .liveTV))
                    : MediaItem(title: activeSource.name, type: .liveTV),
                liveGuide: guide,
                onSelectLiveChannel: { row in
                    guard row.channel.streamURL != activeSource.url else { return }
                    activeSource = guide.play(row)
                }
            )
            .id(activeSource.id)
        }
        .task { await guide.reload() }
    }
}

private struct PlayerSessionView: View {
    @Environment(\.veyraPlayerVisibility)
    private var setPlayerVisible

    @Environment(\.dismiss)
    private var dismiss

    let source: PlayableSource

    var item: MediaItem? = nil

    var resumeProgress: Double? = nil

    var liveGuide: VeyraEPGStore? = nil
    var onSelectLiveChannel: (VeyraGuideChannel) -> Void = { _ in }

    @Environment(\.scenePhase)
    private var scenePhase

    @StateObject
    private var viewModel: PlaybackViewModel

    @State
    private var nextEpisodeRequest: NextPlaybackRequest?

    @State
    private var isResolvingNextEpisode = false

    @State
    private var showErrorGuide = false

    init(
        source: PlayableSource,
        item: MediaItem? = nil,
        resumeProgress: Double? = nil,
        liveGuide: VeyraEPGStore? = nil,
        onSelectLiveChannel: @escaping (VeyraGuideChannel) -> Void = { _ in }
    ) {
        self.source = source
        self.item = item
        self.resumeProgress = resumeProgress
        self.liveGuide = liveGuide
        self.onSelectLiveChannel = onSelectLiveChannel
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

                    if source.kind == .liveTV {
                        IPTVLiveProviderStatusBadge(source: source, item: item)
                    }

                    HStack(spacing: 24) {
                        Button("Sluiten") {
                            dismiss()
                        }
                        .buttonStyle(.card)

                        Button("Opnieuw proberen") {
                            Task { await viewModel.retry() }
                        }
                        .buttonStyle(.card)

                        if liveGuide != nil {
                            Button("Andere zender") {
                                showErrorGuide = true
                            }
                            .buttonStyle(.card)
                        }
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
                    source: source,
                    liveGuide: liveGuide,
                    onSelectLiveChannel: onSelectLiveChannel,
                    onRequestExit: {
                        dismiss()
                    },
                    onUserActivity: {
                        viewModel.registerActivity()
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

                        // Dezelfde bron (provider/resolutie/audio/...)
                        // zoeken voor de volgende aflevering, zodat de
                        // speler gewoon blijft doorspelen i.p.v. terug te
                        // vallen op het bronkeuzescherm. Enkel wanneer daar
                        // niets bij dezelfde provider gevonden wordt, valt
                        // dit terug op SourceSelectionView (zie
                        // `NextPlaybackRequest`/`navigationDestination`
                        // hieronder).
                        isResolvingNextEpisode = true
                        Task {
                            let matchedSource = await NextEpisodeSourceResolver.resolve(
                                matching: source, for: next
                            )
                            isResolvingNextEpisode = false
                            nextEpisodeRequest = NextPlaybackRequest(item: next, source: matchedSource)
                        }
                    }
                )
                .ignoresSafeArea()

            } else {
                VStack(
                    spacing: 16
                ) {
                    ProgressView()

                    Text(
                        isResolvingNextEpisode
                            ? "Volgende aflevering zoeken…"
                            : "Veyra Player starten…"
                    )
                    .font(
                        .system(
                            size: 26
                        )
                    )
                }
            }

            if showErrorGuide, let liveGuide {
                Color.black.opacity(0.6).ignoresSafeArea()
                LivePlayerChannelPanel(
                    guide: liveGuide,
                    currentSource: source,
                    initialFilter: .guide,
                    onSelect: { row in
                        showErrorGuide = false
                        onSelectLiveChannel(row)
                    },
                    onClose: { showErrorGuide = false }
                )
                .focusSection()
                .onExitCommand { showErrorGuide = false }
            }
        }
        .onAppear {
            setPlayerVisible(true)
        }
        .alert("Kijk je nog?", isPresented: Binding(
            get: { viewModel.showStillWatchingPrompt },
            set: { if !$0 { viewModel.registerActivity() } }
        )) {
            Button("Ja, doorgaan") { viewModel.registerActivity() }
        } message: {
            Text("Afspelen stopt zo als er geen reactie komt.")
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
        .navigationDestination(item: $nextEpisodeRequest) { request in
            if let matchedSource = request.source {
                PlayerView(source: matchedSource, item: request.item)
            } else {
                SourceSelectionView(item: request.item)
            }
        }
    }
}

/// Draagt zowel de volgende aflevering als (indien gevonden) de daarbij
/// passende bron door de `navigationDestination`-push heen: met een bron
/// speelt de player meteen door, zonder bron valt dit terug op
/// `SourceSelectionView`, precies zoals wanneer je de aflevering zelf had
/// opgezocht.
private struct NextPlaybackRequest: Identifiable, Hashable {
    let id = UUID()
    let item: MediaItem
    let source: PlayableSource?
}
