import UIKit

/// Globale schakelaar waarmee `AppDelegate` bepaalt welke schermoriëntaties
/// op dit moment zijn toegestaan. De rest van de app ondersteunt alle
/// oriëntaties (zie Info.plist); alleen de speler kan dit tijdelijk naar
/// enkel liggend of enkel staand beperken, afhankelijk van "Automatisch
/// draaien naar liggend" in de Afspelen-instellingen.
@MainActor
final class OrientationLock {
    static let shared = OrientationLock()

    private(set) var mask: UIInterfaceOrientationMask = .all

    private init() {}

    /// Tijdens het afspelen, wanneer automatisch draaien is uitgeschakeld:
    /// blijft in staand, ongeacht hoe het toestel gedraaid wordt.
    func lockToPortrait() {
        mask = .portrait
        apply()
    }

    /// Standaardgedrag (en tijdens het afspelen wanneer automatisch draaien
    /// wél is ingeschakeld): alle oriëntaties toegestaan, zoals Info.plist
    /// al voorschrijft.
    func allowAll() {
        mask = .all
        apply()
    }

    private func apply() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

/// Minimale `UIApplicationDelegate`, enkel om `OrientationLock` te kunnen
/// laten meespelen bij het bepalen van de toegestane oriëntaties. Zie
/// `Veyra_iOSApp.swift` (`@UIApplicationDelegateAdaptor`).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.shared.mask
    }
}
