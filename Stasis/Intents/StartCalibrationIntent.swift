import AppIntents
import Foundation

struct StartCalibrationIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Battery Calibration"
    static let description = IntentDescription("Start a battery calibration cycle in Stasis.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let appDelegate = AppDelegate.shared,
              let (_, _, _, calibrationManager) = await appDelegate.ensureServicesReady()
        else {
            throw CustomIntentError.stasisNotReady
        }

        calibrationManager.startCalibration()
        let message = "Battery calibration cycle started."
        return .result(value: message, dialog: "\(message)")
    }
}
