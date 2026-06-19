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
    @Environment(\.openPlusPaywall) private var openPlusPaywall
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var selectedMarket: TradeMarket?
    @State private var selectedAction: TradeAction = .buy
    @State private var gateAlertMessage: String?
    
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
        .alert("需要 Walleaf Plus", isPresented: Binding(
            get: { gateAlertMessage != nil },
            set: { if !$0 { gateAlertMessage = nil } }
        )) {
            Button("了解 Plus") {
                gateAlertMessage = nil
                openPlusPaywall()
            }
            Button("知道了", role: .cancel) {
                gateAlertMessage = nil
            }
        } message: {
            Text(gateAlertMessage ?? "")
        }
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
            .padding(.bottom, 12)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(marketsForSelection) { market in
                        TradeMarketSelectionCard(market: market) {
                            Task {
                                await selectMarket(market)
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
            tradeFlowHeader(for: market)
                .background(Color.mainBackground)
                .fixedSize(horizontal: false, vertical: true)
                .zIndex(1)

            Group {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .background(Color.mainBackground)
    }

    private func tradeFlowHeader(for market: TradeMarket) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(market.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(market.themeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(market.themeColor.opacity(0.15))
                    .clipShape(Capsule())

                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            HStack(spacing: 8) {
                ForEach(TradeAction.allCases) { action in
                    tradeActionPill(action)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(6)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.separator.opacity(0.35), lineWidth: 1)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func tradeActionPill(_ action: TradeAction) -> some View {
        let isSelected = selectedAction == action
        let color: Color = action == .buy ? .profitGreen : .lossRed
        return Button {
            guard selectedAction != action else { return }
            if action == .buy, let selectedMarket {
                let previousAction = selectedAction
                withAnimation(ChartMotion.switchSpring) {
                    selectedAction = .buy
                }
                Task {
                    let allowed = await canOpenBuyFlow(for: selectedMarket)
                    if !allowed {
                        withAnimation(ChartMotion.switchSpring) {
                            selectedAction = previousAction
                        }
                    }
                }
            } else {
                withAnimation(ChartMotion.switchSpring) {
                    selectedAction = action
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: action.iconName)
                    .font(.system(size: 12, weight: .bold))
                Text(action.title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(isSelected ? AppColors.actionForeground : .primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule().fill(color)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectMarket(_ market: TradeMarket) async {
        guard await canOpenBuyFlow(for: market) else { return }
        withAnimation {
            selectedMarket = market
        }
    }

    private func canOpenBuyFlow(for market: TradeMarket) async -> Bool {
        guard selectedAction == .buy else { return true }
        do {
            let snapshot = try await PlusFeatureGate.loadSnapshot(userId: AppUser.id)
            let decision = PlusFeatureGate.canOpenBuyFlow(
                assetType: market.assetType,
                snapshot: snapshot,
                isPlusActive: subscriptionManager.isPlusActive
            )
            switch decision {
            case .allowed:
                return true
            case .blocked(let reason):
                gateAlertMessage = PlusFeatureGate.message(for: reason)
                return false
            }
        } catch {
            gateAlertMessage = "無法驗證 Free 上限：\(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - 市場選擇卡片
struct TradeMarketSelectionCard: View {
    let market: TradeMarket
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
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
                
                Text("選擇")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(market.themeColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(market.themeColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding()
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(market.themeColor)
                    .frame(width: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(market.themeColor.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NewTradeFlowView()
}
