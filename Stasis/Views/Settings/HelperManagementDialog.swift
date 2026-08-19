import AppKit
import SwiftUI

struct HelperManagementDialog: View {
    @Environment(\.dismiss) private var dismiss
    private var helperManager = ChargingHelperManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "shield")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privileged Helper Daemon")
                        .font(.headline)
                    Text("Manages battery charging states in the background.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Form {
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(
                            helperManager.isInstalled
                                ? String(localized: "Installed")
                                : String(localized: "Not Installed")
                        )
                        .foregroundStyle(helperManager.isInstalled ? .green : .secondary)
                        .fontWeight(.medium)
                    }

                    HStack {
                        Text(
                            helperManager.isInstalled
                                ? String(localized: "Uninstall helper daemon")
                                : String(localized: "Install helper daemon")
                        )
                        Spacer()
                        Button(
                            helperManager.isInstalled
                                ? String(localized: "Uninstall")
                                : String(localized: "Install")
                        ) {
                            handleHelperAction()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(helperManager.isInstalled ? .red : .accentColor)
                    }
                } footer: {
                    Text("Note: macOS intentionally retains apps in the \"App Background Activity\" list (System Settings) even after their background helper is unregistered. Once you click Uninstall, the helper is truly disabled, but macOS will keep Stasis visible in that list until the app itself is deleted from your Mac.")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(height: 220)

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func handleHelperAction() {
        let installing = !helperManager.isInstalled
        do {
            if installing {
                NSApp.activate(ignoringOtherApps: true)
                try helperManager.install()
                if helperManager.helperStatus == .requiresApproval {
                    NSAlert.show(
                        title: String(localized: "Action Required"),
                        message: String(localized: "Please open System Settings -> General -> Login Items and allow Stasis to run in the background, then try again."),
                        style: .warning
                    )
                } else {
                    NSAlert.show(
                        title: String(localized: "Helper Status"),
                        message: String(localized: "Helper daemon successfully installed.")
                    )
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.forceSyncSettings()
                    }
                }
            } else {
                try helperManager.uninstall()
                NSAlert.show(
                    title: String(localized: "Helper Status"),
                    message: String(localized: "Helper daemon successfully uninstalled. The app will now restart.")
                )
                AppRestartHelper.restartApp()
            }
        } catch {
            let prefix = installing
                ? String(localized: "Failed to install charging helper")
                : String(localized: "Failed to uninstall charging helper")
            let tip = String(localized: "Tip: Check System Settings -> General -> Login Items. Ensure Stasis is allowed to run in the background. If it is already on, try toggling it off and on again.")
            let msg = "\(prefix):\n\(error.localizedDescription)\n\n\(tip)"
            NSAlert.show(
                title: String(localized: "Helper Status"),
                message: msg,
                style: .warning
            )
        }
    }
}
