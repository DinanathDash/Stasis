import AppIntents
import Defaults
import Foundation

struct GetBatteryStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Battery Status"
    static let description = IntentDescription("Get current battery percentage, charge limit, charging mode, wattage, health, and temperature from Stasis.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        if let appDelegate = AppDelegate.shared,
           let (_, _, viewModel, _) = await appDelegate.ensureServicesReady() {
            let percentage = viewModel.displayPercentage
            let chargingMode = viewModel.chargingMode
            let limit = Defaults[.chargeLimit]
            let isSailing = Defaults[.sailingMode]
            let healthText = viewModel.batteryHealthText
            let tempText = viewModel.batteryTemperatureText

            var modeText = ""
            switch chargingMode {
            case .charging:
                modeText = "Charging"
            case .discharging:
                modeText = "On Battery (Discharging)"
            case .pluggedIn:
                if isSailing {
                    modeText = "Sailing Mode (Limit: \(limit.formattedPercentage))"
                } else {
                    modeText = "On Hold (Limit: \(limit.formattedPercentage))"
                }
            }

            let batteryWatts = abs(viewModel.batteryPower)
            let adapterWatts = abs(viewModel.adapterPower)
            let systemWatts = abs(viewModel.systemPower)

            let powerFlowDescription: String
            if viewModel.batteryPower > 0.5 {
                powerFlowDescription = String(format: "Charging battery at +%.1fW (AC Input: %.1fW)", batteryWatts, adapterWatts)
            } else if viewModel.batteryPower < -0.5 {
                powerFlowDescription = String(format: "Draining battery at -%.1fW (System load: %.1fW)", batteryWatts, systemWatts)
            } else if viewModel.adapterConnected {
                powerFlowDescription = String(format: "0.0W to battery — running on AC power (Input: %.1fW, System load: %.1fW)", adapterWatts, systemWatts)
            } else {
                powerFlowDescription = "0.0W battery flow"
            }

            let statusString = "Battery is at \(percentage.formattedPercentage) (\(modeText)). Power Flow: \(powerFlowDescription). Health: \(healthText), Temperature: \(tempText)."

            return .result(value: statusString, dialog: "\(statusString)")
        } else {
            let data = WidgetStatusData.load()
            let statusString = "Battery is at \(data.percentage.formattedPercentage) (\(data.chargingModeRaw)). Health: \(data.batteryHealth.formattedPercentage), Temperature: \(String(format: "%.1f°C", data.batteryTemperature))."
            return .result(value: statusString, dialog: "\(statusString)")
        }
    }
}

enum CustomIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case stasisNotReady
    case invalidLimit(Int)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .stasisNotReady:
            return "Stasis services are not ready or running."
        case .invalidLimit(let value):
            return "Charge limit \(value.formattedPercentage) is invalid. Must be between 50 and 100."
        }
    }
}
