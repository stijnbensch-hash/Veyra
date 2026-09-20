import SwiftUI

struct VeyraActionLabel: View {
    let title: String
    let symbol: String
    var body: some View {
        Label(title, systemImage: symbol).font(.system(size: 24, weight: .semibold))
            .foregroundStyle(.white).padding(.horizontal, 26).frame(height: 68)
    }
}

struct VeyraHero<Actions: View>: View {
    let title: String
    var eyebrow: String = ""
    var overview: String?
    var metadata: [String] = []
    @ViewBuilder let actions: () -> Actions
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !eyebrow.isEmpty {
                HStack(spacing: 10) {
                    Capsule().fill(VeyraColors.red).frame(width: 28, height: 5)
                    Text(eyebrow.uppercased()).font(.system(size: 18, weight: .medium)).tracking(4).foregroundStyle(VeyraColors.ice)
                }
            }
            Text(title)
                .font(.system(size: 58, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.6), radius: 18, y: 8)
            if !metadata.isEmpty {
                HStack(spacing: 12) {
                    ForEach(metadata, id: \.self) { value in
                        Text(value).font(.system(size: 19, weight: .medium)).padding(.horizontal, 13).padding(.vertical, 7)
                            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.10)))
                    }
                }
            }
            if let overview, !overview.isEmpty {
                Text(overview).font(VeyraTypography.body).foregroundStyle(.white.opacity(0.78))
                    .lineSpacing(4).lineLimit(3)
            }
            HStack(spacing: 22, content: actions).padding(.top, 8)
        }
        .frame(maxWidth: 860, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 28)
        #if os(tvOS)
        .focusSection()
        #endif
    }
}
