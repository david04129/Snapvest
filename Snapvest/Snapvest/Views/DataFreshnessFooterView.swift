//
//  DataFreshnessFooterView.swift
//  Snapvest
//
//  Phase 5：各 Tab 底部顯示資料更新時間。
//

import SwiftUI

enum DataFreshnessFooterStyle {
    /// 首頁／帳戶／資產：股價與估值快照
    case valuationTabs
    /// 紀錄：結構快照 A
    case transactions
}

struct DataFreshnessFooterView: View {
    @EnvironmentObject private var freshness: DataFreshnessStore
    let style: DataFreshnessFooterStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch style {
            case .valuationTabs:
                freshnessLine(title: "股價來源（DB）", date: freshness.snapshot.priceSourceUpdatedAt)
                freshnessLine(title: "本機同步", date: freshness.snapshot.priceSyncedAt)
                freshnessLine(title: "估值快照", date: freshness.snapshot.valuationUpdatedAt)
                
                if freshness.snapshot.isPriceStale {
                    Text("後端股價較新，尚未同步至本機")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            case .transactions:
                freshnessLine(title: "交易資料", date: freshness.snapshot.structureUpdatedAt)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .onAppear {
            freshness.refresh()
        }
    }
    
    private func freshnessLine(title: String, date: Date?) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundColor(.secondaryText)
            Text(DataFreshnessFormatter.label(for: date))
                .foregroundColor(.secondaryText.opacity(0.85))
        }
        .font(.caption2)
    }
}
