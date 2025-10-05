import AVFoundation
import XCTest
@testable import EndoEditCore

final class EndoEditCoreTests: XCTestCase {
    func testEditGraphRoundTrip() throws {
        let freeze = FreezeSegment(
            start: CMTime(seconds: 5, preferredTimescale: 600),
            duration: CMTime(seconds: 3, preferredTimescale: 600),
            sourceTime: CMTime(seconds: 5, preferredTimescale: 600),
            annotations: [
                .text(TextAnnotation(text: "Lesion", rect: NormalizedRect(x: 0.1, y: 0.1, width: 0.3, height: 0.15))),
                .shape(ShapeAnnotation(kind: .rectangle, rect: NormalizedRect(x: 0.4, y: 0.2, width: 0.2, height: 0.2)))
            ]
        )

        let redact = RedactOverlay(
            rect: NormalizedRect(x: 0.0, y: 0.0, width: 1.0, height: 0.2),
            activeTime: CMTimeRange(start: .zero, duration: CMTime(seconds: 30, preferredTimescale: 600)),
            style: .solidBlack
        )

        let ceiling = CeilingRedact(
            heightFraction: 0.18,
            activeTime: CMTimeRange(start: .zero, duration: CMTime(seconds: 30, preferredTimescale: 600))
        )

        let graph = EditGraph(operations: [.freeze(freeze), .redact(redact), .ceiling(ceiling)])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(graph)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EditGraph.self, from: data)

        XCTAssertEqual(decoded.version, EditGraph.schemaVersion)
        XCTAssertEqual(decoded, graph)
    }

    func testNormalizedRectClampsCorrectly() {
        let rect = NormalizedRect(x: -0.2, y: 0.9, width: 0.5, height: 0.5)
        XCTAssertEqual(rect.origin.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(rect.origin.y, 0.9, accuracy: 0.0001)
        XCTAssertEqual(rect.size.width, 0.5, accuracy: 0.0001)
        XCTAssertEqual(rect.size.height, 0.1, accuracy: 0.0001) // limited so origin+height <= 1
    }

    func testTimeRangeEncodingRoundTrip() throws {
        let range = CMTimeRange(start: CMTime(seconds: 10, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600))
        let value = TimeRangeValue(range)
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(TimeRangeValue.self, from: encoded)
        XCTAssertEqual(decoded, value)
        XCTAssertEqual(decoded.cmTimeRange, range)
    }
}
