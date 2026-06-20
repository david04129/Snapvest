//
//  TransactionImportTutorialView.swift
//  Snapvest
//
//  匯入交易分頁圖文教學（SwiftUI 動畫 mock，風格對齊 OnboardingView）
//

import SwiftUI

struct TransactionImportTutorialView: View {
    let account: Account

    init(account: Account) {
        self.account = account
    }

    /// 設定頁等無特定帳戶時，以代表帳戶類型展示通用匯入教學。
    init(accountType: AccountType) {
        self.account = Account(
            userId: AppUser.id,
            name: "示範",
            accountType: accountType
        )
    }

    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0
    @State private var animate = false

    private var pages: [ImportTutorialPage] {
        ImportTutorialPage.pages(for: account.accountType)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        ImportTutorialPageView(
                            page: page,
                            animate: animate && pageIndex == index
                        )
                        .tag(index)
                        .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
            .background(Color.mainBackground)
            .navigationTitle("如何批量匯入持倉")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(.appPrimary)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.45)) {
                    animate = true
                }
            }
            .onChange(of: pageIndex) { _, _ in
                animate = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeOut(duration: 0.45)) {
                        animate = true
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == pageIndex ? Color.appPrimary : Color.separator)
                        .frame(width: index == pageIndex ? 22 : 7, height: 7)
                        .animation(ChartMotion.switchSpring, value: pageIndex)
                }
            }

            if pageIndex == pages.count - 1 {
                Button {
                    dismiss()
                } label: {
                    Text("開始匯入")
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.actionForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    withAnimation(ChartMotion.switchSpring) {
                        pageIndex += 1
                    }
                } label: {
                    Text("下一步")
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.actionForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Pages

private enum ImportTutorialTextRun: Equatable {
    case normal(String)
    case strong(String)
}

private struct ImportTutorialTextSection: Identifiable, Equatable {
    let id: String
    let title: String
    let bullets: [[ImportTutorialTextRun]]
}

private struct ImportTutorialPage: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let detailBullets: [[ImportTutorialTextRun]]
    let textSections: [ImportTutorialTextSection]?
    let visual: ImportTutorialVisual

    init(
        id: String,
        title: String,
        subtitle: String,
        detailBullets: [[ImportTutorialTextRun]] = [],
        textSections: [ImportTutorialTextSection]? = nil,
        visual: ImportTutorialVisual
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.detailBullets = detailBullets
        self.textSections = textSections
        self.visual = visual
    }

    static func pages(for accountType: AccountType) -> [ImportTutorialPage] {
        let showStatement = accountType != .cryptoWallet

        let step1Subtitle: String
        let step1Sections: [ImportTutorialTextSection]
        if accountType == .cryptoWallet {
            step1Subtitle = "請準備完整的持有倉位截圖，並確認三項必填資訊齊全。"
            step1Sections = [
                ImportTutorialTextSection(
                    id: "holdings",
                    title: "持有倉位",
                    bullets: [
                        [
                            .normal("必填欄位："),
                            .strong("幣種"),
                            .normal("、"),
                            .strong("持有數量"),
                            .normal("、"),
                            .strong("成本價"),
                        ],
                        [.normal("僅有現價而缺少成本價的畫面，無法正確匯入")],
                        [.normal("請使用完整持有倉位列表，避免裁切欄位名稱")],
                    ]
                ),
            ]
        } else {
            step1Subtitle = "請依上方示意，準備「成交明細」或「持有倉位」其中之一，並確認必填欄位齊全。"
            step1Sections = [
                ImportTutorialTextSection(
                    id: "statement",
                    title: "成交明細",
                    bullets: [
                        [
                            .normal("必填欄位："),
                            .strong("日期"),
                            .normal("、"),
                            .strong("買／賣"),
                            .normal("、"),
                            .strong("代號或股票名稱"),
                            .normal("、"),
                            .strong("數量"),
                            .normal("、"),
                            .strong("成交單價"),
                        ],
                    ]
                ),
                ImportTutorialTextSection(
                    id: "holdings",
                    title: "持有倉位",
                    bullets: [
                        [
                            .normal("必填欄位："),
                            .strong("代號或股票名稱"),
                            .normal("、"),
                            .strong("持有數量"),
                            .normal("、"),
                            .strong("成本價"),
                            .normal("（現價不可替代成本）"),
                        ],
                        [.normal("截圖請保留欄位標題，避免裁切關鍵資訊")],
                    ]
                ),
            ]
        }

        let step1Bullets: [[ImportTutorialTextRun]] = []

        let step2Bullets: [[ImportTutorialTextRun]]
        if showStatement {
            step2Bullets = [
                [.normal("回到 Walleaf 匯入頁的「複製提示詞」區")],
                [
                    .normal("有成交紀錄 → 按「"),
                    .strong("成交明細"),
                    .normal("」"),
                ],
                [
                    .normal("僅有持股 → 按「"),
                    .strong("持有倉位"),
                    .normal("」"),
                ],
            ]
        } else {
            step2Bullets = [
                [.normal("回到 Walleaf 匯入頁的「複製提示詞」區")],
                [
                    .normal("按「"),
                    .strong("持有倉位"),
                    .normal("」複製專用提示詞"),
                ],
            ]
        }

        let step2Subtitle = showStatement
            ? "依資料類型選擇「成交明細」或「持有倉位」，並複製對應提示詞。"
            : "請按「持有倉位」複製專用提示詞。"

        return [
            ImportTutorialPage(
                id: "prepare",
                title: "準備資料（二擇一）",
                subtitle: step1Subtitle,
                detailBullets: step1Bullets,
                textSections: step1Sections,
                visual: .prepareMaterials(
                    showStatementOption: showStatement,
                    accountType: accountType
                )
            ),
            ImportTutorialPage(
                id: "copy",
                title: "複製提示詞",
                subtitle: step2Subtitle,
                detailBullets: step2Bullets,
                visual: .copyPrompt(showStatementOption: showStatement)
            ),
            ImportTutorialPage(
                id: "ai",
                title: "請「外部」AI 產生匯入文字",
                subtitle: "在 ChatGPT、Gemini 等「Walleaf 以外」的 App 貼上提示詞與截圖，取得可貼回本 App 的表格文字。",
                detailBullets: [
                    [.normal("請使用 ChatGPT、Gemini 等外部工具（非 Walleaf 內建 AI）")],
                    [.normal("複製外部 AI 回覆全文，回到 Walleaf 貼上")],
                ],
                visual: .externalAI(accountType: accountType)
            ),
            ImportTutorialPage(
                id: "paste",
                title: "貼回並匯入",
                subtitle: "將外部 AI 產生的文字貼入下方欄位，預覽確認無誤後即可匯入。",
                detailBullets: [
                    [.normal("貼到「貼回並匯入」欄位，按「解析預覽」")],
                    [.normal("檢查每筆代號、數量、價格是否合理")],
                    [.normal("有問題的列可點進修改；確認後再按「確認匯入」")],
                ],
                textSections: [
                    ImportTutorialTextSection(
                        id: "tips",
                        title: "小提醒",
                        bullets: [
                            [.normal("匯入前多檢查一次預覽，能避免錯誤")],
                            [.normal("若與既有交易相似，系統會提示重複，可選擇略過")],
                            [.normal("賣出數量不可超過目前持股")],
                        ]
                    ),
                ],
                visual: .pastePreview(accountType: accountType)
            ),
        ]
    }
}

private enum ImportTutorialVisual: Equatable {
    case prepareMaterials(showStatementOption: Bool, accountType: AccountType)
    case copyPrompt(showStatementOption: Bool)
    case externalAI(accountType: AccountType)
    case pastePreview(accountType: AccountType)
}

private enum ImportTutorialLayout {
    static let highlightGutter: CGFloat = 10

    static func visualHeight(for visual: ImportTutorialVisual) -> CGFloat {
        switch visual {
        case .prepareMaterials:
            return 318
        case .pastePreview:
            return 420
        case .copyPrompt:
            return 328
        case .externalAI:
            return 400
        }
    }
}

private struct ImportTutorialPageView: View {
    let page: ImportTutorialPage
    let animate: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                visual
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(height: ImportTutorialLayout.visualHeight(for: page.visual), alignment: .top)

                VStack(spacing: 8) {
                    Text(page.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primaryText)
                        .multilineTextAlignment(.center)

                    Text(page.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                if !page.detailBullets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(page.detailBullets.enumerated()), id: \.offset) { index, runs in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Color.appPrimary.opacity(0.85))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                ImportTutorialBulletText(runs: runs)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .opacity(animate ? 1 : 0)
                            .offset(y: animate ? 0 : 6)
                            .animation(.easeOut(duration: 0.32).delay(Double(index) * 0.05), value: animate)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
                }

                if let sections = page.textSections {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(sections.enumerated()), id: \.element.id) { sectionIndex, section in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(section.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.appPrimary)

                                ForEach(Array(section.bullets.enumerated()), id: \.offset) { bulletIndex, runs in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(Color.appPrimary.opacity(0.85))
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 6)
                                        ImportTutorialBulletText(runs: runs)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .opacity(animate ? 1 : 0)
                                    .offset(y: animate ? 0 : 6)
                                    .animation(
                                        .easeOut(duration: 0.32)
                                            .delay(0.12 + Double(sectionIndex) * 0.06 + Double(bulletIndex) * 0.05),
                                        value: animate
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
                }
            }
            .padding(.bottom, 4)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var visual: some View {
        switch page.visual {
        case .prepareMaterials(let showStatement, let accountType):
            ImportTutorialPrepareMock(
                animate: animate,
                showStatementOption: showStatement,
                accountType: accountType
            )
        case .copyPrompt(let showStatementOption):
            ImportTutorialCopyPromptMock(
                animate: animate,
                showStatementOption: showStatementOption
            )
        case .externalAI(let accountType):
            ImportTutorialAIMock(animate: animate, accountType: accountType)
        case .pastePreview(let accountType):
            ImportTutorialPasteMock(animate: animate, accountType: accountType)
        }
    }
}

private struct ImportTutorialBulletText: View {
    let runs: [ImportTutorialTextRun]

    var body: some View {
        Text(attributedContent)
    }

    private var attributedContent: AttributedString {
        runs.reduce(into: AttributedString()) { result, run in
            switch run {
            case .normal(let string):
                var segment = AttributedString(string)
                var style = AttributeContainer()
                style.font = .caption.weight(.medium)
                style.foregroundColor = Color.secondaryText
                segment.mergeAttributes(style)
                result.append(segment)
            case .strong(let string):
                var segment = AttributedString(string)
                var style = AttributeContainer()
                style.font = .caption.weight(.bold)
                style.foregroundColor = Color.primaryText
                segment.mergeAttributes(style)
                result.append(segment)
            }
        }
    }
}

private enum ImportTutorialMotion {
    static let highlightSpring = Animation.easeInOut(duration: 0.38)
    static let pressSpring = Animation.easeInOut(duration: 0.36)
}

private struct ImportTutorialHighlightModifier: ViewModifier {
    let active: Bool
    var cornerRadius: CGFloat = 12
    var prominent: Bool = false

    @State private var pulseExpanded = false

    private var strokeWidth: CGFloat { prominent ? 3 : 2.5 }
    private var glowRadius: CGFloat { prominent ? 10 : 8 }

    func body(content: Content) -> some View {
        content
            .padding(ImportTutorialLayout.highlightGutter)
            .overlay {
                if active {
                    RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                        .stroke(Color.appPrimary.opacity(0.22), lineWidth: prominent ? 5 : 4)
                        .padding(ImportTutorialLayout.highlightGutter - 2)
                        .scaleEffect(pulseExpanded ? 1.04 : 1)

                    RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous)
                        .stroke(Color.appPrimary, lineWidth: strokeWidth)
                        .padding(ImportTutorialLayout.highlightGutter - 1)
                        .shadow(color: Color.appPrimary.opacity(0.45), radius: glowRadius, x: 0, y: 0)
                }
            }
            .padding(-ImportTutorialLayout.highlightGutter)
            .scaleEffect(active ? 0.985 : 1)
            .animation(ImportTutorialMotion.highlightSpring, value: active)
            .onChange(of: active) { _, isActive in
                if isActive {
                    pulseExpanded = false
                    withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                        pulseExpanded = true
                    }
                } else {
                    pulseExpanded = false
                }
            }
    }
}

