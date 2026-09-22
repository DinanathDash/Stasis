import Foundation
import ObjectiveC
import os.log

// MARK: - Errors

public enum NativeChargeError: LocalizedError {
    case unavailable
    case unsupportedLimit
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Native charge control is unavailable on this Mac."
        case .unsupportedLimit:
            return "This charge limit is not supported by macOS (supported: 80, 85, 90, 95, 100)."
        case .failed(let message):
            return message
        }
    }
}

// MARK: - Backend Protocol

public protocol NativeChargeBackend: AnyObject {
    var limits: [Int] { get }
    func readLimit() throws -> Int
    func writeLimit(_ value: Int) throws
}

// MARK: - Session

/// Wraps a NativeChargeBackend with journaling so the original system limit
/// can always be recovered — even across crashes — on the next launch.
public final class NativeChargeSession {
    private let backend: NativeChargeBackend
    private let defaults: UserDefaults
    private let recoveryKey = "nativeChargeOriginalLimit"
    private let logger = Logger(subsystem: "com.dinanathdash.stasis", category: "NativeChargeSession")

    public init(backend: NativeChargeBackend, defaults: UserDefaults = .standard) {
        self.backend = backend
        self.defaults = defaults
    }

    public var supportedLimits: [Int] { backend.limits }

    /// Nearest supported PowerUI limit step at or below `value`. Nil if value < minimum (80).
    public func nearestLimit(atOrBelow value: Int) -> Int? {
        backend.limits.filter { $0 <= value }.max()
    }

    /// Nearest supported PowerUI limit step at or above `value`. Nil if value > maximum (100).
    public func nearestLimit(atOrAbove value: Int) -> Int? {
        backend.limits.filter { $0 >= value }.min()
    }

    /// Writes `value` and verifies the readback, retrying the whole write+readback round trip
    /// a few times before giving up. Right after the PowerUI client first connects (e.g. the
    /// daemon just launched), its very first WRITE can fail outright — not just a stale
    /// readback — because the private client needs a brief moment after construction before
    /// it's ready to accept writes, even though reads during init already succeeded fine.
    private func writeAndVerify(_ value: Int, attempts: Int = 4) throws -> Int {
        var lastError: Error?
        for attempt in 1 ... attempts {
            do {
                try backend.writeLimit(value)
                let readback = try backend.readLimit()
                guard readback == value else {
                    throw NativeChargeError.failed(
                        "macOS did not retain the requested limit (read back \(readback)%, expected \(value)%)."
                    )
                }
                return readback
            } catch {
                lastError = error
                if attempt < attempts {
                    logger.warning("PowerUI write attempt \(attempt) failed, retrying: \(error.localizedDescription)")
                    Thread.sleep(forTimeInterval: 0.15)
                }
            }
        }
        throw lastError ?? NativeChargeError.failed("Unknown failure applying limit \(value)%.")
    }

    public func apply(_ limit: Int) throws {

        guard backend.limits.contains(limit) else { throw NativeChargeError.unsupportedLimit }
        let current = try backend.readLimit()
        if defaults.object(forKey: recoveryKey) == nil {
            defaults.set(current, forKey: recoveryKey)
            defaults.synchronize()
            logger.info("Journaled original native charge limit: \(current)%")
        }
        guard current != limit else { return }
        logger.info("Setting native charge limit: \(current)% → \(limit)%")
        _ = try writeAndVerify(limit)
    }

    public func restore() throws {
        guard defaults.object(forKey: recoveryKey) != nil else { return }
        let original = defaults.integer(forKey: recoveryKey)
        logger.info("Restoring native charge limit to \(original)%")
        _ = try writeAndVerify(original)
        defaults.removeObject(forKey: recoveryKey)
        defaults.synchronize()
        logger.info("Native charge limit restored and journal cleared.")
    }
}

// MARK: - PowerUI Private Framework Backend

/// Loads Apple's private PowerUI framework at runtime and calls PowerUISmartChargeClient
/// via ObjC runtime selectors. Same service client used by System Settings → Battery.
/// Fails closed: any missing selector or unavailable hardware → throws .unavailable.
public final class PowerUIChargeBackend: NativeChargeBackend {
    private let client: NSObject
    public let limits: [Int]
    private typealias ErrorPointer = AutoreleasingUnsafeMutablePointer<NSError?>?
    private let logger = Logger(subsystem: "com.dinanathdash.stasis", category: "PowerUIChargeBackend")

