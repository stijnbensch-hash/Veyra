import SwiftUI

struct VeyraPosterCard: View {
    let title: String
    let url: URL?
    var symbol = "film"
    var width: CGFloat = 220

    // Op tvOS bekijk je dit van op de bank (10-foot UI), op iOS hou je het
    // vast — dezelfde tvOS-maten op een telefoon gaven een los, blokkerig
    // 2-koloms grid met veel te grote titels. Op iOS dus overal kleiner en
    // subtieler, met een zachte schaduw voor wat diepte i.p.v. een zware
    // gradient.
#if os(tvOS)
    private var titleFontSize: CGFloat { 22 }
    private var titleHeight: CGFloat { 56 }
    private var gradientHeight: CGFloat { 90 }
    private var cardPadding: CGFloat { 8 }
    private var stackSpacing: CGFloat { 12 }
#else
    private var titleFontSize: CGFloat { 13 }
    private var titleHeight: CGFloat { 34 }
    private var gradientHeight: CGFloat { 44 }
    private var cardPadding: CGFloat { 4 }
    private var stackSpacing: CGFloat { 6 }
#endif

    var body: some View {
        VStack(alignment: .leading, spacing: stackSpacing) {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else {
                    ZStack {
                        VeyraColors.surface
                        Image(systemName: symbol).font(.system(size: 42)).foregroundStyle(VeyraColors.secondary)
                    }
                }
            }
            .frame(width: width, height: width * 1.5).clipped()
            .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.poster, style: .continuous))
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                    .frame(height: gradientHeight)
                    .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.poster, style: .continuous))
            }
#if !os(tvOS)
            .shadow(color: .black.opacity(0.28), radius: 6, y: 3)
#endif
            Text(title).font(.system(size: titleFontSize, weight: .medium)).foregroundStyle(.white)
                .lineLimit(2).frame(height: titleHeight, alignment: .topLeading)
        }.frame(width: width).padding(cardPadding)
    }
}

struct VeyraPosterBadge: View {
    let title: String
    var symbol: String? = nil
    var accent: Color = VeyraColors.cyan
    var fontSize: CGFloat = 15

    var body: some View {
        HStack(spacing: 7) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: fontSize - 1, weight: .bold))
                    .foregroundStyle(accent)
            } else {
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)
            }

            Text(title.uppercased())
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .tracking(0.7)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Color(red: 0.015, green: 0.025, blue: 0.038).opacity(0.94),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(accent.opacity(0.78), lineWidth: 1.25)
        }
        .shadow(color: .black.opacity(0.62), radius: 8, y: 3)
    }
}