private struct ImportTutorialPressModifier: ViewModifier {
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.93 : 1)
            .animation(ImportTutorialMotion.pressSpring, value: isPressed)
    }
}

private extension View {
    func importTutorialHighlight(
        _ active: Bool,
        cornerRadius: CGFloat = 12,
        prominent: Bool = false
    ) -> some View {
        modifier(ImportTutorialHighlightModifier(
            active: active,
            cornerRadius: cornerRadius,
            prominent: prominent
        ))
    }

    func importTutorialPress(_ isPressed: Bool) -> some View {
        modifier(ImportTutorialPressModifier(isPressed: isPressed))
    }
}

// MARK: - Visual mocks

private enum ImportTutorialBrokerScreenshotPalette {
    static let headerBackground = Color(red: 0.11, green: 0.20, blue: 0.26)
    static let rowBackground = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let rowDivider = Color.white.opacity(0.14)
    static let headerText = Color.white.opacity(0.95)
    static let cellText = Color.white.opacity(0.92)
}

private struct ImportTutorialBrokerCell {
    let text: String
    var underlined: Bool = false
    var tint: Color?
}

private enum ImportTutorialBrokerSampleData {
    static func symbolColumnTitle(for accountType: AccountType) -> String {
        accountType == .cryptoWallet ? "幣種" : "代號"
    }

