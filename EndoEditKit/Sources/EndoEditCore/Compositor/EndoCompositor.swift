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
               let entry = self.freezeEntry(for: freeze, request: request, trackID: instruction.sourceTrackID) {
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
                     request: AVAsynchronousVideoCompositionRequest,
                     trackID: CMPersistentTrackID) -> FreezeCacheEntry? {
        if let cached = freezeCache[segment.id] {
            return cached
        }

        guard let buffer = request.sourceFrame(byTrackID: trackID) else {
            return nil
        }

        let size = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
        let image = CIImage(cvPixelBuffer: buffer)
        let entry = FreezeCacheEntry(image: image, size: size)
        freezeCache[segment.id] = entry
        return entry
    }

    func render(image baseImage: CIImage,
                sourceSize: CGSize,
                cropRect: NormalizedRect?,
                renderContext: AVVideoCompositionRenderContext) -> CVPixelBuffer? {
        let outputSize = renderContext.size
        guard outputSize.width > 0, outputSize.height > 0 else { return nil }
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        guard let outputBuffer = renderContext.newPixelBuffer() else { return nil }

        var workingImage = baseImage
        let sanitizedCrop = cropRect?.sanitized()

        if let crop = sanitizedCrop {
            var rect = crop.rect(inWidth: sourceSize.width, height: sourceSize.height)
            rect.origin.y = sourceSize.height - rect.origin.y - rect.height
            rect = rect.integral
            guard rect.width > 0, rect.height > 0 else { return nil }
            workingImage = workingImage.cropped(to: rect)
            let scaleX = outputSize.width / rect.width
            let scaleY = outputSize.height / rect.height
            workingImage = workingImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        } else {
            let scaleX = outputSize.width / sourceSize.width
            let scaleY = outputSize.height / sourceSize.height
            workingImage = workingImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        }

        ciContext.render(workingImage,
                         to: outputBuffer,
                         bounds: CGRect(origin: .zero, size: outputSize),
                         colorSpace: colorSpace)

        return outputBuffer
    }
}

private struct FreezeCacheEntry {
    let image: CIImage
    let size: CGSize
}
