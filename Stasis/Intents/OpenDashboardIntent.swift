import AppIntents
import AppKit
import Foundation

struct OpenDashboardIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Stasis Dashboard"
    static let description = IntentDescription("Open the Stasis Dashboard / Settings window.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let appDelegate = AppDelegate.shared,
              let _ = await appDelegate.ensureServicesReady()
        else {
            throw CustomIntentError.stasisNotReady
        }

        appDelegate.showSettingsWindow()
        NSApp.activate(ignoringOtherApps: true)

        let message = "Stasis Dashboard opened."
        return .result(value: message, dialog: "\(message)")
    }
}
