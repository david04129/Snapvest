//
//  AmountKeypadInputView.swift
//  Snapvest
//
//  固定顯示的金額數字鍵盤，避免喚出系統鍵盤。
//

import SwiftUI

struct AmountKeypadInputView: View {
    @Binding var text: String
    let currency: Currency
    var accentColor: Color = .appPrimary
    var placeholder: String = "0"
    var allowsDecimal: Bool = true
    var maxFractionDigits: Int = 2
    
    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "delete.left"]
    ]
    
    private var displayText: String {
        text.isEmpty ? placeholder : text
    }
    
    var body: some View {
        VStack(spacing: 12) {
            amountDisplay
            keypad
        }
    }
    
    private var amountDisplay: some View {
        HStack(spacing: 10) {
            TradeFormCurrencyBadge(currency: currency)
            
            Text(displayText)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(text.isEmpty ? .secondaryText : .primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(Color.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor.opacity(0.22), lineWidth: 1)
        }
    }
    
    private var keypad: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        keypadButton(key)
                    }
                }
            }
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Text("清除")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func keypadButton(_ key: String) -> some View {
        Button {
            handleKey(key)
        } label: {
            Group {
                if key == "delete.left" {
                    Image(systemName: key)
                        .font(.system(size: 20, weight: .semibold))
                } else {
                    Text(key)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(buttonForeground(for: key))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(buttonBackground(for: key))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(key == "." && !allowsDecimal)
        .opacity(key == "." && !allowsDecimal ? 0.35 : 1)
    }
    
    private func buttonForeground(for key: String) -> Color {
        if key == "delete.left" { return .lossRed }
        if key == "." { return accentColor }
        return .primaryText
    }
    
    private func buttonBackground(for key: String) -> Color {
        if key == "delete.left" { return Color.lossRed.opacity(0.11) }
        if key == "." { return accentColor.opacity(0.11) }
        return Color.cardBackground
    }
    
    private func handleKey(_ key: String) {
        switch key {
        case "delete.left":
            guard !text.isEmpty else { return }
            text.removeLast()
        case ".":
            appendDecimalPoint()
        default:
            appendDigit(key)
        }
    }
    
    private func appendDecimalPoint() {
        guard allowsDecimal, !text.contains(".") else { return }
        text = text.isEmpty ? "0." : text + "."
    }
    
    private func appendDigit(_ digit: String) {
        guard digit.allSatisfy(\.isNumber) else { return }
        
        if text == "0" {
            text = digit
        } else {
            text += digit
        }
        
        normalizeFractionDigits()
    }
    
    private func normalizeFractionDigits() {
        guard maxFractionDigits >= 0,
              let decimalIndex = text.firstIndex(of: ".") else { return }
        let fractionStart = text.index(after: decimalIndex)
        let fractionDigits = text[fractionStart...].count
        guard fractionDigits > maxFractionDigits else { return }
        text.removeLast(fractionDigits - maxFractionDigits)
    }
}
