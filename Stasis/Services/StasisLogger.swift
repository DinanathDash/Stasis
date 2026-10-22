import AppKit
import Foundation
import OSLog
import UniformTypeIdentifiers

/// Thread-safe rotating file logger and diagnostic exporter for Stasis.
/// Writes entries to ~/Library/Logs/Stasis/stasis.log and /tmp/stasis.log.
public final class StasisLogger: @unchecked Sendable {
    public static let shared = StasisLogger()

    public static var logDirectory: URL {
        let libraryLogs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
        return libraryLogs.appendingPathComponent("Logs/Stasis")
    }

    private let logDirectory: URL
    private let fileName = "stasis.log"
    private let maxFileSize: UInt64 = 5 * 1024 * 1024 // 5 MB
    private let maxBackups = 3

    private let queue = DispatchQueue(label: "com.dinanathdash.stasis.logger", qos: .utility)
    private var fileHandle: FileHandle?
    private var currentFileSize: UInt64 = 0

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    public init(directory: URL? = nil) {
        self.logDirectory = directory ?? Self.logDirectory
        queue.sync {
            self.prepareLogFile()
        }
    }

    deinit {
        let handle = fileHandle
        queue.async {
            try? handle?.synchronize()
            try? handle?.close()
        }
    }

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

    public static func flush() {
        shared.syncFlush()
    }

    public func record(message: String) {
        let now = Date()
        queue.async { [weak self] in
            guard let self else { return }
            let formattedDate = self.dateFormatter.string(from: now)
            let line = "[\(formattedDate)] [Stasis] \(message)\n"

            fputs(line, stderr)
            NSLog("[Stasis] %@", message)

            guard let data = line.data(using: .utf8) else { return }
            self.write(data)

            // Mirror to /tmp/stasis.log capped at 1 MB for quick terminal inspection
            let tmpURL = URL(fileURLWithPath: "/tmp/stasis.log")
            let fm = FileManager.default
            if fm.fileExists(atPath: tmpURL.path) {
                let tmpSize = ((try? fm.attributesOfItem(atPath: tmpURL.path)[.size]) as? UInt64) ?? 0
                if tmpSize > 1024 * 1024 {
                    try? fm.removeItem(at: tmpURL)
                    try? data.write(to: tmpURL)
                } else if let handle = try? FileHandle(forWritingTo: tmpURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: tmpURL)
            }
        }
    }

    public func syncFlush() {
        queue.sync {
            try? fileHandle?.synchronize()
        }
    }

    private var currentFileURL: URL {
        logDirectory.appendingPathComponent(fileName)
    }

    private func backupFileURL(index: Int) -> URL {
        let baseName = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        let backupName = ext.isEmpty ? "\(baseName).\(index)" : "\(baseName).\(index).\(ext)"
        return logDirectory.appendingPathComponent(backupName)
    }

    private func prepareLogFile() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: logDirectory.path) {
            try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        }

        purgeOldLogs()

        let fileURL = currentFileURL
        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }

        do {
            let handle = try FileHandle(forWritingTo: fileURL)
            handle.seekToEndOfFile()
            self.fileHandle = handle
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            self.currentFileSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        } catch {
            self.fileHandle = nil
            self.currentFileSize = 0
        }
    }

    /// Automatically purges log backups older than 7 days and stale export zips older than 24 hours.
    private func purgeOldLogs(olderThanDays days: Int = 7) {
        let fileManager = FileManager.default
        let cutoffDate = Date(timeIntervalSinceNow: -Double(days * 24 * 3600))

        // 1. Purge rotated logs in ~/Library/Logs/Stasis/ older than 7 days
        if let files = try? fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for file in files where file.lastPathComponent.hasPrefix("stasis") && file.lastPathComponent.contains(".log") {
                if let attrs = try? fileManager.attributesOfItem(atPath: file.path),
                   let modDate = attrs[.modificationDate] as? Date,
                   modDate < cutoffDate {
                    try? fileManager.removeItem(at: file)
                }
            }
        }

        // 2. Clean up any stale export archives in NSTemporaryDirectory older than 24 hours
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        if let tempFiles = try? fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.contentModificationDateKey]) {
            let tempCutoff = Date(timeIntervalSinceNow: -86400)
            for file in tempFiles where file.lastPathComponent.hasPrefix("Stasis-Logs-") && file.lastPathComponent.hasSuffix(".zip") {
                if let attrs = try? fileManager.attributesOfItem(atPath: file.path),
                   let modDate = attrs[.modificationDate] as? Date,
                   modDate < tempCutoff {
                    try? fileManager.removeItem(at: file)
                }
            }
        }
    }

    private func write(_ data: Data) {
        if currentFileSize + UInt64(data.count) > maxFileSize {
            rotate()
        }

        if fileHandle == nil {
            prepareLogFile()
        }

        guard let fileHandle else { return }

        do {
            try fileHandle.write(contentsOf: data)
            currentFileSize += UInt64(data.count)
        } catch {
            try? fileHandle.close()
            self.fileHandle = nil
        }
    }

    private func rotate() {
        try? fileHandle?.synchronize()
        try? fileHandle?.close()
        fileHandle = nil

        let fileManager = FileManager.default

        let highestBackup = backupFileURL(index: maxBackups)
        if fileManager.fileExists(atPath: highestBackup.path) {
            try? fileManager.removeItem(at: highestBackup)
        }

        if maxBackups > 1 {
            for i in stride(from: maxBackups - 1, through: 1, by: -1) {
                let src = backupFileURL(index: i)
                let dst = backupFileURL(index: i + 1)
                if fileManager.fileExists(atPath: src.path) {
                    try? fileManager.moveItem(at: src, to: dst)
                }
            }
        }

        let current = currentFileURL
        let firstBackup = backupFileURL(index: 1)
        if fileManager.fileExists(atPath: current.path) {
            try? fileManager.moveItem(at: current, to: firstBackup)
        }

        prepareLogFile()
    }
}

