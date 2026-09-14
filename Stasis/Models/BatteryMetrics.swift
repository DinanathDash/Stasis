import Foundation

enum AccessoryType: String, Codable, Equatable {
    case phone
    case storage
    case network
    case printer
    case display
    case hub
    case unknown
}

struct OutputPortPower: Codable, Equatable, Identifiable {
    var portIndex: Int
    var powerWatts: Double

    var id: Int {
        portIndex
    }
}

struct BatteryMetrics: Codable, Equatable {
    var batteryPercentage: Int = 0
    var hardwareBatteryPercentage: Int = 0
    var isCharging: Bool = false
    var timeRemaining: Int = 0

    var batteryVoltage: Double = 0
    var batteryCurrent: Double = 0
    var batteryPower: Double = 0
    var systemInputPower: Double = 0
    var outputPower: Double = 0
    var outputPorts: [OutputPortPower] = []
    var batteryTemperature: Double = 0

    var rawBatteryHealth: Int = 0
    var calibratedBatteryHealth: Int? = nil
    var cycleCount: Int = 0

    var currentCapacity: Int = 0
    var maxCapacity: Int = 0

    var externalConnected: Bool = false
    var hasMultiPort: Bool = false
    var connectedAccessories: [AccessoryType] = []
}

struct AdapterMetrics: Equatable {
    var adapterConnected: Bool = false
    var adapterCapacityWatts: Int = 0
    var adapterVoltage: Double = 0
    var adapterCurrent: Double = 0
    var adapterPower: Double = 0
}

struct BatteryControlState: Equatable {
    var batteryPercentage: Int = 0
    var hardwareBatteryPercentage: Int = 0
    var adapterConnected: Bool = false
    var batteryTemperature: Double = 0
}
