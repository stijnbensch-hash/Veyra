//
//  ContentView.swift
//  Veyra-iOS
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            MoviesView()
                .tabItem { Label("Films", systemImage: "film.fill") }

            SeriesView()
                .tabItem { Label("Series", systemImage: "tv.fill") }

            LiveTVView()
                .tabItem { Label("Live", systemImage: "antenna.radiowaves.left.and.right") }

            SportsView()
                .tabItem { Label("Sport", systemImage: "trophy") }

            PlaceholderTab(title: "Zoeken", symbol: "magnifyingglass")
                .tabItem { Label("Zoeken", systemImage: "magnifyingglass") }

            SettingsView()
                .tabItem { Label("Instellingen", systemImage: "gearshape.fill") }
        }
        .tint(VeyraColors.cyan)
        .preferredColorScheme(.dark)
    }
}

private struct PlaceholderTab: View {
    let title: String
    let symbol: String

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraColors.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: symbol)
                        .font(.system(size: 44))
                        .foregroundStyle(VeyraColors.cyan)

                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Binnenkort beschikbaar op iPhone/iPad.")
                        .font(.subheadline)
                        .foregroundStyle(VeyraColors.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .navigationTitle(title)
        }
    }
}

#Preview {
    ContentView()
}
