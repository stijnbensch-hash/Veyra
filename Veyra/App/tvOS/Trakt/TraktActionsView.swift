import SwiftUI

struct TraktActionsView: View {
    let item: MediaItem
    @ObservedObject private var store = TraktStore.shared
    @State private var showActions = false

    var body: some View {
        if item.canSyncTrakt {
            Button {
                showActions = true
            } label: {
                Label(store.isWatched(item) ? "BEKEKEN · TRAKT" : "TRAKT", systemImage: store.isWatched(item) ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 22, weight: .semibold))
            }
            .sheet(isPresented: $showActions) {
                NavigationStack { TraktItemActionsView(item: item) }
            }
        }
    }
}

private struct TraktItemActionsView: View {
    let item: MediaItem
    @ObservedObject private var store = TraktStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var message: String?
    @State private var confirmUnwatched = false
    @State private var selectedRating = 7

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(item.title).font(.title)
                if store.isConnected {
                    if item.traktKind != "show" {
                        Button(store.isWatched(item) ? "Markeer als niet bekeken" : "Markeer als bekeken") {
                            if store.isWatched(item) { confirmUnwatched = true }
                            else { perform { try await store.setWatched(item, watched: true) } }
                        }
                    }
                    Button(store.isWatchlisted(item) ? "Verwijder uit watchlist" : "Voeg toe aan watchlist") {
                        perform { try await store.setWatchlist(item, included: !store.isWatchlisted(item)) }
                    }
                    Text(store.rating(for: item).map { "Jouw beoordeling: \($0)/10" } ?? "Nog geen beoordeling")
                        .foregroundStyle(.cyan)
                    Picker("Beoordeling", selection: $selectedRating) {
                        ForEach(1...10, id: \.self) { Text("\($0)/10").tag($0) }
                    }
                    HStack(spacing: 24) {
                        Button("Beoordeling opslaan") { perform { try await store.setRating(item, rating: selectedRating) } }
                        if store.rating(for: item) != nil {
                            Button("Beoordeling verwijderen") { perform { try await store.setRating(item, rating: nil) } }
                        }
                    }
                    if !store.lists.isEmpty {
                        Text("Toevoegen aan eigen lijst").font(.headline)
                        ForEach(store.lists) { list in
                            Button(list.name) { perform { try await store.add(item, to: list) } }
                        }
                    } else {
                        Text("Maak een eigen lijst aan via het Trakt-scherm.").foregroundStyle(.secondary)
                    }
                } else {
                    NavigationLink("Koppel je Trakt-account") { TraktView() }
                }
                if let message { Text(message).foregroundStyle(.cyan) }
                if let error = store.errorMessage { Text(error).foregroundStyle(.orange) }
                Button("Sluiten") { dismiss() }
            }
            .disabled(isSaving || store.isSyncing)
            .frame(maxWidth: 1250, alignment: .leading)
            .padding(.horizontal, VeyraSpacing.page)
            .padding(.top, 36)
            .padding(.bottom, 50)
        }
        .task { await store.refreshIfNeeded(); selectedRating = store.rating(for: item) ?? 7 }
        .confirmationDialog("Alle kijkregistraties voor deze titel verwijderen?", isPresented: $confirmUnwatched, titleVisibility: .visible) {
            Button("Markeer als niet bekeken", role: .destructive) {
                perform { try await store.setWatched(item, watched: false) }
            }
        }
    }
    private func perform(_ action: @escaping @MainActor () async throws -> Void) {
        isSaving = true
        message = nil
        Task {
            do { try await action(); message = "Opgeslagen in Trakt." }
            catch { message = error.localizedDescription }
            isSaving = false
        }
    }
}
