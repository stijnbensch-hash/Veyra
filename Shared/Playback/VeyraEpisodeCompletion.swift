import SwiftUI
import AetherEngine

/// The originating source picker owns the whole episode playback branch, including
/// any players opened by autoplay. Returning removes that branch in one action.
private struct VeyraEpisodeReturnKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> Void)? = nil
}

extension EnvironmentValues {
    var veyraEpisodeReturn: (@MainActor () -> Void)? {
        get { self[VeyraEpisodeReturnKey.self] }
        set { self[VeyraEpisodeReturnKey.self] = newValue }
    }
}

/// Handles a real end-of-file event, independently of the optional credits countdown.
/// Keeping the engine alive until this action lets the watch trackers record .ended.
private struct VeyraEpisodeCompletionModifier: ViewModifier {
    @ObservedObject var engine: AetherEngine
    let item: MediaItem?
    let isLive: Bool
    let nextEpisode: MediaItem?
    let nextEpisodeResolved: Bool
    let autoAdvanceCancelled: Bool
    let onNext: (MediaItem) -> Void
    let onReturn: () -> Void

    @AppStorage(PlaybackSettingsDefaults.autoPlayNextEpisodeKey)
    private var autoplay = true
    @State private var handled = false

    func body(content: Content) -> some View {
        content
            .onChange(of: engine.state, initial: true) { _, _ in handleEnd() }
            .onChange(of: nextEpisodeResolved) { _, _ in handleEnd() }
            .onChange(of: autoplay) { _, _ in handleEnd() }
            .onChange(of: autoAdvanceCancelled) { _, _ in handleEnd() }
    }

    private func handleEnd() {
        guard !handled, !isLive, engine.state == .ended,
              item?.type == .series, item?.seasonNumber != nil,
              item?.episodeNumber != nil else { return }
        // Autoplay off must return immediately, even if the metadata lookup hangs.
        if !autoplay || autoAdvanceCancelled {
            handled = true
            onReturn()
        } else if nextEpisodeResolved {
            handled = true
            if let nextEpisode { onNext(nextEpisode) }
            else { onReturn() }
        }
    }
}

extension View {
    func veyraEpisodeCompletion(
        engine: AetherEngine, item: MediaItem?, isLive: Bool,
        nextEpisode: MediaItem?, nextEpisodeResolved: Bool,
        autoAdvanceCancelled: Bool,
        onNext: @escaping (MediaItem) -> Void, onReturn: @escaping () -> Void
    ) -> some View {
        modifier(VeyraEpisodeCompletionModifier(
            engine: engine, item: item, isLive: isLive,
            nextEpisode: nextEpisode, nextEpisodeResolved: nextEpisodeResolved,
            autoAdvanceCancelled: autoAdvanceCancelled,
            onNext: onNext, onReturn: onReturn
        ))
    }
}
