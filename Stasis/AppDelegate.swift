import AppKit
import Defaults
import IOKit
import Observation
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusBarManager: StatusBarManager!
    private var batteryService: BatteryService!
    private var viewModel: MenuViewModel!
    private var menuBuilder: MenuBuilder!
    private var chargeManager: ChargeManager!
    private var settingsWindowController: SettingsWindowController!
    private var menu: NSMenu!
    private let updaterManager = UpdaterManager.shared
    private var settingsObservation: Task<Void, Never>?
    private var adapterObservation: Task<Void, Never>?
    private var isMenuOpen = false
    private var needsMenuRebuild = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Perform first‑run / version‑upgrade reset of user defaults
        resetStasisPreferencesIfNeeded()
        // Exit the app immediately if the device doesn't have a battery
        let batteryIOService = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard batteryIOService != 0 else {
            NSApplication.shared.terminate(nil)
            return
        }
        IOObjectRelease(batteryIOService)

        Task {
            await setupServices()
            setupMenu()
            requestNotificationPermissions()
            updaterManager.start()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let alert = NSAlert()
        alert.icon = NSImage(named: "AppIcon")
        alert.messageText = "Quit Stasis?"
        alert.informativeText = "Quitting Stasis will stop the background helper services. Battery charging limits and protections will no longer work."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Don't Quit")
        alert.addButton(withTitle: "Quit Anyway")

        NSSound.beep()
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            return .terminateCancel
        } else {
            return .terminateNow
        }
    }

    private func setupServices() async {
        batteryService = BatteryService()
        await batteryService.loadCapabilities()
        chargeManager = ChargeManager(batteryService: batteryService)
        viewModel = MenuViewModel(
            batteryService: batteryService,
            chargeManager: chargeManager
        )
        settingsWindowController = SettingsWindowController(
            capabilities: batteryService.deviceCapabilities
        )
        menuBuilder = MenuBuilder(
            viewModel: viewModel,
            settingsWindowController: settingsWindowController
        )
        statusBarManager = StatusBarManager(viewModel: viewModel)
    }

    private func setupMenu() {
        // Ensure the helper manager status is refreshed after potential reset
        // (no‑op if already correct)
        // This call is safe even if called multiple times.
        //
        // Note: The reset logic is performed earlier in `applicationDidFinishLaunching`.
        //
        // ---
        // Added methods for resetting defaults on first run / version change.
        // See `resetStasisPreferencesIfNeeded()` below.

        menu = menuBuilder.buildMenu()
        menu.delegate = self
        statusBarManager.setMenu(menu)
        observeMenuSettingsChanges()
    }

    private func observeMenuSettingsChanges() {
        settingsObservation = Task { [weak self] in
            for await _ in Defaults.updates(
                [
                    .showPowerSource, .showTimeTillDischarge,
                    .showBatteryCycleCount,
                    .showBatteryHealth, .showBatteryTemperature, .showUptime,
                    .showBatteryMode, .showInternalPower, .showExternalPower,
                    .showPowerDistribution,
                    .showOutputPortsText, .outputVisualizationMode,
                    .manageCharging, .showAdvancedChargingControls
                ],
                initial: false
            ) {
                self?.rebuildMenu()
            }
        }

        adapterObservation = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.rebuildMenu()
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.viewModel.adapterConnected
                    } onChange: {
                        Task { @MainActor in
                            continuation.resume()
                        }
                    }
                }
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.chargeManager.forceSyncSettings()
            self.batteryService.scheduleSinglePoll()
        }
    }

    private func rebuildMenu() {
        guard !isMenuOpen else {
            needsMenuRebuild = true
            return
        }
        menuBuilder.populateMenu(menu)
        needsMenuRebuild = false
    }

    private func requestNotificationPermissions() {
        // Request permission for user notifications (no changes)
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    // MARK: - First‑run / version‑upgrade preferences reset
    private func resetStasisPreferencesIfNeeded() {
        // Bundle identifier for the app (fallback to known identifier)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.dinanathdash.stasis"
        // Current app version
        let currentVersion =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? ""
        // If this is the first launch or the app has been updated, clear stored defaults
        if Defaults[.firstRun] || Defaults[.storedAppVersion] != currentVersion
        {
            // Remove all persisted defaults for this bundle
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            // Reset tracking keys to appropriate values
            Defaults[.firstRun] = false
            Defaults[.storedAppVersion] = currentVersion
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        viewModel.menuWillOpen()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        if needsMenuRebuild {
            rebuildMenu()
        }
        viewModel.menuDidClose()
    }
}
