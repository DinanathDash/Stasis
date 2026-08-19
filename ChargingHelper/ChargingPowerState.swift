import Foundation
import os.log
import smc_power
import IOPMPrivate

@MainActor
enum ChargingPowerState {
    private static var chargingDisabled = false
    private static var powerDisabled = false
    
    private static var battery: SMCBattery?
    private static var adapter: SMCAdapter?
    private static var sleepDisabledByStasis = false

    private static let logger = Logger(subsystem: "com.dinanathdash.stasis.charging-helper", category: "ChargingPowerState")

    static func initialize(battery: SMCBattery, adapter: SMCAdapter) {
        self.battery = battery
        self.adapter = adapter
        
        do {
            if battery.capabilities.inhibitChargeControl {
                self.chargingDisabled = try battery.getChargingInhibited()
            }
            if battery.capabilities.forceDischargeControl {
                self.powerDisabled = try battery.getForceDischarging()
            }
        } catch {
            logger.error("Failed to read initial states: \(error.localizedDescription)")
        }
        
        GlobalSleep.restoreOnStart()
    }

    static func isChargingDisabled() -> Bool {
        return self.chargingDisabled
    }

    static func isPowerAdapterDisabled() -> Bool {
        return self.powerDisabled
    }

    static func syncSleepState() {
        let shouldDisableForCharging = !self.chargingDisabled && ChargingSettings.disableSleepUntilChargeLimit
        let shouldDisableForDischarging = self.powerDisabled && ChargingSettings.disableSleepWhileDischarging

        if shouldDisableForCharging || shouldDisableForDischarging {
            if !sleepDisabledByStasis {
                GlobalSleep.disable()
                sleepDisabledByStasis = true
            }
        } else {
            if sleepDisabledByStasis {
                GlobalSleep.restore()
                sleepDisabledByStasis = false
            }
        }
    }

    static func disableCharging(force: Bool = false) -> (Bool, String?) {
        guard force || !self.chargingDisabled else { return (true, nil) }
        guard let battery = self.battery else { return (false, "Battery is nil") }
        guard battery.capabilities.inhibitChargeControl else { return (false, "inhibitChargeControl is false") }

        do {
            try battery.setChargingInhibited(true)
            self.chargingDisabled = true
            logger.debug("SMC set charging inhibited to true")
            
            syncSleepState()
            let (percent, _) = IOKitHelper.getPercentRemaining()
            syncMagSafeState(percent: percent)
            return (true, nil)
        } catch {
            logger.error("Failed to disable charging: \(error.localizedDescription)")
            return (false, "Failed to disable charging: \(error.localizedDescription)")
        }
    }

    static func enableCharging(force: Bool = false) -> (Bool, String?) {
        guard force || self.chargingDisabled else { return (true, nil) }
        guard let battery = self.battery else { return (false, "Battery is nil") }
        guard battery.capabilities.inhibitChargeControl else { return (false, "inhibitChargeControl is false") }

        do {
            try battery.setChargingInhibited(false)
            self.chargingDisabled = false
            logger.debug("SMC set charging inhibited to false")
            
            syncSleepState()
            let (percent, _) = IOKitHelper.getPercentRemaining()
            syncMagSafeState(percent: percent)
            return (true, nil)
        } catch {
            logger.error("Failed to enable charging: \(error.localizedDescription)")
            return (false, "Failed to enable charging: \(error.localizedDescription)")
        }
    }

    static func disablePowerAdapter(force: Bool = false) -> (Bool, String?) {
        guard force || !self.powerDisabled else { return (true, nil) }
        guard let battery = self.battery else { return (false, "Battery is nil") }
        guard battery.capabilities.forceDischargeControl else { return (false, "forceDischargeControl is false") }

        do {
            try battery.setForceDischarging(true)
            self.powerDisabled = true
            logger.debug("SMC set force discharging to true")
            syncSleepState()
            return (true, nil)
        } catch {
            logger.error("Failed to disable power adapter: \(error.localizedDescription)")
            return (false, "Failed to disable power adapter: \(error.localizedDescription)")
        }
    }

    static func enablePowerAdapter(force: Bool = false) -> (Bool, String?) {
        guard force || self.powerDisabled else { return (true, nil) }
        guard let battery = self.battery else { return (false, "Battery is nil") }
        guard battery.capabilities.forceDischargeControl else { return (false, "forceDischargeControl is false") }

        do {
            try battery.setForceDischarging(false)
            self.powerDisabled = false
            logger.debug("SMC set force discharging to false")
            
            if self.chargingDisabled {
                try? battery.setChargingInhibited(true)
                logger.debug("SMC re-asserted charging inhibited to true after disabling power adapter")
            }
            
            syncSleepState()
            return (true, nil)
        } catch {
            logger.error("Failed to enable power adapter: \(error.localizedDescription)")
            return (false, "Failed to enable power adapter: \(error.localizedDescription)")
        }
    }

