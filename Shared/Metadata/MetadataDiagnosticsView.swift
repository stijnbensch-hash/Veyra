import SwiftUI

/// Artwork-engine-spec §72/§73: diagnostics zijn bewust NIET zichtbaar in de normale UI (geen
/// "Artwork by TVDB"-label op Home) maar enkel hier, onder Instellingen → Metadata. Toont de
/// meest recente metadata-/artwork-resoluties uit `MetadataDiagnosticsRecorder` (in-memory,
/// sessie-only, geen secrets/tokens). Cross-platform net als `VeyraArtworkPickerView`.
struct MetadataDiagnosticsView: View {
    @State private var events: [MetadataDiagnosticsEvent] = []
    @State private var loading = true

    var body: some View {
        VeyraDynamicBackgroundScope {
            content
                .navigationTitle("Diagnostics")
                .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        #if os(tvOS)
        ZStack {
            VeyraBackground().ignoresSafeArea()
            form
        }
        #else
        form
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Wis") { Task { await clear() } }
                        .disabled(events.isEmpty)
                }
            }
        #endif
    }

    private var form: some View {
        VeyraForm {
            if loading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if events.isEmpty {
                Section {
                    Text("Nog geen metadata-/artwork-aanvragen in deze sessie.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(events) { event in
                        row(event)
                    }
                } footer: {
                    Text("Laatste \(events.count) aanvragen deze sessie, nieuwste eerst. Niet gepersisteerd.")
                }
                #if os(tvOS)
                Section {
                    Button("Wis") { Task { await clear() } }
                }
                #endif
            }
        }
        .frame(maxWidth: 1000)
    }

    private func row(_ event: MetadataDiagnosticsEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.kind.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VeyraColors.cyan)
                Text(event.canonicalID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(event.durationMs) ms")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Text(event.sourceSelected == event.sourceActuallyUsed
                     ? event.sourceActuallyUsed
                     : "\(event.sourceSelected) → \(event.sourceActuallyUsed)")
                    .font(.system(size: 15, weight: .medium))
                if event.fallbackUsed { badge("fallback") }
                if event.cacheHit { badge("cache") }
            }
            if let addonID = event.addonID {
                Text(addonID).font(.caption2).foregroundStyle(.secondary)
            }
            if let candidateID = event.candidateID, !candidateID.isEmpty {
                Text(candidateID).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            if let language = event.language {
                Text("Taal: \(language)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func badge(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.white.opacity(0.12), in: Capsule())
    }

    private func load() async {
        events = await MetadataDiagnosticsRecorder.shared.recent()
        loading = false
    }

    private func clear() async {
        await MetadataDiagnosticsRecorder.shared.clear()
        events = []
    }
}
