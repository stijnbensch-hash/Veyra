import MediaPlayer
import SwiftUI

/// Onzichtbare `MPVolumeView` puur om bij de systeem-volumeslider te
/// kunnen — er is geen publieke Apple-API om het systeemvolume direct te
/// zetten, dit is de gangbare, App Store-veilige omweg (Apple's eigen
/// `MPVolumeView` documentatie noemt dit als bedoeld gebruik). De knop en
/// routekeuze van de view zelf blijven verborgen; alleen de onderliggende
/// `UISlider` wordt gebruikt.
struct SystemVolumeSlider: UIViewRepresentable {
    @Binding var slider: UISlider?

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = false
        view.showsVolumeSlider = true

        DispatchQueue.main.async {
            slider = view.subviews.compactMap { $0 as? UISlider }.first
        }

        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
