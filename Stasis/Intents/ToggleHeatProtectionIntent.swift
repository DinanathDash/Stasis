import AppIntents
import Defaults
import Foundation
import smc_power

struct ToggleHeatProtectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Heat Protection"
    static let description = IntentDescription("Enable or disable Heat Protection Mode in Stasis.")
    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Enable Heat Protection",
        description: "True to enable, false to disable. Leave empty (nil) to toggle current state.",
        default: nil
    )
    var enable: Bool?

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

        let targetState = enable ?? !Defaults[.enableHeatProtectionMode]
        Defaults[.enableHeatProtectionMode] = targetState
        Defaults[.manageCharging] = true
        chargeManager.forceSyncSettings()

        let message = targetState ? "Heat Protection Mode enabled." : "Heat Protection Mode disabled."
        return .result(value: message, dialog: "\(message)")
    }
}
