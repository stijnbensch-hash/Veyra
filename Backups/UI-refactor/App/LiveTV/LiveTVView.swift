import SwiftUI
import Foundation

@MainActor
struct LiveTVView: View {
    @StateObject private var guide = VeyraEPGStore()

    @State private var showProviders = false
    @State private var selection: VeyraEPGSelection?
    @State private var selectedSource: PlayableSource?
    @State private var pendingSource: PlayableSource?

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            VeyraEPGTheme.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                toolbar

                searchBar

                if let error = guide.channelError {
                    Text(error)
                        .font(.system(size: 18))
                        .foregroundStyle(.orange)
                }

                HStack(alignment: .top, spacing: 22) {
                    sidebar
                        .frame(width: 250)

                    TimelineView(
                        .periodic(from: .now, by: 60)
                    ) { context in
                        programmeGrid(now: context.date)
                    }
                    .focusSection()
                }

                footer
            }
            .padding(.horizontal, 50)
            .padding(.vertical, 32)
        }
        .foregroundStyle(.white)
        .task(id: guide.reloadID) {
            await guide.reload()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .iptvConfigurationDidChange
            )
        ) { _ in
            selection = nil
            guide.reloadID = UUID()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                guide.reloadID = UUID()
            }
        }
        .confirmationDialog(
            "Kies je IPTV-provider",
            isPresented: $showProviders,
            titleVisibility: .visible
        ) {
            ForEach(guide.providers) { provider in
                Button(
                    provider.displayName
                        + (
                            provider.id == guide.activeProviderID
                                ? " (actief)"
                                : ""
                        )
                ) {
                    guide.selectProvider(provider)
                }
            }

            Button("Annuleren", role: .cancel) {}
        }
        .sheet(
            item: $selection,
            onDismiss: {
                if let source = pendingSource {
                    pendingSource = nil
                    selectedSource = source
                }
            }
        ) { selection in
            VeyraEPGDetails(
                selection: selection,
                guide: guide
            ) {
                pendingSource = guide.play(selection.row)
                self.selection = nil
            }
        }
        .navigationDestination(
            item: $selectedSource
        ) { source in
            PlayerView(source: source)
        }
    }

    // MARK: - Bovenbalk

    private var toolbar: some View {
        HStack(spacing: 18) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.cyan)
                    .frame(width: 4, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text("LIVE TV")
                        .font(
                            .system(
                                size: 32,
                                weight: .light
                            )
                        )
                        .tracking(5)

                    Text("JOUW PROGRAMMAGIDS")
                        .font(
                            .system(
                                size: 12,
                                weight: .medium
                            )
                        )
                        .tracking(2)
                        .foregroundStyle(
                            .cyan.opacity(0.75)
                        )
                }
            }

            Spacer(minLength: 10)

            Button {
                showProviders = true
            } label: {
                Label(
                    guide.providerName,
                    systemImage:
                        "antenna.radiowaves.left.and.right"
                )
                .lineLimit(1)
                .frame(maxWidth: 300)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(VeyraEPGButtonStyle())
            .disabled(guide.providers.isEmpty)

            Button {
                guide.showNow()
            } label: {
                Label(
                    "Nu",
                    systemImage: "clock"
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(VeyraEPGButtonStyle())

            Button {
                guide.reloadID = UUID()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(VeyraEPGButtonStyle())
            .disabled(
                guide.loadingChannels || guide.loadingGuide
            )
            .accessibilityLabel(
                "Zenders en programmagids vernieuwen"
            )

            NavigationLink {
                IPTVAccountsView()
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(VeyraEPGButtonStyle())
            .accessibilityLabel(
                "IPTV-providers beheren"
            )
        }
        .font(
            .system(
                size: 18,
                weight: .semibold
            )
        )
        .focusSection()
    }

    // MARK: - Zoeken
    //
    // Eigen Veyra-container.
    // De standaard witte tvOS-TextField achtergrond wordt verwijderd.

    private var searchBar: some View {
        HStack(spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(
                        .system(
                            size: 18,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        .cyan.opacity(0.75)
                    )

                TextField(
                    "Zoek zenders en programma's in dit tijdvak",
                    text: $guide.searchText
                )
                .font(.system(size: 18))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 54)
            .background(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .fill(
                    Color(
                        red: 0.035,
                        green: 0.10,
                        blue: 0.16
                    )
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .strokeBorder(
                    Color.cyan.opacity(0.12),
                    lineWidth: 1
                )
            )

            if !guide.searchText.isEmpty {
                Button {
                    guide.searchText = ""
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(VeyraEPGButtonStyle())
                .accessibilityLabel(
                    "Zoekopdracht wissen"
                )
            }
        }
    }

    // MARK: - Categorieën

    private var sidebar: some View {
        ScrollView(
            .vertical,
            showsIndicators: false
        ) {
            VStack(alignment: .leading, spacing: 10) {
                categoryButton(
                    "Alle zenders",
                    icon: "tv",
                    key: "all",
                    count: guide.channels.count
                )

                categoryButton(
                    "Favorieten",
                    icon: "star",
                    key: "favorites",
                    count: guide.channels.filter {
                        guide.favorites.contains($0.id)
                    }.count
                )

                categoryButton(
                    "Recent geopend",
                    icon: "clock.arrow.circlepath",
                    key: "recent",
                    count: guide.channels.filter {
                        guide.recent.contains($0.id)
                    }.count
                )

                Text("CATEGORIEËN")
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )
                    .tracking(2)
                    .foregroundStyle(
                        .cyan.opacity(0.6)
                    )
                    .padding(.top, 18)
                    .padding(.bottom, 6)

                ForEach(guide.categories) { category in
                    categoryButton(
                        category.name,
                        icon: nil,
                        key: "group:" + category.id,
                        count: nil
                    )
                }
            }
            .padding(4)
        }
        .focusSection()
    }

    private func categoryButton(
        _ title: String,
        icon: String?,
        key: String,
        count: Int?
    ) -> some View {
        Button {
            guide.selectedCategory = key
        } label: {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .frame(width: 22)
                }

                Text(title)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 4)

                if let count {
                    Text("\(count)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .font(
                .system(
                    size: 17,
                    weight: .medium
                )
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(
                maxWidth: .infinity,
                minHeight: 50,
                alignment: .leading
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle(
                selected: guide.selectedCategory == key
            )
        )
    }

    // MARK: - Programmagids

    private func programmeGrid(
        now: Date
    ) -> some View {
        let rows = guide.visibleChannels

        return GeometryReader { geometry in
            let channelWidth: CGFloat = 190

            let timelineWidth = max(
                240,
                geometry.size.width - channelWidth - 12
            )

            VStack(spacing: 12) {
                HStack {
                    Text(
                        VeyraEPGFormat.day(guide.windowStart)
                    )
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                    )

                    Spacer()

                    Button {
                        guide.moveWindow(-3)
                    } label: {
                        Label(
                            "3 uur",
                            systemImage: "chevron.left"
                        )
                        .padding(10)
                    }
                    .buttonStyle(VeyraEPGButtonStyle())

                    Button {
                        guide.moveWindow(3)
                    } label: {
                        HStack(spacing: 8) {
                            Text("3 uur")
                            Image(systemName: "chevron.right")
                        }
                        .padding(10)
                    }
                    .buttonStyle(VeyraEPGButtonStyle())
                }
                .font(
                    .system(
                        size: 16,
                        weight: .semibold
                    )
                )

                HStack(spacing: 12) {
                    Text("ZENDER")
                        .font(
                            .system(
                                size: 13,
                                weight: .medium
                            )
                        )
                        .tracking(2)
                        .foregroundStyle(.secondary)
                        .frame(
                            width: channelWidth,
                            alignment: .leading
                        )

                    timeRuler(
                        width: timelineWidth,
                        now: now
                    )
                }
                .frame(height: 35)

                if guide.loadingChannels {
                    ProgressView("Zenders laden...")
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
                } else if rows.isEmpty {
                    Text(
                        guide.searchText.isEmpty
                            ? "Geen zichtbare zenders in deze selectie."
                            : "Geen zoekresultaten in dit tijdvak."
                    )
                    .foregroundStyle(.secondary)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(
                            .vertical,
                            showsIndicators: false
                        ) {
                            LazyVStack(spacing: 8) {
                                ForEach(rows) { row in
                                    HStack(spacing: 12) {
                                        channelButton(
                                            row,
                                            now: now
                                        )
                                        .frame(
                                            width: channelWidth
                                        )

                                        programmeRow(
                                            row,
                                            width: timelineWidth,
                                            now: now
                                        )
                                    }
                                    .frame(height: 88)
                                    .id(row.id)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onChange(
                            of: guide.selectedCategory
                        ) { _, _ in
                            if let id =
                                guide.visibleChannels.first?.id {
                                proxy.scrollTo(
                                    id,
                                    anchor: .top
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func timeRuler(
        width: CGFloat,
        now: Date
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<6, id: \.self) { index in
                Text(
                    VeyraEPGFormat.time(
                        guide.windowStart.addingTimeInterval(
                            Double(index) * 1_800
                        )
                    )
                )
                .font(
                    .system(
                        size: 15,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.6)
                )
                .offset(
                    x: width * CGFloat(index) / 6
                )
            }

            if now >= guide.windowStart
                && now < guide.windowEnd {
                Image(
                    systemName: "arrowtriangle.down.fill"
                )
                .font(.system(size: 11))
                .foregroundStyle(.cyan)
                .offset(
                    x: width
                        * now.timeIntervalSince(
                            guide.windowStart
                        )
                        / guide.windowDuration - 5,
                    y: 22
                )
            }
        }
        .frame(
            width: width,
            height: 35,
            alignment: .topLeading
        )
        .accessibilityHidden(true)
    }

    private func channelButton(
        _ row: VeyraGuideChannel,
        now: Date
    ) -> some View {
        Button {
            selection = VeyraEPGSelection(
                row: row,
                programme: guide.programmes(for: row).first {
                    $0.isOnAir(at: now)
                }
            )
        } label: {
            HStack(spacing: 12) {
                AsyncImage(
                    url: row.channel.logoURL
                ) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "tv")
                            .font(.system(size: 26))
                            .foregroundStyle(
                                .cyan.opacity(0.5)
                            )
                    }
                }
                .frame(width: 56, height: 50)

                VStack(alignment: .leading, spacing: 5) {
                    Text(row.channel.name)
                        .font(
                            .system(
                                size: 16,
                                weight: .semibold
                            )
                        )
                        .lineLimit(2)

                    if guide.favorites.contains(row.id) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.cyan)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(
                maxWidth: .infinity,
                minHeight: 88,
                maxHeight: 88
            )
        }
        .buttonStyle(VeyraEPGButtonStyle())
        .accessibilityLabel(row.channel.name)
        .accessibilityHint(
            "Opent zenderinformatie en Kijk live"
        )
    }

    private func programmeRow(
        _ row: VeyraGuideChannel,
        width: CGFloat,
        now: Date
    ) -> some View {
        let slots = VeyraEPGSlot.make(
            guide.programmes(for: row),
            from: guide.windowStart,
            to: guide.windowEnd
        )

        return HStack(spacing: 0) {
            ForEach(slots) { slot in
                let span = width
                    * slot.end.timeIntervalSince(slot.start)
                    / guide.windowDuration

                Button {
                    selection = VeyraEPGSelection(
                        row: row,
                        programme: slot.programme
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        if span > 60 {
                            Text(
                                slot.programme?.title
                                    ?? (
                                        guide.loadingGuide
                                            ? "Gids laden..."
                                            : "Geen programma-informatie"
                                    )
                            )
                            .font(
                                .system(
                                    size: 17,
                                    weight: .semibold
                                )
                            )
                            .lineLimit(2)

                            if let programme = slot.programme,
                               span > 95 {
                                HStack(spacing: 7) {
                                    Text(
                                        VeyraEPGFormat.time(
                                            programme.start
                                        )
                                    )
                                    .foregroundStyle(
                                        .white.opacity(0.65)
                                    )

                                    if programme.isOnAir(at: now) {
                                        Text("NU")
                                            .foregroundStyle(.cyan)
                                            .bold()
                                    }
                                }
                                .font(.system(size: 12))
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(
                        .horizontal,
                        span > 60 ? 12 : 0
                    )
                    .padding(.vertical, 12)
                    .frame(
                        width: max(0, span - 3),
                        height: 88,
                        alignment: .topLeading
                    )
                    .clipped()
                }
                .buttonStyle(
                    VeyraEPGButtonStyle(
                        onAir:
                            slot.programme?.isOnAir(at: now) == true
                    )
                )
                .frame(
                    width: span,
                    alignment: .leading
                )
                .accessibilityLabel(
                    (
                        slot.programme?.title
                            ?? "Geen programma-informatie"
                    ) + ", " + row.channel.name
                )
                .accessibilityHint(
                    "Toon programmadetails; begint niet automatisch met afspelen"
                )
            }
        }
        .frame(
            width: width,
            height: 88,
            alignment: .leading
        )
        .overlay(alignment: .leading) {
            if now >= guide.windowStart
                && now < guide.windowEnd {
                Rectangle()
                    .fill(
                        Color.cyan.opacity(0.7)
                    )
                    .frame(width: 2)
                    .offset(
                        x: width
                            * now.timeIntervalSince(
                                guide.windowStart
                            )
                            / guide.windowDuration
                    )
                    .allowsHitTesting(false)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if guide.loadingGuide {
                ProgressView()
                    .scaleEffect(0.65)
            }

            Text(
                guide.loadingGuide
                    ? "Programmagids laden; zenders zijn al beschikbaar."
                    : (
                        guide.guideMessage
                            ?? "Selecteer een programma voor informatie of kies Kijk live."
                    )
            )
            .font(.system(size: 14))
            .foregroundStyle(
                .white.opacity(0.55)
            )
            .lineLimit(2)

            Spacer(minLength: 0)
        }
        .frame(minHeight: 24)
    }
}

// MARK: - Selectie

private struct VeyraEPGSelection: Identifiable {
    let row: VeyraGuideChannel
    let programme: VeyraEPGProgramme?

    var id: String {
        "\(row.id):\(programme?.id ?? "channel")"
    }
}

// MARK: - Programmadetails

@MainActor
private struct VeyraEPGDetails: View {
    let selection: VeyraEPGSelection

    @ObservedObject var guide: VeyraEPGStore

    let onPlay: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VeyraEPGTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(selection.row.channel.name)
                        .font(
                            .system(
                                size: 22,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.cyan)

                    Text(
                        selection.programme?.title
                            ?? "Zenderinformatie"
                    )
                    .font(
                        .system(
                            size: 38,
                            weight: .semibold
                        )
                    )

                    if let programme = selection.programme {
                        Text(
                            VeyraEPGFormat.day(programme.start)
                                + "  "
                                + VeyraEPGFormat.time(programme.start)
                                + " - "
                                + VeyraEPGFormat.time(programme.end)
                        )
                        .foregroundStyle(
                            .cyan.opacity(0.8)
                        )

                        if !programme.subtitle.isEmpty {
                            Text(programme.subtitle)
                                .font(.title3)
                        }

                        Text(
                            programme.summary.isEmpty
                                ? "Geen beschrijving beschikbaar."
                                : programme.summary
                        )
                        .foregroundStyle(
                            .white.opacity(0.75)
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                        if programme.estimatedEnd {
                            Text(
                                "De eindtijd is afgeleid van het volgende programma."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        if !programme.isOnAir(at: Date()) {
                            Text(
                                "Kijk live opent de huidige uitzending van deze zender, niet dit geplande of afgelopen programma. Terugkijken is in deze gids nog niet ingebouwd."
                            )
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(
                            "Geen programma-informatie voor dit tijdvak. De livezender blijft beschikbaar."
                        )
                        .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 20) {
                        Button(action: onPlay) {
                            Label(
                                "Kijk live",
                                systemImage: "play.fill"
                            )
                            .padding(16)
                        }
                        .buttonStyle(
                            VeyraEPGButtonStyle(
                                selected: true
                            )
                        )

                        Button {
                            guide.toggleFavorite(
                                selection.row
                            )
                        } label: {
                            Label(
                                guide.favorites.contains(
                                    selection.row.id
                                )
                                    ? "Favoriet verwijderen"
                                    : "Favoriet maken",
                                systemImage:
                                    guide.favorites.contains(
                                        selection.row.id
                                    )
                                    ? "star.fill"
                                    : "star"
                            )
                            .padding(16)
                        }
                        .buttonStyle(
                            VeyraEPGButtonStyle()
                        )

                        Button("Sluiten") {
                            dismiss()
                        }
                        .padding(16)
                        .buttonStyle(
                            VeyraEPGButtonStyle()
                        )
                    }
                }
                .frame(
                    maxWidth: 1200,
                    alignment: .leading
                )
                .padding(60)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Eigen Veyra-knopstijl

private struct VeyraEPGButtonStyle: ButtonStyle {
    var selected = false
    var onAir = false

    func makeBody(
        configuration: Configuration
    ) -> some View {
        VeyraEPGButtonSurface(
            label: configuration.label,
            pressed: configuration.isPressed,
            selected: selected,
            onAir: onAir
        )
    }
}

private struct VeyraEPGButtonSurface<Label: View>: View {
    let label: Label
    let pressed: Bool
    let selected: Bool
    let onAir: Bool

    @Environment(\.isFocused) private var isFocused
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .fill(
                    isFocused
                        ? Color.cyan.opacity(0.24)
                        : selected
                            ? Color.cyan.opacity(0.16)
                            : onAir
                                ? Color(
                                    red: 0.035,
                                    green: 0.20,
                                    blue: 0.25
                                )
                                : Color(
                                    red: 0.035,
                                    green: 0.10,
                                    blue: 0.16
                                )
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .strokeBorder(
                    isFocused
                        ? Color.cyan
                        : Color.cyan.opacity(
                            selected ? 0.45 : 0.08
                        ),
                    lineWidth: isFocused ? 2 : 1
                )
            )
            .opacity(
                !isEnabled
                    ? 0.4
                    : pressed
                        ? 0.8
                        : 1
            )
    }
}

// MARK: - Thema

private enum VeyraEPGTheme {
    static var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(
                    red: 0.01,
                    green: 0.04,
                    blue: 0.07
                ),
                Color(
                    red: 0.02,
                    green: 0.10,
                    blue: 0.16
                )
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Lokale tijdweergave

@MainActor
private enum VeyraEPGFormat {
    private static let clock: DateFormatter = {
        let value = DateFormatter()
        value.locale = Locale(identifier: "nl_BE")
        value.timeZone = .autoupdatingCurrent
        value.dateFormat = "HH:mm"
        return value
    }()

    private static let calendar: DateFormatter = {
        let value = DateFormatter()
        value.locale = Locale(identifier: "nl_BE")
        value.timeZone = .autoupdatingCurrent
        value.dateFormat = "EEE d MMM"
        return value
    }()

    static func time(_ date: Date) -> String {
        clock.string(from: date)
    }

    static func day(_ date: Date) -> String {
        calendar.string(from: date)
    }
}

#Preview {
    NavigationStack {
        LiveTVView()
    }
}
