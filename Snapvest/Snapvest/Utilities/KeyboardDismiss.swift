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

// MARK: - 全域點擊（單一手勢、略過輸入框與按鈕）

private enum SnapKeyboardDismissInstallerState {
    static weak var activeCoordinator: SnapKeyboardDismissInstaller.Coordinator?
}

private struct SnapKeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var tapGesture: UITapGestureRecognizer?
        private weak var installedWindow: UIWindow?

        @objc func handleTap() {
            KeyboardDismiss.dismiss()
        }

        func install(on window: UIWindow) {
            if SnapKeyboardDismissInstallerState.activeCoordinator === self,
               installedWindow === window,
               tapGesture != nil {
                return
            }
            SnapKeyboardDismissInstallerState.activeCoordinator?.uninstall()
            SnapKeyboardDismissInstallerState.activeCoordinator = self

            uninstall()

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            tapGesture = tap
            installedWindow = window
        }

        func uninstall() {
            if let tap = tapGesture, let window = installedWindow {
                window.removeGestureRecognizer(tap)
            }
            if SnapKeyboardDismissInstallerState.activeCoordinator === self {
                SnapKeyboardDismissInstallerState.activeCoordinator = nil
            }
            tapGesture = nil
            installedWindow = nil
        }

        deinit {
            uninstall()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let window = installedWindow else { return true }
            let location = touch.location(in: window)
            guard let hitView = window.hitTest(location, with: nil) else { return true }
            return !Self.isInteractiveControl(hitView)
        }

        private static func isInteractiveControl(_ view: UIView) -> Bool {
            var current: UIView? = view
            while let candidate = current {
                if candidate is UITextField || candidate is UITextView {
                    return true
                }
                if let control = candidate as? UIControl,
                   control.isUserInteractionEnabled,
                   !(control is UISlider) {
                    return true
                }
                current = candidate.superview
            }
            return false
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
    /// 點擊畫面空白處收起鍵盤（略過 TextField、Button、Picker 等）
    func snapDismissKeyboardOnTap() -> some View {
        background(SnapKeyboardDismissInstaller())
    }

    /// Sheet 表單：數字鍵盤「完成」；空白處靠 ScrollView 的 scrollDismissesKeyboard
    func snapFormSheetChrome() -> some View {
        snapKeyboardDoneToolbar()
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
