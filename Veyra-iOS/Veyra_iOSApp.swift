//
//  Veyra_iOSApp.swift
//  Veyra-iOS
//
//  Created by Stijn Bensch on 19/09/2026.
//

import SwiftUI

@main
struct Veyra_iOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Instellingen via iCloud spiegelen — zie
                    // `Shared/Sync/CloudSettingsSync.swift`.
                    CloudSettingsSync.shared.start()
                }
        }
    }
}
