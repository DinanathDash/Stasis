import AppIntents
import Defaults
import Foundation
import smc_power

struct ToggleForceDischargeIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Force Discharge"
    static let description = IntentDescription("Enable or disable force discharging the battery while plugged in.")
    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Enable Force Discharge",
        description: "True to start discharge, false to stop. Leave empty (nil) to toggle current state.",
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
            throw CustomIntentError.unsupportedOnOS("Force Discharge")
        }

        let targetState = enable ?? !chargeManager.forceDischargeActive
        if chargeManager.forceDischargeActive != targetState {
            chargeManager.toggleForceDischarge()
        }

        let message = targetState ? "Force Discharge started. Draining to limit." : "Force Discharge stopped."
        return .result(value: message, dialog: "\(message)")
    }
}
