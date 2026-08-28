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

        // Dynamically build requirement matching our own signing certificate's Common Name
        var selfCode: SecCode?
        guard SecCodeCopySelf(SecCSFlags(rawValue: 0), &selfCode) == errSecSuccess,
              let code = selfCode else { return false }
        
        var dict: CFDictionary?
        let staticCode = unsafeBitCast(code, to: SecStaticCode.self)
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &dict) == errSecSuccess,
              let info = dict as? [String: Any],
              let certs = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certs.first else { return false }
        
        var cnCF: CFString?
        SecCertificateCopyCommonName(leaf, &cnCF)
        guard let commonName = cnCF as String? else { return false }
        
        let reqString = "anchor apple generic and identifier \"com.dinanathdash.stasis\" and certificate leaf[subject.CN] = \"\(commonName)\"" as CFString
        
        var requirement: SecRequirement?
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
