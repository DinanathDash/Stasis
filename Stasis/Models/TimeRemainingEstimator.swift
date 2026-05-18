import Foundation

struct TimeRemainingEstimator {
    func estimateTimeRemaining(
        reportedMinutes: Int,
        isCharging: Bool,
        batteryPercentage: Int,
        chargingTargetPercentage: Int
    ) -> Int? {
        if batteryPercentage >= chargingTargetPercentage && isCharging {
            return 0
        }

        guard reportedMinutes >= 0 else {
            return nil
        }

        return reportedMinutes
    }
}
