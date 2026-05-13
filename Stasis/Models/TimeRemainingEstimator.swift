import Foundation

@MainActor
class TimeRemainingEstimator {
    private var trendSample: (date: Date, percentage: Int, isCharging: Bool)?

    func formatTimeRemaining(
        reportedMinutes: Int,
        powerSource: PowerSource,
        isCharging: Bool,
        adapterConnected: Bool,
        batteryPercentage: Int,
        chargingTargetPercentage: Int
    ) -> String {
        if adapterConnected && !isCharging {
            return "N/A"
        }

        let adjustedReportedMinutes = adjustedReportedMinutesToTarget(
            reportedMinutes: reportedMinutes,
            isCharging: isCharging,
            batteryPercentage: batteryPercentage,
            targetPercentage: chargingTargetPercentage
        )

        let fallbackMinutes = estimateMinutesFromTrend(
            batteryPercentage: batteryPercentage,
            isCharging: isCharging,
            adapterConnected: adapterConnected,
            targetPercentage: chargingTargetPercentage
        )

        let effectiveMinutes = adjustedReportedMinutes >= 0 ? adjustedReportedMinutes : fallbackMinutes
        guard let effectiveMinutes, effectiveMinutes >= 0 else {
            return "Calculating..."
        }

        let hours = effectiveMinutes / 60
        let mins = effectiveMinutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }

    private func adjustedReportedMinutesToTarget(
        reportedMinutes: Int,
        isCharging: Bool,
        batteryPercentage: Int,
        targetPercentage: Int
    ) -> Int {
        guard reportedMinutes >= 0 else { return -1 }
        guard isCharging else { return reportedMinutes }

        if batteryPercentage >= targetPercentage {
            return 0
        }

        if targetPercentage >= 100 || batteryPercentage >= 100 {
            return reportedMinutes
        }

        let remainingToTarget = max(0, targetPercentage - batteryPercentage)
        let remainingToFull = max(1, 100 - batteryPercentage)
        let scaled = Double(reportedMinutes) * Double(remainingToTarget) / Double(remainingToFull)
        return Int(ceil(scaled))
    }

    private func estimateMinutesFromTrend(
        batteryPercentage: Int,
        isCharging: Bool,
        adapterConnected: Bool,
        targetPercentage: Int
    ) -> Int? {
        let now = Date()
        defer {
            trendSample = (date: now, percentage: batteryPercentage, isCharging: isCharging)
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
