//
//  FaceGalleryState.swift
//  FaceGallery
//
//  Created by Serhat Akalin
//  Detection state and published results for FaceGalleryEngine.
//

import Foundation
import Combine
import Photos

/// States of the face detection pipeline.
public enum DetectionState {
    case initial
    case start
    case resume
    case finished
    case photosChanged
}

/// Observable state for FaceGalleryEngine (detection state and assets to display).
public final class FaceGalleryState: ObservableObject {

    @Published public private(set) var detectionState: DetectionState = .initial
    @Published public private(set) var resultAssetsToDraw: [PHAsset] = []

    let stateSubject = PassthroughSubject<DetectionState, Never>()
    let resultSubject = PassthroughSubject<[PHAsset], Never>()

    public init() {}

    func setDetectionState(_ state: DetectionState) {
        DispatchQueue.main.async { [weak self] in
            self?.detectionState = state
            self?.stateSubject.send(state)
        }
    }

    func appendResultAssetsToDraw(_ assets: [PHAsset]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.resultAssetsToDraw.append(contentsOf: assets)
            self.resultSubject.send(self.resultAssetsToDraw)
        }
    }

    func replaceResultAssetsToDraw(_ assets: [PHAsset]) {
        DispatchQueue.main.async { [weak self] in
            self?.resultAssetsToDraw = assets
            self?.resultSubject.send(assets)
        }
    }

    func clearResultAssetsToDraw() {
        DispatchQueue.main.async { [weak self] in
            self?.resultAssetsToDraw = []
            self?.resultSubject.send([])
        }
    }
}
