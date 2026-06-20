//
//  SubscriptionComplianceBanner.swift
//  Snapvest
//
//  Free 超額合規模式提示橫幅
//

import SwiftUI

struct SubscriptionComplianceBanner: View {
    let snapshot: PortfolioLimitSnapshot
    var onShowPaywall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Free 合規模式", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.orange)

            Text(complianceMessage)
                .font(.caption)
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onShowPaywall) {
                Text("了解 Walleaf Plus")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.orange)
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var complianceMessage: String {
        "你目前有 \(snapshot.distinctHoldingCount) 檔持股（Free 上限 \(PlusFreeLimits.maxDistinctHoldings) 檔）。只能全數賣出清倉，無法買入，直到恢復合規或訂閱 Plus。"
    }
}
