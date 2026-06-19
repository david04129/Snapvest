//
//  ChartHoldToInteractOverlay.swift
//  Snapvest
//
//  UIKit 透明 overlay：長按成功後才進入拖曳；長按前允許 ScrollView 捲動。
//

import SwiftUI
import UIKit

/// 透明手勢承載層（全區域接收長按，長按前與 ScrollView 並行）
private final class ChartInteractionHostView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.contains(point)
    }
}

struct ChartHoldToInteractOverlay: UIViewRepresentable {
    let minimumHoldDuration: TimeInterval
    let maximumMovement: CGFloat
    /// SwiftUI 容器尺寸（GeometryReader.size），用於對齊 UIKit touch 座標
    var contentSize: CGSize
    var onReady: () -> Void
    var onLocationChanged: (CGPoint) -> Void
    var onEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = ChartInteractionHostView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false
        context.coordinator.attach(
            to: view,
            minimumHoldDuration: minimumHoldDuration,
            maximumMovement: maximumMovement
        )
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.contentSize = contentSize
        context.coordinator.onReady = onReady
        context.coordinator.onLocationChanged = onLocationChanged
        context.coordinator.onEnded = onEnded
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var contentSize: CGSize = .zero
        var onReady: (() -> Void)?
        var onLocationChanged: ((CGPoint) -> Void)?
        var onEnded: (() -> Void)?

        private weak var hostView: UIView?
        private weak var scrollView: UIScrollView?
        private var longPress: UILongPressGestureRecognizer!
        private var isInteracting = false

        func attach(
            to view: UIView,
            minimumHoldDuration: TimeInterval,
            maximumMovement: CGFloat
        ) {
            hostView = view

            let longPress = UILongPressGestureRecognizer(
                target: self,
                action: #selector(handleLongPress(_:))
            )
            longPress.minimumPressDuration = minimumHoldDuration
            longPress.allowableMovement = maximumMovement
            longPress.cancelsTouchesInView = false
            longPress.delaysTouchesBegan = false
            longPress.delegate = self
            view.addGestureRecognizer(longPress)
            self.longPress = longPress

            DispatchQueue.main.async { [weak self, weak view] in
                guard let view else { return }
                self?.scrollView = Self.findScrollView(from: view)
            }
        }

        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = mappedLocation(gesture.location(in: view), in: view)

            switch gesture.state {
            case .began:
                isInteracting = true
                scrollView?.isScrollEnabled = false
                onReady?()
                onLocationChanged?(location)
            case .changed:
                guard isInteracting else { return }
                onLocationChanged?(location)
            case .ended, .cancelled, .failed:
                finishInteraction()
            default:
                break
            }
        }

        private func mappedLocation(_ pointInView: CGPoint, in view: UIView) -> CGPoint {
            let bounds = view.bounds.size
            guard contentSize.width > 0,
                  contentSize.height > 0,
                  bounds.width > 0,
                  bounds.height > 0 else {
                return pointInView
            }
            return CGPoint(
                x: pointInView.x * (contentSize.width / bounds.width),
                y: pointInView.y * (contentSize.height / bounds.height)
            )
        }

        private func finishInteraction() {
            guard isInteracting else { return }
            isInteracting = false
            scrollView?.isScrollEnabled = true
            onEnded?()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            !isInteracting
        }

        private static func findScrollView(from view: UIView) -> UIScrollView? {
            var current: UIView? = view
            while let candidate = current {
                if let scrollView = candidate as? UIScrollView {
                    return scrollView
                }
                for subview in candidate.subviews {
                    if let scrollView = subview as? UIScrollView {
                        return scrollView
                    }
                }
                current = candidate.superview
            }
            return nil
        }
    }
}
