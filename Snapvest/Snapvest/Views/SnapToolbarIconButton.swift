//
//  SnapToolbarIconButton.swift
//  Snapvest
//
//  Toolbar 圖示按鈕：至少 44pt 觸控區，避免只有圖示中心可點。
//

import SwiftUI

struct SnapToolbarIconButton: View {
    enum Icon {
        case back
        case close

        var systemName: String {
            switch self {
            case .back: return "chevron.left"
            case .close: return "xmark"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .back: return "返回"
            case .close: return "關閉"
            }
        }
    }

    let icon: Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon.systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appPrimary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.accessibilityLabel)
    }
}
