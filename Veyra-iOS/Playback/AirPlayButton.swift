import AVKit
import SwiftUI

/// Systeem-AirPlay-knop (`AVRoutePickerView`). Werkt met elke `AVPlayer`,
/// dus zonder verdere koppeling aan `AetherEngine` — AirPlay is een
/// systeemroute-keuze, geen speler-specifieke functie.
struct AirPlayButton: UIViewRepresentable {
    var tintColor: UIColor = .white

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = tintColor
        view.activeTintColor = UIColor(VeyraColors.cyan)
        view.prioritizesVideoDevices = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tintColor
    }
}
