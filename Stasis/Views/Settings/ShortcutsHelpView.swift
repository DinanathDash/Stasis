import AppKit
import SwiftUI

struct ShortcutItem: Identifiable {
    let id = UUID()
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let urlString: String
    let exampleCLI: String
}

struct ShortcutsHelpView: View {
    @State private var copiedURL: String? = nil

    private let shortcuts: [ShortcutItem] = [
        ShortcutItem(
            title: "Open Dashboard",
            description: "Open the main Stasis dashboard and settings window.",
            urlString: "stasis://dashboard",
            exampleCLI: "open \"stasis://dashboard\""
        ),
        ShortcutItem(
            title: "Open Menu Bar Dialog",
            description: "Open the Stasis menu bar dropdown dialog from anywhere.",
            urlString: "stasis://menu",
            exampleCLI: "open \"stasis://menu\""
        ),
        ShortcutItem(
            title: "Get Battery Status",
            description: "Show a banner notification with percentage, charging mode, wattage, health, and temperature.",
            urlString: "stasis://status",
            exampleCLI: "open \"stasis://status\""
        ),
        ShortcutItem(
            title: "Set Charge Limit",
            description: "Set the maximum battery charging limit (50 to 100 percent).",
            urlString: "stasis://charge-limit?value=80",
            exampleCLI: "open \"stasis://charge-limit?value=80\""
        ),
        ShortcutItem(
            title: "Toggle Top-Up to 100 percent",
            description: "Temporarily override the limit and charge to 100 percent (or cancel Top-Up).",
            urlString: "stasis://topup?enable=true",
            exampleCLI: "open \"stasis://topup?enable=true\""
        ),
        ShortcutItem(
            title: "Toggle Sailing Mode",
            description: "Enable or disable Sailing Mode (allow battery to discharge naturally before recharging).",
            urlString: "stasis://sailing?enable=true",
            exampleCLI: "open \"stasis://sailing?enable=true\""
        ),
        ShortcutItem(
            title: "Set Sailing Mode Range",
            description: "Set the Sailing Mode drop percentage below the charge limit (5 to 20 percent).",
            urlString: "stasis://sailing-limit?value=5",
            exampleCLI: "open \"stasis://sailing-limit?value=5\""
        ),
        ShortcutItem(
            title: "Toggle Force Discharge",
            description: "Enable or disable force discharging the battery while plugged into AC power.",
            urlString: "stasis://force-discharge?enable=true",
            exampleCLI: "open \"stasis://force-discharge?enable=true\""
        ),
        ShortcutItem(
            title: "Start Battery Calibration",
            description: "Start a full battery calibration cycle in Stasis.",
            urlString: "stasis://calibrate?action=start",
            exampleCLI: "open \"stasis://calibrate?action=start\""
        ),
        ShortcutItem(
            title: "Cancel Battery Calibration",
            description: "Cancel an ongoing battery calibration cycle.",
            urlString: "stasis://calibrate?action=cancel",
            exampleCLI: "open \"stasis://calibrate?action=cancel\""
        ),
        ShortcutItem(
            title: "Toggle Heat Protection",
            description: "Enable or disable Heat Protection Mode.",
            urlString: "stasis://heat-protection?enable=true",
            exampleCLI: "open \"stasis://heat-protection?enable=true\""
        ),
        ShortcutItem(
            title: "Set Heat Protection Threshold",
            description: "Set the temperature threshold for Heat Protection Mode (30°C to 50°C).",
            urlString: "stasis://heat-protection-limit?value=35",
            exampleCLI: "open \"stasis://heat-protection-limit?value=35\""
        ),
        ShortcutItem(
            title: "Toggle MagSafe LED Control",
            description: "Enable or disable custom MagSafe LED color indication.",
            urlString: "stasis://magsafe-led?enable=true",
            exampleCLI: "open \"stasis://magsafe-led?enable=true\""
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shortcuts & Automation")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Stasis supports custom URL schemes (**stasis://**) and command-line automation. This is a 100 percent reliable, universal automation system that works in Apple Shortcuts, Raycast, Alfred, and Terminal scripts—without needing an Apple Developer Account.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Apple Shortcuts Guide Card
                VStack(alignment: .leading, spacing: 12) {
                    Label("How to use in Apple's Shortcuts App", systemImage: "bolt.fill")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        StepView(step: 1, text: "Open Apple's **Shortcuts** app on your Mac.")
                        StepView(step: 2, text: "Create a new Shortcut and add the **Open URL** action.")
                        StepView(step: 3, text: "Paste any Stasis URL from the reference list below (e.g., `stasis://charge-limit?value=80`).")
                        StepView(step: 4, text: "Run your Shortcut from your Menu Bar, Keyboard Shortcut, Dock, or Siri!")
                    }
                    .padding(.top, 4)
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)

                // Terminal / Script Guide Card
                VStack(alignment: .leading, spacing: 8) {
                    Label("CLI & Terminal Usage", systemImage: "terminal.fill")
                        .font(.headline)

                    Text("You can run any Stasis command from Terminal, shell scripts, Raycast, or Alfred using the `open` command:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(verbatim: "open \"stasis://charge-limit?value=80\"")
                        .font(.system(.footnote, design: .monospaced))
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)

                Text("URL Scheme Reference")
                    .font(.headline)
                    .padding(.top, 4)

                // Shortcuts Reference Table
                VStack(spacing: 10) {
                    ForEach(shortcuts) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Spacer()

                                HStack(spacing: 6) {
                                    Button {
                                        copyToClipboard(item.urlString)
                                    } label: {
                                        Label(copiedURL == item.urlString ? "Copied" : "Copy URL", systemImage: copiedURL == item.urlString ? "checkmark" : "doc.on.doc")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)

                                    Button {
                                        if let url = URL(string: item.urlString) {
                                            StasisURLHandler.shared.handleURL(url)
                                        }
                                    } label: {
                                        Label("Test", systemImage: "play.fill")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }

                            Text(item.description)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(item.urlString)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.accentColor)
                                .textSelection(.enabled)
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(24)
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation {
            copiedURL = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                if copiedURL == text {
                    copiedURL = nil
                }
            }
        }
    }
}

private struct StepView: View {
    let step: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(step)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.subheadline)
        }
    }
}