    static func holdingsSymbolColumnTitle(for accountType: AccountType) -> String {
        accountType == .cryptoWallet ? "幣種" : "股票名稱"
    }

    static func statementColumns(for accountType: AccountType) -> [String] {
        ["日期", "買賣", symbolColumnTitle(for: accountType), "數量", "成交價"]
    }

    static func holdingsColumns(for accountType: AccountType) -> [String] {
        [holdingsSymbolColumnTitle(for: accountType), "持有數量", "成本價"]
    }

    static func statementRows(for accountType: AccountType) -> [[ImportTutorialBrokerCell]] {
        switch accountType {
        case .twdSecurities:
            return [
                [
                    .init(text: "2025/01/08"),
                    .init(text: "買進", tint: .lossRed),
                    .init(text: "0050", underlined: true),
                    .init(text: "200"),
                    .init(text: "152.30"),
                ],
                [
                    .init(text: "2025/01/15"),
                    .init(text: "買進", tint: .lossRed),
                    .init(text: "2330", underlined: true),
                    .init(text: "10"),
                    .init(text: "985.00"),
                ],
                [
                    .init(text: "2025/02/03"),
                    .init(text: "賣出", tint: .profitGreen),
                    .init(text: "0050", underlined: true),
                    .init(text: "50"),
                    .init(text: "168.50"),
                ],
            ]
        case .usdAccount:
            return [
                [
                    .init(text: "01/08/25"),
                    .init(text: "Buy", tint: .lossRed),
                    .init(text: "NVDA", underlined: true),
                    .init(text: "15"),
                    .init(text: "175.64"),
                ],
                [
                    .init(text: "01/22/25"),
                    .init(text: "Buy", tint: .lossRed),
                    .init(text: "AAPL", underlined: true),
                    .init(text: "20"),
                    .init(text: "228.40"),
                ],
                [
                    .init(text: "02/05/25"),
                    .init(text: "Sell", tint: .profitGreen),
                    .init(text: "NVDA", underlined: true),
                    .init(text: "5"),
                    .init(text: "211.10"),
                ],
            ]
        default:
            return []
        }
    }

