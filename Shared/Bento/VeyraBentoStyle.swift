// VeyraBentoStyle.swift — gedeeld door tvOS en iOS/macOS (tvOS 17+ / iOS 17+ / macOS 14+)
// Veyra-stijl bouwstenen voor "Verder kijken" en "Binnenkort":
//   glas boven wazig beeld · één accent (cyaan) · rood alleen voor live · elk kader eindigt op een tijdlijn-lijn
//
// De inhoudsviews hieronder hebben een `compact`-vlag: false = tvOS-maten, true = telefoon/tablet.
// De platformbestanden (VeyraBentoFocus.swift voor tvOS, VeyraBentoFocus.swift) bepalen
// alleen de indeling, focus/aanraking en knopstijl.
//
// VeyraHomeStyle verwijst naar VeyraColors. Wil je later het echte glas: veyraGlassSurface -> .veyraGlass(...).

import SwiftUI

// MARK: - Tokens (afgeleid, vervang door Veyra-tokens)

enum VeyraHomeStyle {
    // Gekoppeld aan de echte Veyra-tokens (Shared/Theme/VeyraColors.swift).
    static let cyan = VeyraColors.cyan
    static let live = VeyraColors.red
    static let dim = VeyraColors.secondary
    static let faint = Color.white.opacity(0.44)
    static let ink = VeyraColors.background
}

/// Het Veyra-kader: cyaan (ijs) links naar rood rechts, zoals `veyraGlass` en `VeyraCard`.
enum VeyraFrame {
    static let resting = LinearGradient(
        colors: [VeyraColors.cyan.opacity(0.42), .white.opacity(0.10), VeyraColors.red.opacity(0.34)],
        startPoint: .leading, endPoint: .trailing)
    /// Opvulling van de paneeltegels: ijsblauw linksboven naar rood rechtsonder, zacht zodat tekst leesbaar blijft.
    static let fill = LinearGradient(
        colors: [VeyraColors.cyan.opacity(0.24), VeyraColors.cyan.opacity(0.07), VeyraColors.red.opacity(0.17)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let active = LinearGradient(
        colors: [VeyraColors.ice, VeyraColors.cyan, VeyraColors.red.opacity(0.75)],
        startPoint: .leading, endPoint: .trailing)
}

extension Array {
    func veyraElement(at index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

// MARK: - Glas

struct VeyraGlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 30

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(.ultraThinMaterial, in: shape)
            .background(Color.white.opacity(0.05), in: shape)
            .overlay(shape.strokeBorder(VeyraFrame.resting, lineWidth: 1.5))
    }
}

extension View {
    func veyraGlassSurface(cornerRadius: CGFloat = 30) -> some View {
        modifier(VeyraGlassSurface(cornerRadius: cornerRadius))
    }
}

// MARK: - Tijdlijn-lijn (de Veyra-handtekening)

struct VeyraHairline: View {
    var progress: Double
    var tint: Color = VeyraHomeStyle.cyan
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let p = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.16))
                Rectangle().fill(tint)
                    .frame(width: geo.size.width * p)
                    .shadow(color: tint, radius: 7)
                Circle().fill(tint)
                    .frame(width: height * 2.5, height: height * 2.5)
                    .shadow(color: tint, radius: 8)
                    .offset(x: geo.size.width * p - height * 1.25)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Beeld

/// Backdrop met een rustige, per titel vaste kleur als plaatshouder tot het TMDB-beeld binnen is.
struct VeyraArt: View {
    let url: URL?
    let seed: String

