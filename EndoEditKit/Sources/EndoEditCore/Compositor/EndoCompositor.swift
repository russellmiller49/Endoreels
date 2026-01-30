import AVFoundation
import CoreImage
import Metal

/// Initial pass-through compositor. It simply forwards the source frame without modification.
public final class EndoCompositor: NSObject, AVVideoCompositing {
    private let renderQueue = DispatchQueue(label: "com.endoreels.endocompositor.renderqueue")
    private let device: MTLDevice?
    private var renderContext: AVVideoCompositionRenderContext?
    private let ciContext = CIContext(options: nil)
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private var freezeCache: [UUID: FreezeCacheEntry] = [:]

    public let sourcePixelBufferAttributes: [String: any Sendable]?
    public let requiredPixelBufferAttributesForRenderContext: [String: any Sendable]

    public override init() {
        self.device = MTLCreateSystemDefaultDevice()
        let attributes: [String: any Sendable] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        self.sourcePixelBufferAttributes = attributes
        self.requiredPixelBufferAttributesForRenderContext = attributes
        super.init()
    }

    public var supportsWideColorSourceFrames: Bool {
        false
    }

    public func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        renderQueue.sync {
            renderContext = newRenderContext
            freezeCache.removeAll()
        }
    }

    public func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        renderQueue.async {
            guard let instruction = request.videoCompositionInstruction as? EndoCompositionInstruction else {
                request.finish(with: EndoCompositorError.invalidInstruction)
                return
            }

            guard let renderContext = self.renderContext else {
                request.finish(with: EndoCompositorError.missingRenderContext)
                return
            }

            let renderResult: CVPixelBuffer?

            if let freeze = self.freezeSegment(containing: request.compositionTime, from: instruction.freezeSegments),
               let entry = self.freezeEntry(for: freeze, instruction: instruction, request: request) {
                renderResult = self.render(image: entry.image,
                                           sourceSize: entry.size,
                                           cropRect: instruction.cropRect,
                                           renderContext: renderContext)
            } else if let sourceBuffer = request.sourceFrame(byTrackID: instruction.sourceTrackID) {
                let sourceSize = CGSize(width: CVPixelBufferGetWidth(sourceBuffer),
                                        height: CVPixelBufferGetHeight(sourceBuffer))
                let sourceImage = CIImage(cvPixelBuffer: sourceBuffer)
                renderResult = self.render(image: sourceImage,
                                           sourceSize: sourceSize,
                                           cropRect: instruction.cropRect,
                                           renderContext: renderContext) ?? sourceBuffer
            } else {
                request.finish(with: EndoCompositorError.missingSourceFrame)
                return
            }

            request.finish(withComposedVideoFrame: renderResult ?? request.sourceFrame(byTrackID: instruction.sourceTrackID)!)
        }
    }

    public func cancelAllPendingVideoCompositionRequests() {
        renderQueue.sync {
            // No-op for pass-through mode.
        }
    }
}

public enum EndoCompositorError: Error {
    case invalidInstruction
    case missingSourceFrame
    case missingRenderContext
}

private extension EndoCompositor {
    func freezeSegment(containing time: CMTime, from segments: [FreezeSegment]) -> FreezeSegment? {
        segments.first(where: { CMTimeRangeContainsTime($0.timeRange, time: time) })
    }

    func freezeEntry(for segment: FreezeSegment,
                     instruction: EndoCompositionInstruction,
                     request: AVAsynchronousVideoCompositionRequest) -> FreezeCacheEntry? {
        if let cached = freezeCache[segment.id] {
            return cached
        }

        if let generator = instruction.imageGenerator {
            var actual = CMTime.zero
            if let cgImage = try? generator.copyCGImage(at: segment.sourceTime, actualTime: &actual) {
                let width = cgImage.width
                let height = cgImage.height
                guard width > 0, height > 0 else { return fallbackEntry(request: request, instruction: instruction, segment: segment) }
                let image = CIImage(cgImage: cgImage)
                let size = CGSize(width: width, height: height)
                let entry = FreezeCacheEntry(image: image, size: size)
                freezeCache[segment.id] = entry
                return entry
            }
        }

        return fallbackEntry(request: request, instruction: instruction, segment: segment)
    }

