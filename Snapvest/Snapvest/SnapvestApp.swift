//
//  SnapvestApp.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

@main
struct SnapvestApp: App {
    init() {
        SupabaseConfigLoader.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
