//
//  HoldingsCompareParser.swift
//  Snapvest
//
//  解析使用者貼上的持倉對照表（symbol, quantity）。
//

import Foundation

struct HoldingsCompareEntry: Equatable {
    let assetType: AssetType?
    let symbol: String
    let quantity: Decimal
}

struct HoldingsCompareDiff: Identifiable, Equatable {
    let symbol: String
    let projected: Decimal?
    let stated: Decimal?
    
    var id: String { symbol }
    
    var matches: Bool {
        guard let projected, let stated else { return false }
        return projected == stated
    }
}

enum HoldingsCompareParser {
    /// 解析 `symbol,quantity` 或含標題列；asset_type 可選。
    static func parse(_ text: String, defaultAssetType: AssetType?) -> [HoldingsCompareEntry] {
        let cleaned = TransactionImportCSVParser.sanitizePastedText(text)
        guard !cleaned.isEmpty else { return [] }
        
        let lines = cleaned
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else { return [] }
        
        var startIndex = 0
        if let first = lines.first?.lowercased(),
           first.contains("symbol") || first.contains("代號") || first.contains("quantity") || first.contains("數量") {
            startIndex = 1
        }
        
        var entries: [HoldingsCompareEntry] = []
        for line in lines.dropFirst(startIndex) {
            let fields = splitFields(line)
            guard fields.count >= 2 else { continue }
            
            let assetType: AssetType?
            let symbolIndex: Int
            let qtyIndex: Int
            
            if fields.count >= 3, let type = AssetType(rawValue: fields[0].lowercased()) {
                assetType = type
                symbolIndex = 1
                qtyIndex = 2
            } else {
                assetType = defaultAssetType
                symbolIndex = 0
                qtyIndex = 1
            }
            
            let symbol = fields[symbolIndex].trimmingCharacters(in: .whitespaces)
            guard !symbol.isEmpty, let qty = Decimal(string: fields[qtyIndex].replacingOccurrences(of: ",", with: "")),
                  qty >= 0 else { continue }
            
            entries.append(HoldingsCompareEntry(assetType: assetType, symbol: symbol, quantity: qty))
        }
        return entries
    }
    
    static func compare(
        projected: [ImportProjectedHolding],
        stated: [HoldingsCompareEntry],
        account: Account
    ) -> [HoldingsCompareDiff] {
        func normalizeKey(assetType: AssetType, symbol: String) -> String {
            let type = assetType
            let sym: String
            switch type {
            case .crypto:
                sym = SymbolListService.normalizedCryptoSymbol(symbol)
            case .stockUS:
                sym = symbol.uppercased()
            default:
                sym = symbol
            }
            return "\(type.rawValue)_\(sym)"
        }
        
        func inferredType(for entry: HoldingsCompareEntry) -> AssetType {
            if let t = entry.assetType { return t }
            switch account.accountType {
            case .usdAccount:
                return .stockUS
            case .twdSecurities:
                return entry.symbol.allSatisfy(\.isNumber) ? .stockTW : .stockUS
            default:
                return .stockTW
            }
        }
        
        var projectedMap: [String: Decimal] = [:]
        for item in projected {
            projectedMap[normalizeKey(assetType: item.assetType, symbol: item.symbol)] = item.quantity
        }
        
        var statedMap: [String: Decimal] = [:]
        for entry in stated {
            let type = inferredType(for: entry)
            statedMap[normalizeKey(assetType: type, symbol: entry.symbol)] = entry.quantity
        }
        
        let allKeys = Set(projectedMap.keys).union(statedMap.keys)
        return allKeys.sorted().map { key in
            let symbol = key.split(separator: "_", maxSplits: 1).dropFirst().first.map(String.init) ?? key
            return HoldingsCompareDiff(
                symbol: symbol,
                projected: projectedMap[key],
                stated: statedMap[key]
            )
        }
    }
    
    private static func splitFields(_ line: String) -> [String] {
        if line.contains("\t") {
            return line.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
