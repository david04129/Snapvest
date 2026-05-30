//
//  Backup.swift
//  Snapvest
//
//  iCloud Drive backup package models.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct WalleafBackupFile: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let appName: String
    let createdAt: Date
    let sourceUserId: String
    var data: LocalUserData
    var preferences: BackupUserPreferences

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        appName: String = "Walleaf",
        createdAt: Date = Date(),
        sourceUserId: String,
        data: LocalUserData,
        preferences: BackupUserPreferences
    ) {
        self.schemaVersion = schemaVersion
        self.appName = appName
        self.createdAt = createdAt
        self.sourceUserId = sourceUserId
        self.data = data
        self.preferences = preferences
    }
}

struct BackupUserPreferences: Codable, Equatable {
    var baseCurrency: Currency?
    var isDarkMode: Bool?
    var isRedUpGreenDown: Bool?
    var isHomeAmountHidden: Bool?
    var homeShareSelectedChartKinds: [String]?
    var pieChartGroups: [PieChartItemGroup]?
    var pieChartDisplayMode: PieChartGroupingDisplayMode?
    var pieChartExpandedLegendGroupIds: [String]?
    var accountOrderData: [String: Data]
    var holdingColorData: [String: Data]

    init(
        baseCurrency: Currency? = nil,
        isDarkMode: Bool? = nil,
        isRedUpGreenDown: Bool? = nil,
        isHomeAmountHidden: Bool? = nil,
        homeShareSelectedChartKinds: [String]? = nil,
        pieChartGroups: [PieChartItemGroup]? = nil,
        pieChartDisplayMode: PieChartGroupingDisplayMode? = nil,
        pieChartExpandedLegendGroupIds: [String]? = nil,
        accountOrderData: [String: Data] = [:],
        holdingColorData: [String: Data] = [:]
    ) {
        self.baseCurrency = baseCurrency
        self.isDarkMode = isDarkMode
        self.isRedUpGreenDown = isRedUpGreenDown
        self.isHomeAmountHidden = isHomeAmountHidden
        self.homeShareSelectedChartKinds = homeShareSelectedChartKinds
        self.pieChartGroups = pieChartGroups
        self.pieChartDisplayMode = pieChartDisplayMode
        self.pieChartExpandedLegendGroupIds = pieChartExpandedLegendGroupIds
        self.accountOrderData = accountOrderData
        self.holdingColorData = holdingColorData
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension LocalUserData {
    func backupPayload() -> LocalUserData {
        var valuation = valuation
        valuation.assetPriceSnapshotsByKey = [:]
        valuation.priceSyncedAt = nil
        valuation.priceSourceUpdatedAt = nil
        return LocalUserData(
            schemaVersion: LocalUserData.currentSchemaVersion,
            userId: userId,
            structure: structure,
            valuation: valuation
        )
    }

    func normalizedForRestore(userId targetUserId: String) -> LocalUserData {
        let normalizedAccounts = structure.accounts.map { account in
            Account(
                id: account.id,
                userId: targetUserId,
                name: account.name,
                accountType: account.accountType,
                currency: account.currency,
                createdAt: account.createdAt,
                updatedAt: account.updatedAt,
                isArchived: account.isArchived,
                archivedAt: account.archivedAt
            )
        }

        let normalizedManualAssets = structure.manualAssets.map { asset in
            ManualAsset(
                id: asset.id,
                userId: targetUserId,
                name: asset.name,
                category: asset.category,
                currency: asset.currency,
                currentValue: asset.currentValue,
                costBasis: asset.costBasis,
                purchaseDate: asset.purchaseDate,
                notes: asset.notes,
                isIncludedInTotalAssets: asset.isIncludedInTotalAssets,
                isIncludedInInvestments: asset.isIncludedInInvestments,
                currentValueUpdatedAt: asset.currentValueUpdatedAt,
                createdAt: asset.createdAt,
                updatedAt: asset.updatedAt
            )
        }

        let normalizedValuations = valuation.manualAssetValuationsByAssetId.values.flatMap { valuations in
            valuations.map { valuation in
                ManualAssetValuation(
                    id: valuation.id,
                    userId: targetUserId,
                    manualAssetId: valuation.manualAssetId,
                    value: valuation.value,
                    currency: valuation.currency,
                    valuationDate: valuation.valuationDate,
                    notes: valuation.notes,
                    createdAt: valuation.createdAt
                )
            }
        }

        let normalizedTrendSnapshots = valuation.dailyTrendSnapshotsByDate.values.map { snapshot in
            LocalDailyTrendSnapshot(
                userId: targetUserId,
                date: snapshot.date,
                currency: snapshot.currency,
                totalAssets: snapshot.totalAssets,
                netWorth: snapshot.netWorth,
                unrealizedGainLoss: snapshot.unrealizedGainLoss,
                sourceHomeSnapshotUpdatedAt: snapshot.sourceHomeSnapshotUpdatedAt,
                recordedAt: snapshot.recordedAt
            )
        }

        var normalizedValuation = valuation
        normalizedValuation.homeDashboardSnapshot = valuation.homeDashboardSnapshot.map { snapshot in
            HomeDashboardSnapshot(
                userId: targetUserId,
                netWorth: snapshot.netWorth,
                totalLiabilities: snapshot.totalLiabilities,
                totalAssets: snapshot.totalAssets,
                totalInvestments: snapshot.totalInvestments,
                totalInvestmentsCost: snapshot.totalInvestmentsCost,
                totalCash: snapshot.totalCash,
                twdCash: snapshot.twdCash,
                usdCash: snapshot.usdCash,
                realizedGainLossTWD: snapshot.realizedGainLossTWD,
                realizedGainLossUSD: snapshot.realizedGainLossUSD,
                lastUpdated: snapshot.lastUpdated
            )
        }
        normalizedValuation.userHoldingsSnapshot = valuation.userHoldingsSnapshot.map { snapshot in
            UserHoldingsSnapshot(
                userId: targetUserId,
                symbols: snapshot.symbols,
                lastUpdated: snapshot.lastUpdated
            )
        }
        normalizedValuation.aggregatedHoldingSnapshots = valuation.aggregatedHoldingSnapshots.map { snapshot in
            AggregatedHoldingSnapshot(
                userId: targetUserId,
                assetType: snapshot.assetType,
                symbol: snapshot.symbol,
                name: snapshot.name,
                currency: snapshot.currency,
                totalQuantity: snapshot.totalQuantity,
                weightedAverageCost: snapshot.weightedAverageCost,
                totalCost: snapshot.totalCost,
                sourceAccountIds: snapshot.sourceAccountIds,
                fifoLotsByAccount: snapshot.fifoLotsByAccount,
                lastUpdated: snapshot.lastUpdated,
                lastTransactionDate: snapshot.lastTransactionDate,
                version: snapshot.version
            )
        }
        normalizedValuation.manualAssetValuationsByAssetId = Dictionary(
            grouping: normalizedValuations,
            by: \.manualAssetId
        )
        normalizedValuation.dailyTrendSnapshotsByDate = Dictionary(
            grouping: normalizedTrendSnapshots,
            by: \.id
        ).compactMapValues { snapshots in
            snapshots.max { lhs, rhs in
                if lhs.recordedAt == rhs.recordedAt {
                    return lhs.sourceHomeSnapshotUpdatedAt < rhs.sourceHomeSnapshotUpdatedAt
                }
                return lhs.recordedAt < rhs.recordedAt
            }
        }
        normalizedValuation.priceSyncedAt = nil
        normalizedValuation.priceSourceUpdatedAt = nil

        let normalizedStructure = LocalUserStructureStore(
            accounts: normalizedAccounts,
            transactionsByAccountId: structure.transactionsByAccountId,
            liabilitiesByAccountId: structure.liabilitiesByAccountId,
            manualAssets: normalizedManualAssets,
            updatedAt: structure.updatedAt
        )

        return LocalUserData(
            schemaVersion: LocalUserData.currentSchemaVersion,
            userId: targetUserId,
            structure: normalizedStructure,
            valuation: normalizedValuation
        )
    }
}
