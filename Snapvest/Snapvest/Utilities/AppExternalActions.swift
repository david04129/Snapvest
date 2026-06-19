//
//  AppExternalActions.swift
//  Snapvest
//
//  App Store 評論、優惠碼兌換等外部動作
//

import Foundation
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

enum AppExternalActions {
    static func presentOfferCodeRedemptionSheet() {
        #if canImport(UIKit)
        guard let scene = foregroundActiveWindowScene else { return }
        Task { @MainActor in
            do {
                try await AppStore.presentOfferCodeRedeemSheet(in: scene)
            } catch {
                // Apple sheet dismissal or environment errors are user-driven; no alert needed.
            }
        }
        #endif
    }

    #if canImport(UIKit)
    private static var foregroundActiveWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
    }
    #endif
}
