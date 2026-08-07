import AppKit
import Defaults
import Foundation
import IOKit.pwr_mgt
import Observation
import os.log
import smc_power
import ServiceManagement

@MainActor
@Observable
class ChargeManager {
    private let batteryService: BatteryService

    private var settingsObservation: Task<Void, Never>?

    private(set) var chargeLimitOverrideActive = false
    private(set) var forceDischargeActive = false
    private(set) var chargeToLimitActive = false
    private(set) var daemonSyncError = false
    private(set) var daemonError: String? = nil
    private var hasShownDaemonErrorAlert = false

    private let logger = Logger(
        subsystem: "com.dinanathdash.stasis",
        category: "ChargeManager"
    )

    init(batteryService: BatteryService) {
        self.batteryService = batteryService
        startObservingSettings()
    }

    private func startObservingSettings() {
        settingsObservation = Task { [weak self] in
            for await _ in Defaults.updates(
                [
                    .manageCharging, .sailingMode, .automaticDischarge,
                    .enableHeatProtectionMode, .manageMagSafeLED,
                    .chargeLimit, .sailingModeLimit, .heatProtectionLimit,
                    .disableSleepUntilChargeLimit, .chargingOnHoldMagSafeLEDState,
                    .heatProtectionMagSafeLEDState
                ],
                initial: true
            ) {
                guard let self else { return }
                self.syncSettingsToDaemon()
            }
        }
    }

    func forceSyncSettings() {
        syncSettingsToDaemon()
    }

    private func syncSettingsToDaemon() {
        guard ChargingHelperManager.shared.isInstalled else {
            logger.info("Skipping sync: helper is not installed")
            return
        }

        let settings: [String: NSObject & Sendable] = [
            "manageCharging": Defaults[.manageCharging] as NSNumber,
            "chargeLimit": Defaults[.chargeLimit] as NSNumber,
            "sailingMode": Defaults[.sailingMode] as NSNumber,
            "sailingModeLimit": Defaults[.sailingModeLimit] as NSNumber,
            "automaticDischarge": Defaults[.automaticDischarge] as NSNumber,
            "enableHeatProtectionMode": Defaults[.enableHeatProtectionMode] as NSNumber,
            "heatProtectionLimit": Defaults[.heatProtectionLimit] as NSNumber,
            "disableSleepUntilChargeLimit": Defaults[.disableSleepUntilChargeLimit] as NSNumber,
            "manageMagSafeLED": Defaults[.manageMagSafeLED] as NSNumber,
            "chargingOnHoldMagSafeLEDState": Defaults[.chargingOnHoldMagSafeLEDState].rawValue as NSNumber,
            "heatProtectionMagSafeLEDState": Defaults[.heatProtectionMagSafeLEDState].rawValue as NSNumber
        ]

        Task {
            let maxRetries = 20
            for attempt in 1...maxRetries {
                do {
                    try await batteryService.setSettings(settings: settings)
                    logger.info("Successfully synced settings to daemon on attempt \(attempt)")
                    daemonSyncError = false
                    hasShownDaemonErrorAlert = false
                    // Once settings are synced, trigger a single poll to update UI immediately
                    batteryService.scheduleSinglePoll(delay: .milliseconds(500))
                    break
                } catch {
                    logger.error("Failed to sync settings to daemon (attempt \(attempt)): \(error.localizedDescription)")
                    if attempt < maxRetries {
                        try? await Task.sleep(for: .milliseconds(500))
                    } else {
                        daemonSyncError = true
                        showDaemonErrorAlertIfNeeded()
                    }
                }
            }
        }
    }

    private func showDaemonErrorAlertIfNeeded() {
        guard !hasShownDaemonErrorAlert else { return }
        hasShownDaemonErrorAlert = true
        
        let alert = NSAlert()
        alert.icon = NSImage(named: "AppIcon")
        alert.messageText = String(localized: "Background Helper Disconnected")
        alert.informativeText = String(localized: "Stasis lost connection to its background helper. Please go to System Settings > General > Login Items, turn Stasis off and back on under 'Allow in the Background', and restart the app.")
        alert.alertStyle = .critical
        alert.addButton(withTitle: String(localized: "Open Settings"))
        alert.addButton(withTitle: String(localized: "Dismiss"))
        
        alert.window.level = .screenSaver
        alert.window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
        
        NSSound.beep()
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    func toggleChargeLimitOverride() {
        chargeLimitOverrideActive.toggle()
        if chargeLimitOverrideActive {
            forceDischargeActive = false
            chargeToLimitActive = false
            if Defaults[.calibrationStatus] != .idle {
                Defaults[.calibrationStatus] = .idle
            }
        }
        Task {
            do {
                if chargeLimitOverrideActive {
                    try await batteryService.chargeToFull()
                } else {
                    try await batteryService.cancelOverride()
                    syncSettingsToDaemon()
                }
                batteryService.scheduleSinglePoll()
                self.daemonError = nil
            } catch {
                logger.error("Failed to toggle charge limit override: \(error.localizedDescription)")
                self.daemonError = error.localizedDescription
                chargeLimitOverrideActive.toggle() // revert on failure
            }
        }
    }

    func toggleForceDischarge() {
        forceDischargeActive.toggle()
        if forceDischargeActive {
            chargeLimitOverrideActive = false
            chargeToLimitActive = false
            if Defaults[.calibrationStatus] != .idle {
                Defaults[.calibrationStatus] = .idle
            }
        }
        Task {
            do {
                if forceDischargeActive {
                    try await batteryService.disablePowerAdapter()
                } else {
                    try await batteryService.cancelOverride()
                    syncSettingsToDaemon()
                }
                batteryService.scheduleSinglePoll()
                self.daemonError = nil
            } catch {
                logger.error("Failed to toggle force discharge: \(error.localizedDescription)")
                self.daemonError = error.localizedDescription
                forceDischargeActive.toggle() // revert on failure
            }
        }
    }

    func toggleChargeToLimit() {
        chargeToLimitActive.toggle()
        if chargeToLimitActive {
            chargeLimitOverrideActive = false
            forceDischargeActive = false
            if Defaults[.calibrationStatus] != .idle {
                Defaults[.calibrationStatus] = .idle
            }
        }
        Task {
            do {
                if chargeToLimitActive {
                    try await batteryService.chargeToLimit()
                } else {
                    try await batteryService.cancelOverride()
                    syncSettingsToDaemon()
                }
                batteryService.scheduleSinglePoll()
                self.daemonError = nil
            } catch {
                logger.error("Failed to toggle charge to limit: \(error.localizedDescription)")
                self.daemonError = error.localizedDescription
                chargeToLimitActive.toggle() // revert on failure
            }
        }
    }

    func stop() {
        settingsObservation?.cancel()
        settingsObservation = nil
    }
}
