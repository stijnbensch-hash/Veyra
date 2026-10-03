import SwiftUI

/// De diensten en knoppen horen bij de scrollende hero. Alleen het beeld loopt
/// onder de statuszone door; de bediening blijft binnen de veilige bovenruimte.
struct VeyraHomeHeroHeader<Hero: View, Services: View, Controls: View>: View {
    let fullscreen: Bool
    var topInset: CGFloat = 0
    @ViewBuilder let hero: () -> Hero
    @ViewBuilder let services: () -> Services
    @ViewBuilder let controls: () -> Controls

    var body: some View {
        if fullscreen {
            hero()
                .overlay(alignment: .top) {
                    VStack(spacing: 0) {
                        services()
                        controls()
                    }
                    .padding(.top, topInset)
                }
        } else {
            VStack(spacing: 0) {
                services()
                hero().overlay(alignment: .top) { controls() }
            }
        }
    }
}
