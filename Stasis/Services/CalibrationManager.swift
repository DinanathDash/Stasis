import AppKit
import Defaults
import Foundation
import Observation
import os.log

@MainActor
@Observable
class CalibrationManager {
    private let batteryService: BatteryService
    private let chargeManager: ChargeManager

    private var metricsObservation: Task<Void, Never>?
    private var schedulerTask: Task<Void, Never>?

    private let logger = Logger(
        subsystem: "com.dinanathdash.stasis",
        category: "CalibrationManager"
    )

    init(batteryService: BatteryService, chargeManager: ChargeManager) {
        self.batteryService = batteryService
        self.chargeManager = chargeManager
        startObservingMetrics()
        startScheduler()
    }

    private func startObservingMetrics() {
        metricsObservation = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.evaluateCalibrationState(metrics: self.batteryService.metrics)
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.batteryService.metrics
                    } onChange: {
                        Task { @MainActor in
                            continuation.resume()
                        }
                    }
                }
            }
        }

        Task { [weak self] in
            for await _ in Defaults.updates([.calibrationStatus], initial: false) {
                guard let self else { return }
                let status = Defaults[.calibrationStatus]
                if status == .idle {
                    self.resetState()
                } else {
                    self.evaluateCalibrationState(metrics: self.batteryService.metrics)
                }
            }
        }
    }

    private func startScheduler() {
        schedulerTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.checkSchedule()
                // Check every minute
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    func startCalibration() {
        guard Defaults[.calibrationStatus] == .idle else { return }
        logger.info("Starting battery calibration cycle manually")
        Defaults[.calibrationStatus] = .discharging
        evaluateCalibrationState(metrics: batteryService.metrics)
    }

    func cancelCalibration() {
        guard Defaults[.calibrationStatus] != .idle else { return }
        logger.info("Canceling battery calibration cycle")
        resetState()
    }

    private func resetState() {
        Defaults[.calibrationStatus] = .idle
        Defaults[.calibrationStepStartTime] = nil
        Task {
            // Restore normal behavior by disabling our manual overrides
            do {
                try await batteryService.cancelOverride()
                chargeManager.forceSyncSettings() // Resync defaults to daemon
                batteryService.scheduleSinglePoll()
            } catch {
                logger.error("Failed to restore state after calibration: \(error.localizedDescription)")
            }
        }
    }

    private func finishCalibration() {
        logger.info("Battery calibration cycle completed successfully")
        Defaults[.lastCalibrationDate] = Date()
        resetState()
    }

    private func evaluateCalibrationState(metrics: BatteryMetrics) {
        let status = Defaults[.calibrationStatus]

        Task {
            do {
                switch status {
                case .discharging:
                    let batteryPercentage = Defaults[.useHardwarePercentage] ? metrics.hardwareBatteryPercentage : metrics.batteryPercentage
                    // Production: 15%
                    if batteryPercentage <= 15 {
                        logger.info("Discharge step complete. Moving to charging step.")
                        Defaults[.calibrationStatus] = .charging
                        try await batteryService.enablePowerAdapter()
                        try await batteryService.chargeToFull()
                        if Defaults[.manageMagSafeLED] {
                            try await batteryService.manageMagsafeLED(target: Defaults[.chargingMagSafeLEDState])
                        }
                    } else {
                        // Ensure it's discharging
                        try await batteryService.disablePowerAdapter()
                        if Defaults[.manageMagSafeLED] {
                            try await batteryService.manageMagsafeLED(target: Defaults[.dischargingMagSafeLEDState])
                        }
                    }
                    batteryService.scheduleSinglePoll()
                case .charging:
                    let batteryPercentage = Defaults[.useHardwarePercentage] ? metrics.hardwareBatteryPercentage : metrics.batteryPercentage
                    // Production: 100%
                    if batteryPercentage >= 100 {
                        logger.info("Charging step complete. Moving to resting step.")
                        Defaults[.calibrationStatus] = .resting
                        Defaults[.calibrationStepStartTime] = Date()
                        // Keep it resting at 100% using adapter power
                        try await batteryService.disableCharging()
                        if Defaults[.manageMagSafeLED] {
                            try await batteryService.manageMagsafeLED(target: Defaults[.pausedMagSafeLEDState])
                        }
                    } else {
                        // Ensure it's charging
                        try await batteryService.chargeToFull()
                        if Defaults[.manageMagSafeLED] {
                            try await batteryService.manageMagsafeLED(target: Defaults[.chargingMagSafeLEDState])
                        }
                    }
                    batteryService.scheduleSinglePoll()
                case .resting:
                    guard let startTime = Defaults[.calibrationStepStartTime] else {
                        Defaults[.calibrationStepStartTime] = Date()
                        return
                    }
                    // Production: 120 mins (2 hours)
                    let elapsedMinutes = Date().timeIntervalSince(startTime) / 60
                    if elapsedMinutes >= 120.0 {
                        finishCalibration()
                    } else {
                        // Keep it resting and use adapter power
                        try await batteryService.disableCharging()
                        if Defaults[.manageMagSafeLED] {
                            try await batteryService.manageMagsafeLED(target: Defaults[.pausedMagSafeLEDState])
                        }
                    }
                case .idle:
                    break
                }
            } catch {
                logger.error("Failed to execute calibration step: \(error.localizedDescription)")
            }
        }
    }

    private func checkSchedule() {
        guard Defaults[.enableAutomaticCalibration] else { return }
        guard Defaults[.calibrationStatus] == .idle else { return }

        let now = Date()
        
        if let snoozeUntil = Defaults[.calibrationSnoozeUntil], now < snoozeUntil {
            return
        }

        let intervalDays = Defaults[.calibrationIntervalDays]
        let targetTime = Defaults[.calibrationTimeOfDay]

        // If never calibrated, consider it ready immediately when time matches
        let lastDate = Defaults[.lastCalibrationDate] ?? .distantPast
        
        let calendar = Calendar.current
        let daysSince = calendar.dateComponents([.day], from: lastDate, to: now).day ?? 0
        
        if daysSince >= intervalDays {
            let currentHour = calendar.component(.hour, from: now)
            let currentMinute = calendar.component(.minute, from: now)
            let targetHour = calendar.component(.hour, from: targetTime)
            let targetMinute = calendar.component(.minute, from: targetTime)
            
            // Allow triggering within a 5-minute window if we missed it or are at the time
            if currentHour == targetHour && currentMinute >= targetMinute && currentMinute < targetMinute + 5 {
                logger.info("Automatic calibration schedule triggered. Requesting user permission.")
                // Bump snooze by 5 minutes so we don't spam them within the window if they ignore it
                Defaults[.calibrationSnoozeUntil] = now.addingTimeInterval(300)

                requestCalibrationPermission()
            }
        }
    }
    
    private func requestCalibrationPermission() {
        let alert = NSAlert()
        alert.icon = NSImage(named: "AppIcon")
        alert.messageText = String(localized: "Battery Calibration Due")
        let percentText = 15.formattedPercentage
        alert.informativeText = String(
            localized: "It's time for your scheduled battery calibration. This will discharge your Mac to \(percentText) before recharging."
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "Start Now"))
        alert.addButton(withTitle: String(localized: "Snooze (1 Day)"))

        alert.window.level = .screenSaver
        alert.window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }

        NSSound.beep()
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Defaults[.calibrationStatus] = .discharging
        } else if response == .alertSecondButtonReturn {
            Defaults[.calibrationSnoozeUntil] = Calendar.current.date(
                byAdding: .day,
                value: 1,
                to: Date()
            )
        }
    }
}
