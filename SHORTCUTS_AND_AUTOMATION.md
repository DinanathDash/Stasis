# Stasis Automation & Apple Shortcuts Guide

Stasis provides powerful automation options via **Custom URL Schemes (`stasis://...`)** and **Command-Line (CLI)** triggers. This allows 100% reliable integration with **Apple Shortcuts**, **Raycast**, **Alfred**, **Hammerspoon**, and **Terminal scripts**, without requiring an Apple Developer Account or hitting macOS code-signing restrictions.

---

## 1. Why Use URL Scheme (`stasis://`) Automation?

When downloading ad-hoc signed releases from GitHub (without an Apple Developer Program certificate), macOS security restricts out-of-process XPC communication for native App Intents (`BackgroundShortcutRunner`).

By using Stasis's **`stasis://` URL Scheme**, you bypass these restrictions entirely. The macOS CoreServices URL router delivers commands directly to the running Stasis application in-process with zero friction.

---

## 2. Using Stasis in Apple's Shortcuts App

You can build custom workflows in the macOS **Shortcuts** app in just a few clicks:

1. Open the **Shortcuts** app on your Mac.
2. Create a new Shortcut.
3. Search for and add the **Open URL** action.
4. Paste any command from the table below into the URL field (for example: `stasis://charge-limit?value=80`).
5. Run your shortcut via menu bar, keyboard shortcut, Dock icon, or Siri!

```
+-------------------------------------------------------------+
| [Shortcuts App]                                             |
|                                                             |
|   Open URL [ stasis://charge-limit?value=80 ]               |
|                                                             |
+-------------------------------------------------------------+
```

---

## 3. Command-Line & Scripting Usage (`open`)

You can trigger any Stasis command from **Terminal**, **Bash / Zsh scripts**, **AppleScript**, **Raycast**, or **Alfred** using the macOS `open` command:

```bash
# Example: Set battery charge limit to 80%
open "stasis://charge-limit?value=80"

# Example: Enable Top-Up to 100%
open "stasis://topup?enable=true"

# Example: Toggle Sailing Mode
open "stasis://sailing"
```

In AppleScript:
```applescript
do shell script "open 'stasis://charge-limit?value=80'"
```

---

## 4. Complete URL Scheme Reference

Every Stasis command supports both full parameter assignment (`?enable=true`/`false`) and automatic toggling when omitted.

> **Note on macOS 27+ Compatibility:** Manual charging controls marked with an asterisk (*) are gracefully disabled on macOS 27 due to OS-level restrictions where Apple has locked down SMC keys, preventing forced discharging below the system's 80% charge limit.

| Action | URL Scheme Command | Example Terminal Command |
| :--- | :--- | :--- |
| **Open Dashboard** | `stasis://dashboard` | `open "stasis://dashboard"` |
| **Open Menu Bar Dialog** | `stasis://menu` | `open "stasis://menu"` |
| **Get Battery Status** | `stasis://status` | `open "stasis://status"` |
| **Set Charge Limit** | `stasis://charge-limit?value=80` | `open "stasis://charge-limit?value=80"` |
| **Toggle Top-Up to 100%** * | `stasis://topup?enable=true` | `open "stasis://topup?enable=true"` |
| **Toggle Sailing Mode** * | `stasis://sailing?enable=true` | `open "stasis://sailing?enable=true"` |
| **Set Sailing Mode Range** * | `stasis://sailing-limit?value=5` | `open "stasis://sailing-limit?value=5"` |
| **Toggle Force Discharge** * | `stasis://force-discharge?enable=true` | `open "stasis://force-discharge?enable=true"` |
| **Start Battery Calibration** | `stasis://calibrate?action=start` | `open "stasis://calibrate?action=start"` |
| **Cancel Battery Calibration**| `stasis://calibrate?action=cancel`| `open "stasis://calibrate?action=cancel"`|
| **Toggle Heat Protection** | `stasis://heat-protection?enable=true` | `open "stasis://heat-protection?enable=true"` |
| **Set Heat Protection Limit** | `stasis://heat-protection-limit?value=35` | `open "stasis://heat-protection-limit?value=35"` |
| **Toggle MagSafe LED Control**| `stasis://magsafe-led?enable=true` | `open "stasis://magsafe-led?enable=true"` |

---

## 5. Visual Notifications & Feedback

Whenever any `stasis://` command is triggered, Stasis delivers a clean macOS **Desktop Notification** confirming the action and displaying real-time system power metrics (battery percentage, wattage, temperature, and health).

---

## 6. Native App Intents & Xcode Development

For developers compiling Stasis locally in Xcode (or for future builds signed with an Apple Developer ID certificate), all **12 native App Intents** (`Stasis/Intents/*.swift`) remain fully functional and available inside Siri and the Shortcuts App Intent library.
