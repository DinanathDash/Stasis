import Foundation
import os.log

public final class ChargingHelperLogger: @unchecked Sendable {
    public static let shared = ChargingHelperLogger()

    private let logURL = URL(fileURLWithPath: "/tmp/stasis-charging-helper.log")
    private let queue = DispatchQueue(label: "com.dinanathdash.stasis.charging-helper.logger", qos: .utility)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    public static func log(_ message: String) {
        shared.record(message: message)
    }

    public static func info(_ message: String) {
        shared.record(message: "[INFO] \(message)")
    }

    public static func warn(_ message: String) {
        shared.record(message: "[WARN] \(message)")
    }

    public static func error(_ message: String) {
        shared.record(message: "[ERROR] \(message)")
    }

    public static func debug(_ message: String) {
        shared.record(message: "[DEBUG] \(message)")
    }

    public func record(message: String) {
        let now = Date()
        queue.async { [weak self] in
            guard let self else { return }
            let formattedDate = self.dateFormatter.string(from: now)
            let line = "[\(formattedDate)] [ChargingHelper] \(message)\n"
            fputs(line, stderr)
            guard let data = line.data(using: .utf8) else { return }

            let fm = FileManager.default
            if fm.fileExists(atPath: self.logURL.path) {
                let size = ((try? fm.attributesOfItem(atPath: self.logURL.path)[.size]) as? UInt64) ?? 0
                if size > 2 * 1024 * 1024 {
                    try? fm.removeItem(at: self.logURL)
                    try? data.write(to: self.logURL)
                } else if let handle = try? FileHandle(forWritingTo: self.logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: self.logURL)
            }
        }
    }
}

public struct ChargingHelperLog: Sendable {
    public let category: String
    private let osLogger: Logger

    public init(category: String, subsystem: String = "com.dinanathdash.stasis.charging-helper") {
        self.category = category
        self.osLogger = Logger(subsystem: subsystem, category: category)
    }

    public func info(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
        ChargingHelperLogger.info("[\(category)] \(message)")
    }

    public func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
        ChargingHelperLogger.error("[\(category)] \(message)")
    }

    public func warn(_ message: String) {
        osLogger.warning("\(message, privacy: .public)")
        ChargingHelperLogger.warn("[\(category)] \(message)")
    }

    public func warning(_ message: String) {
        warn(message)
    }

    public func debug(_ message: String) {
        osLogger.debug("\(message, privacy: .public)")
        ChargingHelperLogger.debug("[\(category)] \(message)")
    }

    public func fault(_ message: String) {
        osLogger.fault("\(message, privacy: .public)")
        ChargingHelperLogger.error("[\(category)] [FAULT] \(message)")
    }
}
