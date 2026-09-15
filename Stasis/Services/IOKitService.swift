import Defaults
import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import os.log

@MainActor
class IOKitService {
    private var notificationPort: IONotificationPortRef?
    private var interestNotification: io_object_t = 0
    private var batteryService: io_service_t = 0

    private var continuation:
        AsyncStream<(BatteryMetrics, AdapterMetrics)>.Continuation?
    private var refreshTask: Task<Void, Never>?

    private let logger = Logger(
        subsystem: "com.dinanathdash.stasis",
        category: "IOKitService"
    )

    private var calibratedHealthCache: Int?
    private var lastCalibratedFetch: Date = .distantPast

    func metricsStream() -> AsyncStream<(BatteryMetrics, AdapterMetrics)> {
        AsyncStream { continuation in
            self.continuation = continuation

            continuation.onTermination = { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.stop()
                }
            }

            self.startNotifications()
        }
    }

    private func startNotifications() {
        logger.info("Starting IOKit monitoring")

        batteryService = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        if batteryService == 0 {
            logger.error("Failed to get AppleSmartBattery service")
        }

        guard batteryService != 0 else { return }

        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notificationPort else {
            logger.error("Failed to create IONotificationPort")
            return
        }

        let notificationSource = IONotificationPortGetRunLoopSource(
            notificationPort
        ).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), notificationSource, .commonModes)

        let context = UnsafeMutableRawPointer(
            Unmanaged.passUnretained(self).toOpaque()
        )

        let callback: IOServiceInterestCallback = { refcon, _, _, _ in
            guard let refcon else { return }
            let monitor = Unmanaged<IOKitService>.fromOpaque(refcon)
                .takeUnretainedValue()
            MainActor.assumeIsolated {
                monitor.emitMetrics()
            }
        }

        let result = IOServiceAddInterestNotification(
            notificationPort,
            batteryService,
            kIOGeneralInterest,
            callback,
            context,
            &interestNotification
        )

        if result == KERN_SUCCESS {
            logger.info(
                "IORegistry interest notification registered for AppleSmartBattery"
            )
        } else {
            logger.error("Failed to register interest notification: \(result)")
        }

        emitMetrics()
        startRefreshLoop()
    }

    private func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        if interestNotification != 0 {
            IOObjectRelease(interestNotification)
            interestNotification = 0
        }
        if let notificationPort {
            let source = IONotificationPortGetRunLoopSource(notificationPort)
                .takeUnretainedValue()
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
        }
        if batteryService != 0 {
            IOObjectRelease(batteryService)
            batteryService = 0
        }
        continuation = nil
    }

    private func emitMetrics() {
        logger.debug("IOKit notification triggered")
        fetchCalibratedHealthIfNeeded()

        let powerInfo = getPowerSourceInfo() as? [String: Any]
        var batteryMetrics = BatteryMetrics()
        var adapterMetrics = AdapterMetrics()

        let percentages = getBatteryPercentages(powerInfo: powerInfo)
        batteryMetrics.batteryPercentage = percentages.displayed
        batteryMetrics.hardwareBatteryPercentage = percentages.hardware

        batteryMetrics.isCharging =
            powerInfo?[kIOPSIsChargingKey] as? Bool ?? false
        if batteryMetrics.isCharging {
            batteryMetrics.timeRemaining =
                getTimeToFull(powerInfo: powerInfo) ?? -1
        } else {
            batteryMetrics.timeRemaining =
                getTimeRemaining(powerInfo: powerInfo) ?? -1
        }

        var properties = [String: Any]()
        var propertiesCF: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(batteryService, &propertiesCF, kCFAllocatorDefault, 0) == kIOReturnSuccess,
           let dict = propertiesCF?.takeRetainedValue() as? [String: Any] {
            properties = dict
        }

        let capacities = BatteryReading.capacities(from: properties)
        batteryMetrics.currentCapacity = capacities.current ?? 0
        batteryMetrics.maxCapacity = capacities.maximum ?? 0
        batteryMetrics.rawBatteryHealth = BatteryReading.estimatedHealth(from: properties) ?? 100
        // Calibrated health (cached from system_profiler)
        batteryMetrics.calibratedBatteryHealth = calibratedHealthCache

        batteryMetrics.externalConnected =
            getPropertyValue(batteryService, key: "ExternalConnected") ?? false
        batteryMetrics.systemInputPower = getSystemInputPowerWatts()
        batteryMetrics.outputPorts = getOutputPortPowers()
        batteryMetrics.outputPower = batteryMetrics.outputPorts.reduce(0) {
            $0 + $1.powerWatts
        }
        let accessories = getConnectedUSBAccessories()
        batteryMetrics.connectedAccessories = accessories
        batteryMetrics.hasMultiPort = accessories.contains(.hub)

        let adapterRatedWatts = getAdapterRatedWatts()
        adapterMetrics.adapterCapacityWatts = adapterRatedWatts ?? 0
        adapterMetrics.adapterConnected = (adapterRatedWatts ?? 0) > 0

        if let temp = getBatteryTemperature(powerInfo: powerInfo) {
            batteryMetrics.batteryTemperature = temp
        }

        batteryMetrics.cycleCount =
            getPropertyValue(batteryService, key: "CycleCount") ?? 0

        logger.debug(
            "IOKit metrics: battery=\(batteryMetrics.batteryPercentage)%, hardwareBattery=\(batteryMetrics.hardwareBatteryPercentage)%, rawHealth=\(batteryMetrics.rawBatteryHealth)%, calibratedHealth=\(batteryMetrics.calibratedBatteryHealth.map(String.init) ?? "nil")%, charging=\(batteryMetrics.isCharging), temp=\(batteryMetrics.batteryTemperature)°C, cycles=\(batteryMetrics.cycleCount), timeRemaining=\(batteryMetrics.timeRemaining), externalConnected=\(batteryMetrics.externalConnected), adapterConnected=\(adapterMetrics.adapterConnected)"
        )

        continuation?.yield((batteryMetrics, adapterMetrics))
    }

    private nonisolated func getPowerSourceInfo() -> CFDictionary? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources =
            IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        guard let source = sources.first else { return nil }
        return IOPSGetPowerSourceDescription(snapshot, source)
            .takeUnretainedValue()
    }

    private nonisolated func getPropertyValue<T>(
        _ service: io_service_t,
        key: String
    ) -> T? {
        guard
            let prop = IORegistryEntryCreateCFProperty(
                service,
                key as CFString,
                kCFAllocatorDefault,
                0
            )
        else {
            return nil
        }
        return prop.takeRetainedValue() as? T
    }

    private func getBatteryPercentages(powerInfo: [String: Any]?) -> (
        displayed: Int, hardware: Int
    ) {
        let displayedPercent = powerInfo?[kIOPSCurrentCapacityKey] as? Int ?? 0

        let rawCurrentCapacity: Int =
            getPropertyValue(batteryService, key: "AppleRawCurrentCapacity")
                ?? 0
        let rawMaxCapacity: Int =
            getPropertyValue(batteryService, key: "AppleRawMaxCapacity") ?? 0

        let hardwarePercent: Int
        if rawMaxCapacity > 0 {
            hardwarePercent = (rawCurrentCapacity * 100) / rawMaxCapacity
        } else {
            let currentCapacity: Int =
                getPropertyValue(batteryService, key: "CurrentCapacity")
                    ?? displayedPercent
            hardwarePercent = currentCapacity
        }

        return (displayedPercent, hardwarePercent)
    }

    private func fetchCalibratedHealthIfNeeded() {
        // Run only once per hour or on first start
        let oneHourAgo = Date().addingTimeInterval(-3600)
        guard calibratedHealthCache == nil || lastCalibratedFetch < oneHourAgo
        else { return }

        Task.detached { [weak self] in
            guard let self = self else { return }

            // Run `system_profiler SPPowerDataType`
            let proc = Process()
            proc.executableURL = URL(
                fileURLWithPath: "/usr/sbin/system_profiler"
            )
            proc.arguments = ["SPPowerDataType"]
            let outPipe = Pipe()
            proc.standardOutput = outPipe

            do {
                try proc.run()
            } catch {
                // If the command cannot run, just keep the old cache.
                return
            }

            // Read output (small; OK to read to end)
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()

            guard let output = String(data: data, encoding: .utf8) else {
                return
            }

            // Look for:  Maximum Capacity: 92%
            let regex = try? NSRegularExpression(
                pattern: #"Maximum Capacity:\s+(\d+)%"#,
                options: .caseInsensitive
            )
            if let match = regex?.firstMatch(
                in: output,
                options: [],
                range: NSRange(output.startIndex..., in: output)
            ),
                let range = Range(match.range(at: 1), in: output),
                let percent = Int(output[range])
            {
                // Update cache on the main actor (UI‑safe)
                Task { @MainActor in
                    self.calibratedHealthCache = percent
                    self.lastCalibratedFetch = Date()
                }
            }
        }
    }

    private func getTimeRemaining(powerInfo: [String: Any]?) -> Int? {
        guard let timeToEmpty = powerInfo?[kIOPSTimeToEmptyKey] as? Int,
              timeToEmpty > 0,
              timeToEmpty != Int(kIOPSTimeRemainingUnknown)
        else {
            return nil
        }

        return timeToEmpty
    }

    private func getTimeToFull(powerInfo: [String: Any]?) -> Int? {
        guard let timeToFull = powerInfo?[kIOPSTimeToFullChargeKey] as? Int,
              timeToFull > 0,
              timeToFull != Int(kIOPSTimeRemainingUnknown)
        else {
            return nil
        }

        return timeToFull
    }

    private func getAdapterRatedWatts() -> Int? {
        guard
            let adapterDetails: [String: Any] = getPropertyValue(
                batteryService,
                key: "AdapterDetails"
            ),
            let watts = adapterDetails["Watts"] as? Int,
            watts > 0
        else {
            return nil
        }
        return watts
    }

    private func getBatteryTemperature(powerInfo: [String: Any]?) -> Double? {
        if let powerInfo,
           let temp = powerInfo[kIOPSTemperatureKey] as? Int,
           temp > 0
        {
            return decikelvinToCelsius(temp)
        }

        guard
            let temp: Int = getPropertyValue(
                batteryService,
                key: "Temperature"
            ),
            temp > 0, temp <= 5000
        else {
            return nil
        }

        return decikelvinToCelsius(temp)
    }

    private nonisolated func decikelvinToCelsius(_ decikelvin: Int) -> Double? {
        let celsius = (Double(decikelvin) / 10.0) - 273.15
        return (0 ... 80).contains(celsius) ? celsius : nil
    }

    private func getBatteryCapacities() -> (current: Int, max: Int, design: Int) {
        let currentCapacity: Int =
            getPropertyValue(batteryService, key: "AppleRawCurrentCapacity")
                ?? 0
        let maxCapacity: Int =
            getPropertyValue(batteryService, key: "AppleRawMaxCapacity") ?? 0
        let designCapacity: Int =
            getPropertyValue(batteryService, key: "DesignCapacity") ?? 0

        return (currentCapacity, maxCapacity, designCapacity)
    }

    private func getSystemInputPowerWatts() -> Double {
        guard
            let telemetry: [String: Any] = getPropertyValue(
                batteryService,
                key: "PowerTelemetryData"
            )
        else {
            return 0
        }

        if let systemPowerMilliwatts = telemetry["SystemPowerIn"] as? NSNumber {
            return max(0, systemPowerMilliwatts.doubleValue / 1000.0)
        }

        if let systemLoadMilliwatts = telemetry["SystemLoad"] as? NSNumber {
            return max(0, systemLoadMilliwatts.doubleValue / 1000.0)
        }

        return 0
    }

    private func getOutputPowerWatts() -> Double {
        getOutputPortPowers().reduce(0) { $0 + $1.powerWatts }
    }

    private func getOutputPortPowers() -> [OutputPortPower] {
        guard
            let powerOutDetails: [[String: Any]] = getPropertyValue(
                batteryService,
                key: "PowerOutDetails"
            )
        else {
            return []
        }

        return powerOutDetails.compactMap { detail in
            guard let portIndex = (detail["PortIndex"] as? NSNumber)?.intValue
            else {
                return nil
            }

            let milliwatts: Double
            if let wattsMilliwatts = detail["Watts"] as? NSNumber {
                milliwatts = wattsMilliwatts.doubleValue
            } else if let currentMilliamps = detail["Current"] as? NSNumber,
                      let voltageMillivolts = detail["AdapterVoltage"] as? NSNumber
            {
                milliwatts =
                    currentMilliamps.doubleValue * voltageMillivolts.doubleValue
                        / 1000.0
            } else {
                milliwatts = 0
            }

            let watts = max(0, milliwatts / 1000.0)
            guard watts >= 2.0 else { return nil }
            return OutputPortPower(portIndex: portIndex, powerWatts: watts)
        }
        .sorted { $0.portIndex < $1.portIndex }
    }

    private func startRefreshLoop() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.emitMetrics()
                }
            }
        }
    }

    private func getConnectedUSBAccessories() -> [AccessoryType] {
        var iterator: io_iterator_t = 0
        let matchingDict = IOServiceMatching("IOUSBHostDevice")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)

        var portGroups: [UInt32: [AccessoryType]] = [:]

        if result == kIOReturnSuccess {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                if let name = IORegistryEntryCreateCFProperty(service, "USB Product Name" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
                    let lower = name.lowercased()
                    // Exclude internal Apple devices like Trackpad, Keyboard, Camera, Headset, Touch Bar
                    if !lower.contains("trackpad"), !lower.contains("keyboard"), !lower.contains("camera"), !lower.contains("headset"), !lower.contains("touch bar"), !lower.contains("bcm20702"), !lower.contains("bluetooth"), !lower.contains("ambient light"), !lower.contains("apple internal") {
                        var type: AccessoryType = .unknown
                        if lower.contains("iphone") || lower.contains("ipad") || lower.contains("ipod") || lower.contains("pixel") || lower.contains("galaxy") || lower.contains("phone") {
                            type = .phone
                        } else if lower.contains("disk") || lower.contains("drive") || lower.contains("storage") || lower.contains("sandisk") || lower.contains("flash") {
                            type = .storage
                        } else if lower.contains("lan") || lower.contains("ethernet") || lower.contains("network") {
                            type = .network
                        } else if lower.contains("print") {
                            type = .printer
                        } else if lower.contains("display") || lower.contains("monitor") || lower.contains("screen") {
                            type = .display
                        } else if lower.contains("hub") {
                            type = .hub
                        } else {
                            type = .unknown
                        }

                        if let locationID = IORegistryEntryCreateCFProperty(service, "locationID" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? UInt32 {
                            let rootPort = locationID & 0xFFF0_0000
                            portGroups[rootPort, default: []].append(type)
                        }
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
        }

        return portGroups.values.map { items in
            if items.count > 1 {
                return .hub
            }
            return items.first ?? .unknown
        }
    }
}
