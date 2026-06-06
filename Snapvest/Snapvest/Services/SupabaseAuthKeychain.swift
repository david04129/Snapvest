//
//  SupabaseAuthKeychain.swift
//  Snapvest
//
//  持久化 Anonymous Auth session（refresh token）。
//

import Foundation
import Security

struct SupabaseAuthStoredSession: Sendable, Equatable, Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: TimeInterval
    let userId: String
    let isAnonymous: Bool

    nonisolated init(
        accessToken: String,
        refreshToken: String,
        expiresAt: TimeInterval,
        userId: String,
        isAnonymous: Bool
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.userId = userId
        self.isAnonymous = isAnonymous
    }

    private enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case expiresAt
        case userId
        case isAnonymous
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        expiresAt = try container.decode(TimeInterval.self, forKey: .expiresAt)
        userId = try container.decode(String.self, forKey: .userId)
        isAnonymous = try container.decode(Bool.self, forKey: .isAnonymous)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encode(expiresAt, forKey: .expiresAt)
        try container.encode(userId, forKey: .userId)
        try container.encode(isAnonymous, forKey: .isAnonymous)
    }
}

enum SupabaseAuthKeychain: Sendable {
    nonisolated private static var service: String { "com.snapvest.supabase.auth" }
    nonisolated private static var account: String { "anonymous-session" }

    nonisolated static func load() -> SupabaseAuthStoredSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let session = try? JSONDecoder().decode(SupabaseAuthStoredSession.self, from: data) else {
            return nil
        }
        return session
    }

    nonisolated static func save(_ session: SupabaseAuthStoredSession) {
        delete()
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    nonisolated static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
