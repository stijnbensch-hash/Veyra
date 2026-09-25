import SwiftUI

/// tvOS: "Mijn opnames" — VeyraHub Recorder's geplande, lopende en
/// voltooide opnames. Bereikbaar vanuit de programmagids (zie
/// `LiveTVView.recordingsButton`).
struct TVRecordingsView: View {
    @State private var recordings: [VeyraHubRecording] = []
    @State private var message: String?
    @State private var playingSource: PlayableSource?

    @Environment(\.dismiss) private var dismiss

    private var hub: MediaServerAccount? {
        MediaServerStore().load().first(where: { $0.isVeyraHub })
    }

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            if recordings.isEmpty, let message {
                Text(message)
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                List {
                    Section {
                        ForEach(recordings.sorted { $0.start > $1.start }) { recording in
                            row(for: recording)
                        }
                    } header: {
                        Text("Opnames")
                    }
                }
                .frame(maxWidth: 1200)
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
        return Button {
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
                HStack(spacing: 14) {
                    if recording.isRecording {
                        Button {
                            Task { await stop(recording) }
                        } label: {
                            Image(systemName: "stop.circle")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(VeyraColors.red)
                    }
                    Button {
                        Task { await delete(recording) }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .veyraCardRow()
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
