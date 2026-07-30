import Foundation
import os.log

/// A Codable snapshot of the current battery and power state of Stasis,
/// shared between the main app (`Stasis`) and the widget extension (`StasisWidgets`).
struct WidgetStatusData: Codable, Equatable, Sendable {
    var percentage: Int
    var isCharging: Bool
    var isPluggedIn: Bool
    var chargeLimit: Int
    var isSailingMode: Bool
    var sailingDropLimit: Int
    var isTopUpActive: Bool
    var batteryWatts: Double
    var adapterWatts: Double
    var systemWatts: Double
    var batteryHealth: Int
    var batteryTemperature: Double
    var cycleCount: Int
    var timeRemainingMinutes: Int?
    var chargingModeRaw: String // e.g. "charging", "discharging", "pluggedIn", "onHold"
    var outputPortPowers: [Double]
    var outputIcons: [String]
    var hasMultiPort: Bool
    var lastUpdated: Date

    static let `default` = WidgetStatusData(
        percentage: 80,
        isCharging: false,
        isPluggedIn: true,
        chargeLimit: 80,
        isSailingMode: false,
        sailingDropLimit: 10,
        isTopUpActive: false,
        batteryWatts: 0.0,
        adapterWatts: 15.0,
        systemWatts: 15.0,
        batteryHealth: 98,
        batteryTemperature: 30.5,
        cycleCount: 42,
        timeRemainingMinutes: nil,
        chargingModeRaw: "onHold",
        outputPortPowers: [15.0],
        outputIcons: ["cable.connector"],
        hasMultiPort: false,
        lastUpdated: Date()
    )

    private static let userDefaultsKey = "com.dinanathdash.stasis.WidgetStatusData"
    private static let suiteName = "com.dinanathdash.stasis.shared"

    private static var fileURL: URL? {
        let home = NSHomeDirectory()
        let path: String
        if home.contains("Library/Containers") {
            // Running inside sandboxed widget extension container
            path = home + "/Library/Application Support/Stasis/widget_data.json"
        } else {
            // Running in main app
            path = home + "/Library/Containers/com.dinanathdash.stasis.widgets/Data/Library/Application Support/Stasis/widget_data.json"
        }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        return url
    }

    /// Saves the snapshot to container JSON file, shared JSON file, and shared UserDefaults.
    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return }

        // 1. Write to UserDefaults suite
        if let defaults = UserDefaults(suiteName: Self.suiteName) {
            defaults.set(data, forKey: Self.userDefaultsKey)
        }

        // 2. Write to container JSON file
        if let url = Self.fileURL {
            try? data.write(to: url, options: .atomic)
        }

        // 3. Write to /Users/Shared/Stasis/widget_data.json
        let sharedDir = URL(fileURLWithPath: "/Users/Shared/Stasis", isDirectory: true)
        try? FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true, attributes: nil)
        let sharedURL = sharedDir.appendingPathComponent("widget_data.json")
        try? data.write(to: sharedURL, options: .atomic)
    }

    /// Loads the latest snapshot from container JSON file, shared JSON file, or UserDefaults.
    static func load() -> WidgetStatusData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 1. Try reading from container JSON file
        if let url = fileURL,
           let data = try? Data(contentsOf: url),
           let snapshot = try? decoder.decode(WidgetStatusData.self, from: data) {
            os_log("WidgetStatusData: Successfully loaded from %{public}s - percentage: %d, cycles: %d", type: .default, url.path, snapshot.percentage, snapshot.cycleCount)
            return snapshot
        }

        // 2. Try reading from shared JSON file (/Users/Shared/Stasis/widget_data.json)
        let sharedURL = URL(fileURLWithPath: "/Users/Shared/Stasis/widget_data.json")
        if let data = try? Data(contentsOf: sharedURL),
           let snapshot = try? decoder.decode(WidgetStatusData.self, from: data) {
            os_log("WidgetStatusData: Successfully loaded from shared JSON file - percentage: %d, cycles: %d", type: .default, snapshot.percentage, snapshot.cycleCount)
            return snapshot
        }

        // 3. Try reading from UserDefaults suite
        if let defaults = UserDefaults(suiteName: suiteName),
           let data = defaults.data(forKey: userDefaultsKey),
           let snapshot = try? decoder.decode(WidgetStatusData.self, from: data) {
            os_log("WidgetStatusData: Successfully loaded from UserDefaults suite - percentage: %d, cycles: %d", type: .default, snapshot.percentage, snapshot.cycleCount)
            return snapshot
        }

        os_log("WidgetStatusData: FAILED to load from container, shared file, or UserDefaults! Returning default snapshot.", type: .fault)
        return .default
    }
}
