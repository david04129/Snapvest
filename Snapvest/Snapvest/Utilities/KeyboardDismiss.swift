//
//  KeyboardDismiss.swift
//  Snapvest
//
//  點擊畫面其他區域收起鍵盤；數字鍵盤提供「完成」工具列。
//

import SwiftUI
import UIKit

enum KeyboardDismiss {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - 全域點擊（不阻擋按鈕／輸入框）

private struct SnapKeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        private weak var tapGesture: UITapGestureRecognizer?
        private weak var installedWindow: UIWindow?

        @objc func handleTap() {
            KeyboardDismiss.dismiss()
        }

        func install(on window: UIWindow) {
            guard installedWindow !== window else { return }
            uninstall()
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tap.cancelsTouchesInView = false
            window.addGestureRecognizer(tap)
            tapGesture = tap
            installedWindow = window
        }

        func uninstall() {
            if let tap = tapGesture, let window = installedWindow {
                window.removeGestureRecognizer(tap)
            }
            tapGesture = nil
            installedWindow = nil
        }

        deinit {
            uninstall()
        }
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let window = uiView.window else { return }
            context.coordinator.install(on: window)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }
}

extension View {
    /// 點擊畫面任意處收起鍵盤（含 Sheet 內容）
    func snapDismissKeyboardOnTap() -> some View {
        background(SnapKeyboardDismissInstaller())
    }

    /// Sheet 表單：點空白收起鍵盤 + 數字鍵盤「完成」
    func snapFormSheetChrome() -> some View {
        snapDismissKeyboardOnTap()
            .snapKeyboardDoneToolbar()
    }

    /// 數字小鍵盤上方「完成」
    func snapKeyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    KeyboardDismiss.dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    /// 表單 ScrollView：滑動或點空白時收起鍵盤
    func snapFormScrollDismissesKeyboard() -> some View {
        scrollDismissesKeyboard(.immediately)
    }
}
