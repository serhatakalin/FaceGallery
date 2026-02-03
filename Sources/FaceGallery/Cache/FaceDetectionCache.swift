//
//  FaceDetectionCache.swift
//  FaceGallery
//
//  Created by Serhat Akalin
//  Persists face detection results (asset localIdentifier -> hasFace) to avoid re-detecting.
//

import Foundation

/// In-memory and optionally persistent cache for face detection results per asset.
public final class FaceDetectionCache {

    private var storage: [String: Bool] = [:]
    private let queue = DispatchQueue(label: "FaceGallery.FaceDetectionCache")
    private let userDefaults: UserDefaults?
    private let storageKey: String

    /// - Parameters:
    ///   - userDefaults: If non-nil, cache is persisted to this UserDefaults. If nil, in-memory only.
    ///   - storageKey: Key used for persistence. Default is "FaceGallery.assetDict".
    public init(userDefaults: UserDefaults? = .standard, storageKey: String = "FaceGallery.assetDict") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        queue.sync {
            if let ud = userDefaults, let data = ud.data(forKey: storageKey),
               let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
                storage = decoded
            }
        }
    }

    /// Returns cached value for asset localIdentifier, if any.
    public func get(_ assetId: String) -> Bool? {
        queue.sync { storage[assetId] }
    }

    /// Stores result for asset localIdentifier.
    public func set(_ assetId: String, hasFace: Bool) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.storage[assetId] = hasFace
        }
    }

    /// Persists current in-memory cache to UserDefaults (if configured).
    public func persist() {
        queue.async { [weak self] in
            guard let self = self, let ud = self.userDefaults else { return }
            let copy = self.storage
            if let data = try? JSONEncoder().encode(copy) {
                ud.set(data, forKey: self.storageKey)
            }
        }
    }

    /// Replaces in-memory cache with the given dictionary (e.g. after loading from host app).
    public func replace(with dict: [String: Bool]) {
        queue.async { [weak self] in
            self?.storage = dict
        }
    }

    /// Returns current in-memory snapshot (e.g. for host app to persist elsewhere).
    public func snapshot() -> [String: Bool] {
        queue.sync { storage }
    }
}