    public init() throws {
        guard dlopen("/System/Library/PrivateFrameworks/PowerUI.framework/PowerUI", RTLD_NOW) != nil,
              let cls = NSClassFromString("PowerUISmartChargeClient") as? NSObject.Type
        else { throw NativeChargeError.unavailable }

        let allocSel = NSSelectorFromString("alloc")
        typealias Alloc = @convention(c) (AnyObject, Selector) -> AnyObject
        guard let allocMethod = class_getClassMethod(cls, allocSel) else { throw NativeChargeError.unavailable }
        let allocated = unsafeBitCast(method_getImplementation(allocMethod), to: Alloc.self)(cls, allocSel)

        let initSel = NSSelectorFromString("initWithClientName:")
        typealias Init = @convention(c) (AnyObject, Selector, NSString) -> AnyObject
        guard let initMethod = class_getInstanceMethod(cls, initSel) else { throw NativeChargeError.unavailable }
        guard let initialized = unsafeBitCast(method_getImplementation(initMethod), to: Init.self)(
            allocated, initSel, "Stasis"
        ) as? NSObject else { throw NativeChargeError.unavailable }
        client = initialized

        for name in ["isMCLSupported", "isMCLCurrentlyEnabled:", "getMCLLimitWithError:",
                     "availableChargeLimitsWithError:", "setMCLLimit:error:"] {
            guard client.responds(to: NSSelectorFromString(name)) else { throw NativeChargeError.unavailable }
        }

        let supportedSel = NSSelectorFromString("isMCLSupported")
        typealias Supported = @convention(c) (AnyObject, Selector) -> Bool
        guard unsafeBitCast(client.method(for: supportedSel), to: Supported.self)(client, supportedSel) else {
            throw NativeChargeError.unavailable
        }

        var error: NSError?
        let enabledSel = NSSelectorFromString("isMCLCurrentlyEnabled:")
        typealias Enabled = @convention(c) (AnyObject, Selector, ErrorPointer) -> UInt
        let isEnabled = unsafeBitCast(client.method(for: enabledSel), to: Enabled.self)(client, enabledSel, &error)
        guard error == nil else { throw NativeChargeError.unavailable }
        
        if isEnabled == 0 {
            let enableSel = NSSelectorFromString("enableMCL:")
            typealias Enable = @convention(c) (AnyObject, Selector, ErrorPointer) -> Bool
            if client.responds(to: enableSel) {
                let success = unsafeBitCast(client.method(for: enableSel), to: Enable.self)(client, enableSel, &error)
                if !success || error != nil {
                    Logger(subsystem: "com.dinanathdash.stasis", category: "PowerUIChargeBackend")
                        .error("Failed to enable MCL. OS native limit might not be respected.")
                } else {
                    Logger(subsystem: "com.dinanathdash.stasis", category: "PowerUIChargeBackend")
                        .info("MCL was disabled in system settings; successfully enabled it.")
                }
            }
        }

        let availSel = NSSelectorFromString("availableChargeLimitsWithError:")
        typealias Available = @convention(c) (AnyObject, Selector, ErrorPointer) -> Unmanaged<AnyObject>?
        let values = unsafeBitCast(client.method(for: availSel), to: Available.self)(
            client, availSel, &error
        )?.takeUnretainedValue() as? [NSNumber]
        guard error == nil, let values else { throw NativeChargeError.unavailable }

        limits = values.map(\.intValue).filter { (80...100).contains($0) }.sorted()
        guard limits.contains(80), limits.contains(100) else { throw NativeChargeError.unavailable }
        Logger(subsystem: "com.dinanathdash.stasis", category: "PowerUIChargeBackend")
            .info("PowerUI backend ready. Limits: \(self.limits)")
    }

    public func readLimit() throws -> Int {
        let sel = NSSelectorFromString("getMCLLimitWithError:")
        typealias Read = @convention(c) (AnyObject, Selector, ErrorPointer) -> UInt8
        var error: NSError?
        let result = unsafeBitCast(client.method(for: sel), to: Read.self)(client, sel, &error)
        if let error { throw error }
        // macOS returns 0 when limit is disabled (= 100%)
        let value = result == 0 ? 100 : Int(result)
        guard limits.contains(value) else { throw NativeChargeError.unsupportedLimit }
        return value
    }

    public func writeLimit(_ value: Int) throws {
        guard limits.contains(value) else { throw NativeChargeError.unsupportedLimit }
        let sel = NSSelectorFromString("setMCLLimit:error:")
        typealias Write = @convention(c) (AnyObject, Selector, UInt8, ErrorPointer) -> Bool
        var error: NSError?
        let raw = UInt8(value == 100 ? 0 : value)  // macOS uses 0 for "no limit"
        let success = unsafeBitCast(client.method(for: sel), to: Write.self)(client, sel, raw, &error)
        if let error { throw error }
        guard success else {
            throw NativeChargeError.failed("macOS rejected the charge-limit update to \(value)%.")
        }
        logger.info("PowerUI wrote \(value)% (raw=\(raw))")
    }
}
