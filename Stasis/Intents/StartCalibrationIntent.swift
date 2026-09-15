import AppIntents
import Foundation
import smc_power

struct StartCalibrationIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Battery Calibration"
    static let description = IntentDescription("Start a battery calibration cycle in Stasis.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let appDelegate = AppDelegate.shared,
              let (batteryService, _, _, calibrationManager) = await appDelegate.ensureServicesReady()
        else {
            throw CustomIntentError.stasisNotReady
        }

        if batteryService.deviceCapabilities.nativeMode {
            throw CustomIntentError.unsupportedOnOS("Battery Calibration")
        }

        calibrationManager.startCalibration()
        let message = "Battery calibration cycle started."
        return .result(value: message, dialog: "\(message)")
    }
}
