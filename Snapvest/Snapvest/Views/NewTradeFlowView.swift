//
//  NewTradeFlowView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

/// 從個股／資產類型帶入交易市場
extension TradeMarket {
    init?(assetType: AssetType) {
        switch assetType {
        case .stockTW: self = .stockTW
        case .stockUS: self = .stockUS
        case .crypto: self = .crypto
        case .cash: return nil
        }
    }
}

/// 從帳戶詳情進入時：限定市場並鎖定帳戶
struct TradeFlowContext: Equatable {
    let sourceAccountId: String
    let allowedMarkets: [TradeMarket]
    
    static func from(account: Account) -> TradeFlowContext? {
        guard account.accountType.supportsStockTrading else { return nil }
        return TradeFlowContext(
            sourceAccountId: account.id,
            allowedMarkets: account.accountType.tradeMarketChoices
        )
    }
}

extension AccountType {
    /// 此帳戶類型可選的交易市場（單一市場時略過市場選擇步驟）
    var tradeMarketChoices: [TradeMarket] {
        switch self {
        case .twdSecurities: return [.stockTW]
        case .usdAccount: return [.stockUS]
        case .cryptoWallet: return [.crypto]
        default: return []
        }
    }
}

struct BuyTradePrefill: Equatable {
    let symbol: String
    let symbolName: String?
    let preferredAccountId: String?
    /// 從個股詳情進入時為 true：不可改選其他代號
    var lockSymbol: Bool = false
    /// 從帳戶詳情進入時為 true：不可改選其他帳戶
    var lockAccount: Bool = false
}

struct SellTradePrefill: Equatable {
    let symbol: String
    let preferredAccountId: String?
    /// 從個股詳情進入時為 true：僅能賣出此代號
    var lockSymbol: Bool = false
    /// 從帳戶詳情進入時為 true：不可改選其他帳戶
    var lockAccount: Bool = false
}

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
    
    let context: TradeFlowContext?
    let onComplete: ((TradeMarket, TradeAction) -> Void)?
    
    init(context: TradeFlowContext? = nil, onComplete: ((TradeMarket, TradeAction) -> Void)? = nil) {
        self.context = context
        self.onComplete = onComplete
        if let context, context.allowedMarkets.count == 1 {
            _selectedMarket = State(initialValue: context.allowedMarkets.first)
        } else {
            _selectedMarket = State(initialValue: nil)
        }
    }
    
    init(sourceAccount: Account, onComplete: ((TradeMarket, TradeAction) -> Void)? = nil) {
        self.init(context: TradeFlowContext.from(account: sourceAccount), onComplete: onComplete)
    }
    
    private var marketsForSelection: [TradeMarket] {
        context?.allowedMarkets ?? Array(TradeMarket.allCases)
    }
    
    private var showsMarketSelectionStep: Bool {
        selectedMarket == nil && marketsForSelection.count > 1
    }
    
    private var canNavigateBackToMarkets: Bool {
        selectedMarket != nil && marketsForSelection.count > 1
    }
    
    private var marketSelectionHint: String {
        if context != nil, marketsForSelection == [.stockTW, .stockUS] {
            return "請選擇要交易的市場（台股或美股）。"
        }
        return "請先選擇交易市場。"
    }
    
    private var lockedBuyPrefill: BuyTradePrefill? {
        guard let accountId = context?.sourceAccountId else { return nil }
        return BuyTradePrefill(
            symbol: "",
            symbolName: nil,
            preferredAccountId: accountId,
            lockAccount: true
        )
    }
    
    private var lockedSellPrefill: SellTradePrefill? {
        guard let accountId = context?.sourceAccountId else { return nil }
        return SellTradePrefill(symbol: "", preferredAccountId: accountId, lockAccount: true)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let selectedMarket = selectedMarket {
                    tradeActionStep(for: selectedMarket)
                } else if showsMarketSelectionStep {
                    marketSelectionStep
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("新增交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if canNavigateBackToMarkets {
                        SnapToolbarIconButton(icon: .back) {
                            withAnimation(ChartMotion.switchSpring) {
                                selectedMarket = nil
                                selectedAction = .buy
                            }
                        }
                    } else {
                        SnapToolbarIconButton(icon: .close, action: { dismiss() })
                    }
                }
            }
        }
        .snapFormSheetChrome()
    }
    
    private var marketSelectionStep: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("新增交易")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(marketSelectionHint)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(marketsForSelection) { market in
                        TradeMarketSelectionCard(market: market) {
                            withAnimation {
                                selectedMarket = market
                            }
                        }
                    }
                }
                .padding()
            }
            .snapFormScrollDismissesKeyboard()
        }
    }
    
    private func tradeActionStep(for market: TradeMarket) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: market.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(market.themeColor)
                    .frame(width: 32, height: 32)
                    .background(market.themeColor.opacity(0.12))
                    .clipShape(Circle())
                
                Text(market.title)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
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
            .padding(.bottom, 8)
            
            if selectedAction == .sell {
                SellTradeFormView(
                    market: market,
                    prefill: lockedSellPrefill,
                    embedInTradeFlow: true,
                    onSubmit: { _ in
                        onComplete?(market, .sell)
                    }
                )
            } else {
                BuyTradeFormView(
                    market: market,
                    prefill: lockedBuyPrefill,
                    embedInTradeFlow: true,
                    onSubmit: {
                        onComplete?(market, .buy)
                    }
                )
            }
        }
        .background(Color.mainBackground)
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
