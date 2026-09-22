import Foundation
import os.log
import ServiceManagement

enum ChargingHelperStatus {
    case notInstalled
    case requiresApproval
    case installed
}

/// Resumes a `CheckedContinuation` at most once, guarding against the XPC reply and a
/// fallback timeout both firing (a double-resume is a runtime crash).
private nonisolated final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var isResumed = false
    private let continuation: CheckedContinuation<Void, Never>

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        lock.lock()
        defer { lock.unlock() }
        guard !isResumed else { return }
        isResumed = true
        continuation.resume()
    }
}

@MainActor
@Observable
class ChargingHelperManager {
    static let shared = ChargingHelperManager()

    private static let machServiceName = "com.dinanathdash.stasis.charging-helper"
    private static let plistName = "com.dinanathdash.stasis.charging-helper.plist"

    private var service: SMAppService
    private var connection: NSXPCConnection?
    private let logger = Logger(
        subsystem: "com.dinanathdash.stasis",
        category: "ChargingHelperManager"
    )

    private(set) var helperStatus: ChargingHelperStatus

    var isInstalled: Bool {
        helperStatus == .installed
    }

    private init() {
        service = SMAppService.daemon(plistName: Self.plistName)
        switch SMAppService.daemon(plistName: Self.plistName).status {
        case .enabled: helperStatus = .installed
        case .requiresApproval: helperStatus = .requiresApproval
        default: helperStatus = .notInstalled
        }
    }

    func install() throws {
        logger.info("Registering charging helper daemon")

        do {
            try service.register()
        } catch {
            // register() commonly throws "Operation not permitted" while macOS
            // processes the background item notification, even though the
            // registration advanced to requiresApproval or enabled.
            let currentStatus = SMAppService.daemon(plistName: Self.plistName).status
            if currentStatus != .enabled, currentStatus != .requiresApproval {
                throw error
            }
        }

        refreshStatus()
    }

    func forceUpgrade() throws {
        logger.info("Force upgrading charging helper daemon")
        disconnect()
        try? service.unregister()

        // IMPORTANT: backgroundtaskmanagementd (BTM) has a notorious bug on macOS 13+
        // where it aggressively caches the code signature of the previous daemon.
        // If we register() too quickly after unregister(), BTM will throw errSecCSReqFailed (-67028)
        // because its cache is in a race condition.
        // We MUST wait at least 1.0 second before registering the new one.
        // To avoid blocking the main thread during app launch, we do this asynchronously.
        Task {
            do {
                try await Task.sleep(for: .seconds(1.5))

                // Re-instantiate to clear internal SMAppService state
                let newService = SMAppService.daemon(plistName: Self.plistName)
                try newService.register()

                await MainActor.run {
                    self.service = newService
                    self.logger.info("Force upgrade register successful")
                    self.refreshStatus()
                }
            } catch {
                await MainActor.run {
                    self.logger.error("Force upgrade register failed: \(error.localizedDescription)")
                    self.refreshStatus()
                }
            }
        }
    }

    func uninstall() async throws {
        logger.info("Unregistering charging helper daemon")
        // Reset the SMC to its default state before uninstalling so the Mac isn't stuck at 80%
        if let helper = getHelper(errorHandler: { _ in }) {
            // Wait briefly for the reset to complete before we destroy the daemon, without
            // blocking the main thread the way a DispatchSemaphore wait would.
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let once = ResumeOnce(continuation)
                helper.resetToDefaults { _, _ in once.resume() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    once.resume()
                }
            }
        }

        disconnect()
        try await service.unregister()
        helperStatus = .notInstalled

        // Force the UI toggle off since the helper is gone
        UserDefaults.standard.set(false, forKey: "manageCharging")
        UserDefaults.standard.synchronize()
    }

    func refreshStatus() {
        let currentStatus = SMAppService.daemon(plistName: Self.plistName).status
        switch currentStatus {
        case .enabled:
            Task {
                if await checkLiveness() {
                    await MainActor.run { self.helperStatus = .installed }
                } else {
                    await MainActor.run { self.helperStatus = .notInstalled }
                }
            }
        case .requiresApproval: helperStatus = .requiresApproval
        default: helperStatus = .notInstalled
        }
    }

    private func checkLiveness() async -> Bool {
        return await withCheckedContinuation { continuation in
            guard let helper = getHelper(errorHandler: { _ in
                continuation.resume(returning: false)
            }) else {
                continuation.resume(returning: false)
                return
            }

            helper.ping { success in
                continuation.resume(returning: success)
            }
        }
    }

    func getHelper(errorHandler: @escaping @Sendable (Error) -> Void) -> ChargingHelperProtocol? {
        if connection == nil {
            connect()
        }
        guard let connection else { return nil }
        return connection.remoteObjectProxyWithErrorHandler(errorHandler)
            as? ChargingHelperProtocol
    }

    private func connect() {
        logger.info("Setting up XPC connection to charging helper daemon")
        let newConnection = NSXPCConnection(
            machServiceName: Self.machServiceName
        )
        newConnection.remoteObjectInterface = NSXPCInterface(
            with: ChargingHelperProtocol.self
        )

        newConnection.invalidationHandler = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.logger.warning("Charging helper XPC connection invalidated")
                self.connection = nil
            }
        }

        newConnection.interruptionHandler = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.logger.warning("Charging helper XPC connection interrupted")
                self.connection = nil
            }
        }

        newConnection.resume()
        connection = newConnection
    }

    func disconnect() {
        connection?.invalidate()
        connection = nil
    }

    func setLowPowerMode(_ enabled: Bool) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            guard let helper = getHelper(errorHandler: { error in
                continuation.resume(throwing: error)
            }) else {
                continuation.resume(throwing: NSError(domain: "ChargingHelperManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Helper not available"]))
                return
            }

            helper.setLowPowerMode(enabled: enabled) { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "ChargingHelperManager", code: 2, userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "Unknown error"]))
                }
            }
        }
    }
}
