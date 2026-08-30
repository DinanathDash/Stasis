import Foundation
import Observation
import os.log
import smc_power

enum XPCError: LocalizedError {
    case helperUnavailable
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .helperUnavailable:
            "XPC helper is unavailable"
        case .commandFailed(let message):
            "Command failed: \(message)"
        }
    }
}

@MainActor
@Observable
class BatteryService {
    private enum ChargingTransitionCandidate {
        case charging
        case notCharging
    }

    var metrics = BatteryMetrics()
    var adapterMetrics = AdapterMetrics()
    private(set) var controlState = BatteryControlState()
    private(set) var deviceCapabilities = DeviceCapabilities(
        chargingControl: false,
        adapterControl: false,
        hasMagSafe: false,
        magsafeLEDControl: false
    )

    private let xpcManager = SMCReaderConnection(
        serviceName: "com.dinanathdash.stasis.helper"
    )
    private let ioKitService = IOKitService()

    private var ioKitMonitorTask: Task<Void, Never>?
    private var smcPollTask: Task<Void, Never>?
    private var backgroundPollTask: Task<Void, Never>?
    private var delayedPollTask: Task<Void, Never>?
    private var chargingTransitionCandidate: ChargingTransitionCandidate?
    private var chargingTransitionCandidateCount: Int = 0

    private let chargingPowerEpsilonWatts: Double = 0.8
    private let transitionConfirmationSamples: Int = 2

    private let logger = Logger(
        subsystem: "com.dinanathdash.stasis",
        category: "BatteryService"
    )

    init() {
        logger.info("BatteryService initialized")
        xpcManager.connect()
        // Start monitoring right away
        startIOKitMonitoring()
        startBackgroundPolling()
    }

    func loadCapabilities() async {
        let logger = self.logger
        let capabilities: DeviceCapabilities = await withCheckedContinuation { continuation in
            guard let helper = xpcManager.getHelper(errorHandler: { error in
                logger.error("XPC error loading capabilities: \(error.localizedDescription)")
                continuation.resume(
                    returning: DeviceCapabilities(
                        chargingControl: false,
                        adapterControl: false,
                        hasMagSafe: false,
                        magsafeLEDControl: false
                    )
                )
            }) else {
                logger.warning("Helper unavailable for capability probe")
                continuation.resume(
                    returning: DeviceCapabilities(
                        chargingControl: false,
                        adapterControl: false,
                        hasMagSafe: false,
                        magsafeLEDControl: false
                    )
                )
                return
            }

            helper.getCapabilities { chargingControl, adapterControl, hasMagSafe, magsafeLEDControl in
                continuation.resume(
                    returning: DeviceCapabilities(
                        chargingControl: chargingControl,
                        adapterControl: adapterControl,
                        hasMagSafe: hasMagSafe,
                        magsafeLEDControl: magsafeLEDControl
                    )
                )
            }
        }

        self.deviceCapabilities = capabilities
        logger.info(
            "Capabilities loaded: charging=\(capabilities.chargingControl), adapter=\(capabilities.adapterControl), magSafe=\(capabilities.hasMagSafe)"
        )
    }

    private func startIOKitMonitoring() {
        logger.info("Starting IOKit monitoring in main app")
        ioKitMonitorTask = Task {
            for await (newBatteryMetrics, newAdapterMetrics) in self.ioKitService.metricsStream() {
                guard !Task.isCancelled else { break }
                self.handleIOKitUpdate(newBatteryMetrics, adapterUpdate: newAdapterMetrics)
            }
        }
    }

