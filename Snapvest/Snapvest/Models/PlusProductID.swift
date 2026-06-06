//
//  PlusProductID.swift
//  Snapvest
//
//  Walleaf Plus 訂閱 Product ID（須與 WalleafPlus.storekit、App Store Connect 一致）
//

import Foundation

enum PlusProductID {
    static let monthly = "walleaf.plus.monthly"
    static let yearly = "walleaf.plus.yearly"
    /// 與 WalleafPlus.storekit / App Store Connect 訂閱群組一致
    static let subscriptionGroupID = "WALLEAF_PLUS_GROUP"

    static var all: [String] { [monthly, yearly] }
}
