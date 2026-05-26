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
    @State private var holdingsCompareText: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        accountHeaderCard
                        flowStepsCard
                        copyPromptButtons
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
            .task {
                await viewModel.loadTransactions(userId: account.userId)
            }
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
            
            Image(systemName: account.accountType.icon)
                .font(.title2)
                .foregroundColor(account.accountType.color)
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
    
    private var flowStepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("怎麼做？")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            importFlowStep(
                number: 1,
                title: "複製提示詞（成交明細或持倉）",
                isHighlighted: false
            )
            
            importFlowStep(
                number: 2,
                title: "到外部 AI 轉成 CSV",
                detail: "流水用「成交明細提示詞」；只有持倉截圖用「持倉建倉提示詞」。附上 PDF／Excel／照片即可。",
                footnote: "可用 ChatGPT、Gemini…",
                isHighlighted: true
            )
            
            importFlowStep(
                number: 3,
                title: "貼回並匯入",
                detail: "貼在下方 → 解析預覽 → 確認匯入。",
                isHighlighted: false
            )
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
    
    private func importFlowStep(
        number: Int,
        title: String,
        detail: String? = nil,
        footnote: String? = nil,
        isHighlighted: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isHighlighted ? .white : .appPrimary)
                .frame(width: 24, height: 24)
                .background(isHighlighted ? Color.appPrimary : Color.appPrimary.opacity(0.12))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let footnote {
                    Text(footnote)
                        .font(.caption2)
                        .foregroundColor(.tertiaryText)
                }
            }
        }
        .padding(isHighlighted ? 12 : 0)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.appPrimary.opacity(0.08))
            }
        }
    }
    
    private var copyPromptButtons: some View {
        VStack(spacing: 10) {
            copyPromptButton(
                title: didCopyStatementPrompt ? "已複製成交明細提示詞" : "複製成交明細提示詞",
                systemImage: didCopyStatementPrompt ? "checkmark.circle.fill" : "list.bullet.rectangle"
            ) {
                UIPasteboard.general.string = Self.statementPromptTemplate(account: account)
                flashCopiedPrompt(.statement)
            }
            
            copyPromptButton(
                title: didCopyHoldingsPrompt ? "已複製持倉建倉提示詞" : "複製持倉建倉提示詞",
                systemImage: didCopyHoldingsPrompt ? "checkmark.circle.fill" : "photo.on.rectangle",
                prominent: false
            ) {
                UIPasteboard.general.string = Self.holdingsSnapshotPromptTemplate(account: account)
                flashCopiedPrompt(.holdings)
            }
        }
    }
    
    private enum CopiedPromptKind { case statement, holdings }
    
    @ViewBuilder
    private func copyPromptButton(
        title: String,
        systemImage: String,
        prominent: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        if prominent {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.appPrimary)
        } else {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .tint(.appPrimary)
        }
    }
    
    private func flashCopiedPrompt(_ kind: CopiedPromptKind) {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch kind {
            case .statement:
                didCopyStatementPrompt = true
            case .holdings:
                didCopyHoldingsPrompt = true
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
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
            HStack(spacing: 8) {
                Text("3")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.appPrimary)
                    .frame(width: 20, height: 20)
                    .background(Color.appPrimary.opacity(0.12))
                    .clipShape(Circle())
                Text("貼回並匯入")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
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
    
    private var holdingsCompareDiffs: [HoldingsCompareDiff] {
        let stated = HoldingsCompareParser.parse(holdingsCompareText, defaultAssetType: nil)
        guard !stated.isEmpty else { return [] }
        return HoldingsCompareParser.compare(
            projected: projectedHoldings,
            stated: stated,
            account: account
        )
    }
    
    private var holdingsCompareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("持倉對照（選填）")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            Text("貼上券商 App 目前持倉（symbol,quantity），與下方「匯入後預期持股」比對。")
                .font(.caption)
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            TextEditor(text: $holdingsCompareText)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 72)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.secondaryBackground.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("匯入後預期持股")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondaryText)
                if projectedHoldings.isEmpty {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                } else {
                    ForEach(projectedHoldings) { holding in
                        HStack {
                            Text(holding.symbol)
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Text(holding.quantity.formattedQuantityInput(
                                maxFractionDigits: holding.assetType == .crypto ? 8 : 4
                            ))
                                .font(.caption)
                                .monospacedDigit()
                        }
                    }
                }
            }
            
            if !holdingsCompareDiffs.isEmpty {
                let allMatch = holdingsCompareDiffs.allSatisfy(\.matches)
                HStack(spacing: 6) {
                    Image(systemName: allMatch ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(allMatch ? .profitGreen : .orange)
                    Text(allMatch ? "與你提供的持倉一致" : "與你提供的持倉有差異（請檢查流水或代號）")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(allMatch ? .profitGreen : .orange)
                }
                
                ForEach(holdingsCompareDiffs.filter { !$0.matches }) { diff in
                    HStack {
                        Text(diff.symbol)
                            .font(.caption)
                        Spacer()
                        Text("匯入 \(diff.projected.map { formatCompareQty($0) } ?? "—")")
                            .font(.caption2)
                        Text("／")
                            .font(.caption2)
                            .foregroundColor(.tertiaryText)
                        Text("提供 \(diff.stated.map { formatCompareQty($0) } ?? "—")")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondaryText)
                }
            }
        }
        .padding(12)
        .background(Color.secondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func formatCompareQty(_ value: Decimal) -> String {
        value.formattedQuantityInput(maxFractionDigits: 8)
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
            validation: validation
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
            Account: Taiwan securities (台股 + 複委託同一帳戶).
            asset_type: stock_tw (台股代號) or stock_us (複委託美股代號大寫).
            台股 price=TWD/股; 複委託 price=USD/股. currency 留空.
            """
            examples = """
            \(csvHeader)
            2025-06-17,buy,stock_us,VOO,1.35879,551.96,,0,,,
            2025-07-07,sell,stock_us,AMD,30,136.3,,0,,,
            2025-01-10,buy,stock_tw,0050,100,150.5,,20,,,
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
        Convert the trade history / brokerage statement into Snapvest CSV.
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
            accountHint = "asset_type: stock_tw or stock_us. 台股 price=TWD; 複委託 price=USD."
            example = "\(csvHeader)\n\(today),buy,stock_tw,0050,100,150.5,,0,,,"
        case .usdAccount:
            accountHint = "asset_type=stock_us, price=USD per share."
            example = "\(csvHeader)\n\(today),buy,stock_us,VOO,1.5,520,,0,,,"
        default:
            accountHint = "Set asset_type per holding."
            example = "\(csvHeader)\n\(today),buy,stock_tw,2330,10,100,,0,,,"
        }
        
        return """
        Extract CURRENT holdings from the screenshot / portfolio view into Snapvest CSV.
        Output RAW CSV only (header + rows). No markdown, no explanation.

        Rules:
        - Header exactly: \(csvHeader)
        - type: buy ONLY (one row per held symbol)
        - date: use \(today) unless the image shows another as-of date (YYYY-MM-DD)
        - quantity: shares held now
        - price: cost per share or average cost; REQUIRED, > 0. If unknown, leave price empty.
        - Do NOT invent sell rows or trade history.
        - Leave optional fields empty (keep commas).

        \(accountHint)

        Example:
        \(example)

        User image / data:
        """
    }
}
