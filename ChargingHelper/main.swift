import Foundation
import Security
import os.log
import smc_power

let logger = Logger(
    subsystem: "com.dinanathdash.stasis.charging-helper",
    category: "ServiceDelegate"
)

let battery: SMCBattery
let adapter: SMCAdapter
do {
    battery = try SMCBattery.probe()
    adapter = try SMCAdapter.probe()
} catch {
    logger.fault("Failed to probe SMC capabilities: \(error.localizedDescription)")
    exit(1)
}

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    let helper: ChargingHelper

    init(helper: ChargingHelper) {
        self.helper = helper
    }

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
            logger.error("Failed to get SecCode for connecting process PID \(pid) (status: \(status))")
            return false
        }

        // Dynamically build requirement matching our own signing certificate's Common Name
        var selfCode: SecCode?
        guard SecCodeCopySelf(SecCSFlags(rawValue: 0), &selfCode) == errSecSuccess,
              let code = selfCode else { return false }
        
        var dict: CFDictionary?
        let staticCode = unsafeBitCast(code, to: SecStaticCode.self)
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &dict) == errSecSuccess,
              let info = dict as? [String: Any] else { return false }
        
        let flags = info[kSecCodeInfoFlags as String] as? UInt32 ?? 0
        let isAdHoc = (flags & SecCodeSignatureFlags.adhoc.rawValue) != 0
        
        let reqString: CFString
        if isAdHoc {
            reqString = "identifier \"com.dinanathdash.stasis\"" as CFString
        } else {
            guard let certs = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
                  let leaf = certs.first else { return false }
            
            var cnCF: CFString?
            SecCertificateCopyCommonName(leaf, &cnCF)
            guard let commonName = cnCF as String? else { return false }
            
            reqString = "anchor apple generic and identifier \"com.dinanathdash.stasis\" and certificate leaf[subject.CN] = \"\(commonName)\"" as CFString
        }
        
        var requirement: SecRequirement?
        let reqStatus = SecRequirementCreateWithString(reqString, [], &requirement)
        guard reqStatus == errSecSuccess, let validReq = requirement else {
            logger.error("Failed to create SecRequirement")
            return false
        }

        // Check validity against the requirement
        let checkStatus = SecCodeCheckValidity(validCode, [], validReq)
        guard checkStatus == errSecSuccess else {
            logger.error("XPC connection rejected: Process does not match required code signature (status: \(checkStatus))")
            return false
        }

        logger.info("XPC connection accepted from valid Stasis process")

        newConnection.exportedInterface = NSXPCInterface(
            with: (any ChargingHelperProtocol).self
        )
        newConnection.exportedObject = helper

        newConnection.invalidationHandler = {
            logger.info("XPC connection invalidated. Resetting to safe defaults and stopping power events.")
            Task { @MainActor in
                ChargingPowerState.restoreDefaults()
                ChargingPowerEvents.stop()
            }
        }

        newConnection.resume()
        return true
    }
}

let helper = ChargingHelper(battery: battery, adapter: adapter)
let delegate = ServiceDelegate(helper: helper)
let listener = NSXPCListener(
    machServiceName: "com.dinanathdash.stasis.charging-helper"
)
listener.delegate = delegate
listener.resume()

// Initialize the SMC Power state controller
ChargingPowerState.initialize(battery: battery, adapter: adapter)

// Start monitoring power events in the background
ChargingPowerEvents.start()

// Setup graceful teardown
let termSource = DispatchSource.makeSignalSource(
    signal: SIGTERM,
    queue: DispatchQueue.main
)
termSource.setEventHandler {
    ChargingPowerState.restoreDefaults()
    ChargingPowerEvents.stop()
    exit(0)
}
termSource.resume()
signal(SIGTERM, SIG_IGN)

dispatchMain()
