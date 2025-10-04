import SwiftUI
import UIKit

struct ThumbnailStripView: View {
    let spriteURL: URL?
    let duration: TimeInterval
    let playhead: TimeInterval
    let inPoint: TimeInterval?
    let outPoint: TimeInterval?

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            // Guard against degenerate/invalid sizes (avoid division by zero later)
            let size = safeSize(proxy.size.width, proxy.size.height, fallback: CGSize(width: 1, height: 1))
            let w = size.width
            let h = size.height

            // Validate duration is finite and non-zero to prevent NaN in calculations
            let safeDuration = max(duration.finiteOrZero, 0.0001)
            guard safeDuration.isFinite else {
                return AnyView(placeholderView(width: w, height: h))
            }

            return AnyView(
                ZStack(alignment: .leading) {
                    // Background image or placeholder
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: w, height: h)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: w, height: h)
                            .overlay {
                                ProgressView()
                            }
                    }

                    selectionOverlay(width: w, height: h, duration: safeDuration)
                    playheadIndicator(width: w, height: h, duration: safeDuration)
                }
                .task(id: spriteURL) {
                    await loadSprite()
                }
            )
        }
    }

    private func placeholderView(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.red.opacity(0.1))
            .frame(width: safeSize(width, height, fallback: CGSize(width: 1, height: 1)).width,
                   height: safeSize(width, height, fallback: CGSize(width: 1, height: 1)).height)
            .overlay {
                Text("Invalid timeline data")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
    }

    private func selectionOverlay(width: CGFloat, height: CGFloat, duration: TimeInterval) -> some View {
        ZStack(alignment: .leading) {
            if let inPoint, let outPoint, outPoint > inPoint,
               inPoint.isFinite, outPoint.isFinite {
                let startRatio = (inPoint / duration).clamped(to: 0...1)
                let endRatio = (outPoint / duration).clamped(to: 0...1)
                let startX = CGFloat(startRatio) * width
                let endX = CGFloat(endRatio) * width

                if startX.isFinite && endX.isFinite {
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: max(endX - startX, 2), height: height)
                        .offset(x: startX)
                }
            }
        }
    }

    private func playheadIndicator(width: CGFloat, height: CGFloat, duration: TimeInterval) -> some View {
        let ratio = playhead.isFinite ? (playhead / duration).clamped(to: 0...1) : 0
        let x = CGFloat(ratio) * width

        return Group {
            if x.isFinite {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 2, height: height)
                    .offset(x: x - 1)
            }
        }
    }

    @MainActor
    private func loadSprite() async {
        // Early validation: check URL is valid before attempting I/O
        guard let url = spriteURL else {
            print("📸 ThumbnailStripView: No sprite URL, showing placeholder")
            image = nil
            return
        }

        // Validate it's a file URL and exists
        guard url.isFileURL else {
            print("❌ ThumbnailStripView: URL is not a file URL: \(url)")
            image = nil
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ ThumbnailStripView: File does not exist at \(url.path)")
            image = nil
            return
        }

        // Perform I/O off the main actor
        let loadedImage: UIImage? = await Task.detached(priority: .utility) { () -> UIImage? in
            // Read file data
            guard let data = try? Data(contentsOf: url),
                  !data.isEmpty else {
                print("❌ ThumbnailStripView: Failed to read data from \(url.path)")
                return nil
            }

            // Decode image (can be slow for large sprites)
            guard let img = UIImage(data: data) else {
                print("❌ ThumbnailStripView: Failed to decode image from \(data.count) bytes at \(url.path)")
                return nil
            }

            print("✅ ThumbnailStripView: Successfully loaded sprite (\(img.size.width)×\(img.size.height))")
            return img
        }.value

        // Update @State ONLY on MainActor (we're already on it due to @MainActor annotation)
        image = loadedImage
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
