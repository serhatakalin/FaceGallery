//
//  FaceDetector.swift
//  FaceGallery
//
//  Created by Serhat Akalin
//  Single-image face detection and minimum size check using CIDetector.
//

import Foundation
import UIKit
import CoreImage

/// Result of checking one image for a sufficiently large face.
public struct FaceDetectionResult {
    public let hasFace: Bool
    public let maxFaceHeight: CGFloat
    public let maxFaceWidth: CGFloat

    public init(hasFace: Bool, maxFaceHeight: CGFloat = 0, maxFaceWidth: CGFloat = 0) {
        self.hasFace = hasFace
        self.maxFaceHeight = maxFaceHeight
        self.maxFaceWidth = maxFaceWidth
    }
}

/// Detects faces in a single image and checks if the largest face meets a minimum size (in full-resolution projected points).
public final class FaceDetector {

    private let detector: CIDetector?
    private let minFaceSize: CGFloat
    private let legacyDeviceOffset: CGFloat

    /// - Parameters:
    ///   - useLowAccuracy: If true, uses CIDetectorAccuracyLow for faster detection on older devices.
    ///   - minFaceSize: Minimum face size in full-resolution projected points (e.g. 200).
    ///   - legacyDeviceOffset: Extra points added to threshold on legacy devices (e.g. 40).
    public init(
        useLowAccuracy: Bool = false,
        minFaceSize: CGFloat = 200,
        legacyDeviceOffset: CGFloat = 40
    ) {
        self.minFaceSize = minFaceSize
        self.legacyDeviceOffset = legacyDeviceOffset
        let accuracy = useLowAccuracy ? CIDetectorAccuracyLow : CIDetectorAccuracyHigh
        self.detector = CIDetector(
            ofType: CIDetectorTypeFace,
            context: nil,
            options: [CIDetectorAccuracy: accuracy]
        )
    }

    /// Checks whether the image contains at least one face that meets the minimum size when projected to full resolution.
    /// - Parameters:
    ///   - image: Thumbnail or downscaled image used for detection.
    ///   - assetPixelWidth: Original asset pixel width.
    ///   - assetPixelHeight: Original asset pixel height.
    ///   - useLegacyOffset: If true, adds legacyDeviceOffset to the threshold.
    /// - Returns: Result with hasFace and max face dimensions.
    public func containsSizedFace(
        image: UIImage,
        assetPixelWidth: Int,
        assetPixelHeight: Int,
        useLegacyOffset: Bool = false
    ) -> FaceDetectionResult {
        guard let ciImage = CIImage(image: image) else {
            return FaceDetectionResult(hasFace: false)
        }
        let orientation = image.imageOrientation
        var options: [String: Any] = [:]
        options[CIDetectorImageOrientation] = orientation.rawValue
        options[CIDetectorMinFeatureSize] = 0.15

        guard let features = detector?.features(in: ciImage, options: options), !features.isEmpty else {
            return FaceDetectionResult(hasFace: false)
        }

        var maxFaceHeight: CGFloat = 0
        var maxFaceWidth: CGFloat = 0
        for feature in features {
            let rect = feature.bounds
            if rect.size.height > maxFaceHeight { maxFaceHeight = rect.size.height }
            if rect.size.width > maxFaceWidth { maxFaceWidth = rect.size.width }
        }

        var assetWidth = CGFloat(assetPixelWidth)
        var assetHeight = CGFloat(assetPixelHeight)
        if assetPixelWidth > 2000, assetPixelWidth > assetPixelHeight {
            let r = CGFloat(2000) / assetWidth
            assetWidth *= r
            assetHeight *= r
        } else if assetPixelHeight > 2000 {
            let r = CGFloat(2000) / assetHeight
            assetWidth *= r
            assetHeight *= r
        }
        let ratio = assetWidth / image.size.width
        let threshold = minFaceSize + (useLegacyOffset ? legacyDeviceOffset : 0)
        let meetsHeight = (maxFaceHeight * ratio) > threshold
        let meetsWidth = (maxFaceWidth * ratio) > threshold
        let hasFace = meetsHeight || meetsWidth

        return FaceDetectionResult(
            hasFace: hasFace,
            maxFaceHeight: maxFaceHeight * ratio,
            maxFaceWidth: maxFaceWidth * ratio
        )
    }
}
