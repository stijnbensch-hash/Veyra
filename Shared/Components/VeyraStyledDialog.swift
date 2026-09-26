import SwiftUI

// MARK: - Cyaan/rood-gerande dialoogknop

/// Vervangt de systeem-stijl van `.confirmationDialog` (op tvOS een felwitte
/// achtergrond bij focus, op iOS een lichte actionsheet-rij) door dezelfde
/// donkere kaart met cyaan/rode rand die de rest van de app gebruikt. Werkt
/// op elk platform: tvOS kijkt naar `isFocused` (remote), iOS/macOS naar
/// `isPressed` (tik/klik). De kleur volgt de knop-`role` die al op elke
/// bestaande `Button(..., role: .destructive/.cancel)` staat, dus de
/// knop-declaraties zelf hoeven niet te veranderen.
struct VeyraDialogButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        VeyraDialogButtonLabel(configuration: configuration)
    }
}

private struct VeyraDialogButtonLabel: View {
    let configuration: ButtonStyleConfiguration

    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused
    #endif

    private var tint: Color {
        switch configuration.role {
        case .destructive: return VeyraColors.red
        case .cancel: return .white.opacity(0.55)
        default: return VeyraColors.cyan
        }
    }

    private var highlighted: Bool {
        #if os(tvOS)
        isFocused
        #else
        configuration.isPressed
        #endif
    }

    #if os(tvOS)
    private let fontSize: CGFloat = 24
    private let vPad: CGFloat = 16
    private let cornerRadius: CGFloat = 14
    #else
    private let fontSize: CGFloat = 17
    private let vPad: CGFloat = 13
    private let cornerRadius: CGFloat = 12
    #endif

    var body: some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(highlighted ? .white : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, vPad)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(highlighted ? tint.opacity(0.22) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(highlighted ? tint : tint.opacity(0.35), lineWidth: highlighted ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .animation(.easeOut(duration: 0.14), value: highlighted)
    }
}

// MARK: - Eigen "confirmationDialog"

/// Drop-in vervanger voor `.confirmationDialog(title:isPresented:titleVisibility:) { buttons } message: { ... }`,
/// maar met de eigen donkere/cyaan-rode kaartstijl i.p.v. de systeemdialoog.
/// De knoplijst blijft gewoon gewone `Button(...)`-declaraties (met hun
/// bestaande `role:`), enkel de presentatie verandert.
extension View {
    // Zelfde volgorde als het systeem-eigen `.confirmationDialog`: eerst de
    // ongelabelde `buttons`-trailing closure, dan de gelabelde `message:`.
    func veyraConfirmationDialog<Buttons: View, Message: View>(
        _ title: String,
        isPresented: Binding<Bool>,
        @ViewBuilder buttons: @escaping () -> Buttons,
        @ViewBuilder message: @escaping () -> Message
    ) -> some View {
        modifier(
            VeyraConfirmationDialogModifier(
                title: title, isPresented: isPresented, message: message, buttons: buttons
            )
        )
    }

    func veyraConfirmationDialog<Buttons: View>(
        _ title: String,
        isPresented: Binding<Bool>,
        @ViewBuilder buttons: @escaping () -> Buttons
    ) -> some View {
        veyraConfirmationDialog(title, isPresented: isPresented, buttons: buttons, message: { EmptyView() })
    }
}

private struct VeyraConfirmationDialogModifier<Buttons: View, Message: View>: ViewModifier {
    let title: String
    @Binding var isPresented: Bool
    @ViewBuilder var message: () -> Message
    @ViewBuilder var buttons: () -> Buttons

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                VeyraConfirmationDialogCard(title: title, isPresented: $isPresented, message: message, buttons: buttons)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.16), value: isPresented)
    }
}

private struct VeyraConfirmationDialogCard<Buttons: View, Message: View>: View {
    let title: String
    @Binding var isPresented: Bool
    @ViewBuilder var message: () -> Message
    @ViewBuilder var buttons: () -> Buttons

    #if os(tvOS)
    private let titleFont: Font = .system(size: 30, weight: .bold, design: .rounded)
    private let messageFont: Font = .system(size: 20)
    private let cardPadding: CGFloat = 40
    private let cardWidth: CGFloat = 720
    private let spacing: CGFloat = 22
    private let maxButtonsHeight: CGFloat = 620
    #else
    private let titleFont: Font = .system(size: 19, weight: .bold)
    private let messageFont: Font = .system(size: 14)
    private let cardPadding: CGFloat = 24
    private let cardWidth: CGFloat = 340
    private let spacing: CGFloat = 14
    private let maxButtonsHeight: CGFloat = 420
    #endif

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
                #if !os(tvOS)
                .onTapGesture { isPresented = false }
                #endif

            VStack(spacing: spacing) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                message()
                    .font(messageFont)
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)

                ScrollView {
                    VStack(spacing: 10) { buttons() }
                }
                .frame(maxHeight: maxButtonsHeight)
            }
            .padding(cardPadding)
            .frame(maxWidth: cardWidth)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.03, green: 0.09, blue: 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [VeyraColors.cyan.opacity(0.55), VeyraColors.red.opacity(0.45)],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
        }
        .buttonStyle(VeyraDialogButtonStyle())
        #if os(tvOS)
        .onExitCommand { isPresented = false }
        #endif
    }
}
