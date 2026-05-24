//
//  AppUser.swift
//  Snapvest
//
//  測試期使用者 ID（雲端 sync／走勢圖依此分開）。
//  兩人分開測試：各自在 Info.plist 改 SNAPVEST_USER_ID，不必改程式、也避免 git 衝突。
//

import Foundation

enum AppUser {
    static let id: String = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "SNAPVEST_USER_ID") as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "test-user-id"
    }()
}
