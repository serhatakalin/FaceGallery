//
//  PhotoAssetLoader.swift
//  FaceGallery
//
//  Created by Serhat Akalin
//  Loads thumbnails and full-size images from PHAsset using PHImageManager.
//

import Foundation
import UIKit
import Photos

/// Loads images for PHAssets (thumbnails for detection, optional full-size).
public final class PhotoAssetLoader {

    private let imageManager: PHImageManager

    public init(imageManager: PHImageManager = .default()) {
        self.imageManager = imageManager
    }

    /// Thumbnail request for use inside detection loop. Use isSynchronous: true so the completion
    /// runs before the method returns (per-asset blocking), matching batch detection flow.
    /// - Parameters:
    ///   - asset: The photo asset.
    ///   - maxSize: Target size (e.g. scale-adjusted for screen).
    ///   - isLimited: Whether library access is limited (affects options).
    ///   - isSynchronous: If true, resultHandler is called before requestImage returns.
    ///   - completion: Called with the thumbnail or nil.
    public func requestThumbnail(
        for asset: PHAsset,
        maxSize: CGSize,
        isLimited: Bool,
        isSynchronous: Bool = false,
        completion: @escaping (UIImage?) -> Void
    ) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact
        options.isSynchronous = isSynchronous

        imageManager.requestImage(
            for: asset,
            targetSize: maxSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }

    /// Async thumbnail for UI (e.g. collection view cells).
    public func requestThumbnailAsync(
        for asset: PHAsset,
        maxSize: CGSize,
        isLimited: Bool = false
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            requestThumbnail(for: asset, maxSize: maxSize, isLimited: isLimited) { image in
                continuation.resume(returning: image)
            }
        }
    }

    /// Async full-size (or large) image for editing/preview.
    public func requestFullSizeImage(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 2000, height: 2000),
        retryCount: Int = 3
    ) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                if image == nil, retryCount > 0 {
                    Task {
                        let img = await self.requestFullSizeImage(for: asset, targetSize: targetSize, retryCount: retryCount - 1)
                        continuation.resume(returning: img)
                    }
                } else {
                    continuation.resume(returning: image)
                }
            }
        }
    }
}
