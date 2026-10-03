import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Nachtgloed: donker grafiet met zachte ijsblauwe en robijnrode randgloed.
/// Alleen de achtergrond reageert op scrollen; er zijn geen timers of extra afbeeldingen.
struct VeyraBackground: View {
    var scrollOffset: CGFloat? = nil
    @Environment(\.veyraPageBackgroundOffset) private var pageOffset
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let phase = VeyraNightGlow.phase(offset: reduceMotion ? 0 : (scrollOffset ?? pageOffset))
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

private struct VeyraPageBackgroundOffsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct VeyraPageBackgroundScopeKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var veyraPageBackgroundOffset: CGFloat {
        get { self[VeyraPageBackgroundOffsetKey.self] }
        set { self[VeyraPageBackgroundOffsetKey.self] = newValue }
    }
    var veyraHasPageBackgroundScope: Bool {
        get { self[VeyraPageBackgroundScopeKey.self] }
        set { self[VeyraPageBackgroundScopeKey.self] = newValue }
    }
}

private struct VeyraPageBackgroundPreference: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

/// Een eigen scrollkleur per pagina of sheet, zonder globale toestand.
/// Onderliggende detailpagina's geven hun scrollpositie niet door aan de vorige pagina.
struct VeyraDynamicBackgroundScope<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var offset: CGFloat = 0

    var body: some View {
        content()
            .environment(\.veyraPageBackgroundOffset, offset)
            .environment(\.veyraHasPageBackgroundScope, true)
            .background(VeyraBackground(scrollOffset: offset))
            .onPreferenceChange(VeyraPageBackgroundPreference.self) { values in
                let next = values.values.max() ?? 0
                if offset != next { offset = next }
            }
            .transformPreference(VeyraPageBackgroundPreference.self) { $0.removeAll() }
    }
}

/// Horizontale rijen blijven gewone scrollviews. Alleen verticale pagina's sturen de kleur.
struct VeyraScrollView<Content: View>: View {
    var axes: Axis.Set = .vertical
    var showsIndicators = true
    @ViewBuilder let content: () -> Content

    init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true,
         @ViewBuilder content: @escaping () -> Content) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content
    }

    @ViewBuilder var body: some View {
        if axes.contains(.vertical) {
            ScrollView(axes, showsIndicators: showsIndicators) {
                content().background(VeyraScrollPositionReader())
            }
            .veyraScrollingBackground()
        } else {
            ScrollView(axes, showsIndicators: showsIndicators, content: content)
        }
    }
}

struct VeyraList<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        List(content: content)
            // `.scrollContentBackground(.hidden)` bestaat niet op tvOS --
            // op tvOS wordt de achtergrond al transparant gemaakt via
            // `UITableView.appearance().backgroundColor = .clear` in
            // `VeyraApp.swift`'s `init()`.
            #if os(iOS)
            .scrollContentBackground(.hidden)
            #endif
            .veyraScrollingBackground(legacyList: true)
    }
}

struct VeyraForm<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        Form(content: content)
            .formStyle(.grouped)
            // `.scrollContentBackground(.hidden)` bestaat niet op tvOS --
            // op tvOS wordt de achtergrond al transparant gemaakt via
            // `UITableView.appearance().backgroundColor = .clear` in
            // `VeyraApp.swift`'s `init()`.
            #if os(iOS)
            .scrollContentBackground(.hidden)
            #endif
            .veyraScrollingBackground(legacyList: true)
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
    var legacyList = false
    @State private var offset: CGFloat = 0
    @State private var space = UUID()
    @State private var initialTop: CGFloat?
    @Environment(\.veyraHasPageBackgroundScope) private var hasPageScope
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18, tvOS 18, macOS 15, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    reduceMotion ? 0 : VeyraNightGlow.sampledOffset(geometry.contentOffset.y + geometry.contentInsets.top)
                } action: { _, value in
                    offset = value
                }
                .preference(key: VeyraPageBackgroundPreference.self, value: [space: offset])
                .background {
                    if !hasPageScope { VeyraBackground(scrollOffset: offset) }
                }
        } else {
            content
                .coordinateSpace(name: space)
                .environment(\.veyraBackgroundScrollSpace, space)
                .onPreferenceChange(VeyraBackgroundScrollPreference.self) { values in
                    guard let top = values[space], top.isFinite else { return }
                    if initialTop == nil { initialTop = top }
                    let value = reduceMotion ? 0 : VeyraNightGlow.sampledOffset((initialTop ?? top) - top)
                    if offset != value { offset = value }
                }
                .background {
                    #if os(macOS)
                    if legacyList {
                        VeyraLegacyListScrollReader { value in
                            let next = reduceMotion ? 0 : VeyraNightGlow.sampledOffset(value)
                            if offset != next { offset = next }
                        }
                    }
                    #endif
                }
                .preference(key: VeyraPageBackgroundPreference.self, value: [space: offset])
                .background {
                    if !hasPageScope { VeyraBackground(scrollOffset: offset) }
                }
        }
    }
}

