# 📦 FaceGallery

Face detection and gallery loading for iOS. Scans photo library assets in batches, detects faces using Core Image, and exposes a list of assets that contain a face meeting a minimum size threshold. Suitable for building “photos with faces” or “selfie” galleries.

## Requirements

- iOS 14+
- Xcode 14+
- Swift 5.9+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/serhatakalin/FaceGallery.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** and enter the repository URL.

## Usage

### 1. Request photo library authorization

Use `PHPhotoLibrary.requestAuthorization(for:)` (or `requestAuthorization(for:access:)` on iOS 14+) and handle `.authorized` / `.limited` / `.denied` as needed.

### 2. Load albums and assets

```swift
import FaceGallery
import Photos

// Smart albums: All Photos, Selfies, Favorites
let collections = AlbumLoader.loadAlbums(subTypes: [
    .smartAlbumUserLibrary,
    .smartAlbumSelfPortraits,
    .smartAlbumFavorites
])

let allPhotos = collections.first { $0.assetCollectionSubtype == .smartAlbumUserLibrary }
let fetchResult = allPhotos.map { AlbumLoader.loadAssets(from: $0) }
```

### 3. Run face detection

```swift
let state = FaceGalleryState()
let engine = FaceGalleryEngine(state: state, configuration: FaceGalleryConfiguration())

engine.fetchResults = fetchResult
engine.isLimitedPermission = (PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited)
engine.detect()
```

### 4. Observe state and display results

```swift
state.$detectionState
    .receive(on: DispatchQueue.main)
    .sink { state in
        switch state {
        case .start: break // show loading
        case .resume: break // append new batch to UI
        case .finished: break // hide loading
        case .photosChanged, .initial: break
        }
    }
    .store(in: &cancellables)

state.$resultAssetsToDraw
    .receive(on: DispatchQueue.main)
    .sink { assets in
        // Update collection view with assets
    }
    .store(in: &cancellables)
```

### 5. Incremental loading

When the user scrolls to the last cell, call:

```swift
engine.checkAssetsAreReady()
```

This triggers the next batch of face detection; when it finishes, `detectionState` becomes `.resume` and `resultAssetsToDraw` is updated.

### 6. Load thumbnails and full-size images

```swift
let loader = PhotoAssetLoader()
let size = CGSize(width: 200, height: 200)
let image = await loader.requestThumbnailAsync(for: asset, maxSize: size)
let fullSize = await loader.requestFullSizeImage(for: asset)
```

## API overview

| Type | Purpose |
|------|--------|
| `FaceGalleryEngine` | Batch face detection over `PHFetchResult<PHAsset>`; drives state and cache |
| `FaceGalleryState` | `@Published` `detectionState` and `resultAssetsToDraw` |
| `DetectionState` | `.initial`, `.start`, `.resume`, `.finished`, `.photosChanged` |
| `FaceDetector` | Single-image face check with minimum size (CIDetector) |
| `FaceDetectionCache` | Persists per-asset results (optional UserDefaults) |
| `PhotoAssetLoader` | Thumbnail and full-size image loading via PHImageManager |
| `AlbumLoader` | Load smart albums and assets from `PHAssetCollection` |
| `FaceGalleryConfiguration` | Batch size, min face size, detector accuracy |
| `DeviceCapability` | Heuristics for legacy/small devices (batch size, accuracy) |

## Cache key

By default the cache uses UserDefaults key `"FaceGallery.assetDict"`. You can pass a custom key or `UserDefaults(suiteName:)` when creating `FaceDetectionCache` to share or isolate cache with your app.

## Demo

The `Demo/FaceGalleryDemo` Xcode project shows a single screen with a photo library permission flow and a collection view of assets that contain a face, using incremental loading.

## License

See repository license file.
