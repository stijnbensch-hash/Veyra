import SwiftUI

/// The same full wordmark in Home, service headers and streaming settings.
struct VeyraStreamingWordmark: View {
    let brand: VeyraStreamingBrand
    var color: Color? = nil

    var body: some View {
        Image(brand.assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color ?? Color(red: Double((brand.color >> 16) & 0xFF) / 255,
                                           green: Double((brand.color >> 8) & 0xFF) / 255,
                                           blue: Double(brand.color & 0xFF) / 255))
    }
}
