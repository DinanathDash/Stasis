import Defaults
import Foundation
import smc_power

extension MagSafeLEDState: Defaults.Serializable {}

enum OutputVisualizationMode: String, CaseIterable, Defaults.Serializable {
    case off
    case powerOnly
    case batteryOnly
    case always
}

enum BatteryPercentageVisibility: String, CaseIterable, Defaults.Serializable, Identifiable {
    case hidden = "Hidden"
    case nextToIcon = "Next to icon"
    case insideIcon = "Inside icon"
    case insideIconAndNextToItWhenPowered = "Inside (Outside on power)"
    
    var id: Self { self }
}

extension Defaults.Keys {
    // General
    static let launchAtLogin = Key<Bool>("launchAtLogin", default: false)
    static let storedAppVersion = Key<String>("storedAppVersion", default: "")
    static let firstRun = Key<Bool>("firstRun", default: false)

    // Status Icon
    static let batteryPercentageVisibility = Key<BatteryPercentageVisibility>(
        "batteryPercentageVisibility",
        default: .nextToIcon
    )
    static let showBatteryStateInStatusIcon = Key<Bool>(
        "showBatteryStateInStatusIcon",
        default: true
    )

    // Notifications
    static let disableNotifications = Key<Bool>(
        "disableNotifications",
        default: false
    )
    static let showChargingStatusChangedNotification = Key<Bool>(
        "showChargingStatusChangedNotification",
        default: true
    )

    // Menu Dashboard
    static let showTimeTillDischarge = Key<Bool>(
        "showTimeTillDischarge",
        default: true
    )
    static let showBatteryCycleCount = Key<Bool>(
        "showBatteryCycleCount",
        default: true
    )
    static let showBatteryHealth = Key<Bool>("showBatteryHealth", default: true)
    static let showBatteryTemperature = Key<Bool>(
        "showBatteryTemperature",
        default: false
    )
    static let showPowerSource = Key<Bool>("showPowerSource", default: false)
    static let showUptime = Key<Bool>("showUptime", default: true)
    static let showBatteryMode = Key<Bool>("showBatteryMode", default: true)
    static let showInternalPower = Key<Bool>("showInternalPower", default: true)
    static let showExternalPower = Key<Bool>("showExternalPower", default: true)
    static let showPowerDistribution = Key<Bool>(
        "showPowerDistribution",
        default: true
    )
    static let showOutputPortsText = Key<Bool>(
        "showOutputPortsText",
        default: false
    )
    static let outputVisualizationMode = Key<OutputVisualizationMode>(
        "outputVisualizationMode",
        default: .always
    )
    static let showAdvancedChargingControls = Key<Bool>(
        "showAdvancedChargingControls",
        default: false
    )

    // Charging
    static let manageCharging = Key<Bool>("manageCharging", default: false)
    static let chargeLimit = Key<Int>("chargeLimit", default: 80)
    static let sailingMode = Key<Bool>("sailingMode", default: true)
    static let sailingModeLimit = Key<Int>("sailingModeLimit", default: 5)
    static let automaticDischarge = Key<Bool>(
        "automaticDischarge",
        default: true
    )
    static let disableSleepUntilChargeLimit = Key<Bool>(
        "disableSleepUntilChargeLimit",
        default: false
    )

    // Charging - Heat Protection
    static let enableHeatProtectionMode = Key<Bool>(
        "enableHeatProtectionMode",
        default: true
    )
    static let heatProtectionLimit = Key<Int>(
        "heatProtectionLimit",
        default: 40
    )

    // Charging - MagSafe LED Control
    static let manageMagSafeLED = Key<Bool>("manageMagSafeLED", default: true)
    static let heatProtectionMagSafeLEDState = Key<MagSafeLEDState>(
        "heatProtectionMagSafeLEDState",
        default: MagSafeLEDState.blinkOrangeSlow
    )
    static let chargingOnHoldMagSafeLEDState = Key<MagSafeLEDState>(
        "chargingOnHoldMagSafeLEDState",
        default: MagSafeLEDState.orange
    )
    // Advanced
    static let useHardwarePercentage = Key<Bool>(
        "useHardwarePercentage",
        default: false
    )
    static let useRawHardwareHealth = Key<Bool>(
        "useRawHardwareHealth",
        default: false
    )

}
