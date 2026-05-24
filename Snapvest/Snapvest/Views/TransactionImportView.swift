//
//  TransactionImportView.swift
//  Snapvest
//
//  於帳戶詳情匯入 CSV 交易流水（貼上 AI 產出的 CSV 文字）
//

import SwiftUI
import UniformTypeIdentifiers

struct TransactionImportView: View {
    let account: Account
    @ObservedObject var viewModel: TransactionsViewModel
    var onFinished: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var csvText: String = ""
    @State private var parseResult: TransactionImportParseResult?
    @State private var validationResult: TransactionImportValidationResult?
    @State private var previewRows: [TransactionImportValidatedRow] = []
    @State private var importBuyDraftItem: ImportBuyDraftSheetItem?
    @State private var importSellDraftItem: ImportSellDraftSheetItem?
    @State private var showingFileImporter = false
    @State private var showingPromptSheet = false
    @State private var isImporting = false
    @State private var showingImportResultAlert = false
    @State private var importResultAlertTitle = ""
    @State private var importResultAlertMessage = ""
    @State private var dismissAfterImportResultAlert = false
    @State private var copiedPrompt = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    instructionCard
                    actionButtons
                    pasteSection
                    
                    if let fatal = parseResult?.fatalError {
                        errorBanner(fatal)
                    }
                    
