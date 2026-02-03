//
//  AlbumLoader.swift
//  FaceGallery
//
//  Created by Serhat Akalin
//  Loads album collections and assets using Photos framework.
//

import Foundation
import Photos

/// Loads PHAssetCollection lists and PHFetchResult for a given collection.
public enum AlbumLoader {

    /// Fetch smart albums by subtypes (e.g. All Photos, Selfies, Favorites).
    /// - Parameter subTypes: e.g. [.smartAlbumUserLibrary, .smartAlbumSelfPortraits, .smartAlbumFavorites]
    /// - Returns: Matching collections in no guaranteed order; map by subtype if needed.
    public static func loadAlbums(subTypes: [PHAssetCollectionSubtype]) -> [PHAssetCollection] {
        let fetchResult = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .any,
            options: nil
        )
        var result: [PHAssetCollection] = []
        fetchResult.enumerateObjects { collection, _, _ in
            if subTypes.contains(collection.assetCollectionSubtype) {
                result.append(collection)
            }
        }
        return result
    }

    /// Fetch assets (images) from a collection, sorted by creation date descending.
    /// - Parameter collection: The album (e.g. from loadAlbums).
    /// - Returns: Fetch result of image assets, or nil if collection is invalid.
    public static func loadAssets(from collection: PHAssetCollection) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeiTunesSynced, .typeCloudShared]
        return PHAsset.fetchAssets(in: collection, options: options)
    }
}
