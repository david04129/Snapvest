//
//  NetworkConnectivity.swift
//  Snapvest
//
//  冷啟動時檢查裝置是否有可用網路。
//

import Foundation
import Network

enum NetworkConnectivity {
    /// 目前是否有可用網路（Wi‑Fi 或行動數據）。
    static func isConnected() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.snapvest.network-connectivity")
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: queue)
        }
    }
}
