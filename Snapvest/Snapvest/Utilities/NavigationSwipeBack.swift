//
//  NavigationSwipeBack.swift
//  Snapvest
//
//  隱藏系統返回鈕時仍保留左緣滑動返回。
//

import SwiftUI
import UIKit

extension View {
    /// 在 `navigationBarBackButtonHidden(true)` 的推入頁啟用系統邊緣返回手勢。
    func enableNavigationSwipeBack() -> some View {
        background(NavigationSwipeBackEnabler())
    }
}

private struct NavigationSwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        NavigationSwipeBackController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        (uiViewController as? NavigationSwipeBackController)?.enableSwipeBackIfPossible()
    }
}

private final class NavigationSwipeBackController: UIViewController {
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        enableSwipeBackIfPossible()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableSwipeBackIfPossible()
    }

    func enableSwipeBackIfPossible() {
        guard let navigationController = navigationController else { return }
        navigationController.interactivePopGestureRecognizer?.isEnabled = true
        navigationController.interactivePopGestureRecognizer?.delegate = nil
    }
}
