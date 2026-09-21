import Dispatch
import Foundation
import IOKit.ps
import IOKit.pwr_mgt
import notify
import os.log
import smc_power

@MainActor
enum ChargingPowerEvents {
    enum ChargingMode {
        case standard
        case toLimit
        case toFull
        case forceDischarge
    }

    static var chargingMode = ChargingMode.standard
    private static var powerToken: Int32 = 0
    private static var percentToken: Int32 = 0
    private static var isRunning = false

    private static let logger = Logger(subsystem: "com.dinanathdash.stasis.charging-helper", category: "ChargingPowerEvents")

    static func start() {
        guard !isRunning else { return }
        isRunning = true

        notify_register_dispatch(
            kIOPSNotifyPowerSource,
            &powerToken,
            DispatchQueue.main
        ) { _ in
            self.handlePowerEvent()
        }

        notify_register_dispatch(
            "com.apple.system.powersources.percent",
            &percentToken,
            DispatchQueue.main
        ) { _ in
            self.handlePercentEvent()
        }

        let callback: IOServiceInterestCallback = { _, _, messageType, messageArgument in
            if messageType == PowerEvents.kIOMessageCanSystemSleep ||
                messageType == PowerEvents.kIOMessageSystemWillSleep
            {
                IOAllowPowerChange(
                    PowerEvents.root_port,
                    Int(bitPattern: messageArgument)
                )
            } else if messageType == PowerEvents.kIOMessageSystemHasPoweredOn {
                Task { @MainActor in
                    ChargingPowerEvents.wakeFromSleep()
                }
            }
        }

        let success = PowerEvents.register(callback: callback)
        guard success else {
            logger.error("Error registering system power event")
            exit(-1)
        }

        handlePowerEvent()
    }

    static func wakeFromSleep() {
        // Force evaluation on wake
        _ = evaluateState()
    }

    static func stop() {
        guard isRunning else { return }
        isRunning = false
        notify_cancel(powerToken)
        notify_cancel(percentToken)
        PowerEvents.deregister()
    }

    static func chargeToLimit() -> (Bool, String?) {
        chargingMode = .toLimit
        return evaluateState(force: true)
    }

    static func chargeToFull() -> (Bool, String?) {
        chargingMode = .toFull
        return evaluateState(force: true)
    }

    static func disableCharging() -> (Bool, String?) {
        chargingMode = .standard
        return ChargingPowerState.disableCharging(force: true)
    }

    static func forceDischarge() -> (Bool, String?) {
        chargingMode = .forceDischarge
        return evaluateState(force: true)
    }

    static func cancelOverride() -> (Bool, String?) {
        chargingMode = .standard
        return evaluateState(force: true)
    }

    static func settingsChanged() {
        _ = evaluateState()
    }

    private static func handlePowerEvent() {
        _ = evaluateState()
    }

    private static func handlePercentEvent() {
        _ = evaluateState()
    }

