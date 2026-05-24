//
//  TransactionDisplayFormatter.swift
//  Snapvest
//
//  交易列顯示邏輯（自紀錄分頁 TransactionRowView 複製，供多處共用）
//

import SwiftUI

struct TransactionDisplayFormatter {
    let transaction: Transaction
    
    // MARK: - 標題
    
    var primaryTitle: String {
        switch transaction.type {
        case .buy:
            return "買入 \(tradeTitleSuffix)"
        case .sell:
            return "賣出 \(tradeTitleSuffix)"
        case .transfer:
            return "轉帳"
        case .repayment:
            return "還款"
        case .deposit:
            return "收入"
        case .withdraw:
            return "支出"
        case .dividend:
            return "股利"
        case .fee:
            return "手續費"
        case .liability:
            return "債務"
        }
    }
    
    // MARK: - 副標
    
    /// 紀錄分頁：帳戶名 · 交易明細 · 備註 preview
    func detailSubtitle(accountName: String) -> String {
        var parts: [String] = [accountName]
        if let tradeLine = tradeDetailLine {
            parts.append(tradeLine)
        }
        if let note = userNotePreview {
            parts.append(note)
        }
        return parts.joined(separator: " · ")
    }
    
    /// 帳戶交易紀錄：不含帳戶名
    var accountHistorySubtitle: String {
        var parts: [String] = []
        if let tradeLine = tradeDetailLine {
            parts.append(tradeLine)
        }
        if let note = userNotePreview {
            parts.append(note)
        }
        return parts.joined(separator: " · ")
    }
    
    var tradeDetailLine: String? {
        guard transaction.type == .buy || transaction.type == .sell else { return nil }
        let qty = Self.formatQuantity(transaction.quantity)
        let price = transaction.price.formattedTradePrice(currency: tradePriceCurrency)
        return "\(qty) 股 @ \(price)"
    }
    
    /// 買賣成交價幣別（美股／加密貨幣以 USD 顯示，與交易表單一致）
    var tradePriceCurrency: Currency {
        switch transaction.assetType {
        case .stockUS, .crypto:
            return .USD
        case .stockTW:
            return .TWD
        case .cash:
            return transaction.currency
        }
    }
    
    /// 匯入預覽右側：成交金額（交易幣別）
    var tradeTotalAmountText: String? {
        guard transaction.type == .buy || transaction.type == .sell else { return nil }
        let total = transaction.quantity * transaction.price
        return total.formattedTradeAmount(currency: tradePriceCurrency)
    }
    
    /// 過濾系統自動備註，只保留使用者自訂內容 preview
    var userNotePreview: String? {
        guard let raw = transaction.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        if transaction.type == .buy || transaction.type == .sell {
            if raw.contains("自訂備註：") {
                return raw.components(separatedBy: "自訂備註：").last?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if raw.hasPrefix("買入") || raw.hasPrefix("賣出") { return nil }
        }
        return raw
    }
    
    // MARK: - 展開明細
    
    var expandedNotes: String? {
        let userNote = transaction.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasUserNote = !(userNote?.isEmpty ?? true)
        
        if transaction.type == .buy || transaction.type == .sell {
            let action = transaction.type == .buy ? "買入" : "賣出"
            let name = tradeDisplayName
            let quantityText = Self.formatQuantity(transaction.quantity)
            let priceText = transaction.price.formattedTradePrice(currency: transaction.currency)
            let autoNote = "\(action)\(quantityText)股\(name)，股價\(priceText)"
            
            if hasUserNote {
                return "\(autoNote)\n自訂備註：\(userNote!)"
            }
            return autoNote
        }
        
        if hasUserNote {
            return userNote
        }
        return nil
    }
    
    /// 有自訂備註時可展開完整明細（紀錄分頁、帳戶交易紀錄共用）
    var shouldShowExpandedDetail: Bool {
        expandedNotes != nil && userNotePreview != nil
    }
    
    // MARK: - 樣式
    
    var typeAccentColor: Color {
        switch transaction.type {
        case .transfer:
            return .appPrimary
        case .repayment:
            return .lossRed
        case .buy:
            return .lossRed
        case .sell:
            return .profitGreen
        case .deposit, .dividend:
            return .profitGreen
        case .withdraw, .fee, .liability:
            return .lossRed
        }
    }
    
    // MARK: - Private
    
    private var tradeTitleSuffix: String {
        let name = tradeDisplayName
        if transaction.assetType == .stockTW, name != transaction.symbol {
            return "\(name) \(transaction.symbol)"
        }
        return name
    }
    
    private var tradeDisplayName: String {
        if transaction.assetType == .stockTW {
            return SymbolListService.twDisplayName(for: transaction.symbol) ?? transaction.symbol
        }
        return transaction.symbol
    }
    
    private static func formatQuantity(_ quantity: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.usesGroupingSeparator = true
        return formatter.string(from: quantity as NSDecimalNumber) ?? "\(quantity)"
    }
}
