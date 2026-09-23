import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import smc_power

enum IOKitHelper {
    static func getPowerSourceInfo() -> CFDictionary? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        guard let source = sources.first else { return nil }
        return IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue()
    }

    static func getPercentRemaining() -> (UInt8, Bool) {
        guard let info = getPowerSourceInfo() as? [String: Any],
              let percent = info[kIOPSCurrentCapacityKey] as? Int,
              let isCharging = info[kIOPSIsChargingKey] as? Bool
        else {
            return (100, false)
        }
        return (UInt8(max(0, min(100, percent))), isCharging)
    }

    static func getBatteryTemperature() -> Double? {
        let batteryService = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if batteryService != 0 {
            let prop = IORegistryEntryCreateCFProperty(batteryService, "Temperature" as CFString, kCFAllocatorDefault, 0)
            IOObjectRelease(batteryService)
            
            if let temp100 = prop?.takeRetainedValue() as? Int {
                let celsius = Double(temp100) / 100.0
                if (0 ... 80).contains(celsius) {
                    return celsius
                }
            }
        }
        
        do {
            return try smc_power.SMCBattery.getTemperature()
        } catch {
            return nil
        }
    }

    static func isDrawingUnlimitedPower() -> Bool {
        let batteryService = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard batteryService != 0 else { return false }
        defer { IOObjectRelease(batteryService) }

        let prop = IORegistryEntryCreateCFProperty(batteryService, "AdapterDetails" as CFString, kCFAllocatorDefault, 0)
        guard let adapterDetails = prop?.takeRetainedValue() as? [String: Any],
              let watts = adapterDetails["Watts"] as? Int
        else {
            return false
        }

        return watts > 0
    }
}
