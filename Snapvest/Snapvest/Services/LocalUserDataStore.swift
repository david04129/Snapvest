//
//  LocalUserDataStore.swift
//  Snapvest
//
//  本機 JSON 持久化（帳戶／交易／負債／快照），依 AppUser.id 分檔。
//

import Foundation

struct LocalUserData: Codable, Equatable {
    static let currentSchemaVersion = 2
    
    let schemaVersion: Int
    let userId: String
    var accounts: [Account]
    var transactionsByAccountId: [String: [Transaction]]
    var liabilitiesByAccountId: [String: [Liability]]
    var homeDashboardSnapshot: HomeDashboardSnapshot?
    var userHoldingsSnapshot: UserHoldingsSnapshot?
    var accountSnapshotsByAccountId: [String: AccountSnapshot]
    var assetPriceSnapshotsByKey: [String: AssetPriceSnapshot]
    var aggregatedHoldingSnapshots: [AggregatedHoldingSnapshot]
    
    init(
        schemaVersion: Int = LocalUserData.currentSchemaVersion,
        userId: String,
        accounts: [Account],
        transactionsByAccountId: [String: [Transaction]],
        liabilitiesByAccountId: [String: [Liability]],
        homeDashboardSnapshot: HomeDashboardSnapshot? = nil,
        userHoldingsSnapshot: UserHoldingsSnapshot? = nil,
        accountSnapshotsByAccountId: [String: AccountSnapshot] = [:],
        assetPriceSnapshotsByKey: [String: AssetPriceSnapshot] = [:],
        aggregatedHoldingSnapshots: [AggregatedHoldingSnapshot] = []
    ) {
        self.schemaVersion = schemaVersion
        self.userId = userId
        self.accounts = accounts
        self.transactionsByAccountId = transactionsByAccountId
        self.liabilitiesByAccountId = liabilitiesByAccountId
        self.homeDashboardSnapshot = homeDashboardSnapshot
        self.userHoldingsSnapshot = userHoldingsSnapshot
        self.accountSnapshotsByAccountId = accountSnapshotsByAccountId
        self.assetPriceSnapshotsByKey = assetPriceSnapshotsByKey
        self.aggregatedHoldingSnapshots = aggregatedHoldingSnapshots
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        userId = try container.decode(String.self, forKey: .userId)
        accounts = try container.decode([Account].self, forKey: .accounts)
        transactionsByAccountId = try container.decodeIfPresent([String: [Transaction]].self, forKey: .transactionsByAccountId) ?? [:]
        liabilitiesByAccountId = try container.decodeIfPresent([String: [Liability]].self, forKey: .liabilitiesByAccountId) ?? [:]
        homeDashboardSnapshot = try container.decodeIfPresent(HomeDashboardSnapshot.self, forKey: .homeDashboardSnapshot)
        userHoldingsSnapshot = try container.decodeIfPresent(UserHoldingsSnapshot.self, forKey: .userHoldingsSnapshot)
        accountSnapshotsByAccountId = try container.decodeIfPresent([String: AccountSnapshot].self, forKey: .accountSnapshotsByAccountId) ?? [:]
        assetPriceSnapshotsByKey = try container.decodeIfPresent([String: AssetPriceSnapshot].self, forKey: .assetPriceSnapshotsByKey) ?? [:]
        aggregatedHoldingSnapshots = try container.decodeIfPresent([AggregatedHoldingSnapshot].self, forKey: .aggregatedHoldingSnapshots) ?? []
    }
}

enum LocalUserDataStore {
    private static let directoryName = "Snapvest"
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .deferredToDate
        return encoder
    }()
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }()
    
    static func load(userId: String) -> LocalUserData? {
        let url = fileURL(for: userId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try decoder.decode(LocalUserData.self, from: data)
            guard decoded.userId == userId else { return nil }
            return decoded
        } catch {
            print("[LocalUserDataStore] load failed for \(userId): \(error.localizedDescription)")
            return nil
        }
    }
    
    static func save(_ payload: LocalUserData) {
        do {
            let directory = try storageDirectoryURL()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            let url = fileURL(for: payload.userId)
            let tempURL = directory.appendingPathComponent("\(sanitizedFileStem(for: payload.userId)).tmp")
            let encoded = try encoder.encode(payload)
            try encoded.write(to: tempURL, options: .atomic)
            
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: url)
            }
        } catch {
            print("[LocalUserDataStore] save failed for \(payload.userId): \(error.localizedDescription)")
        }
    }
    
    private static func storageDirectoryURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }
    
    private static func fileURL(for userId: String) -> URL {
        let directory = (try? storageDirectoryURL()) ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent("\(sanitizedFileStem(for: userId)).json")
    }
    
    private static func sanitizedFileStem(for userId: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let sanitized = String(userId.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return sanitized.isEmpty ? "default-user" : sanitized
    }
}
