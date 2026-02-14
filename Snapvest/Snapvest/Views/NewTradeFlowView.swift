//
//  NewTradeFlowView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

enum TradeMarket: String, CaseIterable, Identifiable {
    case stockTW
    case stockUS
    case crypto
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .stockTW: return "台股"
        case .stockUS: return "美股"
        case .crypto: return "加密貨幣"
        }
    }
    
    var subtitle: String {
        switch self {
        case .stockTW: return "台灣上市股票與 ETF"
        case .stockUS: return "美國股票與 ETF"
        case .crypto: return "加密貨幣與代幣"
        }
    }
    
    var iconName: String {
        switch self {
        case .stockTW: return "chart.line.uptrend.xyaxis"
        case .stockUS: return "dollarsign.circle"
        case .crypto: return "bitcoinsign.circle"
        }
    }
    
    var themeColor: Color {
        switch self {
        case .stockTW: return .stockTWColor
        case .stockUS: return .stockUSColor
        case .crypto: return .cryptoColor
        }
    }
    
    var assetType: AssetType {
        switch self {
        case .stockTW: return .stockTW
        case .stockUS: return .stockUS
        case .crypto: return .crypto
        }
    }
}

enum TradeAction: String, CaseIterable, Identifiable {
    case buy
    case sell
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .buy: return "買入"
        case .sell: return "賣出"
        }
    }
    
    var iconName: String {
        switch self {
        case .buy: return "arrow.up"
        case .sell: return "arrow.down"
        }
    }
}

struct NewTradeFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMarket: TradeMarket?
    @State private var selectedAction: TradeAction = .buy
    
    let onComplete: ((TradeMarket, TradeAction) -> Void)?
    
    init(onComplete: ((TradeMarket, TradeAction) -> Void)? = nil) {
        self.onComplete = onComplete
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let selectedMarket = selectedMarket {
                    tradeActionStep(for: selectedMarket)
                } else {
                    marketSelectionStep
                }
            }
            .navigationTitle("新增交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }
            }
        }
    }
    
    private var marketSelectionStep: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("新增交易")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("請先選擇交易市場。")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(TradeMarket.allCases) { market in
                        TradeMarketSelectionCard(market: market) {
                            withAnimation {
                                selectedMarket = market
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private func tradeActionStep(for market: TradeMarket) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(market.title) 交易")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("請選擇要進行的交易動作。")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)
            
            CardView(padding: 8, cornerRadius: 12) {
                Picker("", selection: $selectedAction) {
                    ForEach(TradeAction.allCases) { action in
                        Label(action.title, systemImage: action.iconName)
                            .tag(action)
                    }
                }
                .pickerStyle(.segmented)
                .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            
            if selectedAction == .sell {
                SellTradeFormView(market: market)
            } else {
                BuyTradeFormView(market: market)
            }
        }
    }
}

// MARK: - 市場選擇卡片
struct TradeMarketSelectionCard: View {
    let market: TradeMarket
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(market.themeColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: market.iconName)
                        .foregroundColor(market.themeColor)
                        .font(.system(size: 24))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(market.title)
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    
                    Text(market.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondaryText)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(market.themeColor.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(market.themeColor.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NewTradeFlowView()
}
