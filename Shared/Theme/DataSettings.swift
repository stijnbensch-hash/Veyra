import Foundation

/// Instellingen → Data: cache legen en automatisch verversen bij het
/// terugkeren naar de app. Zie `VeyraApp.swift`/`Veyra_iOSApp.swift`/
/// `VeyraMacApp.swift` voor waar `autoRefreshOnForegroundKey` toegepast
/// wordt, en `DataSettingsView` voor de "Cache legen"-knop.
enum DataSettingsDefaults {
    static let autoRefreshOnForegroundKey = "data.autoRefreshOnForeground"
}
