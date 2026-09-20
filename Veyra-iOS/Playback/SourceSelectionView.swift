import SwiftUI

struct SourceSelectionView: View {
    let item: MediaItem

    @StateObject private var viewModel: SourceSelectionViewModel
    @ObservedObject private var traktStore = TraktStore.shared
    @State private var selectedSource: PlayableSource?

    init(item: MediaItem) {
        self.item = item
        _viewModel = StateObject(wrappedValue: SourceSelectionViewModel(item: item))
    }

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
            if viewModel.isLoadingAddons && viewModel.sources.isEmpty {
                HStack {
                    ProgressView()
                    Text("Bronnen zoeken…")
                }
            } else if viewModel.sources.isEmpty && viewModel.hasLoaded {
                ContentUnavailableView(
                    "Geen afspeelbronnen gevonden",
                    systemImage: "play.slash"
                )
            } else {
                ForEach(viewModel.sources) { resolved in
                    Button {
                        selectedSource = resolved.source
                    } label: {
                        sourceRow(resolved)
                    }
                }

                if viewModel.isLoadingIPTV {
                    HStack {
                        ProgressView()
                        Text("IPTV-bronnen worden toegevoegd…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadSources() }
        .navigationDestination(item: $selectedSource) { source in
            PlayerView(
                source: source,
                item: item,
                resumeProgress: traktStore.progress(for: item)
            )
        }
    }

    private func sourceRow(_ resolved: ResolvedSource) -> some View {
        HStack(spacing: 14) {
            Image(systemName: sourceIconName(resolved.source))
                .font(.title3)
                .foregroundStyle(VeyraColors.cyan)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(resolved.source.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                if let description = resolved.source.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(resolved.source.kind == .iptvVOD ? "IPTV VOD" : resolved.originName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VeyraColors.cyan)
            }

            Spacer()

            Image(systemName: "play.fill")
                .foregroundStyle(VeyraColors.cyan)
        }
        .padding(.vertical, 4)
    }

    private func sourceIconName(_ source: PlayableSource) -> String {
        switch source.kind {
        case .iptvVOD: return "tv.and.hifispeaker.fill"
        case .usenet: return "externaldrive.fill"
        case .debrid: return "cloud.fill"
        case .liveTV: return "antenna.radiowaves.left.and.right"
        case .direct: return "play.rectangle.fill"
        }
    }
}
