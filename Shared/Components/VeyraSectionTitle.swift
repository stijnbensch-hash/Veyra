import SwiftUI

struct VeyraSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [VeyraColors.cyan, VeyraColors.red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: barWidth, height: barHeight)
                .clipShape(Capsule())

            Text(title)
                .font(VeyraTypography.section)
                .foregroundStyle(.white)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle.uppercased())
                    .font(.system(size: subtitleSize, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(VeyraColors.ice.opacity(0.72))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: chevronSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))
        }
    }

#if os(tvOS)
    private let barWidth: CGFloat = 5
    private let barHeight: CGFloat = 30
    private let subtitleSize: CGFloat = 16
    private let chevronSize: CGFloat = 18
#else
    private let barWidth: CGFloat = 4
    private let barHeight: CGFloat = 20
    private let subtitleSize: CGFloat = 12
    private let chevronSize: CGFloat = 14
#endif
}
