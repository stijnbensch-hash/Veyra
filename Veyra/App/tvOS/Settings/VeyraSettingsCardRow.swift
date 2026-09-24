import SwiftUI

/// Herbruikbare "kaart"-look voor een instellingenrij binnenin een tvOS
/// `List` — icoon-vierkant + titel (+ optionele subtitel) + eigen
/// rechterkant (waarde/pijl, schakelaar, knop, …). Zelfde visuele taal als
/// `SettingsView.settingsCard` op het hoofdscherm, alleen compacter zodat
/// meerdere rijen per scherm passen.
///
/// Dit is alleen de INHOUD van de rij — de kaart-achtergrond zelf komt van
/// `VeyraFocusButtonStyle` op de omliggende `Button`/`NavigationLink` (zie
/// `.veyraCardRow()`), niet van een statische `listRowBackground`-fill.
/// Reden: een systeem-`Toggle` of `Picker` binnenin een tvOS `List` legt bij
/// focus altijd zijn eigen felwitte highlight over de hele rij, wat niet te
/// combineren is met een eigen achtergrondkleur — pas door de rij zelf een
/// knop te maken (met `VeyraFocusButtonStyle`, dezelfde stijl als de
/// navigatiekaarten op het hoofdscherm) krijgen we i.p.v. daarvan de
/// donkere kaart + cyaan gloed bij focus.
struct VeyraSettingsCardRowLabel<Trailing: View>: View {
    let icon: String
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(VeyraColors.cyan.opacity(0.14))

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(VeyraColors.cyan)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

/// Standaard rechterkant voor een navigatie-/waarde-rij: huidige waarde +
/// chevron, zoals `VeyraSettingsChoiceRow` gebruikt.
struct VeyraSettingsCardRowValue: View {
    let value: String?

    var body: some View {
        HStack(spacing: 10) {
            if let value {
                Text(value).foregroundStyle(.white.opacity(0.55))
                    .font(.system(size: 18))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.30))
        }
    }
}

/// Eigen aan/uit-indicator i.p.v. een systeem-`Toggle` — zie de
/// toelichting bovenaan dit bestand. De hele rij is hier zelf de knop;
/// drukken op selecteer keert de waarde om.
struct VeyraSettingsCardRowSwitch: View {
    let isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? VeyraColors.cyan : Color.white.opacity(0.18))
            .frame(width: 54, height: 30)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: 24, height: 24)
                    .padding(3)
            }
    }
}

/// Kaart-versie van een `Toggle`-rij (icoon + titel + eigen
/// aan/uit-indicator), zelfde stijl als `VeyraSettingsChoiceRow` maar voor
/// aan/uit-instellingen i.p.v. een keuze uit meerdere opties.
struct VeyraSettingsToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            VeyraSettingsCardRowLabel(icon: icon, title: title, subtitle: subtitle) {
                VeyraSettingsCardRowSwitch(isOn: isOn)
            }
        }
        .veyraCardRow()
    }
}

/// Focusstijl speciaal voor rijen binnenin een tvOS `List` — bewust GEEN
/// `VeyraCard`/`VeyraFocusButtonStyle`. Die groeit bij focus
/// (`scaleEffect`) en gloeit met een schaduw die buiten de eigen rand
/// valt; een List clipt zijn rijen echter altijd hard op de rijgrens, hoe
/// groot de marge ook is (dat gaf de afgesneden/platte rand i.p.v. een
/// afgeronde hoek). Deze stijl blijft dus altijd binnen zijn eigen
/// grootte — geen scale, geen schaduw — en toont focus alleen via een
/// helderdere achtergrond + cyaan rand, zodat er niets af te snijden valt.
private struct VeyraSettingsRowButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(focused ? 0.14 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        focused
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [VeyraColors.ice, VeyraColors.cyan, VeyraColors.red.opacity(0.70)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            : AnyShapeStyle(Color.white.opacity(0.10)),
                        lineWidth: focused ? 2 : 1
                    )
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

extension View {
    /// Maakt van een `Button`/`NavigationLink` een instellingenrij-"kaart":
    /// donkere achtergrond die oplicht + cyaan rand bij focus, plus een
    /// doorzichtige List-rijachtergrond en wat verticale lucht tussen
    /// rijen zodat het losse kaarten voelen i.p.v. een aaneengesloten lijst.
    func veyraCardRow() -> some View {
        self
            .buttonStyle(VeyraSettingsRowButtonStyle())
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
        // Geen .listRowSeparator hier: die modifier bestaat niet op tvOS
        // (alleen iOS/macOS/watchOS) — tvOS-Lists tonen sowieso geen
        // scheidingslijnen tussen rijen, dus er is niets te verbergen.
    }
}
