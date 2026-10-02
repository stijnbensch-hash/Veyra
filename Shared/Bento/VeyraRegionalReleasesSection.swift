// VeyraRegionalReleasesSection.swift — tvOS 17+
// Fase 4 ("NIEUW VAN HIER" spec §4/§30/§31): Home-sectie + datumgroepering voor regionale
// releases, visueel aansluitend bij "Binnenkort" (spec §30: "dezelfde timeline primitives;
// date grouping; typography; spacing; animation language; focus behavior"). De bestaande
// Binnenkort-kalendercomponent (`VeyraCalendarHorizon`) is hardcoded aan `[UpcomingItem]`
// gebonden en wordt momenteel zelf niet meer als losse sectie gebruikt op tvOS Home (Binnenkort
// zit terug in `bentoTop`'s gewone rij, zie `VeyraBentoHome.swift`) -- deze sectie kopieert
// daarom zijn bucket-/groeperingspatroon (vandaag/morgen/deze week/later) voor
// `RegionalReleaseEvent` i.p.v. het bestaande type generiek te maken.
#if os(tvOS)
import SwiftUI

struct VeyraRegionalReleasesRow: View {
    let events: [RegionalReleaseEvent]
    let now: Date
    var focus: FocusState<VeyraHomeFocus?>.Binding
    let onOpen: (RegionalReleaseEvent) -> Void
    /// Spec §32/§58 (fase 11): enkel aangeboden wanneer een kanaal betrouwbaar bekend EN
    /// zichtbaar is in Veyra -- zie `isLiveRelevant(_:now:)` hieronder. De call site in
    /// `VeyraBentoHome.swift` geeft dit rechtstreeks door aan de al bestaande
    /// `onPlayChannel`/`playableSource(forChannelID:)`, die verborgen/uitgeschakelde kanalen al
    /// zelf uitsluit (spec §59) -- geen tweede zichtbaarheidscheck nodig.
    var onPlayLive: (String) -> Void = { _ in }

    @State private var mode: ViewMode = .new

    /// Spec §31: "[ NIEUW ] [ DEZE WEEK ] [ KALENDER ]" boven de sectie.
    private enum ViewMode: String, CaseIterable, Hashable {
        case new = "Nieuw"
        case week = "Deze week"
        case calendar = "Kalender"
    }

    private enum Bucket: Int, CaseIterable, Hashable {
        case today, tomorrow, week, later

        var title: String {
            switch self {
            case .today: return "Vandaag"
            case .tomorrow: return "Morgen"
            case .week: return "Deze week"
            case .later: return "Later"
            }
        }
    }

