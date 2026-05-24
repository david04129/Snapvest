//
//  ImportDuplicateRowView.swift
//  Snapvest
//
//  匯入預覽：可能重複的交易列（預設略過，可改為仍要匯入）
//

import SwiftUI

struct ImportDuplicateRowView: View {
    let row: TransactionImportValidatedRow
    let match: TransactionDuplicateMatch
    let importDespiteDuplicate: Bool
    var onTap: (() -> Void)?
    var onToggleImport: (Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let transaction = row.transaction {
                duplicateTradeContent(transaction)
            }
            
            duplicateActionBar
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
    }
    
    private func duplicateTradeContent(_ transaction: Transaction) -> some View {
        let display = TransactionDisplayFormatter(transaction: transaction)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(display.primaryTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                Text("第 \(row.lineNumber) 列")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            if let detail = display.tradeDetailLine {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Text(match.detailMessage)
                .font(.caption)
                .foregroundColor(.orange)
            
            Text("既有：\(TransactionDuplicateChecker.summary(for: match.referenceTransaction))")
                .font(.caption)
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            if onTap != nil {
                Button {
                    onTap?()
                } label: {
                    Label("編輯", systemImage: "pencil")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.appPrimary)
            }
        }
    }
    
    private var duplicateActionBar: some View {
        HStack(spacing: 10) {
            Button {
                onToggleImport(false)
            } label: {
                Text("略過")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(importDespiteDuplicate ? .secondaryText : .orange)
            .background(importDespiteDuplicate ? Color.clear : Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button {
                onToggleImport(true)
            } label: {
                Text("仍要匯入")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(importDespiteDuplicate ? .orange : .secondaryText)
            .background(importDespiteDuplicate ? Color.orange.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
