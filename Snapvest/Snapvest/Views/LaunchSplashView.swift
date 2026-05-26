//
//  LaunchSplashView.swift
//  Snapvest
//
//  開機：Logo 淡入 + 呼吸循環（無副標文案）。
//

import SwiftUI

struct LaunchSplashView: View {
    var networkErrorMessage: String?
    var blockedMessage: String?
    var blockedAllowsRetry: Bool = false
    var onRetryLaunch: () -> Void = {}
    var onExitApp: () -> Void = {}
    
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.94
    @State private var breathScale: CGFloat = 1
    @State private var glowOpacity: Double = 0.16
    @State private var glowScale: CGFloat = 0.92
    @State private var gradientPhase: CGFloat = 0
    
    private var showsLoadingBrand: Bool {
        networkErrorMessage == nil && blockedMessage == nil
    }
    
    var body: some View {
        ZStack {
            ambientBackground
            
            if let networkErrorMessage {
                fatalErrorContent(
                    title: "無法連線",
                    systemImage: "wifi.slash",
                    message: networkErrorMessage,
                    primaryTitle: "離開 App",
                    primaryAction: onExitApp,
                    showsRetry: false
                )
            } else if let blockedMessage {
                fatalErrorContent(
                    title: "無法啟動",
                    systemImage: "exclamationmark.icloud",
                    message: blockedMessage,
                    primaryTitle: blockedAllowsRetry ? "重試" : "離開 App",
                    primaryAction: blockedAllowsRetry ? onRetryLaunch : onExitApp,
                    showsRetry: blockedAllowsRetry
                )
            } else {
                loadingContent
            }
        }
        .onAppear {
            guard showsLoadingBrand else { return }
            startLaunchAnimation()
        }
    }
    
    private var loadingContent: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColors.appPrimary.opacity(glowOpacity),
                            AppColors.appPrimary.opacity(0)
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 72
                    )
                )
                .frame(width: 196, height: 196)
                .blur(radius: 24)
                .scaleEffect(glowScale)
            
            SnapvestBrandMark(
                iconSize: 92,
                wordmarkSize: 36,
                spacing: 16,
                layout: .vertical
            )
        }
        .scaleEffect(logoScale * breathScale)
        .opacity(logoOpacity)
    }
    
    private var ambientBackground: some View {
        ZStack {
            Color.mainBackground
                .ignoresSafeArea()
            
            RadialGradient(
                colors: [
                    AppColors.appPrimary.opacity(0.07),
                    AppColors.appPrimary.opacity(0.02),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5 + gradientPhase * 0.04, y: 0.42),
                startRadius: 40,
                endRadius: 380
            )
            .ignoresSafeArea()
        }
    }
    
    private func fatalErrorContent(
        title: String,
        systemImage: String,
        message: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        showsRetry: Bool
    ) -> some View {
        VStack(spacing: 28) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.secondaryText)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primaryText)
                
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            
            VStack(spacing: 10) {
                Button(action: primaryAction) {
                    Text(primaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(showsRetry ? AppColors.actionForeground : Color.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(showsRetry ? Color.appPrimary : Color.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            if !showsRetry {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.separator.opacity(0.35), lineWidth: 1)
                            }
                        }
                }
                
                if showsRetry {
                    Button(action: onExitApp) {
                        Text("離開 App")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 48)
        }
    }
    
    private func startLaunchAnimation() {
        logoOpacity = 0
        logoScale = 0.94
        breathScale = 0.94
        glowOpacity = 0.1
        glowScale = 0.86
        
        withAnimation(.easeOut(duration: 0.55)) {
            logoOpacity = 1
            logoScale = 1
        }
        
        withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
            gradientPhase = 1
        }
        
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                    breathScale = 1.14
                    glowOpacity = 0.58
                    glowScale = 1.28
                }
            }
        }
    }
}

enum LaunchSplashTiming {
    /// Splash 至少停留時間（載入很快時也不會一閃而過）
    static let minimumDuration: Duration = .seconds(2.2)
    /// 灌完資料後、切入主畫面前的短暫停留
    static let preTransitionHold: Duration = .milliseconds(400)
}
