import SwiftUI

/// Menubalk bovenaan voor macOS, als alternatief voor de zijbalk
/// (`Instellingen → Algemeen → Navigatie`) -- qua opbouw en stijl bewust
/// hetzelfde "menu overzicht" als `VeyraTopNavigation` op tvOS: dezelfde
/// items in dezelfde volgorde, dezelfde cyaan/rode verloopkleur op de
/// geselecteerde knop. Het enige verschil is de interactie: tvOS gebruikt
/// remote-focus (`@Environment(\.isFocused)`), macOS gebruikt de muis
/// (`.onHover`) -- er is geen focus-ring nodig omdat een muis geen
/// "huidige positie" op het scherm heeft zoals de tvOS-afstandsbediening.
struct MacTopNavigation: View {
    let selected: MenuDestination
    let navigate: (MenuDestination) -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach([MenuDestination.home, .film, .series, .watchlist, .sport, .liveTV, .recordings]) { destination in
                    item(destination, iconOnly: false)
                }
            }

            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(width: 1, height: 28)

            HStack(spacing: 8) {
                item(.search, iconOnly: true)
                item(.account, iconOnly: true)
                item(.settings, iconOnly: true)
            }

            Spacer(minLength: 24)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(VeyraColors.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
        }
    }

    private func item(_ destination: MenuDestination, iconOnly: Bool) -> some View {
        Button {
            navigate(destination)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: destination.symbol).font(.system(size: 15, weight: .medium))
                if !iconOnly { Text(destination.title).font(.system(size: 15, weight: .medium)) }
            }
            .foregroundStyle(selected == destination ? .white : .white.opacity(0.72))
            .padding(.horizontal, iconOnly ? 12 : 15)
            .frame(height: 36)
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
        .buttonStyle(MacTopNavigationButtonStyle(isSelected: selected == destination))
        .accessibilityLabel(destination.title)
        .accessibilityAddTraits(selected == destination ? [.isSelected] : [])
    }
}

/// Muis-hover-equivalent van tvOS' `VeyraNavigationButtonStyle`: een cyaan
/// gloed/rand bij hover in plaats van bij focus, en een lichte
/// indrukanimatie.
private struct MacTopNavigationButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        MacTopNavigationButtonLabel(configuration: configuration, isSelected: isSelected)
    }
}

private struct MacTopNavigationButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool

    @State private var isHovering = false

    var body: some View {
        configuration.label
            .background(
                isHovering && !isSelected ? Color.white.opacity(0.08) : Color.clear,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        isHovering ? VeyraColors.cyan.opacity(0.7) : Color.clear,
                        lineWidth: 1.5
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { isHovering = $0 }
    }
}
