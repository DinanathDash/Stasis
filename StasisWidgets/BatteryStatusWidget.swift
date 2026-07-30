import SwiftUI
import WidgetKit

extension WidgetStatusData {
    var chargingModeEnum: ChargingMode {
        switch chargingModeRaw {
        case "charging": return .charging
        case "discharging": return .discharging
        default: return .pluggedIn
        }
    }
}

struct StatusPillView: View {
    let data: WidgetStatusData

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .bold))
            Text(statusText)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.primary.opacity(0.12)))
        .foregroundColor(.primary)
    }

    private var iconName: String {
        if data.isTopUpActive { return "bolt.fill" }
        if data.isSailingMode { return "sailboat.fill" }
        if data.isCharging { return "bolt.fill" }
        if data.isPluggedIn { return "powerplug.fill" }
        return "battery.100"
    }

    private var statusText: String {
        if data.isTopUpActive { return "Top-Up" }
        if data.isSailingMode { return "Sailing" }
        if data.isCharging { return "Charging" }
        if data.isPluggedIn { return "On hold" }
        return "On battery"
    }
}

// MARK: - Small View (.systemSmall)
struct BatteryStatusWidgetSmallView: View {
    let data: WidgetStatusData

    var body: some View {
        VStack(spacing: 8) {
            BatteryIndicatorView(
                batteryLevel: data.percentage,
                chargingMode: data.chargingModeEnum,
                isLowPowerModeEnabled: false,
                batteryPercentageVisibility: .hidden,
                showState: true
            )
            .scaleEffect(1.9)
            .frame(height: 38)
            .padding(.top, 4)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(data.percentage)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("%")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            StatusPillView(data: data)
        }
        .padding(4)
    }
}

// MARK: - Medium View (.systemMedium)
struct BatteryStatusWidgetMediumView: View {
    let data: WidgetStatusData

    var body: some View {
        HStack(spacing: 20) {
            VStack(spacing: 8) {
                BatteryIndicatorView(
                    batteryLevel: data.percentage,
                    chargingMode: data.chargingModeEnum,
                    isLowPowerModeEnabled: false,
                    batteryPercentageVisibility: .hidden,
                    showState: true
                )
                .scaleEffect(1.8)
                .frame(height: 34)
                .padding(.top, 2)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(data.percentage)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("%")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                StatusPillView(data: data)
            }
            .frame(width: 125)

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("\(data.batteryHealth)% Health", systemImage: "heart.fill")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Label("\(String(format: "%.1f", data.batteryTemperature))°C", systemImage: "thermometer.medium")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    Button(intent: ToggleTopUpIntent()) {
                        HStack {
                            Image(systemName: data.isTopUpActive ? "bolt.fill.batteryblock.fill" : "bolt.batteryblock")
                                .font(.system(size: 11, weight: .bold))
                            Text(data.isTopUpActive ? "Cancel Top-Up" : "Top-Up 100%")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(data.isTopUpActive ? Color.accentColor : Color.primary.opacity(0.10)))
                        .foregroundColor(data.isTopUpActive ? .white : .primary)
                    }
                    .buttonStyle(.plain)

                    Button(intent: ToggleSailingModeIntent()) {
                        HStack {
                            Image(systemName: "sailboat.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(data.isSailingMode ? "Sailing On" : "Sailing Off")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(data.isSailingMode ? Color.accentColor : Color.primary.opacity(0.10)))
                        .foregroundColor(data.isSailingMode ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
    }
}

// MARK: - Large View (.systemLarge)
struct BatteryStatusWidgetLargeView: View {
    let data: WidgetStatusData

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack(alignment: .center, spacing: 14) {
                BatteryIndicatorView(
                    batteryLevel: data.percentage,
                    chargingMode: data.chargingModeEnum,
                    isLowPowerModeEnabled: false,
                    batteryPercentageVisibility: .hidden,
                    showState: true
                )
                .scaleEffect(1.7)
                .frame(width: 50, height: 28)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(data.percentage)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("%")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusPillView(data: data)
            }

            Divider()

            // Metrics Grid (2x2)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricCardView(title: "Battery Health", value: "\(data.batteryHealth)%", icon: "heart.fill", color: .green)
                MetricCardView(title: "Cycle Count", value: "\(data.cycleCount)", icon: "arrow.triangle.2.circlepath", color: .blue)
                MetricCardView(title: "Temperature", value: "\(String(format: "%.1f", data.batteryTemperature))°C", icon: "thermometer.medium", color: .orange)
                MetricCardView(title: "Active Limit", value: "\(data.chargeLimit)%", icon: "gauge.medium", color: .purple)
            }

            // Interactive Toggles Row (No Spacer shoving to bottom)
            HStack(spacing: 10) {
                Button(intent: ToggleTopUpIntent()) {
                    HStack {
                        Image(systemName: data.isTopUpActive ? "bolt.fill.batteryblock.fill" : "bolt.batteryblock")
                            .font(.system(size: 11, weight: .bold))
                        Text(data.isTopUpActive ? "Top-Up Active" : "Top-Up 100%")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(data.isTopUpActive ? Color.accentColor : Color.primary.opacity(0.10)))
                    .foregroundColor(data.isTopUpActive ? .white : .primary)
                }
                .buttonStyle(.plain)

                Button(intent: ToggleSailingModeIntent()) {
                    HStack {
                        Image(systemName: "sailboat.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(data.isSailingMode ? "Sailing On" : "Sailing Off")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(data.isSailingMode ? Color.accentColor : Color.primary.opacity(0.10)))
                    .foregroundColor(data.isSailingMode ? .white : .primary)
                }
                .buttonStyle(.plain)
            }

            // Charge Limit Preset Selector
            VStack(alignment: .leading, spacing: 4) {
                Text("Quick Charge Limit")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach([50, 80, 100], id: \.self) { preset in
                        Button(intent: SetChargeLimitIntent(limit: preset)) {
                            Text("\(preset)%")
                                .font(.system(size: 11, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(data.chargeLimit == preset ? Color.primary.opacity(0.24) : Color.primary.opacity(0.08))
                                )
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
    }
}

struct MetricCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Widget Definition
struct BatteryStatusWidget: Widget {
    let kind: String = "com.dinanathdash.stasis.BatteryStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StasisWidgetProvider()) { entry in
            BatteryStatusWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(NSColor.windowBackgroundColor)
                }
        }
        .configurationDisplayName("Battery Status")
        .description("View real-time battery status, health, and quick charge controls.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct BatteryStatusWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: StasisWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            BatteryStatusWidgetSmallView(data: entry.data)
        case .systemMedium:
            BatteryStatusWidgetMediumView(data: entry.data)
        case .systemLarge:
            BatteryStatusWidgetLargeView(data: entry.data)
        default:
            BatteryStatusWidgetMediumView(data: entry.data)
        }
    }
}
