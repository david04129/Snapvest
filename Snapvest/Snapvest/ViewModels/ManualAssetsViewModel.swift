//
//  ManualAssetsViewModel.swift
//  Snapvest
//
//  Local-only manual asset management and snapshot refresh orchestration.
//

import Foundation
import Combine

struct ManualAssetFormState: Equatable {
    var id: String?
    var name: String
    var category: ManualAssetCategory
    var currency: Currency
    var currentValue: Decimal
    var costBasis: Decimal?
    var purchaseDate: Date?
    var notes: String
    var isIncludedInTotalAssets: Bool
    var isIncludedInInvestments: Bool

    init(
        id: String? = nil,
        name: String = "",
        category: ManualAssetCategory = .other,
        currency: Currency = .TWD,
        currentValue: Decimal = 0,
        costBasis: Decimal? = nil,
        purchaseDate: Date? = nil,
        notes: String = "",
        isIncludedInTotalAssets: Bool = true,
        isIncludedInInvestments: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.currency = currency
        self.currentValue = currentValue
        self.costBasis = costBasis
        self.purchaseDate = purchaseDate
        self.notes = notes
        self.isIncludedInTotalAssets = isIncludedInInvestments ? true : isIncludedInTotalAssets
        self.isIncludedInInvestments = isIncludedInInvestments
    }

    @MainActor
    static func emptyWithBaseCurrency() -> ManualAssetFormState {
        ManualAssetFormState(currency: BaseCurrencyManager.shared.baseCurrency)
    }

    init(asset: ManualAsset) {
        self.init(
            id: asset.id,
            name: asset.name,
            category: asset.category,
            currency: asset.currency,
            currentValue: asset.currentValue,
            costBasis: asset.costBasis,
            purchaseDate: asset.purchaseDate,
            notes: asset.notes ?? "",
            isIncludedInTotalAssets: asset.isIncludedInTotalAssets,
            isIncludedInInvestments: asset.isIncludedInInvestments
        )
    }

    var normalized: ManualAssetFormState {
        ManualAssetFormState(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            currency: currency,
            currentValue: currentValue,
            costBasis: costBasis,
            purchaseDate: purchaseDate,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            isIncludedInTotalAssets: isIncludedInInvestments ? true : isIncludedInTotalAssets,
            isIncludedInInvestments: isIncludedInInvestments
        )
    }

    func makeAsset(userId: String, existing: ManualAsset? = nil) throws -> ManualAsset {
        let state = normalized
        try state.validate()
        let now = Date()
        let valueChanged = existing?.currentValue != state.currentValue
        return ManualAsset(
            id: existing?.id ?? state.id ?? UUID().uuidString,
            userId: existing?.userId ?? userId,
            name: state.name,
            category: state.category,
            currency: state.currency,
            currentValue: state.currentValue,
            costBasis: state.costBasis,
            purchaseDate: state.purchaseDate,
            notes: state.notes.isEmpty ? nil : state.notes,
            isIncludedInTotalAssets: state.isIncludedInTotalAssets,
            isIncludedInInvestments: state.isIncludedInInvestments,
            currentValueUpdatedAt: valueChanged ? now : (existing?.currentValueUpdatedAt ?? now),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )
    }

    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ManualAssetFormValidationError.nameRequired
        }
        if currentValue < 0 {
            throw ManualAssetFormValidationError.currentValueCannotBeNegative
        }
        if let costBasis, costBasis < 0 {
            throw ManualAssetFormValidationError.costBasisCannotBeNegative
        }
        if isIncludedInInvestments {
            guard let costBasis, costBasis > 0 else {
                throw ManualAssetFormValidationError.investmentCostBasisRequired
            }
        }
    }
}

enum ManualAssetFormValidationError: LocalizedError, Equatable {
    case nameRequired
    case currentValueCannotBeNegative
    case costBasisCannotBeNegative
    case investmentCostBasisRequired
    case assetNotFound
    case duplicateNameInCategory

    var errorDescription: String? {
        switch self {
        case .nameRequired:
            return "請輸入資產名稱"
        case .currentValueCannotBeNegative:
            return "現值不能小於 0"
        case .costBasisCannotBeNegative:
            return "成本不能小於 0"
        case .investmentCostBasisRequired:
            return "納入投資時，請填寫大於 0 的成本，才能計算損益與報酬率。"
        case .assetNotFound:
            return "找不到要更新的其他資產"
        case .duplicateNameInCategory:
            return "此類別已有相同名稱的其他資產"
        }
    }
}

