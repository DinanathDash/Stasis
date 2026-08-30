# Changelog

All notable changes to Stasis are documented here.

---

## Unreleased

- No unreleased changes yet.

---

## 0.21.3 - 2026-08-30

Major stability update addressing privileged daemon crashes and XPC reliability in ad-hoc builds.

### Bug Fixes & Refinements

- **XPC Security & Build Support:** Refactored XPC validation to use `SecCodeCopyDesignatedRequirement` combined with `processIdentifier`, resolving a critical `EX_CONFIG` launch crash on ad-hoc release builds while maintaining robust security against spoofing.
- **Daemon Liveness & Sync:** Replaced the unreliable `SMAppService.status` check with an active XPC `ping` for true daemon liveness verification. Silent sync failures are now caught and immediately surfaced to the user.
- **Daemon Re-installation:** Fixed a 32-second UI thread blocking issue during daemon installation and ensured `manageCharging` preferences are cleanly wiped upon uninstallation to prevent unintended charging pauses on restart.
- **Heat Protection:** Fixed a logic bug where heat protection failed to re-enable the power adapter, inadvertently draining the battery while trying to cool it down.
- **SMC Read Reliability:** SMC read failures (e.g. from the unprivileged helper) are now properly surfaced to the UI instead of silently masking as zero values (0.00W).
- **Launchd Compatibility:** Added required `CFBundleIdentifier` and bundle keys to the `ChargingHelper` Info.plist to satisfy strict `launchd` constraint requirements.

---

## 0.21.2 - 2026-08-28

Fixed an issue where toggling off 'Manage charging' during a forced discharge failed to re-enable the power adapter.

### Bug Fixes & Refinements

- **Charging Controls:** Ensure the power adapter is properly re-enabled when turning off charge management so native macOS charging resumes immediately.

---

## 0.21.1 - 2026-08-28

XPC security validation, calibration state improvements, and DMG layout updates.

### Features & Core Capabilities

- **XPC Security:** Implemented code signature validation for incoming XPC connections and added input validation for charging configuration settings.
- **Code Signing:** Dynamically generating code signing requirements using the leaf certificate's common name to enforce identity and team ID verification.
- **Calibration States:** Added MagSafe LED control to calibration states and improved charging mode display logic.

### Bug Fixes & Refinements

- **XPC Connection:** Reset power state and stop monitoring events when the XPC connection is invalidated.
- **Helper Identity:** Updated bundle identifier requirement to lowercase in ChargingHelper and Helper targets.

### Infrastructure & Build

- **DMG Layout:** Updated DMG layout, bumped macOS support, and added a local DMG testing script.
- **Release Workflow:** Refined the release workflow configuration and updated GitHub Actions dependencies.

---

## 0.20.2 - 2026-08-20

Launch sequence cleanup.

### Refactors & Architecture

- **App Launch:** Replaced the `forceUpgrade` call with `install` inside the `AppDelegate` launch sequence for smoother helper initialization.

---

## 0.20.1 - 2026-08-20

Race condition fix for charging helper registration.

### Bug Fixes

- **Helper Registration:** Resolved race conditions during charging helper registration by introducing a delayed asynchronous upgrade process.

---

## 0.20.0 - 2026-08-20

Launch state management for robust helper upgrades.

### Features & Core Capabilities

- **Launch States:** Implemented granular app launch state handling to properly support forced charging helper upgrades during active version updates.

---

## 0.19.0 - 2026-08-19

Battery heat protection and MagSafe state separation.

### Features & Core Capabilities

- **Heat Protection:** Implemented intelligent battery heat protection, updated temperature readings, and ensured helper sync upon initialization.
- **MagSafe States:** Separated MagSafe LED settings into distinctly manageable charging, paused, and discharging states.

### UI & Enhancements

- **Localization:** Added Italian localization specifically for LED pause and limit state strings.

---

## 0.18.0 - 2026-08-17

Discharge sleep prevention and notch optimizations.

### Features & Core Capabilities

- **Session Energy:** Added sleep prevention during forced discharge, alongside new session energy dashboard metrics with full intent and settings support.

