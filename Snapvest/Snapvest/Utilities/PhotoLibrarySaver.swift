//
//  PhotoLibrarySaver.swift
//  Snapvest
//
//  將 UIImage 儲存至系統相簿
//

import Photos
import UIKit

enum PhotoLibrarySaver {
    enum SaveError: LocalizedError {
        case denied
        case restricted
        case failed

        var errorDescription: String? {
            switch self {
            case .denied:
                return "請到「設定 > Walleaf > 照片」允許加入照片。"
            case .restricted:
                return "此裝置無法存取相簿。"
            case .failed:
                return "儲存失敗，請稍後再試。"
            }
        }
    }

    @MainActor
    static func saveImage(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        switch status {
        case .authorized, .limited:
            break
        case .notDetermined:
            throw SaveError.failed
        case .denied:
            throw SaveError.denied
        case .restricted:
            throw SaveError.restricted
        @unknown default:
            throw SaveError.failed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? SaveError.failed)
                }
            }
        }
    }
}
