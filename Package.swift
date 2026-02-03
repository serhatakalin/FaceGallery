// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FaceGallery",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "FaceGallery", targets: ["FaceGallery"])
    ],
    targets: [
        .target(
            name: "FaceGallery",
            path: "Sources/FaceGallery"
        )
    ]
)
