import SwiftUI

/// "Mijn opnames": VeyraHub Recorder's geplande, lopende en voltooide
/// opnames — afspelen, stoppen en verwijderen. Bereikbaar vanuit de
/// programmagids (zie `LiveTVGuideView`).
struct VeyraRecordingsView: View {
    @State private var recordings: [VeyraHubRecording] = []
    @State private var isLoading = true
    @State private var message: String?
    @State private var playingSource: PlayableSource?

    @Environment(\.dismiss) private var dismiss

    private var hub: MediaServerAccount? {
        MediaServerStore().load().first(where: { $0.isVeyraHub })
    }

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            if let message, recordings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "record.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                List {
                    ForEach(recordings.sorted { $0.start > $1.start }) { recording in
                        row(for: recording)
                    }
                }
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Mijn opnames")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Sluiten") { dismiss() }
            }
        }
        .fullScreenCover(item: $playingSource) { source in
            PlayerView(source: source)
        }
        .task { await load() }
    }

    @ViewBuilder
    private func row(for recording: VeyraHubRecording) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.title).font(.headline)
            Text(statusLine(recording))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let error = recording.error, !error.isEmpty {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await delete(recording) }
            } label: {
                Label(recording.isScheduled ? "Annuleer" : "Verwijder", systemImage: "trash")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard recording.isCompleted, let hub else { return }
            playingSource = PlayableSource(
                name: recording.title,
                url: VeyraHubRecorderClient(account: hub).fileURL(id: recording.id),
                kind: .direct,
                recorderCleanup: VeyraHubRecorderCleanup(account: hub, recordingID: recording.id)
            )
        }
        .overlay(alignment: .trailing) {
            if recording.isRecording {
                Button {
                    Task { await stop(recording) }
                } label: {
                    Label("Stop", systemImage: "stop.circle")
                }
                .buttonStyle(.bordered)
                .tint(VeyraColors.red)
            }
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
        case "failed": status = "Mislukt"
        default: status = recording.status
        }
        return "\(channel)\(when) · \(status)"
    }

    private func load() async {
        guard let hub else {
            message = "Voeg VeyraHub eerst toe bij Mediaservers."
            isLoading = false
            return
        }
        do {
            recordings = try await VeyraHubRecorderClient(account: hub).recordings()
            message = recordings.isEmpty ? "Nog geen opnames." : nil
        } catch {
            message = error.localizedDescription
        }
        isLoading = false
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
    NavigationStack { VeyraRecordingsView() }
}
