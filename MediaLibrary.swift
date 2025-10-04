import Foundation
import AVFoundation
import UIKit
import UniformTypeIdentifiers

enum MediaAssetKind: String, Codable {
    case image
    case video
    case audio
}

enum MediaAssetSource: String, Codable {
    case photoLibrary
    case filesProvider
}

struct ImportedMediaAsset: Identifiable {
    let id: UUID
    var kind: MediaAssetKind
    var url: URL
    var filename: String
    var source: MediaAssetSource
    var createdAt: Date
    var duration: Double?
    var trimRange: ClosedRange<Double>?
    var thumbnail: UIImage?
    var editedImage: UIImage?
    var transcript: String?
    var proxyURL: URL?
    var thumbnailSpriteURL: URL?
    var waveformURL: URL?

    init(id: UUID = UUID(),
         kind: MediaAssetKind,
         url: URL,
         filename: String,
         source: MediaAssetSource,
         createdAt: Date = .now,
         duration: Double? = nil,
         trimRange: ClosedRange<Double>? = nil,
         thumbnail: UIImage? = nil,
         editedImage: UIImage? = nil,
         transcript: String? = nil,
         proxyURL: URL? = nil,
         thumbnailSpriteURL: URL? = nil,
         waveformURL: URL? = nil) {
        self.id = id
        self.kind = kind
        self.url = url
        self.filename = filename
        self.source = source
        self.createdAt = createdAt
        self.duration = duration
        self.trimRange = trimRange
        self.thumbnail = thumbnail
        self.editedImage = editedImage
        self.transcript = transcript
        self.proxyURL = proxyURL
        self.thumbnailSpriteURL = thumbnailSpriteURL
        self.waveformURL = waveformURL
    }
}

extension ImportedMediaAsset {
    enum CreationError: Error {
        case unsupportedType
        case unreadableAsset
    }

    static func make(from url: URL, source: MediaAssetSource) async throws -> ImportedMediaAsset {
        let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey, .nameKey, .fileSizeKey])
        guard let contentType = resourceValues.contentType else {
            throw CreationError.unsupportedType
        }

        if contentType.conforms(to: .movie) {
            let asset = AVURLAsset(url: url)
            let durationTime = try await asset.load(.duration)
            let thumbnail = await asset.generateThumbnail()
            return ImportedMediaAsset(kind: .video,
                                      url: url,
                                      filename: resourceValues.name ?? url.lastPathComponent,
                                      source: source,
                                      duration: CMTimeGetSeconds(durationTime),
                                      thumbnail: thumbnail)
        }

        if contentType.conforms(to: .image) {
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
                throw CreationError.unreadableAsset
            }
            return ImportedMediaAsset(kind: .image,
                                      url: url,
                                      filename: resourceValues.name ?? url.lastPathComponent,
                                      source: source,
                                      thumbnail: image,
                                      editedImage: image)
        }

        if contentType.conforms(to: .audio) {
            let asset = AVURLAsset(url: url)
            let durationTime = try await asset.load(.duration)
            return ImportedMediaAsset(kind: .audio,
                                      url: url,
                                      filename: resourceValues.name ?? url.lastPathComponent,
                                      source: source,
                                      duration: CMTimeGetSeconds(durationTime))
        }

        throw CreationError.unsupportedType
    }

    @MainActor
    mutating func applyTrimmedVideo(url: URL, duration: Double, range: ClosedRange<Double>, thumbnail: UIImage?) {
        self.url = url
        self.duration = duration
        self.trimRange = range
        if let thumbnail {
            self.thumbnail = thumbnail
        }
    }

    mutating func applyEditedImage(_ image: UIImage, storeAt url: URL) throws {
        if let pngData = image.pngData() {
            try pngData.write(to: url, options: [.atomic])
        } else if let jpegData = image.jpegData(compressionQuality: 0.9) {
            try jpegData.write(to: url, options: [.atomic])
        } else {
            throw CreationError.unreadableAsset
        }

        self.url = url
        self.thumbnail = image
        self.editedImage = image
    }

    @MainActor
    mutating func applyTrimmedAudio(url: URL, duration: Double, range: ClosedRange<Double>) {
        self.url = url
        self.duration = duration
        self.trimRange = range
    }

    mutating func updateTranscript(_ transcript: String?) {
        self.transcript = transcript
    }
}

extension AVAsset {
    func generateThumbnail(time: CMTime = CMTime(seconds: 1, preferredTimescale: 240)) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: self)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)

        return await withCheckedContinuation { continuation in
            if #available(iOS 18, *) {
                generator.generateCGImageAsynchronously(for: time) { cgImage, _, _ in
                    if let cgImage {
                        continuation.resume(returning: UIImage(cgImage: cgImage))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            } else {
                let times = [NSValue(time: time)]
                generator.generateCGImagesAsynchronously(forTimes: times) { _, cgImage, _, _, _ in
                    if let cgImage {
                        continuation.resume(returning: UIImage(cgImage: cgImage))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
}

extension ImportedMediaAsset: Equatable {
    static func == (lhs: ImportedMediaAsset, rhs: ImportedMediaAsset) -> Bool {
        lhs.id == rhs.id
    }
}

extension ImportedMediaAsset: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
