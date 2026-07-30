import AppIntents
import Defaults
import Foundation

struct ToggleTopUpIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Top-Up to 100 percent"
    static let description = IntentDescription("Temporarily override the charge limit and charge the MacBook to 100 percent, or cancel Top-Up if active.")
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Enable Top-Up",
        description: "True to start Top-Up, false to stop. Leave empty (nil) to toggle current state.",
        default: nil
    )
    var enable: Bool?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        if let appDelegate = AppDelegate.shared,
           let (_, chargeManager, _, _) = await appDelegate.ensureServicesReady() {
            let targetState = enable ?? !chargeManager.chargeLimitOverrideActive
            if chargeManager.chargeLimitOverrideActive != targetState {
                chargeManager.toggleChargeLimitOverride()
            }
            let message = targetState ? "Top-up to \(100.formattedPercentage) started." : "Top-up to \(100.formattedPercentage) cancelled. Standard limit resumed."
            return .result(value: message, dialog: "\(message)")
        } else {
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("com.dinanathdash.stasis.toggleTopUp"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            let message = "Toggled Top-Up in Stasis."
            return .result(value: message, dialog: "\(message)")
        }
    }
}
