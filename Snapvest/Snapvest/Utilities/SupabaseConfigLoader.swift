//
//  SupabaseConfigLoader.swift
//  Snapvest
//
//  在 App 啟動時載入 Supabase 設定
//  請在 Info.plist 或此處設定 SUPABASE_URL、SUPABASE_ANON_KEY
//

import Foundation

enum SupabaseConfigLoader {
    /// 在 App 啟動時呼叫
    static func configure() {
        // 開發與正式版皆可從 Info.plist 讀取，或直接設定如下
        #if DEBUG
        SupabaseConfig.url = "https://eqtbyusegarvdfplcorq.supabase.co"
        SupabaseConfig.anonKey = "sb_publishable__E7HewKbHnA47_P1Z6mkOg_qMxiC3os"
        #else
        if let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
           let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String {
            SupabaseConfig.url = url
            SupabaseConfig.anonKey = key
        }
        #endif
    }
}