### UI & Layout

- **Notch View:** Enabled robust multi-display support and implemented dynamic notch width calculations for `ChargingNotchView`.

---

## 0.17.0 - 2026-08-07

Submodule updates and view positioning fixes.

### Features & Core Capabilities

- **Autosave:** Added autosave support for the macOS status item configuration.

### Refactors & Architecture

- **Battery-Toolkit:** Integrated and updated `Battery-Toolkit` submodule components, introducing improved power event and service communication logic.
- **Service Sync:** Synchronized charging management services natively across the Stasis codebase.

### UI & Layout

- **Sankey Anchoring:** Migrated `PowerSankeyView` labels to utilize anchored geometry-based positioning.

---

## 0.16.1 - 2026-08-02

Massive localization fixes and terminology refinements.

### Bug Fixes & Refinements

- **Localization:** Repaired translations across Asian, European, and Western locales, including completing the Shortcuts help localization coverage for Chinese.
- **Terminology:** Refined overarching localization terminology and formats.

### Refactors & Architecture

- **Code Cleanup:** Updated `LocalizedStringResource` types and simplified the conditional logic behind the clipboard button.
- **Documentation:** Updated documentation to identify the original Stasis fork source.

---

## 0.16.0 - 2026-07-31

Introduction of custom URL schemes for system automation.

### Features & Core Capabilities

- **System Automation:** Implemented a custom URL scheme handler and a dedicated Shortcuts help view to streamline system automation workflows.

---

## 0.15.1 - 2026-07-30

Stability improvements for App Intents.

### Bug Fixes & Refinements

- **App Intents Execution:** Refactored App Intents to always foreground the application and ensure background services are fully ready before execution.

---

## 0.15.0 - 2026-07-30

Improvements to AppIntents shortcuts and build registration.

### Features & Core Capabilities

- **Shortcuts Parameters:** Implemented parameter updates for AppIntents shortcuts.
- **Installation:** Improved the build installation script registration process.

---

## 0.14.0 - 2026-07-30

Introduction of AppIntents for comprehensive system control.

### Features & Core Capabilities

- **App Intents:** Implemented 13 native App Intents for comprehensive system control and battery status reporting directly through macOS Shortcuts.

### UI & Layout

- **Typography:** Introduced `PercentageFormatter` to enforce standardized percentage string representations across the entire application.

### Bug Fixes & Refinements

- **Documentation Updates:** Aligned documentation with codebase strings, detailing 17 languages, 13 App Intents, 3-stage calibration, and evergreen Apple Silicon references.

---

## 0.13.1 - 2026-07-29

Memory leak fix.

### Bug Fixes & Refinements

- **Memory Management:** Marked `DynamicallyResizingHostingView` as final and added explicit `deinit` to prevent memory leaks during view lifecycle.

---

## 0.13.0 - 2026-07-29

Significant energy impact monitoring and enhanced localization.

### Features & Core Capabilities

- **Energy Impact Monitor:** Added a Significant Energy Apps monitor with a configurable dashboard toggle and menu integration.
- **Power Precision:** Added a toggle to display two-decimal precision for power readings.

### UI & Layout

- **View Optimization:** Optimized the layout of `SignificantEnergyViews` and fixed hosting view resizing logic.
- **Localization:** Completed full localization coverage across all languages, with specific fixes for Simplified Chinese and updated localization strings.

### Bug Fixes & Refinements

- **Formatting:** Ensured the port power string is correctly formatted when returned to the UI.

---

## 0.12.0 - 2026-07-26

Language selection UI and calibration formatting improvements.

### Features & Core Capabilities

- **Language Settings:** Implemented language selection within settings, complete with automatic app restart support to seamlessly apply localizations.
- **Daemon Management:** Added helper daemon management UI and dedicated localized strings.

### UI & Enhancements

- **Notifications:** Refactored battery calibration notifications to use localized, dynamic formatting.

---

## 0.11.0 - 2026-07-23

Battery calibration service and Notch HUD concurrency updates.

### Features & Core Capabilities

