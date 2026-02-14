//
//  SupabaseConfig.template.swift
//  Snapvest
//
//  使用方式：
//  1. 複製此檔案，重新命名為 SupabaseConfig.secrets.swift（不要 commit 到 git）
//  2. 填入你的 URL 和 anon key
//  3. 在 SupabaseConfigLoader 中改為讀取此檔案的內容
//  4. 或直接在此檔案內呼叫 SupabaseConfig.url = "..." 並在 configure() 時執行
//

import Foundation

/// 開發用：直接設定 Supabase（複製此段到 SupabaseConfigLoader.configure() 的 #if DEBUG 區塊內）
/*
SupabaseConfig.url = "https://你的專案ID.supabase.co"
SupabaseConfig.anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...."
*/
