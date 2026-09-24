// SportChannelPickerView.swift — gedeeld (iOS + tvOS)
// Lijst met IPTV-zenders die een wedstrijd volgens de EPG uitzenden. Kiezen geeft de speelbare bron terug.

import SwiftUI

extension SportEvent {
    /// Teamnamen om in de EPG te zoeken: home/away, anders de titel gesplitst op " – ", " - ", " vs ".
    var searchTeams: [String] {
        if let home, let away, !home.isEmpty, !away.isEmpty { return [home, away] }
        for sep in [" – ", " — ", " - ", " vs. ", " vs ", " v "] {
            let parts = title.components(separatedBy: sep)
            if parts.count == 2 { return parts.map { $0.trimmingCharacters(in: .whitespaces) } }
        }
        return [title]
    }
}

/// Wat de sheet nodig heeft om zenders te zoeken.
struct SportChannelQuery: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let teams: [String]
    let start: Date

    init(title: String, teams: [String], start: Date) {
        self.title = title
        self.teams = teams
        self.start = start
    }

    init(event: SportEvent) {
        self.init(title: event.title, teams: event.searchTeams, start: event.start)
    }
}

struct SportChannelPickerView: View {
    let query: SportChannelQuery
    var onPick: (PlayableSource) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var matches: [SportChannelMatch] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraHomeStyle.ink.ignoresSafeArea()
                content
            }
            .navigationTitle("Waar kijken?")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sluit") { dismiss() }
                }
            }
            #endif
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            VStack(spacing: 14) {
                ProgressView()
                Text("Zenders zoeken in de gids…").foregroundStyle(VeyraHomeStyle.dim)
            }
        } else if matches.isEmpty {
            VStack(spacing: 10) {
                Text("Geen zenders gevonden")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Geen enkele zender heeft \(query.title) in de gids staan. Kies zelf een zender in Live TV.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(VeyraHomeStyle.dim)
            }
            .padding(40)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(query.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VeyraHomeStyle.dim)
                        .padding(.bottom, 4)
                    ForEach(matches) { match in
                        Button { pick(match) } label: { row(match) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
    }

    private func row(_ match: SportChannelMatch) -> some View {
        let live = match.isLive(at: Date())
        return HStack(spacing: 14) {
            AsyncImage(url: match.logoURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "tv").foregroundStyle(VeyraHomeStyle.faint)
                }
            }
            .frame(width: 56, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(match.channelName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(match.programmeTitle)
                    .font(.subheadline)
                    .foregroundStyle(VeyraHomeStyle.dim)
                    .lineLimit(1)
                Text(timeRange(match))
                    .font(.caption)
                    .foregroundStyle(VeyraHomeStyle.faint)
            }
            Spacer(minLength: 8)
            if live {
                Text("NU LIVE")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VeyraHomeStyle.live, in: Capsule())
                    .foregroundStyle(.white)
            }
            Image(systemName: "play.fill").foregroundStyle(VeyraHomeStyle.cyan)
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func timeRange(_ match: SportChannelMatch) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: match.start)) – \(f.string(from: match.end))"
    }

    private func load() async {
        let found = await VeyraBentoServices.shared.sportChannels(teams: query.teams, start: query.start)
        matches = found
        loading = false
    }

    private func pick(_ match: SportChannelMatch) {
        guard let source = VeyraBentoServices.shared.playableSource(forChannelID: match.channelID) else { return }
        onPick(source)
    }
}

/// Toont de zenderkeuze als sheet en geeft de gekozen bron door nadat de sheet gesloten is.
struct SportChannelSheetModifier: ViewModifier {
    @Binding var query: SportChannelQuery?
    var onPlay: (PlayableSource) -> Void

    func body(content: Content) -> some View {
        content.sheet(item: $query) { q in
            SportChannelPickerView(query: q) { source in
                query = nil
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    onPlay(source)
                }
            }
        }
    }
}

extension View {
    func sportChannelSheet(_ query: Binding<SportChannelQuery?>, onPlay: @escaping (PlayableSource) -> Void) -> some View {
        modifier(SportChannelSheetModifier(query: query, onPlay: onPlay))
    }
}
