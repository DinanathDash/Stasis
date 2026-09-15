import Foundation

enum TargetTimeEstimate: Equatable {
    case estimating, notApproaching, holding(Int), minutes(Int, target: Int)

    var text: String {
        switch self {
        case .estimating: "Estimating…"
        case .notApproaching: "Not approaching target"
        case .holding(let target): "∞ · Holding at \(target)%"
        case .minutes(let minutes, let target): "≈ \(minutes) min to \(target)%"
        }
    }
}

/// A short-horizon estimate, not a prediction of future workload or charge taper.
/// Uses the OS display percentage for the target gap, avoiding raw/display SOC mismatch.
struct TargetTimeEstimator {
    private var context: Context?
    private var firstSample: Double?
    private var lastSample: Double?
    private var averageAmps: Double?

    private struct Context: Equatable {
        let target: Int
        let connected: Bool
        let direction: Int
    }

    mutating func reset() {
        context = nil
        firstSample = nil
        lastSample = nil
        averageAmps = nil
    }

    mutating func update(_ battery: BatteryMetrics, target: Int, now: Double) -> TargetTimeEstimate {
        guard battery.hasPowerSourceData, (0...100).contains(battery.batteryPercentage),
              (1...100).contains(target), now.isFinite,
              let sample = battery.powerSampleTime, sample.isFinite,
              now >= sample, now - sample <= 120,
              let amps = battery.osBatteryCurrent, amps.isFinite else {
            reset()
            return .estimating
        }
        let direction = amps > 0.05 ? 1 : (amps < -0.05 ? -1 : 0)
        let newContext = Context(target: target, connected: battery.externalConnected, direction: direction)
        if context != newContext || (lastSample.map { sample < $0 || sample - $0 > 120 } ?? false) {
            reset()
            context = newContext
        }
        let gap = target - battery.batteryPercentage
        if gap == 0 {
            return battery.externalConnected && direction == 0 && !battery.isCharging
                ? .holding(target) : .estimating
        }
        guard direction != 0, (gap > 0) == (direction > 0) else { return .notApproaching }
        // Apple's full-charge prediction can account for taper that a current-rate
        // projection cannot. It is directly applicable only to a 100% target.
        if target == 100, battery.isCharging, direction > 0,
           (1...2880).contains(battery.timeRemaining) {
            return .minutes(battery.timeRemaining, target: target)
        }
        guard let capacity = battery.fullChargeCapacityMAh, capacity.isFinite,
              capacity > 100, capacity < 100_000 else {
            reset()
            return .estimating
        }
        // Deduplicate the same IOKit snapshot when SMC, settings or UI refreshes fire.
        if lastSample != sample {
            if let last = lastSample, let previous = averageAmps {
                let weight = 1 - exp(-(sample - last) / 60)
                averageAmps = previous + weight * (abs(amps) - previous)
            } else {
                firstSample = sample
                averageAmps = abs(amps)
            }
            lastSample = sample
        }
        guard let firstSample, sample - firstSample >= 15, let averageAmps else { return .estimating }
        let minutes = capacity * Double(abs(gap)) / 100 / (averageAmps * 1000) * 60
        guard minutes.isFinite, minutes >= 0, minutes <= 48 * 60 else { return .estimating }
        return .minutes(max(1, Int(minutes.rounded(FloatingPointRoundingRule.up))), target: target)
    }
}
