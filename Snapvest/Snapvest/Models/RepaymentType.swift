//
//  RepaymentType.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

/// 還款類型
enum RepaymentType {
    case regular  // 定期還款
    case early   // 提前還款（非定期還款）
    
    var displayName: String {
        switch self {
        case .regular:
            return "定期還款"
        case .early:
            return "提前還款"
        }
    }
}


