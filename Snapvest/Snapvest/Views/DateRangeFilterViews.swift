//
//  DateRangeFilterViews.swift
//  Snapvest
//
//  共用日期區間選擇 UI（走勢圖、紀錄篩選等）
//

import SwiftUI

// MARK: - 預設區間

enum DateRangePreset: String, CaseIterable, Identifiable {
    case sevenDays = "7D"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case oneYear = "1Y"
    case all = "全部"
    case custom = "自訂"
    
    var id: String { rawValue }
}

enum CustomDatePickerField: Identifiable {
    case start
    case end
    
    var id: String {
        switch self {
        case .start: return "start"
        case .end: return "end"
        }
    }
    
    var title: String {
        switch self {
        case .start: return "開始日期"
        case .end: return "結束日期"
        }
    }
}

enum DateRangePresetCalculator {
    static func dateRange(
        for preset: DateRangePreset,
        now: Date = Date(),
        customStart: Date,
        customEnd: Date
    ) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: now)
        let startDay: Date
        switch preset {
        case .sevenDays:
            startDay = calendar.date(byAdding: .day, value: -6, to: endDay) ?? endDay
        case .oneMonth:
            startDay = calendar.date(byAdding: .month, value: -1, to: endDay) ?? endDay
        case .threeMonths:
            startDay = calendar.date(byAdding: .month, value: -3, to: endDay) ?? endDay
        case .oneYear:
            startDay = calendar.date(byAdding: .year, value: -1, to: endDay) ?? endDay
        case .all:
            startDay = .distantPast
        case .custom:
            let start = calendar.startOfDay(for: customStart)
            let end = calendar.startOfDay(for: customEnd)
            return (min(start, end), max(start, end))
        }
        return (startDay, endDay)
    }
    
    static func dateInterval(
        for preset: DateRangePreset,
        now: Date = Date(),
        customStart: Date,
        customEnd: Date
    ) -> DateInterval {
        let range = dateRange(for: preset, now: now, customStart: customStart, customEnd: customEnd)
        let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: range.end) ?? range.end
        return DateInterval(start: range.start, end: end)
    }
    
    /// 若開始／結束日剛好符合某預設區間，回傳該預設；否則 nil（表示自訂）
    static func matchingPreset(
        start: Date,
        end: Date,
        now: Date = Date()
    ) -> DateRangePreset? {
        let calendar = Calendar.current
        for preset in [DateRangePreset.sevenDays, .oneMonth, .threeMonths, .oneYear] {
            let range = dateRange(for: preset, now: now, customStart: start, customEnd: end)
            if calendar.isDate(start, inSameDayAs: range.start),
               calendar.isDate(end, inSameDayAs: range.end) {
                return preset
            }
        }
        return nil
    }
}

// MARK: - 預設區間選擇列

struct DateRangePresetPicker: View {
    @Binding var selection: DateRangePreset
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(DateRangePreset.allCases) { preset in
                    Button {
                        guard selection != preset else { return }
                        withAnimation(ChartMotion.switchSpring) {
                            selection = preset
                        }
                    } label: {
                        Text(preset.rawValue)
                            .font(.system(size: 12, weight: selection == preset ? .bold : .medium))
                            .foregroundColor(selection == preset ? AppColors.actionForeground : .secondaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background {
                                if selection == preset {
                                    Capsule()
                                        .fill(AppColors.appPrimary)
                                } else {
                                    Capsule()
                                        .fill(AppColors.secondaryBackground)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - 自訂日期雙欄

struct CustomDateRangeBar: View {
    let startDate: Date
    let endDate: Date
    let onStartTapped: () -> Void
    let onEndTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            dateField(date: startDate, action: onStartTapped)
            
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondaryText)
            
            dateField(date: endDate, action: onEndTapped)
        }
    }
    
    private func dateField(date: Date, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(formatShortDate(date))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppColors.separator.opacity(0.6), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - 滾輪日期 Bottom Sheet

struct WheelDatePickerSheet: View {
    let title: String
    @Binding var selection: Date
    let earliestDate: Date
    let onDone: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "",
                    selection: $selection,
                    in: earliestDate...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "zh_TW"))
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onDone()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }
}
