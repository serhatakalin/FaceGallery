//
//  Configuration.swift
//  FaceGallery
//
//  Created by Serhat Akalin
//  iOS face detection and gallery loading configuration.
//

import Foundation
import UIKit

/// Device capability hints used for batch size and detector accuracy.
/// Uses screen size heuristics so the package stays independent of device model names.
public enum DeviceCapability {
    /// Older devices (no notch): use lower detector accuracy and smaller batch for performance.
    case legacy
    /// Smaller screen (e.g. narrow phones): use smaller batch size.
    case smallScreen
    /// Default: higher accuracy, larger batch.
    case standard

    /// Heuristic: device has no notch (pre‑iPhone X style).
    /// Uses screen size only; call from main thread if used from UI context.
    public static var hasNotch: Bool {
        UIScreen.main.bounds.height > 800
    }

    /// Heuristic: treat as legacy (pre‑iPhone X) for accuracy/batch.
    public static var isLegacyDevice: Bool {
        !hasNotch || UIScreen.main.bounds.height < 700
    }

    /// Heuristic: small screen for batch size.
    public static var isSmallScreen: Bool {
        let w = UIScreen.main.bounds.width
        let h = UIScreen.main.bounds.height
        return min(w, h) < 375
    }

    /// Resolved capability from current device.
    public static var current: DeviceCapability {
        if isSmallScreen { return .smallScreen }
        if isLegacyDevice { return .legacy }
        return .standard
    }
}

/// Configuration for face detection and batch processing.
public struct FaceGalleryConfiguration {

    /// Number of assets to process per batch.
    public var batchSize: Int

    /// Minimum face size (in full-resolution projected points) to consider "has face".
    public var minFaceSize: CGFloat

    /// Extra offset added to min face size on legacy devices (e.g. 40).
    public var legacyDeviceOffset: CGFloat

    /// Use high accuracy for CIDetector when false; low when true (faster on older devices).
    public var useLowAccuracy: Bool

    public init(
        batchSize: Int? = nil,
        minFaceSize: CGFloat = 200,
        legacyDeviceOffset: CGFloat = 40,
        useLowAccuracy: Bool? = nil
    ) {
        let cap = DeviceCapability.current
        self.batchSize = batchSize ?? cap.defaultBatchSize
        self.minFaceSize = minFaceSize
        self.legacyDeviceOffset = legacyDeviceOffset
        self.useLowAccuracy = useLowAccuracy ?? cap.useLowAccuracy
    }
}

extension DeviceCapability {
    var defaultBatchSize: Int {
        switch self {
        case .smallScreen: return 15
        case .legacy: return 30
        case .standard: return 30
        }
    }

    var useLowAccuracy: Bool {
        self == .legacy
    }
}
