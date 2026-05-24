//
//  ImportPreviewRowView.swift
//  Snapvest
//
//  匯入預覽列（沿用交易紀錄卡片樣式，可點擊進買賣表單）
//

import SwiftUI

struct ImportPreviewRowView: View {
    let row: TransactionImportValidatedRow
    var onTap: (() -> Void)?
    
    private var isEditableTrade: Bool {
        guard !row.isSkipped, let type = row.transaction?.type else { return false }
        return type == .buy || type == .sell
    }
    
    var body: some View {
        Group {
            if let transaction = row.transaction {
                tradeRow(transaction)
            } else {
                errorOnlyRow
            }
        }
    }
    
    private func tradeRow(_ transaction: Transaction) -> some View {
        let display = TransactionDisplayFormatter(transaction: transaction)
        let accentColor = row.isSkipped ? Color.secondaryText : display.typeAccentColor
        let content = HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(display.primaryTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .lineLimit(2)
                
                if let detail = display.tradeDetailLine {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                } else if !display.accountHistorySubtitle.isEmpty {
                    Text(display.accountHistorySubtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
                
                if let error = row.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.lossRed)
                } else if let skipReason = row.skipReason {
                    Text(skipReason)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            
            Spacer(minLength: 8)
            
            VStack(alignment: .trailing, spacing: 4) {
                if let amount = display.tradeTotalAmountText {
                    Text(amount)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                Text(transaction.transactionDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                if isEditableTrade {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .contentShape(Rectangle())
        
        return Group {
            if isEditableTrade, let onTap {
                Button(action: onTap) {
                    previewCard(accentColor: accentColor) {
                        content
                    }
                }
                .buttonStyle(.plain)
            } else {
                previewCard(accentColor: accentColor) {
                    content
                }
            }
        }
    }
    
    private var errorOnlyRow: some View {
        previewCard(accentColor: .lossRed) {
            VStack(alignment: .leading, spacing: 6) {
                Text("第 \(row.lineNumber) 列無法匯入")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                if let error = row.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.lossRed)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private func previewCard<C: View>(
        accentColor: Color,
        @ViewBuilder content: () -> C
    ) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor)
                    .frame(width: 4)
            }
            .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
    }
}
