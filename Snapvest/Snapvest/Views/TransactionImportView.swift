//
//  TransactionImportView.swift
//  Snapvest
//
//  於帳戶詳情匯入交易（貼上 AI 產出的 CSV 文字）
//

import SwiftUI

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
    @State private var isImporting = false
    @State private var isValidatingPrices = false
    @State private var showingImportResultAlert = false
    @State private var importResultAlertTitle = ""
    @State private var importResultAlertMessage = ""
    @State private var dismissAfterImportResultAlert = false
    @State private var didCopyStatementPrompt = false
    @State private var didCopyHoldingsPrompt = false
    @FocusState private var isCSVFocused: Bool
    @State private var scrollToPreviewTrigger = 0
    @State private var duplicateMatches: [Int: TransactionDuplicateMatch] = [:]
    @State private var duplicateImportOverrides: Set<Int> = []
    @State private var projectedHoldings: [ImportProjectedHolding] = []
    @State private var showingImportTutorial = false
    @State private var copyToastMessage: String?
    
    private var supportsStatementPrompt: Bool {
        account.accountType != .cryptoWallet
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        accountHeaderCard
                        flowStepsCard
                        pasteSection
                        
                        if let fatal = parseResult?.fatalError {
                            errorBanner(fatal)
                        }
                        
                        if !previewRows.isEmpty {
                            previewSection
                                .id("import-preview")
                        }
                    }
                    .padding()
                }
                .snapFormScrollDismissesKeyboard()
                .background(Color.mainBackground)
                .onChange(of: scrollToPreviewTrigger) { _, _ in
                    guard !previewRows.isEmpty else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo("import-preview", anchor: .top)
                        }
                    }
                }
            }
            .alert(importResultAlertTitle, isPresented: $showingImportResultAlert) {
                Button("好") {
                    if dismissAfterImportResultAlert {
                        dismiss()
                    }
                }
            } message: {
                Text(importResultAlertMessage)
            }
            .navigationTitle("匯入交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") { dismiss() }
                        .foregroundColor(.appPrimary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        isCSVFocused = false
                        KeyboardDismiss.dismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
            .sheet(item: $importBuyDraftItem) { item in
                importBuyDraftSheet(item: item)
            }
            .sheet(item: $importSellDraftItem) { item in
                importSellDraftSheet(item: item)
            }
            .sheet(isPresented: $showingImportTutorial) {
                TransactionImportTutorialView(account: account)
            }
            .task {
                await viewModel.loadTransactions(userId: account.userId)
            }
            .overlay(alignment: .bottom) {
                if let copyToastMessage {
                    ClipboardCopyToast(message: copyToastMessage)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: copyToastMessage)
        }
        .snapDismissKeyboardOnTap()
    }
    
    // MARK: - Header & Flow
    
    private var accountHeaderCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(account.accountType.color)
                .frame(width: 4, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("匯入至")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                Text(account.name)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                Text(account.accountType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            CurrencyIconBadge(
                currency: account.currency,
                tint: account.accountType.color
            )
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
    
    private var flowStepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text("複製提示詞")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Spacer(minLength: 8)
                
                importTutorialButton
            }
            
            copyPromptOptions
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
    
    private var importTutorialButton: some View {
        Button {
            showingImportTutorial = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.body.weight(.semibold))
                Text("圖文教學")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.appPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.appPrimary.opacity(0.14))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.appPrimary.opacity(0.32), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("匯入圖文教學")
    }
    
    private var copyPromptOptions: some View {
        VStack(spacing: 8) {
            if supportsStatementPrompt {
                copyPromptOptionButton(
                    title: "成交明細",
                    subtitle: "適合券商匯出的成交紀錄、對帳單、PDF、Excel 或截圖",
                    isCopied: didCopyStatementPrompt,
                    systemImage: "list.bullet.rectangle"
                ) {
                    UIPasteboard.general.string = Self.statementPromptTemplate(account: account)
                    flashCopiedPrompt(.statement)
                }
            }
            
            copyPromptOptionButton(
                title: "持有倉位",
                subtitle: account.accountType == .cryptoWallet
                    ? "需含幣種、持有數量與成本價；僅現價無法匯入"
                    : "需含代號、持有數量與成本價；僅現價無法匯入",
                isCopied: didCopyHoldingsPrompt,
                systemImage: "photo.on.rectangle"
            ) {
                UIPasteboard.general.string = Self.holdingsSnapshotPromptTemplate(account: account)
                flashCopiedPrompt(.holdings)
            }
        }
    }
    
    private enum CopiedPromptKind { case statement, holdings }
    
    private func copyPromptOptionButton(
        title: String,
        subtitle: String,
        isCopied: Bool,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isCopied ? "checkmark.circle.fill" : systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.appPrimary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(isCopied ? "已複製提示詞" : title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 8)
                
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isCopied ? Color.appPrimary.opacity(0.12) : Color.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isCopied ? Color.appPrimary.opacity(0.35) : Color.separator.opacity(0.4), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func flashCopiedPrompt(_ kind: CopiedPromptKind) {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        withAnimation(.easeInOut(duration: 0.2)) {
            copyToastMessage = "已複製到剪貼簿"
            switch kind {
            case .statement:
                didCopyStatementPrompt = true
            case .holdings:
                didCopyHoldingsPrompt = true
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    copyToastMessage = nil
                }
            }
            try? await Task.sleep(for: .seconds(0.5))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    switch kind {
                    case .statement: didCopyStatementPrompt = false
                    case .holdings: didCopyHoldingsPrompt = false
                    }
                }
            }
        }
    }
    
    private var pasteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("貼回並匯入")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $csvText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 168)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.secondaryBackground.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.separator.opacity(0.35), lineWidth: 1)
                    )
                    .focused($isCSVFocused)
                
                if csvText.isEmpty {
                    Text("把 AI 回覆貼在這裡，再按「解析預覽」")
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
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
                    duplicateMatches = [:]
                    duplicateImportOverrides = []
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
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
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
    
    private var previewDuplicateRows: [TransactionImportValidatedRow] {
        previewRows
            .filter { row in
                row.isValid && duplicateMatches[row.lineNumber] != nil
            }
            .sorted { $0.lineNumber < $1.lineNumber }
    }
    
    private var effectiveImportCount: Int {
        previewRows.filter(isRowScheduledForImport).count
    }
    
    private var skippedDuplicateCount: Int {
        duplicateMatches.keys.filter { !duplicateImportOverrides.contains($0) }.count
    }
    
    private var canConfirmImport: Bool {
        previewErrorRows.isEmpty && effectiveImportCount > 0 && !isValidatingPrices && !isImporting
    }
    
    private func isRowScheduledForImport(_ row: TransactionImportValidatedRow) -> Bool {
        guard row.isValid else { return false }
        if duplicateMatches[row.lineNumber] != nil {
            return duplicateImportOverrides.contains(row.lineNumber)
        }
        return true
    }
    
    private var previewDayGroups: [ImportPreviewDayGroup] {
        let calendar = Calendar.current
        let validRows = previewRows.filter { row in
            guard isRowScheduledForImport(row), let type = row.transaction?.type else { return false }
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
        return VStack(alignment: .leading, spacing: 16) {
            if !previewErrorRows.isEmpty {
                previewErrorSection
            }
            
            if !previewDuplicateRows.isEmpty {
                previewDuplicateSection
            }
            
            if effectiveImportCount > 0 || isValidatingPrices {
                importablePreviewSection(validation: validation)
            } else if !isValidatingPrices,
                      previewErrorRows.isEmpty,
                      previewDuplicateRows.count == previewRows.filter(\.isValid).count,
                      !previewRows.isEmpty {
                Text("所有可匯入列皆被標記為重複且預設略過。若確定要匯入，請在上方改為「仍要匯入」。")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            } else if !isValidatingPrices, previewErrorRows.count == previewRows.count {
                Text("所有列皆需修正或已移除，請編輯錯誤列或重新貼上 CSV。")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            if !projectedHoldings.isEmpty, effectiveImportCount > 0 {
                holdingsCompareSection
            }
            
            importActionSection(validation: validation)
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
    
    private var holdingsCompareSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appPrimary)
                    .frame(width: 28, height: 28)
                    .background(Color.appPrimary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("匯入後預計持股")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)
                    Text("依照既有交易與本次預覽，匯入後帳戶會留下的數量。")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            
            VStack(spacing: 8) {
                if projectedHoldings.isEmpty {
                    Text("—")
                        .font(.subheadline)
                        .foregroundColor(.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(projectedHoldings) { holding in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(holding.symbol)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primaryText)
                                Text(holding.assetType.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            Spacer()
                            
                            Text(projectedHoldingQuantityText(holding))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.appPrimary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.secondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func projectedHoldingQuantityText(_ holding: ImportProjectedHolding) -> String {
        let digits = holding.assetType == .crypto ? 8 : 4
        let unit = holding.assetType == .crypto ? "單位" : "股"
        return "\(holding.quantity.formattedQuantityInput(maxFractionDigits: digits)) \(unit)"
    }
    
    private var previewErrorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.lossRed)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(previewErrorRows.count) 筆需修正")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.lossRed)
                    Text("含格式錯誤、缺成本價，或賣出超過可賣股數。請點列編輯，或移除後再匯入。")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.lossRed.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            ForEach(previewErrorRows) { row in
                ImportPreviewRowView(
                    row: row,
                    onTap: row.transaction != nil ? { openDraftEditor(for: row) } : nil,
                    onRemove: { removeRowFromPreview(lineNumber: row.lineNumber) }
                )
            }
        }
        .id("import-errors")
    }
    
    private var previewDuplicateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(previewDuplicateRows.count) 筆可能重複")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    Text("預設略過重複交易。若確定要再匯入一筆相同紀錄，請改為「仍要匯入」。")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            ForEach(previewDuplicateRows) { row in
                if let match = duplicateMatches[row.lineNumber] {
                    ImportDuplicateRowView(
                        row: row,
                        match: match,
                        importDespiteDuplicate: duplicateImportOverrides.contains(row.lineNumber),
                        onTap: { openDraftEditor(for: row) },
                        onToggleImport: { importDespiteDuplicate in
                            setDuplicateImportOverride(
                                lineNumber: row.lineNumber,
                                importDespiteDuplicate: importDespiteDuplicate
                            )
                        }
                    )
                }
            }
        }
        .id("import-duplicates")
    }
    
    private func importablePreviewSection(validation: TransactionImportValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("可匯入（\(effectiveImportCount) 筆）")
                    .font(.headline)
                if !validation.skippedRows.isEmpty {
                    Text("· 略過 \(validation.skippedRows.count) 筆")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }
            
            Text("點一筆可改價格、股數，確認後再匯入。")
                .font(.caption)
                .foregroundColor(.secondaryText)
            
            if isValidatingPrices {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("驗證股價中…")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }
            
            ForEach(previewDayGroups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    TransactionDateSectionHeader(date: group.day, count: group.rows.count)
                    ForEach(group.rows) { row in
                        ImportPreviewRowView(row: row, onTap: {
                            openDraftEditor(for: row)
                        })
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
        }
    }
    
    private func importActionSection(validation: TransactionImportValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if validation.errorCount > 0 {
                Text("尚有 \(validation.errorCount) 筆需修正，修正或移除後才能匯入。")
                    .font(.caption)
                    .foregroundColor(.lossRed)
            } else if skippedDuplicateCount > 0 {
                Text("將略過 \(skippedDuplicateCount) 筆可能重複的交易。")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Button {
                Task { await runImport() }
            } label: {
                if isImporting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if skippedDuplicateCount > 0 {
                    Text("確認匯入 \(effectiveImportCount) 筆（略過 \(skippedDuplicateCount) 筆重複）")
                        .frame(maxWidth: .infinity)
                } else {
                    Text("確認匯入 \(effectiveImportCount) 筆")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.appPrimary)
            .disabled(!canConfirmImport)
        }
    }
    
    private func setDuplicateImportOverride(lineNumber: Int, importDespiteDuplicate: Bool) {
        if importDespiteDuplicate {
            duplicateImportOverrides.insert(lineNumber)
        } else {
            duplicateImportOverrides.remove(lineNumber)
        }
        applyLedgerSimulationToPreview()
    }
    
    private func applyDuplicateCheck() {
        let existing = viewModel.transactions.filter { $0.accountId == account.id }
        duplicateMatches = TransactionDuplicateChecker.duplicateMatches(
            for: previewRows,
            existingTransactions: existing
        )
        duplicateImportOverrides = duplicateImportOverrides.filter { duplicateMatches[$0] != nil }
    }
    
    private func removeRowFromPreview(lineNumber: Int) {
        previewRows.removeAll { $0.lineNumber == lineNumber }
        duplicateMatches.removeValue(forKey: lineNumber)
        duplicateImportOverrides.remove(lineNumber)
        validationResult = currentValidation
        applyDuplicateCheck()
        applyLedgerSimulationToPreview()
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
        Task { await applyPriceValidationToPreview() }
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
                onImportDraftRemove: {
                    removeRowFromPreview(lineNumber: item.lineNumber)
                    importBuyDraftItem = nil
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
        .snapFormSheetChrome()
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
                onImportDraftRemove: {
                    removeRowFromPreview(lineNumber: item.lineNumber)
                    importSellDraftItem = nil
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
        .snapFormSheetChrome()
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
    
    private func revalidateCSV() {
        isCSVFocused = false
        duplicateMatches = [:]
        duplicateImportOverrides = []
        projectedHoldings = []
        
        let parsed = TransactionImportCSVParser.parse(csvText)
        parseResult = parsed
        guard parsed.fatalError == nil else {
            validationResult = nil
            previewRows = []
            return
        }
        let syncResult = TransactionImportService.validate(
            parsedRows: parsed.rows,
            account: account
        )
        validationResult = syncResult
        previewRows = syncResult.rows
        scrollToPreviewTrigger += 1
        Task { await applyPriceValidationToPreview() }
    }
    
    @MainActor
    private func applyPriceValidationToPreview() async {
        guard let syncResult = validationResult else { return }
        isValidatingPrices = true
        defer { isValidatingPrices = false }
        
        let pricedResult = await TransactionImportService.applyPriceValidation(to: syncResult)
        validationResult = pricedResult
        previewRows = pricedResult.rows
        applyDuplicateCheck()
        applyLedgerSimulationToPreview()
        scrollToPreviewTrigger += 1
    }
    
    private func applyLedgerSimulationToPreview() {
        let existing = viewModel.transactions.filter { $0.accountId == account.id }
        let scheduled: [(lineNumber: Int, transaction: Transaction)] = previewRows
            .filter(isRowScheduledForImport)
            .compactMap { row in
                guard let transaction = row.transaction,
                      transaction.type == .buy || transaction.type == .sell else { return nil }
                return (row.lineNumber, transaction)
            }
        
        let simulation = ImportLedgerSimulator.simulate(
            account: account,
            existingTransactions: existing,
            scheduledImports: scheduled
        )
        projectedHoldings = simulation.projectedHoldings
        previewRows = TransactionImportService.applyLedgerSimulation(
            rows: previewRows,
            simulation: simulation
        )
        validationResult = currentValidation
    }
    
    private func runImport() async {
        let rowsToImport = previewRows.filter(isRowScheduledForImport)
        let validation = TransactionImportValidationResult(rows: rowsToImport)
        isImporting = true
        let result = await viewModel.importValidatedTransactions(
            userId: account.userId,
            validation: validation,
            assumePricesValidated: true
        )
        isImporting = false
        
        importResultAlertTitle = result.alertTitle
        importResultAlertMessage = importResultMessage(from: result, validation: validation)
        dismissAfterImportResultAlert = result.isFullSuccess
        if result.imported > 0 {
            onFinished()
        }
        if result.isFullSuccess {
            clearPreviewAfterSuccessfulImport()
        }
        showingImportResultAlert = true
    }
    
    /// 匯入完成後不再對同一批預覽重跑重複檢查（否則會對到剛寫入的列）。
    private func clearPreviewAfterSuccessfulImport() {
        duplicateMatches = [:]
        duplicateImportOverrides = []
        previewRows = []
        projectedHoldings = []
        validationResult = nil
    }
    
    private func importResultMessage(
        from result: TransactionImportBatchResult,
        validation: TransactionImportValidationResult
    ) -> String {
        var lines = result.alertMessage.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let cashSkippedCount = validation.skippedRows.filter { row in
            guard let type = row.transaction?.type else { return false }
            return type == .deposit || type == .withdraw
        }.count
        if cashSkippedCount > 0 {
            lines.append("略過 \(cashSkippedCount) 筆存入／提領（此匯入僅支援買賣）")
        }
        return lines.joined(separator: "\n")
    }
    
    private static let csvHeader = "date,type,asset_type,symbol,quantity,price,currency,fee,target_account_name,exchange_rate,notes,deduct_from_account"
    
    static func statementPromptTemplate(account: Account) -> String {
        let accountHint: String
        let examples: String
        switch account.accountType {
        case .twdSecurities:
            accountHint = """
            Account: Taiwan securities ONLY.
            asset_type: stock_tw only. Do NOT include US stocks or crypto rows.
            台股 price=TWD/股. currency 留空.
            """
            examples = """
            \(csvHeader)
            2025-01-10,buy,stock_tw,0050,100,150.5,,20,,,
            2025-02-18,sell,stock_tw,2330,10,880,,20,,,
            """
        case .usdAccount:
            accountHint = "Account: US stocks ONLY (asset_type=stock_us). Do NOT use stock_tw or Taiwan numeric symbols."
            examples = """
            \(csvHeader)
            2025-01-15,buy,stock_us,AAPL,10,185.2,,1,,,
            2025-02-01,sell,stock_us,AAPL,5,190,,0,,,
            """
        default:
            accountHint = "Match asset_type to the statement."
            examples = "\(csvHeader)\n"
        }
        
        return """
        Convert the trade history / brokerage statement into Walleaf CSV.
        Output RAW CSV only (header + data rows). No markdown, no explanation.

        Rules:
        - Header exactly: \(csvHeader)
        - type: buy or sell only (include ALL sells from the statement)
        - date: YYYY-MM-DD, ascending
        - price: required, > 0 (per-share). Leave empty only if truly unknown.
        - Ignore cash movements (deposits, withdrawals, 交割專戶). Securities trades only.
        - All rows go to the account already selected in the app; leave target_account_name empty.
        - buy: leave deduct_from_account empty (do not deduct cash by default).
        - Leave unknown optional fields empty (keep commas).

        \(accountHint)

        Examples:
        \(examples)

        User data:
        """
    }
    
    static func holdingsSnapshotPromptTemplate(account: Account) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let today = formatter.string(from: Date())
        let accountHint: String
        let example: String
        switch account.accountType {
        case .twdSecurities:
            accountHint = "asset_type=stock_tw only. 台股 price=TWD."
            example = "\(csvHeader)\n\(today),buy,stock_tw,0050,100,150.5,,0,,,"
        case .usdAccount:
            accountHint = "asset_type=stock_us, price=USD per share."
            example = "\(csvHeader)\n\(today),buy,stock_us,VOO,1.5,520,,0,,,"
        case .cryptoWallet:
            accountHint = """
            asset_type=crypto only.
            symbol: use uppercase crypto tickers from the screenshot, e.g. BTC, ETH, SOL, USDT.
            quantity: exact coin amount shown.
            price: USD/USDT cost per coin or average cost. If only total cost is shown, compute price = total cost / quantity. If cost is truly unavailable, use current value / quantity and add notes="缺少成本價，使用目前估值".
            currency: leave empty or use USD.
            fee: 0 unless the image clearly shows a fee.
            """
            example = "\(csvHeader)\n\(today),buy,crypto,BTC,0.03634362,87283.68,,0,,,,false\n\(today),buy,crypto,USDT,0.4825466,1,,0,,,,false"
        default:
            accountHint = "Set asset_type per holding."
            example = "\(csvHeader)\n\(today),buy,stock_tw,2330,10,100,,0,,,"
        }
        
        let title = account.accountType == .cryptoWallet
            ? "Extract CURRENT crypto holdings from the exchange screenshot / asset page into Walleaf CSV."
            : "Extract CURRENT holdings from the screenshot / portfolio view into Walleaf CSV."
        
        return """
        \(title)
        Output RAW CSV only (header + rows). No markdown, no explanation.

        Rules:
        - Header exactly: \(csvHeader)
        - type: buy ONLY (one row per held symbol)
        - date: use \(today) unless the image shows another as-of date (YYYY-MM-DD)
        - quantity: units held now
        - price: cost per unit or average cost; REQUIRED, > 0. If unknown, follow the account-specific rule below.
        - Do NOT invent sell rows or trade history.
        - Leave optional fields empty (keep commas).

        \(accountHint)

        Example:
        \(example)

        User image / data:
        """
    }
}

private struct ClipboardCopyToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundColor(.primaryText)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: AppColors.shadowMedium, radius: 10, x: 0, y: 4)
        .accessibilityLabel(message)
    }
}
