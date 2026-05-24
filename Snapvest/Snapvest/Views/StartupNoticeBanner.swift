//
//  StartupNoticeBanner.swift
//  Snapvest
//
//  冷啟動降級提示橫幅（Phase 3）。
//

import SwiftUI

struct StartupNoticeBanner: View {
    let message: String
    var onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.orange)
                .font(.subheadline)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 4)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
