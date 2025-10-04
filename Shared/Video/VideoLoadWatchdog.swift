import Foundation

final class VideoLoadWatchdog {
    private var workItem: DispatchWorkItem?

    func start(timeout: TimeInterval = 8, onTimeout: @escaping () -> Void) {
        cancel()
        let item = DispatchWorkItem(block: onTimeout)
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: item)
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