    static func holdingsRows(for accountType: AccountType) -> [[ImportTutorialBrokerCell]] {
        switch accountType {
        case .twdSecurities:
            return [
                [.init(text: "元大台灣50", underlined: true), .init(text: "150", underlined: true), .init(text: "154.20")],
                [.init(text: "台積電", underlined: true), .init(text: "10", underlined: true), .init(text: "985.00")],
                [.init(text: "國泰永續高股息", underlined: true), .init(text: "500", underlined: true), .init(text: "19.86")],
            ]
        case .usdAccount:
            return [
                [.init(text: "NVIDIA", underlined: true), .init(text: "11.08", underlined: true), .init(text: "178.25")],
                [.init(text: "AMD", underlined: true), .init(text: "8", underlined: true), .init(text: "158.20")],
                [.init(text: "Alphabet", underlined: true), .init(text: "35", underlined: true), .init(text: "142.50")],
            ]
        case .cryptoWallet:
            return [
                [.init(text: "BTC", underlined: true), .init(text: "0.42", underlined: true), .init(text: "68,420")],
                [.init(text: "ETH", underlined: true), .init(text: "3.15", underlined: true), .init(text: "3,820")],
            ]
        default:
            return []
        }
    }

    static func compactHoldingsRows(for accountType: AccountType) -> [[ImportTutorialBrokerCell]] {
        Array(holdingsRows(for: accountType).prefix(2))
    }

