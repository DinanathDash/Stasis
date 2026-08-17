import AppKit
import Defaults
import Foundation
import Observation

@MainActor
@Observable
class MenuViewModel {
    private let batteryService: BatteryService
    private let chargeManager: ChargeManager
    let significantEnergyService: SignificantEnergyService
    private let bootTimestamp: Date?

    var significantApps: [SignificantEnergyApp] {
        significantEnergyService.apps
    }

    var batteryPercentageText: String = 0.formattedPercentage
    var powerSourceText: String = String(localized: "Battery")
    var timeRemainingText: String = String(localized: "Calculating...")
    var uptimeText: String = "00:00"
    var batteryModeText: String = String(localized: "Unknown")
    var batteryTemperatureText: String = "0°C"
    var externalInputText: String = "0V @ 0A"
    var internalInputText: String = "0V @ 0A"
    var cycleCountText: String = "0"
    var batteryHealthText: String = 100.formattedPercentage
    var sessionEnergyText: String = "0.00 Wh"
    var shouldShowSessionEnergy: Bool = false

    var displayPercentage: Int = 0
    var chargingMode: ChargingMode = .discharging
    var batteryPower: Double = 0
    var adapterPower: Double = 0
    var systemPower: Double = 0
    var outputPower: Double = 0
    var outputPortPowers: [OutputPortPower] = []
    var outputPortDetailsText: String = String(localized: "None")
    var powerSource: PowerSource = .battery
    var isCharging: Bool = false
    var hasMultiPort: Bool = false
    var connectedAccessories: [AccessoryType] = []
    var outputIcons: [String] = []
    var isLowPowerModeEnabled: Bool = ProcessInfo.processInfo
        .isLowPowerModeEnabled

    var chargeLimitOverrideActive: Bool {
        chargeManager.chargeLimitOverrideActive
    }
    var forceDischargeActive: Bool { chargeManager.forceDischargeActive }
    var chargeToLimitActive: Bool { chargeManager.chargeToLimitActive }
    var daemonSyncError: Bool { chargeManager.daemonSyncError }
    var daemonError: String? { chargeManager.daemonError }
    var manageChargingEnabled: Bool { Defaults[.manageCharging] }
    var adapterConnected: Bool = false

    private var metricsObservation: Task<Void, Never>?
    private var settingsObservation: Task<Void, Never>?
    private var uptimeTask: Task<Void, Never>?
    private var powerModeObservation: Task<Void, Never>?
    private var trendSample: (date: Date, percentage: Int, isCharging: Bool)?
    private var currentTrendMinutes: Int?
    private var stableOutputPorts: [OutputPortPower] = []
    private var outputPortsHoldUntil: Date = .distantPast

    private var lastAdapterConnected: Bool = false
    private var isChargingHoldUntil: Date = .distantPast
    private var stableIsCharging: Bool = false
    private var lastEnergyCalculationTime: Date?
    private var sessionEnergyAccumulatedWh: Double = 0
    private var disconnectTime: Date?

