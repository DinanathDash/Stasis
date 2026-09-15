import AppIntents
import Defaults
import Foundation
import smc_power

struct ToggleTopUpIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Top-Up to 100 percent"
    static let description = IntentDescription("Temporarily override the charge limit and charge the MacBook to 100 percent, or cancel Top-Up if active.")
    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Enable Top-Up",
        description: "True to start Top-Up, false to stop. Leave empty (nil) to toggle current state.",
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
            throw CustomIntentError.unsupportedOnOS("Charge Limit Override")
        }

        let targetState = enable ?? !chargeManager.chargeLimitOverrideActive
        if chargeManager.chargeLimitOverrideActive != targetState {
            chargeManager.toggleChargeLimitOverride()
        }

        let message = targetState ? "Top-up to \(100.formattedPercentage) started." : "Top-up to \(100.formattedPercentage) cancelled. Standard limit resumed."
        return .result(value: message, dialog: "\(message)")
    }
}
