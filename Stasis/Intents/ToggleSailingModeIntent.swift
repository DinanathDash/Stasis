import AppIntents
import Defaults
import Foundation

struct ToggleSailingModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Sailing Mode"
    static let description = IntentDescription("Enable or disable Sailing Mode (reduces micro-charging cycles) in Stasis.")
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Enable Sailing Mode",
        description: "True to enable, false to disable. Leave empty (nil) to toggle current state.",
        default: nil
    )
    var enable: Bool?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let targetState = enable ?? !Defaults[.sailingMode]
        Defaults[.sailingMode] = targetState
        Defaults[.manageCharging] = true

        if let appDelegate = AppDelegate.shared,
           let (_, chargeManager, _, _) = await appDelegate.ensureServicesReady() {
            chargeManager.forceSyncSettings()
        }

        let message = targetState ? "Sailing Mode enabled." : "Sailing Mode disabled."
        return .result(value: message, dialog: "\(message)")
    }
}
