import Defaults
import ServiceManagement
import SwiftUI

struct AboutSettingsView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject private var updaterManager = UpdaterManager.shared

    init() {}

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
                    Text("Weekly").tag(TimeInterval(604_800))
                    Text("Monthly").tag(TimeInterval(2_592_000))
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
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 4, for: .scrollContent)
        .scrollEdgeEffectStyleSoftIfAvailable()
    }

    private var versionText: String? {
        guard
            let shortVersion = Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String
        else {
            return nil
        }

        return String(localized: "Version \(shortVersion)")
    }
}

@MainActor
extension NSAlert {
    static func show(title: String, message: String, style: NSAlert.Style = .informational) {
        let alert = NSAlert()
        alert.icon = NSImage(named: "AppIcon")
        alert.messageText = String(localized: String.LocalizationValue(title))
        alert.informativeText = String(localized: String.LocalizationValue(message))
        alert.alertStyle = style
        alert.addButton(withTitle: String(localized: "OK"))

        alert.window.level = .screenSaver
        alert.window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }

        NSSound.beep()
        alert.runModal()
    }
}

#Preview {
    AboutSettingsView()
}