    var body: some View {
        GeometryReader { geo in
            ZStack {
                placeholder
                if let url {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase { image.resizable().scaledToFill() }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    private var placeholder: some View {
        let hue = Double(seed.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) % 360 }) / 360
        return ZStack {
            Color(hue: hue, saturation: 0.30, brightness: 0.24)
            Circle().fill(Color.white.opacity(0.06))
                .frame(width: 340, height: 340)
                .offset(x: 120, y: -80)
        }
    }
}

/// Clearlogo als het er is, anders de titel in hoofdletters met ruime spatiëring.
struct VeyraTitleLogo: View {
    let title: String
    let logoURL: URL?
    var size: CGFloat = 44
    var maxLogoHeight: CGFloat = 90
    var alignment: Alignment = .leading

    var body: some View {
        Group {
            if let logoURL {
                AsyncImage(url: logoURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        text
                    }
                }
                .frame(maxHeight: maxLogoHeight, alignment: alignment)
            } else {
                text
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .shadow(color: .black.opacity(0.5), radius: 10, y: 3)
    }

    private var text: some View {
        Text(title)
            .font(.system(size: size, weight: .bold))
            .tracking(size * 0.14)
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(.white)
    }
}

// MARK: - Kop en status

struct VeyraHomeSectionHeader: View {
    let title: String
    var trailing: String? = nil
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 12 : 18) {
            Capsule()
                .fill(VeyraHomeStyle.cyan)
                .frame(width: 6, height: compact ? 20 : 26)
                .shadow(color: VeyraHomeStyle.cyan, radius: 7)
            Text(title)
                .font(.system(size: compact ? 17 : 26, weight: .bold))
                .tracking(compact ? 1.8 : 3.6)
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1)
            if let trailing {
                Text(trailing)
                    .font(compact ? .footnote : .title3)
                    .foregroundStyle(VeyraHomeStyle.dim)
            }
        }
    }
}

struct VeyraStatusMessage: View {
    let text: String
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Text(text).font(.callout).foregroundStyle(VeyraHomeStyle.dim).multilineTextAlignment(.center)
            if let retry {
                Button("Opnieuw proberen", action: retry).buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .veyraGlassSurface(cornerRadius: 24)
    }
}

struct VeyraReminderPill: View {
    let isOn: Bool
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 6 : 10) {
            Image(systemName: isOn ? "bell.fill" : "bell")
                .foregroundStyle(isOn ? VeyraHomeStyle.cyan : .white)
            Text(isOn ? "Herinnering aan" : "Herinner mij")
        }
        .font(compact ? .footnote.weight(.semibold) : .callout.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 12 : 18)
        .padding(.vertical, compact ? 6 : 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Verder kijken: inhoud

struct VeyraContinueBigContent: View {
    let item: ContinueItem
    var compact = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VeyraArt(url: item.backdropURL, seed: item.title)
            LinearGradient(colors: [.clear, .black.opacity(0.9)],
                           startPoint: UnitPoint(x: 0.5, y: 0.3), endPoint: .bottom)
            VStack(alignment: .leading, spacing: compact ? 6 : 10) {
                VeyraTitleLogo(title: item.title, logoURL: item.logoURL,
                               size: compact ? 22 : 44, maxLogoHeight: compact ? 44 : 90)
                Text(item.metaText)
                    .font(compact ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
                    .foregroundStyle(VeyraHomeStyle.dim)
            }
            .padding(.horizontal, compact ? 16 : 34)
            .padding(.bottom, compact ? 20 : 34)
        }
        .overlay(alignment: .bottom) {
            if item.progress > 0 { VeyraHairline(progress: item.progress) }
        }
        .foregroundStyle(.white)
    }
}

struct VeyraContinueStripContent: View {
    let item: ContinueItem
    var compact = false

