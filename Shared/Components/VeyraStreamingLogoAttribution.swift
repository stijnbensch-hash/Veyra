import SwiftUI

/// Attribution supplied with the adapted CC BY wordmark, on every platform.
struct VeyraStreamingLogoAttribution: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("VTM GO-logo: DPG Media · aangepast voor weergave in Veyra.")
            Text("Bron: [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:VTM_Go_logo_2024.svg) · [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .tint(VeyraColors.cyan)
    }
}