- **Battery Calibration:** Implemented a dedicated battery calibration service featuring a notification-driven workflow and native UI support.
- **Charging State:** Improved charging state detection to support adaptive power visualization in the UI.

### UI & Layout

- **Notch Concurrency:** Updated concurrency handling for the `NotchWindow` and cleaned up surrounding localization strings.
- **Localization:** Localized all battery percentage formatting across the app.

---

## 0.10.0 - 2026-07-18

Introduction of the Dynamic Island-style Notch HUD.

### Features & Core Capabilities

- **Dynamic Notch HUD:** Implemented a stunning Dynamic Island-style Notch HUD to gracefully surface charging state notifications.

### UI & Enhancements

- **Notch Layering:** Implemented `TopWindowElevator` to guarantee the `NotchWindow` remains visible above all system UI and lock screens.
- **Animation & Positioning:** Refined the notch animation logic and settings window positioning.

### Bug Fixes

- **Notch Layout:** Stabilized notch layout and clipping by refactoring frame and background modifiers inside `ChargingNotchView`.

---

## 0.9.0 - 2026-07-01

Introduction of USB accessory detection and visualization.

### Features & Core Capabilities

- **Accessory Detection:** Added support for USB hub and accessory detection with custom icon rendering in the power dashboard.

---

## 0.8.2 - 2026-06-23

Minor project configuration cleanup.

### Infrastructure & Build

- **Configuration:** Removed obsolete `Stasis.icon` references from the project configuration.

---

## 0.8.1 - 2026-06-23

Settings window UX improvements.

### UI & Layout

- **Window Placement:** Centered the settings window on the active screen during initialization and display for a more predictable user experience.

---

## 0.8.0 - 2026-06-07

Major AppIcon overhaul and localization expansions.

### Features & Core Capabilities

- **Localization:** Implemented extensive localized strings and updated project build configurations.
- **Dependency Locking:** Restored `Package.resolved` to enforce locked dependencies.

### UI & Layout

- **App Icons:** Replaced the legacy AppIcon asset catalog with a new icon configuration, ensuring proper standard sizes for native macOS styles.
- **Settings View:** Removed negative padding from settings views and localized the battery percentage picker labels.

### Security & Distribution

- **Build Pipeline:** Resolved GitHub Actions pipeline failures related to code signing and Xcode asset compilation.
- **App Bundle:** Renamed the build product to `Stasis.app` and wrapped settings sync tasks in `MainActor` for thread safety.

---

## 0.7.0 - 2026-06-05

Sparkle auto-update integration and workflow enhancements.

### Features & Core Capabilities

- **Sparkle Auto-Update:** Fully implemented Sparkle auto-update integration, ensuring seamless background updates.
- **Release Triggers:** Added `workflow_dispatch` to enable manual release triggering via GitHub Actions.

### Bug Fixes & Refinements

- **Data Persistence:** Fixed a bug that caused `UserDefaults` to be wiped unintentionally.
- **Settings UI:** Updated the UI layout in the settings views for better alignment and rolled back the internal project version to 0.6.1 to correct sequencing.

---

## 0.6.1 - 2026-06-02

UI enhancements for popup dialogs.

### UI & Layout

- **Native Dialogs:** Refactored popup dialogs to utilize native `NSAlert` with custom styling for a more cohesive macOS experience.

---

## 0.6.0 - 2026-06-01

Privileged helper management and hardware power detection.

### Features & Core Capabilities

- **Helper Management:** Added a dedicated UI in settings for managing the privileged helper tool.
- **Power Detection:** Updated IOKit power detection logic for improved accuracy.

---

## 0.5.1 - 2026-06-01

Workflow trigger updates.

### Infrastructure & Build

- **Release Automation:** Minor trigger update for the release workflow.

---

## 0.5.0 - 2026-06-01

Major rewrite migrating charging logic to an XPC helper daemon.

### Features & Core Capabilities

- **XPC Helper Daemon:** Successfully migrated core charging logic and power events to a dedicated XPC helper daemon for improved security and stability.
- **Advanced Controls:** Added support for "Top-up to limit", daemon sync recovery, and an advanced charging controls toggle.
- **Daemon Validation:** Added `Info.plist` to the ChargingHelper and updated code signing requirements to support `SMAppService` validation.

