//
//  FaceGalleryEngine.swift
//  FaceGallery
//
//  Created by Serhat Akalin
//  Batch face detection over PHFetchResult with cache and state updates.
//

import Foundation
import UIKit
import Photos
import Combine

/// Orchestrates batch face detection: consumes fetch results, uses cache and loader, updates state.
public final class FaceGalleryEngine {

    public let state: FaceGalleryState
    private let config: FaceGalleryConfiguration
    private let cache: FaceDetectionCache
    private let loader: PhotoAssetLoader
    private let faceDetector: FaceDetector

    private let detectionQueue = DispatchQueue(label: "FaceGallery.detection")
    private var isWaitingForAssets = false
    private var detectingFetchIndex = 0
    private var resultAssets: [PHAsset] = []
    /// Captured on main thread before dispatching to detection queue; never touch UI from background.
    private var cachedThumbnailSize: CGSize = .zero
    private var cachedUseLegacyOffset: Bool = false

    public var fetchResults: PHFetchResult<PHAsset>?
    public var isLimitedPermission: Bool = false

    public init(
        state: FaceGalleryState = FaceGalleryState(),
        configuration: FaceGalleryConfiguration = FaceGalleryConfiguration(),
        cache: FaceDetectionCache = FaceDetectionCache(),
        loader: PhotoAssetLoader = PhotoAssetLoader(),
        faceDetector: FaceDetector? = nil
    ) {
        self.state = state
        self.config = configuration
        self.cache = cache
        self.loader = loader
        self.faceDetector = faceDetector ?? FaceDetector(
            useLowAccuracy: configuration.useLowAccuracy,
            minFaceSize: configuration.minFaceSize,
            legacyDeviceOffset: configuration.legacyDeviceOffset
        )
    }

    /// Resets detection and starts from the beginning (state .start, then first batch on detection queue).
    /// Call from main thread so UI-derived values are captured safely.
    public func detect() {
        let width = UIScreen.main.bounds.width / 3.0
        let scale = UIScreen.main.scale
        cachedThumbnailSize = CGSize(width: width * scale, height: width * scale)
        cachedUseLegacyOffset = DeviceCapability.isLegacyDevice

        detectingFetchIndex = 0
        resultAssets = []
        state.clearResultAssetsToDraw()
        state.setDetectionState(.start)
        detectionQueue.async { [weak self] in
            self?.detectFace(counter: self?.config.batchSize ?? 30)
        }
    }

    /// Call from UI when the last cell is about to be displayed to load the next batch.
    public func checkAssetsAreReady() {
        guard !isWaitingForAssets else { return }
        isWaitingForAssets = true
        detectionQueue.async { [weak self] in
            guard let self = self else { return }
            self.detectFace(counter: self.config.batchSize)
        }
    }

    /// Called internally when a batch is done; updates state and resultAssetsToDraw.
    /// When allProcessed is true, sets .finished so UI stops the spinner.
    private func assetsAreReady(batchStart: Int, batchEnd: Int, allProcessed: Bool) {
        isWaitingForAssets = false
        if isLimitedPermission {
            state.replaceResultAssetsToDraw(resultAssets)
        } else {
            let batch = Array(resultAssets[batchStart..<batchEnd])
            state.appendResultAssetsToDraw(batch)
        }
        state.setDetectionState(allProcessed ? .finished : .resume)
    }

    /// Runs one batch of face detection (called on detectionQueue).
    private func detectFace(counter: Int) {
        guard let results = fetchResults else { return }
        var batchSize = counter
        if isLimitedPermission {
            batchSize = results.count
        }
        let startIndex = detectingFetchIndex
        var endIndex = detectingFetchIndex + batchSize

        detectingFetchIndex += batchSize
        if detectingFetchIndex > results.count {
            endIndex = results.count
            detectingFetchIndex = results.count
        }

        if startIndex > endIndex {
            isWaitingForAssets = false
            state.setDetectionState(.finished)
            return
        }
        if startIndex == endIndex {
            isWaitingForAssets = false
            state.setDetectionState(.finished)
            return
        }

        let size = cachedThumbnailSize
        guard size.width > 0, size.height > 0 else { return }
        let countBeforeBatch = resultAssets.count
        let useLegacyOffset = cachedUseLegacyOffset

        autoreleasepool {
            for index in startIndex..<endIndex {
                let asset = results.object(at: index) as PHAsset
                let assetId = asset.localIdentifier
                if let cached = cache.get(assetId) {
                    if cached {
                        resultAssets.append(asset)
                    }
                    continue
                }
                loader.requestThumbnail(
                    for: asset,
                    maxSize: size,
                    isLimited: isLimitedPermission,
                    isSynchronous: true
                ) { [weak self] image in
                    guard let self = self else { return }
                    guard let img = image, let _ = CIImage(image: img) else {
                        self.cache.set(assetId, hasFace: false)
                        return
                    }
                    let result = self.faceDetector.containsSizedFace(
                        image: img,
                        assetPixelWidth: asset.pixelWidth,
                        assetPixelHeight: asset.pixelHeight,
                        useLegacyOffset: useLegacyOffset
                    )
                    self.cache.set(assetId, hasFace: result.hasFace)
                    if result.hasFace {
                        self.resultAssets.append(asset)
                    }
                }
            }
            let allProcessed = detectingFetchIndex >= results.count
            assetsAreReady(batchStart: countBeforeBatch, batchEnd: resultAssets.count, allProcessed: allProcessed)
        }
    }
}
