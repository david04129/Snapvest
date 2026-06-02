//
//  DataFreshnessStore.swift
//  Snapvest
//
//  Phase 5：各 Tab 顯示股價／快照更新時間（測試版）。
//

import Foundation
import Combine

struct DataFreshnessSnapshot: Equatable {
    var priceSourceUpdatedAt: Date?
    var priceSyncedAt: Date?
    var valuationUpdatedAt: Date?
    var structureUpdatedAt: Date?
    
    var isPriceStale: Bool {
        guard let source = priceSourceUpdatedAt,
              let synced = priceSyncedAt else { return false }
        return source > synced
    }
}

enum DataFreshnessFormatter {
    private static let oneHour: TimeInterval = 3600

    private static let absoluteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    /// 資料寫入時間：1 小時內為「剛剛／N 分鐘前」，超過則為 yyyy/MM/dd HH:mm（台北）。
    static func label(for date: Date?, relativeTo now: Date = Date()) -> String {
        guard let date else { return "—" }
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 60 {
            return "剛剛"
        }
        if elapsed < oneHour {
            let minutes = Int(ceil(elapsed / 60))
            return "\(minutes) 分鐘前"
        }
        return absoluteFormatter.string(from: date)
    }
}

@MainActor
final class DataFreshnessStore: ObservableObject {
    static let shared = DataFreshnessStore()
    
    @Published private(set) var snapshot = DataFreshnessSnapshot()
    
    private let dataService: DataServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(dataService: DataServiceProtocol? = nil) {
        self.dataService = dataService ?? MockDataService.shared
        
        NotificationCenter.default.publisher(for: .snapshotsDidUpdate)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }
    
    func refresh(userId: String? = nil) {
        let resolvedUserId = userId ?? AppUser.id
        snapshot = DataFreshnessSnapshot(
            priceSourceUpdatedAt: dataService.fetchPriceSourceUpdatedAt(userId: resolvedUserId),
            priceSyncedAt: dataService.fetchPriceSyncedAt(userId: resolvedUserId),
            valuationUpdatedAt: dataService.fetchValuationUpdatedAt(userId: resolvedUserId),
            structureUpdatedAt: dataService.fetchStructureUpdatedAt(userId: resolvedUserId)
        )
    }
}
