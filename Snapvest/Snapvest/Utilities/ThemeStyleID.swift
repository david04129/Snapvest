//
//  ThemeStyleID.swift
//  Snapvest
//
//  使用者可選的資產類別配色風格（台股／美股／加密）。
//

import SwiftUI

enum ThemeStyleID: String, CaseIterable, Identifiable, Codable {
    /// 現行預設：琥珀台股、藍系美股、青綠加密
    case steadyFinance
    /// 對照組：青綠台股、橘系美股、紫色加密
    case vividContrast
    /// 翡翠台股、天藍美股、萊姆加密
    case forestMint
    /// 玫瑰台股、紫系美股、琥珀加密
    case sunsetGlow
    /// 青藍台股、深藍美股、靛紫加密
    case oceanCool
    /// 紅寶台股、藍寶美股、祖母綠加密
    case jewelTone
    /// 紫系台股、青綠美股、橘系加密
    case auroraVivid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .steadyFinance: return "沉穩理財"
        case .vividContrast: return "清晰對比"
        case .forestMint: return "森林薄荷"
        case .sunsetGlow: return "暮色暖彩"
        case .oceanCool: return "海洋清涼"
        case .jewelTone: return "寶石質感"
        case .auroraVivid: return "極光靛紫"
        }
    }

    var subtitle: String {
        switch self {
        case .steadyFinance: return "目前的預設配色"
        case .vividContrast: return "台股／美股／加密改用另一組色票"
        case .forestMint: return "翠綠台股、薄荷底與翡翠品牌色"
        case .sunsetGlow: return "暖色背景、玫瑰品牌與暮光紫"
        case .oceanCool: return "海藍底、青品牌與深海投資色"
        case .jewelTone: return "紫調底、寶石品牌與紅藍綠投資色"
        case .auroraVivid: return "極光紫底、靛紫品牌與對比投資色"
        }
    }

    /// 設定頁色卡預覽（依目前深淺色模式）
    func previewAssetColors(isDarkMode: Bool) -> (stockTW: Color, stockUS: Color, crypto: Color) {
        let palette = ThemeStyleCatalog.palette(style: self, isDarkMode: isDarkMode)
        return (palette.stockTWColor, palette.stockUSColor, palette.cryptoColor)
    }
}
