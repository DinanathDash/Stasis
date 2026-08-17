import AppKit
import Defaults
import Foundation
import Observation
import SwiftUI

@MainActor
class NotchHUDManager {
    private var windows: [NotchWindow] = []
    private let viewModel: MenuViewModel
    private var observationTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private let state = NotchHUDState() // Persistent state for smooth animations

    // Track previous states to detect changes
    private var previousChargingMode: ChargingMode?
    private var previousLowPowerMode: Bool?
    private var previousForceDischarge: Bool?
    private var previousAdapterConnected: Bool?
    private var previousCalibrationStatus: CalibrationStatus?
    private var previousChargeLimitOverride: Bool?
    private var previousChargeToLimit: Bool?

    init(viewModel: MenuViewModel) {
        self.viewModel = viewModel
        startObserving()
    }

    private func startObserving() {
        observationTask = Task {
            // Wait for initial values to settle
            try? await Task.sleep(for: .seconds(2))
            
            // Set initial state without triggering HUD
            previousChargingMode = viewModel.chargingMode
            previousLowPowerMode = viewModel.isLowPowerModeEnabled
            previousForceDischarge = viewModel.forceDischargeActive
            previousAdapterConnected = viewModel.adapterConnected
            previousCalibrationStatus = Defaults[.calibrationStatus]
            previousChargeLimitOverride = viewModel.chargeLimitOverrideActive
            previousChargeToLimit = viewModel.chargeToLimitActive

            for await _ in NotificationCenter.default.notifications(named: .NSProcessInfoPowerStateDidChange) {
                // To allow Low Power Mode observation without polling
                Task { @MainActor in
                    self.checkStateAndShowHUD()
                }
            }
        }
        
        Task {
            // Give time for initial properties to settle
            try? await Task.sleep(for: .seconds(2))
            while !Task.isCancelled {
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = viewModel.chargingMode
                        _ = viewModel.isLowPowerModeEnabled
                        _ = viewModel.forceDischargeActive
                        _ = viewModel.adapterConnected
                        _ = viewModel.chargeLimitOverrideActive
                        _ = viewModel.chargeToLimitActive
                    } onChange: {
                        Task { @MainActor in
                            continuation.resume()
                        }
                    }
                }
                checkStateAndShowHUD()
            }
        }

        Task {
            // Observe defaults for calibration
            for await _ in Defaults.updates([.calibrationStatus], initial: false) {
                Task { @MainActor in
                    self.checkStateAndShowHUD()
                }
            }
        }
    }

    private func checkStateAndShowHUD() {
        guard Defaults[.enableNotchHUD] else { return }
        
        if !Defaults[.showNotchHUDOnLockScreen] {
            if let session = CGSessionCopyCurrentDictionary() as? [String: Any],
               let isLocked = session["CGSSessionScreenIsLocked"] as? Bool,
               isLocked {
                return
            }
        }

        let currentChargingMode = viewModel.chargingMode
        let currentLowPowerMode = viewModel.isLowPowerModeEnabled
        let currentForceDischarge = viewModel.forceDischargeActive
        let currentAdapterConnected = viewModel.adapterConnected
        let currentCalibrationStatus = Defaults[.calibrationStatus]
        let currentChargeLimitOverride = viewModel.chargeLimitOverrideActive
        let currentChargeToLimit = viewModel.chargeToLimitActive

        // Determine what changed
        let modeChanged = currentChargingMode != previousChargingMode
        let lpmChanged = currentLowPowerMode != previousLowPowerMode
        let fdChanged = currentForceDischarge != previousForceDischarge
        let adapterChanged = currentAdapterConnected != previousAdapterConnected
        let calChanged = currentCalibrationStatus != previousCalibrationStatus
        let overrideChanged = currentChargeLimitOverride != previousChargeLimitOverride
        let topupChanged = currentChargeToLimit != previousChargeToLimit

        // If something relevant changed, show HUD
        if modeChanged || lpmChanged || fdChanged || adapterChanged || calChanged || overrideChanged || topupChanged {
            let text = determineStatusText(
                chargingMode: currentChargingMode,
                lowPowerMode: currentLowPowerMode,
                forceDischarge: currentForceDischarge,
                adapterConnected: currentAdapterConnected,
                lpmChanged: lpmChanged,
                calibrationStatus: currentCalibrationStatus,
                chargeLimitOverride: currentChargeLimitOverride,
                overrideChanged: overrideChanged,
                chargeToLimit: currentChargeToLimit,
                topupChanged: topupChanged
            )
            showHUD(with: text)
        }

        // Update tracking
        previousChargingMode = currentChargingMode
        previousLowPowerMode = currentLowPowerMode
        previousForceDischarge = currentForceDischarge
        previousAdapterConnected = currentAdapterConnected
        previousCalibrationStatus = currentCalibrationStatus
        previousChargeLimitOverride = currentChargeLimitOverride
        previousChargeToLimit = currentChargeToLimit
    }

    private func determineStatusText(
        chargingMode: ChargingMode,
        lowPowerMode: Bool,
        forceDischarge: Bool,
        adapterConnected: Bool,
        lpmChanged: Bool,
        calibrationStatus: CalibrationStatus,
        chargeLimitOverride: Bool,
        overrideChanged: Bool,
        chargeToLimit: Bool,
        topupChanged: Bool
    ) -> String {
        if calibrationStatus != .idle {
            if !adapterConnected && calibrationStatus != .discharging {
                return String(localized: "Calibrating (Paused - Plug in)")
            }
            if calibrationStatus == .discharging {
                return String(localized: "Calibrating (Discharging)")
            }
            if calibrationStatus == .charging {
                return String(localized: "Calibrating (Charging up)")
            }
            if calibrationStatus == .resting {
                return String(localized: "Calibrating (Resting)")
            }
        }
        
        if overrideChanged && chargeLimitOverride {
            return String(localized: "Charging to \(100.formattedPercentage) (Override)")
        }
        
        if topupChanged && chargeToLimit {
            return String(localized: "Top-up to Limit")
        }
        if lowPowerMode && lpmChanged {
            return String(localized: "Low Power Mode")
        }
        if forceDischarge {
            return String(localized: "Force Discharging")
        }
        if !adapterConnected {
            return String(localized: "On Battery")
        }
        if chargingMode == .discharging {
            // If adapter is connected but we are discharging (and not force discharging), we must be draining to limit
            return String(localized: "Draining to Limit")
        }
        if chargingMode == .charging {
            return String(localized: "Charging")
        }
        if chargingMode == .pluggedIn {
            if Defaults[.manageCharging] {
                // If manage charging is on and we are plugged in but not charging
                let level = viewModel.displayPercentage
                if level >= Defaults[.chargeLimit] {
                    return String(localized: "Limit Reached")
                } else if Defaults[.sailingMode] {
                    return String(localized: "Sailing Mode")
                } else {
                    return String(localized: "On Hold")
                }
            }
            if viewModel.displayPercentage == 100 {
                return String(localized: "Fully Charged")
            }
            return String(localized: "Plugged In")
        }
        return String(localized: "Unknown")
    }

    private func showHUD(with text: String) {
        let displayMode = Defaults[.notchHUDDisplayMode]
        var targetScreens: [NSScreen] = []
        
        if displayMode == .macDisplayOnly {
            // Find the screen with a physical notch
            if let notchScreen = NSScreen.screens.first(where: { NotchWindow.hasNotch(screen: $0) }) {
                targetScreens.append(notchScreen)
            } else if let mainScreen = NSScreen.main {
                // Fallback to main if no notch is found, maybe it's an older Mac display
                targetScreens.append(mainScreen)
            }
        } else {
            // Show on all screens
            targetScreens = NSScreen.screens
        }

        let wasVisible = !windows.isEmpty && windows.first?.isVisible == true
        
        // Ensure state starts collapsed if window is not visible
        if !wasVisible {
            state.isVisible = false
            let soundSelection = Defaults[.notchHUDSound]
            if soundSelection != .none {
                NSSound(named: NSSound.Name(soundSelection.rawValue))?.play()
            }
        }

        // Update state content
        state.statusText = text
        state.batteryLevel = viewModel.displayPercentage
        state.chargingMode = viewModel.chargingMode
        state.isLowPowerModeEnabled = viewModel.isLowPowerModeEnabled
        
        // Match windows count to targetScreens
        while windows.count < targetScreens.count {
            let window = NotchWindow()
            window.contentHeight = 36
            window.shadowPadding = 0
            window.hasShadow = false
            windows.append(window)
        }
        while windows.count > targetScreens.count {
            let window = windows.removeLast()
            window.orderOut(nil)
        }
        
        // Ensure the windows are shown with the view bound to our state
        for (index, targetScreen) in targetScreens.enumerated() {
            let window = windows[index]
            
            if window.contentView == nil || !wasVisible {
                var calculatedNotchWidth: CGFloat = 180.0
                if #available(macOS 12.0, *) {
                    if let leftArea = targetScreen.auxiliaryTopLeftArea,
                       let rightArea = targetScreen.auxiliaryTopRightArea,
                       leftArea.width > 0, rightArea.width > 0 {
                        let gap = rightArea.minX - leftArea.maxX
                        if gap > 0 {
                            calculatedNotchWidth = gap
                        }
                    } else {
                        // Responsive fallback
                        let scale = targetScreen.frame.width / 1470.0
                        calculatedNotchWidth = 180.0 * max(0.8, min(scale, 1.5))
                    }
                } else {
                    let scale = targetScreen.frame.width / 1470.0
                    calculatedNotchWidth = 180.0 * max(0.8, min(scale, 1.5))
                }

                let contentView = ChargingNotchView(state: state, notchWidth: calculatedNotchWidth)
                let safeAreaTop = targetScreen.safeAreaInsets.top
                let menuBarHeight = targetScreen.frame.maxY - targetScreen.visibleFrame.maxY
                
                let notchHeight: CGFloat
                if safeAreaTop > 0 {
                    notchHeight = safeAreaTop
                } else if menuBarHeight > 0 {
                    notchHeight = menuBarHeight
                } else {
                    notchHeight = 32 // Fallback if menu bar is hidden
                }
                
                window.contentHeight = notchHeight
                window.showNotch(on: targetScreen, content: contentView)
            }
        }
        
        if !wasVisible {
            // Trigger animation on next runloop tick so view is in hierarchy
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                self.state.isVisible = true
            }
        } else {
            state.isVisible = true
        }

        // Cancel existing hide task
        hideTask?.cancel()

        // Create new hide task
        hideTask = Task {
            let duration = Defaults[.notchHUDDisplayDuration]
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            
            // Trigger SwiftUI collapse animation
            state.isVisible = false
            
            // Wait for spring animation to finish then close windows
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            for window in self.windows {
                window.orderOut(nil)
            }
        }
    }
}
