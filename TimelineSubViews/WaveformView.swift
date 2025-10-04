import SwiftUI

struct WaveformView: View {
    let waveformURL: URL?
    let duration: TimeInterval
    let playhead: TimeInterval
    let inPoint: TimeInterval?
    let outPoint: TimeInterval?

    @State private var samples: [CGFloat] = []

    var body: some View {
        GeometryReader { proxy in
            // Guard against degenerate sizes
            let w = max(proxy.size.width, 1)
            let h = max(proxy.size.height, 1)

            // Validate duration
            let safeDuration = max(duration, 0.0001)
            guard safeDuration.isFinite else {
                return AnyView(placeholderView(width: w, height: h, message: "Invalid duration"))
            }

            return AnyView(
                ZStack(alignment: .leading) {
                    waveformPath(size: CGSize(width: w, height: h))
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
                    selectionOverlay(width: w, height: h, duration: safeDuration)
                    playheadIndicator(width: w, height: h, duration: safeDuration)
                    if samples.isEmpty {
                        Text("Waveform will appear once audio analysis finishes.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .task(id: waveformURL) {
                    await loadWaveform()
                }
            )
        }
    }

    private func placeholderView(width: CGFloat, height: CGFloat, message: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.08))
            .frame(width: width, height: height)
            .overlay {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
    }

    private func waveformPath(size: CGSize) -> Path {
        guard !samples.isEmpty else { return Path() }
        var path = Path()
        let step = size.width / CGFloat(samples.count)
        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * step
            let y = size.height / 2
            let scaled = sample.clamped(to: 0...1) * (size.height / 2)
            path.move(to: CGPoint(x: x, y: y - scaled))
            path.addLine(to: CGPoint(x: x, y: y + scaled))
        }
        return path
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
                        .fill(Color.blue.opacity(0.15))
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
    private func loadWaveform() async {
        // Early validation
        guard let url = waveformURL else {
            samples = []
            return
        }

        guard url.isFileURL else {
            print("❌ WaveformView: URL is not a file URL: \(url)")
            samples = []
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ WaveformView: File does not exist at \(url.path)")
            samples = []
            return
        }

        // Perform I/O off the main actor
        let loadedSamples: [CGFloat] = await Task.detached(priority: .utility) { () -> [CGFloat] in
            do {
                let data = try Data(contentsOf: url)
                guard !data.isEmpty else {
                    print("📊 WaveformView: Waveform file is empty")
                    return []
                }

                if let raw = try JSONSerialization.jsonObject(with: data) as? [Double] {
                    let clamped = raw.map { max(0, min($0, 1)) }
                    let cgFloats = clamped.map { CGFloat($0) }
                    print("✅ WaveformView: Loaded \(cgFloats.count) waveform samples")
                    return cgFloats
                } else {
                    print("❌ WaveformView: Failed to parse JSON as [Double]")
                    return []
                }
            } catch {
                print("❌ WaveformView: Error loading waveform: \(error.localizedDescription)")
                return []
            }
        }.value

        // Update @State on MainActor
        samples = loadedSamples
    }
}
