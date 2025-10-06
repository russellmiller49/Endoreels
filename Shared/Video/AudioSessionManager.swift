import AVFoundation
import os

/// Manages audio session configuration to prevent HALC overload errors
final class AudioSessionManager {
    private let log = Logger(subsystem: "EndoReels", category: "AudioSession")
    private var isConfigured = false
    
    static let shared = AudioSessionManager()
    
    private init() {}
    
    /// Configure audio session for video playback with optimized settings
    func configureForPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // Set category with options to prevent audio overload
            try session.setCategory(.playback, 
                                  mode: .moviePlayback, 
                                  options: [.allowAirPlay, .allowBluetoothHFP])
            
            // Configure buffer size to reduce I/O pressure
            try session.setPreferredIOBufferDuration(0.005) // 5ms buffer
            try session.setPreferredSampleRate(44100)
            
            // Activate session
            try session.setActive(true)
            isConfigured = true
            
            log.info("Audio session configured for playback")
        } catch {
            log.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    /// Configure audio session for recording
    func configureForRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            
            try session.setCategory(.record, 
                                  mode: .measurement, 
                                  options: [.allowBluetoothHFP])
            
            try session.setPreferredIOBufferDuration(0.01) // 10ms buffer for recording
            try session.setPreferredSampleRate(44100)
            
            try session.setActive(true)
            isConfigured = true
            
            log.info("Audio session configured for recording")
        } catch {
            log.error("Failed to configure audio session for recording: \(error.localizedDescription)")
        }
    }
    
    /// Reset audio session to default state
    func reset() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            isConfigured = false
            log.info("Audio session reset")
        } catch {
            log.error("Failed to reset audio session: \(error.localizedDescription)")
        }
    }
    
    /// Handle audio interruption
    func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            log.info("Audio interruption began")
        case .ended:
            log.info("Audio interruption ended")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    configureForPlayback()
                }
            }
        @unknown default:
            break
        }
    }
}