    var body: some View {
        HStack(spacing: 0) {
            VeyraArt(url: item.backdropURL, seed: item.title)
                .frame(width: compact ? 112 : 250)
            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                Text(item.title)
                    .font(.system(size: compact ? 16 : 30, weight: .bold))
                    .tracking(compact ? 1.4 : 3.4)
                    .textCase(.uppercase)
                    .lineLimit(1)
                Text(item.metaText)
                    .font(compact ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
                    .lineLimit(1)
                if let episodeTitle = item.episodeTitle {
                    Text(episodeTitle)
                        .font(compact ? .footnote : .callout)
                        .foregroundStyle(VeyraHomeStyle.dim)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, compact ? 14 : 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .overlay(alignment: .bottom) {
            if item.progress > 0 { VeyraHairline(progress: item.progress) }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Binnenkort: inhoud

struct VeyraCountdownContent: View {
    let item: UpcomingItem
    let now: Date
    let reminderOn: Bool
    var compact = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            VeyraArt(url: item.backdropURL, seed: item.title)
            LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(VeyraHomeFormat.when(item.airDate, now: now, dateOnly: item.isDateOnly))
                        .font(.system(size: compact ? 13 : 22, weight: .bold))
                        .tracking(compact ? 1.6 : 3)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.78))
                    Spacer(minLength: 12)
                    VeyraReminderPill(isOn: reminderOn, compact: compact)
                }
                Spacer(minLength: compact ? 8 : 16)
                Text(VeyraHomeFormat.countdown(to: item.airDate, now: now))
                    .font(.system(size: compact ? 60 : 148, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(item.kind == .movie ? "tot de release" : "tot de nieuwe aflevering")
                    .font(compact ? .footnote : .title3)
                    .foregroundStyle(VeyraHomeStyle.dim)
                Spacer(minLength: compact ? 12 : 24)
                Text(item.title)
                    .font(.system(size: compact ? 20 : 36, weight: .bold))
                    .tracking(compact ? 2.4 : 5)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(compact ? .subheadline : .title3)
                        .foregroundStyle(VeyraHomeStyle.dim)
                        .lineLimit(1)
                }
            }
            .padding(compact ? 18 : 40)
            .padding(.bottom, compact ? 6 : 8)
        }
        .overlay(alignment: .bottom) {
            VeyraHairline(progress: VeyraHomeFormat.countdownProgress(to: item.airDate, now: now))
        }
        .foregroundStyle(.white)
    }
}

/// Miniatuur + tekst voor de tweede/derde release (tvOS-tegel en iOS-rij).
struct VeyraUpcomingStripContent: View {
    let item: UpcomingItem
    let now: Date
    let reminderOn: Bool
    var compact = false

