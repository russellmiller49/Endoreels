import SwiftUI
import UIKit

struct ThumbnailStripView: View {
    let spriteURL: URL?
    let duration: TimeInterval
    let playhead: TimeInterval
    let inPoint: TimeInterval?
    let outPoint: TimeInterval?

    @State private var image: UIImage?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                backgroundView
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .onAppear(perform: loadImage)
                    .onChange(of: spriteURL) { _, _ in loadImage() }
                    .onDisappear { loadTask?.cancel() }

                selectionOverlay(width: proxy.size.width)
                playheadIndicator(width: proxy.size.width)
            }
        }
    }

    private var backgroundView: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .overlay {
                        ProgressView()
                    }
            }
        }
    }

    private func selectionOverlay(width: CGFloat) -> some View {
        let duration = max(duration, 0.1)
        return ZStack(alignment: .leading) {
            if let inPoint, let outPoint, outPoint > inPoint {
                let startX = CGFloat(inPoint / duration) * width
                let endX = CGFloat(outPoint / duration) * width
                Rectangle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: max(endX - startX, 2), height: .infinity)
                    .offset(x: startX)
            }
        }
    }

    private func playheadIndicator(width: CGFloat) -> some View {
        let duration = max(duration, 0.1)
        let x = CGFloat(playhead / duration).clamped(to: 0...1) * width
        return Rectangle()
            .fill(Color.blue)
            .frame(width: 2, height: .infinity)
            .offset(x: x - 1)
    }

    private func loadImage() {
        loadTask?.cancel()
        guard let spriteURL else {
            image = nil
            return
        }

        loadTask = Task(priority: .utility) {
            let uiImage: UIImage?
            if spriteURL.isFileURL {
                uiImage = UIImage(contentsOfFile: spriteURL.path)
            } else if let data = try? Data(contentsOf: spriteURL) {
                uiImage = UIImage(data: data)
            } else {
                uiImage = nil
            }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.image = uiImage
                self.loadTask = nil
            }
        }
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