    static func sampleCSV(for accountType: AccountType) -> String {
        switch accountType {
        case .twdSecurities:
            return "date,type,asset_type,symbol,quantity,price\n2025-01-08,buy,stock_tw,0050,200,152.3\n2025-01-15,buy,stock_tw,2330,10,985"
        case .usdAccount:
            return "date,type,asset_type,symbol,quantity,price\n2025-01-08,buy,stock_us,NVDA,15,175.64\n2025-01-22,buy,stock_us,AAPL,20,228.4"
        case .cryptoWallet:
            return "date,type,asset_type,symbol,quantity,price\n2025-01-08,buy,crypto,BTC,0.42,68420\n2025-01-15,buy,crypto,ETH,3.15,3820"
        default:
            return "date,type,symbol,quantity,price"
        }
    }
}

private struct ImportTutorialInlineBrokerTable: View {
    let columns: [String]
    let rows: [[ImportTutorialBrokerCell]]

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: columns.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: gridColumns, spacing: 0) {
                ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                    HStack(spacing: 0) {
                        if index > 0 {
                            Text("|")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        Text(column)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(ImportTutorialBrokerScreenshotPalette.headerText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 2)
                }
            }
            .background(ImportTutorialBrokerScreenshotPalette.headerBackground)

            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                LazyVGrid(columns: gridColumns, spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(cell.text)
                            .font(.system(size: 8, weight: cell.underlined ? .semibold : .regular))
                            .foregroundColor(cell.tint ?? ImportTutorialBrokerScreenshotPalette.cellText)
                            .underline(cell.underlined, color: (cell.tint ?? ImportTutorialBrokerScreenshotPalette.cellText).opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 2)
                    }
                }
                .background(ImportTutorialBrokerScreenshotPalette.rowBackground)
                .overlay(alignment: .bottom) {
                    if rowIndex < rows.count - 1 {
                        Rectangle()
                            .fill(ImportTutorialBrokerScreenshotPalette.rowDivider)
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.black.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct ImportTutorialCopyToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.caption.weight(.semibold))
            Text("已複製到剪貼簿")
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(.primaryText)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 3)
    }
}

private struct ImportTutorialPrepareMock: View {
    let animate: Bool
    let showStatementOption: Bool
    let accountType: AccountType

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if showStatementOption {
                    ImportTutorialBrokerScreenshotCard(
                        title: "成交明細",
                        columns: ImportTutorialBrokerSampleData.statementColumns(for: accountType),
                        rows: ImportTutorialBrokerSampleData.statementRows(for: accountType),
                        animate: animate,
                        delay: 0
                    )
                }