    @discardableResult
    static func evaluateState(force: Bool = false) -> (Bool, String?) {
        let (percent, _) = IOKitHelper.getPercentRemaining()

        defer {
            ChargingPowerState.syncMagSafeState(percent: percent)
        }

        // Heat Protection
        if ChargingSettings.enableHeatProtectionMode,
           let temp = IOKitHelper.getBatteryTemperature(),
           temp > Double(ChargingSettings.heatProtectionLimit)
        {
            ChargingPowerState.heatProtectionActive = true
            logger.info("Heat protection engaged (Temp: \(temp)°C)")

            if ChargingPowerState.nativeMode {
                // macOS 27: clamp PowerUI limit to current percent so firmware stops now
                ChargingPowerState.applyNativeLimit(Int(percent))
                _ = ChargingPowerState.enablePowerAdapter(force: force)
                return ChargingPowerState.disableCharging(force: force)
            } else {
                // Legacy macOS 26: SMC inhibit
                _ = ChargingPowerState.enablePowerAdapter(force: force)
                return ChargingPowerState.disableCharging(force: force)
            }
        }
        ChargingPowerState.heatProtectionActive = false

        // Force Discharge
        if chargingMode == .forceDischarge {
            _ = ChargingPowerState.disableCharging(force: force)
            return ChargingPowerState.disablePowerAdapter(force: force)
        }

        // Charging Management Off
        if !ChargingSettings.manageCharging {
            if ChargingPowerState.nativeMode {
                ChargingPowerState.applyNativeLimit(100)
            }
            _ = ChargingPowerState.enablePowerAdapter(force: force)
            return ChargingPowerState.enableCharging(force: force)
        }

        // Disconnected
        let limit = ChargingSettings.chargeLimit
        let isUnlimited = IOKitHelper.isDrawingUnlimitedPower()

        if !isUnlimited {
            chargingMode = .standard
            return ChargingPowerState.disableCharging(force: force)
        }

        // macOS 27 PowerUI path
        if ChargingPowerState.nativeMode {
            return evaluateStateNative(percent: percent, limit: limit, force: force)
        }
        
        if ChargingPowerState.dischargeOnlyFallback {
            return evaluateStateDischargeOnly(percent: percent, limit: limit, force: force)
        }

        // Legacy macOS 26 (inhibit-based — strictly restored)
        let sailingActive = ChargingSettings.sailingMode && chargingMode == .standard
        let sailingThreshold: UInt8 = sailingActive
            ? (limit >= ChargingSettings.sailingModeLimit ? limit - ChargingSettings.sailingModeLimit : 0)
            : 0

        if percent >= limit {
            if chargingMode == .toFull, percent < 100 {
                _ = ChargingPowerState.enablePowerAdapter(force: force)
                return ChargingPowerState.enableCharging(force: force)
            } else {
                if ChargingSettings.automaticDischarge, percent > limit {
                    _ = ChargingPowerState.disablePowerAdapter(force: force)
                } else {
                    _ = ChargingPowerState.enablePowerAdapter(force: force)
                }
                return ChargingPowerState.disableCharging(force: force)
            }
        } else {
            _ = ChargingPowerState.enablePowerAdapter(force: force)
            if sailingActive, percent >= sailingThreshold {
                if ChargingPowerState.isChargingDisabled() {
                    ChargingPowerState.syncMagSafeState(percent: percent)
                    return (true, nil)
                }
                return ChargingPowerState.disableCharging(force: force)
            }
            return ChargingPowerState.enableCharging(force: force)
        }
    }

    // MARK: - macOS 27 PowerUI evaluation

    private static func powerUISailingThreshold(limit: UInt8, session: NativeChargeSession) -> Int? {
        guard ChargingSettings.sailingMode else { return nil }
        let raw = Int(limit) - Int(ChargingSettings.sailingModeLimit)
        guard let threshold = session.nearestLimit(atOrBelow: raw), threshold >= 80,
              threshold < Int(limit) else { return nil }
        return threshold
    }

    // MARK: - macOS 27 (PowerUI)
    @discardableResult
    private static func evaluateStateNative(percent: UInt8, limit: UInt8, force: Bool) -> (Bool, String?) {
        guard let session = ChargingPowerState.nativeSession else {
            return (false, "nativeSession unexpectedly nil")
        }

        let sailingActive = ChargingSettings.sailingMode && chargingMode == .standard
        let sailingThreshold = powerUISailingThreshold(limit: limit, session: session)

        if percent >= limit {
            if chargingMode == .toFull, percent < 100 {
                ChargingPowerState.applyNativeLimit(100)
                _ = ChargingPowerState.enablePowerAdapter(force: force)
                return ChargingPowerState.enableCharging(force: force)
            } else {
                // To prevent active discharge on battery, we must never set the PowerUI limit
                // BELOW the current percentage. We clamp it to `percent` to force AC power pause.
                let targetNativeLimit = max(Int(limit), Int(percent))
                ChargingPowerState.applyNativeLimit(targetNativeLimit)
                
                // If they specifically ask for forced discharge, use it. Otherwise, native pause works.
                if ChargingSettings.automaticDischarge, percent > limit {
                    _ = ChargingPowerState.disablePowerAdapter(force: force)
                } else {
                    _ = ChargingPowerState.enablePowerAdapter(force: force)
                }
                return ChargingPowerState.disableCharging(force: force)
            }
        } else if let threshold = sailingThreshold, Int(percent) >= threshold {
            // Sailing zone
            // Set native limit to current percentage to pause charging on AC adapter without active draining
            ChargingPowerState.applyNativeLimit(Int(percent))
            _ = ChargingPowerState.enablePowerAdapter(force: force)
            if ChargingPowerState.isChargingDisabled() {
                ChargingPowerState.syncMagSafeState(percent: percent)
                return (true, nil)
            }
            return ChargingPowerState.disableCharging(force: force)
        } else {
            // Below threshold (or sailing off): charge to limit
            ChargingPowerState.applyNativeLimit(Int(limit))
            _ = ChargingPowerState.enablePowerAdapter(force: force)
            return ChargingPowerState.enableCharging(force: force)
        }
    }
    
