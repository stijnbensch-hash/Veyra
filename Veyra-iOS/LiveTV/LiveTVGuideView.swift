import SwiftUI

/// A compact, horizontally scrolling programme guide for iPhone and iPad.
/// The channel column stays visible while the three-hour timeline moves.
@MainActor
struct LiveTVGuideView: View {
    @ObservedObject var guide: VeyraEPGStore
    let logoOverrideVersion: Int
    let onPlay: (VeyraGuideChannel) -> Void

    @State private var selection: ProgrammeSelection?

    @Environment(\.horizontalSizeClass) private var sizeClass

    // iPad: bredere kanaalkolom, ruimere tijdlijn en hogere rijen.
    private var channelWidth: CGFloat { sizeClass == .regular ? 168 : 118 }
    private var timelineWidth: CGFloat { sizeClass == .regular ? 1200 : 720 }
    private var rowHeight: CGFloat { sizeClass == .regular ? 96 : 82 }

    var body: some View {
        VStack(spacing: 0) {
            controls

            if guide.loadingGuide {
                ProgressView("Programmagids laden…")
                    .font(.caption)
                    .padding(.vertical, 8)
            } else if let message = guide.guideMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            TimelineView(.periodic(from: .now, by: 60)) { context in
                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: 0) {
                        channelColumn
                            .frame(width: channelWidth)

                        ScrollView(.horizontal) {
                            timeline(now: context.date)
                                .frame(width: timelineWidth)
                        }
                        .scrollIndicators(.visible)
                    }
                }
                .scrollIndicators(.visible)
            }
        }
        .sheet(item: $selection) { selected in
            details(for: selected)
                .presentationDetents([.medium, .large])
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                guide.moveWindow(-3)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Drie uur eerder")

            VStack(alignment: .leading, spacing: 2) {
                Text(Self.day.string(from: guide.windowStart))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Self.clock.string(from: guide.windowStart))–\(Self.clock.string(from: guide.windowEnd))")
                    .font(.subheadline.weight(.semibold))
            }

            Button {
                guide.moveWindow(3)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Drie uur later")

            Spacer(minLength: 0)

            Button("Nu") {
                guide.showNow()
            }
            .font(.subheadline.weight(.semibold))

            Button {
                guide.reloadID = UUID()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Programmagids vernieuwen")
        }
        .foregroundStyle(VeyraColors.cyan)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var channelColumn: some View {
        LazyVStack(spacing: 0) {
            Text("Zender")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 34)
                .padding(.leading, 8)

            ForEach(guide.visibleChannels) { row in
                Button {
                    selection = ProgrammeSelection(row: row, programme: onAir(for: row, at: Date()))
                } label: {
                    VStack(spacing: 3) {
                        AsyncImage(url: ChannelLogoOverrideStore.effectiveLogoURL(
                            channelID: row.channel.id, defaultLogoURL: row.channel.logoURL
                        )) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFit()
                            } else {
                                Image(systemName: "tv").foregroundStyle(.secondary)
                            }
                        }
                        .id(logoOverrideVersion)
                        .frame(width: 44, height: 38)

                        Text(ChannelNameOverrideStore.effectiveName(
                            channelID: row.channel.id, defaultName: row.channel.name
                        ))
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: rowHeight)
                }
                .buttonStyle(.plain)
                .background(VeyraColors.surface)
                .overlay(alignment: .bottom) { Divider().opacity(0.4) }
            }
        }
    }

    private func timeline(now: Date) -> some View {
        LazyVStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<3) { hour in
                    Text(Self.clock.string(from: guide.windowStart.addingTimeInterval(Double(hour) * 3_600)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: timelineWidth / 3, alignment: .leading)
                }
            }
            .frame(height: 34)

            ForEach(guide.visibleChannels) { row in
                programmeRow(row, now: now)
                    .frame(height: rowHeight)
            }
        }
    }

    private func programmeRow(_ row: VeyraGuideChannel, now: Date) -> some View {
        let slots = VeyraEPGSlot.make(
            guide.programmes(for: row), from: guide.windowStart, to: guide.windowEnd
        )

        return HStack(spacing: 0) {
            ForEach(slots) { slot in
                let width = timelineWidth * slot.end.timeIntervalSince(slot.start) / guide.windowDuration
                let onAir = slot.programme?.isOnAir(at: now) == true

                Button {
                    selection = ProgrammeSelection(row: row, programme: slot.programme)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(slot.programme?.title ?? (guide.loadingGuide ? "Gids laden…" : "Geen programma-informatie"))
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)

                        if let programme = slot.programme, width > 90 {
                            Text("\(Self.clock.string(from: programme.start))–\(Self.clock.string(from: programme.end))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                    .frame(width: max(0, width - 3), height: rowHeight - 4)
                    .background(onAir ? VeyraColors.cyan.opacity(0.22) : VeyraColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .frame(width: width, height: rowHeight)
                .accessibilityLabel(slot.programme?.title ?? "Geen programma-informatie")
            }
        }
    }

    private func onAir(for row: VeyraGuideChannel, at date: Date) -> VeyraEPGProgramme? {
        guide.programmes(for: row).first { $0.isOnAir(at: date) }
    }

    private func details(for selected: ProgrammeSelection) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(ChannelNameOverrideStore.effectiveName(
                        channelID: selected.row.channel.id,
                        defaultName: selected.row.channel.name
                    ))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VeyraColors.cyan)

                    Text(selected.programme?.title ?? "Zenderinformatie")
                        .font(.title2.weight(.bold))

                    if let programme = selected.programme {
                        Text("\(Self.day.string(from: programme.start))  \(Self.clock.string(from: programme.start))–\(Self.clock.string(from: programme.end))")
                            .font(.subheadline)
                            .foregroundStyle(VeyraColors.cyan)

                        if !programme.subtitle.isEmpty {
                            Text(programme.subtitle).font(.headline)
                        }

                        Text(programme.summary.isEmpty ? "Geen beschrijving beschikbaar." : programme.summary)
                            .foregroundStyle(.secondary)

                        if !programme.isOnAir(at: Date()) {
                            Text("Kijk live opent de huidige uitzending van deze zender. Terugkijken is niet beschikbaar in deze gids.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Geen programma-informatie voor dit tijdvak.")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        selection = nil
                        onPlay(selected.row)
                    } label: {
                        Label("Kijk live", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VeyraColors.cyan)

                    Button {
                        guide.toggleFavorite(selected.row)
                    } label: {
                        Label(
                            guide.favorites.contains(selected.row.id)
                                ? "Uit favorieten verwijderen" : "Aan favorieten toevoegen",
                            systemImage: guide.favorites.contains(selected.row.id) ? "star.slash" : "star"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(VeyraColors.background)
            .navigationTitle("Programma")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private struct ProgrammeSelection: Identifiable {
        let row: VeyraGuideChannel
        let programme: VeyraEPGProgramme?

        var id: String { "\(row.id):\(programme?.id ?? "channel")" }
    }

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_BE")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_BE")
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()
}
