import AppIntents
import Foundation

struct StasisShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenMenuIntent(),
            phrases: [
                "Open \(.applicationName) menu",
                "Show \(.applicationName) menu",
                "Open \(.applicationName) menu bar dialog",
            ],
            shortTitle: "Open Menu Bar",
            systemImageName: "menubar.rectangle"
        )
        AppShortcut(
            intent: OpenDashboardIntent(),
            phrases: [
                "Open \(.applicationName) dashboard",
                "Open \(.applicationName) settings",
                "Show \(.applicationName) dashboard",
            ],
            shortTitle: "Open Dashboard",
            systemImageName: "gauge.with.dots.needle.bottom.50percent"
        )
        AppShortcut(
            intent: GetBatteryStatusIntent(),
            phrases: [
                "Get battery status in \(.applicationName)",
                "Check battery in \(.applicationName)",
                "What is my battery status in \(.applicationName)?",
            ],
            shortTitle: "Get Battery Status",
            systemImageName: "battery.100"
        )
        AppShortcut(
            intent: SetChargeLimitIntent(),
            phrases: [
                "Set charge limit in \(.applicationName)",
                "Change charge limit in \(.applicationName)",
            ],
            shortTitle: "Set Charge Limit",
            systemImageName: "battery.75"
        )
        AppShortcut(
            intent: ToggleTopUpIntent(),
            phrases: [
                "Top up battery in \(.applicationName)",
                "Charge to 100 percent in \(.applicationName)",
                "Stop top up in \(.applicationName)",
            ],
            shortTitle: "Toggle Top-Up to 100 percent",
            systemImageName: "bolt.fill.batteryblock.fill"
        )
        AppShortcut(
            intent: ToggleSailingModeIntent(),
            phrases: [
                "Toggle sailing mode in \(.applicationName)",
                "Enable sailing mode in \(.applicationName)",
                "Disable sailing mode in \(.applicationName)",
            ],
            shortTitle: "Toggle Sailing Mode",
            systemImageName: "sailboat.fill"
        )
        AppShortcut(
            intent: ToggleForceDischargeIntent(),
            phrases: [
                "Toggle force discharge in \(.applicationName)",
                "Discharge battery in \(.applicationName)",
            ],
            shortTitle: "Toggle Force Discharge",
            systemImageName: "arrow.down.batteryblock.fill"
        )
        AppShortcut(
            intent: StartCalibrationIntent(),
            phrases: [
                "Start battery calibration in \(.applicationName)",
                "Calibrate battery in \(.applicationName)",
            ],
            shortTitle: "Start Battery Calibration",
            systemImageName: "gauge.with.dots.needle.bottom.100percent"
        )
        AppShortcut(
            intent: ToggleHeatProtectionIntent(),
            phrases: [
                "Toggle heat protection in \(.applicationName)",
                "Enable heat protection in \(.applicationName)",
                "Disable heat protection in \(.applicationName)",
            ],
            shortTitle: "Toggle Heat Protection",
            systemImageName: "flame.fill"
        )
        AppShortcut(
            intent: SetHeatProtectionLimitIntent(),
            phrases: [
                "Set heat protection temperature in \(.applicationName)",
                "Change heat protection threshold in \(.applicationName)",
            ],
            shortTitle: "Set Heat Protection Temperature",
            systemImageName: "thermometer.sun.fill"
        )
    }
}
