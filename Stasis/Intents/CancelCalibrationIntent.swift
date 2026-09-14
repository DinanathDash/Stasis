import AppIntents
import Foundation

struct CancelCalibrationIntent: AppIntent {
    static let title: LocalizedStringResource = "Cancel Battery Calibration"
    static let description = IntentDescription("Cancel an ongoing battery calibration cycle in Stasis.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let appDelegate = AppDelegate.shared,
              let (_, _, _, calibrationManager) = await appDelegate.ensureServicesReady()
        else {
            throw CustomIntentError.stasisNotReady
        }

        calibrationManager.cancelCalibration()
        let message = "Battery calibration cycle cancelled."
        return .result(value: message, dialog: "\(message)")
    }
}
