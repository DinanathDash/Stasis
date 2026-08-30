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

        var guestCode: SecCode?
        let status = SecCodeCopyGuestWithAttributes(nil, attributes, [], &guestCode)
        guard status == errSecSuccess, let validCode = guestCode else {
            logger.error("Failed to get SecCode for connecting process (status: \(status))")
            return false
        }

        // Find the containing Stasis.app bundle
        var appURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        while appURL.path != "/" && appURL.pathExtension != "app" {
            appURL = appURL.deletingLastPathComponent()
        }
        
        guard appURL.pathExtension == "app" else {
            logger.error("Failed to find containing Stasis.app bundle")
            return false
        }
        
        var appStaticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(appURL as CFURL, [], &appStaticCode) == errSecSuccess,
              let appCode = appStaticCode else {
            logger.error("Failed to create SecStaticCode for app bundle")
            return false
        }
        
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(appCode, [], &requirement) == errSecSuccess,
              let validReq = requirement else {
            logger.error("Failed to copy Designated Requirement from app bundle")
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