@MainActor
final class ManualAssetsViewModel: ObservableObject {
    @Published private(set) var assets: [ManualAsset] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let dataService: DataServiceProtocol
    private let priceService: PriceServiceProtocol?

    init(
        dataService: DataServiceProtocol? = nil,
        priceService: PriceServiceProtocol? = nil
    ) {
        self.dataService = dataService ?? MockDataService.shared
        self.priceService = priceService
    }

    func loadAssets(userId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            assets = try await dataService.fetchManualAssets(userId: userId)
                .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = "載入其他資產失敗：\(error.localizedDescription)"
        }
    }

    @discardableResult
    func createAsset(
        from formState: ManualAssetFormState,
        userId: String,
        showsLoadingOverlay: Bool = true
    ) async -> Bool {
        await saveMutation(userId: userId, showsLoadingOverlay: showsLoadingOverlay) {
            let asset = try formState.makeAsset(userId: userId)
            try await validateUniqueName(asset)
            try await dataService.createManualAsset(asset)
            try await dataService.saveManualAssetValuation(
                ManualAssetValuation(
                    userId: asset.userId,
                    manualAssetId: asset.id,
                    value: asset.currentValue,
                    currency: asset.currency,
                    valuationDate: asset.createdAt,
                    notes: ManualAssetValuation.creationRecordNote,
                    createdAt: asset.createdAt
                )
            )
        }
    }

    @discardableResult
    func updateAsset(
        id: String,
        formState: ManualAssetFormState,
        userId: String,
        showsLoadingOverlay: Bool = true,
        syncCreationValuation: Bool = false
    ) async -> Bool {
        await saveMutation(userId: userId, showsLoadingOverlay: showsLoadingOverlay) {
            let existing = assets.first(where: { $0.id == id })
            let persistedAssets = try await dataService.fetchManualAssets(userId: userId)
            let persisted = persistedAssets.first { $0.id == id }
            guard let assetToUpdate = existing ?? persisted else {
                throw ManualAssetFormValidationError.assetNotFound
            }
            let asset = try formState.makeAsset(userId: userId, existing: assetToUpdate)
            try await validateUniqueName(asset, excludingAssetId: id)
            try await dataService.updateManualAsset(asset)
            if syncCreationValuation {
                try await upsertCreationValuation(for: asset)
                try await syncCurrentValueFromLatestValuation(asset: asset)
            }
        }
    }

    @discardableResult
    func deleteAsset(
        id: String,
        userId: String,
        showsLoadingOverlay: Bool = true
    ) async -> Bool {
        await saveMutation(userId: userId, showsLoadingOverlay: showsLoadingOverlay) {
            try await dataService.deleteManualAsset(id)
        }
    }

    @discardableResult
    func updateCurrentValue(
        asset: ManualAsset,
        currentValue: Decimal,
        valuationDate: Date,
        notes: String?,
        showsLoadingOverlay: Bool = true
    ) async -> Bool {
        await saveMutation(userId: asset.userId, showsLoadingOverlay: showsLoadingOverlay) {
            var updatedAsset = asset
            updatedAsset.currentValue = currentValue
            updatedAsset.currentValueUpdatedAt = valuationDate
            updatedAsset.updatedAt = Date()
            try await dataService.updateManualAsset(updatedAsset)
            try await dataService.saveManualAssetValuation(
                ManualAssetValuation(
                    userId: asset.userId,
                    manualAssetId: asset.id,
                    value: currentValue,
                    currency: asset.currency,
                    valuationDate: valuationDate,
                    notes: notes
                )
            )
        }
    }

    @discardableResult
    func updateManualAssetValuation(
        asset: ManualAsset,
        valuation: ManualAssetValuation,
        value: Decimal,
        valuationDate: Date,
        notes: String?,
        showsLoadingOverlay: Bool = true
    ) async -> Bool {
        await saveMutation(userId: asset.userId, showsLoadingOverlay: showsLoadingOverlay) {
            try await dataService.saveManualAssetValuation(
                ManualAssetValuation(
                    id: valuation.id,
                    userId: valuation.userId,
                    manualAssetId: valuation.manualAssetId,
                    value: value,
                    currency: valuation.currency,
                    valuationDate: valuationDate,
                    notes: notes,
                    createdAt: valuation.createdAt
                )
            )
            try await syncCurrentValueFromLatestValuation(asset: asset)
        }
    }

    @discardableResult
    func deleteManualAssetValuation(
        asset: ManualAsset,
        valuation: ManualAssetValuation,
        showsLoadingOverlay: Bool = true
    ) async -> Bool {
        await saveMutation(userId: asset.userId, showsLoadingOverlay: showsLoadingOverlay) {
            guard valuation.notes != ManualAssetValuation.creationRecordNote else {
                throw DataServiceError.invalidOperation("建立紀錄不能單獨刪除，請刪除此其他資產。")
            }
            try await dataService.deleteManualAssetValuation(valuation.id)
            try await syncCurrentValueFromLatestValuation(asset: asset)
        }
    }

    private func saveMutation(
        userId: String,
        showsLoadingOverlay: Bool,
        operation: () async throws -> Void
    ) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        errorMessage = nil
        if showsLoadingOverlay {
            NotificationCenter.default.post(name: .portfolioMutationRefreshBegan, object: nil)
        }
        defer {
            isSaving = false
            if showsLoadingOverlay {
                NotificationCenter.default.post(name: .portfolioMutationRefreshEnded, object: nil)
            }
        }

        do {
            try await operation()
            let refreshed = await SnapshotRefreshCoordinator.rebuildAndNotify(
                userId: userId,
                dataService: dataService,
                priceService: priceService,
                syncPortfolio: false,
                updatePriceMetadata: false,
                deferRemoteWork: false,
                postsUpdateNotification: true
            )
            await loadAssets(userId: userId)
            if !refreshed {
                errorMessage = "其他資產已儲存，但重新整理資產快照失敗"
            }
            return refreshed
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func validateUniqueName(_ asset: ManualAsset, excludingAssetId: String? = nil) async throws {
        let existingAssets = try await dataService.fetchManualAssets(userId: asset.userId)
        let normalizedName = asset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDuplicate = existingAssets.contains { existing in
            if let excludingAssetId, existing.id == excludingAssetId {
                return false
            }
            return existing.category == asset.category
                && existing.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare(normalizedName) == .orderedSame
        }
        if isDuplicate {
            throw ManualAssetFormValidationError.duplicateNameInCategory
        }
    }

    private func upsertCreationValuation(for asset: ManualAsset) async throws {
        let valuations = try await dataService.fetchManualAssetValuations(assetId: asset.id)
        if let existing = valuations.first(where: { $0.notes == ManualAssetValuation.creationRecordNote }) {
            try await dataService.saveManualAssetValuation(
                ManualAssetValuation(
                    id: existing.id,
                    userId: existing.userId,
                    manualAssetId: existing.manualAssetId,
                    value: asset.currentValue,
                    currency: asset.currency,
                    valuationDate: asset.createdAt,
                    notes: ManualAssetValuation.creationRecordNote,
                    createdAt: existing.createdAt
                )
            )
        } else {
            try await dataService.saveManualAssetValuation(
                ManualAssetValuation(
                    userId: asset.userId,
                    manualAssetId: asset.id,
                    value: asset.currentValue,
                    currency: asset.currency,
                    valuationDate: asset.createdAt,
                    notes: ManualAssetValuation.creationRecordNote,
                    createdAt: asset.createdAt
                )
            )
        }
    }

    private func syncCurrentValueFromLatestValuation(asset: ManualAsset) async throws {
        let latest = try await dataService.fetchManualAssetValuations(assetId: asset.id)
            .sorted { lhs, rhs in
                if lhs.valuationDate == rhs.valuationDate {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.valuationDate > rhs.valuationDate
            }
            .first
        guard let latest else { return }
        var updatedAsset = asset
        updatedAsset.currentValue = latest.value
        updatedAsset.currency = latest.currency
        updatedAsset.currentValueUpdatedAt = latest.valuationDate
        updatedAsset.updatedAt = Date()
        try await dataService.updateManualAsset(updatedAsset)
    }
}
