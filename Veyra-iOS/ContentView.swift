//
//  ContentView.swift
//  Veyra-iOS
//

import SwiftUI

private enum AppTab: Hashable {
    case home, movies, series, live, sports, settings
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showSettings = false
    @ObservedObject private var homeNavigation = HomeNavigationState.shared
    @State private var showSearch = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    // iPad-navigatie: zijbalk of menubalk boven (Instellingen → Algemeen) —
    // nooit allebei, in tegenstelling tot het systeem-eigen wisselknopje dat
    // `.sidebarAdaptable` anders altijd aanbiedt.
    @AppStorage(GeneralSettingsDefaults.ipadNavigationStyleKey)
    private var ipadNavigationStyleRaw = IPadNavigationStyle.sidebar.rawValue

    private var ipadNavigationStyle: IPadNavigationStyle {
        IPadNavigationStyle(rawValue: ipadNavigationStyleRaw) ?? .sidebar
    }

    /// iPad (regular): navigatie via een zijbalk en Instellingen als eigen onderdeel; iPhone blijft een tabbalk.
    private var isRegular: Bool { sizeClass == .regular }

    private var tabViewContent: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) { HomeView() }
            Tab("Films", systemImage: "film.fill", value: AppTab.movies) { MoviesView() }
            Tab("Series", systemImage: "tv.fill", value: AppTab.series) { SeriesView() }
            Tab("Live", systemImage: "antenna.radiowaves.left.and.right", value: AppTab.live) { LiveTVView() }
            Tab("Sport", systemImage: "trophy", value: AppTab.sports) { SportsView() }
            if isRegular {
                Tab("Instellingen", systemImage: "gearshape.fill", value: AppTab.settings) { SettingsView() }
            }
        }
    }

    // Echte, vaste zijbalk (`NavigationSplitView`) in plaats van
    // `TabView(.sidebarAdaptable)` — die laatste toont bij een ingeklapte
    // zijbalk (bv. in portret, of na een systeem-swipe) alsnog de eigen
    // zwevende menubalk boven, wat we hier juist nooit willen.
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all

    /// `List(selection:)` verwacht een optionele binding (`Binding<AppTab?>`);
    /// `selectedTab` zelf blijft non-optional omdat `TabView`/`tabViewContent`
    /// altijd een geldige waarde nodig heeft. Deze computed binding overbrugt
    /// dat: een `nil`-selectie in de lijst (kan niet echt voorkomen bij één
    /// vaste rij per item, maar hoort bij het type) laat `selectedTab` ongewijzigd.
    private var sidebarSelection: Binding<AppTab?> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if let newValue { selectedTab = newValue }
            }
        )
    }

    private var sidebarSplitView: some View {
        NavigationSplitView(columnVisibility: $splitViewVisibility) {
            List(selection: sidebarSelection) {
                Label("Home", systemImage: "house.fill").tag(AppTab.home)
                Label("Films", systemImage: "film.fill").tag(AppTab.movies)
                Label("Series", systemImage: "tv.fill").tag(AppTab.series)
                Label("Live", systemImage: "antenna.radiowaves.left.and.right").tag(AppTab.live)
                Label("Sport", systemImage: "trophy").tag(AppTab.sports)
                Label("Instellingen", systemImage: "gearshape.fill").tag(AppTab.settings)
            }
            .navigationTitle("Veyra")
            .listStyle(.sidebar)
        } detail: {
            // Elke bestemming (HomeView, MoviesView, …) wikkelt zichzelf al
            // in een eigen `NavigationStack` (SettingsView zelfs in een
            // eigen `NavigationSplitView` op iPad) — hier nog een stack
            // omheen zetten zou die nesten, met dubbele navigatiebalken
            // tot gevolg. De vaste balk erboven (met de zijbalk-knop) duwt
            // die inhoud gewoon omlaag i.p.v. eroverheen te zweven, en
            // verschijnt alleen als de zijbalk is ingeklapt.
            VStack(spacing: 0) {
                if splitViewVisibility != .all {
                    sidebarToggleBar
                }
                sidebarDetailContent
            }
        }
        .navigationSplitViewStyle(.balanced)
        // Verwijdert het systeem-eigen zijbalk-knopje — we tonen zelf al een
        // vaste knop (`sidebarToggleBar`) zodra de zijbalk ingeklapt is, dus
        // het automatische knopje zou een tweede, overbodige knop geven.
        .toolbar(removing: .sidebarToggle)
        .tint(VeyraColors.cyan)
        .onChange(of: selectedTab) { _, _ in
            // Een item kiezen in de zijbalk klapt hem meteen weer in, zoals
            // op de meeste iPad-apps met een zijbalk.
            withAnimation {
                splitViewVisibility = .detailOnly
            }
        }
    }

    /// Vaste (niet-zwevende) balk helemaal bovenaan, enkel zichtbaar als de
    /// zijbalk ingeklapt is — met de knop om hem weer open te klappen.
    private var sidebarToggleBar: some View {
        HStack {
            Button {
                withAnimation { splitViewVisibility = .all }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Zijbalk tonen")

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(VeyraColors.background)
    }

    @ViewBuilder
    private var sidebarDetailContent: some View {
        switch selectedTab {
        case .home: HomeView()
        case .movies: MoviesView()
        case .series: SeriesView()
        case .live: LiveTVView()
        case .sports: SportsView()
        case .settings: SettingsView()
        }
    }

    @ViewBuilder
    private var styledTabView: some View {
        if isRegular && ipadNavigationStyle == .sidebar {
            sidebarSplitView
        } else {
            // Vaste menubalk boven (iPad) of gewone tabbalk onderaan
            // (iPhone) — geen zijbalk-alternatief, dus geen dubbele chrome.
            tabViewContent
                .tabViewStyle(.automatic)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            styledTabView
                .tint(VeyraColors.cyan)

            // Losse, zwevende knoppen bovenin: vergrootglas linksboven
            // (Zoeken), tandwiel rechtsboven (Instellingen) — enkel op het
            // Home-tabblad, nergens anders. Bij de zijbalk-stijl op iPad
            // blijft dit weg: Instellingen zit dan al als eigen item in de
            // zijbalk, en deze balk zou boven de zijbalk een tweede,
            // overbodige menubalk vormen.
            if selectedTab == .home && homeNavigation.isAtRoot
                && !(isRegular && ipadNavigationStyle == .sidebar) {
                HStack {
                    FloatingIconButton(symbol: "magnifyingglass", accessibilityLabel: "Zoeken") {
                        showSearch = true
                    }
                    Spacer()
                    if !isRegular {
                        FloatingIconButton(symbol: "gearshape.fill", accessibilityLabel: "Instellingen") {
                            showSettings = true
                        }
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
        .onChange(of: isRegular) { _, regular in
            // Van iPad-indeling naar compact (bv. Split View): Instellingen bestaat dan alleen nog als sheet.
            if !regular, selectedTab == .settings { selectedTab = .home }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationSizing(.page)
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
