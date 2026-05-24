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
    var onRemove: (() -> Void)? = nil
    
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
        let accentColor: Color = {
            if row.errorMessage != nil { return .lossRed }
            if row.isSkipped { return .secondaryText }
            return display.typeAccentColor
        }()
        let content = VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(display.primaryTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                            .lineLimit(2)
                        if row.errorMessage != nil {
                            Text("第 \(row.lineNumber) 列")
                                .font(.caption2)
                                .foregroundColor(.lossRed)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.lossRed.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    
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
                            .fixedSize(horizontal: false, vertical: true)
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
                    
                    if isEditableTrade, onTap != nil, row.errorMessage == nil {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            
            if onRemove != nil || (isEditableTrade && onTap != nil && row.errorMessage != nil) {
                errorActionBar
            }
        }
        .contentShape(Rectangle())
        
        return Group {
            if isEditableTrade, let onTap, row.errorMessage == nil {
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
    
    private var errorActionBar: some View {
        HStack(spacing: 12) {
            if isEditableTrade, let onTap, row.errorMessage != nil {
                Button {
                    onTap()
                } label: {
                    Label("編輯", systemImage: "pencil")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.appPrimary)
            }
            
            Spacer()
            
            if let onRemove {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("移除此筆", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var errorOnlyRow: some View {
        previewCard(accentColor: .lossRed) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("第 \(row.lineNumber) 列無法匯入")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    if let error = row.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.lossRed)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                if let onRemove {
                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            onRemove()
                        } label: {
                            Label("移除此筆", systemImage: "trash")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                    }
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