### UI & Enhancements

- **Battery Visibility:** Consolidated battery percentage visibility settings for a cleaner preferences pane.
- **Sankey Diagram:** Updated the `PowerSankeyView` battery icon state to accurately reflect charging.

### Security & Distribution

- **Code Signing:** Corrected the `SMAppService` code signing sequence for GitHub Actions releases.
- **Build Scripts:** Added dedicated build and install scripts alongside updated developer documentation.

---

## 0.4.0 - 2026-05-17

Battery health caching and preferences enhancements.

### Features & Core Capabilities

- **Battery Health:** Implemented cached, system-calibrated battery health with a toggle for viewing raw hardware health data.
- **Settings Management:** Added preference reset functionality and initial run tracking support.

---

## 0.3.1 - 2026-05-15

UI refinements and improvements to charging helper installation flow.

### Bug Fixes & Refinements

- **Charging Helper Flow:** Enhanced the charging helper installation flow and added clear user guidance for charge management.
- **Battery Status:** Updated battery time remaining UI to correctly show "N/A" when plugged in and stabilized the overall charging state UI.
- **Sankey Diagram:** Corrected height misalignment issues in `PowerSankeyView` when dealing with multiple outputs.

---

## 0.3.0 - 2026-05-14

New power metrics, font styling, and update check controls.

### Features & Core Capabilities

- **Power Metrics:** Added visibility for wattage on internal and external power inputs.
- **Update Frequency:** Introduced configuration settings for customizing the update check frequency.

### UI & Layout

- **Typography:** Applied tabular formatting to numbers to prevent text wiggling during active value changes.
- **Assets & GitHub:** Added GitHub templates, updated localizations, and refreshed icons.

---

## 0.2.1 - 2026-05-12

Cleanup of the release pipeline.

### Refactors & Architecture

- **Release Workflow:** Removed the Sparkle updater dependency and simplified the GitHub Actions release workflow.

---

## 0.2.0 - 2026-05-12

Transition to a custom native updater.

### Features & Core Capabilities

- **Native Updater:** Replaced Sparkle with a custom, native GitHub Release updater mechanism for seamless over-the-air updates.

---

## 0.1.14 - 2026-05-12

Icon asset standardization.

### UI & Enhancements

- **Asset Naming:** Renamed app icon assets to enforce a standardized naming convention across the project.

---

## 0.1.13 - 2026-05-12

Application icon updates.

### UI & Enhancements

- **App Icons:** Updated application icon assets to reflect the latest design language.

---

## 0.1.12 - 2026-05-12

Improvements to the Sparkle update packaging process.

### Security & Distribution

- **Sparkle Package:** Updated the CI workflow to use the properly re-signed application bundle for the Sparkle update zip, ensuring Gatekeeper compliance.

---

## 0.1.11 - 2026-05-12

Visual polish for the application installer.

### UI & Enhancements

- **DMG Icon:** Configured the build process to set a custom icon directly on the generated DMG file for a better unboxing experience.

---

## 0.1.10 - 2026-05-12

Minor fix to the Sparkle download URL configuration.

### Bug Fixes

- **URL Formatting:** Fixed a trailing slash issue in the Sparkle download URL prefix within the CI workflow.

---

## 0.1.9 - 2026-05-12

Refinement of the signature injection process for appcast generation.

### Bug Fixes & Refinements

- **Signature Injection:** Fixed regex escaping logic in the signature injection fallback script to ensure reliable appcast updates.

---

## 0.1.8 - 2026-05-12

Improvements to the Sparkle appcast signing process during the release workflow.

### Bug Fixes & Refinements

- **Appcast Signing:** Captured Sparkle signing output to correctly inject the missing `edSignature` into the appcast XML during the release workflow.

---

## 0.1.7 - 2026-05-12

Enhancements to appcast validation logic.

### Bug Fixes

- **Validation Checks:** Updated appcast validation to accept both `sparkle:edSignature` and `sparkle:signature` attributes for robust compatibility.

---

