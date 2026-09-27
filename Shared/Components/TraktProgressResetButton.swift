import SwiftUI

/// Verwijdert een Trakt-hervatpunt zonder de bekeken-status te wijzigen.
/// Alleen zichtbaar voor een film of aflevering met gedeeltelijke voortgang.
struct TraktProgressResetButton: View {
    let item: MediaItem
    var compact = false

    @ObservedObject private var store = TraktStore.shared
    @State private var asksConfirmation = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if store.isConnected && store.progress(for: item) != nil {
                Button {
                    asksConfirmation = true
                } label: {
                    label
                }
                #if os(tvOS)
                .buttonStyle(VeyraFocusButtonStyle())
                #else
                .buttonStyle(.bordered)
                .tint(VeyraColors.cyan)
                #endif
                .disabled(isWorking)
                .accessibilityLabel("Voortgang resetten")
                .confirmationDialog(
                    "Voortgang resetten?",
                    isPresented: $asksConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Voortgang resetten", role: .destructive) {
                        Task { await reset() }
                    }
                } message: {
                    Text("De volgende keer begint deze titel opnieuw. De bekeken-status blijft behouden. Het hervatpunt wordt ook bij Trakt verwijderd.")
                }
            }
        }
        .alert("Voortgang niet gereset", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Probeer het opnieuw.")
        }
    }

    @ViewBuilder
    private var label: some View {
        #if os(tvOS)
        if compact {
            VeyraActionLabel(title: "RESET", symbol: "arrow.counterclockwise", compact: true)
        } else {
            VeyraActionLabel(title: "RESET VOORTGANG", symbol: "arrow.counterclockwise", compact: true)
        }
        #else
        if compact {
            Image(systemName: "arrow.counterclockwise")
                .font(.headline)
                .frame(width: 30, height: 30)
        } else {
            Label("Voortgang resetten", systemImage: "arrow.counterclockwise")
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 6)
        }
        #endif
    }

    private func reset() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await store.resetProgress(for: item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