    @discardableResult
    static func manageMagsafeLED(target: UInt8) -> Bool {
        guard ChargingSettings.manageMagSafeLED else { return false }
        guard let adapter = self.adapter, adapter.capabilities.magSafeControl else { return false }
        guard let ledState = MagSafeLEDState(rawValue: target) else { return false }

        do {
            let currentState = try adapter.getMagSafeLEDState()
            if currentState.rawValue != target {
                try adapter.setMagSafeLEDState(ledState)
                logger.info("MagSafe LED changed from \(currentState.rawValue) to \(target)")
            }
            return true
        } catch {
            logger.error("Failed to manage MagSafe LED: \(error.localizedDescription)")
            return false
        }
    }

    static func syncMagSafeState(percent: UInt8) {
        if self.powerDisabled {
            manageMagsafeLED(target: ChargingSettings.dischargingMagSafeLEDState)
        } else if self.chargingDisabled || percent == 100 {
            manageMagsafeLED(target: ChargingSettings.pausedMagSafeLEDState)
        } else {
            manageMagsafeLED(target: ChargingSettings.chargingMagSafeLEDState)
        }
    }

    static func restoreDefaults() {
        _ = enableCharging()
        _ = enablePowerAdapter()
        _ = manageMagsafeLED(target: MagSafeLEDState.reset.rawValue)
    }
}

@MainActor
enum GlobalSleep {
    private static let previousSleepDisabledKey = "PreviousSleepDisabled"
    private static var disabledCounter: UInt8 = 0
    private static var previousDisabled = false
    private static var sleepAssertion: IOPMAssertionID = 0

    static func restoreOnStart() {
        guard let value = UserDefaults.standard.object(forKey: self.previousSleepDisabledKey) as? Bool else {
            return
        }
        
        self.setSleepDisabledIOPMValue(value: value as CFBoolean)
        UserDefaults.standard.removeObject(forKey: self.previousSleepDisabledKey)
        _ = CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    }

    static func forceRestore() {
        guard self.disabledCounter > 0 else { return }
        self.disabledCounter = 0
        self.restorePrevious()
    }

    static func restore() {
        guard self.disabledCounter > 0 else { return }
        self.disabledCounter -= 1
        guard self.disabledCounter == 0 else { return }
        self.restorePrevious()
    }

    static func disable() {
        assert(self.disabledCounter >= 0)
        self.disabledCounter += 1
        guard self.disabledCounter == 1 else { return }

        let sleepDisable = self.getSleepDisabledIOPMValue()
        self.previousDisabled = sleepDisable
        UserDefaults.standard.setValue(sleepDisable, forKey: self.previousSleepDisabledKey)
        _ = CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)

        // Create an explicit assertion to prevent system sleep (helps with clamshell mode transition)
        let reasonForActivity = "Stasis preventing sleep for charging/discharging" as CFString
        _ = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reasonForActivity,
            &sleepAssertion
        )

        guard !sleepDisable else { return }
        self.setSleepDisabledIOPMValue(value: kCFBooleanTrue)
    }

    private static func getSleepDisabledIOPMValue() -> Bool {
        guard let settingsRef = IOPMCopySystemPowerSettings() else { return false }
        guard let settings = settingsRef.takeUnretainedValue() as? [String: AnyObject] else { return false }
        guard let sleepDisable = settings[kIOPMSleepDisabledKey] as? Bool else { return false }
        return sleepDisable
    }

    private static func setSleepDisabledIOPMValue(value: CFBoolean) {
        let result = IOPMSetSystemPowerSetting(kIOPMSleepDisabledKey as CFString, value)
        if result != kIOReturnSuccess {
            // logger.error(...)
        }
    }

    private static func restorePrevious() {
        if sleepAssertion != 0 {
            IOPMAssertionRelease(sleepAssertion)
            sleepAssertion = 0
        }

        guard !self.previousDisabled else {
            self.previousDisabled = false
            return
        }
        
        self.setSleepDisabledIOPMValue(value: kCFBooleanFalse)
        UserDefaults.standard.removeObject(forKey: self.previousSleepDisabledKey)
        _ = CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    }
}