                ImportTutorialBrokerScreenshotCard(
                    title: "持有倉位",
                    columns: ImportTutorialBrokerSampleData.holdingsColumns(for: accountType),
                    rows: ImportTutorialBrokerSampleData.holdingsRows(for: accountType),
                    animate: animate,
                    delay: showStatementOption ? 0.1 : 0
                )
            }
            .padding(.bottom, 4)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct ImportTutorialBrokerScreenshotCard: View {
    let title: String
    let columns: [String]
    let rows: [[ImportTutorialBrokerCell]]
    let animate: Bool
    let delay: Double

    private var gridColumns: [GridItem] {
        let count = columns.count
        if count == 5 {
            return [
                GridItem(.flexible(), spacing: 0),
                GridItem(.flexible(), spacing: 0),
                GridItem(.flexible(), spacing: 0),
                GridItem(.flexible(), spacing: 0),
                GridItem(.flexible(), spacing: 0),
            ]
        }
        return Array(repeating: GridItem(.flexible(), spacing: 0), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(.appPrimary)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                LazyVGrid(columns: gridColumns, spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                        headerCell(column, showDivider: index > 0)
                    }
                }
                .background(ImportTutorialBrokerScreenshotPalette.headerBackground)

                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    LazyVGrid(columns: gridColumns, spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { cellIndex, cell in
                            dataCell(cell)
                                .overlay(alignment: .leading) {
                                    if cellIndex > 0 {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.08))
                                            .frame(width: 0.5)
                                    }
                                }
                        }
                    }
                    .background(ImportTutorialBrokerScreenshotPalette.rowBackground)
                    .overlay(alignment: .bottom) {
                        if rowIndex < rows.count - 1 {
                            Rectangle()
                                .fill(ImportTutorialBrokerScreenshotPalette.rowDivider)
                                .frame(height: 0.5)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
        .offset(y: animate ? 0 : 10)
        .opacity(animate ? 1 : 0)
        .animation(.easeOut(duration: 0.38).delay(delay), value: animate)
    }

    private func headerCell(_ title: String, showDivider: Bool) -> some View {
        HStack(spacing: 0) {
            if showDivider {
                Text("|")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(ImportTutorialBrokerScreenshotPalette.headerText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 4)
    }

    private func dataCell(_ cell: ImportTutorialBrokerCell) -> some View {
        Text(cell.text)
            .font(.system(size: 9, weight: cell.underlined ? .semibold : .regular))
            .foregroundColor(cell.tint ?? ImportTutorialBrokerScreenshotPalette.cellText)
            .underline(cell.underlined, color: (cell.tint ?? ImportTutorialBrokerScreenshotPalette.cellText).opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 4)
    }
}

private struct ImportTutorialCopyPromptMock: View {
    let animate: Bool
    let showStatementOption: Bool

    @State private var pressedIndex: Int?
    @State private var showToast = false
    @State private var loopTask: Task<Void, Never>?

    private struct CopyOption: Identifiable {
        let id: Int
        let title: String
        let subtitle: String
        let icon: String
    }

    private var options: [CopyOption] {
        if showStatementOption {
            return [
                CopyOption(id: 0, title: "成交明細", subtitle: "適合券商匯出的成交紀錄、對帳單、PDF、Excel 或截圖", icon: "list.bullet.rectangle"),
                CopyOption(id: 1, title: "持有倉位", subtitle: "需含代號、持有數量與成本價；僅現價無法匯入", icon: "photo.on.rectangle"),
            ]
        }
        return [
            CopyOption(id: 0, title: "持有倉位", subtitle: "需含幣種、持有數量與成本價；僅現價無法匯入", icon: "photo.on.rectangle"),
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 14) {
                Text("複製提示詞")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(options) { option in
                    mockCopyRow(option: option, isPressed: pressedIndex == option.id)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AppColors.shadowMedium, radius: 10, x: 0, y: 3)

            if showToast {
                ImportTutorialCopyToast()
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: animate) { _, active in
            active ? startCopyLoop() : stopCopyLoop()
        }
        .onAppear {
            if animate { startCopyLoop() }
        }
        .onDisappear {
            stopCopyLoop()
        }
    }

    private func mockCopyRow(option: CopyOption, isPressed: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isPressed ? "checkmark.circle.fill" : option.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.appPrimary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(option.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Image(systemName: "doc.on.doc")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondaryText)
        }
        .padding(14)
        .background(isPressed ? Color.appPrimary.opacity(0.12) : Color.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.separator.opacity(0.4), lineWidth: 1)
        }
        .importTutorialHighlight(isPressed, cornerRadius: 14, prominent: true)
        .importTutorialPress(isPressed)
    }

    private func startCopyLoop() {
        stopCopyLoop()
        loopTask = Task {
            var nextIndex = 0
            while !Task.isCancelled {
                await MainActor.run {
                    pressedIndex = nil
                    showToast = false
                }

                try? await Task.sleep(for: .milliseconds(850))
                guard !Task.isCancelled else { return }

                let target = options[nextIndex].id
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        pressedIndex = target
                    }
                }

                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                        showToast = true
                    }
                }

                try? await Task.sleep(for: .milliseconds(1800))
                guard !Task.isCancelled else { return }

                nextIndex = (nextIndex + 1) % options.count
            }
        }
    }

    private func stopCopyLoop() {
        loopTask?.cancel()
        loopTask = nil
        Task { @MainActor in
            pressedIndex = nil
            showToast = false
        }
    }
}

private struct ImportTutorialAIMock: View {
    let animate: Bool
    let accountType: AccountType

    @State private var visibleStep = 0
    @State private var isThinking = false
    @State private var showResponse = false
    @State private var showCopyHint = false
    @State private var loopTask: Task<Void, Never>?

