import SwiftUI
import AVKit
import AetherEngine

struct MacAirPlayButton: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        AVRoutePickerView(frame: .zero)
    }

    func updateNSView(_ view: AVRoutePickerView, context: Context) {}
}

@MainActor
final class MacPictureInPictureController: NSObject, ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var isActive = false

    private weak var engine: AetherEngine?
    private var controller: AVPictureInPictureController?
    private var attachedLayer: AVPlayerLayer?

    func attach(engine: AetherEngine) {
        self.engine = engine
        guard AVPictureInPictureController.isPictureInPictureSupported(),
              let layer = engine.nativePlayerLayer else {
            isAvailable = false
            return
        }
        if attachedLayer === layer, controller != nil {
            isAvailable = true
            return
        }
        guard let controller = AVPictureInPictureController(playerLayer: layer) else {
            isAvailable = false
            return
        }
        controller.delegate = self
        self.controller = controller
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

extension MacPictureInPictureController: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isActive = true
            self?.engine?.pictureInPictureActive = true
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isActive = false
            self?.engine?.pictureInPictureActive = false
        }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        Task { @MainActor [weak self] in self?.isActive = false }
    }
}