    private func fallbackEntry(request: AVAsynchronousVideoCompositionRequest,
                               instruction: EndoCompositionInstruction,
                               segment: FreezeSegment) -> FreezeCacheEntry? {
        if let buffer = request.sourceFrame(byTrackID: instruction.sourceTrackID) {
            let width = CVPixelBufferGetWidth(buffer)
            let height = CVPixelBufferGetHeight(buffer)
            guard width > 0, height > 0 else { return nil }
            let size = CGSize(width: width, height: height)
            let image = CIImage(cvPixelBuffer: buffer)
            let entry = FreezeCacheEntry(image: image, size: size)
            freezeCache[segment.id] = entry
            return entry
        }
        return nil
    }

    func render(image baseImage: CIImage,
                sourceSize: CGSize,
                cropRect: NormalizedRect?,
                renderContext: AVVideoCompositionRenderContext) -> CVPixelBuffer? {
        let outputSize = renderContext.size
        print("🎨 Compositor.render: outputSize=\(outputSize), sourceSize=\(sourceSize), cropRect=\(String(describing: cropRect))")

        guard sanitizeValue(outputSize.width) > 0, sanitizeValue(outputSize.height) > 0 else {
            print("❌ Compositor.render: Invalid outputSize")
            return nil
        }
        guard sanitizeValue(sourceSize.width) > 0, sanitizeValue(sourceSize.height) > 0 else {
            print("❌ Compositor.render: Invalid sourceSize")
            return nil
        }

        guard let outputBuffer = renderContext.newPixelBuffer() else { return nil }

        var workingImage = baseImage
        let sanitizedCrop = cropRect?.sanitized()

        if let crop = sanitizedCrop {
            var rect = crop.rect(inWidth: sourceSize.width, height: sourceSize.height)
            if rect.isFinite == false {
                print("❌ Compositor.render: Non-finite rect from crop=\(rect)")
                return nil
            }
            print("🎨 Compositor.render: pre-flip rect=\(rect)")

            // Flip Y coordinate for CoreImage coordinate system (validate all components)
            let flippedY = sanitizeValue(sourceSize.height - rect.origin.y - rect.height, min: 0)
            rect.origin.y = flippedY

            // Validate rect components before integral conversion
            rect.origin.x = sanitizeValue(rect.origin.x, min: 0)
            rect.size.width = sanitizeValue(rect.size.width, min: 1)
            rect.size.height = sanitizeValue(rect.size.height, min: 1)
            print("🎨 Compositor.render: sanitized rect=\(rect)")

            rect = rect.integral
            print("🎨 Compositor.render: integral rect=\(rect)")
            guard rect.width > 0, rect.height > 0 else {
                print("❌ Compositor.render: Invalid rect after integral")
                return nil
            }

            workingImage = workingImage.cropped(to: rect)
            let scaleX = sanitizeValue(outputSize.width / rect.width, min: 0.01)
            let scaleY = sanitizeValue(outputSize.height / rect.height, min: 0.01)
            guard scaleX > 0, scaleY > 0 else { return nil }
            workingImage = workingImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        } else {
            let scaleX = sanitizeValue(outputSize.width / sourceSize.width, min: 0.01)
            let scaleY = sanitizeValue(outputSize.height / sourceSize.height, min: 0.01)
            guard scaleX > 0, scaleY > 0 else { return nil }
            workingImage = workingImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        }

        // Validate the final image extent before rendering
        let extent = workingImage.extent
        guard extent.isFinite,
              extent.width.isFinite,
              extent.height.isFinite,
              !extent.isEmpty else {
            return nil
        }

        let renderBounds = CGRect(origin: .zero, size: outputSize)
        guard renderBounds.isFinite,
              renderBounds.width > 0,
              renderBounds.height > 0 else {
            return nil
        }

        ciContext.render(workingImage,
                         to: outputBuffer,
                         bounds: renderBounds,
                         colorSpace: colorSpace)

        return outputBuffer
    }

    private func sanitizeValue(_ value: CGFloat, min minValue: CGFloat = 0) -> CGFloat {
        guard value.isFinite else {
            print("⚠️ Compositor.render: Non-finite value encountered (value=\(value)); clamping to \(minValue)")
            return minValue
        }
        if value < minValue {
            print("⚠️ Compositor.render: Value \(value) below minimum \(minValue); clamping")
        }
        return max(value, minValue)
    }
}

private extension CGRect {
    var isFinite: Bool {
        origin.x.isFinite && origin.y.isFinite && size.width.isFinite && size.height.isFinite
    }
}

private struct FreezeCacheEntry {
    let image: CIImage
    let size: CGSize
}
