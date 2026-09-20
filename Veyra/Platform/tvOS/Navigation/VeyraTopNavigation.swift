import SwiftUI

struct VeyraTopNavigation: View {
    let selected: MenuDestination
    let navigate: (MenuDestination) -> Void
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach([MenuDestination.home, .film, .series, .sport, .liveTV]) { destination in
                    item(destination, iconOnly: false)
                }
            }

            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(width: 1, height: 34)

            HStack(spacing: 8) {
                item(.search, iconOnly: true)
                item(.account, iconOnly: true)
                item(.settings, iconOnly: true)
            }

            Spacer(minLength: 36)

            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(context.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(
                        Color.black.opacity(0.48),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 42).padding(.top, 12).padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .focusSection()
    }
    private func item(_ destination: MenuDestination, iconOnly: Bool) -> some View {
        Button { navigate(destination) } label: {
            HStack(spacing: 12) {
                Image(systemName: destination.symbol).font(.system(size: 22, weight: .medium))
                if !iconOnly { Text(destination.title).font(.system(size: 22, weight: .medium)) }
            }
            .foregroundStyle(selected == destination ? .white : .white.opacity(0.78))
            .padding(.horizontal, iconOnly ? 17 : 18).frame(height: 56)
            .background {
                if selected == destination {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [VeyraColors.cyan.opacity(0.30), VeyraColors.cyan.opacity(0.10), VeyraColors.red.opacity(0.12)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(Capsule().stroke(VeyraColors.ice.opacity(0.40)))
                }
            }
        }
        .buttonStyle(VeyraNavigationButtonStyle())
        .accessibilityLabel(destination.title)
        .accessibilityAddTraits(selected == destination ? [.isSelected] : [])
    }
}

private struct VeyraNavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        VeyraNavigationButtonLabel(configuration: configuration)
    }
}

private struct VeyraNavigationButtonLabel: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isFocused)
    private var isFocused

    var body: some View {
        configuration.label
            .background(
                isFocused
                    ? Color.black.opacity(0.52)
                    : Color.clear,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        isFocused
                            ? VeyraColors.cyan.opacity(0.92)
                            : Color.clear,
                        lineWidth: 2
                    )
            }
            .shadow(
                color: isFocused
                    ? VeyraColors.cyan.opacity(0.25)
                    : .clear,
                radius: 14,
                y: 3
            )
            .scaleEffect(
                configuration.isPressed
                    ? 0.97
                    : isFocused
                        ? 1.045
                        : 1
            )
            .animation(VeyraAnimation.focus, value: isFocused)
    }
}
