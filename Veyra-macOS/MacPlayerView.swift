import SwiftUI
import AetherEngine

struct PlayerView: View {
    let source: PlayableSource
    var item: MediaItem? = nil
    var resumeProgress: Double? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlaybackViewModel

    init(source: PlayableSource, item: MediaItem? = nil, resumeProgress: Double? = nil) {
        self.source = source
        self.item = item
        self.resumeProgress = resumeProgress
        _viewModel = StateObject(wrappedValue: PlaybackViewModel(
            source: source, item: item, resumeProgress: resumeProgress
        ))
    }

    var body: some View {
        ZStack {
            Color.black

            if let message = viewModel.playbackError {
                ContentUnavailableView("Afspelen niet mogelijk", systemImage: "play.slash", description: Text(message))
                    .overlay(alignment: .bottom) {
                        Button("Opnieuw proberen") { Task { await viewModel.retry() } }
                            .padding()
                    }
            } else if let playbackEngine = viewModel.playbackEngine {
                MacPlayerSurface(engine: playbackEngine.engine, title: item?.title ?? source.name)
            } else {
                ProgressView("Veyra Player starten…")
                    .controlSize(.large)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Sluiten", systemImage: "xmark") { dismiss() }
            }
        }
        .task { await viewModel.startPlayback() }
        .onDisappear { viewModel.stopForDisappear() }
        .frame(minWidth: 680, minHeight: 440)
    }
}

private struct MacPlayerSurface: View {
    @ObservedObject var engine: AetherEngine
    let title: String

    @State private var seekPosition: Double = 0
    @State private var isSeeking = false

    private var canSeek: Bool { engine.duration.isFinite && engine.duration > 0 }

    var body: some View {
        VStack(spacing: 0) {
            AetherPlayerSurface(engine: engine)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)

            VStack(spacing: 10) {
                if canSeek {
                    HStack {
                        Text(formatTime(isSeeking ? seekPosition : engine.currentTime))
                        Slider(value: $seekPosition, in: 0...max(engine.duration, 1)) { editing in
                            isSeeking = editing
                            if !editing { Task { await engine.seek(to: seekPosition) } }
                        }
                        Text(formatTime(engine.duration))
                    }
                    .font(.caption.monospacedDigit())
                    .onChange(of: engine.currentTime) { _, time in
                        if !isSeeking { seekPosition = max(0, time) }
                    }
                }

                HStack(spacing: 18) {
                    Text(title).font(.headline).lineLimit(1)
                    Spacer()
                    Button { Task { await engine.seek(to: max(0, engine.currentTime - 10)) } } label: {
                        Image(systemName: "gobackward.10")
                    }
                    .disabled(!canSeek)
                    Button {
                        if engine.state == .playing { engine.pause() } else { engine.play() }
                    } label: {
                        Image(systemName: engine.state == .playing ? "pause.fill" : "play.fill")
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    Button { Task { await engine.seek(to: min(engine.duration, engine.currentTime + 10)) } } label: {
                        Image(systemName: "goforward.10")
                    }
                    .disabled(!canSeek)

                    Menu {
                        Button("Uit") { engine.selectSubtitleTrack(index: -1) }
                        ForEach(engine.subtitleTracks) { track in
                            Button(track.name) { engine.selectSubtitleTrack(index: track.id) }
                        }
                    } label: { Image(systemName: "captions.bubble") }
                    .help("Ondertitels")

                    Menu {
                        ForEach(engine.audioTracks) { track in
                            Button(track.name) { engine.selectAudioTrack(index: track.id) }
                        }
                    } label: { Image(systemName: "speaker.wave.2") }
                    .help("Audiospoor")
                }
                .buttonStyle(.borderless)
            }
            .padding(16)
            .background(.black.opacity(0.92))
        }
        .foregroundStyle(.white)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let value = max(0, Int(seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
