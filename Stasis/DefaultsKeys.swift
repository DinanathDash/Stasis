import Defaults
import Foundation
import SwiftUI

#if !WIDGET_EXTENSION
import smc_power
#else
public enum MagSafeLEDState: UInt8, Codable, Sendable {
    case off = 0
    case green = 1
    case orange = 2
    case blinkOrangeSlow = 3
    case blinkOrangeFast = 4
    case reset = 255
}
#endif

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

    var localizedName: String {
        switch self {
        case .hidden:
            return String(localized: "Hidden")
        case .nextToIcon:
            return String(localized: "Next to icon")
        case .insideIcon:
            return String(localized: "Inside icon")
        case .insideIconAndNextToItWhenPowered:
            return String(localized: "Inside (Outside on power)")
        }
    }
}

enum NotchHUDSound: String, CaseIterable, Defaults.Serializable, Identifiable {
    case basso = "Basso"
    case frog = "Frog"
    case glass = "Glass"
    case hero = "Hero"
    case pop = "Pop"
    case tink = "Tink"
    case none = "None"
    
    var id: Self { self }

    var localizedName: String {
        switch self {
        case .basso:
            return String(localized: "Basso")
        case .frog:
            return String(localized: "Frog")
        case .glass:
            return String(localized: "Glass")
        case .hero:
            return String(localized: "Hero")
        case .pop:
            return String(localized: "Pop")
        case .tink:
            return String(localized: "Tink")
        case .none:
            return String(localized: "None")
        }
    }
}

enum NotchHUDDisplayMode: String, CaseIterable, Defaults.Serializable, Identifiable {
    case macDisplayOnly = "Mac Display Only"
    case allDisplays = "All Displays"
    
    var id: Self { self }

    var localizedName: String {
        switch self {
        case .macDisplayOnly:
            return String(localized: "Mac Display Only")
        case .allDisplays:
            return String(localized: "All Displays")
        }
    }
}

enum CalibrationStatus: String, Defaults.Serializable, Equatable {
    case idle
    case discharging
    case charging
    case resting
}

enum AppLanguage: String, CaseIterable, Defaults.Serializable, Identifiable {
    case system = "System Default"
    case german = "Deutsch"
    case english = "English"
    case spanish = "Español"
    case french = "Français"
    case italian = "Italiano"
    case dutch = "Nederlands"
    case portugueseBR = "Português (Brasil)"
    case portuguesePT = "Português (Portugal)"
    case slovak = "Slovenčina"
    case slovenian = "Slovenščina"
    case vietnamese = "Tiếng Việt"
    case turkish = "Türkçe"
    case russian = "Русский"
    case simplifiedChinese = "简体中文"
    case traditionalChinese = "繁體中文"
    case japanese = "日本語"
    case korean = "한국어"

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .system:
            return "System Default"
        case .german:
            return "Deutsch"
        case .english:
            return "English"
        case .spanish:
            return "Español"
        case .french:
            return "Français"
        case .italian:
            return "Italiano"
        case .dutch:
            return "Nederlands"
        case .portugueseBR:
            return "Português (Brasil)"
        case .portuguesePT:
            return "Português (Portugal)"
        case .slovak:
            return "Slovenčina"
        case .slovenian:
            return "Slovenščina"
        case .vietnamese:
            return "Tiếng Việt"
        case .turkish:
            return "Türkçe"
        case .russian:
            return "Русский"
        case .simplifiedChinese:
            return "简体中文"
        case .traditionalChinese:
            return "繁體中文"
        case .japanese:
            return "日本語"
        case .korean:
            return "한국어"
        }
    }

    var code: String? {
        switch self {
        case .system:
            return nil
        case .german:
            return "de"
        case .english:
            return "en"
        case .spanish:
            return "es"
        case .french:
            return "fr"
        case .italian:
            return "it"
        case .dutch:
            return "nl"
        case .portugueseBR:
            return "pt-BR"
        case .portuguesePT:
            return "pt-PT"
        case .slovak:
            return "sk"
        case .slovenian:
            return "sl"
        case .vietnamese:
            return "vi"
        case .turkish:
            return "tr"
        case .russian:
            return "ru"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        case .japanese:
            return "ja"
        case .korean:
            return "ko"
        }
    }
}

extension Defaults.Keys {
    // General
    static let launchAtLogin = Key<Bool>("launchAtLogin", default: false)
    static let storedAppVersion = Key<String>("storedAppVersion", default: "")
    static let firstRun = Key<Bool>("firstRun", default: false)
    static let appLanguage = Key<AppLanguage>("appLanguage", default: .system)

    // Status Icon
    static let batteryPercentageVisibility = Key<BatteryPercentageVisibility>(
        "batteryPercentageVisibility",
        default: .nextToIcon
    )
    static let showBatteryStateInStatusIcon = Key<Bool>(
        "showBatteryStateInStatusIcon",
        default: true
    )

    static let enableNotchHUD = Key<Bool>(
        "enableNotchHUD",
        default: true
    )
    static let showNotchHUDOnLockScreen = Key<Bool>(
        "showNotchHUDOnLockScreen",
        default: true
    )
    static let notchHUDDisplayMode = Key<NotchHUDDisplayMode>(
        "notchHUDDisplayMode",
        default: .macDisplayOnly
    )
    static let notchHUDDisplayDuration = Key<Double>(
        "notchHUDDisplayDuration",
        default: 3.0
    )
    static let notchHUDSound = Key<NotchHUDSound>(
        "notchHUDSound",
        default: .frog
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
    static let showPowerSource = Key<Bool>("showPowerSource", default: true)
    static let showUptime = Key<Bool>("showUptime", default: true)
    static let showBatteryMode = Key<Bool>("showBatteryMode", default: true)
    static let showInternalPower = Key<Bool>("showInternalPower", default: true)
    static let showExternalPower = Key<Bool>("showExternalPower", default: true)
    static let showPowerDistribution = Key<Bool>(
        "showPowerDistribution",
        default: true
    )
    static let showTwoDecimalPowerValues = Key<Bool>(
        "showTwoDecimalPowerValues",
        default: false
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
    static let showSignificantEnergyApps = Key<Bool>(
        "showSignificantEnergyApps",
        default: true
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

    // Calibration
    static let enableAutomaticCalibration = Key<Bool>(
        "enableAutomaticCalibration",
        default: false
    )
    static let calibrationIntervalDays = Key<Int>(
        "calibrationIntervalDays",
        default: 30
    )
    static let calibrationTimeOfDay = Key<Date>(
        "calibrationTimeOfDay",
        default: {
            var components = DateComponents()
            components.hour = 9
            components.minute = 0
            return Calendar.current.date(from: components) ?? Date()
        }()
    )
    static let lastCalibrationDate = Key<Date?>(
        "lastCalibrationDate",
        default: nil
    )
    static let calibrationStatus = Key<CalibrationStatus>(
        "calibrationStatus",
        default: .idle
    )
    static let calibrationStepStartTime = Key<Date?>(
        "calibrationStepStartTime",
        default: nil
    )
    static let calibrationSnoozeUntil = Key<Date?>(
        "calibrationSnoozeUntil",
        default: nil
    )
}
