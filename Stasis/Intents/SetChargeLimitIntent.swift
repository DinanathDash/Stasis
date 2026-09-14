import AppIntents
import Defaults
import Foundation

struct SetChargeLimitIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Charge Limit"
    static let description = IntentDescription("Set the maximum battery charging limit in Stasis.")
    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Limit (%)",
        description: "Charge limit percentage (50 to 100)",
        default: 80
    )
    var limit: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let appDelegate = AppDelegate.shared,
              let (_, chargeManager, _, _) = await appDelegate.ensureServicesReady()
        else {
            throw CustomIntentError.stasisNotReady
        }

        let clampedLimit = min(max(limit, 50), 100)
        Defaults[.chargeLimit] = clampedLimit
        Defaults[.manageCharging] = true
        chargeManager.forceSyncSettings()

        let message: String
        if limit < 50 {
            message = "Charge limit set to \(50.formattedPercentage) (minimum allowed is \(50.formattedPercentage)). Managed Charging enabled."
        } else if limit > 100 {
            message = "Charge limit set to \(100.formattedPercentage) (maximum allowed is \(100.formattedPercentage)). Managed Charging enabled."
        } else {
            message = "Charge limit set to \(clampedLimit.formattedPercentage) (Managed Charging enabled)."
        }

        return .result(value: message, dialog: "\(message)")
    }
}
