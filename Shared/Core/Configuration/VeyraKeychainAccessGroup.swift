import Foundation
import Security

/// De volledige, team-geprefixte naam van de "com.veyra.shared"
/// Keychain-toegangsgroep (bv. "AB12CD34EF.com.veyra.shared"), gedeeld
/// tussen de Veyra-app en de VeyraTopShelf-extensie (zie beider
/// `.entitlements`) zodat de extensie dezelfde Trakt-sessie en
/// API-sleutels kan lezen als de app zelf, om "Verder kijken" te kunnen
/// tonen op het tvOS-beginscherm zonder dat de app open staat.
///
/// De team-prefix (`$(AppIdentifierPrefix)`) is pas bekend na het
/// bouwen (afhankelijk van het Apple-ontwikkelaarsteam) en kan dus niet
/// hardcoded in de broncode staan. In plaats daarvan wordt hij één keer
/// automatisch afgeleid: een wegwerp-item wordt zonder expliciete
/// toegangsgroep opgeslagen (het systeem kiest dan vanzelf de eerste
/// toegangsgroep van de app, hier "com.veyra.shared" — de enige die in
/// de entitlements staat) en meteen weer uitgelezen mét attributen, om
/// te zien onder welke volledige groepsnaam het is terechtgekomen.
enum VeyraKeychainAccessGroup {
    private static var cached: String?
    private static var didFail = false

    /// `nil` zolang de opzoeking nog niet is gelukt (bv. de eerste keer
    /// op een systeem zonder Keychain-toegang, zoals een Preview/Simulator
    /// zonder signing). Aanroepers vallen in dat geval terug op een query
    /// zonder `kSecAttrAccessGroup`, wat gewoon de app-eigen items geeft.
    static var shared: String? {
        if let cached { return cached }
        guard !didFail else { return nil }

        let probeQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.veyra.shared.keychain-group-probe",
            kSecAttrAccount as String: "probe"
        ]

        SecItemDelete(probeQuery as CFDictionary)

        var addQuery = probeQuery
        addQuery[kSecValueData as String] = Data([0])
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        guard SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess else {
            didFail = true
            return nil
        }

        var readQuery = probeQuery
        readQuery[kSecReturnAttributes as String] = true

        var result: CFTypeRef?
        guard SecItemCopyMatching(readQuery as CFDictionary, &result) == errSecSuccess,
              let attributes = result as? [String: Any],
              let group = attributes[kSecAttrAccessGroup as String] as? String
        else {
            didFail = true
            return nil
        }

        cached = group
        return group
    }
}
