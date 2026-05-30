//
//  LocalUserDataStore.swift
//  Snapvest
//
//  本機 JSON：結構快照（A）與估值快照（B）分區持久化，依 AppUser.id 分檔。
//

import Foundation

// MARK: - A：結構（帳戶／交易／負債）

struct LocalUserStructureStore: Codable {
    var accounts: [Account]
    var transactionsByAccountId: [String: [Transaction]]
    var liabilitiesByAccountId: [String: [Liability]]
    var manualAssets: [ManualAsset]
    var updatedAt: Date?
    
    init(
        accounts: [Account] = [],
        transactionsByAccountId: [String: [Transaction]] = [:],
        liabilitiesByAccountId: [String: [Liability]] = [:],
        manualAssets: [ManualAsset] = [],
        updatedAt: Date? = nil
    ) {
        self.accounts = accounts
        self.transactionsByAccountId = transactionsByAccountId
        self.liabilitiesByAccountId = liabilitiesByAccountId
        self.manualAssets = manualAssets
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try container.decodeIfPresent([Account].self, forKey: .accounts) ?? []
        transactionsByAccountId = try container.decodeIfPresent([String: [Transaction]].self, forKey: .transactionsByAccountId) ?? [:]
        liabilitiesByAccountId = try container.decodeIfPresent([String: [Liability]].self, forKey: .liabilitiesByAccountId) ?? [:]
        manualAssets = try container.decodeIfPresent([ManualAsset].self, forKey: .manualAssets) ?? []
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

// MARK: - B：估值（股價／市值／首頁總覽）

struct LocalUserValuationStore: Codable {
    var homeDashboardSnapshot: HomeDashboardSnapshot?
    var userHoldingsSnapshot: UserHoldingsSnapshot?
    var accountSnapshotsByAccountId: [String: AccountSnapshot]
    var assetPriceSnapshotsByKey: [String: AssetPriceSnapshot]
    var aggregatedHoldingSnapshots: [AggregatedHoldingSnapshot]
    var manualAssetValuationsByAssetId: [String: [ManualAssetValuation]]
    /// 本機完成對齊 Supabase 股價的時間
    var priceSyncedAt: Date?
    /// 對齊當下讀到的 price_update_metadata.last_updated_at
    var priceSourceUpdatedAt: Date?
    var updatedAt: Date?
    
    init(
        homeDashboardSnapshot: HomeDashboardSnapshot? = nil,
        userHoldingsSnapshot: UserHoldingsSnapshot? = nil,
        accountSnapshotsByAccountId: [String: AccountSnapshot] = [:],
        assetPriceSnapshotsByKey: [String: AssetPriceSnapshot] = [:],
        aggregatedHoldingSnapshots: [AggregatedHoldingSnapshot] = [],
        manualAssetValuationsByAssetId: [String: [ManualAssetValuation]] = [:],
        priceSyncedAt: Date? = nil,
        priceSourceUpdatedAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.homeDashboardSnapshot = homeDashboardSnapshot
        self.userHoldingsSnapshot = userHoldingsSnapshot
        self.accountSnapshotsByAccountId = accountSnapshotsByAccountId
        self.assetPriceSnapshotsByKey = assetPriceSnapshotsByKey
        self.aggregatedHoldingSnapshots = aggregatedHoldingSnapshots
        self.manualAssetValuationsByAssetId = manualAssetValuationsByAssetId
        self.priceSyncedAt = priceSyncedAt
        self.priceSourceUpdatedAt = priceSourceUpdatedAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        homeDashboardSnapshot = try container.decodeIfPresent(HomeDashboardSnapshot.self, forKey: .homeDashboardSnapshot)
        userHoldingsSnapshot = try container.decodeIfPresent(UserHoldingsSnapshot.self, forKey: .userHoldingsSnapshot)
        accountSnapshotsByAccountId = try container.decodeIfPresent([String: AccountSnapshot].self, forKey: .accountSnapshotsByAccountId) ?? [:]
        assetPriceSnapshotsByKey = try container.decodeIfPresent([String: AssetPriceSnapshot].self, forKey: .assetPriceSnapshotsByKey) ?? [:]
        aggregatedHoldingSnapshots = try container.decodeIfPresent([AggregatedHoldingSnapshot].self, forKey: .aggregatedHoldingSnapshots) ?? []
        manualAssetValuationsByAssetId = try container.decodeIfPresent([String: [ManualAssetValuation]].self, forKey: .manualAssetValuationsByAssetId) ?? [:]
        priceSyncedAt = try container.decodeIfPresent(Date.self, forKey: .priceSyncedAt)
        priceSourceUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .priceSourceUpdatedAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

// MARK: - 根文件（schema v4）

struct LocalUserData: Codable {
    static let currentSchemaVersion = 4
    
    let schemaVersion: Int
    let userId: String
    var structure: LocalUserStructureStore
    var valuation: LocalUserValuationStore
    
    init(
        schemaVersion: Int = LocalUserData.currentSchemaVersion,
        userId: String,
        structure: LocalUserStructureStore,
        valuation: LocalUserValuationStore
    ) {
        self.schemaVersion = schemaVersion
        self.userId = userId
        self.structure = structure
        self.valuation = valuation
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        userId = try container.decode(String.self, forKey: .userId)
        
        if container.contains(.structure), container.contains(.valuation) {
            structure = try container.decode(LocalUserStructureStore.self, forKey: .structure)
            valuation = try container.decode(LocalUserValuationStore.self, forKey: .valuation)
            return
        }
        
        // v1/v2 扁平格式 → 拆成 A/B
        let accounts = try container.decode([Account].self, forKey: .accounts)
        let transactionsByAccountId = try container.decodeIfPresent([String: [Transaction]].self, forKey: .transactionsByAccountId) ?? [:]
        let liabilitiesByAccountId = try container.decodeIfPresent([String: [Liability]].self, forKey: .liabilitiesByAccountId) ?? [:]
        let manualAssets = try container.decodeIfPresent([ManualAsset].self, forKey: .manualAssets) ?? []
        structure = LocalUserStructureStore(
            accounts: accounts,
            transactionsByAccountId: transactionsByAccountId,
            liabilitiesByAccountId: liabilitiesByAccountId,
            manualAssets: manualAssets
        )
        valuation = LocalUserValuationStore(
            homeDashboardSnapshot: try container.decodeIfPresent(HomeDashboardSnapshot.self, forKey: .homeDashboardSnapshot),
            userHoldingsSnapshot: try container.decodeIfPresent(UserHoldingsSnapshot.self, forKey: .userHoldingsSnapshot),
            accountSnapshotsByAccountId: try container.decodeIfPresent([String: AccountSnapshot].self, forKey: .accountSnapshotsByAccountId) ?? [:],
            assetPriceSnapshotsByKey: try container.decodeIfPresent([String: AssetPriceSnapshot].self, forKey: .assetPriceSnapshotsByKey) ?? [:],
            aggregatedHoldingSnapshots: try container.decodeIfPresent([AggregatedHoldingSnapshot].self, forKey: .aggregatedHoldingSnapshots) ?? [],
            manualAssetValuationsByAssetId: try container.decodeIfPresent([String: [ManualAssetValuation]].self, forKey: .manualAssetValuationsByAssetId) ?? [:]
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(userId, forKey: .userId)
        try container.encode(structure, forKey: .structure)
        try container.encode(valuation, forKey: .valuation)
    }
    
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case userId
        case structure
        case valuation
        case accounts
        case transactionsByAccountId
        case liabilitiesByAccountId
        case manualAssets
        case homeDashboardSnapshot
        case userHoldingsSnapshot
        case accountSnapshotsByAccountId
        case assetPriceSnapshotsByKey
        case aggregatedHoldingSnapshots
        case manualAssetValuationsByAssetId
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
        write(payload, userId: payload.userId)
    }
    
    static func saveStructure(_ structure: LocalUserStructureStore, userId: String) {
        var payload = load(userId: userId) ?? empty(userId: userId)
        payload.structure = structure
        write(payload, userId: userId)
    }
    
    static func saveValuation(_ valuation: LocalUserValuationStore, userId: String) {
        var payload = load(userId: userId) ?? empty(userId: userId)
        payload.valuation = valuation
        write(payload, userId: userId)
    }
    
    static func empty(userId: String) -> LocalUserData {
        LocalUserData(
            userId: userId,
            structure: LocalUserStructureStore(),
            valuation: LocalUserValuationStore()
        )
    }
    
    private static func write(_ payload: LocalUserData, userId: String) {
        do {
            let directory = try storageDirectoryURL()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            let url = fileURL(for: userId)
            let tempURL = directory.appendingPathComponent("\(sanitizedFileStem(for: userId)).tmp")
            var normalized = payload
            normalized = LocalUserData(
                schemaVersion: LocalUserData.currentSchemaVersion,
                userId: userId,
                structure: payload.structure,
                valuation: payload.valuation
            )
            let encoded = try encoder.encode(normalized)
            try encoded.write(to: tempURL, options: .atomic)
            
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: url)
            }
        } catch {
            print("[LocalUserDataStore] save failed for \(userId): \(error.localizedDescription)")
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
