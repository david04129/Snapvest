//
//  WalleafPlusPaywallL10n.swift
//  Snapvest
//
//  Walleaf Plus 訂閱頁文案（繁體中文）
//

import Foundation

enum WalleafPlusPaywallL10n {
    private static func t(_ zh: String, _ en: String) -> String {
        zh
    }

    static var close: String { t("關閉", "Close") }
    static var done: String { t("完成", "Done") }
    static var continueButton: String { t("繼續", "Continue") }

    static var heroSubtitle: String {
        t("升級 Plus，讓資產追蹤不再設限", "Upgrade to Plus for unlimited portfolio tracking")
    }

    static var plusActiveEnabled: String { t("已啟用", "Active") }

    static var currentPlanBadge: String { t("目前方案", "Current") }

    static var currentPlanTitle: String { t("目前方案", "Current plan") }

    static var currentPlanSubtitle: String {
        t("您目前的訂閱方案", "Your current subscription")
    }

    static var switchToYearly: String { t("改為按年訂閱", "Switch to Annual") }
    static var switchToMonthly: String { t("改為按月訂閱", "Switch to Monthly") }
    static var currentPlanButton: String { t("您目前的方案", "Current Plan") }

    static var subscribedSuccess: String {
        t("已成功訂閱 Walleaf Plus。", "Successfully subscribed to Walleaf Plus.")
    }

    static var switchedToYearly: String {
        t(
            "已排程改為按年訂閱。本期月訂結束後，下個週期將以年費計費。",
            "Annual billing is scheduled. It starts when your current monthly period ends."
        )
    }

    static var switchedToMonthly: String {
        t(
            "已排程改為按月訂閱。本期年訂結束後，下個週期將以月費計費。",
            "Monthly billing is scheduled. It starts when your current annual period ends."
        )
    }

    static var scheduledPlanBadge: String { t("下個週期生效", "Starts next period") }

    static var scheduledPlanSubtitle: String {
        t("已排程，將於下個續訂週期生效", "Scheduled for your next renewal")
    }

    static func scheduledPlanSubtitle(on date: Date) -> String {
        let formatted = renewalDateFormatter.string(from: date)
        return t("已排程，將於 \(formatted) 改為此方案", "Scheduled to start on \(formatted)")
    }

    private static var renewalDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    static var scheduledPlanButton: String { t("已排程", "Scheduled") }

    static var switchToYearlyHint: String {
        t("本期月訂結束後，下個週期改為按年計費", "Annual billing starts after this monthly period")
    }

    static var applePlanChangeNotice: String {
        t(
            "Apple 會在確認頁顯示實際費用與生效時間。",
            "Apple will show the final charge and effective date on the confirmation sheet."
        )
    }

    static var switchToMonthlyHint: String {
        t("本期年訂結束後，下個週期改為按月計費", "Monthly billing starts after this annual period")
    }

    static var switchPlanNotApplied: String {
        t(
            "購買已完成，但方案尚未切換。請至 Xcode Debug → StoreKit → Manage Transactions 刪除舊交易後重試，或使用 Sandbox 測試。",
            "Purchase completed, but your plan did not switch. Delete the old transaction in Xcode Debug → StoreKit → Manage Transactions and try again, or test in Sandbox."
        )
    }

    static var comparisonTitle: String { t("Free vs Plus 功能表", "Free vs Plus Features") }
    static var comparisonFeature: String { t("功能", "Feature") }
    static var comparisonFree: String { "Free" }
    static var comparisonPlus: String { "Plus" }

    static var rowAccounts: String { t("帳戶數量", "Accounts") }
    static var rowHoldings: String { t("持股檔數", "Holdings") }
    static var rowMarkets: String { t("投資市場", "Markets") }
    static var rowBackup: String { t("備份與還原", "Backup & Restore") }
    static var rowImport: String { t("批量匯入", "Bulk Import") }
    static var rowFaceID: String { t("Face ID 隱私鎖", "Face ID Lock") }

    static var freeAccounts: String { t("最多 3 個", "Up to 3") }
    static var freeHoldings: String { t("最多 3 檔", "Up to 3") }
    static var freeMarkets: String { t("僅一種", "One market") }
    static var plusUnlimited: String { t("無上限", "Unlimited") }
    static var plusMarkets: String { t("台股・美股・加密", "TW · US · Crypto") }
    static var included: String { "✓" }
    static var notIncluded: String { "—" }