    private func startBackgroundPolling() {
        backgroundPollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                if self.smcPollTask == nil {
                    await self.pollSMCOnce()
                }
            }
        }
    }

    func enableFastPolling() {
        guard smcPollTask == nil else {
            logger.warning("Fast polling already enabled")
            return
        }

        logger.info("Enabling fast SMC polling")

        smcPollTask = Task {
            await self.pollSMCOnce()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await self.pollSMCOnce()
            }
        }
    }

    func scheduleSinglePoll(delay: Duration = .seconds(3)) {
        delayedPollTask?.cancel()
        delayedPollTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self.pollSMCOnce()
        }
    }

    func disableFastPolling() {
        guard smcPollTask != nil else {
            logger.warning("Fast polling not enabled")
            return
        }

        logger.info("Disabling fast SMC polling")
        smcPollTask?.cancel()
        smcPollTask = nil
    }

    private func fetchSMCBatteryData() async -> SMCBatteryReading? {
        let logger = self.logger
        return await withCheckedContinuation { continuation in
            guard let helper = xpcManager.getHelper(errorHandler: { error in
                logger.error("XPC error during SMC battery poll: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }) else {
                continuation.resume(returning: nil)
                return
            }

            helper.readBatteryMetrics { batteryVoltage, batteryCurrent, batteryPower, errorMsg in
                if let errorMsg = errorMsg {
                    self.logger.error("SMC battery read failed in helper: \(errorMsg)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(
                        returning: SMCBatteryReading(
                            batteryVoltage: batteryVoltage,
                            batteryCurrent: batteryCurrent,
                            batteryPower: batteryPower
                        )
                    )
                }
            }
        }
    }

    private func fetchSMCAdapterData() async -> SMCAdapterReading? {
        let logger = self.logger
        return await withCheckedContinuation { continuation in
            guard let helper = xpcManager.getHelper(errorHandler: { error in
                logger.error("XPC error during SMC adapter poll: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }) else {
                continuation.resume(returning: nil)
                return
            }

            helper.readAdapterMetrics { adapterVoltage, adapterCurrent, adapterPower, errorMsg in
                if let errorMsg = errorMsg {
                    self.logger.error("SMC adapter read failed in helper: \(errorMsg)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(
                        returning: SMCAdapterReading(
                            adapterVoltage: adapterVoltage,
                            adapterCurrent: adapterCurrent,
                            adapterPower: adapterPower
                        )
                    )
                }
            }
        }
    }

    private func pollSMCOnce() async {
        async let batteryData = fetchSMCBatteryData()
        async let adapterData = fetchSMCAdapterData()

        guard let batteryReading = await batteryData, let adapterReading = await adapterData else {
            logger.error("No helper available for SMC battery polling")
            return
        }

        var updatedBattery = metrics
        updatedBattery.batteryVoltage = batteryReading.batteryVoltage
        updatedBattery.batteryCurrent = batteryReading.batteryCurrent
        updatedBattery.batteryPower = batteryReading.batteryPower

        var updatedAdapter = adapterMetrics
        updatedAdapter.adapterVoltage = adapterReading.adapterVoltage
        updatedAdapter.adapterCurrent = adapterReading.adapterCurrent
        updatedAdapter.adapterPower = adapterReading.adapterPower

        // SMC reports faster than IOKit can update. Refine isCharging
        // with hysteresis around 0W to avoid near-zero state flapping.
        if updatedAdapter.adapterConnected {
            updatedBattery.isCharging = stabilizedChargingState(
                current: updatedBattery.isCharging,
                batteryPower: batteryReading.batteryPower
            )
        } else {
            chargingTransitionCandidate = nil
            chargingTransitionCandidateCount = 0
        }

        if updatedBattery != metrics {
            metrics = updatedBattery
        }
        if updatedAdapter != adapterMetrics {
            adapterMetrics = updatedAdapter
        }
        updateControlState(from: updatedBattery, adapter: updatedAdapter)
    }

    private func handleIOKitUpdate(_ newBatteryMetrics: BatteryMetrics, adapterUpdate: AdapterMetrics) {
        logger.debug("Received IOKit update")

        var updatedBattery = newBatteryMetrics
        updatedBattery.batteryVoltage = metrics.batteryVoltage
        updatedBattery.batteryCurrent = metrics.batteryCurrent
        updatedBattery.batteryPower = metrics.batteryPower

        if !adapterUpdate.adapterConnected {
            chargingTransitionCandidate = nil
            chargingTransitionCandidateCount = 0
        }

        if updatedBattery != metrics {
            metrics = updatedBattery
        }

        var updatedAdapter = adapterUpdate
        updatedAdapter.adapterVoltage = adapterMetrics.adapterVoltage
        updatedAdapter.adapterCurrent = adapterMetrics.adapterCurrent
        updatedAdapter.adapterPower = adapterMetrics.adapterPower

        if updatedAdapter != adapterMetrics {
            adapterMetrics = updatedAdapter
        }

        updateControlState(from: updatedBattery, adapter: updatedAdapter)
    }

    private func stabilizedChargingState(current: Bool, batteryPower: Double) -> Bool {
        if batteryPower > chargingPowerEpsilonWatts {
            return confirmChargingTransition(to: .charging, fallback: current)
        }

        if batteryPower < -chargingPowerEpsilonWatts {
            return confirmChargingTransition(to: .notCharging, fallback: current)
        }

        chargingTransitionCandidate = nil
        chargingTransitionCandidateCount = 0
        return current
    }

    private func confirmChargingTransition(
        to candidate: ChargingTransitionCandidate,
        fallback current: Bool
    ) -> Bool {
        if chargingTransitionCandidate == candidate {
            chargingTransitionCandidateCount += 1
        } else {
            chargingTransitionCandidate = candidate
            chargingTransitionCandidateCount = 1
        }

        guard chargingTransitionCandidateCount >= transitionConfirmationSamples else {
            return current
        }

        chargingTransitionCandidate = nil
        chargingTransitionCandidateCount = 0
        return candidate == .charging
    }

    private func updateControlState(from metrics: BatteryMetrics, adapter: AdapterMetrics) {
        let newState = BatteryControlState(
            batteryPercentage: metrics.batteryPercentage,
            hardwareBatteryPercentage: metrics.hardwareBatteryPercentage,
            adapterConnected: adapter.adapterConnected,
            batteryTemperature: metrics.batteryTemperature
        )
        if newState != controlState {
            controlState = newState
        }
    }

    func setSettings(settings: [String: NSObject & Sendable]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let helper = ChargingHelperManager.shared.getHelper(errorHandler: { error in
                continuation.resume(throwing: XPCError.commandFailed(error.localizedDescription))
            }) else {
                continuation.resume(throwing: XPCError.helperUnavailable)
                return
            }

            helper.setSettings(settings: settings) { success, errorMessage in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: XPCError.commandFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func chargeToLimit() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let helper = ChargingHelperManager.shared.getHelper(errorHandler: { error in
                continuation.resume(throwing: XPCError.commandFailed(error.localizedDescription))
            }) else {
                continuation.resume(throwing: XPCError.helperUnavailable)
                return
            }

            helper.chargeToLimit { success, errorMessage in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: XPCError.commandFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func chargeToFull() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let helper = ChargingHelperManager.shared.getHelper(errorHandler: { error in
                continuation.resume(throwing: XPCError.commandFailed(error.localizedDescription))
            }) else {
                continuation.resume(throwing: XPCError.helperUnavailable)
                return
            }

            helper.chargeToFull { success, errorMessage in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: XPCError.commandFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func disableCharging() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let helper = ChargingHelperManager.shared.getHelper(errorHandler: { error in
                continuation.resume(throwing: XPCError.commandFailed(error.localizedDescription))
            }) else {
                continuation.resume(throwing: XPCError.helperUnavailable)
                return
            }

            helper.disableCharging { success, errorMessage in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: XPCError.commandFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func cancelOverride() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let helper = ChargingHelperManager.shared.getHelper(errorHandler: { error in
                continuation.resume(throwing: XPCError.commandFailed(error.localizedDescription))
            }) else {
                continuation.resume(throwing: XPCError.helperUnavailable)
                return
            }

            helper.cancelOverride { success, errorMessage in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: XPCError.commandFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func disablePowerAdapter() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let helper = ChargingHelperManager.shared.getHelper(errorHandler: { error in
                continuation.resume(throwing: XPCError.commandFailed(error.localizedDescription))
            }) else {
                continuation.resume(throwing: XPCError.helperUnavailable)
                return
            }

            helper.disablePowerAdapter { success, errorMessage in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: XPCError.commandFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func enablePowerAdapter() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let helper = ChargingHelperManager.shared.getHelper(errorHandler: { error in
                continuation.resume(throwing: XPCError.commandFailed(error.localizedDescription))
            }) else {
                continuation.resume(throwing: XPCError.helperUnavailable)
                return
            }

            helper.enablePowerAdapter { success, errorMessage in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: XPCError.commandFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func manageMagsafeLED(target: MagSafeLEDState) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let helper = ChargingHelperManager.shared.getHelper(errorHandler: { error in
                continuation.resume(throwing: XPCError.commandFailed(error.localizedDescription))
            }) else {
                continuation.resume(throwing: XPCError.helperUnavailable)
                return
            }

            helper.manageMagsafeLED(target: target.rawValue) { success, errorMessage in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: XPCError.commandFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func stop() {
        logger.info("BatteryService stopping")
        ioKitMonitorTask?.cancel()
        ioKitMonitorTask = nil
        smcPollTask?.cancel()
        smcPollTask = nil
        delayedPollTask?.cancel()
        delayedPollTask = nil
        xpcManager.disconnect()
    }
}
