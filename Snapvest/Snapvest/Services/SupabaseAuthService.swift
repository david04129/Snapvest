//
//  SupabaseAuthService.swift
//  Snapvest
//
//  Phase A：Supabase Anonymous Auth，供 Edge / REST 帶 per-device JWT。
//

import Foundation

struct SupabaseAuthSession: Sendable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userId: String
    let isAnonymous: Bool
}

enum SupabaseAuthError: LocalizedError {
    case notConfigured
    case anonymousSignInDisabled
    case invalidResponse
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Supabase 未設定"
        case .anonymousSignInDisabled: return "Anonymous Sign-In 未在 Supabase 啟用"
        case .invalidResponse: return "Auth 回應格式錯誤"
        case .httpStatus(let code, let body): return "Auth 失敗（HTTP \(code)）：\(body)"
        }
    }
}

actor SupabaseAuthService {
    static let shared = SupabaseAuthService()

    private static let refreshSkew: TimeInterval = 120

    private var cachedSession: SupabaseAuthSession?
    private var inFlightEnsure: Task<SupabaseAuthSession?, Never>?

    func warmUp() async {
        _ = await ensureSession()
    }

    func bearerAccessToken() async -> String? {
        guard await shouldUseAuth() else { return nil }
        return await ensureSession()?.accessToken
    }

    func currentUserId() async -> String? {
        guard await shouldUseAuth() else { return nil }
        return await ensureSession()?.userId
    }

    /// 清除 session（除錯／登出用；Phase A 一般使用者不需呼叫）
    func signOut() {
        cachedSession = nil
        SupabaseAuthKeychain.delete()
    }

    func ensureSession() async -> SupabaseAuthSession? {
        guard await shouldUseAuth() else { return nil }

        if let inFlightEnsure {
            return await inFlightEnsure.value
        }

        let task = Task<SupabaseAuthSession?, Never> {
            await self.ensureSessionUnlocked()
        }
        inFlightEnsure = task
        defer { inFlightEnsure = nil }
        return await task.value
    }

    private func ensureSessionUnlocked() async -> SupabaseAuthSession? {
        if let cachedSession, !shouldRefresh(cachedSession) {
            return cachedSession
        }

        if let stored = SupabaseAuthKeychain.load() {
            if !shouldRefresh(stored) {
                let session = SupabaseAuthSession(stored: stored)
                cachedSession = session
                return session
            }
            if let refreshed = try? await refreshSession(refreshToken: stored.refreshToken) {
                cachedSession = refreshed
                persist(refreshed)
                return refreshed
            }
            SupabaseAuthKeychain.delete()
        }

        do {
            let created = try await signInAnonymously()
            cachedSession = created
            persist(created)
            #if DEBUG
            print("[SupabaseAuthService] anonymous sign-in userId=\(created.userId.prefix(8))…")
            #endif
            return created
        } catch {
            print("[SupabaseAuthService] ensureSession failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func shouldUseAuth() async -> Bool {
        guard SupabaseConfig.isConfigured else { return false }
        let demoEnabled = await MainActor.run { DemoModeManager.shared.isEnabled }
        return !demoEnabled
    }

    private func shouldRefresh(_ session: SupabaseAuthSession) -> Bool {
        session.expiresAt.timeIntervalSinceNow <= Self.refreshSkew
    }

    private func shouldRefresh(_ stored: SupabaseAuthStoredSession) -> Bool {
        stored.expiresAt - Date().timeIntervalSince1970 <= Self.refreshSkew
    }

    private func persist(_ session: SupabaseAuthSession) {
        SupabaseAuthKeychain.save(
            SupabaseAuthStoredSession(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                expiresAt: session.expiresAt.timeIntervalSince1970,
                userId: session.userId,
                isAnonymous: session.isAnonymous
            )
        )
    }

    private func authRequestHeaders() -> (apikey: String, authorization: String)? {
        guard let apikey = SupabaseConfig.anonKey else { return nil }
        let bearer = SupabaseConfig.edgeFunctionAuthorizationToken ?? apikey
        return (apikey, bearer)
    }

    private func signInAnonymously() async throws -> SupabaseAuthSession {
        guard let baseUrl = SupabaseConfig.url,
              let headers = authRequestHeaders(),
              let url = URL(string: "\(baseUrl)/auth/v1/signup") else {
            throw SupabaseAuthError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(headers.apikey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(headers.authorization)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SignUpBody(data: [:]))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseAuthError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            if body.localizedCaseInsensitiveContains("anonymous") {
                throw SupabaseAuthError.anonymousSignInDisabled
            }
            throw SupabaseAuthError.httpStatus(http.statusCode, String(body.prefix(300)))
        }
        return try parseAuthResponse(data)
    }

    private func refreshSession(refreshToken: String) async throws -> SupabaseAuthSession {
        guard let baseUrl = SupabaseConfig.url,
              let headers = authRequestHeaders(),
              let url = URL(string: "\(baseUrl)/auth/v1/token?grant_type=refresh_token") else {
            throw SupabaseAuthError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(headers.apikey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(headers.authorization)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RefreshBody(refreshToken: refreshToken))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseAuthError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw SupabaseAuthError.httpStatus(
                http.statusCode,
                String((String(data: data, encoding: .utf8) ?? "").prefix(300))
            )
        }
        return try parseAuthResponse(data)
    }

    private func parseAuthResponse(_ data: Data) throws -> SupabaseAuthSession {
        let decoded = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
        guard let accessToken = decoded.access_token,
              let refreshToken = decoded.refresh_token,
              let userId = decoded.user?.id else {
            throw SupabaseAuthError.invalidResponse
        }
        let expiresAt: Date
        if let expiresAtSeconds = decoded.expires_at {
            expiresAt = Date(timeIntervalSince1970: TimeInterval(expiresAtSeconds))
        } else if let expiresIn = decoded.expires_in {
            expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            expiresAt = Date().addingTimeInterval(3600)
        }
        return SupabaseAuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            userId: userId,
            isAnonymous: decoded.user?.is_anonymous ?? true
        )
    }

    private struct SignUpBody: Encodable {
        let data: [String: String]
    }

    private struct RefreshBody: Encodable {
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case refreshToken = "refresh_token"
        }
    }

    private struct AuthTokenResponse: Decodable {
        let access_token: String?
        let refresh_token: String?
        let expires_in: Int?
        let expires_at: Int?
        let user: AuthUserResponse?
    }

    private struct AuthUserResponse: Decodable {
        let id: String?
        let is_anonymous: Bool?
    }
}

private extension SupabaseAuthSession {
    nonisolated init(stored: SupabaseAuthStoredSession) {
        self.init(
            accessToken: stored.accessToken,
            refreshToken: stored.refreshToken,
            expiresAt: Date(timeIntervalSince1970: stored.expiresAt),
            userId: stored.userId,
            isAnonymous: stored.isAnonymous
        )
    }
}
