import VideoToolbox
import os

private let log = Logger(subsystem: "EndoReels", category: "VideoToolbox")

@discardableResult
func vtSetIfSupported(_ session: VTSession, key: CFString, value: CFTypeRef) -> OSStatus {
    var supportedDict: CFDictionary?
    let status = VTSessionCopySupportedPropertyDictionary(session, supportedPropertyDictionaryOut: &supportedDict)
    
    guard status == noErr, let dictionary = supportedDict as? [CFString: Any], dictionary[key] != nil else {
        log.debug("Property \(key) not supported by session")
        return kVTPropertyNotSupportedErr
    }
    
    let result = VTSessionSetProperty(session, key: key, value: value)
    if result != noErr {
        log.error("Failed to set property \(key): \(result)")
    }
    return result
}

/// Safely configure VideoToolbox session with fallback for unsupported properties
@discardableResult
func vtConfigureSession(_ session: VTSession, properties: [(CFString, CFTypeRef)]) -> OSStatus {
    var lastError: OSStatus = noErr
    
    for (key, value) in properties {
        let result = vtSetIfSupported(session, key: key, value: value)
        if result != noErr && result != kVTPropertyNotSupportedErr {
            lastError = result
        }
    }
    
    return lastError
}
