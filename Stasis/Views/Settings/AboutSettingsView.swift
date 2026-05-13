import Defaults
import SwiftUI

struct AboutSettingsView: View {
    @Default(.automaticallyCheckForUpdates) var automaticallyCheckForUpdates
    @Default(.updateAutomationMode) var updateAutomationMode

    private let updaterService: UpdaterService

    init(updaterService: UpdaterService) {
        self.updaterService = updaterService
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
                    Text("Srimana Achanta")
                        .fontWeight(.medium)
                    Text("Built with a focus on practical battery health and charging workflows.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Section {
                Toggle("Automatically check for updates", isOn: $automaticallyCheckForUpdates)

                Picker("When updates are found", selection: $updateAutomationMode) {
                    Text("Notify only").tag(UpdaterService.UpdateAutomationMode.notify)
                    Text("Auto-download to Downloads folder").tag(UpdaterService.UpdateAutomationMode.autoDownload)
                }
                .disabled(!automaticallyCheckForUpdates)

                Button("Check for updates now") {
                    updaterService.checkForUpdates()
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Updates")
                    Text("Stasis can check and download updates to your Downloads folder.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0)
        .onChange(of: automaticallyCheckForUpdates) { _, _ in
            // Update check preference saved automatically via Defaults
        }
    }

    private var versionText: String? {
        guard let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return nil
        }

        return "Version \(shortVersion)"
    }
}

#Preview {
    AboutSettingsView(updaterService: UpdaterService.shared)
}
