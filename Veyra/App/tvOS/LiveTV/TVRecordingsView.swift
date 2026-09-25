import SwiftUI

/// tvOS: "Mijn opnames" — VeyraHub Recorder's geplande, lopende en
/// voltooide opnames. Bereikbaar vanuit de programmagids (zie
/// `LiveTVView.recordingsButton`).
struct TVRecordingsView: View {
    @State private var recordings: [VeyraHubRecording] = []
    @State private var message: String?
    @State private var playingSource: PlayableSource?

    @FocusState private var focusedActionID: String?

    @Environment(\.dismiss) private var dismiss

    private var hub: MediaServerAccount? {
        MediaServerStore().load().first(where: { $0.isVeyraHub })
    }

    /// Titels van actieve "neem hele serie op"-regels (zie
    /// `SeriesRecordingRule`), voor het scheiden van losse opnames en
    /// serie-opnames hieronder — de recorder zelf houdt geen seriesverband
    /// bij, dus dit is de enige plek waar dat onderscheid bekend is.
    private var seriesTitles: Set<String> {
        Set(SeriesRecordingDefaults.loadRules().map { $0.title.lowercased() })
    }

    private var singleRecordings: [VeyraHubRecording] {
        let seriesTitles = self.seriesTitles
        return recordings
            .filter { !seriesTitles.contains($0.title.lowercased()) }
            .sorted { $0.start > $1.start }
    }

    private var seriesRecordings: [VeyraHubRecording] {
        let seriesTitles = self.seriesTitles
        return recordings
            .filter { seriesTitles.contains($0.title.lowercased()) }
            .sorted { $0.start > $1.start }
    }

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            if recordings.isEmpty, let message {
                Text(message)
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                List {
                    if !singleRecordings.isEmpty {
                        Section {
                            ForEach(singleRecordings) { recording in
                                row(for: recording)
                            }
                        } header: {
                            Text("Losse opnames")
                        }
                    }

                    if !seriesRecordings.isEmpty {
                        Section {
                            ForEach(seriesRecordings) { recording in
                                row(for: recording)
                            }
                        } header: {
                            Text("Serie-opnames")
                        }
                    }
                }
                .frame(maxWidth: 1850)
            }
        }
        .navigationTitle("Mijn opnames")
        .fullScreenCover(item: $playingSource) { source in
            PlayerView(source: source)
        }
        .task { await load() }
    }

    private func row(for recording: VeyraHubRecording) -> some View {
        let hub = self.hub
        return HStack(spacing: 14) {
            Button {
                guard recording.isCompleted, let hub else { return }
                playingSource = PlayableSource(
                    name: recording.title,
                    url: VeyraHubRecorderClient(account: hub).fileURL(id: recording.id),
                    kind: .direct,
                    recorderCleanup: VeyraHubRecorderCleanup(account: hub, recordingID: recording.id)
                )
            } label: {
                VeyraSettingsCardRowLabel(
                    icon: iconName(for: recording),
                    title: recording.title,
                    subtitle: statusLine(recording)
                ) {
                    EmptyView()
                }
            }

            // De acties staan hier bewust NAAST de speel-knop, niet erin
            // genest: een focusbaar element binnenin de label van een
            // andere Button krijgt op tvOS geen eigen focus/klik — zie
            // ook `addonDeleteControl`, die om dezelfde reden als
            // broer/zus in een HStack staat (SettingsView.addonRow).
            if recording.isRecording {
                actionButton(
                    id: "\(recording.id)|stop",
                    systemImage: "stop.circle",
                    tint: VeyraColors.red
                ) {
                    Task { await stop(recording) }
                }
            }
            actionButton(
                id: "\(recording.id)|delete",
                systemImage: "trash",
                tint: VeyraColors.red
            ) {
                Task { await delete(recording) }
            }
        }
        .veyraCardRow()
    }

    /// Een op zichzelf staande, focusbare actieknop met een eigen
    /// achtergrond — zonder dit valt tvOS terug op zijn eigen witte
    /// focus-halo rond de knop, zoals bij de verwijderknop in de
    /// bronnen-instellingen (`SettingsView.addonDeleteControl`).
    private func actionButton(
        id: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        let isFocused = focusedActionID == id

        return Image(systemName: systemImage)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(isFocused ? .white : tint.opacity(0.85))
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isFocused
                            ? tint.opacity(0.20)
                            : Color(red: 0.03, green: 0.09, blue: 0.14)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isFocused ? tint : tint.opacity(0.25),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .contentShape(Rectangle())
            .focusable(true)
            .focused($focusedActionID, equals: id)
            .focusEffectDisabled()
            .onTapGesture(perform: action)
    }

    private func iconName(for recording: VeyraHubRecording) -> String {
        switch recording.status {
        case "recording": return "record.circle.fill"
        case "completed": return "play.circle"
        case "failed": return "exclamationmark.circle"
        default: return "clock"
        }
    }

    private func statusLine(_ recording: VeyraHubRecording) -> String {
        let when = "\(Self.day.string(from: recording.start)) \(Self.clock.string(from: recording.start))–\(Self.clock.string(from: recording.end))"
        let channel = recording.channel.map { $0 + " · " } ?? ""
        let status: String
        switch recording.status {
        case "scheduled": status = "Gepland"
        case "recording": status = "Bezig met opnemen"
        case "completed": status = "Voltooid"
        case "failed": status = recording.error ?? "Mislukt"
        default: status = recording.status
        }
        return "\(channel)\(when) · \(status)"
    }

    private func load() async {
        guard let hub else {
            message = "Voeg VeyraHub eerst toe bij Mediaservers."
            return
        }
        do {
            recordings = try await VeyraHubRecorderClient(account: hub).recordings()
            message = recordings.isEmpty ? "Nog geen opnames." : nil
        } catch {
            message = error.localizedDescription
        }
    }

    private func delete(_ recording: VeyraHubRecording) async {
        guard let hub else { return }
        do {
            try await VeyraHubRecorderClient(account: hub).deleteRecording(id: recording.id)
            await load()
        } catch {
            message = error.localizedDescription
        }
    }

    private func stop(_ recording: VeyraHubRecording) async {
        guard let hub else { return }
        do {
            try await VeyraHubRecorderClient(account: hub).stopRecording(id: recording.id)
            await load()
        } catch {
            message = error.localizedDescription
        }
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

#Preview {
    NavigationStack { TVRecordingsView() }
}
