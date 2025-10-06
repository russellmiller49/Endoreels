import AVFoundation
import UIKit
import os

/// Centralized manager for AVFoundation resource lifecycle
final class AVFoundationManager {
    private let log = Logger(subsystem: "EndoReels", category: "AVFoundation")
    private var activePlayers: Set<ObjectIdentifier> = []
    private var activeExportSessions: Set<ObjectIdentifier> = []
    
    static let shared = AVFoundationManager()
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    /// Register a player for lifecycle management
    func registerPlayer(_ player: AVPlayer) {
        let id = ObjectIdentifier(player)
        activePlayers.insert(id)
        log.debug("Registered player: \(String(describing: id))")
    }
    
    /// Unregister a player
    func unregisterPlayer(_ player: AVPlayer) {
        let id = ObjectIdentifier(player)
        activePlayers.remove(id)
        log.debug("Unregistered player: \(String(describing: id))")
    }
    
    /// Register an export session
    func registerExportSession(_ session: AVAssetExportSession) {
        let id = ObjectIdentifier(session)
        activeExportSessions.insert(id)
        log.debug("Registered export session: \(String(describing: id))")
    }
    
    /// Unregister an export session
    func unregisterExportSession(_ session: AVAssetExportSession) {
        let id = ObjectIdentifier(session)
        activeExportSessions.remove(id)
        log.debug("Unregistered export session: \(String(describing: id))")
    }
    
    /// Get count of active players
    var activePlayerCount: Int {
        activePlayers.count
    }
    
    /// Get count of active export sessions
    var activeExportSessionCount: Int {
        activeExportSessions.count
    }
    
    /// Safely invalidate a player
    func invalidatePlayer(_ player: AVPlayer) {
        player.pause()
        player.replaceCurrentItem(with: nil)
        unregisterPlayer(player)
        log.debug("Invalidated player")
    }
    
    /// Safely cancel an export session
    func cancelExportSession(_ session: AVAssetExportSession) {
        session.cancelExport()
        unregisterExportSession(session)
        log.debug("Cancelled export session")
    }
    
    @objc private func handleMemoryWarning() {
        log.warning("Memory warning received - cleaning up AVFoundation resources")
        
        // Log resource usage for debugging
        log.info("Active players: \(self.activePlayers.count), Active exports: \(self.activeExportSessions.count)")
        
        // Note: We track ObjectIdentifiers but can't directly access the objects
        // This is a limitation of the current design, but helps with resource awareness
    }
    
    @objc private func handleAppWillResignActive() {
        log.info("App will resign active - pausing AVFoundation operations")
        // Audio session will be handled by AudioSessionManager
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

/// Extension to track player lifecycle automatically
extension AVPlayer {
    private static var isRegisteredKey: UInt8 = 0
    
    var isLifecycleManaged: Bool {
        get {
            return objc_getAssociatedObject(self, &Self.isRegisteredKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &Self.isRegisteredKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func enableLifecycleManagement() {
        guard !isLifecycleManaged else { return }
        AVFoundationManager.shared.registerPlayer(self)
        isLifecycleManaged = true
    }
    
    func disableLifecycleManagement() {
        guard isLifecycleManaged else { return }
        AVFoundationManager.shared.unregisterPlayer(self)
        isLifecycleManaged = false
    }
}

/// Extension to track export session lifecycle automatically
extension AVAssetExportSession {
    private static var isRegisteredKey: UInt8 = 0
    
    var isLifecycleManaged: Bool {
        get {
            return objc_getAssociatedObject(self, &Self.isRegisteredKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &Self.isRegisteredKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func enableLifecycleManagement() {
        guard !isLifecycleManaged else { return }
        AVFoundationManager.shared.registerExportSession(self)
        isLifecycleManaged = true
    }
    
    func disableLifecycleManagement() {
        guard isLifecycleManaged else { return }
        AVFoundationManager.shared.unregisterExportSession(self)
        isLifecycleManaged = false
    }
}
