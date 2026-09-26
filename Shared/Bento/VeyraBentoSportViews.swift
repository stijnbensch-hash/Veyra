// VeyraBentoSportViews.swift — gedeeld door tvOS en iOS/macOS (tvOS 17+ / iOS 17+ / macOS 14+)
// Veyra-stijl bouwstenen voor de sectie "Sport":
//   glas boven een wazig veld · rood alleen voor live · cyaan voor komende wedstrijden en focus ·
//   elk kader eindigt op een tijdlijn-lijn (rood = live voortgang, cyaan = aftellen naar de aftrap)
//
// De inhoudsviews hebben een `compact`-vlag: false = tvOS-maten, true = telefoon/tablet.
// Vereist: VeyraBentoStyle.swift, VeyraBentoSportModel.swift, VeyraBentoEPGModel.swift (SourceHealth), VeyraBentoTrakt.swift.

import SwiftUI

// MARK: - Hulpfuncties

enum VeyraSportFormat {
    /// "Club Brugge" -> "CB", "Anderlecht" -> "AN", "Man City" -> "MC"
    static func initials(_ name: String) -> String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" }).filter { !$0.isEmpty }
        if words.count >= 2 {
            return String(words.prefix(2).compactMap(\.first)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    /// Tekst voor de aftrap, zelfde notatie als de rest van de home (VeyraHomeFormat.when).
    static func kickoff(_ start: Date, now: Date) -> String {
        VeyraHomeFormat.when(start, now: now)
    }

    /// Progressie naar de aftrap: 0 ver weg (>= 3 uur) … 1 net begonnen.
    static func countdownProgress(to start: Date, now: Date) -> Double {
        let window: TimeInterval = 3 * 3600
        let remaining = start.timeIntervalSince(now)
        return min(max(1 - remaining / window, 0), 1)
    }
}

extension SourceHealth {
    var sportTint: Color {
        switch self {
        case .good: return Color(red: 0.30, green: 0.85, blue: 0.50)
        case .degraded: return Color(red: 1.0, green: 0.68, blue: 0.25)
        case .down: return Color.white.opacity(0.4)
        }
    }
}

// MARK: - Veld (plaatshouder tot er een beeld is)

/// Rustig groen veld met lijnen; een echte backdrop (TMDB/EPG) komt er bovenop zodra hij binnen is.
struct VeyraSportBackdrop: View {
    let url: URL?
    let seed: String
    /// Groot, zacht logo van de competitie op de achtergrond (leesbaar, overheerst niet).
    var leagueLogoURL: URL? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                pitch(size: geo.size)
                if let url {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase { image.resizable().scaledToFill() }
                    }
                }
                if let leagueLogoURL {
                    AsyncImage(url: leagueLogoURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit()
                                .frame(width: geo.size.height * 0.95, height: geo.size.height * 0.95)
                                .opacity(0.16)
                                .offset(x: geo.size.width * 0.28, y: -geo.size.height * 0.04)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    private func pitch(size: CGSize) -> some View {
        let line = Color.white.opacity(0.10)
        return ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.20, blue: 0.16), Color(red: 0.03, green: 0.11, blue: 0.10)],
                           startPoint: .top, endPoint: .bottom)
            // middenlijn + middencirkel
            Rectangle().fill(line).frame(width: 2)
            Circle().strokeBorder(line, lineWidth: 2).frame(width: min(size.width, size.height) * 0.55)
        }
    }
}

// MARK: - Bronpil

