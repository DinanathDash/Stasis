import AppKit
import ServiceManagement
import SwiftUI

enum AppResetHelper {
    @MainActor
    static func resetAllPreferences() {
        // Uninstall the helper daemon (this handles SMC reset internally)
        do {
            try ChargingHelperManager.shared.uninstall()
        } catch {
            print("Failed to uninstall charging helper: \(error)")
        }

        // Disable launch at login and actively unregister to clear OS cache
        LaunchAtLoginService.shared.setLaunchAtLogin(false)
        try? SMAppService.mainApp.unregister()

        // Remove all persisted defaults for this app bundle
        let bundleID = Bundle.main.bundleIdentifier ?? "com.dinanathdash.stasis"
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
        UserDefaults.standard.synchronize() // Force write

        // Reset system permissions (Accessibility, Background Items, etc.) to force OS cache flush
        let tccProcess = Process()
        tccProcess.launchPath = "/usr/bin/tccutil"
        tccProcess.arguments = ["reset", "All", bundleID]
        try? tccProcess.run()
        tccProcess.waitUntilExit()
    }
}

struct SidebarBottomButtonsView: View {
    @Binding var showLanguageDialog: Bool
    @Binding var showHelperDialog: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button {
                showLanguageDialog = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 28, height: 28)
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.cyan)
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Change display language...")

            Button {
                showHelperDialog = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 28, height: 28)
                    Image(systemName: "shield")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.orange)
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Manage privileged helper daemon...")

            Button {
                presentResetAlert()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 28, height: 28)
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.red)
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Reset all preferences")

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func presentResetAlert() {
        let alert = NSAlert()
        alert.icon = NSImage(named: "AppIcon")
        alert.messageText = String(localized: "Reset All Preferences?")
        alert.informativeText = String(
            localized: "All preferences will be restored to their defaults and Stasis will restart immediately."
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Reset and Restart"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        alert.window.level = .screenSaver
        alert.window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }

        NSSound.beep()
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            AppResetHelper.resetAllPreferences()
            NSAlert.show(
                title: String(localized: "Preferences Reset"),
                message: String(localized: "All preferences have been successfully restored to their defaults. The app will now restart.")
            )
            AppRestartHelper.restartApp()
        }
    }
}
