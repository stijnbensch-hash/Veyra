// VeyraHomeBackground.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Subtiele, permanente, STILSTAANDE globale achtergrond achter heel Home, uit het
// spec "Veyra Home — subtiele globale achtergrond". Los van `VeyraBackground`
// (cyaan/rood gradient+ribbon, elders gebruikt, bv. Settings) zodat andere
// schermen ongemoeid blijven. Geen netwerkrequest: lokale asset
// (`VeyraHomeBackground` in Assets.xcassets, alle drie de targets).
// Laagopbouw (spec): donkere basiskleur -> afbeelding (.scaledToFill, lage
// opacity) -> donkere overlay -> subtiele verticale gradient (donkerder boven/
// onder, lichter in het midden). Geen animatie, geen zware blur, geen parallax
// -- volledig statisch in deze eerste versie (spec: "Niet doen: animatie/
// particles/parallax"). `.allowsHitTesting(false)` zodat dit nooit focus/
// gestures onderschept.
// De bestaande Hero blijft ONGEWIJZIGD op iOS/iPadOS/macOS (boven deze laag in
// de visuele stack); tvOS heeft geen Hero (de context-ribbon vervult die rol).

import SwiftUI

struct VeyraHomeBackground: View {
    var body: some View {
        ZStack {
            Color.black

            Image("VeyraHomeBackground")
                .resizable()
                .scaledToFill()
                .opacity(0.7)

            Color.black.opacity(0.10)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.04),
                    Color.black.opacity(0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
