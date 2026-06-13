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
        let qty = formatQuantity(transaction.quantity)
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

    func displayAmount(
        accountCurrency: Currency?,
        usdToTwdRate: Decimal? = nil
    ) -> (amount: Decimal, currency: Currency) {
        let targetCurrency = accountCurrency ?? transaction.currency
        guard transaction.type == .buy || transaction.type == .sell else {
            return (transaction.totalAmountWithFee, transaction.currency)
        }

        let gross = transaction.quantity * transaction.price
        let amountInTradeCurrency: Decimal
        switch transaction.type {
        case .buy:
            amountInTradeCurrency = gross + transaction.fee
        case .sell:
            amountInTradeCurrency = gross - transaction.fee
        default:
            amountInTradeCurrency = gross
        }

        if let converted = convertedAmount(
            amountInTradeCurrency,
            from: tradePriceCurrency,
            to: targetCurrency,
            rate: transaction.exchangeRate ?? usdToTwdRate
        ) {
            return (converted, targetCurrency)
        }
        return (amountInTradeCurrency, tradePriceCurrency)
    }

    func displayRealizedGainLoss(
        accountCurrency: Currency?,
        usdToTwdRate: Decimal? = nil
    ) -> (amount: Decimal, currency: Currency)? {
        guard let realized = transaction.realizedGainLoss else { return nil }
        let targetCurrency = accountCurrency ?? transaction.currency
        if let converted = convertedAmount(
            realized,
            from: tradePriceCurrency,
            to: targetCurrency,
            rate: transaction.exchangeRate ?? usdToTwdRate
        ) {
            return (converted, targetCurrency)
        }
        return (realized, tradePriceCurrency)
    }

    private func convertedAmount(
        _ amount: Decimal,
        from sourceCurrency: Currency,
        to targetCurrency: Currency,
        rate: Decimal?
    ) -> Decimal? {
        if sourceCurrency == targetCurrency { return amount }
        guard let rate, rate > 0 else { return nil }
        if sourceCurrency == .USD, targetCurrency == .TWD {
            return amount * rate
        }
        if sourceCurrency == .TWD, targetCurrency == .USD {
            return amount / rate
        }
        return nil
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
            let quantityText = formatQuantity(transaction.quantity)
            let priceText = transaction.price.formattedTradePrice(currency: tradePriceCurrency)
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
    
    // MARK: - 已實現損益明細（首頁）
    
    var realizedQuantityText: String {
        transaction.quantity.formattedQuantityInput(
            maxFractionDigits: transaction.assetType == .crypto ? 8 : 4
        )
    }
    
    var realizedCostPerUnitText: String? {
        transaction.realizedCostPerUnit.map {
            $0.formattedTradePrice(currency: tradePriceCurrency)
        }
    }
    
    var realizedSellPriceText: String {
        transaction.price.formattedTradePrice(currency: tradePriceCurrency)
    }
    
    var realizedGainLossText: String? {
        guard let realized = transaction.realizedGainLoss else { return nil }
        switch transaction.currency {
        case .TWD:
            return realized.formatted(currency: .TWD)
        case .USD:
            return realized.formattedTradeAmount(currency: .USD)
        default:
            return realized.formatted(currency: transaction.currency)
        }
    }
    
    var realizedGainLossPercentText: String? {
        guard let percent = transaction.realizedGainLossPercent else { return nil }
        return "(\(percent.formattedPercentValue(maxFractionDigits: 1))%)"
    }
    
    // MARK: - 樣式
    
    var typeAccentColor: Color {
        switch transaction.type {
        case .repayment:
            return .lossRed
        case .buy:
            return transaction.deductFromAccount == true ? .lossRed : .profitGreen
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
        switch transaction.assetType {
        case .stockTW:
            return SymbolListService.twDisplayName(for: transaction.symbol) ?? transaction.symbol
        case .crypto:
            return SymbolListService.cryptoDisplayName(
                for: transaction.symbol,
                storedName: transaction.buySymbolNameFromNotes
            )
        case .stockUS:
            return transaction.symbol.uppercased()
        default:
            return transaction.symbol
        }
    }
    
    private func formatQuantity(_ quantity: Decimal) -> String {
        quantity.formattedQuantityInput(
            maxFractionDigits: transaction.assetType == .crypto ? 8 : 4
        )
    }
}
