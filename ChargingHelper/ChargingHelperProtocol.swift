import Foundation

@objc protocol ChargingHelperProtocol {
    func ping(reply: @escaping @Sendable (Bool) -> Void)
    func setSettings(settings: [String: NSObject & Sendable], reply: @escaping @Sendable (Bool, String?) -> Void)
    func getSettings(reply: @escaping @Sendable ([String: NSObject & Sendable]) -> Void)
    func chargeToLimit(reply: @escaping @Sendable (Bool, String?) -> Void)
    func chargeToFull(reply: @escaping @Sendable (Bool, String?) -> Void)
    func disableCharging(reply: @escaping @Sendable (Bool, String?) -> Void)
    func disablePowerAdapter(reply: @escaping @Sendable (Bool, String?) -> Void)
    func enablePowerAdapter(reply: @escaping @Sendable (Bool, String?) -> Void)
    func manageMagsafeLED(target: UInt8, reply: @escaping @Sendable (Bool, String?) -> Void)
    func cancelOverride(reply: @escaping @Sendable (Bool, String?) -> Void)
    func resetToDefaults(reply: @escaping @Sendable (Bool, String?) -> Void)
}
