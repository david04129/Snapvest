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
        // Anonymous Auth 由 LaunchCoordinator 在確認有網路後 warmUp，避免啟動初網路未就緒時 signup 失敗。
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
