import CoreMedia

extension CMTime {
    /// Returns a non-negative, finite duration in seconds or `nil` when the time cannot be represented safely.
    var sanitizedSeconds: Double? {
        guard isValid, isNumeric else { return nil }
        let seconds = CMTimeGetSeconds(self)
        guard seconds.isFinite else { return nil }
        return max(seconds, 0)
    }
}
