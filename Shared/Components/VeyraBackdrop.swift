import SwiftUI

struct VeyraBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VeyraColors.background
                LinearGradient(
                    colors: [
                        VeyraColors.cyan.opacity(0.12),
                        .clear,
                        VeyraColors.red.opacity(0.11)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(colors: [VeyraColors.cyan.opacity(0.22), .clear], center: .bottomLeading,
                               startRadius: 0, endRadius: geometry.size.width * 0.62)
                RadialGradient(colors: [VeyraColors.red.opacity(0.19), .clear], center: .topTrailing,
                               startRadius: 0, endRadius: geometry.size.width * 0.58)

                VeyraLightRibbon(color: VeyraColors.cyan)
                    .frame(width: geometry.size.width * 0.56, height: 170)
                    .rotationEffect(.degrees(-29))
                    .offset(x: -geometry.size.width * 0.36, y: geometry.size.height * 0.32)

                VeyraLightRibbon(color: VeyraColors.red)
                    .frame(width: geometry.size.width * 0.52, height: 150)
                    .rotationEffect(.degrees(31))
                    .offset(x: geometry.size.width * 0.36, y: -geometry.size.height * 0.30)
            }
        }.ignoresSafeArea()
    }
}


/// Effen, iets grijzere achtergrond (i.p.v. cyaan/rood of puur zwart) voor
/// de rustende Home-achtergrond.
struct VeyraPlainBackground: View {
    var body: some View {
        Color(white: 0.085).ignoresSafeArea()
    }
}

private struct VeyraLightRibbon: View {
    let color: Color

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.clear, color.opacity(0.18), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .blur(radius: 34)
            .allowsHitTesting(false)
    }
}

/// One bounded image for the hero and the artwork behind the navigation.
///
/// "Living Backdrop": in plaats van een volledig statisch beeld drijft de artwork heel
/// traag en subtiel in en uit (Ken Burns-effect) zodat het scherm nooit helemaal stilstaat
/// -- en wanneer de URL verandert (bv. een andere hero roteert in beeld) glijdt/zoomt het
/// nieuwe beeld zacht in i.p.v. hard te wisselen.
struct VeyraArtworkBackground: View {
    let url: URL?
    @State private var isBreathing = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                VeyraBackground()
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Color.clear }
                .frame(width: geometry.size.width, height: min(geometry.size.height, 900))
                .scaleEffect(isBreathing ? 1.05 : 1.0)
                .clipped()
                .saturation(0.90)
                .contrast(1.06)
                LinearGradient(stops: [.init(color: VeyraColors.background.opacity(0.96), location: 0),
                                       .init(color: VeyraColors.background.opacity(0.50), location: 0.40),
                                       .init(color: VeyraColors.red.opacity(0.05), location: 0.78)], startPoint: .leading, endPoint: .trailing)
                LinearGradient(stops: [.init(color: .clear, location: 0.3),
                                       .init(color: VeyraColors.background.opacity(0.7), location: 0.66),
                                       .init(color: VeyraColors.background, location: 0.94)], startPoint: .top, endPoint: .bottom)
            }
            .id(url)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.045)),
                removal: .opacity
            ))
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
        .animation(.easeInOut(duration: 0.5), value: url)
    }
}
