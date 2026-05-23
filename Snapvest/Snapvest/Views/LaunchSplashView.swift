//
//  LaunchSplashView.swift
//  Snapvest
//
//  開機：僅 Logo 淡入與輕微呼吸動畫（無轉圈、無載入文案）
//

import SwiftUI

struct LaunchSplashView: View {
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.9
    
    var body: some View {
        ZStack {
            Color.mainBackground
                .ignoresSafeArea()
            
            VStack(spacing: 14) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(AppColors.appPrimary)
                
                Text("Snapvest")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primaryText)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                logoOpacity = 1
                logoScale = 1
            }
            Task {
                try? await Task.sleep(nanoseconds: 550_000_000)
                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                    logoScale = 1.045
                }
            }
        }
    }
}
