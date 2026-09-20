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
                .frame(width: 5, height: 30)
                .clipShape(Capsule())

            Text(title)
                .font(VeyraTypography.section)
                .foregroundStyle(.white)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle.uppercased())
                    .font(.system(size: 16, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(VeyraColors.ice.opacity(0.72))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))
        }
    }
}
