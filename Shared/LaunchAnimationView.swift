import SwiftUI

/// Openingsanimatie bij het opstarten van Veyra: het beeldmerk verschijnt,
/// blijft eventjes staan, en vliegt dan weg om plaats te maken voor de app
/// zelf. Gebruikt hetzelfde beeldmerk als het app-icoon (`LaunchBrandmark`
/// in Assets.xcassets — een uitgesneden versie met transparante
/// achtergrond, zodat het naadloos over `VeyraColors.background` valt).
///
/// Draait één keer per koude start: de App-structs op iOS en tvOS tonen dit
/// als overlay boven `ContentView` en verbergen het via `onFinished`. Omdat
/// SwiftUI's `@State` in de App-struct blijft bestaan zolang het proces
/// leeft, komt de animatie niet terug bij achtergrond/voorgrond-wissels —
/// alleen bij een echte herstart.
struct LaunchAnimationView: View {
    var onFinished: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.86
    @State private var glowOpacity: Double = 0
    @State private var wordmarkOpacity: Double = 0
    @State private var taglineOpacity: Double = 0

    @State private var flightOffset: CGSize = .zero
    @State private var flightScale: CGFloat = 1
    @State private var flightRotation: Angle = .zero
    @State private var flightOpacity: Double = 1

    @State private var overlayOpacity: Double = 1

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            RadialGradient(
                colors: [VeyraColors.cyan.opacity(glowOpacity * 0.35), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 260
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 18) {
                Image("LaunchBrandmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .opacity(logoOpacity * flightOpacity)
                    .scaleEffect(logoScale * flightScale)
                    .rotationEffect(flightRotation)
                    .offset(flightOffset)

                VStack(spacing: 6) {
                    Text("VEYRA")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .tracking(8)
                        .foregroundStyle(.white)
                        .opacity(wordmarkOpacity)

                    Text("ALL YOUR MEDIA. ONE PLACE.")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(3)
                        .foregroundStyle(VeyraColors.secondary)
                        .opacity(taglineOpacity)
                }
            }
        }
        .opacity(overlayOpacity)
        .allowsHitTesting(overlayOpacity > 0)
        .task { await runSequence() }
    }

    @MainActor
    private func runSequence() async {
        guard !reduceMotion else {
            await runReducedMotionSequence()
            return
        }

        // 1. Beeldmerk en gloed verschijnen.
        withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
            logoOpacity = 1
            logoScale = 1
        }
        withAnimation(.easeOut(duration: 0.9)) {
            glowOpacity = 1
        }

        try? await Task.sleep(for: .seconds(0.35))
        withAnimation(.easeOut(duration: 0.5)) { wordmarkOpacity = 1 }

        try? await Task.sleep(for: .seconds(0.15))
        withAnimation(.easeOut(duration: 0.5)) { taglineOpacity = 1 }

        // 2. Even laten staan.
        try? await Task.sleep(for: .seconds(0.7))

        // 3. Het beeldmerk vliegt weg: omhoog en opzij, kleiner wordend,
        // lichtjes draaiend — zoals een vogel die wegschiet. Wordmerk en
        // tagline vervagen tegelijk.
        withAnimation(.easeIn(duration: 0.6)) {
            wordmarkOpacity = 0
            taglineOpacity = 0
            glowOpacity = 0
        }
        withAnimation(.easeIn(duration: 0.75)) {
            flightOffset = CGSize(width: 130, height: -260)
            flightScale = 0.35
            flightRotation = .degrees(18)
            flightOpacity = 0
        }

        try? await Task.sleep(for: .seconds(0.55))
        withAnimation(.easeIn(duration: 0.3)) { overlayOpacity = 0 }
        try? await Task.sleep(for: .seconds(0.3))

        onFinished()
    }

    /// Eenvoudige fade in/uit zonder beweging, voor "Beweging beperken".
    @MainActor
    private func runReducedMotionSequence() async {
        withAnimation(.easeOut(duration: 0.4)) {
            logoOpacity = 1
            wordmarkOpacity = 1
            taglineOpacity = 1
            glowOpacity = 1
        }

        try? await Task.sleep(for: .seconds(0.9))

        withAnimation(.easeIn(duration: 0.35)) {
            overlayOpacity = 0
        }

        try? await Task.sleep(for: .seconds(0.35))
        onFinished()
    }
}

#Preview {
    LaunchAnimationView()
}
