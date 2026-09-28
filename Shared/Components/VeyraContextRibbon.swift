// VeyraContextRibbon.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// "Veyra Now": één dynamische balk die begrijpt wat nú het relevantst is --
// verder kijken, een live programma dat net begint, een wedstrijd die
// bezig is (en dichtbij het einde nog relevanter) of de volgende aflevering
// die zo verschijnt -- i.p.v. blind te rouleren. Elk scherm bouwt de items
// met een `priority` (zie hieronder); deze view sorteert er zelf op, dus
// de eerste/langst getoonde tegel is altijd de op dit moment relevantste.
// Bewust GEEN eigen databron: elk scherm bouwt de items uit dezelfde
// ContinueItem/UpcomingItem/BentoLiveRow/SportEvent die de rest van de
// Bento-home al gebruikt (zie `VeyraBentoHome.swift`/`VeyraBentoHomeIOS.swift`).

import SwiftUI

nonisolated struct VeyraRibbonItem: Identifiable {
    let id: String
    let icon: String
    let label: String      // "VERDER KIJKEN" · "VOLGENDE AFLEVERING" · "LIVE NU" · "SPORT"
    let text: String       // Titel van film, serie, programma of wedstrijd
    var detail: String? = nil // Aflevering, zender of starttijd
    var isLive: Bool = false
    /// Hoe relevant dit item nú is -- hoger rouleert eerst en vaker naar voren.
    /// Richtlijn: 90+ live/net begonnen, 70-90 bijna zo ver of bijna afgelopen,
    /// 40-60 gewoon beschikbaar (verder kijken), <40 pas later relevant.
    var priority: Double = 50
    let action: () -> Void
}

/// Eigen, lichte focus-/druktoestand i.p.v. een platformspecifieke stijl te
/// importeren -- houdt dit bestand op alle platformen bruikbaar zonder
/// `#if os(tvOS)`-afhankelijkheden naar de tvOS-only kaartstijlen.
private struct VeyraRibbonButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(focused ? VeyraHomeStyle.cyan.opacity(0.7) : Color.white.opacity(0.12),
                                  lineWidth: focused ? 2 : 1)
            )
            .scaleEffect(focused ? 1.012 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.2), value: focused)
    }
}

struct VeyraContextRibbon: View {
    let items: [VeyraRibbonItem]

    @State private var index = 0

    // tvOS is 10-voet-UI: duidelijk groter dan op iOS, zodat de balk niet
    // verdrinkt naast de rest van de bento-tegels.
    private struct Metrics {
        let iconCircle: CGFloat
        let iconSize: CGFloat
        let labelSize: CGFloat
        let textSize: CGFloat
        let detailSize: CGFloat
        let textSpacing: CGFloat
        let hSpacing: CGFloat
        let hPadding: CGFloat
        let vPadding: CGFloat
        let minHeight: CGFloat
        let dot: CGFloat
        let dotWide: CGFloat
    }

    private var ribbonMetrics: Metrics {
        #if os(tvOS)
        Metrics(iconCircle: 64, iconSize: 26, labelSize: 18, textSize: 27, detailSize: 18, textSpacing: 4,
                hSpacing: 24, hPadding: 32, vPadding: 22, minHeight: 108, dot: 9, dotWide: 26)
        #else
        Metrics(iconCircle: 38, iconSize: 16, labelSize: 12, textSize: 17, detailSize: 13, textSpacing: 2,
                hSpacing: 16, hPadding: 20, vPadding: 12, minHeight: 0, dot: 6, dotWide: 16)
        #endif
    }

    /// Relevantste eerst -- "Veyra Now" toont dus altijd de meest actuele
    /// tegel als eerste/vertrekpunt i.p.v. willekeurige invoegvolgorde.
    private var sortedItems: [VeyraRibbonItem] {
        items.sorted { $0.priority > $1.priority }
    }

    var body: some View {
        let items = sortedItems
        if !items.isEmpty {
            let item = items[index % items.count]

            Button(action: item.action) {
                HStack(spacing: ribbonMetrics.hSpacing) {
                    ZStack {
                        Circle().fill((item.isLive ? VeyraColors.red : VeyraHomeStyle.cyan).opacity(0.16))
                        Image(systemName: item.icon)
                            .font(.system(size: ribbonMetrics.iconSize, weight: .bold))
                            .foregroundStyle(item.isLive ? VeyraColors.red : VeyraHomeStyle.cyan)
                    }
                    .frame(width: ribbonMetrics.iconCircle, height: ribbonMetrics.iconCircle)

                    VStack(alignment: .leading, spacing: ribbonMetrics.textSpacing) {
                        Text(item.label)
                            .font(.system(size: ribbonMetrics.labelSize, weight: .bold, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(item.isLive ? VeyraColors.red : VeyraHomeStyle.cyan)
                        Text(item.text)
                            .font(.system(size: ribbonMetrics.textSize, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        if let detail = item.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.system(size: ribbonMetrics.detailSize, weight: .medium))
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 12)

                    if items.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(items.indices, id: \.self) { i in
                                Capsule()
                                    .fill(i == index ? VeyraHomeStyle.cyan : Color.white.opacity(0.22))
                                    .frame(width: i == index ? ribbonMetrics.dotWide : ribbonMetrics.dot, height: ribbonMetrics.dot)
                            }
                        }
                    }
                }
                .padding(.horizontal, ribbonMetrics.hPadding)
                .padding(.vertical, ribbonMetrics.vPadding)
                .frame(maxWidth: .infinity, minHeight: ribbonMetrics.minHeight, alignment: .leading)
            }
            .buttonStyle(VeyraRibbonButtonStyle())
            .id(item.id)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
            .animation(.easeInOut(duration: 0.45), value: item.id)
            .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
                guard items.count > 1 else { return }
                index = (index + 1) % items.count
            }
            // Bij een nieuwe/kortere itemlijst (bv. na herladen) kan de oude index
            // buiten bereik vallen -- terug naar 0 i.p.v. te crashen op de modulo.
            .onChange(of: items.count) { _, newCount in
                if index >= newCount { index = 0 }
            }
        }
    }
}
