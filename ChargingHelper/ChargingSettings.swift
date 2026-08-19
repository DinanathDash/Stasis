import Foundation
import os.log

@MainActor
enum ChargingSettings {
    private static let defaults = UserDefaults.standard
    private static let logger = Logger(subsystem: "com.dinanathdash.stasis.charging-helper", category: "ChargingSettings")

    static var manageCharging: Bool {
        get { defaults.bool(forKey: "manageCharging") }
        set { defaults.set(newValue, forKey: "manageCharging") }
    }

    static var disableSleepUntilChargeLimit: Bool {
        get { defaults.bool(forKey: "disableSleepUntilChargeLimit") }
        set { defaults.set(newValue, forKey: "disableSleepUntilChargeLimit") }
    }

    static var disableSleepWhileDischarging: Bool {
        get { defaults.bool(forKey: "disableSleepWhileDischarging") }
        set { defaults.set(newValue, forKey: "disableSleepWhileDischarging") }
    }

    static var chargeLimit: UInt8 {
        get {
            let val = defaults.integer(forKey: "chargeLimit")
            return val > 0 ? UInt8(val) : 80
        }
        set { defaults.set(newValue, forKey: "chargeLimit") }
    }

    static var sailingMode: Bool {
        get { defaults.bool(forKey: "sailingMode") }
        set { defaults.set(newValue, forKey: "sailingMode") }
    }

    static var sailingModeLimit: UInt8 {
        get {
            let val = defaults.integer(forKey: "sailingModeLimit")
            return val > 0 ? UInt8(val) : 5
        }
        set { defaults.set(newValue, forKey: "sailingModeLimit") }
    }

    static var automaticDischarge: Bool {
        get { defaults.bool(forKey: "automaticDischarge") }
        set { defaults.set(newValue, forKey: "automaticDischarge") }
    }

    static var enableHeatProtectionMode: Bool {
        get { defaults.bool(forKey: "enableHeatProtectionMode") }
        set { defaults.set(newValue, forKey: "enableHeatProtectionMode") }
    }

    static var heatProtectionLimit: Int {
        get {
            let val = defaults.integer(forKey: "heatProtectionLimit")
            return val > 0 ? val : 35
        }
        set { defaults.set(newValue, forKey: "heatProtectionLimit") }
    }

    static var manageMagSafeLED: Bool {
        get { defaults.bool(forKey: "manageMagSafeLED") }
        set { defaults.set(newValue, forKey: "manageMagSafeLED") }
    }

    static var chargingMagSafeLEDState: UInt8 {
        get {
            let val = defaults.integer(forKey: "chargingMagSafeLEDState")
            return val > 0 ? UInt8(val) : 4 // 4 is Orange
        }
        set { defaults.set(newValue, forKey: "chargingMagSafeLEDState") }
    }

    static var pausedMagSafeLEDState: UInt8 {
        get {
            let val = defaults.integer(forKey: "pausedMagSafeLEDState")
            return val > 0 ? UInt8(val) : 3 // 3 is Green
        }
        set { defaults.set(newValue, forKey: "pausedMagSafeLEDState") }
    }

    static var dischargingMagSafeLEDState: UInt8 {
        get {
            let val = defaults.integer(forKey: "dischargingMagSafeLEDState")
            return val > 0 ? UInt8(val) : 3 // 3 is Green
        }
        set { defaults.set(newValue, forKey: "dischargingMagSafeLEDState") }
    }

    static var heatProtectionMagSafeLEDState: UInt8 {
        get {
            let val = defaults.integer(forKey: "heatProtectionMagSafeLEDState")
            return val > 0 ? UInt8(val) : 6 // 6 is blinkOrangeSlow
        }
        set { defaults.set(newValue, forKey: "heatProtectionMagSafeLEDState") }
    }

    static func getSettings() -> [String: NSObject & Sendable] {
        return [
            "manageCharging": manageCharging as NSNumber,
            "chargeLimit": chargeLimit as NSNumber,
            "sailingMode": sailingMode as NSNumber,
            "sailingModeLimit": sailingModeLimit as NSNumber,
            "automaticDischarge": automaticDischarge as NSNumber,
            "enableHeatProtectionMode": enableHeatProtectionMode as NSNumber,
            "heatProtectionLimit": heatProtectionLimit as NSNumber,
            "disableSleepUntilChargeLimit": disableSleepUntilChargeLimit as NSNumber,
            "disableSleepWhileDischarging": disableSleepWhileDischarging as NSNumber,
            "manageMagSafeLED": manageMagSafeLED as NSNumber,
            "chargingMagSafeLEDState": chargingMagSafeLEDState as NSNumber,
            "pausedMagSafeLEDState": pausedMagSafeLEDState as NSNumber,
            "dischargingMagSafeLEDState": dischargingMagSafeLEDState as NSNumber,
            "heatProtectionMagSafeLEDState": heatProtectionMagSafeLEDState as NSNumber
        ]
    }

    static func setSettings(settings: [String: Any]) {
        for (key, value) in settings {
            switch key {
            case "manageCharging":
                manageCharging = value as? Bool ?? manageCharging
            case "chargeLimit":
                chargeLimit = UInt8(value as? Int ?? Int(chargeLimit))
            case "sailingMode":
                sailingMode = value as? Bool ?? sailingMode
            case "sailingModeLimit":
                sailingModeLimit = UInt8(value as? Int ?? Int(sailingModeLimit))
            case "automaticDischarge":
                automaticDischarge = value as? Bool ?? automaticDischarge
            case "enableHeatProtectionMode":
                enableHeatProtectionMode = value as? Bool ?? enableHeatProtectionMode
            case "heatProtectionLimit":
                heatProtectionLimit = value as? Int ?? heatProtectionLimit
            case "disableSleepUntilChargeLimit":
                disableSleepUntilChargeLimit = value as? Bool ?? disableSleepUntilChargeLimit
            case "disableSleepWhileDischarging":
                disableSleepWhileDischarging = value as? Bool ?? disableSleepWhileDischarging
            case "manageMagSafeLED":
                manageMagSafeLED = value as? Bool ?? manageMagSafeLED
            case "chargingMagSafeLEDState":
                chargingMagSafeLEDState = UInt8(value as? Int ?? Int(chargingMagSafeLEDState))
            case "pausedMagSafeLEDState":
                pausedMagSafeLEDState = UInt8(value as? Int ?? Int(pausedMagSafeLEDState))
            case "dischargingMagSafeLEDState":
                dischargingMagSafeLEDState = UInt8(value as? Int ?? Int(dischargingMagSafeLEDState))
            case "heatProtectionMagSafeLEDState":
                heatProtectionMagSafeLEDState = UInt8(value as? Int ?? Int(heatProtectionMagSafeLEDState))
            default:
                logger.warning("Unknown setting key: \(key)")
            }
        }

        _ = CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        logger.info("Settings updated via XPC (CFPreferencesAppSynchronize)")
    }
}
