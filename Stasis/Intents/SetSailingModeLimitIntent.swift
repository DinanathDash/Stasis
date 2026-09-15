import AppIntents
import Defaults
import Foundation
import smc_power

struct SetSailingModeLimitIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Sailing Mode Drop Range"
    static let description = IntentDescription("Set the percentage range for Sailing Mode (1 to 20 percent) in Stasis.")
    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Drop Range (%)",
        description: "Percentage drop allowed before recharging in Sailing Mode (1 to 20)",
        default: 5
    )
    var dropPercentage: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let appDelegate = AppDelegate.shared,
              let (batteryService, chargeManager, _, _) = await appDelegate.ensureServicesReady()
        else {
            throw CustomIntentError.stasisNotReady
        }

        var clampedDrop = min(max(dropPercentage, 1), 20)
        if batteryService.deviceCapabilities.nativeMode {
            let chargeLimit = Defaults[.chargeLimit]
            if chargeLimit <= 80 {
                throw CustomIntentError.unsupportedOnOS("Sailing Mode with a Charge Limit of \(chargeLimit)%")
            }
            let maxDrop = chargeLimit - 80
            clampedDrop = min(max(dropPercentage, 5), maxDrop)
        }

        Defaults[.sailingModeLimit] = clampedDrop
        Defaults[.manageCharging] = true
        chargeManager.forceSyncSettings()

        let message = "Sailing Mode drop range set to \(clampedDrop.formattedPercentage)."
        return .result(value: message, dialog: "\(message)")
    }
}