// MARK: - Log Exporter

public enum StasisLogExporterError: LocalizedError, Equatable {
    case noLogFilesFound
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noLogFilesFound:
            return String(localized: "No log files found to export.")
        case .exportFailed(let reason):
            return String(localized: "Failed to export logs: \(reason)")
        }
    }
}

@MainActor
public enum StasisLogExporter {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Gathers diagnostic system info and OSLogStore entries before export.
    private static func generateDiagnosticDump(in directory: URL) {
        let diagURL = directory.appendingPathComponent("stasis-diagnostics.log")
        var lines: [String] = []

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        lines.append("=== Stasis Diagnostics Dump ===")
        lines.append("Timestamp: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("App Version: \(version) (\(build))")
        lines.append("OS Version: \(osVersion)")
        lines.append("Host Name: \(ProcessInfo.processInfo.hostName)")
        lines.append("")

        // Collect unified OSLog entries if possible
        if let store = try? OSLogStore(scope: .currentProcessIdentifier),
           let position = try? store.position(timeIntervalSinceLatestBoot: 0),
           let entries = try? store.getEntries(at: position) {
            lines.append("=== Recent System Logs ===")
            for entry in entries {
                if let logEntry = entry as? OSLogEntryLog {
                    lines.append("[\(logEntry.date)] [\(logEntry.category)] \(logEntry.composedMessage)")
                }
            }
            lines.append("")
        }

        let content = lines.joined(separator: "\n")
        try? content.data(using: .utf8)?.write(to: diagURL)
    }

    /// Archives all `stasis*.log` files from ~/Library/Logs/Stasis into a timestamped zip.
    @discardableResult
    public static func exportLogs(
        from directory: URL = StasisLogger.logDirectory,
        date: Date = Date()
    ) async throws -> URL {
        StasisLogger.flush()

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        // Generate up-to-date diagnostic dump
        generateDiagnosticDump(in: directory)

        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let logFiles = contents.filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("stasis") && name.hasSuffix(".log")
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !logFiles.isEmpty else {
            throw StasisLogExporterError.noLogFilesFound
        }

        let dateString = dateFormatter.string(from: date)
        let archiveName = "Stasis-Logs-\(dateString).zip"
        let archiveURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(archiveName)

        if fileManager.fileExists(atPath: archiveURL.path) {
            try? fileManager.removeItem(at: archiveURL)
        }

        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.arguments = ["-q", "-j", archiveURL.path] + logFiles.map(\.path)
            try process.run()
            process.waitUntilExit()
        }.value

        guard fileManager.fileExists(atPath: archiveURL.path) else {
            throw StasisLogExporterError.exportFailed("Zip archive was not created.")
        }

        return archiveURL
    }

    /// Reveals the Stasis logs folder in Finder.
    public static func showLogsInFinder(directory: URL = StasisLogger.logDirectory) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: directory.path)
    }
}
