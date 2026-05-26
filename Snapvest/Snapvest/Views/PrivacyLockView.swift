//
//  PrivacyLockView.swift
//  Snapvest
//
//  隱私鎖畫面
//

import SwiftUI

struct PrivacyLockView: View {
    @ObservedObject private var privacyLock = PrivacyLockManager.shared
    
    var body: some View {
        ZStack {
            Color.mainBackground
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                VStack(spacing: 18) {
                    SnapvestBrandMark(
                        iconSize: 72,
                        wordmarkSize: 28,
                        spacing: 12,
                        layout: .vertical
                    )
                    
                    VStack(spacing: 8) {
                        Text("Walleaf 已鎖定")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.primaryText)
                        
                        Text("為了保護你的資產資訊，請先驗證身分。")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondaryText)
                    }
                }
                
                Button {
                    Task { await privacyLock.unlockWithAuthentication() }
                } label: {
                    HStack(spacing: 8) {
                        if privacyLock.isAuthenticating {
                            ProgressView()
                                .tint(AppColors.actionForeground)
                        } else {
                            Image(systemName: "faceid")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        
                        Text(privacyLock.isAuthenticating ? "驗證中..." : "解鎖")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundColor(AppColors.actionForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(privacyLock.isAuthenticating)
                .padding(.horizontal, 48)
            }
            .padding(.horizontal, 24)
        }
        .alert(
            "無法解鎖",
            isPresented: Binding(
                get: { privacyLock.errorMessage != nil },
                set: { if !$0 { privacyLock.errorMessage = nil } }
            )
        ) {
            Button("再試一次") {
                Task { await privacyLock.unlockWithAuthentication() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(privacyLock.errorMessage ?? "")
        }
    }
}
