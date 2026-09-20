import SwiftUI

struct VeyraPosterCard: View {
    let title: String
    let url: URL?
    var symbol = "film"
    var width: CGFloat = 220
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    .frame(height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.poster, style: .continuous))
            }
            Text(title).font(.system(size: 22, weight: .medium)).foregroundStyle(.white)
                .lineLimit(2).frame(height: 56, alignment: .topLeading)
        }.frame(width: width).padding(8)
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