    static var choosePlan: String { t("選擇方案", "Choose a Plan") }
    static var loadingPlans: String { t("載入方案中…", "Loading plans…") }

    static var planYearly: String { t("按年訂閱", "Annual") }
    static var planMonthly: String { t("按月訂閱", "Monthly") }

    static func savePercent(_ percent: String) -> String {
        t("省 \(percent)", "Save \(percent)")
    }

    static var freeTrial7Days: String { t("7 天免費試用", "7-day free trial") }

    static func perMonth(_ price: String) -> String {
        t("折合 \(price) / 月", "≈ \(price) / mo")
    }

    static var yearlySubtitleTrial: String { freeTrial7Days }

    static var monthlySubtitle: String {
        t("每月自動續訂 · 無免費試用", "Renews monthly · No free trial")
    }

    static var restorePurchases: String { t("恢復購買", "Restore Purchases") }
    static var redeemOfferCode: String { t("兌換優惠碼", "Redeem Offer Code") }
    static var redeemOfferCodeSubtitle: String {
        t("輸入 Apple 訂閱優惠碼", "Enter an Apple subscription offer code")
    }
    static var manageSubscription: String { t("管理訂閱", "Manage Subscription") }
    static var contactSectionTitle: String { t("聯絡我們", "Contact") }
    static var supportWithReviewTitle: String { t("支持我們：五星評論", "Support Us: 5-Star Review") }
    static var supportWithReviewSubtitle: String { t("喜歡 Walleaf 的話，歡迎留下評分", "If you enjoy Walleaf, leave a rating") }
    static var contactUsTitle: String { t("聯絡我們", "Contact Us") }
    static var contactUsSubtitle: String { t("有問題或建議，寄信給我們", "Email us with questions or feedback") }

    static var cannotLoadPlans: String { t("無法載入方案", "Unable to load plans") }

    static var startFreeTrial: String { t("開始 7 天免費試用", "Start 7-Day Free Trial") }

    static var subscribeYearly: String { t("按年訂閱", "Subscribe Annually") }
    static var subscribeMonthly: String { t("按月訂閱", "Subscribe Monthly") }

    static var subscriptionAlertTitle: String { t("訂閱", "Subscription") }
    static var alertOK: String { t("知道了", "OK") }

    static var monthlyTimesTwelve: String { t("月付 × 12", "Monthly × 12") }

    static var monthlySubscribedExplanation: String {
        t(
            "你已解鎖所有 Plus 功能。若改成年訂閱，Apple 會處理方案切換與實際費用。",
            "All Plus features are unlocked. If you switch to annual billing, Apple handles the plan change and final charge."
        )
    }

    static var yearlySubscribedExplanation: String {
        t(
            "你已使用年訂閱並解鎖所有 Plus 功能。如需取消或變更方案，請前往 Apple 訂閱管理。",
            "You are on annual billing with all Plus features unlocked. Use Apple subscription management to cancel or change your plan."
        )
    }

    static var genericSubscribedExplanation: String {
        t(
            "你已解鎖所有 Plus 功能。訂閱方案與續訂由 Apple 管理。",
            "All Plus features are unlocked. Apple manages your subscription plan and renewal."
        )
    }

    static func renewalDateText(_ date: Date) -> String {
        let formatted = renewalDateFormatter.string(from: date)
        return t("下次續訂：\(formatted)", "Renews on \(formatted)")
    }

    static var priceLocale: Locale {
        Locale(identifier: "zh_TW")
    }

    static var settingsCardDescription: String {
        t("解鎖更多投資追蹤、分享與進階設定功能", "Unlock advanced tracking, sharing, and settings")
    }

    static var settingsCardDescriptionSubscribed: String {
        t("Plus 已啟用 · 全部功能已解鎖", "Plus active · All features unlocked")
    }

    static var settingsCardSubtitle: String {
        t("查看方案 · 解鎖 Plus 功能", "View plans · Unlock Plus features")
    }

    static var settingsCardSubscribed: String {
        t("Plus 已啟用 · 感謝支持", "Plus active · Thanks for supporting")
    }
}