struct VeyraSourcePill: View {
    let health: SourceHealth
    let alternatives: Int
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            Circle().fill(health.sportTint).frame(width: compact ? 7 : 10, height: compact ? 7 : 10)
                .shadow(color: health.sportTint, radius: 4)
            Text(alternatives > 0 ? "\(health.label) · alternatieve bron klaar" : health.label)
                .lineLimit(1)
        }
        .font(compact ? .caption.weight(.semibold) : .callout.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 4 : 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Live-pil

struct VeyraLivePill: View {
    let isLive: Bool
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            if isLive {
                Circle().fill(.white).frame(width: compact ? 6 : 9, height: compact ? 6 : 9)
            }
            Text(isLive ? "Live" : "Straks")
                .font(.system(size: compact ? 12 : 19, weight: .heavy))
                .tracking(compact ? 1.4 : 2.6)
                .textCase(.uppercase)
        }
        .foregroundStyle(isLive ? Color.white : VeyraHomeStyle.cyan)
        .padding(.horizontal, compact ? 10 : 16)
        .padding(.vertical, compact ? 4 : 6)
        .background {
            if isLive {
                Capsule().fill(VeyraHomeStyle.live).shadow(color: VeyraHomeStyle.live.opacity(0.6), radius: 8)
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .overlay {
            if !isLive { Capsule().strokeBorder(VeyraHomeStyle.cyan.opacity(0.6), lineWidth: 1) }
        }
    }
}

// MARK: - Kaart: uitgelichte wedstrijd

struct VeyraLiveMatchContent: View {
    let event: SportEvent
    let now: Date
    let reminderOn: Bool
    var compact = false

    private var live: Bool { event.isLive(at: now) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VeyraSportBackdrop(url: event.backdropURL, seed: event.title, leagueLogoURL: event.leagueLogoURL)
            LinearGradient(colors: [.black.opacity(0.10), .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: compact ? 6 : 12)
                scoreboard
                Spacer(minLength: compact ? 8 : 16)
                footer
            }
            .padding(compact ? 16 : 34)
            .padding(.bottom, compact ? 6 : 8)
        }
        .overlay(alignment: .bottom) {
            if live {
                VeyraHairline(progress: event.progress(at: now) ?? 0, tint: VeyraHomeStyle.live)
            } else {
                VeyraHairline(progress: VeyraSportFormat.countdownProgress(to: event.start, now: now))
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: compact ? 8 : 14) {
            VeyraLivePill(isLive: live, compact: compact)
            Text([event.competition, event.channelLabel]
                .compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: compact ? 12 : 19, weight: .bold))
                .tracking(compact ? 1.2 : 2.2)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var scoreboard: some View {
        if let home = event.home, let away = event.away {
            HStack(alignment: .center, spacing: compact ? 10 : 24) {
                team(home, logo: event.homeLogoURL)
                centre
                team(away, logo: event.awayLogoURL)
            }
        } else {
            VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                Text(event.title)
                    .font(.system(size: compact ? 26 : 56, weight: .bold))
                    .tracking(compact ? 2.4 : 5)
                    .textCase(.uppercase)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text(event.metaLine(at: now))
                    .font(compact ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
                    .foregroundStyle(VeyraHomeStyle.dim)
            }
        }
    }

    private func team(_ name: String, logo: URL?) -> some View {
        VStack(spacing: compact ? 6 : 12) {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                Text(VeyraSportFormat.initials(name))
                    .font(.system(size: compact ? 20 : 44, weight: .heavy))
                    .tracking(compact ? 1 : 2)
                if let logo {
                    AsyncImage(url: logo) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit().padding(compact ? 5 : 10)
                        }
                    }
                }
            }
            .frame(width: compact ? 64 : 140, height: compact ? 64 : 140)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            Text(name)
                .font(.system(size: compact ? 13 : 24, weight: .bold))
                .tracking(compact ? 0.6 : 1.4)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private var centre: some View {
        VStack(spacing: compact ? 2 : 6) {
            if live, let score = event.score {
                Text(score.text)
                    .font(.system(size: compact ? 34 : 84, weight: .bold))
                    .monospacedDigit()
                if let minute = score.minute {
                    Text(minute)
                        .font(.system(size: compact ? 13 : 24, weight: .bold))
                        .foregroundStyle(VeyraHomeStyle.live)
                }
            } else if live {
                Text("VS")
                    .font(.system(size: compact ? 24 : 56, weight: .bold))
                    .tracking(compact ? 2 : 4)
                    .foregroundStyle(VeyraHomeStyle.dim)
                if let remaining = event.remainingMinutes(at: now) {
                    Text("nog \(remaining) min")
                        .font(.system(size: compact ? 13 : 24, weight: .bold))
                        .foregroundStyle(VeyraHomeStyle.live)
                }
            } else {
                Text(event.start.formatted(.dateTime.hour().minute().locale(VeyraHomeFormat.locale)))
                    .font(.system(size: compact ? 30 : 72, weight: .bold))
                    .monospacedDigit()
                Text(VeyraSportFormat.kickoff(event.start, now: now))
                    .font(.system(size: compact ? 12 : 22, weight: .bold))
                    .tracking(compact ? 1 : 2)
                    .textCase(.uppercase)
                    .foregroundStyle(VeyraHomeStyle.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(minWidth: compact ? 84 : 200)
    }

    private var footer: some View {
        HStack(spacing: compact ? 8 : 14) {
            if event.health != .good || event.alternativeSources > 0 {
                VeyraSourcePill(health: event.health, alternatives: event.alternativeSources, compact: compact)
            }
            Spacer(minLength: 0)
            if live {
                HStack(spacing: compact ? 6 : 10) {
                    Image(systemName: "play.fill")
                    Text("Kijk live")
                }
                .font(compact ? .footnote.weight(.bold) : .callout.weight(.bold))
                .foregroundStyle(.black)
                .padding(.horizontal, compact ? 14 : 22)
                .padding(.vertical, compact ? 7 : 10)
                .background(Color.white, in: Capsule())
            } else {
                VeyraReminderPill(isOn: reminderOn, compact: compact)
            }
        }
    }

    private var accessibilityText: String {
        let teams = event.title
        if live {
            let score = event.score.map { ", stand \($0.home) \($0.away)" } ?? ""
            return "Live: \(teams)\(score)"
        }
        return "Straks: \(teams), \(VeyraSportFormat.kickoff(event.start, now: now))"
    }
}

// MARK: - Rij: wedstrijdenlijst

struct VeyraFixtureRowContent: View {
    let event: SportEvent
    let now: Date
    let reminderOn: Bool
    var compact = false

    private var live: Bool { event.isLive(at: now) }

    var body: some View {
        HStack(spacing: compact ? 12 : 20) {
            timeColumn
                .frame(width: compact ? 50 : 84, alignment: .leading)

            VStack(alignment: .leading, spacing: compact ? 1 : 3) {
                Text(event.title)
                    .font(.system(size: compact ? 15 : 22, weight: .bold))
                    .tracking(compact ? 0.8 : 1.4)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text([event.competition, event.channelName.isEmpty ? nil : event.channelName].compactMap { $0 }.joined(separator: " · "))
                    .font(compact ? .footnote : .callout)
                    .foregroundStyle(VeyraHomeStyle.dim)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if live, let score = event.score {
                Text(score.text)
                    .font(.system(size: compact ? 20 : 28, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

            trailing
        }
        .padding(.horizontal, compact ? 14 : 22)
        .padding(.vertical, compact ? 10 : 14)
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        // Enkel de vulling hier -- het cyaan/rode kader komt van de
        // omliggende ButtonStyle (VeyraSportCardStyle), zodat er geen
        // dubbele rand ontstaat.
        .background(
            RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(live
            ? "Live: \(event.title)\(event.score.map { ", stand \($0.text)" } ?? "")"
            : "\(event.title), \(VeyraSportFormat.kickoff(event.start, now: now))")
    }

    @ViewBuilder
    private var timeColumn: some View {
        if live {
            HStack(spacing: compact ? 4 : 6) {
                Circle().fill(VeyraHomeStyle.live).frame(width: compact ? 6 : 8, height: compact ? 6 : 8)
                Text(event.score?.minute ?? "LIVE")
                    .font(.system(size: compact ? 14 : 18, weight: .heavy))
                    .foregroundStyle(VeyraHomeStyle.live)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(event.start.formatted(.dateTime.hour().minute().locale(VeyraHomeFormat.locale)))
                    .font(.system(size: compact ? 17 : 25, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(VeyraHomeStyle.cyan)
                if !Calendar.current.isDate(event.start, inSameDayAs: now) {
                    Text(event.start.formatted(.dateTime.weekday(.abbreviated).day().locale(VeyraHomeFormat.locale)))
                        .font(.system(size: compact ? 11 : 17, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(VeyraHomeStyle.dim)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if event.health != .good {
            Circle().fill(event.health.sportTint).frame(width: compact ? 7 : 10, height: compact ? 7 : 10)
        }
        if live {
            Image(systemName: "play.fill").font(compact ? .footnote : .callout).foregroundStyle(VeyraHomeStyle.dim)
        } else {
            Image(systemName: reminderOn ? "bell.fill" : "bell")
                .font(compact ? .footnote : .callout)
                .foregroundStyle(reminderOn ? VeyraHomeStyle.cyan : VeyraHomeStyle.dim)
        }
    }
}

/// Kop boven het glazen wedstrijdenpaneel.
struct VeyraFixturesHeader: View {
    let liveCount: Int
    var compact = false

    var body: some View {
        HStack {
            Text("Vandaag & straks")
                .font(.system(size: compact ? 13 : 22, weight: .bold))
                .tracking(compact ? 1.6 : 3)
                .textCase(.uppercase)
                .foregroundStyle(VeyraHomeStyle.dim)
            Spacer()
            if liveCount > 0 {
                HStack(spacing: compact ? 5 : 8) {
                    Circle().fill(VeyraHomeStyle.live).frame(width: compact ? 6 : 9, height: compact ? 6 : 9)
                    Text("\(liveCount) live").font(compact ? .caption.weight(.semibold) : .callout.weight(.semibold))
                }
                .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, compact ? 14 : 24)
        .padding(.top, compact ? 12 : 20)
        .padding(.bottom, compact ? 2 : 6)
    }
}

// MARK: - Tegel: competitie

struct VeyraCompetitionContent: View {
    let competition: SportCompetition
    let now: Date
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 10 : 16) {
            competitionLogo
            VStack(alignment: .leading, spacing: 2) {
                Text("Competitie")
                    .font(.system(size: compact ? 9 : 13, weight: .bold))
                    .tracking(compact ? 1.2 : 2.2)
                    .textCase(.uppercase)
                    .foregroundStyle(VeyraHomeStyle.faint)
                Text(competition.name)
                    .font(.system(size: compact ? 14 : 22, weight: .bold))
                    .tracking(compact ? 0.6 : 1.4)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                status
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 14 : 22)
        .padding(.vertical, compact ? 10 : 14)
        .foregroundStyle(.white)
        // Smalle balk i.p.v. het vierkante kader van voorheen -- zelfde
        // stijl als de wedstrijdenrijen in "Vandaag & straks".
        .background(
            RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                .strokeBorder(competition.liveCount > 0 ? VeyraHomeStyle.live.opacity(0.4) : Color.white.opacity(0.10), lineWidth: 1)
        )
        .overlay(alignment: .bottom) {
            if competition.liveCount > 0 {
                VeyraHairline(progress: 1, tint: VeyraHomeStyle.live)
            } else if let next = competition.nextStart {
                VeyraHairline(progress: VeyraSportFormat.countdownProgress(to: next, now: now))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(competition.name), \(competition.liveCount) live, \(competition.eventCount) wedstrijden")
    }

    @ViewBuilder
    private var competitionLogo: some View {
        let size: CGFloat = compact ? 28 : 40
        Group {
            if let url = competition.logoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        competitionPlaceholder
                    }
                }
            } else {
                competitionPlaceholder
            }
        }
        .frame(width: size, height: size)
    }

    private var competitionPlaceholder: some View {
        Image(systemName: "sportscourt.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(VeyraHomeStyle.dim)
    }

    @ViewBuilder
    private var status: some View {
        if competition.liveCount > 0 {
            HStack(spacing: compact ? 5 : 8) {
                Circle().fill(VeyraHomeStyle.live).frame(width: compact ? 6 : 9, height: compact ? 6 : 9)
                Text("\(competition.liveCount) live")
            }
            .font(compact ? .caption.weight(.semibold) : .callout.weight(.semibold))
        } else if let next = competition.nextStart {
            Text(VeyraSportFormat.kickoff(next, now: now))
                .font(compact ? .caption : .callout)
                .foregroundStyle(VeyraHomeStyle.cyan)
                .lineLimit(1)
        }
    }
}
