import VideoToolbox

@discardableResult
func vtSetIfSupported(_ session: VTSession, key: CFString, value: CFTypeRef) -> OSStatus {
    var supportedDict: CFDictionary?
    let status = VTSessionCopySupportedPropertyDictionary(session, supportedPropertyDictionaryOut: &supportedDict)
    guard status == noErr, let dictionary = supportedDict as? [CFString: Any], dictionary[key] != nil else {
        return kVTPropertyNotSupportedErr
    }
    return VTSessionSetProperty(session, key: key, value: value)
}
