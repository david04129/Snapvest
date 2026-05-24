//
//  PortfolioViewModel.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation
import Combine

@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var totalAssets: Decimal = 0
    @Published var totalLiabilities: Decimal = 0
    @Published var totalCash: Decimal = 0
    @Published var totalInvestments: Decimal = 0
    @Published var unrealizedGainLoss: Decimal = 0
    @Published var realizedGainLoss: Decimal = 0
    @Published var realizedGainLossTWD: Decimal = 0
    @Published var realizedGainLossUSD: Decimal = 0
    @Published var liabilities: [Liability] = []
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var homeSnapshot: HomeDashboardSnapshot?
    @Published var pieChartInputs: PieChartInputs?
    @Published var todayPLSummary: TodayPLSummary = .empty
    
    @Published var baseCurrency: Currency = .TWD
    @Published var viewCurrency: Currency = .TWD
    
    @Published var cashByCurrency: [Currency: Decimal] = [:]
    
    private let dataService: DataServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private(set) var hasLoadedOnce = false
    
    init(dataService: DataServiceProtocol? = nil) {
        self.dataService = dataService ?? MockDataService.shared
    }
    
    /// Splash／快照更新後：從本機 B 灌入首頁狀態（不重算、不寫磁碟）
    func prepareFromPersisted(userId: String, usdToTwdRate: Decimal) async {
        isLoading = true
        errorMessage = nil

        do {
            accounts = try await dataService.fetchAccounts(userId: userId)
            liabilities = try await loadLiabilities(userId: userId)
            homeSnapshot = try await dataService.fetchHomeDashboardSnapshot(userId: userId)
            applyHomeSnapshot(homeSnapshot, usdToTwdRate: usdToTwdRate)
            await refreshPieChartDataFromPersisted(userId: userId, usdToTwdRate: usdToTwdRate)
        } catch {
            errorMessage = "載入資料失敗：\(error.localizedDescription)"
        }

        isLoading = false
        hasLoadedOnce = true
    }

    /// 從本機估值 B 組圓餅圖（Splash／Tab 套用）
    func refreshPieChartDataFromPersisted(userId: String, usdToTwdRate: Decimal) async {
        pieChartInputs = try? await PieChartDataLoader.loadFromPersisted(
            userId: userId,
            dataService: dataService,
            usdToTwdRate: usdToTwdRate
        )
        todayPLSummary = TodayPLCalculator.calculate(from: pieChartInputs)
    }
    
    /// 重新載入負債列表（不動首頁大數字）
    func reloadLiabilities(userId: String) async {
        do {
            liabilities = try await loadLiabilities(userId: userId)
        } catch {
            // 保留現有資料
        }
    }
    
    private func loadLiabilities(userId: String) async throws -> [Liability] {
        let accounts = try await dataService.fetchAccounts(userId: userId)
        var allLiabilities: [Liability] = []
        
        for account in accounts {
            let accountLiabilities = try await dataService.fetchLiabilities(accountId: account.id)
            allLiabilities.append(contentsOf: accountLiabilities)
        }
        
        return allLiabilities
    }

    private func applyHomeSnapshot(_ snapshot: HomeDashboardSnapshot?, usdToTwdRate: Decimal? = nil) {
        guard let snapshot else {
            return
        }
        
        totalAssets = snapshot.totalAssets
        totalLiabilities = snapshot.totalLiabilities
        totalCash = snapshot.totalCash
        totalInvestments = snapshot.totalAssets - snapshot.totalCash
        unrealizedGainLoss = snapshot.totalAssets - snapshot.totalCash - snapshot.totalInvestmentsCost
        realizedGainLossTWD = snapshot.realizedGainLossTWD
        realizedGainLossUSD = snapshot.realizedGainLossUSD
        cashByCurrency = [
            .TWD: snapshot.twdCash,
            .USD: snapshot.usdCash
        ]

        if let usdToTwdRate {
            realizedGainLoss = realizedGainLossTWD + (realizedGainLossUSD * usdToTwdRate)
        } else {
            realizedGainLoss = realizedGainLossTWD
            Task {
                let rate = (try? await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil)?.rate) ?? 0
                realizedGainLoss = realizedGainLossTWD + (realizedGainLossUSD * rate)
            }
        }
    }
}
