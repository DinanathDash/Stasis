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

        var code: SecCode?
        let status = SecCodeCopyGuestWithAttributes(nil, attributes, [], &code)
        guard status == errSecSuccess, let validCode = code else {
            return false
        }

        // Construct the requirement: identifier "com.dinanathdash.stasis"
        var requirement: SecRequirement?
        let reqString = "identifier \"com.dinanathdash.stasis\"" as CFString
        let reqStatus = SecRequirementCreateWithString(reqString, [], &requirement)
        guard reqStatus == errSecSuccess, let validReq = requirement else {
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