#if os(macOS)
/// macOS 14 List/Form use an AppKit clip view. Observe its public bounds notification;
/// no polling, and the observer is removed when the page leaves the hierarchy.
private struct VeyraLegacyListScrollReader: NSViewRepresentable {
    var onOffset: (CGFloat) -> Void
    func makeNSView(context: Context) -> VeyraLegacyListScrollProbe {
        let view = VeyraLegacyListScrollProbe()
        view.onOffset = onOffset
        return view
    }
    func updateNSView(_ view: VeyraLegacyListScrollProbe, context: Context) {
        view.onOffset = onOffset
        view.connect()
    }
    static func dismantleNSView(_ view: VeyraLegacyListScrollProbe, coordinator: ()) {
        view.disconnect()
    }
}

private final class VeyraLegacyListScrollProbe: NSView {
    var onOffset: ((CGFloat) -> Void)?
    private weak var clip: NSClipView?
    private var observation: NSObjectProtocol?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { disconnect() }
        else { DispatchQueue.main.async { [weak self] in self?.connect() } }
    }
    override func layout() {
        super.layout()
        connect()
    }
    func connect() {
        guard window != nil, clip == nil else { return }
        func scrollView(in view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView { return scroll }
            for child in view.subviews {
                if let scroll = scrollView(in: child) { return scroll }
            }
            return nil
        }
        var ancestor = superview
        while let view = ancestor {
            if let scroll = scrollView(in: view) {
                let content = scroll.contentView
                clip = content
                content.postsBoundsChangedNotifications = true
                observation = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification, object: content, queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.report() }
                }
                report()
                return
            }
            ancestor = view.superview
        }
    }
    private func report() {
        guard let clip, let document = clip.documentView else { return }
        let value = document.isFlipped
            ? clip.bounds.minY - document.frame.minY
            : document.frame.maxY - clip.bounds.maxY
        onOffset?(max(0, value))
    }
    func disconnect() {
        if let observation { NotificationCenter.default.removeObserver(observation) }
        observation = nil
        clip = nil
    }
}
#endif

extension View {
    /// Laat artwork én de donkere tekstlaag vloeiend overgaan in de pagina-achtergrond.
    /// Ook toepasbaar op een gezamenlijke afbeelding/trailer-laag.
    func veyraHeroBackdropBlend() -> some View {
        overlay {
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.35),
                .init(color: .black.opacity(0.35), location: 0.65),
                .init(color: .black.opacity(0.65), location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
        .mask {
            LinearGradient(stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 0.55),
                .init(color: .black.opacity(0.85), location: 0.7),
                .init(color: .black.opacity(0.3), location: 0.9),
                .init(color: .clear, location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    /// Aan de verticale ScrollView hangen; horizontale kaartenrijen sturen de kleuren niet aan.
    func veyraScrollingBackground(legacyList: Bool = false) -> some View {
        modifier(VeyraScrollingBackgroundModifier(legacyList: legacyList))
    }
}

/// Compatibility name: older layouts also use the shared dynamic page background.
struct VeyraPlainBackground: View {
    var body: some View {
        VeyraBackground()
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
            }
            .veyraHeroBackdropBlend()
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
    /// Dezelfde transparante overgang als op Home, in een kortere band
    /// onder de catalogus-hero. De vaste hero-layout blijft ongewijzigd.
    var bleed: CGFloat = 160

    var body: some View {
        GeometryReader { geometry in
            VeyraHeroAmbientBackdrop(url: url,
                                     id: url?.absoluteString ?? "catalog-hero",
                                     height: geometry.size.height,
                                     bleed: bleed)
                .frame(width: geometry.size.width)
        }
        // Bewust GEEN `.clipped()` op de GeometryReader zelf: dat zou de
        // extra `bleed`-hoogte hierboven meteen weer afsnijden. De breedte
        // ligt al vast via het expliciete `.frame(width:)` hierboven.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
