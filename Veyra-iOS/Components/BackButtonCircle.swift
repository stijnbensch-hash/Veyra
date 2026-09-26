import SwiftUI

/// Zwevende ronde terug-knop voor detailschermen die de systeem-navigatiebalk
/// verbergen (de "grijze balk" met titel bovenaan) -- clearlogo/hero tonen de
/// titel al, dus die balk is overbodig; dit blijft de enige manier om terug
/// te gaan zonder de balk.
struct BackButtonCircle: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.35), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel("Terug")
    }
}
