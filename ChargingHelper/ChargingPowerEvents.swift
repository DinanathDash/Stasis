import Dispatch
import Foundation
import IOKit.ps
import IOKit.pwr_mgt
import notify
import os.log

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
            logger.info("Heat protection engaged (Temp: \(temp)C). Disabling charging and running on AC.")
            _ = ChargingPowerState.enablePowerAdapter(force: force)
            return ChargingPowerState.disableCharging(force: force)
        }

        ChargingPowerState.heatProtectionActive = false

        if chargingMode == .forceDischarge {
            _ = ChargingPowerState.disableCharging(force: force)
            return ChargingPowerState.disablePowerAdapter(force: force)
        }

        if !ChargingSettings.manageCharging {
            _ = ChargingPowerState.enablePowerAdapter(force: force)
            return ChargingPowerState.enableCharging(force: force)
        }

        let limit = ChargingSettings.chargeLimit
        let isUnlimited = IOKitHelper.isDrawingUnlimitedPower()

        if !isUnlimited {
            // When disconnected, reset to standard so that next plug-in resumes normal limits
            chargingMode = .standard
            return ChargingPowerState.disableCharging(force: force)
        }

        // Hysteresis logic
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

            if ChargingSettings.sailingMode, chargingMode == .standard {
                let sailingThreshold = limit >= ChargingSettings.sailingModeLimit ? limit - ChargingSettings.sailingModeLimit : 0
                if percent >= sailingThreshold, ChargingPowerState.isChargingDisabled() {
                    // Stay disabled in sailing mode range
                    ChargingPowerState.syncMagSafeState(percent: percent)
                    return (true, nil)
                }
            }
            return ChargingPowerState.enableCharging(force: force)
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
