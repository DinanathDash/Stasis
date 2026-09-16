import AppKit
import Defaults
import SwiftUI

@MainActor
class StatusBarManager {
    private let statusItem: NSStatusItem
    private let viewModel: MenuViewModel

    init(viewModel: MenuViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        statusItem.autosaveName = "StasisBatteryStatusItem"
        setupPersistentHostingView()
    }

    func setMenu(_ menu: NSMenu) {
        statusItem.menu = menu
    }

    func openMenu() {
        if let button = statusItem.button {
            button.performClick(nil)
        }
    }

    private func setupPersistentHostingView() {
        guard let button = statusItem.button else { return }

        let rootView = StatusBarContentView(viewModel: viewModel)
        let hosting = StatusBarHostingView(rootView: rootView)
        hosting.onRightClick = { [weak self, weak hosting] event in
            guard let self = self, let view = hosting else { return }
            
            let menu = NSMenu()
            
            let lpmItem = NSMenuItem(
                title: "Low Power Mode",
                action: #selector(self.toggleLowPowerModeAction),
                keyEquivalent: ""
            )
            lpmItem.target = self
            lpmItem.state = self.viewModel.isLowPowerModeEnabled ? .on : .off
            menu.addItem(lpmItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let settingsItem = NSMenuItem(
                title: "Battery Settings...",
                action: #selector(self.openSystemBatterySettings),
                keyEquivalent: ""
            )
            settingsItem.target = self
            menu.addItem(settingsItem)
            
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        }

        button.subviews.forEach { $0.removeFromSuperview() }
        button.title = ""
        button.image = nil

        hosting.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: button.topAnchor, constant: 4),
            hosting.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -4),
            hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 7),
            hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -7),
        ])
    }

    @objc private func toggleLowPowerModeAction() {
        let newState = !self.viewModel.isLowPowerModeEnabled
        self.viewModel.isLowPowerModeEnabled = newState // Optimistic UI update
        Task {
            do {
                try await self.viewModel.toggleLowPowerMode()
            } catch {
                self.viewModel.isLowPowerModeEnabled = !newState // Revert on failure
            }
        }
    }

    @objc private func openSystemBatterySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

class StatusBarHostingView<Content: View>: NSHostingView<Content> {
    var onRightClick: ((NSEvent) -> Void)?

    override func rightMouseDown(with event: NSEvent) {
        if let onRightClick = onRightClick {
            onRightClick(event)
        } else {
            super.rightMouseDown(with: event)
        }
    }
}

struct StatusBarContentView: View {
    let viewModel: MenuViewModel
    @Default(.batteryPercentageVisibility) var batteryPercentageVisibility
    @Default(.showBatteryStateInStatusIcon) var showBatteryStateInStatusIcon

    var body: some View {
        BatteryIndicatorView(
            batteryLevel: viewModel.displayPercentage,
            chargingMode: viewModel.chargingMode,
            isLowPowerModeEnabled: viewModel.isLowPowerModeEnabled,
            batteryPercentageVisibility: batteryPercentageVisibility,
            showState: showBatteryStateInStatusIcon
        )
        .fixedSize()
    }
}
