import AppKit
import Defaults
import Foundation
import UserNotifications

@MainActor
final class StasisURLHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = StasisURLHandler()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "stasis" else {
            return false
        }

        Task {
            await executeURLCommand(url)
        }
        return true
    }

    private func executeURLCommand(_ url: URL) async {
        guard let appDelegate = AppDelegate.shared,
              let (_, chargeManager, viewModel, calibrationManager) = await appDelegate.ensureServicesReady() else {
            showNotification(title: String(localized: "Stasis Error"), message: String(localized: "Stasis background services are not running or ready."))
            return
        }

        let command = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems ?? []
        let params = Dictionary(queryItems.compactMap { item -> (String, String)? in
            guard let val = item.value else { return nil }
            return (item.name.lowercased(), val)
        }, uniquingKeysWith: { $1 })

        func getBoolParam(key: String, defaultValue: Bool) -> Bool {
            if let val = params[key]?.lowercased() {
                return val == "true" || val == "1" || val == "yes"
            }
            return !defaultValue // toggle if omitted
        }

        func getIntParam(key: String, fallback: Int) -> Int {
            if let str = params[key], let val = Int(str) {
                return val
            }
            return fallback
        }

        switch command {
        case "dashboard", "open-dashboard", "settings":
            appDelegate.showSettingsWindow()
            NSApp.activate(ignoringOtherApps: true)

        case "menu", "open-menu", "menubar", "dialog":
            appDelegate.openMenuBarMenu()
            showNotification(title: String(localized: "Stasis Menu"), message: String(localized: "Stasis menu bar dialog opened."))

        case "status", "battery-status", "battery":
            let percentage = viewModel.displayPercentage
            let chargingMode = viewModel.chargingMode
            let limit = Defaults[.chargeLimit]
            let isSailing = Defaults[.sailingMode]
            let healthText = viewModel.batteryHealthText
            let tempText = viewModel.batteryTemperatureText

            var modeText = ""
            switch chargingMode {
            case .charging:
                modeText = String(localized: "Charging")
            case .discharging:
                modeText = String(localized: "On Battery")
            case .pluggedIn:
                if isSailing {
                    modeText = String(localized: "Sailing Mode (\(limit.formattedPercentage))")
                } else {
                    modeText = String(localized: "On Hold (\(limit.formattedPercentage))")
                }
            }

            let batteryWatts = abs(viewModel.batteryPower)
            let statusString = String(localized: "\(percentage.formattedPercentage) (\(modeText)) • \(String(format: "%.1fW", batteryWatts)) • Health: \(healthText) • Temp: \(tempText)")
            showNotification(title: String(localized: "Stasis Battery Status"), message: statusString)

        case "charge-limit", "set-charge-limit", "limit":
            let targetValue = getIntParam(key: "value", fallback: Defaults[.chargeLimit])
            let clampedLimit = min(max(targetValue, 50), 100)
            Defaults[.chargeLimit] = clampedLimit
            Defaults[.manageCharging] = true
            chargeManager.forceSyncSettings()
            showNotification(title: String(localized: "Stasis Charge Limit"), message: String(localized: "Charge limit set to \(clampedLimit.formattedPercentage) (Managed Charging enabled)."))

        case "topup", "toggle-top-up":
            let targetState = getBoolParam(key: "enable", defaultValue: chargeManager.chargeLimitOverrideActive)
            if chargeManager.chargeLimitOverrideActive != targetState {
                chargeManager.toggleChargeLimitOverride()
            }
            let message = targetState ? String(localized: "Top-Up to 100 percent started.") : String(localized: "Top-Up to 100 percent cancelled.")
            showNotification(title: String(localized: "Stasis Top-Up"), message: message)

        case "sailing", "toggle-sailing-mode", "sailing-mode":
            let enable = getBoolParam(key: "enable", defaultValue: Defaults[.sailingMode])
            Defaults[.sailingMode] = enable
            chargeManager.forceSyncSettings()
            let message = enable ? String(localized: "Sailing Mode enabled.") : String(localized: "Sailing Mode disabled.")
            showNotification(title: String(localized: "Stasis Sailing Mode"), message: message)

        case "sailing-limit", "set-sailing-mode-limit":
            let targetValue = getIntParam(key: "value", fallback: Defaults[.sailingModeLimit])
            let clamped = min(max(targetValue, 5), 20)
            Defaults[.sailingModeLimit] = clamped
            showNotification(title: String(localized: "Stasis Sailing Mode Range"), message: String(localized: "Sailing drop percentage set to \(clamped)% below limit."))

        case "force-discharge", "toggle-force-discharge":
            let targetState = getBoolParam(key: "enable", defaultValue: chargeManager.forceDischargeActive)
            if chargeManager.forceDischargeActive != targetState {
                chargeManager.toggleForceDischarge()
            }
            let message = targetState ? String(localized: "Force Discharge started.") : String(localized: "Force Discharge stopped.")
            showNotification(title: String(localized: "Stasis Force Discharge"), message: message)

        case "calibrate", "calibration":
            let action = (params["action"] ?? "start").lowercased()
            if action == "cancel" || action == "stop" {
                calibrationManager.cancelCalibration()
                showNotification(title: String(localized: "Stasis Battery Calibration"), message: String(localized: "Calibration cycle cancelled."))
            } else {
                calibrationManager.startCalibration()
                showNotification(title: String(localized: "Stasis Battery Calibration"), message: String(localized: "Calibration cycle started."))
            }

        case "start-calibration":
            calibrationManager.startCalibration()
            showNotification(title: String(localized: "Stasis Battery Calibration"), message: String(localized: "Calibration cycle started."))

        case "cancel-calibration":
            calibrationManager.cancelCalibration()
            showNotification(title: String(localized: "Stasis Battery Calibration"), message: String(localized: "Calibration cycle cancelled."))

        case "heat-protection", "toggle-heat-protection":
            let enable = getBoolParam(key: "enable", defaultValue: Defaults[.enableHeatProtectionMode])
            Defaults[.enableHeatProtectionMode] = enable
            Defaults[.manageCharging] = true
            chargeManager.forceSyncSettings()
            let message = enable ? String(localized: "Heat Protection Mode enabled.") : String(localized: "Heat Protection Mode disabled.")
            showNotification(title: String(localized: "Stasis Heat Protection"), message: message)

        case "sleep-while-discharging", "toggle-sleep-while-discharging":
            let enable = getBoolParam(key: "enable", defaultValue: Defaults[.disableSleepWhileDischarging])
            Defaults[.disableSleepWhileDischarging] = enable
            Defaults[.manageCharging] = true
            chargeManager.forceSyncSettings()
            let message = enable ? String(localized: "Sleep while discharging disabled.") : String(localized: "Sleep while discharging enabled.")
            showNotification(title: String(localized: "Stasis Sleep Prevention"), message: message)

        case "heat-protection-limit", "set-heat-protection-limit", "heat-limit":
            let targetValue = getIntParam(key: "value", fallback: Defaults[.heatProtectionLimit])
            let clamped = min(max(targetValue, 30), 50)
            Defaults[.heatProtectionLimit] = clamped
            showNotification(title: String(localized: "Stasis Heat Protection Threshold"), message: String(localized: "Heat Protection threshold set to \(clamped)°C."))

        case "magsafe-led", "toggle-magsafe-led":
            let enable = getBoolParam(key: "enable", defaultValue: Defaults[.manageMagSafeLED])
            Defaults[.manageMagSafeLED] = enable
            Defaults[.manageCharging] = true
            chargeManager.forceSyncSettings()
            let message = enable ? String(localized: "MagSafe LED custom control enabled.") : String(localized: "MagSafe LED custom control disabled.")
            showNotification(title: String(localized: "Stasis MagSafe LED"), message: message)

        default:
            showNotification(title: String(localized: "Stasis URL Scheme"), message: String(localized: "Unknown Stasis command: stasis://\(command)"))
        }
    }

    private func showNotification(title: String, message: String) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }

        let legacyNotification = NSUserNotification()
        legacyNotification.title = title
        legacyNotification.informativeText = message
        legacyNotification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(legacyNotification)
    }
}
