import Defaults
import Foundation
import os.log
import WidgetKit

/// Central manager in the `Stasis` app that observes state changes from `MenuViewModel` / `BatteryService`,
/// saves the latest snapshot to shared storage, and reloads WidgetKit timelines when state changes meaningfully.
@MainActor
final class WidgetDataManager {
    static let shared = WidgetDataManager()

    private let logger = Logger(subsystem: "com.dinanathdash.stasis", category: "WidgetDataManager")
    private var lastSnapshot: WidgetStatusData?

    private init() {
        lastSnapshot = WidgetStatusData.load()
    }

    /// Updates the widget snapshot from the current view model state.
    /// Automatically throttles timeline reloads unless percentage, charging mode, or active settings change.
    func update(
        percentage: Int,
        chargingMode: ChargingMode,
        isTopUpActive: Bool,
        batteryWatts: Double,
        adapterWatts: Double,
        systemWatts: Double,
        batteryHealth: Int,
        batteryTemperature: Double,
        cycleCount: Int,
        timeRemainingMinutes: Int?,
        outputPortPowers: [Double],
        outputIcons: [String],
        hasMultiPort: Bool
    ) {
        let isCharging = (chargingMode == .charging)
        let isPluggedIn = (chargingMode != .discharging)
        let chargeLimit = Defaults[.chargeLimit]
        let isSailingMode = Defaults[.sailingMode]
        let sailingDropLimit = Defaults[.sailingModeLimit]

        let modeRaw: String
        switch chargingMode {
        case .charging: modeRaw = "charging"
        case .discharging: modeRaw = "discharging"
        case .pluggedIn: modeRaw = "pluggedIn"
        }

        let newSnapshot = WidgetStatusData(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            chargeLimit: chargeLimit,
            isSailingMode: isSailingMode,
            sailingDropLimit: sailingDropLimit,
            isTopUpActive: isTopUpActive,
            batteryWatts: batteryWatts,
            adapterWatts: adapterWatts,
            systemWatts: systemWatts,
            batteryHealth: batteryHealth,
            batteryTemperature: batteryTemperature,
            cycleCount: cycleCount,
            timeRemainingMinutes: timeRemainingMinutes,
            chargingModeRaw: modeRaw,
            outputPortPowers: outputPortPowers,
            outputIcons: outputIcons,
            hasMultiPort: hasMultiPort,
            lastUpdated: Date()
        )

        let shouldReload: Bool
        if let last = lastSnapshot {
            let percentageChanged = (last.percentage != newSnapshot.percentage)
            let stateChanged = (last.chargingModeRaw != newSnapshot.chargingModeRaw)
            let modeChanged = (last.isSailingMode != newSnapshot.isSailingMode)
                || (last.isTopUpActive != newSnapshot.isTopUpActive)
                || (last.chargeLimit != newSnapshot.chargeLimit)
            let timeElapsed = Date().timeIntervalSince(last.lastUpdated) > 15.0

            shouldReload = percentageChanged || stateChanged || modeChanged || timeElapsed
        } else {
            shouldReload = true
        }

        if shouldReload {
            newSnapshot.save()
            lastSnapshot = newSnapshot
            logger.debug("Saved new WidgetStatusData snapshot and reloading WidgetKit timeline.")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
