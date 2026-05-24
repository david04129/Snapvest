//
//  TransactionImportCSVParser.swift
//  Snapvest
//
//  Snapvest Import CSV v1 解析
//

import Foundation

/// 從 CSV 解析出的單列（尚未對應帳戶）
struct TransactionImportParsedRow: Identifiable, Equatable {
    let id: Int
    let lineNumber: Int
    let date: Date?
    let type: TransactionType?
    let accountName: String
    let assetType: AssetType?
    let symbol: String
    let quantity: Decimal?
    let price: Decimal?
    let currency: Currency?
    let fee: Decimal
    let targetAccountName: String?
    let exchangeRate: Decimal?
    let notes: String?
    let deductFromAccount: Bool
    let rawFields: [String: String]
}

struct TransactionImportParseResult: Equatable {
    let rows: [TransactionImportParsedRow]
    let fatalError: String?
    /// 第一行不是標題列，已依固定欄位順序解析
    let usedImplicitHeader: Bool
}

enum TransactionImportCSVParser {
    static let requiredHeaders: [String] = [
        "date", "type", "quantity", "price"
    ]
    
    static let optionalHeaders: [String] = [
        "asset_type", "symbol", "currency", "fee", "target_account_name",
        "exchange_rate", "notes", "deduct_from_account"
    ]
    
    /// 固定欄位順序（無標題列時使用）
    static let canonicalHeaders: [String] = [
        "date", "type", "asset_type", "symbol", "quantity", "price", "currency", "fee",
        "target_account_name", "exchange_rate", "notes", "deduct_from_account"
    ]
    
