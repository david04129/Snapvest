//
//  TransactionHistoryPreviewSection.swift
//  Snapvest
//
//  帳戶詳情內嵌交易紀錄預覽（對齊其他資產現值紀錄預覽）。
//

import SwiftUI

struct TransactionHistoryPreviewSection: View {
    let account: Account
    let transactions: [Transaction]
    let isLoading: Bool
    let accentColor: Color
    let balanceAfter: (Transaction) -> Decimal
    let onRowTap: (Transaction) -> Void
    let onDelete: (Transaction) -> Void
    let onViewAll: () -> Void

    private static let previewLimit = 4

    private var previewTransactions: [Transaction] {
        Array(transactions.prefix(Self.previewLimit))
    }

    var body: some View {
        AccountSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("交易紀錄")
                        .font(.headline)
                        .foregroundColor(.primaryText)

                    Spacer(minLength: 8)

                    if !transactions.isEmpty {
                        Text("共 \(transactions.count) 筆")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondaryText)
                    }
                }

                if isLoading && transactions.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("載入中…")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                } else if transactions.isEmpty {
                    Text("尚無交易紀錄。可透過「調整餘額」或收入／支出建立紀錄。")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    DetailPreviewMeasuredList(rowIDs: previewTransactions.map(\.id)) {
                        ForEach(previewTransactions) { transaction in
                            TransactionHistoryRowView(
                                transaction: transaction,
                                accountId: account.id,
                                accountCurrency: account.currency,
                                balance: balanceAfter(transaction),
                                onRowTap: { onRowTap(transaction) },
                                onDelete: { _ in onDelete(transaction) }
                            )
                            .detailPreviewListRowStyle()
                            .detailPreviewMeasureRowHeight(id: transaction.id)
                        }
                    }

                    if transactions.count > Self.previewLimit {
                        viewAllButton(title: "查看全部 \(transactions.count) 筆")
                    } else if transactions.count > 1 {
                        viewAllButton(title: "查看完整列表")
                    }
                }
            }
        }
    }

    private func viewAllButton(title: String) -> some View {
        Button(action: onViewAll) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(accentColor)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 詳情內嵌 List（供 swipeActions 使用）

enum DetailPreviewListMetrics {
    static let fallbackRowHeight: CGFloat = 96
    /// listRowInsets top 5 + bottom 5（GeometryReader 量到的是內容區，需補列間距）
    static let listRowVerticalInset: CGFloat = 10
}

private struct DetailPreviewRowHeightKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: max)
    }
}

/// 依實際列高縮放 List，避免固定高度造成裁切或底部留白。
struct DetailPreviewMeasuredList<Content: View>: View {
    let rowIDs: [String]
    @ViewBuilder let content: () -> Content

    @State private var measuredHeight: CGFloat = 0

    private var listHeight: CGFloat {
        if measuredHeight > 0 { return measuredHeight }
        return CGFloat(max(rowIDs.count, 1)) * DetailPreviewListMetrics.fallbackRowHeight
    }

    var body: some View {
        List {
            content()
        }
        .detailPreviewListStyle(height: listHeight)
        .onPreferenceChange(DetailPreviewRowHeightKey.self) { heights in
            let contentTotal = rowIDs.compactMap { heights[$0] }.reduce(0, +)
            guard contentTotal > 0 else { return }
            let insetTotal = CGFloat(rowIDs.count) * DetailPreviewListMetrics.listRowVerticalInset
            let total = contentTotal + insetTotal
            guard abs(total - measuredHeight) > 0.5 else { return }
            measuredHeight = total
        }
        .onChange(of: rowIDs) { _, _ in
            measuredHeight = 0
        }
    }
}

extension View {
    func detailPreviewListRowStyle() -> some View {
        listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
            .listRowBackground(Color.clear)
    }

    func detailPreviewMeasureRowHeight(id: String) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: DetailPreviewRowHeightKey.self,
                    value: [id: geometry.size.height]
                )
            }
        }
    }

    func detailPreviewListStyle(height: CGFloat) -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .environment(\.defaultMinListRowHeight, 1)
            .frame(height: height)
    }
}