    // MARK: - macOS 15.8 Fallback
    
    @discardableResult
    private static func evaluateStateDischargeOnly(percent: UInt8, limit: UInt8, force: Bool) -> (Bool, String?) {
        if chargingMode == .toFull && percent < 100 {
            _ = ChargingPowerState.enablePowerAdapter(force: force)
            return (true, nil)
        }
        
        // On macOS 27 without PowerUI, pausing is physically impossible. 
        // We must bounce between the limit and an upper trigger threshold.
        // We do not discharge down to sailing threshold because it forces a deep physical battery drain.
        if percent >= limit {
            if ChargingSettings.automaticDischarge {
                let triggerLimit = min(100, Int(limit) + 1)
                if Int(percent) > triggerLimit {
                    _ = ChargingPowerState.disablePowerAdapter(force: force)
                } else if percent < limit {
                    _ = ChargingPowerState.enablePowerAdapter(force: force)
                } else {
                    // Inside deadband (e.g. 85-86): maintain current state
                    if force {
                        if ChargingPowerState.isPowerAdapterDisabled() {
                            _ = ChargingPowerState.disablePowerAdapter(force: true)
                        } else {
                            _ = ChargingPowerState.enablePowerAdapter(force: true)
                        }
                    }
                }
            } else {
                _ = ChargingPowerState.enablePowerAdapter(force: force)
            }
            return (true, nil)
        } else {
            _ = ChargingPowerState.enablePowerAdapter(force: force)
            return (true, nil)
        }
    }
}

@MainActor
enum PowerEvents {
    private static func err_system(_ x: UInt32) -> UInt32 {
        return (x & 0x3F) << 26
    }

    private static func err_sub(_ x: UInt32) -> UInt32 {
        return (x & 0xFFF) << 14
    }

    private static let sys_iokit = err_system(0x38)
    private static let sub_iokit_common = err_sub(0)
    private static func iokit_common_msg(_ message: UInt32) -> UInt32 {
        return sys_iokit | sub_iokit_common | message
    }

    static let kIOMessageCanSystemSleep = iokit_common_msg(0x270)
    static let kIOMessageSystemWillSleep = iokit_common_msg(0x280)
    static let kIOMessageSystemHasPoweredOn = iokit_common_msg(0x300)

    private static var notifyPortRef: IONotificationPortRef?
    private static var notifierObject: io_object_t = IO_OBJECT_NULL
    private(set) static var root_port: io_connect_t = IO_OBJECT_NULL

    static func register(callback: @escaping IOServiceInterestCallback) -> Bool {
        assert(root_port == IO_OBJECT_NULL)
        assert(notifyPortRef == nil)
        assert(notifierObject == IO_OBJECT_NULL)

        root_port = IORegisterForSystemPower(
            nil,
            &notifyPortRef,
            callback,
            &notifierObject
        )
        guard root_port != IO_OBJECT_NULL else {
            return false
        }

        assert(notifyPortRef != nil)
        assert(notifierObject != IO_OBJECT_NULL)

        IONotificationPortSetDispatchQueue(
            notifyPortRef!,
            DispatchQueue.main
        )

        return true
    }

    static func deregister() {
        assert(root_port != IO_OBJECT_NULL)
        assert(notifyPortRef != nil)
        assert(notifierObject != IO_OBJECT_NULL)

        IODeregisterForSystemPower(&notifierObject)
        IOServiceClose(root_port)
        IONotificationPortDestroy(notifyPortRef!)

        root_port = IO_OBJECT_NULL
        notifyPortRef = nil
        notifierObject = IO_OBJECT_NULL
    }
}
