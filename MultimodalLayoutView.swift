import SwiftUI
import AVKit

// MARK: - Layout Types

enum MultimodalLayout: String, CaseIterable, Identifiable {
    case single = "Single View"
    case pip = "Picture-in-Picture"
    case sideBySide = "Side-by-Side"
    case splitScreen5050 = "Split 50/50"
    case splitScreen7030 = "Split 70/30"
    case beforeAfter = "Before/After Slider"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .single: return "rectangle"
        case .pip: return "rectangle.inset.filled.and.person.filled"
        case .sideBySide: return "rectangle.split.2x1"
        case .splitScreen5050: return "rectangle.split.2x1"
        case .splitScreen7030: return "rectangle.split.2x1"
        case .beforeAfter: return "arrow.left.and.right"
        }
    }
}

// MARK: - Multimodal Asset Configuration

struct MultimodalAssetConfig: Identifiable {
    let id = UUID()
    var primaryAsset: ImportedMediaAsset?
    var secondaryAsset: ImportedMediaAsset?
    var layout: MultimodalLayout
    var syncPlayback: Bool
    var pipPosition: PiPPosition
    var pipScale: CGFloat
    var beforeAfterSliderPosition: Double

    enum PiPPosition: String, CaseIterable {
        case topLeft = "Top Left"
        case topRight = "Top Right"
        case bottomLeft = "Bottom Left"
        case bottomRight = "Bottom Right"

        var alignment: Alignment {
            switch self {
            case .topLeft: return .topLeading
            case .topRight: return .topTrailing
            case .bottomLeft: return .bottomLeading
            case .bottomRight: return .bottomTrailing
            }
        }

        var offset: (x: CGFloat, y: CGFloat) {
            switch self {
            case .topLeft: return (12, 12)
            case .topRight: return (-12, 12)
            case .bottomLeft: return (12, -12)
            case .bottomRight: return (-12, -12)
            }
        }
    }

    static let `default` = MultimodalAssetConfig(
        layout: .single,
        syncPlayback: true,
        pipPosition: .bottomRight,
        pipScale: 0.3,
        beforeAfterSliderPosition: 0.5
    )
}

// MARK: - Multimodal Layout Editor

struct MultimodalLayoutEditor: View {
    @Binding var config: MultimodalAssetConfig
    let availableAssets: [ImportedMediaAsset]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Layout Type") {
                    Picker("Layout", selection: $config.layout) {
                        ForEach(MultimodalLayout.allCases) { layout in
                            Label(layout.rawValue, systemImage: layout.systemImage)
                                .tag(layout)
                        }
                    }
                }

                Section("Media Assets") {
                    Picker("Primary Asset", selection: $config.primaryAsset) {
                        Text("None").tag(nil as ImportedMediaAsset?)
                        ForEach(availableAssets) { asset in
                            Text(asset.filename).tag(asset as ImportedMediaAsset?)
                        }
                    }

                    if config.layout != .single {
                        Picker("Secondary Asset", selection: $config.secondaryAsset) {
                            Text("None").tag(nil as ImportedMediaAsset?)
                            ForEach(availableAssets) { asset in
                                Text(asset.filename).tag(asset as ImportedMediaAsset?)
                            }
                        }
                    }
                }

                if config.layout != .single {
                    Section("Playback") {
                        Toggle("Sync Playback", isOn: $config.syncPlayback)
                    }
                }

                if config.layout == .pip {
                    Section("Picture-in-Picture Settings") {
                        Picker("Position", selection: $config.pipPosition) {
                            ForEach(MultimodalAssetConfig.PiPPosition.allCases, id: \.self) { position in
                                Text(position.rawValue).tag(position)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Scale: \(Int(config.pipScale * 100))%")
                                .font(.caption)
                            Slider(value: $config.pipScale, in: 0.2...0.5)
                        }
                    }
                }

                if config.layout == .beforeAfter {
                    Section("Before/After Slider") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Initial Position: \(Int(config.beforeAfterSliderPosition * 100))%")
                                .font(.caption)
                            Slider(value: $config.beforeAfterSliderPosition, in: 0...1)
                        }
                    }
                }

                Section("Preview") {
                    MultimodalLayoutPreview(config: config)
                        .frame(height: 250)
                }
            }
            .navigationTitle("Multimodal Layout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Layout Preview

private struct MultimodalLayoutPreview: View {
    let config: MultimodalAssetConfig

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                switch config.layout {
                case .single:
                    singleView(size: geometry.size)

                case .pip:
                    pipView(size: geometry.size)

                case .sideBySide:
                    sideBySideView(size: geometry.size)

                case .splitScreen5050:
                    splitScreenView(size: geometry.size, ratio: 0.5)

                case .splitScreen7030:
                    splitScreenView(size: geometry.size, ratio: 0.7)

                case .beforeAfter:
                    beforeAfterView(size: geometry.size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func singleView(size: CGSize) -> some View {
        assetPreview(config.primaryAsset, label: "Primary")
            .frame(width: size.width, height: size.height)
    }

    private func pipView(size: CGSize) -> some View {
        ZStack(alignment: config.pipPosition.alignment) {
            assetPreview(config.primaryAsset, label: "Primary")
                .frame(width: size.width, height: size.height)

            assetPreview(config.secondaryAsset, label: "PiP")
                .frame(width: size.width * config.pipScale, height: size.height * config.pipScale)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .offset(x: config.pipPosition.offset.x, y: config.pipPosition.offset.y)
        }
    }

    private func sideBySideView(size: CGSize) -> some View {
        HStack(spacing: 2) {
            assetPreview(config.primaryAsset, label: "Primary")
                .frame(width: size.width / 2 - 1, height: size.height)

            assetPreview(config.secondaryAsset, label: "Secondary")
                .frame(width: size.width / 2 - 1, height: size.height)
        }
    }

    private func splitScreenView(size: CGSize, ratio: CGFloat) -> some View {
        HStack(spacing: 2) {
            assetPreview(config.primaryAsset, label: "Primary")
                .frame(width: size.width * ratio - 1, height: size.height)

            assetPreview(config.secondaryAsset, label: "Secondary")
                .frame(width: size.width * (1 - ratio) - 1, height: size.height)
        }
    }

    private func beforeAfterView(size: CGSize) -> some View {
        ZStack {
            assetPreview(config.secondaryAsset, label: "After")
                .frame(width: size.width, height: size.height)

            assetPreview(config.primaryAsset, label: "Before")
                .frame(width: size.width * config.beforeAfterSliderPosition, height: size.height)
                .clipShape(
                    Rectangle()
                        .size(width: size.width * config.beforeAfterSliderPosition, height: size.height)
                )
                .frame(width: size.width, height: size.height, alignment: .leading)

            Rectangle()
                .fill(Color.white)
                .frame(width: 3)
                .offset(x: (size.width * config.beforeAfterSliderPosition) - (size.width / 2))

            Circle()
                .fill(Color.white)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "arrow.left.and.right")
                        .foregroundStyle(.black)
                        .font(.caption)
                )
                .offset(x: (size.width * config.beforeAfterSliderPosition) - (size.width / 2))
        }
    }

    private func assetPreview(_ asset: ImportedMediaAsset?, label: String) -> some View {
        Group {
            if let asset = asset, let thumbnail = asset.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        Text(label)
                            .font(.caption2)
                            .padding(4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(4),
                        alignment: .topLeading
                    )
            } else {
                Color.gray.opacity(0.3)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.title2)
                            Text(label)
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    )
            }
        }
    }
}

