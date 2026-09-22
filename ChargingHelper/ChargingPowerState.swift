import Foundation
import IOPMPrivate
import os.log
import smc_power

@MainActor
enum ChargingPowerState {
    private(set) static var chargingDisabled = false
    private(set) static var powerDisabled = false
    static var heatProtectionActive = false

    private static var battery: SMCBattery?
    private static var adapter: SMCAdapter?
    private static var sleepDisabledByStasis = false

    /// PowerUI session — non-nil on macOS 27 when PowerUISmartChargeClient is available.
    /// This is the ONLY entry point for charge limit writes on macOS 27.
    private(set) static var nativeSession: NativeChargeSession?

    /// True when PowerUI backend is active (macOS 27). All legacy SMC paths are skipped.
    static var nativeMode: Bool { nativeSession != nil }
    
    /// True when the Mac has no inhibit control but has force discharge control (macOS 15.8 workaround)
    static var dischargeOnlyFallback: Bool {
        guard let capabilities = battery?.capabilities else { return false }
        return !nativeMode && !capabilities.inhibitChargeControl && capabilities.forceDischargeControl
    }

    private static let logger = Logger(subsystem: "com.dinanathdash.stasis.charging-helper", category: "ChargingPowerState")

    static func initialize(battery: SMCBattery, adapter: SMCAdapter) {
        self.battery = battery
        self.adapter = adapter

        // ── macOS 27: Try PowerUI backend first ──────────────────────────────────
        if battery.capabilities.nativeChargeLimitControl {
            do {
                let backend = try PowerUIChargeBackend()
                let session = NativeChargeSession(backend: backend)
                nativeSession = session
                logger.info("PowerUI backend ready — using native charge control (macOS 27+)")
                // Recover from crash: restore journaled limit before applying management
                do { try session.restore() } catch {
                    logger.error("PowerUI recovery failed: \(error.localizedDescription)")
                }
                // Sync to configured limit if management is active
                if ChargingSettings.manageCharging {
                    do {
                        let limit = Int(ChargingSettings.chargeLimit)
                        try session.apply(snapToPowerUI(limit, session: session))
                        logger.info("PowerUI synced charge limit to \(limit)% on startup")
                    } catch {
                        logger.error("PowerUI startup sync failed: \(error.localizedDescription)")
                }
                }
            } catch {
                logger.warning("CHLT key present but PowerUI unavailable (\(error.localizedDescription)) — falling back to SMC inhibit path")
            }
        }

        // ── Legacy macOS 26: Read current SMC inhibit state ──────────────────────
        if !nativeMode {
            do {
                if battery.capabilities.inhibitChargeControl {
                    chargingDisabled = try battery.getChargingInhibited()
                }
                if battery.capabilities.forceDischargeControl {
                    powerDisabled = try battery.getForceDischarging()
                }
            } catch {
                logger.error("Failed to read initial SMC states: \(error.localizedDescription)")
            }
        }

        GlobalSleep.restoreOnStart()
    }

    /// Snap `limit` to the nearest supported PowerUI step at or below it.
    /// e.g. 82% → 80%, 87% → 85%, 100% → 100%.
    static func snapToPowerUI(_ limit: Int, session: NativeChargeSession) -> Int {
        session.nearestLimit(atOrBelow: limit) ?? session.supportedLimits.min() ?? 80
    }

    static func isChargingDisabled() -> Bool {
        return chargingDisabled
    }

    static func isPowerAdapterDisabled() -> Bool {
        return powerDisabled
    }

