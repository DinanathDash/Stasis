import AppIntents
import Defaults
import Foundation

struct ToggleMagSafeLEDControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle MagSafe LED Control"
    static let description = IntentDescription("Enable or disable custom MagSafe LED colors in Stasis.")
    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Enable MagSafe LED Control",
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

        let targetState = enable ?? !Defaults[.manageMagSafeLED]
        Defaults[.manageMagSafeLED] = targetState
        Defaults[.manageCharging] = true
        chargeManager.forceSyncSettings()

        let message = targetState ? "MagSafe LED Control enabled." : "MagSafe LED Control disabled."
        return .result(value: message, dialog: "\(message)")
    }
}
