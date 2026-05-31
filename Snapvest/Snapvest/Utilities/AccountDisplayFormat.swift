//
//  AccountDisplayFormat.swift
//  Snapvest
//
//  管理／投資列表帳戶名稱顯示規則
//

import Foundation

enum AccountDisplayFormat {
    /// 列表列帳戶名稱最多顯示字數（其餘以 … 省略）
    static let listNameMaxCharacterCount = 8

    static func listName(_ name: String) -> String {
        guard name.count > listNameMaxCharacterCount else { return name }
        return String(name.prefix(listNameMaxCharacterCount)) + "…"
    }
}
