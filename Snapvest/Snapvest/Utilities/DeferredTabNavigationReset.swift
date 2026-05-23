//
//  DeferredTabNavigationReset.swift
//  Snapvest
//

import SwiftUI

/// 離開 Tab 時先記錄待重置，等使用者再次進入該 Tab 才執行，避免切換動畫期間先 pop 造成閃爍。
struct DeferredTabNavigationResetModifier: ViewModifier {
    @Binding var selectedTab: Int
    let resignedTab: AppTab
    @State private var pendingReset = false
    let onReset: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .tabResigned)) { notification in
                guard tabIndex(from: notification) == resignedTab.rawValue else { return }
                pendingReset = true
            }
            .onChange(of: selectedTab) { _, newTab in
                guard newTab == resignedTab.rawValue, pendingReset else { return }
                pendingReset = false
                onReset()
            }
    }

    private func tabIndex(from notification: Notification) -> Int? {
        notification.userInfo?[TabResignUserInfoKey.tabIndex] as? Int
    }
}

extension View {
    func resetNavigationWhenTabReappears(
        selectedTab: Binding<Int>,
        resignedTab: AppTab,
        onReset: @escaping () -> Void
    ) -> some View {
        modifier(DeferredTabNavigationResetModifier(
            selectedTab: selectedTab,
            resignedTab: resignedTab,
            onReset: onReset
        ))
    }
}