## 0.1.6 - 2026-05-12

Refactoring of XPC helper handling and added release workflow validations.

### Refactors & Architecture

- **XPC Continuation:** Refactored XPC helper handling to improve robust continuation management.
- **Workflow Validation:** Added Sparkle appcast validation to the GitHub release workflow to prevent malformed updates.

---

## 0.1.5 - 2026-05-12

Cleanup of Sparkle appcast generation scripts.

### Infrastructure & Build

- **Appcast Cleanup:** Removed redundant `--versions` flags from Sparkle appcast generation commands for a cleaner, more predictable build output.

---

## 0.1.4 - 2026-05-12

Minor copy updates for update checking.

### UI & Layout

- **Status Messages:** Updated the status message text presented when the application initiates an update check.

---

## 0.1.3 - 2026-05-12

Minor layout adjustments for the Sparkle DMG installer.

### UI & Layout

- **DMG Installer:** Adjusted the DMG window position and updated appcast generation arguments for a smoother installation experience.

---

## 0.1.2 - 2026-05-12

Sparkle auto-update feed configuration and visual fixes.

### Bug Fixes & Refinements

- **DMG Layout:** Updated the position of the application icon within the DMG window.
- **Sparkle Integration:** Implemented the Sparkle delegate to correctly handle the dynamic feed URL configuration.

---

## 0.1.1 - 2026-05-12

Refactoring the Sparkle appcast generation pipeline.

### Infrastructure & Build

- **Appcast Generation:** Refactored the release script to redirect Sparkle appcast generation output directly to a file instead of relying on CLI flags, improving CI reliability.

---

## 0.1.0 - 2026-05-12

Major milestone introducing automated app updates via the Sparkle framework.

### Features & Core Capabilities

- **Auto-Updates:** Integrated the Sparkle framework for seamless over-the-air native macOS app updates.
- **Release Automation:** Expanded CI configuration and release automation scripts to support automated appcast generation.

---

## 0.0.6 - 2026-05-12

Architectural improvements and internal structural enhancements.

### Refactors & Architecture

- **Code Structure:** Extensively refactored the codebase structure for improved readability and long-term maintainability.

---

## 0.0.5 - 2026-05-12

Introduction of Code Signing for the DMG creation process to improve macOS security and installation reliability.

### Security & Distribution

- **Code Signing:** Added code signing to the DMG creation process to prevent Gatekeeper warnings on macOS.

---

## 0.0.4 - 2026-05-12

Fixes to the DMG creation process and Homebrew installation instructions.

### Bug Fixes

- **DMG Creation:** Updated the DMG creation process to ensure stable builds.
- **Homebrew Cask:** Corrected the Homebrew installation instructions in the documentation.

---

## 0.0.3 - 2026-05-11

Minor graphical fix for the DMG installer background.

### UI & Layout

- **Installer Background:** Corrected the file path to the DMG background image so the installer renders beautifully.

---

## 0.0.2 - 2026-05-11

Build process refinements.

### Infrastructure & Build

- **Xcodebuild:** Updated xcodebuild commands to use the `project` file instead of `workspace`.

---

## 0.0.1 - 2026-05-11

Initial core application release featuring the charging helper daemon, MagSafe LED controls, and multi-language support.

### Features & Core Capabilities

- **Charging Helper Daemon:** Implemented the core charging-helper daemon with Read-Write controls on the SMC.
- **Power Metrics Dashboard:** Added output power metrics and visualization options to the frontend MVP.
- **MagSafe LED Settings:** Separated MagSafe LED settings into distinct charging, paused, and discharging states.
- **Localization:** Added full localization support for multiple languages.

### UI & Enhancements

- **Status Icon:** Added an option to show the battery state directly in the macOS status icon.
- **Sankey Diagram:** Simplified Sankey View Diagram construction for cleaner power flow visualization.
- **Landing Assets:** Added a wiki image for the landing image and cleaned up unused graphical assets.

### Bug Fixes

- **Sync Reliability:** Fixed an issue where the charge limit was not being reset on adapted syncs.
- **SMC Async:** Updated SMCKit to a non-async version for improved stability.
