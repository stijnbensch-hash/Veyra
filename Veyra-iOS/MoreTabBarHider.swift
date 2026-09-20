//
//  MoreTabBarHider.swift
//  Veyra-iOS
//

import SwiftUI
import UIKit

/// Verbergt de systeem-navigatiebalk van UIKit's automatische "More"-tabblad.
///
/// Zodra een `TabView` meer tabbladen bevat dan er in één keer op de tabbalk
/// passen, wikkelt iOS de overige tabbladen in
/// `UITabBarController.moreNavigationController` — een eigen
/// `UINavigationController` mét eigen navigatiebalk. Zodra zo'n tabblad zelf
/// ook een `NavigationStack` gebruikt voor eigen push-navigatie (zoals
/// Instellingen, dat achter "More" zit omdat er 7 tabbladen zijn), krijg je
/// twee balken over elkaar zodra je iets pusht: de balk van "More" (met een
/// terugknop naar het "More"-overzicht) én de eigen balk van de
/// `NavigationStack` (met een terugknop naar de instellingenroot). Dat gaf de
/// dubbele terugpijl.
///
/// De vorige aanpak probeerde dit op te lossen met `.toolbar(_:for:)` op de
/// eigen `NavigationStack` in `SettingsView`, maar die modifier bepaalt enkel
/// de zichtbaarheid van de eigen, geneste balk — niet van de balk die "More"
/// zelf toevoegt. Het echte probleem zit in die buitenste, door UIKit
/// aangemaakte balk, dus die moeten we rechtstreeks verbergen.
///
/// Deze view zoekt de dichtstbijzijnde `UITabBarController` op zodra hij in
/// de hiërarchie hangt, en verbergt permanent de balk van diens
/// `moreNavigationController`. De eigen `NavigationStack` van elk tabblad
/// (incl. Instellingen) blijft normaal werken — dat is een aparte, geneste
/// controller en wordt hier niet aangeraakt.
private struct MoreTabBarHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        hideMoreBar(from: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        hideMoreBar(from: uiViewController)
    }

    /// De tabbalkcontroller is soms nog niet gekoppeld op het moment dat
    /// `makeUIViewController` wordt aangeroepen, dus proberen we dit een paar
    /// keer opnieuw kort na het verschijnen van de view.
    private func hideMoreBar(from controller: UIViewController) {
        for delay in [0.0, 0.1, 0.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak controller] in
                guard let tabBarController = controller?.tabBarController else { return }
                tabBarController.moreNavigationController.setNavigationBarHidden(true, animated: false)
            }
        }
    }
}

extension View {
    /// Verbergt de dubbele navigatiebalk die iOS' automatische "More"-tabblad
    /// toevoegt boven op tabbladen die zelf een `NavigationStack` gebruiken.
    func hidingMoreTabNavigationBar() -> some View {
        background(MoreTabBarHider())
    }
}
