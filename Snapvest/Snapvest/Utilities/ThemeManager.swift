//
//  ThemeManager.swift
//  Snapvest
//
//  淺色 / 深色主題切換（UserDefaults 持久化）
//

import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    private static let storageKey = "snapvest.isDarkMode"
    
    @Published private(set) var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: Self.storageKey)
        }
    }
    
    private init() {
        isDarkMode = UserDefaults.standard.bool(forKey: Self.storageKey)
    }
    
    var palette: ThemePalette {
        isDarkMode ? .dark : .light
    }
    
    func toggle() {
        withAnimation(.easeInOut(duration: 0.28)) {
            isDarkMode.toggle()
        }
    }
}
