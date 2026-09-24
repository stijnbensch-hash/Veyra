//
//  ContentView.swift
//  Veyra-iOS
//

import SwiftUI

private enum AppTab: Hashable {
    case home, movies, series, live, sports
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showSettings = false
    @ObservedObject private var homeNavigation = HomeNavigationState.shared
    @State private var showSearch = false

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(AppTab.home)

                MoviesView()
                    .tabItem { Label("Films", systemImage: "film.fill") }
                    .tag(AppTab.movies)

                SeriesView()
                    .tabItem { Label("Series", systemImage: "tv.fill") }
                    .tag(AppTab.series)

                LiveTVView()
                    .tabItem { Label("Live", systemImage: "antenna.radiowaves.left.and.right") }
                    .tag(AppTab.live)

                SportsView()
                    .tabItem { Label("Sport", systemImage: "trophy") }
                    .tag(AppTab.sports)
            }
            .tint(VeyraColors.cyan)

            // Losse, zwevende knoppen bovenin: vergrootglas linksboven
            // (Zoeken), tandwiel rechtsboven (Instellingen) — enkel op het
            // Home-tabblad, nergens anders.
            if selectedTab == .home && homeNavigation.isAtRoot {
                HStack {
                    FloatingIconButton(symbol: "magnifyingglass", accessibilityLabel: "Zoeken") {
                        showSearch = true
                    }
                    Spacer()
                    FloatingIconButton(symbol: "gearshape.fill", accessibilityLabel: "Instellingen") {
                        showSettings = true
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: homeNavigation.requestedTab) { _, tab in
            guard let tab else { return }
            selectedTab = tab == .live ? .live : .sports
            homeNavigation.requestedTab = nil
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showSearch) {
            PlaceholderTab(title: "Zoeken", symbol: "magnifyingglass")
        }
    }
}

/// Glazen, zwevende rondje-knop voor de losse Instellingen-/Zoeken-toegang
/// bovenin het scherm — vervaagd glasmateriaal met een dunne cyaan rand, in
/// stijl met de rest van de app.
private struct FloatingIconButton: View {
    let symbol: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle().stroke(VeyraColors.cyan.opacity(0.55), lineWidth: 1)
                )
        }
        .accessibilityLabel(accessibilityLabel)
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
