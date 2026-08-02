# Stasis

> ***This project is a fork of [srimanachanta/Stasis](https://github.com/srimanachanta/Stasis).***

**A smarter battery icon for your MacBook.** Monitor power metrics, manage charge limits, automate power profiles, and extend your battery's lifespan — all from the menu bar.

Stasis gives you real-time insight into your MacBook's power system and lets you control charging behavior directly, without relying on macOS's opaque "Optimized Battery Charging."

> **Apple Silicon only.** Fully supported on all Apple Silicon MacBooks (M-series chips).
>
> Requires **macOS 14.8 – 26.3**.

![Stasis Menu Bar](assets/images/FullApp.jpg)

---

## Highlights

- **Hardware Charge Limit** — Set a maximum charge level (50–100%) enforced at the hardware level via the SMC, remaining active even through system sleep or power cycling.
- **Sailing Mode** — Prevent micro-charging cycles by allowing the battery to float naturally within a configurable upper and lower percentage range.
- **Automatic Discharge** — Safely drain battery charge down to your target limit while plugged into power.
- **Heat Protection** — Automatically pause charging when battery temperature exceeds your safety threshold.
- **Apple Shortcuts & Siri Automation** — Native Apple Shortcuts and Siri support via 13 App Intents (including `Open Dashboard`, `Get Battery Status`, `Set Charge Limit`, `Toggle Top-Up to 100%`, `Toggle Sailing Mode`, `Toggle Force Discharge`, and `Start/Cancel Battery Calibration`).
- **Apps Using Significant Energy** — Real-time detection and menu bar display of apps consuming excessive energy, with a configurable dashboard toggle.
- **Battery Calibration Service** — Guided 3-stage calibration workflow (**Discharge to 15% → Recharge to 100% → Rest at 100%**) to recalibrate your battery gauge and SMC sensors.
- **Dynamic Island Notch HUD** — Sleek hardware notch overlay for charging state notifications and power alerts, powered by `TopWindowElevator` to stay visible above system UI and lock screens.
- **Multi-Port & Accessory Detection** — Detects USB-C, MagSafe, and USB Hub power sources with custom icon rendering and a two-decimal high-precision power toggle.
- **Live Power Dashboard** — Real-time voltage, current, wattage, temperature, battery health, and cycle count in a compact menu bar dropdown.
- **Power Flow Diagram** — Dynamic Sankey visualization of real-time power distribution across charger, battery, and system.
- **MagSafe LED Control** — Automatically sets your MagSafe LED indicator to green when at charge limit and orange while actively charging.
- **Multi-Language Support** — Fully localized across 17 languages (including English, German, Spanish, French, Italian, Dutch, Brazilian & European Portuguese, Simplified & Traditional Chinese, Japanese, Korean, Russian, Turkish, Vietnamese, Slovak, and Slovenian) with an in-app language switcher.
- **Helper Daemon Management** — Inspect status, reinstall, or remove the privileged SMC helper daemon (`com.dinanathdash.stasis.charging-helper`) directly from Settings.
- **Auto-Updates** — Seamless background updates directly from GitHub Releases via Sparkle.
- **Liquid Glass Interface** — Modern macOS Tahoe-inspired translucent settings UI with native macOS dialogs.

---

## Installation

### Homebrew (Recommended)

```bash
brew tap dinanathdash/stasis https://github.com/DinanathDash/Stasis.git
brew install --cask --no-quarantine dinanathdash/stasis/stasis
```

If macOS blocks launch after installation, remove the quarantine flag manually:

```bash
xattr -dr com.apple.quarantine /Applications/Stasis.app
```

### Direct Download

1. Download the latest release from [GitHub Releases](https://github.com/DinanathDash/Stasis/releases).
2. Open the `.dmg` file and drag **Stasis** into `/Applications`.
3. Remove the quarantine flag from Terminal:
   ```bash
   xattr -cr /Applications/Stasis.app
   ```
4. Launch Stasis from `/Applications`.

---

## Key Features & Automations

### 1. Apple Shortcuts & Siri Integration
Stasis registers native App Intents and Siri Shortcuts:
- **`Get Battery Status`**: Retrieve real-time battery percentage, charging state, wattage, voltage, amperage, temperature, and health metrics.
- **`Set Charge Limit`**: Programmatically change the hardware charge limit (50%–100%).
- **`Toggle Top-Up to 100%`**: Enable or disable Charge Limit Override to temporarily charge to 100%.
- **`Toggle Sailing Mode`** & **`Set Sailing Mode Limit`**: Enable/disable Sailing Mode and set float thresholds.
- **`Toggle Force Discharge`**: Run your MacBook on battery power while plugged in.
- **`Start / Cancel Battery Calibration`**: Initiate or stop an automated calibration cycle.
- **`Toggle Heat Protection`** & **`Set Heat Protection Temperature`**: Manage thermal limits.
- **`Open Dashboard`**: Open the menu bar dropdown or Settings window programmatically.

### 2. Apps Using Significant Energy
Stasis monitors running macOS applications in real-time to identify high-energy consumers:
- Displayed directly in the menu bar popover dashboard for immediate visibility.
- Toggleable in **Settings → Dashboard → Status** (`Apps using significant energy`).

### 3. Battery Calibration Service
Over time, battery gauge readings can drift. Stasis includes an interactive Battery Calibration Service:
- Guided cycle: **Discharge to 15% → Recharge to 100% → Rest at 100%**.
- Interactive system notifications guide you when to plug in or disconnect power.
- Managed from **Settings → Calibration**.

### 4. Dynamic Island Notch HUD
For MacBooks with a hardware camera notch (or simulated notch):
- Displays elegant, animated status pills for charging state changes, charge limit notifications, and power alerts.
- Uses `TopWindowElevator` to ensure notifications remain visible above full-screen apps, menu bars, and lock screens.

### 5. Multi-Port Detection & Precision Power
- Identifies connected power accessories (MagSafe 3, USB-C Power Delivery, USB Hubs, and external displays) with custom iconography.
- Enable **Two-Decimal Power Precision** in **Settings → Dashboard** for 0.01W / 0.01A accuracy.

### 6. Helper Daemon Management
- Stasis uses a lightweight privileged helper daemon (`com.dinanathdash.stasis.charging-helper`) to communicate securely with the Apple Silicon SMC.
- Inspect daemon status, reinstall, or uninstall the daemon directly from **Settings → General**.

---

## Automation, Shortcuts & CLI (`stasis://`)

Stasis supports universal automation via custom URL schemes (`stasis://...`) and shell commands. This allows reliable integration with **Apple Shortcuts** (via the built-in **Open URL** action), **Terminal scripts**, **Raycast**, and **Alfred**—working across all builds (including GitHub releases) without requiring an Apple Developer Account.

For step-by-step Apple Shortcuts setup, CLI examples, and the full command table (`stasis://charge-limit?value=80`, `stasis://topup`, `stasis://sailing`, etc.), see the **[Stasis Automation & Apple Shortcuts Guide](SHORTCUTS_AND_AUTOMATION.md)** or check the in-app **Settings → Shortcuts & Help** tab.

---

## Documentation & Wiki

For comprehensive user guides, automation workflows, technical architecture, and FAQ, see the official **[Stasis GitHub Wiki](https://github.com/DinanathDash/Stasis/wiki)** and **[SHORTCUTS_AND_AUTOMATION.md](SHORTCUTS_AND_AUTOMATION.md)**.

---

## Building from Source

```bash
git clone https://github.com/DinanathDash/Stasis.git
cd Stasis
open stasis.xcodeproj
```

- Requires macOS 15.7+ and Xcode with Swift 6+ support.
- Dependencies resolve automatically via Swift Package Manager.
- To test local builds with automatic replacement of `/Applications/Stasis.app`, use our developer build script:
  ```bash
  ./build_and_install.sh
  ```

---

## Contributing

PRs are welcome! Please review our **[Contributing Guide](CONTRIBUTING.md)** and open an issue first for large changes or feature discussions.

---

## Acknowledgments

- [SMCKit](https://github.com/srimanachanta/SMCKit) — SMC access library
- [AsahiLinux](https://asahilinux.org/) — SMC key reverse engineering
- [Battery-Toolkit](https://github.com/mhaeuser/Battery-Toolkit) — SMC key documentation
- [Sparkle](https://sparkle-project.org/) — Secure and reliable software updates
- [Defaults](https://github.com/sindresorhus/Defaults) — Strongly-typed UserDefaults

---

## License

[GPL-3.0](LICENSE)
