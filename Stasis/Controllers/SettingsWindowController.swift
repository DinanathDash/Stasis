import AppKit
import SwiftUI
import smc_power


@MainActor
class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let capabilities: DeviceCapabilities
    private let chargeManager: ChargeManager
    
    init(capabilities: DeviceCapabilities, chargeManager: ChargeManager) {
        self.capabilities = capabilities
        self.chargeManager = chargeManager
    }

    func showSettings() {
        // Window positioning is now handled by .center()
        if let existingWindow = window {
            existingWindow.center()
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            capabilities: capabilities
        )
        .environment(chargeManager)

        let hostingController = NSHostingController(rootView: settingsView)

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = String(localized: "Stasis Settings")
        newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        newWindow.titleVisibility = .visible
        newWindow.titlebarAppearsTransparent = false
        newWindow.toolbarStyle = .automatic
        newWindow.isMovableByWindowBackground = true
        newWindow.minSize = NSSize(width: 750, height: 540)
        newWindow.setContentSize(NSSize(width: 750, height: 540))
        newWindow.isReleasedWhenClosed = false
        newWindow.collectionBehavior = [.moveToActiveSpace, .fullScreenPrimary]
        
        newWindow.center() // Center it on first launch after reset

        newWindow.delegate = self
        window = newWindow
        newWindow.setFrameAutosaveName("SettingsWindow")
        
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = newWindow
    }
    
}
