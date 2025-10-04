import Foundation
#if canImport(UIKit)
import UIKit
#endif

final class Haptics {
    static let shared = Haptics()

    #if canImport(UIKit)
    private let snapGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let toggleGenerator = UIImpactFeedbackGenerator(style: .medium)
    #endif

    private init() {}

    func snap() {
        #if canImport(UIKit)
        snapGenerator.impactOccurred()
        #endif
    }

    func toggle() {
        #if canImport(UIKit)
        toggleGenerator.impactOccurred()
        #endif
    }
}
