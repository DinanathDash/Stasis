import AppKit
import Defaults
import Foundation
import Observation

@MainActor
@Observable
class MenuViewModel {
    private let batteryService: BatteryService
    private let chargeManager: ChargeManager
    private let bootTimestamp: Date?

    var batteryPercentageText: String = "0%"
    var powerSourceText: String = "Battery"
    var timeRemainingText: String = "Calculating..."
    var uptimeText: String = "00:00"
    var batteryModeText: String = "Unknown"
    var batteryTemperatureText: String = "0°C"
    var externalInputText: String = "0V @ 0A"
    var internalInputText: String = "0V @ 0A"
    var cycleCountText: String = "0"
    var batteryHealthText: String = "100%"

    var displayPercentage: Int = 0
    var chargingMode: ChargingMode = .discharging
    var batteryPower: Double = 0
    var adapterPower: Double = 0
    var systemPower: Double = 0
    var powerSource: PowerSource = .battery
    var isCharging: Bool = false

    var chargeLimitOverrideActive: Bool { chargeManager.chargeLimitOverrideActive }
    var forceDischargeActive: Bool { chargeManager.forceDischargeActive }
    var manageChargingEnabled: Bool { Defaults[.manageCharging] }
    var adapterConnected: Bool = false

    private var metricsObservation: Task<Void, Never>?
    private var settingsObservation: Task<Void, Never>?
    private var uptimeTask: Task<Void, Never>?
    private var timeEstimator = TimeRemainingEstimator()

    init(batteryService: BatteryService, chargeManager: ChargeManager) {
        self.batteryService = batteryService
        self.chargeManager = chargeManager
        self.bootTimestamp = SystemService.bootTimestamp()
        startObservingMetrics()
        startObservingSettings()
    }

    private func startObservingMetrics() {
        metricsObservation = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.updateFormattedValues(
                    from: self.batteryService.metrics,
                    adapter: self.batteryService.adapterMetrics
                )
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.batteryService.metrics
                        _ = self.batteryService.adapterMetrics
                    } onChange: {
                        Task { @MainActor in
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }

    private func startObservingSettings() {
        settingsObservation = Task { [weak self] in
            for await _ in Defaults.updates([.useHardwarePercentage], initial: false) {
                guard let self else { return }
                self.updateFormattedValues(
                    from: self.batteryService.metrics,
                    adapter: self.batteryService.adapterMetrics
                )
            }
        }
    }

    func toggleChargeLimitOverride() {
        chargeManager.toggleChargeLimitOverride()
    }

    func toggleForceDischarge() {
        chargeManager.toggleForceDischarge()
    }

    private func updateFormattedValues(from metrics: BatteryMetrics, adapter: AdapterMetrics) {
        let useHardware = Defaults[.useHardwarePercentage]
        let percentage =
            useHardware
            ? metrics.hardwareBatteryPercentage : metrics.batteryPercentage
        displayPercentage = percentage
        batteryPercentageText = "\(percentage)%"

        let derivedPowerSource = derivePowerSource(battery: metrics, adapter: adapter)

        switch derivedPowerSource {
        case .battery:
            powerSourceText = "Battery"
        case .acAdapter:
            powerSourceText = "Power Adapter"
        case .both:
            powerSourceText = "Battery & Power Adapter"
        }

        updateUptimeText()

        if derivedPowerSource == .acAdapter {
            if metrics.isCharging {
                chargingMode = .charging
                batteryModeText = "Charging"
            } else {
                chargingMode = .pluggedIn
                batteryModeText = "Plugged In (Not Charging)"
            }
        } else {
            chargingMode = .discharging
            batteryModeText = "Discharging"
        }

        batteryTemperatureText =
            "\(metrics.batteryTemperature.formatted(.number.precision(.fractionLength(1))))°C"

        let voltageFormat = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))
        let currentFormat = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))

        externalInputText =
            "\(adapter.adapterVoltage.formatted(voltageFormat))V @ \(adapter.adapterCurrent.formatted(currentFormat))A"

        internalInputText =
            "\(metrics.batteryVoltage.formatted(voltageFormat))V @ \(metrics.batteryCurrent.formatted(currentFormat))A"

        batteryPower = metrics.batteryPower
        adapterPower = adapter.adapterPower
        systemPower = adapter.adapterPower - metrics.batteryPower
        powerSource = derivedPowerSource
        isCharging = metrics.isCharging
        adapterConnected = adapter.adapterConnected

        timeRemainingText = formatTimeRemaining(minutes: metrics.timeRemaining, isCharging: metrics.isCharging)

        cycleCountText = "\(metrics.cycleCount)"
        batteryHealthText = "\(metrics.batteryHealth)%"
    }

    private func derivePowerSource(battery: BatteryMetrics, adapter: AdapterMetrics) -> PowerSource {
        guard adapter.adapterConnected else { return .battery }

        if adapter.adapterPower == 0 {
            return .battery
        } else if battery.batteryPower >= 0 {
            return .acAdapter
        } else {
            return .both
        }
    }

    private func updateUptimeText() {
        guard let bootTimestamp else {
            uptimeText = "Unknown"
            return
        }

        let uptime = max(0, Int(Date().timeIntervalSince(bootTimestamp)))
        let duration = Duration.seconds(uptime)
        uptimeText = duration.formatted(
            .units(allowed: [.days, .hours, .minutes], width: .abbreviated)
        )
    }

    private func startUptimeTimer() {
        guard uptimeTask == nil else { return }

        uptimeTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                self?.updateUptimeText()
            }
        }
    }

    private func stopUptimeTimer() {
        uptimeTask?.cancel()
        uptimeTask = nil
    }

    func menuWillOpen() {
        updateUptimeText()
        startUptimeTimer()
        batteryService.enableFastPolling()
    }

    func menuDidClose() {
        stopUptimeTimer()
        batteryService.disableFastPolling()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func formatTimeRemaining(minutes: Int, isCharging: Bool) -> String {
        if adapterConnected && !isCharging {
            return "N/A"
        }

        let estimatedMinutes = timeEstimator.estimateTimeRemaining(
            reportedMinutes: minutes,
            isCharging: isCharging,
            adapterConnected: adapterConnected,
            batteryPercentage: displayPercentage,
            chargingTargetPercentage: chargingTargetPercentage
        )
        guard let validMinutes = estimatedMinutes, validMinutes >= 0 else {
            return "Calculating..."
        }
        let hours = validMinutes / 60
        let mins = validMinutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }

    private var chargingTargetPercentage: Int {
        if Defaults[.manageCharging] && !chargeLimitOverrideActive {
            return Defaults[.chargeLimit]
        }
        return 100
    }

    deinit {
        MainActor.assumeIsolated {
            metricsObservation?.cancel()
            settingsObservation?.cancel()
            uptimeTask?.cancel()
        }
    }
}