    var body: some View {
        HStack(spacing: 0) {
            VeyraArt(url: item.backdropURL, seed: item.title)
                .frame(width: compact ? 88 : 230)
            VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                Text(VeyraHomeFormat.when(item.airDate, now: now, dateOnly: item.isDateOnly))
                    .font(.system(size: compact ? 12 : 19, weight: .bold))
                    .tracking(compact ? 1.4 : 2.6)
                    .textCase(.uppercase)
                    .foregroundStyle(VeyraHomeStyle.cyan)
                    .lineLimit(1)
                Text(item.title)
                    .font(.system(size: compact ? 16 : 30, weight: .bold))
                    .tracking(compact ? 1.4 : 3.4)
                    .textCase(.uppercase)
                    .lineLimit(1)
                Text("\(item.subtitle ?? (item.kind == .movie ? "Film" : "Nieuw")) · over \(VeyraHomeFormat.countdown(to: item.airDate, now: now))")
                    .font(compact ? .footnote : .title3)
                    .foregroundStyle(VeyraHomeStyle.dim)
                    .lineLimit(1)
            }
            .padding(.horizontal, compact ? 14 : 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            if compact {
                Image(systemName: reminderOn ? "bell.fill" : "bell")
                    .foregroundStyle(reminderOn ? VeyraHomeStyle.cyan : VeyraHomeStyle.dim)
                    .padding(.trailing, 16)
            }
        }
        .overlay(alignment: .bottom) {
            VeyraHairline(progress: VeyraHomeFormat.countdownProgress(to: item.airDate, now: now))
        }
        .foregroundStyle(.white)
    }
}

/// Kleine datumtegel (tvOS-rij onderaan, iOS horizontale rij).
struct VeyraDateTileContent: View {
    let item: UpcomingItem
    let now: Date
    let reminderOn: Bool
    var compact = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VeyraArt(url: item.backdropURL, seed: item.title)
            LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: UnitPoint(x: 0.5, y: 0.25), endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(item.airDate.formatted(.dateTime.weekday(.abbreviated).day().locale(VeyraHomeFormat.locale)))
                        .font(.system(size: compact ? 12 : 19, weight: .bold))
                        .tracking(compact ? 1.2 : 2)
                        .textCase(.uppercase)
                        .foregroundStyle(VeyraHomeStyle.cyan)
                        .padding(.horizontal, compact ? 10 : 14)
                        .padding(.vertical, compact ? 3 : 5)
                        .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                    if reminderOn {
                        Image(systemName: "bell.fill").font(compact ? .footnote : .callout).foregroundStyle(VeyraHomeStyle.cyan)
                    }
                }
                Spacer(minLength: 0)
                Text([item.title, item.episodeCode].compactMap { $0 }.joined(separator: " "))
                    .font(.system(size: compact ? 14 : 24, weight: .bold))
                    .tracking(compact ? 1.2 : 2.4)
                    .textCase(.uppercase)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(compact ? 12 : 22)
            .padding(.bottom, 6)
        }
        .overlay(alignment: .bottom) {
            VeyraHairline(progress: VeyraHomeFormat.countdownProgress(to: item.airDate, now: now))
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Weekstrip

nonisolated struct VeyraWeekDay: Identifiable {
    let date: Date
    let count: Int
    let isToday: Bool
    var id: Date { date }
}

nonisolated func veyraWeek(from items: [UpcomingItem], now: Date, days: Int = 7, calendar: Calendar = .current) -> [VeyraWeekDay] {
    let start = calendar.startOfDay(for: now)
    return (0..<days).compactMap { offset in
        guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
        let count = items.filter { calendar.isDate($0.airDate, inSameDayAs: day) }.count
        return VeyraWeekDay(date: day, count: count, isToday: offset == 0)
    }
}

struct VeyraWeekStrip: View {
    let days: [VeyraWeekDay]
    var trailing: String? = nil
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Deze week")
                    .font(.system(size: compact ? 13 : 22, weight: .bold))
                    .tracking(compact ? 1.6 : 3)
                    .textCase(.uppercase)
                    .foregroundStyle(VeyraHomeStyle.dim)
                Spacer()
                if let trailing {
                    Text(trailing).font(compact ? .caption : .title3).foregroundStyle(VeyraHomeStyle.dim)
                }
            }
            HStack(spacing: compact ? 4 : 8) {
                ForEach(days) { day in column(day) }
            }
        }
        .foregroundStyle(.white)
        .padding(compact ? 14 : 28)
    }

    private func column(_ day: VeyraWeekDay) -> some View {
        let shape = RoundedRectangle(cornerRadius: compact ? 12 : 20, style: .continuous)
        return VStack(spacing: compact ? 2 : 4) {
            Text(day.date.formatted(.dateTime.weekday(.abbreviated).locale(VeyraHomeFormat.locale)))
                .font(.system(size: compact ? 11 : 20, weight: .bold))
                .tracking(compact ? 0.8 : 2.4)
                .textCase(.uppercase)
                .foregroundStyle(VeyraHomeStyle.dim)
            Text(day.date.formatted(.dateTime.day()))
                .font(.system(size: compact ? 18 : 36, weight: .bold))
                .monospacedDigit()
            HStack(spacing: compact ? 3 : 6) {
                if day.count == 0 {
                    Text("–").font(compact ? .caption2 : .callout).foregroundStyle(VeyraHomeStyle.faint)
                } else {
                    ForEach(0..<min(day.count, 3), id: \.self) { _ in
                        Circle().fill(VeyraHomeStyle.cyan)
                            .frame(width: compact ? 6 : 10, height: compact ? 6 : 10)
                            .shadow(color: VeyraHomeStyle.cyan, radius: 4)
                    }
                }
            }
            .frame(height: compact ? 8 : 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 8 : 16)
        .background(day.isToday ? Color.white.opacity(0.10) : Color.clear, in: shape)
        .overlay(alignment: .top) {
            if day.isToday {
                Capsule().fill(VeyraHomeStyle.cyan)
                    .frame(height: 3).padding(.horizontal, compact ? 8 : 14)
                    .shadow(color: VeyraHomeStyle.cyan, radius: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(VeyraHomeFormat.locale))): \(day.count) nieuw")
    }
}
