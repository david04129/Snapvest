//
//  LaunchSessionState.swift
//  Snapvest
//
//  冷啟動降級提示（例如無法同步股價、使用本機資料）。
//

import Foundation
import Combine

@MainActor
final class LaunchSessionState: ObservableObject {
    static let shared = LaunchSessionState()
    
    @Published var startupNotice: String?
    
    private init() {}
    
    func clearStartupNotice() {
        startupNotice = nil
    }
}
