//
//  Toxic_TomApp.swift
//  Toxic Tom
//
//  Created by Elliot Berentsen on 2026-01-18.
//

import SwiftUI

@main
struct Toxic_TomApp: App {
    
    init() {
        // Authenticate with Game Center when app launches
        GameCenterManager.shared.authenticate()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
