import Foundation

/// Stub for AppDelegate and main app services in the `StasisWidgets` extension target,
/// allowing shared AppIntents (`ToggleTopUpIntent`, `ToggleSailingModeIntent`, etc.) to compile
/// cleanly and fall back to their WidgetKit `else` branch at runtime when `AppDelegate.shared` is nil.
struct AppDelegate {
    static let shared: AppDelegateStub? = nil
}

struct AppDelegateStub {
    func ensureServicesReady() async -> (Any, ChargeManagerStub, MenuViewModelStub, Any)? { nil }
}

final class ChargeManagerStub {
    var chargeLimitOverrideActive: Bool = false
    func toggleChargeLimitOverride() {}
    func forceSyncSettings() {}
}

final class MenuViewModelStub {
    var displayPercentage: Int = 80
    var chargingMode: ChargingMode = .pluggedIn
    var batteryHealthText: String = "100%"
    var batteryTemperatureText: String = "30.0°C"
    var batteryPower: Double = 0
    var adapterPower: Double = 0
    var systemPower: Double = 0
    var adapterConnected: Bool = true
}
