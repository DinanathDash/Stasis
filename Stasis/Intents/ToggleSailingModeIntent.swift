import AppIntents
import Defaults
import Foundation

struct ToggleSailingModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Sailing Mode"
    static let description = IntentDescription("Enable or disable Sailing Mode (reduces micro-charging cycles) in Stasis.")
    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Enable Sailing Mode",
        description: "True to enable, false to disable. Leave empty (nil) to toggle current state.",
        default: nil
    )
    var enable: Bool?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let appDelegate = AppDelegate.shared,
              let (_, chargeManager, _, _) = await appDelegate.ensureServicesReady()
        else {
            throw CustomIntentError.stasisNotReady
        }

        let targetState = enable ?? !Defaults[.sailingMode]
        Defaults[.sailingMode] = targetState
        Defaults[.manageCharging] = true
        chargeManager.forceSyncSettings()

        let message = targetState ? "Sailing Mode enabled." : "Sailing Mode disabled."
        return .result(value: message, dialog: "\(message)")
    }
}