// MARK: - Runtime Player View

struct MultimodalPlayerView: View {
    let config: MultimodalAssetConfig
    @State private var primaryPlayer: AVPlayer?
    @State private var secondaryPlayer: AVPlayer?
    @State private var beforeAfterSlider: Double
    @State private var isDraggingSlider = false

    init(config: MultimodalAssetConfig) {
        self.config = config
        _beforeAfterSlider = State(initialValue: config.beforeAfterSliderPosition)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                switch config.layout {
                case .single:
                    if let player = primaryPlayer {
                        VideoPlayer(player: player)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }

                case .pip:
                    pipPlayerView(size: geometry.size)

                case .sideBySide, .splitScreen5050, .splitScreen7030:
                    splitPlayerView(size: geometry.size)

                case .beforeAfter:
                    beforeAfterPlayerView(size: geometry.size)
                }
            }
            .onAppear { setupPlayers() }
            .onDisappear { cleanupPlayers() }
        }
    }

    private func pipPlayerView(size: CGSize) -> some View {
        ZStack(alignment: config.pipPosition.alignment) {
            if let player = primaryPlayer {
                VideoPlayer(player: player)
                    .frame(width: size.width, height: size.height)
            }

            if let player = secondaryPlayer {
                VideoPlayer(player: player)
                    .frame(width: size.width * config.pipScale, height: size.height * config.pipScale)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .offset(x: config.pipPosition.offset.x, y: config.pipPosition.offset.y)
            }
        }
    }

    private func splitPlayerView(size: CGSize) -> some View {
        let ratio: CGFloat = config.layout == .splitScreen7030 ? 0.7 : 0.5

        return HStack(spacing: 0) {
            if let player = primaryPlayer {
                VideoPlayer(player: player)
                    .frame(width: size.width * ratio, height: size.height)
            }

            if let player = secondaryPlayer {
                VideoPlayer(player: player)
                    .frame(width: size.width * (1 - ratio), height: size.height)
            }
        }
    }

    private func beforeAfterPlayerView(size: CGSize) -> some View {
        ZStack {
            if let afterPlayer = secondaryPlayer {
                VideoPlayer(player: afterPlayer)
                    .frame(width: size.width, height: size.height)
            }

            if let beforePlayer = primaryPlayer {
                VideoPlayer(player: beforePlayer)
                    .frame(width: size.width, height: size.height)
                    .mask(
                        Rectangle()
                            .frame(width: size.width * beforeAfterSlider)
                            .frame(width: size.width, alignment: .leading)
                    )
            }

            Rectangle()
                .fill(Color.white)
                .frame(width: 3)
                .offset(x: (size.width * beforeAfterSlider) - (size.width / 2))

            Circle()
                .fill(Color.white)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "arrow.left.and.right")
                        .foregroundStyle(.black)
                )
                .offset(x: (size.width * beforeAfterSlider) - (size.width / 2))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDraggingSlider = true
                            let newPosition = (value.location.x / size.width)
                            beforeAfterSlider = max(0, min(1, newPosition))
                        }
                        .onEnded { _ in
                            isDraggingSlider = false
                        }
                )
        }
    }

    private func setupPlayers() {
        if let primary = config.primaryAsset {
            let player = AVPlayer(url: primary.url)
            primaryPlayer = player
            player.play()
        }

        if let secondary = config.secondaryAsset {
            let player = AVPlayer(url: secondary.url)
            secondaryPlayer = player
            if config.syncPlayback {
                player.play()
            }
        }
    }

    private func cleanupPlayers() {
        primaryPlayer?.pause()
        secondaryPlayer?.pause()
        primaryPlayer = nil
        secondaryPlayer = nil
    }
}

#Preview {
    MultimodalLayoutEditor(
        config: .constant(.default),
        availableAssets: []
    )
}
