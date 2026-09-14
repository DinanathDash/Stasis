import AppIntents
import Defaults
import Foundation

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
              let (_, chargeManager, _, _) = await appDelegate.ensureServicesReady()
        else {
            throw CustomIntentError.stasisNotReady
        }

        let clampedDrop = min(max(dropPercentage, 1), 20)
        Defaults[.sailingModeLimit] = clampedDrop
        Defaults[.manageCharging] = true
        chargeManager.forceSyncSettings()

        let message = "Sailing Mode drop range set to \(clampedDrop.formattedPercentage)."
        return .result(value: message, dialog: "\(message)")
    }
}
