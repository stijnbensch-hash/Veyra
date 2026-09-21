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
    @State private var showSearch = false

    var body: some View {
        ZStack(alignment: .top) {
            // Precies 5 tabbladen: dit blijft onder de drempel waarop iOS
            // zelf een "More"-tabblad toevoegt (dat gebeurt pas vanaf 6).
            // Instellingen en Zoeken zaten hier vroeger ook als tabblad,
            // maar met 7 tabbladen viel dan telkens één van de twee (meestal
            // Instellingen) achter "More" — en dat gaf een dubbele
            // terugpijl zodra Instellingen zelf ook pushte (naar bv.
            // Account), omdat de balk van "More" en onze eigen balk dan
            // allebei zichtbaar werden. Er bleek geen betrouwbare manier om
            // één van die twee balken via een modifier te verbergen. Door
            // Instellingen en Zoeken helemaal geen tabblad meer te laten
            // zijn — en ze in plaats daarvan als losse knoppen te tonen die
            // een sheet openen — is er geen "More" meer nodig en dus ook
            // geen dubbele balk meer mogelijk.
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
            // (Zoeken), tandwiel rechtsboven (Instellingen) — aan
            // weerszijden van het scherm. Alleen op het Home-tabblad, zodat
            // ze niet over de andere tabbladen (Films, Series, Live, Sport)
            // heen blijven zweven.
            if selectedTab == .home {
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
