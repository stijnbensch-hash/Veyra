// VeyraLensCastRow.swift — gedeeld (tvOS/iOS)
// Onderdeel van "Veyra Lens" (de contextknop in de speler): horizontale
// castrij met portret + naam/rol, gebruikt in de Info-tab (tvOS, zie
// `PlayerSubtitleControls.swift`) en het Lens-scherm (iOS, zie
// `VeyraLensSheet.swift`) voor films en series.

import SwiftUI

struct VeyraLensCastRow: View {
    let cast: [TMDBCastMember]

    var body: some View {
        if !cast.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(cast.prefix(12)) { member in
                        VStack(spacing: 6) {
                            VeyraAsyncImage(url: member.profileURL) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    ZStack {
                                        Color.white.opacity(0.08)
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                }
                            }
                            .frame(width: 68, height: 68)
                            .clipShape(Circle())

                            VStack(spacing: 1) {
                                Text(member.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                if let character = member.character, !character.isEmpty {
                                    Text(character)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.55))
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 84)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
