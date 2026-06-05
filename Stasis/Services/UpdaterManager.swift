import AppKit
import Combine
import Foundation
import Sparkle

@MainActor
final class UpdaterManager: NSObject, ObservableObject {
    static let shared = UpdaterManager()

    private let controller: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var updateCheckInterval: TimeInterval {
        get { controller.updater.updateCheckInterval }
        set { controller.updater.updateCheckInterval = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set { controller.updater.automaticallyDownloadsUpdates = newValue }
    }

    private override init() {
        // startingUpdater: false -- we call start() explicitly in applicationDidFinishLaunching.
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    /// Call from applicationDidFinishLaunching to begin the automatic update schedule.
    func start() {
        #if DEBUG
        // Never check for updates in debug builds.
        return
        #else
        controller.startUpdater()
        #endif
    }

    /// Manually trigger an update check. For menu-bar-only apps, this switches
    /// to .regular activation policy so Sparkle's update window can appear.
    func checkForUpdates() {
        #if DEBUG
        return
        #else
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
        #endif
    }
}
