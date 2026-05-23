//
//  SupabaseConfigLoader.swift
//  Snapvest
//
//  在 App 啟動時載入 Supabase 設定
//  Info.plist：
//  - SUPABASE_URL
//  - SUPABASE_ANON_KEY（publishable `sb_publishable__…` 或 legacy anon JWT）
//  - SUPABASE_ANON_JWT（選填，legacy anon JWT `eyJ…`，供 Edge Function Authorization）
//

import Foundation

enum SupabaseConfigLoader {
    /// 在 App 啟動時呼叫
    static func configure() {
        #if DEBUG
        SupabaseConfig.url = stringFromPlist("SUPABASE_URL")
            ?? "https://eqtbyusegarvdfplcorq.supabase.co"
        SupabaseConfig.anonKey = stringFromPlist("SUPABASE_ANON_KEY")
            ?? "sb_publishable__E7HewKbHnA47_P1Z6mkOg_qMxiC3os"
        #else
        SupabaseConfig.url = stringFromPlist("SUPABASE_URL")
        SupabaseConfig.anonKey = stringFromPlist("SUPABASE_ANON_KEY")
        #endif
        
        SupabaseConfig.anonJwt = stringFromPlist("SUPABASE_ANON_JWT")
    }
    
    private static func stringFromPlist(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
