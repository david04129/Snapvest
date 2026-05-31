//
//  BackupService.swift
//  Snapvest
//
//  iCloud Drive backup import/export helpers.
//

import Foundation

enum BackupServiceError: LocalizedError {
    case noLocalData
    case unsupportedSchema(Int)
    case emptyBackup
    case restoreFailed

    var errorDescription: String? {
        switch self {
        case .noLocalData:
            return "目前沒有可備份的本機資料。"
        case .unsupportedSchema(let version):
            return "這個備份檔版本（\(version)）目前不支援。"
        case .emptyBackup:
            return "備份檔內容不完整，無法還原。"
        case .restoreFailed:
            return "還原失敗，原本資料未被覆蓋。"
        }
    }
}

@MainActor
enum BackupService {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .deferredToDate
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }()

    static func makeBackup(userId: String, dataService: MockDataService? = nil) throws -> WalleafBackupFile {
        let resolvedDataService = dataService ?? MockDataService.shared
        resolvedDataService.persistLocalStore(for: userId)
        guard let localData = LocalUserDataStore.load(userId: userId) else {
            throw BackupServiceError.noLocalData
        }
        return WalleafBackupFile(
            sourceUserId: userId,
            data: localData.backupPayload(),
            preferences: BackupUserPreferences.capture(userId: userId, localData: localData)
        )
    }

    static func encode(_ backup: WalleafBackupFile) throws -> Data {
        try encoder.encode(backup)
    }

    static func decodeBackup(from data: Data) throws -> WalleafBackupFile {
        let backup = try decoder.decode(WalleafBackupFile.self, from: data)
        try validate(backup)
        return backup
    }

    static func decodeBackup(from url: URL) throws -> WalleafBackupFile {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try decodeBackup(from: Data(contentsOf: url))
    }

    static func restore(
        _ backup: WalleafBackupFile,
        to userId: String,
        dataService: MockDataService? = nil
    ) async throws {
        let resolvedDataService = dataService ?? MockDataService.shared
        try validate(backup)
        let restoredData = backup.data.normalizedForRestore(userId: userId)
        try resolvedDataService.replaceLocalStoreForRestore(restoredData, userId: userId)
        backup.preferences.apply(to: userId)
        let backupTrendSnapshots = Array(restoredData.valuation.dailyTrendSnapshotsByDate.values)

        _ = await SnapshotRefreshCoordinator.rebuildAndNotify(
            userId: userId,
            dataService: resolvedDataService,
            updatePriceMetadata: false,
            deferRemoteWork: false,
            postsUpdateNotification: false
        )
        for snapshot in backupTrendSnapshots {
            try await resolvedDataService.upsertLocalDailyTrendSnapshot(snapshot)
        }
        NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
    }

    static func defaultFilename(createdAt: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "Walleaf-Backup-\(formatter.string(from: createdAt))"
    }

    private static func validate(_ backup: WalleafBackupFile) throws {
        guard backup.schemaVersion <= WalleafBackupFile.currentSchemaVersion else {
            throw BackupServiceError.unsupportedSchema(backup.schemaVersion)
        }
        guard !backup.data.structure.accounts.isEmpty
            || !backup.data.structure.transactionsByAccountId.isEmpty
            || !backup.data.structure.liabilitiesByAccountId.isEmpty
            || !backup.data.structure.manualAssets.isEmpty
            || !backup.data.valuation.dailyTrendSnapshotsByDate.isEmpty else {
            throw BackupServiceError.emptyBackup
        }
    }
}

extension BackupUserPreferences {
    @MainActor
    static func capture(userId: String, localData: LocalUserData) -> BackupUserPreferences {
        let defaults = UserDefaults.standard
        let baseCurrency = defaults.string(forKey: BackupPreferenceKeys.baseCurrency)
            .flatMap(Currency.init(rawValue:))
        let homeShareKinds = defaults.stringArray(forKey: BackupPreferenceKeys.homeShareSelectedChartKinds(userId: userId))

        return BackupUserPreferences(
            baseCurrency: baseCurrency,
            isDarkMode: defaults.object(forKey: BackupPreferenceKeys.darkMode) as? Bool,
            isRedUpGreenDown: defaults.object(forKey: BackupPreferenceKeys.redUpGreenDown) as? Bool,
            isHomeAmountHidden: defaults.object(forKey: BackupPreferenceKeys.homeAmountHidden) as? Bool,
            homeShareSelectedChartKinds: homeShareKinds,
            pieChartGroups: readPieChartGroups(userId: userId),
            pieChartDisplayMode: readPieChartDisplayMode(userId: userId),
            pieChartExpandedLegendGroupIds: defaults.stringArray(forKey: BackupPreferenceKeys.pieExpandedLegend(userId: userId)),
            accountOrderData: readAccountOrderData(userId: userId),
            holdingColorData: readHoldingColorData(localData: localData)
        )
    }

    @MainActor
    func apply(to userId: String) {
        let defaults = UserDefaults.standard

        if let baseCurrency {
            BaseCurrencyManager.shared.setBaseCurrency(baseCurrency)
        }
        if let isDarkMode {
            ThemeManager.shared.setDarkMode(isDarkMode)
        }
        if let isRedUpGreenDown {
            ThemeManager.shared.setRedUpGreenDown(isRedUpGreenDown)
        }
        if let isHomeAmountHidden {
            HomePrivacyManager.shared.setAmountHidden(isHomeAmountHidden)
        }

        applyHomeSharePreferences(to: userId, defaults: defaults)
        applyPieChartPreferences(to: userId, defaults: defaults)
        applyAccountOrderData(to: userId, defaults: defaults)
        applyHoldingColorData(defaults: defaults)

        PieChartGroupingStore.shared.reload(for: userId)
    }