    /// 清理 AI 回覆中常見的 markdown 程式碼區塊
    static func sanitizePastedText(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.hasPrefix("```") else { return cleaned }
        
        if let firstLineEnd = cleaned.firstIndex(of: "\n") {
            cleaned = String(cleaned[cleaned.index(after: firstLineEnd)...])
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func parse(_ text: String) -> TransactionImportParseResult {
        parseNormalized(sanitizePastedText(text))
    }
    
    private static func parseNormalized(_ text: String) -> TransactionImportParseResult {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return TransactionImportParseResult(rows: [], fatalError: "檔案是空的", usedImplicitHeader: false)
        }
        
        let lines = splitLines(normalized)
        guard let firstLine = lines.first else {
            return TransactionImportParseResult(rows: [], fatalError: "找不到標題列", usedImplicitHeader: false)
        }
        
        let usedImplicitHeader: Bool
        let headers: [String]
        let dataLines: [String]
        
        if isHeaderLine(firstLine) {
            headers = parseCSVLine(firstLine).map { normalizeHeader($0) }
            let missing = requiredHeaders.filter { !headers.contains($0) }
            if !missing.isEmpty {
                return TransactionImportParseResult(
                    rows: [],
                    fatalError: "缺少必要欄位：\(missing.joined(separator: ", "))",
                    usedImplicitHeader: false
                )
            }
            dataLines = Array(lines.dropFirst())
            usedImplicitHeader = false
        } else if looksLikeDataRow(firstLine) {
            headers = canonicalHeaders
            dataLines = lines
            usedImplicitHeader = true
        } else {
            return TransactionImportParseResult(
                rows: [],
                fatalError: "第一行不是標題列，也不是有效資料。請貼上含 date,type,... 的 CSV，或直接貼資料列（固定欄位順序）。",
                usedImplicitHeader: false
            )
        }
        
        guard !headers.isEmpty else {
            return TransactionImportParseResult(rows: [], fatalError: "標題列格式錯誤", usedImplicitHeader: false)
        }
        
        var rows: [TransactionImportParsedRow] = []
        var lineNumber = usedImplicitHeader ? 0 : 1
        
        for line in dataLines {
            lineNumber += 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            let values = parseCSVLine(line)
            var fieldMap: [String: String] = [:]
            for (index, header) in headers.enumerated() where index < values.count {
                fieldMap[header] = values[index].trimmingCharacters(in: .whitespaces)
            }
            
            rows.append(parseRow(fieldMap: fieldMap, lineNumber: lineNumber))
        }
        
        if rows.isEmpty {
            return TransactionImportParseResult(rows: [], fatalError: "沒有可匯入的資料列", usedImplicitHeader: usedImplicitHeader)
        }
        
        return TransactionImportParseResult(rows: rows, fatalError: nil, usedImplicitHeader: usedImplicitHeader)
    }
    
    static func isHeaderLine(_ line: String) -> Bool {
        let fields = parseCSVLine(line).map { normalizeHeader($0) }
        return fields.contains("date") && fields.contains("type")
    }
    
    static func looksLikeDataRow(_ line: String) -> Bool {
        let fields = parseCSVLine(line)
        guard fields.count >= 4 else { return false }
        let dateOK = parseDate(fields[0]) != nil
        let typeRaw = fields[1].trimmingCharacters(in: .whitespaces).lowercased()
        let typeOK = TransactionType(rawValue: typeRaw) != nil
        return dateOK && typeOK
    }
    
    private static func parseRow(fieldMap: [String: String], lineNumber: Int) -> TransactionImportParsedRow {
        let typeRaw = fieldMap["type"]?.lowercased() ?? ""
        let type = TransactionType(rawValue: typeRaw)
        
        let assetTypeRaw = fieldMap["asset_type"]?.lowercased() ?? ""
        let assetType = assetTypeRaw.isEmpty ? nil : AssetType(rawValue: assetTypeRaw)
        
        let currencyRaw = fieldMap["currency"]?.uppercased() ?? ""
        let currency = currencyRaw.isEmpty ? nil : Currency(rawValue: currencyRaw)
        
        let accountName = fieldMap["account_name"] ?? ""
        let symbol = (fieldMap["symbol"] ?? "").trimmingCharacters(in: .whitespaces)
        let targetAccountName = fieldMap["target_account_name"]?.trimmingCharacters(in: .whitespaces)
        let notes = fieldMap["notes"]?.trimmingCharacters(in: .whitespaces)
        
        let deductRaw = fieldMap["deduct_from_account"]?.lowercased().trimmingCharacters(in: .whitespaces) ?? ""
        // 匯入預設不扣款（歷史補登持股）；僅在 CSV 明確填 true/1/yes 時才扣款
        let deductFromAccount: Bool = {
            if deductRaw.isEmpty { return false }
            if deductRaw == "false" || deductRaw == "0" || deductRaw == "no" { return false }
            return deductRaw == "true" || deductRaw == "1" || deductRaw == "yes"
        }()
        
        return TransactionImportParsedRow(
            id: lineNumber,
            lineNumber: lineNumber,
            date: parseDate(fieldMap["date"]),
            type: type,
            accountName: accountName,
            assetType: assetType,
            symbol: symbol,
            quantity: parseDecimal(fieldMap["quantity"]),
            price: parseDecimal(fieldMap["price"]),
            currency: currency,
            fee: parseDecimal(fieldMap["fee"]) ?? 0,
            targetAccountName: targetAccountName?.isEmpty == true ? nil : targetAccountName,
            exchangeRate: parseDecimal(fieldMap["exchange_rate"]),
            notes: notes?.isEmpty == true ? nil : notes,
            deductFromAccount: deductFromAccount,
            rawFields: fieldMap
        )
    }
    
    private static func normalizeHeader(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .lowercased()
    }
    
    private static func splitLines(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }
    
    /// 簡易 CSV 列解析（支援雙引號欄位）
    static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var index = line.startIndex
        
        while index < line.endIndex {
            let char = line[index]
            if char == "\"" {
                if inQuotes {
                    let next = line.index(after: index)
                    if next < line.endIndex, line[next] == "\"" {
                        current.append("\"")
                        index = line.index(after: next)
                        continue
                    }
                    inQuotes = false
                } else if current.isEmpty {
                    inQuotes = true
                } else {
                    current.append(char)
                }
            } else if char == ",", !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
            index = line.index(after: index)
        }
        fields.append(current)
        return fields
    }
    
    static func parseDate(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        let formats = ["yyyy-MM-dd", "yyyy/M/d", "yyyy/MM/dd", "yyyy-M-d"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return Calendar.current.startOfDay(for: date)
            }
        }
        return nil
    }
    
    static func parseDecimal(_ raw: String?) -> Decimal? {
        guard var text = raw?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        text = text.replacingOccurrences(of: ",", with: "")
        text = text.replacingOccurrences(of: "$", with: "")
        text = text.replacingOccurrences(of: "NT$", with: "")
        return Decimal(string: text)
    }
}
