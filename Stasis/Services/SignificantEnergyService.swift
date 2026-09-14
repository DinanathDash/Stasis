import AppKit
import Defaults
import Foundation
import Observation
import os.log

@MainActor
@Observable
class SignificantEnergyService {
    private(set) var apps: [SignificantEnergyApp] = []

    private let threshold: Double = 1.0
    private var openMenuTask: Task<Void, Never>?
    private let logger = Logger(
        subsystem: "com.dinanathdash.stasis",
        category: "SignificantEnergyService"
    )

    init() {}

    func startOpenMenuPolling() {
        stopOpenMenuPolling()
        openMenuTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stopOpenMenuPolling() {
        openMenuTask?.cancel()
        openMenuTask = nil
    }

    func refresh() async {
        guard Defaults[.showSignificantEnergyApps] else {
            apps = []
            return
        }
        let pidPowers = await fetchTopPowerMetrics()
        let filteredApps = filterAndBuildApps(from: pidPowers)
        apps = filteredApps
    }

    private func fetchTopPowerMetrics() async -> [(pid_t, Double)] {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/top")
            process.arguments = [
                "-l", "2", "-s", "0", "-stats", "pid,power", "-o", "power",
                "-n", "15",
            ]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                guard let output = String(data: data, encoding: .utf8) else {
                    return []
                }
                return Self.parseTopOutput(output)
            } catch {
                return []
            }
        }.value
    }

    nonisolated static func parseTopOutput(_ output: String) -> [(pid_t, Double)] {
        let components = output.components(separatedBy: "PID")
        guard let lastSection = components.last else { return [] }

        var results: [(pid_t, Double)] = []
        let lines = lastSection.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("POWER") {
                continue
            }
            let tokens = trimmed.components(separatedBy: .whitespaces).filter {
                !$0.isEmpty
            }
            guard tokens.count >= 2,
                  let pid = pid_t(tokens[0]),
                  let power = Double(tokens[1])
            else {
                continue
            }
            results.append((pid, power))
        }
        return results
    }

    private func filterAndBuildApps(from pidPowers: [(pid_t, Double)])
        -> [SignificantEnergyApp]
    {
        var results: [SignificantEnergyApp] = []
        var seenBundleIDs: Set<String> = []

        for (pid, power) in pidPowers {
            guard power >= threshold else { continue }
            guard let app = NSRunningApplication(processIdentifier: pid) else {
                continue
            }

            // Filter out system background daemons and helper services
            guard app.activationPolicy == .regular || app.activationPolicy == .accessory else {
                continue
            }

            // Skip our own app
            if let bundleID = app.bundleIdentifier,
               bundleID == Bundle.main.bundleIdentifier
            {
                continue
            }

            guard let name = app.localizedName, !name.isEmpty else { continue }

            if let bundleID = app.bundleIdentifier {
                if seenBundleIDs.contains(bundleID) {
                    continue
                }
                seenBundleIDs.insert(bundleID)
            }

            let energyApp = SignificantEnergyApp(
                id: pid,
                pid: pid,
                name: name,
                bundleIdentifier: app.bundleIdentifier,
                powerScore: power,
                icon: app.icon
            )
            results.append(energyApp)
        }

        return results.sorted { $0.powerScore > $1.powerScore }
    }

    deinit {
        MainActor.assumeIsolated {
            openMenuTask?.cancel()
        }
    }
}
