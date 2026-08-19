import AppIntents
import AppKit
import Defaults
import IOKit
import Observation

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusBarManager: StatusBarManager!
    private var batteryService: BatteryService!
    private var viewModel: MenuViewModel!
    private var menuBuilder: MenuBuilder!
    private var chargeManager: ChargeManager!
    private var calibrationManager: CalibrationManager!
    private var significantEnergyService: SignificantEnergyService!
    private var notchHUDManager: NotchHUDManager!
    private var settingsWindowController: SettingsWindowController!
    private var menu: NSMenu!
    private let updaterManager = UpdaterManager.shared
    private var settingsObservation: Task<Void, Never>?
    private var adapterObservation: Task<Void, Never>?
    private var significantEnergyObservation: Task<Void, Never>?
    private var isMenuOpen = false
    private var needsMenuRebuild = false

    @MainActor
    static private(set) var shared: AppDelegate?

    override init() {
        super.init()
        Self.shared = self
    }

    var currentBatteryService: BatteryService? { batteryService }
    var currentChargeManager: ChargeManager? { chargeManager }
    var currentViewModel: MenuViewModel? { viewModel }
    var currentCalibrationManager: CalibrationManager? { calibrationManager }

    @MainActor
    func ensureServicesReady() async -> (BatteryService, ChargeManager, MenuViewModel, CalibrationManager)? {
        for _ in 0..<30 {
            if let batteryService, let chargeManager, let viewModel, let calibrationManager {
                return (batteryService, chargeManager, viewModel, calibrationManager)
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return nil
    }

    @objc func showSettingsWindow() {
        settingsWindowController?.showSettings()
    }

    @objc func openMenuBarMenu() {
        statusBarManager?.openMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Perform first‑run / version‑upgrade reset of user defaults
        let isFirstRun = resetStasisPreferencesIfNeeded()
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

        StasisShortcutsProvider.updateAppShortcutParameters()

        // Auto-update the Privileged Helper Daemon if it's already installed (e.g. after a Sparkle update)
        // Or if it's a completely fresh installation / just wiped by the "Reset App" button.
        if ChargingHelperManager.shared.isInstalled || isFirstRun {
            try? ChargingHelperManager.shared.install()
            self.forceSyncSettings()
        }

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        Task {
            await setupServices()
            setupMenu()
            updaterManager.start()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            StasisURLHandler.shared.handleURL(url)
        }
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }
        StasisURLHandler.shared.handleURL(url)
    }

    static var isRestarting = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.isRestarting {
            return .terminateNow
        }
        let alert = NSAlert()
        alert.icon = NSImage(named: "AppIcon")
        alert.messageText = String(localized: "Quit Stasis?")
        alert.informativeText = String(localized: "Quitting Stasis will stop the background helper services. Battery charging limits and protections will no longer work.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Don't Quit"))
        alert.addButton(withTitle: String(localized: "Quit Anyway"))
        
        alert.window.level = .screenSaver
        alert.window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
        
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
        calibrationManager = CalibrationManager(batteryService: batteryService, chargeManager: chargeManager)
        significantEnergyService = SignificantEnergyService()
        viewModel = MenuViewModel(
            batteryService: batteryService,
            chargeManager: chargeManager,
            significantEnergyService: significantEnergyService
        )
        settingsWindowController = SettingsWindowController(
            capabilities: batteryService.deviceCapabilities,
            chargeManager: chargeManager
        )
        menuBuilder = MenuBuilder(
            viewModel: viewModel,
            settingsWindowController: settingsWindowController
        )
        statusBarManager = StatusBarManager(viewModel: viewModel)
        notchHUDManager = NotchHUDManager(viewModel: viewModel)
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
                    .showTwoDecimalPowerValues,
                    .showOutputPortsText, .outputVisualizationMode,
                    .manageCharging, .showAdvancedChargingControls,
                    .appLanguage, .showSignificantEnergyApps
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

        significantEnergyObservation = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.rebuildMenu()
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.significantEnergyService.apps
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
            Task { @MainActor in
                guard let self else { return }
                self.chargeManager.forceSyncSettings()
                self.batteryService.scheduleSinglePoll()
            }
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

    // MARK: - First‑run / version‑upgrade preferences reset
    private func resetStasisPreferencesIfNeeded() -> Bool {
        // Bundle identifier for the app (fallback to known identifier)
        _ = Bundle.main.bundleIdentifier ?? "com.dinanathdash.stasis"
        // Current app version
        let currentVersion =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? ""
        // If this is the first launch, just record it
        if Defaults[.firstRun] {
            Defaults[.firstRun] = false
            Defaults[.storedAppVersion] = currentVersion
            return true
        } else if Defaults[.storedAppVersion] != currentVersion {
            // App was updated, just record the new version without wiping preferences
            Defaults[.storedAppVersion] = currentVersion
        }
        return false
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

    func forceSyncSettings() {
        chargeManager?.forceSyncSettings()
    }
}
