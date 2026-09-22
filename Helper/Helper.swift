import Foundation
import os.log
import smc_power

private enum Constants {
    static let helperSubsystem = "com.dinanathdash.stasis.helper"
}

final class Helper: NSObject, HelperProtocol {
    private let logger = Logger(
        subsystem: Constants.helperSubsystem,
        category: "Helper"
    )

    func readBatteryMetrics(
        reply: @escaping @Sendable (Double, Double, Double, String?) -> Void
    ) {
        do {
            let batteryVoltage = try SMCBattery.getVoltage()
            let batteryCurrent = try SMCBattery.getCurrent()
            let batteryPower = batteryVoltage * batteryCurrent

            reply(batteryVoltage, batteryCurrent, batteryPower, nil)
        } catch {
            logger.error("SMC battery read failed: \(error.localizedDescription)")
            reply(0, 0, 0, error.localizedDescription)
        }
    }

    func readAdapterMetrics(
        reply: @escaping @Sendable (Double, Double, Double, String?) -> Void
    ) {
        do {
            var adapterVoltage = try SMCAdapter.getVoltage()
            var adapterCurrent = try SMCAdapter.getCurrent()

            if abs(adapterVoltage) < 0.1 {
                adapterVoltage = 0
            }
            if abs(adapterCurrent) < 0.1 {
                adapterCurrent = 0
            }

            let adapterPower = adapterVoltage * adapterCurrent

            reply(adapterVoltage, adapterCurrent, adapterPower, nil)
        } catch {
            logger.error("SMC adapter read failed: \(error.localizedDescription)")
            reply(0, 0, 0, error.localizedDescription)
        }
    }

    func getCapabilities(reply: @escaping @Sendable (Bool, Bool, Bool, Bool, Bool, Bool) -> Void) {
        do {
            let battery = try SMCBattery.probe()
            let adapter = try SMCAdapter.probe()

            // macOS 27: check if PowerUI framework is available (no root needed)
            let powerUIAvailable = (try? PowerUIChargeBackend()) != nil

            // chargingControl = true if we can stop/control charging via ANY mechanism:
            // - Legacy macOS 26: inhibitChargeControl (CH0C/CHTE)
            // - macOS 27 (CHLT present): PowerUISmartChargeClient
            let chargingControl = battery.capabilities.inhibitChargeControl
                || battery.capabilities.nativeChargeLimitControl
                || powerUIAvailable

            let adapterControl = battery.capabilities.forceDischargeControl

            // macOS 15.8: firmware dropped the inhibit keys but PowerUI isn't available pre-26,
            // so only bouncing the AC adapter via force-discharge can hold the limit.
            let dischargeOnlyFallback = !battery.capabilities.inhibitChargeControl
                && !powerUIAvailable
                && battery.capabilities.forceDischargeControl

            logger.info(
                "Probed capabilities: chargingControl=\(chargingControl) [inhibit=\(battery.capabilities.inhibitChargeControl), chlt=\(battery.capabilities.nativeChargeLimitControl), powerUI=\(powerUIAvailable)] adapterControl=\(adapterControl) magSafe=\(adapter.capabilities.magSafeControl) dischargeOnlyFallback=\(dischargeOnlyFallback)"
            )
            reply(
                chargingControl,
                adapterControl,
                adapter.capabilities.magSafeControl,
                adapter.capabilities.magSafeControl,
                powerUIAvailable,
                dischargeOnlyFallback
            )
        } catch {
            logger.error("Failed to probe capabilities: \(error.localizedDescription)")
            reply(false, false, false, false, false, false)
        }
    }
}
