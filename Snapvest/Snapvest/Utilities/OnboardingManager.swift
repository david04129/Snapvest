//
//  OnboardingManager.swift
//  Snapvest
//
//  首次啟動新手教學（UserDefaults 持久化）
//

import Foundation
import Combine

@MainActor
final class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()

    private static let hasCompletedKey = "walleaf.hasCompletedOnboarding"

    @Published var isPresented = false

    private init() {}

    var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: Self.hasCompletedKey)
    }

    func presentIfNeeded() {
        guard !hasCompletedOnboarding else { return }
        isPresented = true
    }

    func presentManually() {
        isPresented = true
    }

    func complete() {
        UserDefaults.standard.set(true, forKey: Self.hasCompletedKey)
        isPresented = false
    }

    func dismissWithoutCompleting() {
        isPresented = false
    }
}
