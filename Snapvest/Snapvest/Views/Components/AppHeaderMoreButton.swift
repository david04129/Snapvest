//
//  AppHeaderMoreButton.swift
//  Snapvest
//
//  全域右上角「更多」入口
//

import SwiftUI

struct AppHeaderMoreButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.appPrimary.opacity(0.14))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.appPrimary)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("更多")
    }
}
