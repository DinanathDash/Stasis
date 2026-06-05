import Defaults
import SwiftUI

struct AboutSettingsView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject private var updaterManager = UpdaterManager.shared

    init() {
    }

    var body: some View {
        Form {
            Section("About Stasis") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Stasis")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Battery and charging control for MacBook.")
                        .foregroundStyle(.secondary)

                    if let versionText {
                        Text(versionText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }

            Section("Developer") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dinanath Dash")
                        .fontWeight(.medium)
                    Text(
                        "Originally forked from an open-source base, then developed further with new features."
                    )
                    .foregroundStyle(.secondary)
                    Text(
                        "Built with a focus on practical battery health and charging workflows."
                    )
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Section("Community") {
                HStack(spacing: 16) {
                    Button {
                        openURL(
                            URL(
                                string:
                                    "https://github.com/DinanathDash/Stasis/issues/new?template=bug_report.yml"
                            )!
                        )
                    } label: {
                        Label("Report a bug", systemImage: "ant")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        openURL(
                            URL(
                                string:
                                    "https://github.com/DinanathDash/Stasis/issues/new?template=feature_request.yml"
                            )!
                        )
                    } label: {
                        Label("Request a feature", systemImage: "lightbulb")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        openURL(
                            URL(
                                string: "https://github.com/DinanathDash/Stasis"
                            )!
                        )
                    } label: {
                        Label {
                            Text("View on GitHub")
                        } icon: {
                            Image("GitHubMark")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.bordered)
                }
                .listRowBackground(Color.clear)
            }

            Section {
                Toggle(isOn: Binding(
                    get: { updaterManager.automaticallyChecksForUpdates },
                    set: { updaterManager.automaticallyChecksForUpdates = $0 }
                )) {
                    Text("Automatically check for updates")
                }

                Picker("Check frequency", selection: Binding(
                    get: { updaterManager.updateCheckInterval },
                    set: { updaterManager.updateCheckInterval = $0 }
                )) {
                    Text("Daily").tag(TimeInterval(86400))
                    Text("Weekly").tag(TimeInterval(604800))
                    Text("Monthly").tag(TimeInterval(2592000))
                }
                .disabled(!updaterManager.automaticallyChecksForUpdates)

                Picker(
                    "When updates are found",
                    selection: Binding(
                        get: { updaterManager.automaticallyDownloadsUpdates },
                        set: { updaterManager.automaticallyDownloadsUpdates = $0 }
                    )
                ) {
                    Text("Notify only").tag(false)
                    Text("Auto-download").tag(true)
                }
                .disabled(!updaterManager.automaticallyChecksForUpdates)

                Button("Check for updates now") {
                    updaterManager.checkForUpdates()
                }
                .disabled(!updaterManager.canCheckForUpdates)
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Updates")
                    Text("Stasis uses Sparkle to handle automatic updates.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    let helperManager = ChargingHelperManager.shared
                    Text(helperManager.isInstalled ? "Uninstall helper daemon" : "Install helper daemon")
                    Spacer()
                    Button(helperManager.isInstalled ? "Uninstall" : "Install") {
                        let installing = !helperManager.isInstalled
                        do {
                            if installing {
                                try helperManager.install()
                                NSAlert.show(title: "Helper Status", message: "Helper daemon successfully installed.")
                            } else {
                                try helperManager.uninstall()
                                NSAlert.show(title: "Helper Status", message: "Helper daemon successfully uninstalled.")
                            }
                        } catch {
                            let msg = "Failed to \(installing ? "install" : "uninstall") charging helper:\n\(error.localizedDescription)\n\nTip: Check System Settings -> General -> Login Items. Ensure Stasis is allowed to run in the background. If it is already on, try toggling it off and on again."
                            NSAlert.show(title: "Helper Status", message: msg, style: .warning)
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(helperManager.isInstalled ? .red : .accentColor)
                }
            } header: {
                Text("Privileged Helper")
            } footer: {
                Text("The helper daemon runs in the background to manage battery charging states.")
            }

            Section {
                HStack {
                    Text("Reset all preferences")
                    Spacer()
                    Button("Reset") {
                        resetAllPreferences()
                        NSAlert.show(title: "Preferences Reset", message: "All preferences have been successfully restored to their defaults.")
                    }
                    .foregroundColor(.red)
                }
            } header: {
                Text("Reset Preferences")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0)

    }

    private var versionText: String? {
        guard
            let shortVersion = Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String
        else {
            return nil
        }

        return "Version \(shortVersion)"
    }

    // MARK: - Preferences reset helper
    private func resetAllPreferences() {
        // Uninstall the helper daemon
        do {
            try ChargingHelperManager.shared.uninstall()
        } catch {
            print("Failed to uninstall charging helper: \(error)")
        }

        // Disable launch at login
        LaunchAtLoginService.shared.setLaunchAtLogin(false)

        // Remove all persisted defaults for this app bundle
        let bundleID = Bundle.main.bundleIdentifier ?? "com.dinanathdash.stasis"
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
    }
}

@MainActor
extension NSAlert {
    static func show(title: String, message: String, style: NSAlert.Style = .informational) {
        let alert = NSAlert()
        alert.icon = NSImage(named: "AppIcon")
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        NSSound.beep()
        alert.runModal()
    }
}

#Preview {
    AboutSettingsView()
}
