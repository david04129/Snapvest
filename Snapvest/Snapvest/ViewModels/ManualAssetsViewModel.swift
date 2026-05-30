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
    }
}

enum ManualAssetFormValidationError: LocalizedError, Equatable {
    case nameRequired
    case currentValueCannotBeNegative
    case costBasisCannotBeNegative
    case assetNotFound

    var errorDescription: String? {
        switch self {
        case .nameRequired:
            return "請輸入資產名稱"
        case .currentValueCannotBeNegative:
            return "現值不能小於 0"
        case .costBasisCannotBeNegative:
            return "成本不能小於 0"
        case .assetNotFound:
            return "找不到要更新的手動資產"
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
            errorMessage = "載入手動資產失敗：\(error.localizedDescription)"
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
            try await dataService.createManualAsset(asset)
        }
    }

    @discardableResult
    func updateAsset(
        id: String,
        formState: ManualAssetFormState,
        userId: String,
        showsLoadingOverlay: Bool = true
    ) async -> Bool {
        await saveMutation(userId: userId, showsLoadingOverlay: showsLoadingOverlay) {
            let existing = assets.first(where: { $0.id == id })
            let persistedAssets = try await dataService.fetchManualAssets(userId: userId)
            let persisted = persistedAssets.first { $0.id == id }
            guard let assetToUpdate = existing ?? persisted else {
                throw ManualAssetFormValidationError.assetNotFound
            }
            let asset = try formState.makeAsset(userId: userId, existing: assetToUpdate)
            try await dataService.updateManualAsset(asset)
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
                errorMessage = "手動資產已儲存，但重新整理資產快照失敗"
            }
            return refreshed
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
