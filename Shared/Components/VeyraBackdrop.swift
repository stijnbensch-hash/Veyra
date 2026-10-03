import SwiftUI

/// Nachtgloed: donker grafiet met zachte ijsblauwe en robijnrode randgloed.
/// Alleen de achtergrond reageert op scrollen; er zijn geen timers of extra afbeeldingen.
struct VeyraBackground: View {
    var scrollOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let phase = VeyraNightGlow.phase(offset: reduceMotion ? 0 : scrollOffset)
        ZStack {
            Color(red: 7 / 255, green: 11 / 255, blue: 17 / 255)
            EllipticalGradient(colors: [
                VeyraNightGlow.color(from: (10, 69, 93), to: (75, 16, 42), phase: phase).opacity(0.75),
                .clear
            ], center: UnitPoint(x: 0.08, y: 0.12), endRadiusFraction: 0.72)
            EllipticalGradient(colors: [
                VeyraNightGlow.color(from: (75, 16, 42), to: (10, 69, 93), phase: phase).opacity(0.75),
                .clear
            ], center: UnitPoint(x: 1.02, y: 0.91), endRadiusFraction: 0.76)
            EllipticalGradient(colors: [Color(red: 40 / 255, green: 47 / 255, blue: 59 / 255).opacity(0.35), .clear],
                               center: UnitPoint(x: 0.5, y: -0.3), endRadiusFraction: 0.8)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

nonisolated enum VeyraNightGlow {
    /// Een lange, vloeiende kleurcyclus; terugscrollen geeft exact dezelfde kleur terug.
    static func phase(offset: CGFloat) -> Double {
        guard offset.isFinite else { return 0 }
        return (1 - cos(Double(max(0, offset)).truncatingRemainder(dividingBy: 4400) / 2200 * .pi)) / 2
    }

    static func color(from: (Double, Double, Double), to: (Double, Double, Double), phase: Double) -> Color {
        Color(red: (from.0 + (to.0 - from.0) * phase) / 255,
              green: (from.1 + (to.1 - from.1) * phase) / 255,
              blue: (from.2 + (to.2 - from.2) * phase) / 255)
    }

    static func sampledOffset(_ offset: CGFloat) -> CGFloat {
        guard offset.isFinite else { return 0 }
        return (max(0, offset) / 8).rounded(.down) * 8
    }
}

private struct VeyraBackgroundScrollSpaceKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

private extension EnvironmentValues {
    var veyraBackgroundScrollSpace: UUID? {
        get { self[VeyraBackgroundScrollSpaceKey.self] }
        set { self[VeyraBackgroundScrollSpaceKey.self] = newValue }
    }
}

private struct VeyraBackgroundScrollPreference: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

/// Meet alleen op oudere systemen zonder ScrollGeometry. De achtergrond bepaalt de ruimte.
struct VeyraScrollPositionReader: View {
    @Environment(\.veyraBackgroundScrollSpace) private var space
    var body: some View {
        if let space {
            GeometryReader { geometry in
                Color.clear.preference(key: VeyraBackgroundScrollPreference.self,
                                       value: [space: geometry.frame(in: .named(space)).minY])
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

private struct VeyraScrollingBackgroundModifier: ViewModifier {
    @State private var offset: CGFloat = 0
    @State private var space = UUID()
    @State private var initialTop: CGFloat?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18, tvOS 18, macOS 15, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    VeyraNightGlow.sampledOffset(geometry.contentOffset.y + geometry.contentInsets.top)
                } action: { _, value in
                    offset = value
                }
                .background(VeyraBackground(scrollOffset: offset))
        } else {
            content
                .coordinateSpace(name: space)
                .environment(\.veyraBackgroundScrollSpace, space)
                .onPreferenceChange(VeyraBackgroundScrollPreference.self) { values in
                    guard let top = values[space], top.isFinite else { return }
                    if initialTop == nil { initialTop = top }
                    let value = VeyraNightGlow.sampledOffset((initialTop ?? top) - top)
                    if offset != value { offset = value }
                }
                .background(VeyraBackground(scrollOffset: offset))
        }
    }
}

extension View {
    /// Aan de verticale ScrollView hangen; horizontale kaartenrijen sturen de kleuren niet aan.
    func veyraScrollingBackground() -> some View {
        modifier(VeyraScrollingBackgroundModifier())
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
    var maxPixelSize = 1920
    @State private var isBreathing = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                VeyraBackground()
                VeyraAsyncImage(url: url, maxPixelSize: maxPixelSize) { image in
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

/// Alleen artwork binnen de hero; de achtergrond volgt de hoogte van de inhoud.
/// Knip alleen de achtergrond af, zodat tvOS-focus en actieknoppen vrij blijven.
struct VeyraHeroArtworkBackground: View {
    let url: URL?
    /// Extra hoogte waarover de achtergrond na de hero zelf nog doorloopt en
    /// vervaagt naar de effen achtergrondkleur -- zonder dit stopt de
    /// afbeelding precies op de onderrand van de hero en voelt die overgang
    /// bruusk aan. Zelfde aanpak als de ambient-bleed van de Home-hero
    /// (VeyraHeroAmbientBackdrop), alleen hier als `.background` van de
    /// hero zelf i.p.v. een aparte laag erachter.
    var bleed: CGFloat = 160

    var body: some View {
        GeometryReader { geometry in
            VeyraArtworkBackground(url: url)
                .frame(width: geometry.size.width, height: geometry.size.height + bleed)
                .clipped()
        }
        // Bewust GEEN `.clipped()` op de GeometryReader zelf: dat zou de
        // extra `bleed`-hoogte hierboven meteen weer afsnijden. De breedte
        // ligt al vast via het expliciete `.frame(width:)` hierboven.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
