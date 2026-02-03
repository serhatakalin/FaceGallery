//
//  GalleryViewController.swift
//  FaceGalleryDemo
//
//  Created by Serhat Akalin
//

import UIKit
import Photos
import Combine
import FaceGallery

final class GalleryViewController: UIViewController {

    private let state = FaceGalleryState()
    private lazy var engine: FaceGalleryEngine = {
        let e = FaceGalleryEngine(state: state, configuration: FaceGalleryConfiguration())
        return e
    }()

    private var collectionView: UICollectionView!
    private var loadingIndicator: UIActivityIndicatorView!
    private var permissionView: UIView!
    private var permissionLabel: UILabel!
    private var allowButton: UIButton!
    private var emptyLabel: UILabel!
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Photos with faces"
        view.backgroundColor = .systemBackground
        setupPermissionView()
        setupCollectionView()
        setupLoadingIndicator()
        setupEmptyLabel()
        bind()
        requestPermissionIfNeeded()
    }

    private func setupPermissionView() {
        permissionView = UIView()
        permissionView.translatesAutoresizingMaskIntoConstraints = false
        permissionView.isHidden = true
        permissionView.isUserInteractionEnabled = true
        view.addSubview(permissionView)

        permissionLabel = UILabel()
        permissionLabel.numberOfLines = 0
        permissionLabel.textAlignment = .center
        permissionLabel.text = "Photo library access is needed to find photos that contain faces."
        permissionLabel.translatesAutoresizingMaskIntoConstraints = false
        permissionView.addSubview(permissionLabel)

        allowButton = UIButton(type: .system)
        allowButton.setTitle("Allow Access", for: .normal)
        allowButton.addTarget(self, action: #selector(allowTapped), for: .touchUpInside)
        allowButton.translatesAutoresizingMaskIntoConstraints = false
        allowButton.isUserInteractionEnabled = true
        permissionView.addSubview(allowButton)

        NSLayoutConstraint.activate([
            permissionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            permissionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            permissionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            permissionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            permissionLabel.leadingAnchor.constraint(equalTo: permissionView.leadingAnchor, constant: 24),
            permissionLabel.trailingAnchor.constraint(equalTo: permissionView.trailingAnchor, constant: -24),
            permissionLabel.topAnchor.constraint(equalTo: permissionView.topAnchor, constant: 40),
            permissionLabel.bottomAnchor.constraint(equalTo: allowButton.topAnchor, constant: -24),
            allowButton.centerXAnchor.constraint(equalTo: permissionView.centerXAnchor),
            allowButton.bottomAnchor.constraint(lessThanOrEqualTo: permissionView.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, env in
            let count: CGFloat = 3
            let spacing: CGFloat = 4
            let totalSpacing = (count - 1) * spacing
            let width = (env.container.effectiveContentSize.width - totalSpacing) / count
            let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(width), heightDimension: .absolute(width))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(width))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            group.interItemSpacing = .fixed(spacing)
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            return section
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.register(FaceCell.self, forCellWithReuseIdentifier: FaceCell.reuseId)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupEmptyLabel() {
        emptyLabel = UILabel()
        emptyLabel.text = "No photos with faces found."
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func bind() {
        state.$detectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleDetectionState(state)
            }
            .store(in: &cancellables)

        state.$resultAssetsToDraw
            .receive(on: DispatchQueue.main)
            .sink { [weak self] assets in
                self?.collectionView.reloadData()
                self?.emptyLabel.isHidden = !assets.isEmpty
            }
            .store(in: &cancellables)
    }

    private func handleDetectionState(_ state: DetectionState) {
        switch state {
        case .initial:
            break
        case .start:
            loadingIndicator.startAnimating()
        case .resume:
            collectionView.reloadData()
            emptyLabel.isHidden = !self.state.resultAssetsToDraw.isEmpty
        case .finished:
            loadingIndicator.stopAnimating()
            emptyLabel.isHidden = !self.state.resultAssetsToDraw.isEmpty
        case .photosChanged:
            collectionView.reloadData()
        }
    }

    private func requestPermissionIfNeeded() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .notDetermined:
            permissionView.isHidden = false
            collectionView.isHidden = true
            view.bringSubviewToFront(permissionView)
        case .denied, .restricted:
            permissionView.isHidden = false
            collectionView.isHidden = true
            view.bringSubviewToFront(permissionView)
        case .authorized, .limited:
            permissionView.isHidden = true
            collectionView.isHidden = false
            engine.isLimitedPermission = (status == .limited)
            loadAndDetect()
        @unknown default:
            permissionView.isHidden = false
            collectionView.isHidden = true
            view.bringSubviewToFront(permissionView)
        }
    }

    private func loadAndDetect() {
        let collections = AlbumLoader.loadAlbums(subTypes: [.smartAlbumUserLibrary, .smartAlbumSelfPortraits, .smartAlbumFavorites])
        guard let allPhotos = collections.first(where: { $0.assetCollectionSubtype == .smartAlbumUserLibrary }) else {
            return
        }
        engine.fetchResults = AlbumLoader.loadAssets(from: allPhotos)
        engine.detect()
    }

    @objc private func allowTapped() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.requestPermissionIfNeeded()
            }
        }
    }
}

extension GalleryViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        state.resultAssetsToDraw.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FaceCell.reuseId, for: indexPath) as! FaceCell
        let asset = state.resultAssetsToDraw[indexPath.item]
        let loader = PhotoAssetLoader()
        let width = (collectionView.bounds.width - 8) / 3 * UIScreen.main.scale
        let size = CGSize(width: width, height: width)
        Task {
            let image = await loader.requestThumbnailAsync(for: asset, maxSize: size)
            await MainActor.run {
                cell.imageView.image = image
            }
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.item == state.resultAssetsToDraw.count - 1 {
            engine.checkAssetsAreReady()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < state.resultAssetsToDraw.count else { return }
        let asset = state.resultAssetsToDraw[indexPath.item]
        printAssetProperties(asset)
    }

    private func printAssetProperties(_ asset: PHAsset) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let created = asset.creationDate.map { formatter.string(from: $0) } ?? "—"
        let modified = asset.modificationDate.map { formatter.string(from: $0) } ?? "—"
        let mediaTypeStr: String = {
            switch asset.mediaType {
            case .image: return "image"
            case .video: return "video"
            case .audio: return "audio"
            default: return "\(asset.mediaType.rawValue)"
            }
        }()
        print("""
            ——— PHAsset ———
            localIdentifier: \(asset.localIdentifier)
            pixelWidth: \(asset.pixelWidth)
            pixelHeight: \(asset.pixelHeight)
            creationDate: \(created)
            modificationDate: \(modified)
            mediaType: \(mediaTypeStr)
            duration: \(asset.duration)s
            mediaSubtypes: \(asset.mediaSubtypes.rawValue)
            isFavorite: \(asset.isFavorite)
            ————————
            """)
    }
}
