import AppIntents
import Defaults
import Foundation
import smc_power

struct SetHeatProtectionLimitIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Heat Protection Temperature"
    static let description = IntentDescription("Set the temperature threshold for Heat Protection Mode (30°C to 50°C) in Stasis.")
    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Temperature (°C)",
        description: "Temperature threshold for Heat Protection Mode (30 to 50)",
        default: 40
    )
    var temperatureC: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let appDelegate = AppDelegate.shared,
              let (batteryService, chargeManager, _, _) = await appDelegate.ensureServicesReady()
        else {
            throw CustomIntentError.stasisNotReady
        }

        if batteryService.deviceCapabilities.nativeMode {
            throw CustomIntentError.unsupportedOnOS("Heat Protection")
        }

        let clampedTemp = min(max(temperatureC, 30), 50)
        Defaults[.heatProtectionLimit] = clampedTemp
        Defaults[.enableHeatProtectionMode] = true
        Defaults[.manageCharging] = true
        chargeManager.forceSyncSettings()

        let message = "Heat Protection threshold set to \(clampedTemp)°C."
        return .result(value: message, dialog: "\(message)")
    }
}
