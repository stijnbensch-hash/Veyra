import SwiftUI

/// Rolverdeling (regisseur/bedenker + cast) van een film of serie, als
/// horizontale rij ronde portretten -- hoort op elk film-/seriedetailscherm,
/// tvOS zowel als iOS. Tikken op iemand opent `PersonDetailView`.
struct CastRow: View {
    let item: MediaItem

    @State private var credits: TMDBCredits?

    private struct Person: Identifiable, Hashable {
        let id: Int
        let name: String
        let role: String?
        let profilePath: String?
    }

    private var people: [Person] {
        guard let credits else { return [] }
        let crew = credits.directorsOrCreators.map {
            Person(id: $0.id, name: $0.name, role: $0.job == "Creator" ? "Bedenker" : "Regisseur", profilePath: $0.profilePath)
        }
        let cast = credits.cast
            .sorted { ($0.order ?? .max) < ($1.order ?? .max) }
            .prefix(20)
            .map { Person(id: $0.id, name: $0.name, role: $0.character, profilePath: $0.profilePath) }
        return crew + Array(cast)
    }

    var body: some View {
        Group {
            if !people.isEmpty {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    VeyraSectionHeader(title: "Rolverdeling")
#if !os(tvOS)
                        .padding(.horizontal)
#endif

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: rowSpacing) {
                            ForEach(people) { person in
                                NavigationLink {
                                    PersonDetailView(personID: person.id, name: person.name)
                                } label: {
                                    personCard(person)
                                }
#if os(tvOS)
                                .buttonStyle(VeyraPosterFocusStyle())
#else
                                .buttonStyle(.plain)
#endif
                            }
                        }
#if os(tvOS)
                        .padding(12)
#else
                        .padding(.horizontal)
#endif
                    }
#if os(tvOS)
                    .scrollClipDisabled()
#endif
                }
            }
        }
        .task(id: item.tmdbID) { await load() }
    }

    private func personCard(_ person: Person) -> some View {
        VStack(spacing: 8) {
            AsyncImage(
                url: person.profilePath.flatMap { URL(string: "https://image.tmdb.org/t/p/w185\($0)") }
            ) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    ZStack {
                        VeyraColors.surface
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white.opacity(0.4))
                            .font(.system(size: avatarSize * 0.4))
                    }
                }
            }
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())

            Text(person.name)
                .font(nameFont)
                .foregroundStyle(.white)
                .lineLimit(1)

            if let role = person.role, !role.isEmpty {
                Text(role)
                    .font(roleFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: avatarSize + 24)
    }

    private var avatarSize: CGFloat {
#if os(tvOS)
        140
#else
        84
#endif
    }

    private var nameFont: Font {
#if os(tvOS)
        .system(size: 18, weight: .semibold)
#else
        .caption.weight(.semibold)
#endif
    }

    private var roleFont: Font {
#if os(tvOS)
        .system(size: 15)
#else
        .caption2
#endif
    }

    private var rowSpacing: CGFloat {
#if os(tvOS)
        28
#else
        16
#endif
    }

    private var sectionSpacing: CGFloat {
#if os(tvOS)
        20
#else
        12
#endif
    }

    private func load() async {
        credits = await CreditsService.credits(for: item)
        print("[CastRow] tmdbID=\(item.tmdbID.map(String.init) ?? "nil") type=\(item.type) cast=\(credits?.cast.count ?? -1) crew=\(credits?.crew.count ?? -1)")
    }
}