    init(
        batteryService: BatteryService,
        chargeManager: ChargeManager,
        significantEnergyService: SignificantEnergyService
    ) {
        self.batteryService = batteryService
        self.chargeManager = chargeManager
        self.significantEnergyService = significantEnergyService
        self.bootTimestamp = SystemService.bootTimestamp()
        startObservingMetrics()
        startObservingSettings()
        startObservingPowerMode()
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
            for await _ in Defaults.updates(
                [
                    .useHardwarePercentage, .useRawHardwareHealth,
                    .calibrationStatus, .showTwoDecimalPowerValues
                ],
                initial: false
            ) {
                guard let self else { return }
                self.updateFormattedValues(
                    from: self.batteryService.metrics,
                    adapter: self.batteryService.adapterMetrics
                )
            }
        }
    }

    private func startObservingPowerMode() {
        powerModeObservation = Task { [weak self] in
            guard let self else { return }
            for await _ in NotificationCenter.default.notifications(
                named: .NSProcessInfoPowerStateDidChange
            ) {
                self.isLowPowerModeEnabled =
                    ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    func toggleChargeLimitOverride() {
        chargeManager.toggleChargeLimitOverride()
    }

    func toggleForceDischarge() {
        chargeManager.toggleForceDischarge()
    }

    func toggleChargeToLimit() {
        chargeManager.toggleChargeToLimit()
    }

    var isCalibrating: Bool = false

    func toggleCalibration() {
        if Defaults[.calibrationStatus] != .idle {
            Defaults[.calibrationStatus] = .idle
        } else {
            if chargeLimitOverrideActive { toggleChargeLimitOverride() }
            if forceDischargeActive { toggleForceDischarge() }
            if chargeToLimitActive { toggleChargeToLimit() }
            Defaults[.calibrationStatus] = .discharging
        }
    }

    private func updateFormattedValues(
        from metrics: BatteryMetrics,
        adapter: AdapterMetrics
    ) {
        var safeMetrics = metrics
        let now = Date()

        // Rely on SMC battery power instead of IOKit's lagging flag to determine true charging state.
        let physicallyCharging = metrics.batteryPower > 0.05

        let logicallyPluggedIn = safeMetrics.externalConnected

        if logicallyPluggedIn && !lastAdapterConnected {
            isChargingHoldUntil = now.addingTimeInterval(5.0)
            stableIsCharging = true
        } else if physicallyCharging {
            isChargingHoldUntil = now.addingTimeInterval(2.0)
            stableIsCharging = true
        } else if now >= isChargingHoldUntil {
            stableIsCharging = false
        }

        lastAdapterConnected = logicallyPluggedIn
        safeMetrics.isCharging = stableIsCharging

        let useHardware = Defaults[.useHardwarePercentage]
        let percentage =
            useHardware
            ? safeMetrics.hardwareBatteryPercentage
            : safeMetrics.batteryPercentage
        displayPercentage = percentage
        batteryPercentageText = percentage.formattedPercentage

        let derivedPowerSource = derivePowerSource(
            battery: safeMetrics,
            adapter: adapter
        )

        powerSourceText = formatPowerSourceText(
            source: derivedPowerSource,
            adapterCapacityWatts: adapter.adapterCapacityWatts
        )

        timeRemainingText = formatTimeRemaining(
            reportedMinutes: safeMetrics.timeRemaining,
            currentCapacity: safeMetrics.currentCapacity,
            maxCapacity: safeMetrics.maxCapacity,
            batteryCurrent: safeMetrics.batteryCurrent,
            powerSource: derivedPowerSource,
            isCharging: safeMetrics.isCharging,
            adapterConnected: safeMetrics.externalConnected,
            batteryPercentage: percentage
        )

        updateUptimeText()

        let physicallyPluggedIn = adapter.adapterConnected
        
        let calibrationStatus = Defaults[.calibrationStatus]
        
        isCalibrating = (calibrationStatus != .idle)

        if calibrationStatus != .idle {
            switch calibrationStatus {
            case .discharging:
                chargingMode = .discharging
                batteryModeText = String(localized: "Calibrating (Discharging to \(15.formattedPercentage))")
            case .charging:
                if logicallyPluggedIn {
                    chargingMode = .charging
                    batteryModeText = String(localized: "Calibrating (Charging to \(100.formattedPercentage))")
                } else {
                    chargingMode = .discharging
                    batteryModeText = String(localized: "Calibrating (Paused - Plug in)")
                }
            case .resting:
                if logicallyPluggedIn {
                    chargingMode = .pluggedIn
                    batteryModeText = String(localized: "Calibrating (Resting at \(100.formattedPercentage))")
                } else {
                    chargingMode = .discharging
                    batteryModeText = String(localized: "Calibrating (Paused - Plug in)")
                }
            default: break
            }
        } else if logicallyPluggedIn {
            if safeMetrics.isCharging {
                chargingMode = .charging
                if chargeLimitOverrideActive {
                    batteryModeText = String(localized: "Charging to \(100.formattedPercentage) (Override)")
                } else if chargeToLimitActive {
                    batteryModeText = String(localized: "Charging to Limit")
                } else {
                    batteryModeText = String(localized: "Charging")
                }
            } else {
                chargingMode = .pluggedIn
                batteryModeText = String(localized: "Plugged In (Not Charging)")
            }
        } else {
            chargingMode = .discharging
            if physicallyPluggedIn && forceDischargeActive {
                batteryModeText = String(localized: "Force Discharging")
            } else {
                batteryModeText = String(localized: "Discharging")
            }
        }

        batteryTemperatureText =
            "\(safeMetrics.batteryTemperature.formatted(.number.precision(.fractionLength(1))))°C"

        let voltageFormat = FloatingPointFormatStyle<Double>.number.precision(
            .fractionLength(2)
        )
        let currentFormat = FloatingPointFormatStyle<Double>.number.precision(
            .fractionLength(2)
        )
        let powerFormat = FloatingPointFormatStyle<Double>.number.precision(
            .fractionLength(2)
        )

        externalInputText =
            "\(adapter.adapterVoltage.formatted(voltageFormat))V @ \(adapter.adapterCurrent.formatted(currentFormat))A (\(adapter.adapterPower.formatted(powerFormat))W)"

        internalInputText =
            "\(safeMetrics.batteryVoltage.formatted(voltageFormat))V @ \(safeMetrics.batteryCurrent.formatted(currentFormat))A (\(abs(safeMetrics.batteryPower).formatted(powerFormat))W)"
            
        if !physicallyPluggedIn {
            if disconnectTime == nil {
                disconnectTime = now
            }
            if let dTime = disconnectTime, now.timeIntervalSince(dTime) > 120.0 {
                // Buffer time of 2 minutes expired
                sessionEnergyAccumulatedWh = 0
            }
            lastEnergyCalculationTime = nil
        } else {
            disconnectTime = nil
            if let lastTime = lastEnergyCalculationTime {
                let elapsedHours = now.timeIntervalSince(lastTime) / 3600.0
                let power = adapter.adapterPower
                if power > 0 {
                    sessionEnergyAccumulatedWh += power * elapsedHours
                }
            }
            lastEnergyCalculationTime = now
        }
        
        let showTwoDecimalPlaces = Defaults[.showTwoDecimalPowerValues]
        let formattedEnergy = PowerValueFormatter.string(
            from: sessionEnergyAccumulatedWh,
            showTwoDecimalPlaces: showTwoDecimalPlaces
        )
        sessionEnergyText = "\(formattedEnergy) Wh"
        shouldShowSessionEnergy = sessionEnergyAccumulatedWh > 0 || physicallyPluggedIn

        batteryPower = safeMetrics.batteryPower
        adapterPower = adapter.adapterPower
        let totalLoadPower: Double = {
            if adapter.adapterConnected {
                return max(0, adapter.adapterPower - safeMetrics.batteryPower)
            }
            return max(0, -safeMetrics.batteryPower)
        }()
        let preferredOutputPower = max(0, safeMetrics.outputPower)
        let rawOutputPower = preferredOutputPower

        if safeMetrics.outputPorts.isEmpty, now < outputPortsHoldUntil,
            !stableOutputPorts.isEmpty
        {
            outputPortPowers = stableOutputPorts
        } else {
            outputPortPowers = metrics.outputPorts
            if !outputPortPowers.isEmpty {
                stableOutputPorts = outputPortPowers
                outputPortsHoldUntil = now.addingTimeInterval(2.5)
            }
        }

        let portsOutputPower = outputPortPowers.reduce(0) { $0 + $1.powerWatts }
        outputPower = min(
            totalLoadPower,
            max(portsOutputPower, min(totalLoadPower, rawOutputPower))
        )
        systemPower = max(0, totalLoadPower - outputPower)

        if outputPortPowers.isEmpty {
            outputPortDetailsText = String(localized: "None")
        } else {
            let showTwoDecimalPlaces = Defaults[.showTwoDecimalPowerValues]
            outputPortDetailsText =
                outputPortPowers
                .map {
                    let power = PowerValueFormatter.string(
                        from: $0.powerWatts,
                        showTwoDecimalPlaces: showTwoDecimalPlaces
                    )
                    return String(
                        localized:
                            "Port \($0.portIndex): \(power) W"
                    )
                }
                .joined(separator: " • ")
        }
        
        // Smart map accessories to output ports based on power
        var availableAccessories = safeMetrics.connectedAccessories
        
        // Priority for matching
        let accessoryPriority: [AccessoryType] = [.hub, .display, .phone, .network, .storage, .printer, .unknown]
        availableAccessories.sort { a, b in
            let idxA = accessoryPriority.firstIndex(of: a) ?? 100
            let idxB = accessoryPriority.firstIndex(of: b) ?? 100
            return idxA < idxB
        }
        
        let sortedPorts = outputPortPowers.sorted { $0.powerWatts > $1.powerWatts }
        var portIconMap: [Int: String] = [:]
        
        for port in sortedPorts {
            let p = port.powerWatts
            var selectedIcon = "cable.connector" // Generic fallback
            
            if p > 15.0 {
                selectedIcon = "externaldrive.fill"
            } else {
                selectedIcon = "iphone" // default medium
            }
            
            if !availableAccessories.isEmpty {
                let acc = availableAccessories.removeFirst()
                switch acc {
                case .display: selectedIcon = "display"
                case .phone: selectedIcon = "iphone"
                case .storage: selectedIcon = "externaldrive.fill"
                case .network: selectedIcon = "network"
                case .printer: selectedIcon = "printer.fill"
                case .hub: selectedIcon = "HubIcon"
                case .unknown: selectedIcon = "cable.connector"
                }
            }
            portIconMap[port.portIndex] = selectedIcon
        }
        
        outputIcons = outputPortPowers.map { portIconMap[$0.portIndex] ?? "cable.connector" }
        
        hasMultiPort = safeMetrics.hasMultiPort
        connectedAccessories = safeMetrics.connectedAccessories
        powerSource = derivedPowerSource
        isCharging = metrics.isCharging
        adapterConnected = adapter.adapterConnected

        cycleCountText = "\(metrics.cycleCount)"

        let healthToShow: Int = {
            if Defaults[.useRawHardwareHealth] {
                return metrics.rawBatteryHealth
            }
            if let calibrated = metrics.calibratedBatteryHealth {
                return calibrated
            }
            return metrics.rawBatteryHealth
        }()

        batteryHealthText = healthToShow.formattedPercentage
    }

    private func derivePowerSource(
        battery: BatteryMetrics,
        adapter: AdapterMetrics
    ) -> PowerSource {
        guard battery.externalConnected else { return .battery }

        if battery.batteryPower >= 0 {
            return .acAdapter
        } else {
            return .both
        }
    }

    private func updateUptimeText() {
        guard let bootTimestamp else {
            uptimeText = String(localized: "Unknown")
            return
        }

        let uptime = max(0, Int(Date().timeIntervalSince(bootTimestamp)))
        let days = uptime / 86_400
        let hours = (uptime % 86_400) / 3_600
        let minutes = (uptime % 3_600) / 60

        if days > 0 {
            uptimeText = String(localized: "\(days)d \(hours)h \(minutes)m")
        } else if hours > 0 {
            uptimeText = String(localized: "\(hours)h \(minutes)m")
        } else {
            uptimeText = String(localized: "\(minutes)m")
        }
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
        significantEnergyService.startOpenMenuPolling()
    }

    func menuDidClose() {
        stopUptimeTimer()
        batteryService.disableFastPolling()
        significantEnergyService.stopOpenMenuPolling()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func formatTimeRemaining(
        minutes: Int,
        powerSource: PowerSource,
        isCharging: Bool
    ) -> String {
        formatTimeRemaining(
            reportedMinutes: minutes,
            currentCapacity: 0,
            maxCapacity: 0,
            batteryCurrent: 0,
            powerSource: powerSource,
            isCharging: isCharging,
            adapterConnected: powerSource != .battery,
            batteryPercentage: displayPercentage
        )
    }

    private func formatTimeRemaining(
        reportedMinutes: Int,
        currentCapacity: Int,
        maxCapacity: Int,
        batteryCurrent: Double,
        powerSource: PowerSource,
        isCharging: Bool,
        adapterConnected: Bool,
        batteryPercentage: Int
    ) -> String {
        if adapterConnected {
            return String(localized: "N/A")
        }

        let adjustedReportedMinutes = adjustedReportedMinutesToTarget(
            reportedMinutes: reportedMinutes,
            isCharging: isCharging,
            batteryPercentage: batteryPercentage
        )

        let capacityMinutes = estimateMinutesFromCapacity(
            currentCapacity: currentCapacity,
            maxCapacity: maxCapacity,
            batteryCurrent: batteryCurrent,
            isCharging: isCharging,
            batteryPercentage: batteryPercentage
        )

        let trendMinutes = estimateMinutesFromTrend(
            batteryPercentage: batteryPercentage,
            isCharging: isCharging,
            adapterConnected: adapterConnected
        )

        let effectiveMinutes =
            adjustedReportedMinutes >= 0
            ? adjustedReportedMinutes : (capacityMinutes ?? trendMinutes)
        guard let effectiveMinutes, effectiveMinutes >= 0 else {
            return String(localized: "Calculating...")
        }

        let hours = effectiveMinutes / 60
        let mins = effectiveMinutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }

    private func adjustedReportedMinutesToTarget(
        reportedMinutes: Int,
        isCharging: Bool,
        batteryPercentage: Int
    ) -> Int {
        guard reportedMinutes >= 0 else { return -1 }
        guard isCharging else { return reportedMinutes }

        let targetPercentage = chargingTargetPercentage
        if batteryPercentage >= targetPercentage {
            return 0
        }

        if targetPercentage >= 100 || batteryPercentage >= 100 {
            return reportedMinutes
        }

        let remainingToTarget = max(0, targetPercentage - batteryPercentage)
        let remainingToFull = max(1, 100 - batteryPercentage)
        let scaled =
            Double(reportedMinutes) * Double(remainingToTarget)
            / Double(remainingToFull)
        return Int(ceil(scaled))
    }

    private var chargingTargetPercentage: Int {
        if Defaults[.manageCharging] && !chargeLimitOverrideActive {
            return Defaults[.chargeLimit]
        }
        return 100
    }

    private func estimateMinutesFromCapacity(
        currentCapacity: Int,
        maxCapacity: Int,
        batteryCurrent: Double,
        isCharging: Bool,
        batteryPercentage: Int
    ) -> Int? {
        guard currentCapacity > 0, maxCapacity > 0 else { return nil }

        let targetPercentage = chargingTargetPercentage
        let targetCapacity = Int(
            Double(maxCapacity) * Double(targetPercentage) / 100.0
        )

        if isCharging {
            guard batteryCurrent > 0.05 else { return nil }
            let remainingCapacity = targetCapacity - currentCapacity
            if remainingCapacity <= 0 { return 0 }

            // batteryCurrent is in Amps (e.g. 1.5). Capacity is in mAh (e.g. 4000).
            // Convert Amps to mA
            let chargeRate_mA = batteryCurrent * 1000.0
            let hours = Double(remainingCapacity) / chargeRate_mA
            return Int(ceil(hours * 60))
        } else {
            guard batteryCurrent < -0.05 else { return nil }
            // Discharge
            // Time to empty
            let dischargeRate_mA = abs(batteryCurrent * 1000.0)
            let hours = Double(currentCapacity) / dischargeRate_mA
            return Int(hours * 60)
        }
    }

    private func estimateMinutesFromTrend(
        batteryPercentage: Int,
        isCharging: Bool,
        adapterConnected: Bool
    ) -> Int? {
        let now = Date()

        guard !(adapterConnected && !isCharging) else {
            trendSample = nil
            currentTrendMinutes = nil
            return nil
        }

        guard let previous = trendSample else {
            trendSample = (
                date: now, percentage: batteryPercentage, isCharging: isCharging
            )
            currentTrendMinutes = nil
            return nil
        }

        if previous.isCharging != isCharging {
            trendSample = (
                date: now, percentage: batteryPercentage, isCharging: isCharging
            )
            currentTrendMinutes = nil
            return nil
        }

        let deltaPercent = abs(batteryPercentage - previous.percentage)
        if deltaPercent > 0 {
            let elapsedMinutes = now.timeIntervalSince(previous.date) / 60
            if elapsedMinutes >= 0.5 || deltaPercent >= 1 {
                let percentPerMinute = Double(deltaPercent) / elapsedMinutes
                if percentPerMinute > 0 {
                    let remainingPercent: Int = {
                        if isCharging {
                            return max(
                                0,
                                chargingTargetPercentage - batteryPercentage
                            )
                        }
                        return max(0, batteryPercentage)
                    }()

                    if remainingPercent == 0 {
                        currentTrendMinutes = 0
                    } else {
                        currentTrendMinutes = Int(
                            ceil(Double(remainingPercent) / percentPerMinute)
                        )
                    }
                }
            }
            trendSample = (
                date: now, percentage: batteryPercentage, isCharging: isCharging
            )
        }

        return currentTrendMinutes
    }

    private func formatPowerSourceText(
        source: PowerSource,
        adapterCapacityWatts: Int
    ) -> String {
        let hasCapacity = adapterCapacityWatts > 0
        switch source {
        case .battery:
            return String(localized: "Battery")
        case .acAdapter:
            return hasCapacity
                ? String(localized: "Power Adapter (\(adapterCapacityWatts) W)")
                : String(localized: "Power Adapter")
        case .both:
            return hasCapacity
                ? String(localized: "Battery & Power Adapter (\(adapterCapacityWatts) W)")
                : String(localized: "Battery & Power Adapter")
        }
    }

    deinit {
        MainActor.assumeIsolated {
            metricsObservation?.cancel()
            settingsObservation?.cancel()
            uptimeTask?.cancel()
            powerModeObservation?.cancel()
        }
    }
}
