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

    private let battery: SMCBattery
    private let adapter: SMCAdapter

    init(battery: SMCBattery, adapter: SMCAdapter) {
        self.battery = battery
        self.adapter = adapter
        super.init()
        Task { @MainActor in
            ChargingPowerState.initialize(battery: battery, adapter: adapter)
            ChargingPowerEvents.start()
        }

        logger.info(
            "Initialized (charging=\(battery.capabilities.inhibitChargeControl), nativeLimit=\(battery.capabilities.nativeChargeLimitControl), discharge=\(battery.capabilities.forceDischargeControl), magSafe=\(adapter.capabilities.magSafeControl))"
        )
    }

    func ping(reply: @escaping @Sendable (Bool) -> Void) {
        reply(true)
    }

    func getCapabilities(reply: @escaping @Sendable (Bool, Bool, Bool, Bool, Bool) -> Void) {
        let powerUIAvailable = (try? PowerUIChargeBackend()) != nil
        // chargingControl is true if we can stop charging — either via legacy inhibit OR native CHLT (macOS 27+)
        let chargingControl = battery.capabilities.inhibitChargeControl || battery.capabilities.nativeChargeLimitControl || powerUIAvailable
        let adapterControl = battery.capabilities.forceDischargeControl
        let hasMagSafe = adapter.capabilities.magSafeControl
        let magsafeLEDControl = adapter.capabilities.magSafeControl
        reply(chargingControl, adapterControl, hasMagSafe, magsafeLEDControl, powerUIAvailable)
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
            UserDefaults.standard.removeObject(forKey: "manageCharging")
            UserDefaults.standard.synchronize()
            ChargingPowerEvents.chargingMode = .standard
            ChargingPowerState.restoreDefaults()
            reply(true, nil)
        }
    }
}
