//
//  OperationLoadingOverlay.swift
//  Snapvest
//

import SwiftUI

struct OperationLoadingOverlay: View {
    let title: String
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(.appPrimary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AppColors.shadowMedium, radius: 12, x: 0, y: 4)
        }
    }
}

enum MinimumDurationLoading {
    static func waitIfNeeded(since start: ContinuousClock.Instant, minimum: Duration = .seconds(1)) async {
        let elapsed = ContinuousClock.now - start
        guard elapsed < minimum else { return }
        try? await Task.sleep(for: minimum - elapsed)
    }
}