    private static func readPieChartGroups(userId: String) -> [PieChartItemGroup]? {
        guard let data = UserDefaults.standard.data(forKey: BackupPreferenceKeys.pieGroups(userId: userId)) else {
            return nil
        }
        return try? JSONDecoder().decode([PieChartItemGroup].self, from: data)
    }

    private static func readPieChartDisplayMode(userId: String) -> PieChartGroupingDisplayMode? {
        guard let raw = UserDefaults.standard.string(forKey: BackupPreferenceKeys.pieDisplayMode(userId: userId)) else {
            return nil
        }
        return PieChartGroupingDisplayMode(rawValue: raw)
    }

    private static func readAccountOrderData(userId: String) -> [String: Data] {
        let defaults = UserDefaults.standard
        var dataByKey: [String: Data] = [:]
        for key in BackupPreferenceKeys.accountOrderBackupKeys(userId: userId) {
            if let data = defaults.data(forKey: key.storageKey) {
                dataByKey[key.backupKey] = data
            }
        }
        return dataByKey
    }

    private static func readHoldingColorData(localData: LocalUserData) -> [String: Data] {
        let defaults = UserDefaults.standard
        var keys = Set<String>()

        for snapshot in localData.valuation.aggregatedHoldingSnapshots {
            keys.insert(BackupPreferenceKeys.holdingColor(assetType: snapshot.assetType, symbol: snapshot.symbol))
        }
        for snapshot in localData.valuation.accountSnapshotsByAccountId.values {
            for holding in snapshot.holdings ?? [] {
                keys.insert(BackupPreferenceKeys.holdingColor(assetType: holding.assetType, symbol: holding.symbol))
            }
        }
        for transactionGroup in localData.structure.transactionsByAccountId.values {
            for transaction in transactionGroup where transaction.assetType != .cash && !transaction.symbol.isEmpty {
                keys.insert(BackupPreferenceKeys.holdingColor(assetType: transaction.assetType, symbol: transaction.symbol))
            }
        }

        return Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            defaults.data(forKey: key).map { (key, $0) }
        })
    }

    private func applyHomeSharePreferences(to userId: String, defaults: UserDefaults) {
        let key = BackupPreferenceKeys.homeShareSelectedChartKinds(userId: userId)
        if let homeShareSelectedChartKinds {
            defaults.set(homeShareSelectedChartKinds, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func applyPieChartPreferences(to userId: String, defaults: UserDefaults) {
        let groupsKey = BackupPreferenceKeys.pieGroups(userId: userId)
        let displayModeKey = BackupPreferenceKeys.pieDisplayMode(userId: userId)
        let expandedKey = BackupPreferenceKeys.pieExpandedLegend(userId: userId)

        if let pieChartGroups,
           let data = try? JSONEncoder().encode(pieChartGroups) {
            defaults.set(data, forKey: groupsKey)
        } else {
            defaults.removeObject(forKey: groupsKey)
        }

        if let pieChartDisplayMode {
            defaults.set(pieChartDisplayMode.rawValue, forKey: displayModeKey)
        } else {
            defaults.removeObject(forKey: displayModeKey)
        }

        if let pieChartExpandedLegendGroupIds {
            defaults.set(pieChartExpandedLegendGroupIds, forKey: expandedKey)
        } else {
            defaults.removeObject(forKey: expandedKey)
        }
    }

    private func applyAccountOrderData(to userId: String, defaults: UserDefaults) {
        for key in BackupPreferenceKeys.accountOrderBackupKeys(userId: userId) {
            if let data = accountOrderData[key.backupKey] {
                defaults.set(data, forKey: key.storageKey)
            } else {
                defaults.removeObject(forKey: key.storageKey)
            }
        }
    }

    private func applyHoldingColorData(defaults: UserDefaults) {
        for (key, data) in holdingColorData {
            defaults.set(data, forKey: key)
        }
    }
}

private enum BackupPreferenceKeys {
    static let baseCurrency = "walleaf.baseCurrency"
    static let darkMode = "snapvest.isDarkMode"
    static let redUpGreenDown = "snapvest.isRedUpGreenDown"
    static let homeAmountHidden = "snapvest.isHomeAmountHidden"

    static func homeShareSelectedChartKinds(userId: String) -> String {
        "homeShareSelectedChartKinds_\(userId)"
    }

    static func pieGroups(userId: String) -> String {
        "pieChartGroups_\(userId)"
    }

    static func pieDisplayMode(userId: String) -> String {
        "pieChartGroupingDisplay_\(userId)"
    }

    static func pieExpandedLegend(userId: String) -> String {
        "pieChartExpandedLegend_\(userId)"
    }

    static func holdingColor(assetType: AssetType, symbol: String) -> String {
        "\(assetType.rawValue)_\(symbol)"
    }

    static func accountOrderBackupKeys(userId: String) -> [(backupKey: String, storageKey: String)] {
        var keys: [(backupKey: String, storageKey: String)] = [
            (backupKey: "accountOrder", storageKey: "accountOrder_\(userId)"),
            (backupKey: "managementSectionOrder", storageKey: "managementSectionOrder_\(userId)")
        ]
        keys.append(
            contentsOf: AccountType.allCases.map { accountType in
                (
                    backupKey: "accountOrder.\(accountType.rawValue)",
                    storageKey: "accountOrder_\(userId)_\(accountType.rawValue)"
                )
            }
        )
        return keys
    }
}
