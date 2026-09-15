import Foundation

nonisolated enum BatteryReading {
    static func fullChargeCapacityMAh(from properties: [String: Any]) -> Double? {
        let nested = properties["BatteryData"] as? [String: Any] ?? [:]
        return [properties["AppleRawMaxCapacity"], nested["AppleRawMaxCapacity"], nested["FullChargeCapacity"]]
            .compactMap { ($0 as? NSNumber)?.doubleValue }
            .first { $0.isFinite && $0 > 100 && $0 < 100_000 }
    }

    static func signedAmperage(_ value: NSNumber) -> Double {
        Double(value.int64Value) / 1000
    }
    static func reportedHealth(from data: Data) -> Int? {
        guard let document = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = document["SPPowerDataType"] as? [[String: Any]] else { return nil }
        for item in items {
            guard let health = item["sppower_battery_health_info"] as? [String: Any],
                  let text = health["sppower_battery_health_maximum_capacity"] as? String,
                  let percentage = Int(text.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)),
                  (1...100).contains(percentage) else { continue }
            return percentage
        }
        return nil
    }

    static func capacities(from properties: [String: Any]) -> (current: Int?, maximum: Int?, design: Int?) {
        let nested = properties["BatteryData"] as? [String: Any] ?? [:]
        func positive(_ values: Any?...) -> Int? {
            values.compactMap { $0 as? Int }.first { $0 > 0 }
        }
        return (
            positive(properties["AppleRawCurrentCapacity"], nested["RemainingCapacity"]),
            positive(properties["AppleRawMaxCapacity"], nested["FullChargeCapacity"]),
            positive(properties["DesignCapacity"], nested["DesignCapacity"])
        )
    }

    static func estimatedHealth(from properties: [String: Any]) -> Int? {
        let values = capacities(from: properties)
        guard let maximum = values.maximum, let design = values.design else { return nil }
        let ratio = Double(maximum) * 100 / Double(design)
        guard ratio.isFinite, ratio >= 1, ratio <= 120 else { return nil }
        return min(100, Int(ratio))
    }
}

nonisolated struct ChargingTransitionTracker {
    private var previous: Bool?

    mutating func update(isCharging: Bool, valid: Bool, notificationsEnabled: Bool) -> Bool? {
        guard valid else { return nil }
        let oldValue = previous
        previous = isCharging
        guard notificationsEnabled, let oldValue, oldValue != isCharging else { return nil }
        return isCharging
    }
}

nonisolated struct PowerConnectionTracker {
    private var previous: Bool?

    mutating func update(connected: Bool, valid: Bool, enabled: Bool) -> Bool? {
        guard valid else { return nil }
        let old = previous
        previous = connected
        guard enabled, let old, old != connected else { return nil }
        return connected
    }
}
