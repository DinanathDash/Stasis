import AppIntents
import Defaults
import Foundation

struct SetChargeLimitIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Charge Limit"
    static let description = IntentDescription("Set the maximum battery charging limit in Stasis.")
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Limit (%)",
        description: "Charge limit percentage (50 to 100)",
        default: 80
    )
    var limit: Int

    init() {
        self.limit = 80
    }

    init(limit: Int) {
        self.limit = limit
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let clampedLimit = min(max(limit, 50), 100)
        Defaults[.chargeLimit] = clampedLimit
        Defaults[.manageCharging] = true

        if let appDelegate = AppDelegate.shared,
           let (_, chargeManager, _, _) = await appDelegate.ensureServicesReady() {
            chargeManager.forceSyncSettings()
        }

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
