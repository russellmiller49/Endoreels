import CoreGraphics

extension CGFloat {
    var finite: CGFloat { (isFinite && !isNaN) ? self : 0 }
}

func safeDiv(_ n: CGFloat, _ d: CGFloat, fallback: CGFloat = 0) -> CGFloat {
    guard d.isFinite, d != 0, n.isFinite else { return fallback }
    let value = n / d
    return value.isFinite ? value : fallback
}

func safeSize(_ w: CGFloat, _ h: CGFloat, fallback: CGSize = .zero) -> CGSize {
    let width = w.finite
    let height = h.finite
    return (width > 0 && height > 0) ? CGSize(width: width, height: height) : fallback
}

func clampPositive(_ x: CGFloat, min: CGFloat = 0.001) -> CGFloat {
    let value = x.finite
    return value > min ? value : min
}
