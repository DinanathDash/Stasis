import Foundation
import Security


class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    let helper = Helper()

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        // Validate the code signature of the connecting process
        let pid = newConnection.processIdentifier
        let attributes = [kSecGuestAttributePid: pid] as CFDictionary

        var guestCode: SecCode?
        let status = SecCodeCopyGuestWithAttributes(nil, attributes, [], &guestCode)
        guard status == errSecSuccess, let validCode = guestCode else {
            return false
        }

        // Find the containing Stasis.app bundle
        var appURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        while appURL.path != "/" && appURL.pathExtension != "app" {
            appURL = appURL.deletingLastPathComponent()
        }
        
        guard appURL.pathExtension == "app" else { return false }
        
        var appStaticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(appURL as CFURL, [], &appStaticCode) == errSecSuccess,
              let appCode = appStaticCode else {
            return false
        }
        
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(appCode, [], &requirement) == errSecSuccess,
              let validReq = requirement else {
            return false
        }

        // Check validity against the requirement
        let checkStatus = SecCodeCheckValidity(validCode, [], validReq)
        guard checkStatus == errSecSuccess else {
            return false
        }

        newConnection.exportedInterface = NSXPCInterface(
            with: (any HelperProtocol).self
        )
        newConnection.exportedObject = helper
        newConnection.resume()
        return true
    }
}

let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
