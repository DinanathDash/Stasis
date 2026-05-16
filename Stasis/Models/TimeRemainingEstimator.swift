import Foundation

struct TimeRemainingEstimator {
    private struct TrendSample {
        let date: Date
        let percentage: Int
        let isCharging: Bool
    }

    private var trendSample: TrendSample?

    mutating func estimateTimeRemaining(
        reportedMinutes: Int,
        isCharging: Bool,
        adapterConnected: Bool,
        batteryPercentage: Int,
        chargingTargetPercentage: Int
    ) -> Int? {
        if batteryPercentage >= chargingTargetPercentage && isCharging {
            return 0
        }

        if reportedMinutes >= 0 {
            return reportedMinutes
        }

        return estimateMinutesFromTrend(
            batteryPercentage: batteryPercentage,
            isCharging: isCharging,
            adapterConnected: adapterConnected,
            targetPercentage: chargingTargetPercentage
        )
    }

    private mutating func estimateMinutesFromTrend(
        batteryPercentage: Int,
        isCharging: Bool,
        adapterConnected: Bool,
        targetPercentage: Int
    ) -> Int? {
        let now = Date()
        defer {
            trendSample = TrendSample(date: now, percentage: batteryPercentage, isCharging: isCharging)
        }

        guard !(adapterConnected && !isCharging) else { return nil }
        guard let previous = trendSample else { return nil }
        guard previous.isCharging == isCharging else { return nil }

        let elapsedMinutes = now.timeIntervalSince(previous.date) / 60
        guard elapsedMinutes >= 0.5 else { return nil }

        let deltaPercent = batteryPercentage - previous.percentage
        guard deltaPercent != 0 else { return nil }

        let percentPerMinute = abs(Double(deltaPercent) / elapsedMinutes)
        guard percentPerMinute > 0 else { return nil }

        let remainingPercent: Int = {
            if isCharging {
                return max(0, targetPercentage - batteryPercentage)
            }
            return max(0, batteryPercentage)
        }()

        if remainingPercent == 0 {
            return 0
        }

        let minutes = Double(remainingPercent) / percentPerMinute
        return Int(ceil(minutes))
    }
}
