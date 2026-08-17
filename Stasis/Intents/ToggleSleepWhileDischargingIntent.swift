import AppIntents
import Defaults
import Foundation

struct ToggleSleepWhileDischargingIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Sleep While Discharging"
    static let description = IntentDescription("Enable or disable preventing sleep while discharging in Stasis. This enables Clamshell Mode during Automatic Discharge.")
    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Disable Sleep While Discharging",
        description: "True to disable sleep, false to allow sleep. Leave empty (nil) to toggle current state.",
        default: nil
    )
    var enable: Bool?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let appDelegate = AppDelegate.shared,
              let (_, chargeManager, _, _) = await appDelegate.ensureServicesReady() else {
            throw CustomIntentError.stasisNotReady
        }

        let targetState = enable ?? !Defaults[.disableSleepWhileDischarging]
        Defaults[.disableSleepWhileDischarging] = targetState
        Defaults[.manageCharging] = true
        chargeManager.forceSyncSettings()

        let message = targetState ? String(localized: "Sleep while discharging disabled.") : String(localized: "Sleep while discharging enabled.")
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
