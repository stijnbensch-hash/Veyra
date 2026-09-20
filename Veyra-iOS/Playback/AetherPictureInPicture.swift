import AVKit
import AetherEngine
import Combine

/// Bouwt en beheert een `AVPictureInPictureController` bovenop de native
/// laag die `AetherEngine` blootlegt (`engine.nativePlayerLayer`). PiP is
/// alleen beschikbaar op het native (AVPlayer-gebaseerde) afspeelpad — bij
/// software-decodering is `nativePlayerLayer` `nil` en blijft de knop
/// verborgen (`isAvailable = false`).
///
/// `engine.pictureInPictureActive` is de vlag die de engine zelf gebruikt
/// om te beslissen of de sessie actief mag blijven op de achtergrond; deze
/// controller houdt die synchroon met de echte PiP-status via het
/// delegate.
@MainActor
final class AetherPictureInPictureController: NSObject, ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var isActive = false

    private weak var engine: AetherEngine?
    private var controller: AVPictureInPictureController?
    private var attachedLayer: AVPlayerLayer?

    /// Probeert (opnieuw) te koppelen aan de huidige native laag. Veilig om
    /// meermaals aan te roepen — bv. zodra `hasFirstFrameReadyForDisplay`
    /// omslaat, wanneer de laag er de eerste keer nog niet was.
    func attach(engine: AetherEngine) {
        self.engine = engine

        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            isAvailable = false
            return
        }

        guard let layer = engine.nativePlayerLayer else {
            isAvailable = false
            return
        }

        // Al gekoppeld aan dezelfde laag: niets te doen.
        if attachedLayer === layer, controller != nil {
            isAvailable = true
            return
        }

        let newController = AVPictureInPictureController(playerLayer: layer)
        newController.delegate = self
        controller = newController
        attachedLayer = layer
        isAvailable = true
    }

    func toggle() {
        guard let controller else { return }
        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
        } else {
            controller.startPictureInPicture()
        }
    }
}

extension AetherPictureInPictureController: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor [weak self] in
            self?.isActive = true
            self?.engine?.pictureInPictureActive = true
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor [weak self] in
            self?.isActive = false
            self?.engine?.pictureInPictureActive = false
        }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.isActive = false
        }
    }
}
