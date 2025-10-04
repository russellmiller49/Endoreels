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
            ZStack(alignment: .leading) {
                waveformPath(size: proxy.size)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
                selectionOverlay(width: proxy.size.width, height: proxy.size.height)
                playheadIndicator(width: proxy.size.width, height: proxy.size.height)
                if samples.isEmpty {
                    Text("Waveform will appear once audio analysis finishes.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onAppear(perform: loadSamples)
            .onChange(of: waveformURL) { _, _ in loadSamples() }
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

    private func selectionOverlay(width: CGFloat, height: CGFloat) -> some View {
        let duration = max(duration, 0.1)
        return ZStack(alignment: .leading) {
            if let inPoint, let outPoint, outPoint > inPoint {
                let startX = CGFloat(inPoint / duration) * width
                let endX = CGFloat(outPoint / duration) * width
                Rectangle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: max(endX - startX, 2), height: height)
                    .offset(x: startX)
            }
        }
    }

    private func playheadIndicator(width: CGFloat, height: CGFloat) -> some View {
        let duration = max(duration, 0.1)
        let x = CGFloat(playhead / duration).clamped(to: 0...1) * width
        return Rectangle()
            .fill(Color.blue)
            .frame(width: 2, height: height)
            .offset(x: x - 1)
    }

    private func loadSamples() {
        guard let waveformURL else {
            samples = []
            return
        }
        do {
            let data = try Data(contentsOf: waveformURL)
            if let raw = try JSONSerialization.jsonObject(with: data) as? [Double] {
                let clamped = raw.map { max(0, min($0, 1)) }
                samples = clamped.map { CGFloat($0) }
            } else {
                samples = []
            }
        } catch {
            samples = []
        }
    }
}
