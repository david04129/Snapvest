//
//  ChartSegmentedControl.swift
//  Snapvest
//
//  首頁圖表用分段選擇（選中項白底＋主色字＋滑動高亮）
//

import SwiftUI

struct ChartSegmentedControl<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String
    var fontSize: CGFloat = 13
    
    @Namespace private var highlightNS
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(options) { option in
                segmentButton(option)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(AppColors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(AppColors.separator, lineWidth: 1)
                )
        )
    }
    
    private func segmentButton(_ option: Option) -> some View {
        let isSelected = selection.id == option.id
        return Button {
            guard !isSelected else { return }
            withAnimation(ChartMotion.switchSpring) {
                selection = option
            }
        } label: {
            Text(label(option))
                .font(.system(size: fontSize, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? AppColors.actionForeground : AppColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppColors.appPrimary)
                            .shadow(color: AppColors.appPrimary.opacity(0.35), radius: 4, x: 0, y: 2)
                            .matchedGeometryEffect(id: "chartSegmentHighlight", in: highlightNS)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
