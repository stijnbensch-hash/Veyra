import SwiftUI
import AetherEngine

struct OpenSubtitlesSearchView: View {
    let item: MediaItem?
    @ObservedObject var engine: AetherEngine
    @State private var language = SubtitlePreferences.language()
    @State private var results: [OpenSubtitlesResult] = []
    @State private var request: UUID?
    @State private var download: OpenSubtitlesResult?
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("OpenSubtitles").font(.system(size: 22, weight: .semibold))
            Text("Zoektaal: \(language.title)").font(.system(size: 18))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SubtitleLanguage.allCases) { option in
                        Button {
                            language = option
                            results = []
                            message = nil
                        } label: {
                            Text(option.title).padding(12)
                                .foregroundStyle(language == option ? VeyraColors.cyan : .white)
                        }.disabled(busy)
                    }
                }.padding(6)
            }
            Button("Zoeken in \(language.title)", systemImage: "magnifyingglass") { request = UUID() }
                .disabled(busy || item == nil)
            if item == nil {
                Text("Online zoeken is beschikbaar bij een film of aflevering met IMDb-gegevens.")
                    .foregroundStyle(.secondary)
            }
            if busy { ProgressView("Ondertitels laden…") }
            if let message { Text(message).font(.system(size: 18)).foregroundStyle(.secondary) }
            ForEach(results) { result in
                Button { download = result } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.displayName)
                        Text(result.name).font(.system(size: 17)).foregroundStyle(.secondary).lineLimit(2)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
                }.disabled(busy)
            }
        }
        .font(.system(size: 20))
        .buttonStyle(VeyraFocusButtonStyle(radius: 12))
        .task(id: request) {
            guard request != nil, let item else { return }
            busy = true; message = nil; results = []
            defer { busy = false }
            do {
                let found = try await SubtitleService.shared.search(for: item, language: language)
                try Task.checkCancellation()
                results = Array(found.prefix(20))
                if results.isEmpty { message = "Geen ondertitels gevonden in \(language.title). Kies eventueel een andere taal." }
            } catch is CancellationError {} catch { message = error.localizedDescription }
        }
        .task(id: download) {
            guard let download else { return }
            busy = true; message = nil
            defer { busy = false; self.download = nil }
            do {
                try await SubtitleService.shared.select(download, into: engine)
                try Task.checkCancellation()
                message = "Ondertitel geselecteerd. Je standaardtaal blijft ongewijzigd."
            } catch is CancellationError {} catch { message = error.localizedDescription }
        }
    }
}