                    if !previewRows.isEmpty {
                        previewSection
                    }
                    
                }
                .padding()
            }
            .background(Color.mainBackground)
            .alert(importResultAlertTitle, isPresented: $showingImportResultAlert) {
                Button("好") {
                    if dismissAfterImportResultAlert {
                        dismiss()
                    }
                }
            } message: {
                Text(importResultAlertMessage)
            }
            .navigationTitle("匯入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") { dismiss() }
                        .foregroundColor(.appPrimary)
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText, .utf8PlainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showingPromptSheet) {
                aiPromptSheet
            }
            .sheet(item: $importBuyDraftItem) { item in
                importBuyDraftSheet(item: item)
            }
            .sheet(item: $importSellDraftItem) { item in
                importSellDraftSheet(item: item)
            }
            .task {
                if viewModel.accounts.isEmpty {
                    await viewModel.loadTransactions(userId: account.userId)
                }
            }
        }
    }
    
    private var instructionCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                Text("匯入至：\(account.name)")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Text("建議流程（手機）：")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. 複製 AI 提示詞 → 到 ChatGPT / Claude 貼上")
                    Text("2. 附上對帳單 PDF、Excel 或照片")
                    Text("3. 複製 AI 回覆的 CSV → 貼到下方 → 解析預覽")
                    Text("4. 點擊明細檢查／修改 → 確認匯入")
                }
                .font(.caption)
                .foregroundColor(.secondaryText)
                
                Text("所有交易會寫入此帳戶，CSV 不需要 account_name。僅匯入股票買賣（buy/sell）；存入、提取等會自動略過。")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .padding(.top, 4)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                showingPromptSheet = true
            } label: {
                Label("步驟 1：複製 AI 提示詞（英文）", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.appPrimary)
            
            Button {
                showingFileImporter = true
            } label: {
                Label("或從檔案選擇 CSV", systemImage: "doc.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.appPrimary)
        }
    }
    
    private var pasteSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("步驟 3：貼上 AI 產出的 CSV")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                TextEditor(text: $csvText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 160)
                    .padding(8)
                    .background(Color.cardBackground.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.separator.opacity(0.35), lineWidth: 1)
                    )
                
                if csvText.isEmpty {
                    Text("從 AI 複製 CSV 後，點「從剪貼簿貼上」或長按貼上。可含標題列，也可直接貼資料列。")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                HStack(spacing: 10) {
                    Button {
                        if let pasted = UIPasteboard.general.string, !pasted.isEmpty {
                            csvText = pasted
                        }
                    } label: {
                        Label("從剪貼簿貼上", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.appPrimary)
                    
                    Button {
                        csvText = ""
                        parseResult = nil
                        validationResult = nil
                        previewRows = []
                    } label: {
                        Text("清除")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondaryText)
                }
                
                Button {
                    revalidateCSV()
                } label: {
                    Text("解析預覽")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.appPrimary)
                .disabled(csvText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private struct ImportPreviewDayGroup: Identifiable {
        let id: Date
        let day: Date
        let rows: [TransactionImportValidatedRow]
    }
    
    private struct ImportBuyDraftSheetItem: Identifiable {
        let lineNumber: Int
        let transaction: Transaction
        let market: TradeMarket
        var id: String { "buy-\(lineNumber)-\(transaction.id)" }
    }
    
    private struct ImportSellDraftSheetItem: Identifiable {
        let lineNumber: Int
        let transaction: Transaction
        let market: TradeMarket
        var id: String { "sell-\(lineNumber)-\(transaction.id)" }
    }
    
    private var currentValidation: TransactionImportValidationResult {
        TransactionImportService.validationResult(from: previewRows)
    }
    
    private var previewErrorRows: [TransactionImportValidatedRow] {
        previewRows.filter { $0.errorMessage != nil }
    }
    
    private var previewDayGroups: [ImportPreviewDayGroup] {
        let calendar = Calendar.current
        let validRows = previewRows.filter { row in
            guard row.isValid, let type = row.transaction?.type else { return false }
            return type == .buy || type == .sell
        }
        let grouped = Dictionary(grouping: validRows) { row in
            calendar.startOfDay(for: row.transaction!.transactionDate)
        }
        return grouped.keys.sorted().map { day in
            ImportPreviewDayGroup(
                id: day,
                day: day,
                rows: grouped[day]!.sorted { $0.lineNumber < $1.lineNumber }
            )
        }
    }
    
    private var previewSection: some View {
        let validation = currentValidation
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("預覽（\(validation.importableCount) 筆）")
                    .font(.headline)
                if validation.errorCount > 0 {
                    Text("· \(validation.errorCount) 列錯誤")
                        .font(.subheadline)
                        .foregroundColor(.lossRed)
                }
                if !validation.skippedRows.isEmpty {
                    Text("· 略過 \(validation.skippedRows.count) 筆")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }
            
            if parseResult?.usedImplicitHeader == true {
                Text("已自動辨識為無標題列（依固定欄位順序解析）。")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Text("點擊買入／賣出明細可檢查並修改，確認後再匯入。")
                .font(.caption)
                .foregroundColor(.secondaryText)
            
            if !previewErrorRows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("需修正")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.lossRed)
                    ForEach(previewErrorRows) { row in
                        ImportPreviewRowView(row: row, onTap: nil)
                    }
                }
            }
            
            ForEach(previewDayGroups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    TransactionDateSectionHeader(date: group.day, count: group.rows.count)
                    ForEach(group.rows) { row in
                        ImportPreviewRowView(row: row) {
                            openDraftEditor(for: row)
                        }
                    }
                }
            }
            
            if !validation.skippedRows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("已略過（不入庫）")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondaryText)
                    ForEach(validation.skippedRows) { row in
                        ImportPreviewRowView(row: row, onTap: nil)
                    }
                }
            }
            
            Button {
                Task { await runImport(validation) }
            } label: {
                if isImporting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("確認匯入 \(validation.importableCount) 筆")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.appPrimary)
            .disabled(!validation.canImport || isImporting)
        }
    }
    
    private func openDraftEditor(for row: TransactionImportValidatedRow) {
        guard let transaction = row.transaction,
              let market = TradeMarket(assetType: transaction.assetType) else { return }
        switch transaction.type {
        case .buy:
            importBuyDraftItem = ImportBuyDraftSheetItem(
                lineNumber: row.lineNumber,
                transaction: transaction,
                market: market
            )
        case .sell:
            importSellDraftItem = ImportSellDraftSheetItem(
                lineNumber: row.lineNumber,
                transaction: transaction,
                market: market
            )
        default:
            break
        }
    }
    
    private func applyDraftUpdate(lineNumber: Int, updated: Transaction) {
        guard let index = previewRows.firstIndex(where: { $0.lineNumber == lineNumber }) else { return }
        previewRows[index] = TransactionImportService.validatedRow(
            from: updated,
            lineNumber: lineNumber,
            account: account
        )
        validationResult = currentValidation
    }
    
    private func importBuyDraftSheet(item: ImportBuyDraftSheetItem) -> some View {
        NavigationStack {
            BuyTradeFormView(
                market: item.market,
                editingTransaction: item.transaction,
                isImportDraftMode: true,
                onImportDraftSave: { updated in
                    applyDraftUpdate(lineNumber: item.lineNumber, updated: updated)
                },
                onSubmit: {
                    importBuyDraftItem = nil
                }
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        importBuyDraftItem = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }
            }
        }
        .background(Color.mainBackground)
        .presentationBackground(Color.mainBackground)
    }
    
    private func importSellDraftSheet(item: ImportSellDraftSheetItem) -> some View {
        NavigationStack {
            SellTradeFormView(
                market: item.market,
                editingTransaction: item.transaction,
                isImportDraftMode: true,
                onImportDraftSave: { updated in
                    applyDraftUpdate(lineNumber: item.lineNumber, updated: updated)
                },
                onSubmit: { _ in
                    importSellDraftItem = nil
                }
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        importSellDraftItem = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }
            }
        }
        .background(Color.mainBackground)
        .presentationBackground(Color.mainBackground)
    }
    
    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.lossRed)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.lossRed.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var aiPromptSheet: some View {
        NavigationStack {
            ScrollView {
                Text(Self.aiPromptTemplate(account: account))
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.mainBackground)
            .navigationTitle("AI Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") { showingPromptSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(copiedPrompt ? "Copied" : "Copy") {
                        UIPasteboard.general.string = Self.aiPromptTemplate(account: account)
                        copiedPrompt = true
                    }
                }
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            parseResult = TransactionImportParseResult(rows: [], fatalError: error.localizedDescription, usedImplicitHeader: false)
            validationResult = nil
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                parseResult = TransactionImportParseResult(rows: [], fatalError: "無法讀取檔案權限", usedImplicitHeader: false)
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
                    parseResult = TransactionImportParseResult(rows: [], fatalError: "無法解析檔案編碼（請使用 UTF-8 CSV）", usedImplicitHeader: false)
                    validationResult = nil
                    return
                }
                csvText = text
                revalidateCSV()
            } catch {
                parseResult = TransactionImportParseResult(rows: [], fatalError: error.localizedDescription, usedImplicitHeader: false)
                validationResult = nil
            }
        }
    }
    
    private func revalidateCSV() {
        let parsed = TransactionImportCSVParser.parse(csvText)
        parseResult = parsed
        guard parsed.fatalError == nil else {
            validationResult = nil
            previewRows = []
            return
        }
        validationResult = TransactionImportService.validate(
            parsedRows: parsed.rows,
            account: account,
            allAccounts: viewModel.accounts
        )
        previewRows = validationResult?.rows ?? []
    }
    
    private func runImport(_ validation: TransactionImportValidationResult) async {
        isImporting = true
        let result = await viewModel.importValidatedTransactions(
            userId: account.userId,
            validation: validation
        )
        isImporting = false
        
        importResultAlertTitle = result.alertTitle
        importResultAlertMessage = result.alertMessage
        dismissAfterImportResultAlert = result.isFullSuccess
        if result.imported > 0 {
            onFinished()
        }
        showingImportResultAlert = true
    }
    
    static func aiPromptTemplate(account: Account) -> String {
        let header = "date,type,asset_type,symbol,quantity,price,currency,fee,target_account_name,exchange_rate,notes,deduct_from_account"
        
        let sharedRules = """
        Convert the brokerage statement into Snapvest CSV. Output RAW CSV only (header + rows). No markdown, no explanation.

        All rows import into the CURRENT account already selected in the app.
        Do NOT output account names or other Snapvest account labels in any field.
        For buy/sell: leave target_account_name, exchange_rate, notes empty unless the statement shows them.
        For buy: leave deduct_from_account empty (defaults to NOT deducting from account cash).

        ONLY output buy and sell rows (stock trades). Do NOT output deposit, withdraw, dividend, or transfer.
        Ignore cash ledger sections (e.g. 交割專戶, e財庫, 授扣入金, 授扣提款, 資金異動). Use ONLY the securities trade table (有價證券買賣).
        One trade = one buy/sell row. Do not duplicate settlement/cash entries for the same trade.

        Header (exactly 12 columns):
        \(header)

        type: buy or sell only
        date: YYYY-MM-DD, sorted ascending
        Leave unknown fields empty (keep commas).
        """
        
        switch account.accountType {
        case .twdSecurities:
            return sharedRules + """

            Account: TWD securities (台幣證券戶) — includes 台股 AND sub-brokerage 複委託 in the SAME account.

            Source: ONLY parse「有價證券買賣」/ securities trade sections. Skip「交割專戶」「e財庫」and all cash in/out lines.

            asset_type:
            - 台股 → stock_tw, symbol digits (0050)
            - 複委託 US stocks → stock_us, symbol UPPERCASE (VOO, QQQ)

            KGI 凱基 mapping (有價證券買賣 table):
            - 成交日 → date
            - 交易類別 買進/賣出 → buy/sell
            - 股票代碼 → symbol
            - 數量 → quantity
            - 單價 → price (TWD for 台股)
            - 手續費 → fee

            Cathay 國泰複委託 mapping:
            - 成交時間 → date
            - 買進/賣出 → buy/sell
            - 代號 → symbol
            - 成交均價 → price (USD per share, NOT TWD)
            - 成交股數 → quantity (fractional OK)

            複委託 buy/sell: currency empty. Do NOT write TWD. Do NOT put 美股帳戶 or any account name anywhere.

            台股 buy/sell: price in TWD, currency empty.

            Examples:
            \(header)
            2025-06-17,buy,stock_us,VOO,1.35879,551.96,,0,,,
            2025-07-07,sell,stock_us,AMD,30,136.3,,0,,,
            2025-01-10,buy,stock_tw,0050,100,150.5,,20,,,

            User statement:
            """
            
        case .usdAccount:
            return sharedRules + """

            Account: USD account (美金帳戶) — US stocks only.

            asset_type: stock_us. symbol UPPERCASE.
            buy/sell: price in USD, currency empty.
            Do NOT output deposit or withdraw.

            Examples:
            \(header)
            2025-01-15,buy,stock_us,AAPL,10,185.20,,1,,,
            2025-02-01,buy,stock_us,AAPL,0.0523,189.50,,0,,,

            User statement:
            """
            
        default:
            return sharedRules
        }
    }
}
