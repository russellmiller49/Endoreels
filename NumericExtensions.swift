import Foundation
import CoreMedia

extension CMTime {
    /// Returns a non-negative, finite duration in seconds or `nil` when the time cannot be represented safely.
    var sanitizedSeconds: Double? {
        guard isNumeric else { return nil }
        let seconds = CMTimeGetSeconds(self)
        guard seconds.isFinite else { return nil }
        return max(seconds, 0)
    }
}

extension Double {
    /// Clamps invalid or negative numeric values to zero for safe geometry calculations.
    var finiteOrZero: Double {
        guard isFinite else { return 0 }
        return self >= 0 ? self : 0
    }
}

extension Optional where Wrapped == Double {
    /// Filters out non-finite optional values and clamps negatives to zero.
    var sanitizedNonNegative: Double? {
        guard let value = self, value.isFinite else { return nil }
        return value >= 0 ? value : 0
    }
}
