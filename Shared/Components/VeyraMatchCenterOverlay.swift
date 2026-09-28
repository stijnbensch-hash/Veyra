// VeyraMatchCenterOverlay.swift — gedeeld (tvOS/iOS/iPadOS)
// "Match Center": een wedstrijd is geen gewone live-TV-stream. Bovenop de
// speler toont dit een eigen glazen infobalk met stand, wedstrijdklok/fase
// en competitie i.p.v. enkel de kale kanaalnaam. De stand kan verborgen
// blijven tot tik, via dezelfde "Uitslag verbergen tot tik"-instelling als
// de Sport-tab (`GeneralSettingsDefaults.hideScoreSpoilersKey`).
//
// Bewust GEEN eigen databron: `PlayerView` geeft het `SportEvent` door dat
// al bij het opzoeken van de zender bekend was (zie `SportChannelQuery`).
// Alternatieve bronnen wisselen vanuit deze balk is nog niet aangesloten --
// het aantal wordt getoond, het kanaal wisselen kan voorlopig via "Andere
// zender" in de speler zelf.

import SwiftUI

struct VeyraMatchCenterOverlay: View {
    let event: SportEvent
    let now: Date

    @AppStorage(GeneralSettingsDefaults.hideScoreSpoilersKey) private var hideScoreSpoilers = false
    @State private var scoreRevealed = false

    private var live: Bool { event.isLive(at: now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if live {
                    Circle().fill(VeyraColors.red).frame(width: 7, height: 7)
                    Text("LIVE")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(VeyraColors.red)
                }
                if let competition = event.competition {
                    Text(competition.uppercased())
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }

            Text(event.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            let hidden = hideScoreSpoilers && !scoreRevealed
            HStack(spacing: 10) {
                if let score = event.score {
                    Text(hidden ? "?–?" : score.text)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    if let minute = score.minute, !hidden {
                        Text(minute)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                } else if let situation = event.situation {
                    Text(situation)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                } else if let remaining = event.remainingMinutes(at: now) {
                    Text("nog \(remaining) min")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }

                if hidden {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { scoreRevealed = true }
                    } label: {
                        Text("Toon uitslag")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VeyraHomeStyle.cyan)
                    }
                }
            }

            if event.alternativeSources > 0 {
                Text("\(event.alternativeSources) andere \(event.alternativeSources == 1 ? "bron" : "bronnen") beschikbaar")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .frame(maxWidth: 420, alignment: .leading)
    }
}