    private func bucket(for event: RegionalReleaseEvent) -> Bucket {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: event.releaseDate)
        ).day ?? 0
        if days <= 0 { return .today }
        if days == 1 { return .tomorrow }
        if days <= 6 { return .week }
        return .later
    }

    /// Spec §27: binnen elke datum-emmer blijft de Home-prioriteit (newSeries vóór newSeason
    /// vóór premiere/upcomingPremiere vóór episode) bepalend -- `events` komt al zo gesorteerd
    /// binnen via `RegionalReleaseRepository`, dus hier enkel groeperen, niet hersorteren.
    private var groups: [(Bucket, [RegionalReleaseEvent])] {
        var buckets: [Bucket: [RegionalReleaseEvent]] = [:]
        for event in events { buckets[bucket(for: event), default: []].append(event) }
        return Bucket.allCases.compactMap { bucket in
            guard let items = buckets[bucket], !items.isEmpty else { return nil }
            return (bucket, items)
        }
    }

    /// Spec §31 ("Deze week"-tab): vlakke lijst zonder datumkoppen, op datum gesorteerd.
    private var weekItems: [RegionalReleaseEvent] {
        let calendar = Calendar.current
        return events
            .filter {
                let days = calendar.dateComponents(
                    [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: $0.releaseDate)
                ).day ?? Int.max
                return days >= 0 && days <= 6
            }
            .sorted { $0.releaseDate < $1.releaseDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 18) {
                VeyraHomeSectionHeader(title: "Nieuw van hier")
                Spacer(minLength: 0)
                modeSwitcher
            }

            switch mode {
            case .new:
                ForEach(groups, id: \.0) { bucket, items in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(bucket.title)
                            .font(.system(size: 17, weight: .semibold))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundStyle(VeyraHomeStyle.dim)
                            .padding(.horizontal, 12)

                        cardRow(items)
                    }
                }
            case .week:
                if weekItems.isEmpty {
                    Text("Geen releases deze week")
                        .font(.callout)
                        .foregroundStyle(VeyraHomeStyle.dim)
                        .padding(.horizontal, 12)
                } else {
                    cardRow(weekItems)
                }
            case .calendar:
                VeyraRegionalCalendarView(events: events, now: now, focus: focus, onOpen: onOpen, onPlayLive: onPlayLive)
            }
        }
    }

    @ViewBuilder
    private var modeSwitcher: some View {
        HStack(spacing: 14) {
            ForEach(ViewMode.allCases, id: \.self) { option in
                Button { mode = option } label: {
                    Text(option.rawValue.uppercased())
                        .font(.system(size: 20, weight: .bold))
                        .tracking(1.2)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(mode == option ? VeyraHomeStyle.cyan.opacity(0.85) : Color.white.opacity(0.08),
                                    in: Capsule())
                        .foregroundStyle(mode == option ? Color.black : Color.white.opacity(0.85))
                }
                // `VeyraRowStyle` onderdrukt (via `.focusEffectDisabled()`) tvOS' eigen witte
                // focus-halo -- zelfde patroon als elders in Bento (`.buttonStyle(.plain)` alleen
                // is hier niet genoeg, dat liet de systeemhalo gewoon doorschijnen).
                .buttonStyle(VeyraRowStyle(cornerRadius: 22))
                .focused(focus, equals: .shelf("regional-mode-\(option.rawValue)"))
            }
        }
    }

    // Zelfde losse-kaarten-op-een-rij-opbouw als "Binnenkort" in `bentoTop`, nu gedeeld door de
    // "Nieuw"-buckets, de "Deze week"-tab én de kalender-daglijst hieronder.
    @ViewBuilder
    private func cardRow(_ items: [RegionalReleaseEvent]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 24) {
                ForEach(items) { event in
                    Button { onOpen(event) } label: {
                        VeyraBentoRegionalCardContent(event: event, now: now)
                    }
                    .buttonStyle(VeyraCaptionedTileStyle())
                    // Spec §62: ontbrekende TMDB-data verwijdert de release niet, maar zonder
                    // `tmdbID` is er ook nog geen detailscherm om naar te gaan -- kaart blijft
                    // zichtbaar, enkel (nog) niet selecteerbaar.
                    .disabled(event.tmdbID == nil)
                    .focused(focus, equals: .shelf("regional-\(event.id)"))
                    .frame(width: VeyraCaptionedCardLayout.tv.width,
                           height: VeyraCaptionedCardLayout.tv.height)
                    .contextMenu {
                        // Spec §8/§32: "Bekijken" (de gewone knop hierboven) blijft primair --
                        // "Kijk live" is een secundaire actie, net als "Verwijder uit Verder
                        // kijken"/"Herinner mij" elders al via het contextmenu lopen.
                        if Self.isLiveRelevant(event, now: now), let channelID = event.channelID {
                            Button { onPlayLive(channelID) } label: {
                                Label("Kijk live", systemImage: "dot.radiowaves.left.and.right")
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
        }
        .scrollClipDisabled()
    }

    /// Spec §32/§58: "Live" is secundair en enkel relevant rond het eigen uitzendmoment -- enkel
    /// vandaag, en het programma is net begonnen of begint binnen een paar uur (ruim genoeg voor
    /// een normale uitzending, strak genoeg om geen dag-oude "live"-knop te tonen).
    static func isLiveRelevant(_ event: RegionalReleaseEvent, now: Date) -> Bool {
        guard event.channelID != nil, let airDate = event.airDate else { return false }
        guard Calendar.current.isDate(airDate, inSameDayAs: now) else { return false }
        let window = airDate.addingTimeInterval(-900)...airDate.addingTimeInterval(4 * 3600)
        return window.contains(now)
    }
}

// MARK: - Kaart

struct VeyraBentoRegionalCardContent: View {
    let event: RegionalReleaseEvent
    let now: Date
    var cardLayout: VeyraCaptionedCardLayout = .tv

    @Environment(\.isFocused) private var isFocused
    // Fase 3 stap 3 (artwork-engine-spec §29/§30/§47): voorheen altijd `nil` -- "Nieuw van
    // hier" kreeg hierdoor nooit een ClearLogo, ongeacht de gekozen metadatabron.
    @State private var logoURL: URL?
    // §66: zelfde herlaad-signaal als `VeyraClearLogo`/`VeyraContextRibbon`.
    @ObservedObject private var artworkRefresh = ArtworkRefreshSignal.shared

    private var typeLabel: String {
        switch event.releaseType {
        case .newSeries: return "Nieuwe serie"
        case .newSeason: return "Nieuw seizoen"
        case .premiere: return "Première"
        case .upcomingPremiere: return "Binnenkort"
        case .episode: return "Nieuwe aflevering"
        }
    }

    private var providerLabel: String { event.providerID.uppercased() }

    private var accessibilityDescription: String {
        let date = VeyraHomeFormat.when(event.airDate ?? event.releaseDate, now: now, dateOnly: event.airDate == nil)
        return [event.title, providerLabel, typeLabel, date].joined(separator: ", ")
    }

    var body: some View {
        // Zelfde eigen vorm als de andere Home-kaarten (twee diagonaal sterker afgeronde hoeken).
        let shape = VeyraRadius.posterShape

        VStack(alignment: .leading, spacing: cardLayout.spacing) {
            ZStack {
                VeyraArt(url: TMDBImageURLBuilder.backdrop(event.backdropPath), seed: event.title, contentMode: .fit)
                LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .top)
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(typeLabel.uppercased())
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(VeyraHomeStyle.cyan.opacity(0.85), in: Capsule())
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                    // Spec §68: provider klein, de kaart blijft verder visueel Veyra.
                    Text(providerLabel)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(14)
            }
            .frame(height: cardLayout.artworkHeight)
            .scaleEffect(isFocused ? 1.045 : 1)
            .clipShape(shape)
            .overlay(shape.strokeBorder(isFocused ? VeyraFrame.active : VeyraFrame.resting,
                                        lineWidth: isFocused ? 3 : 1.5))
            .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.32) : .black.opacity(0.3),
                    radius: isFocused ? 22 : 14, x: isFocused ? -5 : 0, y: isFocused ? 3 : 10)

            HStack(alignment: .center, spacing: 14) {
                VeyraTitleLogo(title: event.title, logoURL: logoURL, size: 30, maxLogoHeight: cardLayout.captionHeight)

                HStack(spacing: 6) {
                    // Spec §68: rood is gereserveerd voor LIVE/urgent.
                    if VeyraRegionalReleasesRow.isLiveRelevant(event, now: now) {
                        Circle().fill(Color.red).frame(width: 7, height: 7)
                    }
                    Text(VeyraHomeFormat.when(event.airDate ?? event.releaseDate, now: now, dateOnly: event.airDate == nil))
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(VeyraHomeStyle.cyan)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(height: cardLayout.captionHeight)
            .padding(.horizontal, 14)
        }
        .foregroundStyle(.white)
        .opacity(event.tmdbID == nil ? 0.6 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .task(id: "\(event.tmdbID ?? -1):\(artworkRefresh.generation)") {
            // Zelfde centrale `ArtworkResolver` als Detail/Hero/Bento -- de regionale bron
            // hoeft zelf geen artwork te leveren (spec §47: "de regionale bron hoeft dus geen
            // perfecte artwork te leveren"). `season` als heuristiek voor film/serie, zoals de
            // regionale releaseproviders die elders ook gebruiken.
            guard event.tmdbID != nil || (event.imdbID?.isEmpty == false) else { return }
            let mediaKind: MediaType = event.season != nil ? .series : .movie
            logoURL = await ArtworkResolver.shared.clearLogoURL(
                for: MediaItem(title: event.title, type: mediaKind, imdbID: event.imdbID, tmdbID: event.tmdbID)
            )
        }
    }
}

// MARK: - Kalender (spec §31/§57)

/// Maandraster + daglijst voor "Nieuw van hier", visueel aansluitend bij de rest van de sectie
/// (zelfde kaart, typografie en kleuren -- spec §30) in plaats van een aparte
/// kalendercomponent-architectuur op te zetten.
struct VeyraRegionalCalendarView: View {
    let events: [RegionalReleaseEvent]
    let now: Date
    var focus: FocusState<VeyraHomeFocus?>.Binding
    let onOpen: (RegionalReleaseEvent) -> Void
    let onPlayLive: (String) -> Void

    @State private var selectedDay: Date

    init(events: [RegionalReleaseEvent], now: Date, focus: FocusState<VeyraHomeFocus?>.Binding,
         onOpen: @escaping (RegionalReleaseEvent) -> Void, onPlayLive: @escaping (String) -> Void) {
        self.events = events
        self.now = now
        self.focus = focus
        self.onOpen = onOpen
        self.onPlayLive = onPlayLive
        _selectedDay = State(initialValue: Calendar.current.startOfDay(for: now))
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Maandag, zoals het spec-voorbeeld (MA..ZO).
        return cal
    }

    private var eventsByDay: [Date: [RegionalReleaseEvent]] {
        Dictionary(grouping: events) { calendar.startOfDay(for: $0.releaseDate) }
    }

    /// 6 volle weken (42 dagen) vanaf de maandag van de eerste week -- dekt elke maandlay-out
    /// zonder sprongen, en toont zo ook de laatste dagen van de vorige/volgende maand als vulling.
    private var monthDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return [] }
        let firstOfMonth = monthInterval.start
        let leadingWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingOffset = (leadingWeekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingOffset, to: firstOfMonth) else { return [] }

        var days: [Date] = []
        var day = gridStart
        for _ in 0..<42 {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    private var monthTitle: String {
        now.formatted(.dateTime.month(.wide).year().locale(VeyraHomeFormat.locale)).capitalized
    }

    private static let weekdaySymbols = ["MA", "DI", "WO", "DO", "VR", "ZA", "ZO"]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(monthTitle)
                .font(.system(size: 17, weight: .semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(VeyraHomeStyle.dim)
                .padding(.horizontal, 12)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 10) {
                ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 15, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(VeyraHomeStyle.dim)
                        .frame(maxWidth: .infinity)
                }
                ForEach(monthDays, id: \.self) { day in
                    dayCell(day)
                }
            }
            .padding(.horizontal, 12)

            dayDetail
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: now, toGranularity: .month)
        let hasEvents = !(eventsByDay[day]?.isEmpty ?? true)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let dayNumber = calendar.component(.day, from: day)

        Button { selectedDay = day } label: {
            VStack(spacing: 6) {
                Text("\(dayNumber)")
                    .font(.system(size: 22, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(inMonth ? .white.opacity(isSelected ? 1 : 0.85) : .white.opacity(0.25))
                Circle()
                    .fill(hasEvents ? VeyraHomeStyle.cyan : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(isSelected ? VeyraHomeStyle.cyan.opacity(0.18) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10))
        }
        // Zie `modeSwitcher` hierboven: `VeyraRowStyle` i.p.v. `.plain` om tvOS' witte
        // systeem-focushalo te onderdrukken (`.focusEffectDisabled()`).
        .buttonStyle(VeyraRowStyle(cornerRadius: 10))
        // Spec §69: stabiele focus-ID's; een lege dag blijft gewoon selecteerbaar (zoals
        // Binnenkort), de timeline-decoratie (puntje) zelf is geen apart focusbaar element.
        .focused(focus, equals: .shelf("regional-cal-day-\(Int(day.timeIntervalSince1970))"))
    }

    @ViewBuilder
    private var dayDetail: some View {
        let items = eventsByDay[selectedDay] ?? []
        VStack(alignment: .leading, spacing: 8) {
            Text(VeyraHomeFormat.when(selectedDay, now: now, dateOnly: true))
                .font(.system(size: 17, weight: .semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(VeyraHomeStyle.dim)
                .padding(.horizontal, 12)

            if items.isEmpty {
                Text("Geen releases op deze dag")
                    .font(.callout)
                    .foregroundStyle(VeyraHomeStyle.dim)
                    .padding(.horizontal, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 24) {
                        ForEach(items) { event in
                            Button { onOpen(event) } label: {
                                VeyraBentoRegionalCardContent(event: event, now: now)
                            }
                            .buttonStyle(VeyraCaptionedTileStyle())
                            .disabled(event.tmdbID == nil)
                            .focused(focus, equals: .shelf("regional-cal-item-\(event.id)"))
                            .frame(width: VeyraCaptionedCardLayout.tv.width,
                                   height: VeyraCaptionedCardLayout.tv.height)
                            .contextMenu {
                                if VeyraRegionalReleasesRow.isLiveRelevant(event, now: now), let channelID = event.channelID {
                                    Button { onPlayLive(channelID) } label: {
                                        Label("Kijk live", systemImage: "dot.radiowaves.left.and.right")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                }
                .scrollClipDisabled()
            }
        }
    }
}
#endif
