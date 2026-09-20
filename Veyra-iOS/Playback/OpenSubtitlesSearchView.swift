import SwiftUI
import AetherEngine

/// iOS-versie van het online-ondertitels-zoekscherm (OpenSubtitles), vanuit
/// de speler te openen naast de lokale ondertitelsporen van de stream zelf.
struct OpenSubtitlesSearchView: View {
    let item: MediaItem?
    @ObservedObject var engine: AetherEngine

    @Environment(\.dismiss) private var dismiss

    @State private var language = SubtitlePreferences.language()
    @State private var results: [OpenSubtitlesResult] = []
    @State private var request: UUID?
    @State private var download: OpenSubtitlesResult?
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Zoektaal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(SubtitleLanguage.allCases) { option in
                                    Button {
                                        language = option
                                        results = []
                                        message = nil
                                    } label: {
                                        Text(option.title)
                                            .font(.system(size: 15, weight: .medium))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                language == option ? VeyraColors.cyan.opacity(0.22) : Color.white.opacity(0.08),
                                                in: Capsule()
                                            )
                                            .foregroundStyle(language == option ? VeyraColors.cyan : .white)
                                    }
                                    .disabled(busy)
                                }
                            }
                        }

                        Button {
                            request = UUID()
                        } label: {
                            Label("Zoeken in \(language.title)", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(VeyraColors.cyan)
                        .disabled(busy || item == nil)

                        if item == nil {
                            Text("Online zoeken is beschikbaar bij een film of aflevering met IMDb-gegevens.")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        if busy {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Ondertitels laden…").foregroundStyle(.white.opacity(0.6))
                            }
                        }

                        if let message {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(results) { result in
                                Button {
                                    download = result
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.displayName)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.white)
                                        Text(result.name)
                                            .font(.footnote)
                                            .foregroundStyle(.white.opacity(0.6))
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .veyraGlass(radius: 14, backgroundOpacity: 0.6)
                                }
                                .buttonStyle(.plain)
                                .disabled(busy)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("OpenSubtitles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten") { dismiss() }
                }
            }
        }
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
                dismiss()
            } catch is CancellationError {} catch { message = error.localizedDescription }
        }
    }
}