    private var sampleCSV: String {
        ImportTutorialBrokerSampleData.sampleCSV(for: accountType)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.appPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.appPrimary.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ChatGPT · Gemini（外部 App）")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.primaryText)
                        Text("貼上提示詞及附上截圖或檔案")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                }

                userPromptBubble
                    .opacity(visibleStep >= 1 ? 1 : 0)
                    .offset(x: visibleStep >= 1 ? 0 : 18)
                    .animation(.easeOut(duration: 0.32), value: visibleStep)

                userAttachmentBubble
                    .opacity(visibleStep >= 2 ? 1 : 0)
                    .offset(x: visibleStep >= 2 ? 0 : 18)
                    .animation(.easeOut(duration: 0.32), value: visibleStep)

                if isThinking {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.appPrimary)
                        Text("AI 思考中…")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondaryText)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .transition(.opacity)
                }

                if showResponse {
                    aiResponseBubble
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }

                if showCopyHint {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption.weight(.bold))
                        Text("複製 CSV 回 Walleaf")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(.appPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.appPrimary.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.appPrimary.opacity(0.45), lineWidth: 1.5)
                    }
                    .scaleEffect(showCopyHint ? 1.03 : 1)
                    .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: showCopyHint)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 10, x: 0, y: 3)
        .onChange(of: animate) { _, active in
            active ? startAILoop() : stopAILoop()
        }
        .onAppear {
            if animate { startAILoop() }
        }
        .onDisappear {
            stopAILoop()
        }
    }

    private var userPromptBubble: some View {
        HStack {
            Spacer(minLength: 28)
            VStack(alignment: .trailing, spacing: 6) {
                Text("Walleaf 匯入提示詞（示意）")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primaryText)
                Text("date,type,symbol,quantity,price…")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondaryText)
            }
            .padding(12)
            .background(Color.appPrimary.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var userAttachmentBubble: some View {
        HStack {
            Spacer(minLength: 20)
            VStack(alignment: .trailing, spacing: 6) {
                Text("持有倉位")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.appPrimary)
                ImportTutorialInlineBrokerTable(
                    columns: ImportTutorialBrokerSampleData.holdingsColumns(for: accountType),
                    rows: ImportTutorialBrokerSampleData.compactHoldingsRows(for: accountType)
                )
                .frame(width: 210)
            }
            .padding(10)
            .background(Color.appPrimary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var aiResponseBubble: some View {
        HStack {
            Text(sampleCSV)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondaryText)
                .lineLimit(4)
                .padding(12)
                .background(Color.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Spacer(minLength: 24)
        }
    }

    private func startAILoop() {
        stopAILoop()
        loopTask = Task {
            while !Task.isCancelled {
                await MainActor.run { resetAIState() }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation { visibleStep = 1 }
                }
                try? await Task.sleep(for: .milliseconds(550))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation { visibleStep = 2 }
                }
                try? await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation { isThinking = true }
                }
                try? await Task.sleep(for: .milliseconds(1200))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation {
                        isThinking = false
                        showResponse = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation { showCopyHint = true }
                }
                try? await Task.sleep(for: .milliseconds(2200))
            }
        }
    }

    private func stopAILoop() {
        loopTask?.cancel()
        loopTask = nil
        Task { @MainActor in resetAIState() }
    }

    @MainActor
    private func resetAIState() {
        visibleStep = 0
        isThinking = false
        showResponse = false
        showCopyHint = false
    }
}

private struct ImportTutorialPasteMock: View {
    let animate: Bool
    let accountType: AccountType

    @State private var pastedCSV = ""
    @State private var isPastePressed = false
    @State private var isParsePressed = false
    @State private var showPreview = false
    @State private var visiblePreviewCount = 0
    @State private var loopTask: Task<Void, Never>?

    private var sampleCSV: String {
        ImportTutorialBrokerSampleData.sampleCSV(for: accountType)
    }