    static func syncSleepState() {
        let shouldDisableForCharging = !chargingDisabled && ChargingSettings.disableSleepUntilChargeLimit
        let shouldDisableForDischarging = powerDisabled && ChargingSettings.disableSleepWhileDischarging

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

    // MARK: - Charge Control (macOS 27 PowerUI | Legacy SMC)

    /// Apply a PowerUI charge limit, snapping to the nearest valid step.
    /// Call only when `nativeMode == true`. Returns success/failure.
    @discardableResult
    static func applyNativeLimit(_ limit: Int) -> (Bool, String?) {
        guard let session = nativeSession else { return (false, "No native session") }
        let snapped = snapToPowerUI(limit, session: session)
        do {
            try session.apply(snapped)
            logger.info("PowerUI limit applied: \(limit)% → snapped \(snapped)%")
            return (true, nil)
        } catch {
            logger.error("PowerUI apply failed: \(error.localizedDescription)")
            return (false, error.localizedDescription)
        }
    }

    /// Apply a PowerUI ceiling that pauses charging at or just above `percent`, snapping UP to
    /// the next supported step instead of down. Snapping down here (as `applyNativeLimit` does
    /// for a user-configured limit) would place the firmware ceiling below the battery's current
    /// level, which makes the firmware actively discharge instead of merely pausing.
    @discardableResult
    static func applyNativePauseCeiling(atLeast percent: Int) -> (Bool, String?) {
        guard let session = nativeSession else { return (false, "No native session") }
        let ceiling = session.nearestLimit(atOrAbove: percent) ?? session.supportedLimits.max() ?? 100
        return applyNativeLimit(ceiling)
    }

    static func disableCharging(force: Bool = false) -> (Bool, String?) {
        guard force || !chargingDisabled else { return (true, nil) }
        guard let battery = battery else { return (false, "Battery is nil") }

        // ── macOS 27 (PowerUI) ───────────────────────────────────────────────────
        // Firmware stops charging at the configured CHLT ceiling — no inhibit needed.
        // We just mark chargingDisabled = true for state tracking.
        if nativeMode {
            chargingDisabled = true
            syncSleepState()
            let (percent, _) = IOKitHelper.getPercentRemaining()
            syncMagSafeState(percent: percent)
            logger.debug("[macOS 27] Charging stop delegated to PowerUI/firmware ceiling")
            return (true, nil)
        }

        // ── Legacy macOS 26: SMC inhibit ─────────────────────────────────────────
        guard battery.capabilities.inhibitChargeControl else {
            return (false, "inhibitChargeControl is false")
        }
        do {
            try battery.setChargingInhibited(true)
            chargingDisabled = true
            logger.debug("[Legacy] SMC charging inhibited = true")
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
        guard force || chargingDisabled else { return (true, nil) }
        guard let battery = battery else { return (false, "Battery is nil") }

        // ── macOS 27 (PowerUI) ───────────────────────────────────────────────────
        // Enabling charging = raising PowerUI limit back to configured limit (done by evaluateState).
        if nativeMode {
            chargingDisabled = false
            syncSleepState()
            let (percent, _) = IOKitHelper.getPercentRemaining()
            syncMagSafeState(percent: percent)
            logger.debug("[macOS 27] Charging resume — PowerUI will allow charging to limit")
            return (true, nil)
        }

        // ── Legacy macOS 26: SMC uninhibit ───────────────────────────────────────
        guard battery.capabilities.inhibitChargeControl else {
            return (false, "inhibitChargeControl is false")
        }
        do {
            try battery.setChargingInhibited(false)
            chargingDisabled = false
            logger.debug("[Legacy] SMC charging inhibited = false")
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
        guard force || !powerDisabled else { return (true, nil) }
        guard let battery = battery else { return (false, "Battery is nil") }

        // ALWAYS use real SMC force discharge if available (even in macOS 27 nativeMode)
        if battery.capabilities.forceDischargeControl {
            do {
                try battery.setForceDischarging(true)
                powerDisabled = true
                logger.debug("[Hybrid] SMC force discharging actively engaged")
                syncSleepState()

                // If nativeMode, also sync the PowerUI ceiling to the configured limit — the
                // actual target of this discharge — not the current (drifting) percent, which
                // would otherwise visibly march the ceiling through intermediate steps as the
                // battery falls (e.g. 90% then 85%) instead of showing the real target directly.
                if nativeMode {
                    let _ = applyNativeLimit(Int(ChargingSettings.chargeLimit))
                }

                return (true, nil)
            } catch {
                logger.error("Failed to disable power adapter (Hybrid): \(error.localizedDescription)")
            }
        }

        // ── macOS 27 (PowerUI) Fallback if CHIE is missing ──────────────────────
        // Force discharge approximation: set the PowerUI ceiling to the configured limit —
        // the firmware itself then drains toward it (this IS the enforcement mechanism here,
        // not just a display sync, since there's no real CHIE to do the discharging).
        if nativeMode {
            let limit = Int(ChargingSettings.chargeLimit)
            let _ = applyNativeLimit(limit)
            powerDisabled = true
            logger.info("[macOS 27] Force discharge approximated — PowerUI limit set to \(limit)%")
            syncSleepState()
            return (true, nil)
        }

        return (false, "forceDischargeControl is false")
    }

    static func enablePowerAdapter(force: Bool = false) -> (Bool, String?) {
        guard force || powerDisabled else { return (true, nil) }
        guard let battery = battery else { return (false, "Battery is nil") }

        // ALWAYS disable real SMC force discharge if it was available
        if battery.capabilities.forceDischargeControl {
            do {
                try battery.setForceDischarging(false)
                powerDisabled = false
                logger.debug("[Hybrid] SMC force discharging ended")
                
                if !nativeMode && chargingDisabled {
                    try? battery.setChargingInhibited(true)
                    logger.debug("[Legacy] Re-asserted charging inhibited after adapter re-enable")
                }
                
                syncSleepState()

                if nativeMode {
                    // Never blindly reapply the raw configured limit here — if the battery is
                    // still even 1% above it when discharge ends (timing lag is normal), that
                    // would set the ceiling below the current percent and immediately trigger
                    // another round of active discharge. Only drop to the exact limit once the
                    // battery has actually reached (or is below) it.
                    let limit = Int(ChargingSettings.chargeLimit)
                    let (percent, _) = IOKitHelper.getPercentRemaining()
                    ChargingPowerState.applyNativePauseCeiling(atLeast: max(limit, Int(percent)))
                    logger.info("[macOS 27] Force discharge ended — PowerUI ceiling restored (limit \(limit)%, percent \(percent)%)")
                }

                return (true, nil)
            } catch {
                logger.error("Failed to enable power adapter (Hybrid): \(error.localizedDescription)")
            }
        }

        // ── macOS 27 (PowerUI) Fallback if CHIE is missing ──────────────────────
        // Restore PowerUI ceiling — same rule: never drop it below the current percent.
        if nativeMode {
            let limit = Int(ChargingSettings.chargeLimit)
            let (percent, _) = IOKitHelper.getPercentRemaining()
            let _ = applyNativePauseCeiling(atLeast: max(limit, Int(percent)))
            powerDisabled = false
            logger.info("[macOS 27] Force discharge ended — PowerUI ceiling restored (limit \(limit)%, percent \(percent)%)")
            syncSleepState()
            return (true, nil)
        }

        return (false, "forceDischargeControl is false")
    }

    @discardableResult
    static func manageMagsafeLED(target: UInt8, force: Bool = false) -> Bool {
        if !force {
            guard ChargingSettings.manageMagSafeLED else { return false }
        }
        guard let adapter = adapter, adapter.capabilities.magSafeControl else { return false }
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
        if !ChargingSettings.manageMagSafeLED {
            manageMagsafeLED(target: MagSafeLEDState.reset.rawValue, force: true)
            return
        }

        if powerDisabled {
            manageMagsafeLED(target: ChargingSettings.dischargingMagSafeLEDState)
        } else if heatProtectionActive {
            manageMagsafeLED(target: ChargingSettings.heatProtectionMagSafeLEDState)
        } else if chargingDisabled || percent == 100 || (nativeMode && percent >= ChargingSettings.chargeLimit) {
            manageMagsafeLED(target: ChargingSettings.pausedMagSafeLEDState)
        } else {
            manageMagsafeLED(target: ChargingSettings.chargingMagSafeLEDState)
        }
    }

    static func restoreDefaults() {
        // ── macOS 27: Restore original PowerUI limit via journal ─────────────────
        if nativeMode, let session = nativeSession {
            do {
                try session.restore()
                logger.info("[macOS 27] PowerUI limit restored to journaled original on quit")
            } catch {
                logger.error("[macOS 27] PowerUI restore failed: \(error.localizedDescription)")
            }
        }

        // ── Legacy macOS 26: uninhibit charging + disable force discharge ─────────
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
        guard let value = UserDefaults.standard.object(forKey: previousSleepDisabledKey) as? Bool else {
            return
        }

        setSleepDisabledIOPMValue(value: value as CFBoolean)
        UserDefaults.standard.removeObject(forKey: previousSleepDisabledKey)
        _ = CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    }

    static func forceRestore() {
        guard disabledCounter > 0 else { return }
        disabledCounter = 0
        restorePrevious()
    }

    static func restore() {
        guard disabledCounter > 0 else { return }
        disabledCounter -= 1
        guard disabledCounter == 0 else { return }
        restorePrevious()
    }

    static func disable() {
        assert(disabledCounter >= 0)
        disabledCounter += 1
        guard disabledCounter == 1 else { return }

        let sleepDisable = getSleepDisabledIOPMValue()
        previousDisabled = sleepDisable
        UserDefaults.standard.setValue(sleepDisable, forKey: previousSleepDisabledKey)
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
        setSleepDisabledIOPMValue(value: kCFBooleanTrue)
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

        guard !previousDisabled else {
            previousDisabled = false
            return
        }

        setSleepDisabledIOPMValue(value: kCFBooleanFalse)
        UserDefaults.standard.removeObject(forKey: previousSleepDisabledKey)
        _ = CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    }
}
