import Foundation

public struct SMCBatteryReading: Sendable {
    public let batteryVoltage: Double
    public let batteryCurrent: Double
    public let batteryPower: Double

    public init(
        batteryVoltage: Double,
        batteryCurrent: Double,
        batteryPower: Double
    ) {
        self.batteryVoltage = batteryVoltage
        self.batteryCurrent = batteryCurrent
        self.batteryPower = batteryPower
    }
}

public struct SMCAdapterReading: Sendable {
    public let adapterVoltage: Double
    public let adapterCurrent: Double
    public let adapterPower: Double

    public init(
        adapterVoltage: Double,
        adapterCurrent: Double,
        adapterPower: Double
    ) {
        self.adapterVoltage = adapterVoltage
        self.adapterCurrent = adapterCurrent
        self.adapterPower = adapterPower
    }
}

public struct DeviceCapabilities: Sendable {
    public let chargingControl: Bool
    public let adapterControl: Bool
    public let hasMagSafe: Bool
    public let magsafeLEDControl: Bool
    public let nativeMode: Bool
    /// True when this Mac has no charge-inhibit key and no working native (PowerUI) limit —
    /// only force-discharge is available (macOS 15.8 with the new firmware). The charge limit
    /// can only be held by bouncing the AC adapter; it is not enforced unless automatic
    /// discharge is also enabled.
    public let dischargeOnlyFallback: Bool

    public init(
        chargingControl: Bool,
        adapterControl: Bool,
        hasMagSafe: Bool,
        magsafeLEDControl: Bool,
        nativeMode: Bool = false,
        dischargeOnlyFallback: Bool = false
    ) {
        self.chargingControl = chargingControl
        self.adapterControl = adapterControl
        self.hasMagSafe = hasMagSafe
        self.magsafeLEDControl = magsafeLEDControl
        self.nativeMode = nativeMode
        self.dischargeOnlyFallback = dischargeOnlyFallback
    }

    public static func from(
        battery: BatteryCapabilities,
        adapter: AdapterCapabilities
    ) -> DeviceCapabilities {
        DeviceCapabilities(
            chargingControl: battery.inhibitChargeControl,
            adapterControl: battery.forceDischargeControl,
            hasMagSafe: adapter.magSafeControl,
            magsafeLEDControl: adapter.magSafeControl
        )
    }
}
