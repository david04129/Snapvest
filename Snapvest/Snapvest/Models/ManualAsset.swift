//
//  ManualAsset.swift
//  Snapvest
//
//  Local-only models for assets without public market prices.
//

import Foundation

enum ManualAssetCategory: String, Codable, CaseIterable, Identifiable {
    case fund
    case bond
    case realEstate
    case insurance
    case collectible
    case preciousMetal
    case retirement
    case privateEquity
    case employeeEquity
    case receivable
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fund: return "基金"
        case .bond: return "債券"
        case .realEstate: return "房地產"
        case .insurance: return "保單"
        case .collectible: return "收藏品"
        case .preciousMetal: return "貴金屬"
        case .retirement: return "退休金"
        case .privateEquity: return "私募 / 股權"
        case .employeeEquity: return "員工股票 / 選擇權"
        case .receivable: return "應收款"
        case .other: return "其他"
        }
    }
}

struct ManualAsset: Identifiable, Codable, Equatable {
    let id: String
    var userId: String
    var name: String
    var category: ManualAssetCategory
    var currency: Currency
    var currentValue: Decimal
    var costBasis: Decimal?
    var purchaseDate: Date?
    var notes: String?
    var isIncludedInTotalAssets: Bool
    var isIncludedInInvestments: Bool
    var currentValueUpdatedAt: Date
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        category: ManualAssetCategory,
        currency: Currency,
        currentValue: Decimal,
        costBasis: Decimal? = nil,
        purchaseDate: Date? = nil,
        notes: String? = nil,
        isIncludedInTotalAssets: Bool = true,
        isIncludedInInvestments: Bool = false,
        currentValueUpdatedAt: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.category = category
        self.currency = currency
        self.currentValue = currentValue
        self.costBasis = costBasis
        self.purchaseDate = purchaseDate
        self.notes = notes
        self.isIncludedInTotalAssets = isIncludedInInvestments ? true : isIncludedInTotalAssets
        self.isIncludedInInvestments = isIncludedInInvestments
        self.currentValueUpdatedAt = currentValueUpdatedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(ManualAssetCategory.self, forKey: .category)
        currency = try container.decode(Currency.self, forKey: .currency)
        currentValue = try container.decode(Decimal.self, forKey: .currentValue)
        costBasis = try container.decodeIfPresent(Decimal.self, forKey: .costBasis)
        purchaseDate = try container.decodeIfPresent(Date.self, forKey: .purchaseDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        let decodedInvestments = try container.decodeIfPresent(Bool.self, forKey: .isIncludedInInvestments) ?? false
        isIncludedInTotalAssets = decodedInvestments
            ? true
            : (try container.decodeIfPresent(Bool.self, forKey: .isIncludedInTotalAssets) ?? true)
        isIncludedInInvestments = decodedInvestments
        currentValueUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .currentValueUpdatedAt) ?? Date()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

struct ManualAssetValuation: Identifiable, Codable, Equatable {
    let id: String
    var userId: String
    var manualAssetId: String
    var value: Decimal
    var currency: Currency
    var valuationDate: Date
    var notes: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        manualAssetId: String,
        value: Decimal,
        currency: Currency,
        valuationDate: Date = Date(),
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.manualAssetId = manualAssetId
        self.value = value
        self.currency = currency
        self.valuationDate = valuationDate
        self.notes = notes
        self.createdAt = createdAt
    }
}
