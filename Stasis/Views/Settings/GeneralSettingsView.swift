import Defaults
import SwiftUI

struct GeneralSettingsView: View {
    @Default(.launchAtLogin) var launchAtLogin
    @Default(.showBatteryGraphicInStatusIcon) var showBatteryGraphicInStatusIcon
    @Default(.batteryPercentageVisibility) var batteryPercentageVisibility
    @Default(.showBatteryStateInStatusIcon) var showBatteryStateInStatusIcon
    @Default(.enableNotchHUD) var enableNotchHUD
    @Default(.showNotchHUDOnLockScreen) var showNotchHUDOnLockScreen
    @Default(.notchHUDDisplayMode) var notchHUDDisplayMode
    @Default(.notchHUDDisplayDuration) var notchHUDDisplayDuration
    @Default(.notchHUDSound) var notchHUDSound

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
            }

            Section {
                Toggle("Show battery icon", isOn: $showBatteryGraphicInStatusIcon)
                Picker("Battery percentage", selection: $batteryPercentageVisibility) {
                    ForEach(BatteryPercentageVisibility.allCases) { visibility in
                        Text(verbatim: visibility.localizedName).tag(visibility)
                    }
                }
                Toggle("Show battery state", isOn: $showBatteryStateInStatusIcon)
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menu Bar Icon")
                    Text(
                        "Show the battery icon and configure the information displayed in the menu bar."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Show charging state in Notch HUD", isOn: $enableNotchHUD)
                if enableNotchHUD {
                    Toggle("Show on lock screen", isOn: $showNotchHUDOnLockScreen)
                    Picker("Display mode", selection: $notchHUDDisplayMode) {
                        ForEach(NotchHUDDisplayMode.allCases) { mode in
                            Text(verbatim: mode.localizedName).tag(mode)
                        }
                    }
                    Picker("Sound", selection: $notchHUDSound) {
                        ForEach(NotchHUDSound.allCases) { sound in
                            Text(verbatim: sound.localizedName)
                                .tag(sound)
                                .onHover { isHovering in
                                    if isHovering && sound != .none {
                                        NSSound(named: NSSound.Name(sound.rawValue))?.play()
                                    }
                                }
                        }
                    }
                    Picker("Duration", selection: $notchHUDDisplayDuration) {
                        Text("1 second").tag(1.0)
                        Text("2 seconds").tag(2.0)
                        Text("3 seconds").tag(3.0)
                        Text("5 seconds").tag(5.0)
                        Text("10 seconds").tag(10.0)
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notch HUD")
                    Text("Display a floating Dynamic Island-style HUD when the charging state changes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 4, for: .scrollContent)
        .scrollEdgeEffectStyleSoftIfAvailable()
        .onChange(of: launchAtLogin) { _, newValue in
            LaunchAtLoginService.shared.setLaunchAtLogin(newValue)
        }
    }
}

#Preview {
    GeneralSettingsView()
}
