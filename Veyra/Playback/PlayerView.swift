import SwiftUI
import AetherEngine

struct PlayerView: View {
    let engine: AetherEngine

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            AetherPlayerSurface(engine: engine)
                .ignoresSafeArea()
        }
    }
}
