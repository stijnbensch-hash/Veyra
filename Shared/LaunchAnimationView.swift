import SwiftUI

/// A short, full-screen brand reveal shared by iOS and tvOS.
/// The app content is already loading underneath this view.
struct LaunchAnimationView: View {
    var onFinished: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var started = false
    @State private var markOpacity: Double = 0
    @State private var markScale: CGFloat = 0.94
    @State private var nameOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var overlayOpacity: Double = 1

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let wide = size.width > size.height
            let markWidth = wide
                ? min(size.width * 0.27, 500)
                : min(size.width * 0.58, 270)

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.025, green: 0.045, blue: 0.075),
                        Color(red: 0.045, green: 0.075, blue: 0.115),
                        Color(red: 0.012, green: 0.025, blue: 0.045)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: wide ? 20 : 15) {
                    Image("LaunchBrandmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: markWidth, height: markWidth * 0.9)
                        .opacity(markOpacity)
                        .scaleEffect(markScale)

                    Text("VEYRA")
                        .font(.system(
                            size: wide ? min(size.width * 0.032, 54) : min(size.width * 0.082, 36),
                            weight: .semibold,
                            design: .rounded
                        ))
                        .tracking(wide ? 14 : 8)
                        .foregroundStyle(.white)
                        .opacity(nameOpacity)

                    Text("ALL YOUR MEDIA. ONE PLACE.")
                        .font(.system(size: wide ? 15 : 11, weight: .medium))
                        .tracking(wide ? 4 : 2.5)
                        .foregroundStyle(VeyraColors.ice.opacity(0.75))
                        .opacity(subtitleOpacity)
                }
                .offset(y: wide ? -12 : -20)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Veyra wordt gestart")
            }
            .frame(width: size.width, height: size.height)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .opacity(overlayOpacity)
        .allowsHitTesting(overlayOpacity > 0)
        .task {
            guard !started else { return }
            started = true
            await runSequence()
        }
    }

    @MainActor
    private func runSequence() async {
        if reduceMotion {
            markOpacity = 1
            markScale = 1
            nameOpacity = 1
            subtitleOpacity = 1
            try? await Task.sleep(for: .seconds(0.8))
            withAnimation(.easeOut(duration: 0.25)) { overlayOpacity = 0 }
            try? await Task.sleep(for: .seconds(0.25))
            onFinished()
            return
        }

        // Alleen het beeldmerk-met-tekst-scherm: logo verschijnt, dan naam, dan subtitel.
        withAnimation(.easeOut(duration: 0.7)) {
            markOpacity = 1
            markScale = 1
        }

        try? await Task.sleep(for: .seconds(0.4))
        withAnimation(.easeOut(duration: 0.45)) {
            nameOpacity = 1
        }

        try? await Task.sleep(for: .seconds(0.2))
        withAnimation(.easeOut(duration: 0.4)) {
            subtitleOpacity = 1
        }

        try? await Task.sleep(for: .seconds(0.75))
        withAnimation(.easeInOut(duration: 0.45)) {
            overlayOpacity = 0
        }
        try? await Task.sleep(for: .seconds(0.45))
        onFinished()
    }
}

#Preview {
    LaunchAnimationView()
}
