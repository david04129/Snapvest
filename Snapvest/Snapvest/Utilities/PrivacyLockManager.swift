//
//  PrivacyLockManager.swift
//  Snapvest
//
//  App 隱私鎖：用 Face ID / Touch ID / 裝置密碼保護前景畫面。
//

import Combine
import LocalAuthentication
import SwiftUI

@MainActor
final class PrivacyLockManager: ObservableObject {
    static let shared = PrivacyLockManager()
    
    private static let enabledStorageKey = "snapvest.isPrivacyLockEnabled"
    
    @Published private(set) var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledStorageKey)
        }
    }
    
    @Published private(set) var isLocked = false
    @Published private(set) var isAuthenticating = false
    @Published var errorMessage: String?
    
    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledStorageKey)
        isLocked = isEnabled
    }
    
    var statusText: String {
        isEnabled ? "已開啟" : "已關閉"
    }
    
    func setEnabled(_ enabled: Bool) async -> PrivacyLockChangeResult {
        guard isEnabled != enabled else {
            return .success
        }
        
        if enabled {
            let result = await evaluateAuthentication(reason: "啟用 Walleaf 隱私鎖")
            switch result {
            case .success:
                isEnabled = true
                isLocked = false
                return .success
            case .failure(let message):
                return .failure(message)
            }
        } else {
            isEnabled = false
            isLocked = false
            errorMessage = nil
            return .success
        }
    }
    
    func lockIfNeeded() {
        guard isEnabled else { return }
        isLocked = true
    }
    
    func prepareForProtectedPresentation() {
        guard isEnabled else { return }
        errorMessage = nil
        isLocked = true
    }
    
    func unlockWithAuthentication() async {
        guard isEnabled, isLocked, !isAuthenticating else { return }
        
        let result = await evaluateAuthentication(reason: "解鎖 Walleaf")
        switch result {
        case .success:
            isLocked = false
            errorMessage = nil
        case .failure(let message):
            isLocked = true
            errorMessage = message
        }
    }
    
    func handleScenePhase(_ scenePhase: ScenePhase, launchComplete: Bool) {
        guard launchComplete else { return }
        
        switch scenePhase {
        case .inactive:
            guard !isAuthenticating else { return }
            lockIfNeeded()
        case .background:
            lockIfNeeded()
        case .active:
            guard isEnabled, isLocked else { return }
            unlockAfterProtectedPresentation()
        @unknown default:
            break
        }
    }
    
    func handleLaunchComplete() {
        guard isEnabled else { return }
        isLocked = true
        unlockAfterProtectedPresentation()
    }
    
    private func unlockAfterProtectedPresentation() {
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            await unlockWithAuthentication()
        }
    }
    
    private func evaluateAuthentication(reason: String) async -> PrivacyLockAuthenticationResult {
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .failure(authenticationMessage(for: error))
        }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return .success
        } catch {
            return .failure(authenticationMessage(for: error as NSError))
        }
    }
    
    private func authenticationMessage(for error: NSError?) -> String {
        guard let error else {
            return "無法使用 Face ID、Touch ID 或裝置密碼驗證。"
        }
        
        switch LAError.Code(rawValue: error.code) {
        case .userCancel, .systemCancel, .appCancel:
            return "尚未解鎖，請再次驗證後繼續使用 Walleaf。"
        case .userFallback:
            return "請使用裝置密碼解鎖 Walleaf。"
        case .biometryNotAvailable:
            return "這台裝置無法使用 Face ID 或 Touch ID。"
        case .biometryNotEnrolled:
            return "尚未設定 Face ID 或 Touch ID，請先到系統設定完成設定。"
        case .passcodeNotSet:
            return "尚未設定裝置密碼，請先到系統設定完成設定。"
        case .biometryLockout:
            return "Face ID 或 Touch ID 已暫時鎖定，請使用裝置密碼解鎖。"
        default:
            return "驗證失敗，請再試一次。"
        }
    }
}

enum PrivacyLockChangeResult {
    case success
    case failure(String)
}

private enum PrivacyLockAuthenticationResult {
    case success
    case failure(String)
}