    private var previewItems: [(side: String, symbol: String, detail: String)] {
        switch accountType {
        case .twdSecurities:
            return [
                ("買入", "0050", "200 股 · 152.3"),
                ("買入", "2330", "10 股 · 985"),
            ]
        case .usdAccount:
            return [
                ("買入", "NVDA", "15 股 · 175.64"),
                ("買入", "AAPL", "20 股 · 228.4"),
            ]
        case .cryptoWallet:
            return [
                ("買入", "BTC", "0.42 · 68,420"),
                ("買入", "ETH", "3.15 · 3,820"),
            ]
        default:
            return []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("貼回並匯入")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primaryText)

            Group {
                if pastedCSV.isEmpty {
                    Text("在此貼上外部 AI 回覆的 CSV…")
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                } else {
                    Text(pastedCSV)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.primaryText.opacity(0.9))
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                }
            }
            .padding(10)
            .background(Color.secondaryBackground.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.separator.opacity(0.35), lineWidth: 1)
            }
            .animation(.easeOut(duration: 0.28), value: pastedCSV)

            HStack(spacing: 8) {
                mockBorderedButton(
                    title: "從剪貼簿貼上",
                    icon: "doc.on.clipboard",
                    tint: .appPrimary,
                    isPressed: isPastePressed
                )
                mockBorderedButton(title: "清除", icon: nil, tint: .secondaryText, isPressed: false)
            }

            mockParseButton
                .importTutorialHighlight(isParsePressed, cornerRadius: 10, prominent: true)
                .importTutorialPress(isParsePressed)

            VStack(alignment: .leading, spacing: 6) {
                Text("解析預覽")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondaryText)
                    .opacity(showPreview ? 1 : 0.35)

                VStack(spacing: 6) {
                    ForEach(Array(previewItems.enumerated()), id: \.offset) { index, item in
                        previewRow(side: item.side, symbol: item.symbol, detail: item.detail)
                            .opacity(index < visiblePreviewCount ? 1 : 0)
                            .offset(y: index < visiblePreviewCount ? 0 : 8)
                            .animation(.easeOut(duration: 0.28), value: visiblePreviewCount)
                    }
                }
            }
            .opacity(showPreview ? 1 : 0)
            .offset(y: showPreview ? 0 : 6)
            .animation(.easeOut(duration: 0.3), value: showPreview)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
        .onChange(of: animate) { _, active in
            active ? startPasteLoop() : stopPasteLoop()
        }
        .onAppear {
            if animate { startPasteLoop() }
        }
        .onDisappear {
            stopPasteLoop()
        }
    }

    private func startPasteLoop() {
        stopPasteLoop()
        loopTask = Task {
            while !Task.isCancelled {
                await MainActor.run { resetPasteState() }

                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isPastePressed = true
                    }
                }

                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.32)) {
                        isPastePressed = false
                        pastedCSV = sampleCSV
                    }
                }

                try? await Task.sleep(for: .milliseconds(750))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isParsePressed = true
                    }
                }

                try? await Task.sleep(for: .milliseconds(380))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        isParsePressed = false
                        showPreview = true
                    }
                }

                for index in previewItems.indices {
                    try? await Task.sleep(for: .milliseconds(140))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.28)) {
                            visiblePreviewCount = index + 1
                        }
                    }
                }

                try? await Task.sleep(for: .milliseconds(2200))
            }
        }
    }

    private func stopPasteLoop() {
        loopTask?.cancel()
        loopTask = nil
        Task { @MainActor in resetPasteState() }
    }

    @MainActor
    private func resetPasteState() {
        pastedCSV = ""
        isPastePressed = false
        isParsePressed = false
        showPreview = false
        visiblePreviewCount = 0
    }

    private func mockBorderedButton(title: String, icon: String?, tint: Color, isPressed: Bool) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
            }
            Text(title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(tint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isPressed ? Color.appPrimary.opacity(0.12) : Color.secondaryBackground.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.separator.opacity(0.45), lineWidth: 1)
        }
        .importTutorialHighlight(isPressed, cornerRadius: 8, prominent: true)
        .importTutorialPress(isPressed)
    }

    private var mockParseButton: some View {
        Text("解析預覽")
            .font(.caption.weight(.bold))
            .foregroundColor(AppColors.actionForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.appPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func previewRow(side: String, symbol: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Text(side)
                .font(.caption2.weight(.bold))
                .foregroundColor(.profitGreen)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.profitGreen.opacity(0.12))
                .clipShape(Capsule())
            VStack(alignment: .leading, spacing: 1) {
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primaryText)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#if DEBUG
#Preview("台股匯入教學") {
    TransactionImportTutorialView(
        account: Account(
            userId: "preview",
            name: "台股證券戶",
            accountType: .twdSecurities,
            currency: .TWD
        )
    )
}
#endif
