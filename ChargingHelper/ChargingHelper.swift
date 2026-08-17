import Foundation
import os.log
import smc_power

private enum Constants {
    static let subsystem = "com.dinanathdash.stasis.charging-helper"
}

final class ChargingHelper: NSObject, ChargingHelperProtocol, @unchecked Sendable {
    private let logger = Logger(
        subsystem: Constants.subsystem,
        category: "ChargingHelper"
    )

    init(battery: SMCBattery, adapter: SMCAdapter) {
        super.init()
        Task { @MainActor in
            ChargingPowerState.initialize(battery: battery, adapter: adapter)
            ChargingPowerEvents.start()
        }
        
        logger.info(
            "Initialized (charging=\(battery.capabilities.inhibitChargeControl), discharge=\(battery.capabilities.forceDischargeControl), magSafe=\(adapter.capabilities.magSafeControl))"
        )
    }

    func setSettings(settings: [String: NSObject & Sendable], reply: @escaping @Sendable (Bool, String?) -> Void) {
        Task { @MainActor in
            ChargingSettings.setSettings(settings: settings)
            ChargingPowerState.syncSleepState()
            ChargingPowerEvents.settingsChanged()
            reply(true, nil)
        }
    }

    func getSettings(reply: @escaping @Sendable ([String: NSObject & Sendable]) -> Void) {
        Task { @MainActor in
            reply(ChargingSettings.getSettings())
        }
    }

    func chargeToLimit(reply: @escaping @Sendable (Bool, String?) -> Void) {
        Task { @MainActor in
            let (success, errorMessage) = ChargingPowerEvents.chargeToLimit()
            reply(success, errorMessage)
        }
    }

    func chargeToFull(reply: @escaping @Sendable (Bool, String?) -> Void) {
        Task { @MainActor in
            let (success, errorMessage) = ChargingPowerEvents.chargeToFull()
            reply(success, errorMessage)
        }
    }

    func disableCharging(reply: @escaping @Sendable (Bool, String?) -> Void) {
        Task { @MainActor in
            let (success, errorMessage) = ChargingPowerEvents.disableCharging()
            reply(success, errorMessage)
        }
    }

    func disablePowerAdapter(reply: @escaping @Sendable (Bool, String?) -> Void) {
        Task { @MainActor in
            let (success, errorMessage) = ChargingPowerEvents.forceDischarge()
            reply(success, errorMessage)
        }
    }

    func enablePowerAdapter(reply: @escaping @Sendable (Bool, String?) -> Void) {
        Task { @MainActor in
            let (success, errorMessage) = ChargingPowerState.enablePowerAdapter(force: true)
            reply(success, errorMessage)
        }
    }

    func manageMagsafeLED(target: UInt8, reply: @escaping @Sendable (Bool, String?) -> Void) {
        Task { @MainActor in
            let success = ChargingPowerState.manageMagsafeLED(target: target)
            reply(success, nil)
        }
    }

    func cancelOverride(reply: @escaping @Sendable (Bool, String?) -> Void) {
        Task { @MainActor in
            let (success, errorMessage) = ChargingPowerEvents.cancelOverride()
            reply(success, errorMessage)
        }
    }

    func resetToDefaults(reply: @escaping @Sendable (Bool, String?) -> Void) {
        Task { @MainActor in
            ChargingPowerEvents.chargingMode = .standard
            ChargingPowerState.restoreDefaults()
            reply(true, nil)
        }
    }
}

