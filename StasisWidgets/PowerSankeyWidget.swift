import SwiftUI
import WidgetKit

// MARK: - Dedicated Compact Power Flow Card for Widgets
struct WidgetPowerFlowCard: View {
    let data: WidgetStatusData
    let isCompact: Bool

    var body: some View {
        HStack(spacing: isCompact ? 10 : 14) {
            // Source Node (Adapter or Battery)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: data.isPluggedIn ? "powercord.fill" : "battery.100")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(data.isPluggedIn ? .purple : .green)
                    Text(data.isPluggedIn ? "Adapter" : "Battery")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", abs(data.isPluggedIn ? data.adapterWatts : data.batteryWatts)))
                        .font(.system(size: isCompact ? 16 : 18, weight: .bold, design: .rounded))
                    Text("W")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))

            // Flow Indicator
            VStack(spacing: 2) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                Text("\(data.percentage)%")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 30)

            // Destination Nodes (System & Battery)
            VStack(spacing: isCompact ? 6 : 8) {
                // System Load Box
                HStack {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                    Text("System")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(String(format: "%.1f W", abs(data.systemWatts)))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .padding(8)
                .frame(maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.06)))

                // Battery State Box
                HStack {
                    Image(systemName: "battery.100.bolt")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(data.isCharging ? .green : .blue)
                    Text(data.isCharging ? "Charging" : (data.isPluggedIn ? "Idle" : "Discharging"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(String(format: "%.1f W", abs(data.batteryWatts)))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .padding(8)
                .frame(maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.06)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Medium View (.systemMedium)
struct PowerSankeyWidgetMediumView: View {
    let data: WidgetStatusData

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Power Flow", systemImage: "bolt.horizontal.fill")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                StatusPillView(data: data)
            }

            WidgetPowerFlowCard(data: data, isCompact: true)
        }
        .padding(10)
    }
}

// MARK: - Large View (.systemLarge)
struct PowerSankeyWidgetLargeView: View {
    let data: WidgetStatusData

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Label("Power Flow", systemImage: "bolt.horizontal.fill")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                StatusPillView(data: data)
            }

            // Clean 3-Node Power Flow Visualization
            WidgetPowerFlowCard(data: data, isCompact: false)
                .frame(height: 110)

            // Power Metrics Summary Cards (Never Truncate Title)
            HStack(spacing: 10) {
                PowerMetricCard(title: "Adapter", powerWatts: data.adapterWatts, color: .purple)
                PowerMetricCard(title: "Battery", powerWatts: data.batteryWatts, color: data.isCharging ? .green : .blue)
                PowerMetricCard(title: "System", powerWatts: data.systemWatts, color: .orange)
            }

            // Interactive Mode Toggles (Balanced spacing, no bottom edge shove)
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
        }
        .padding(12)
    }
}

struct PowerMetricCard: View {
    let title: String
    let powerWatts: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", abs(powerWatts)))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text("W")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Widget Definition
struct PowerSankeyWidget: Widget {
    let kind: String = "com.dinanathdash.stasis.PowerSankeyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StasisWidgetProvider()) { entry in
            PowerSankeyWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(NSColor.windowBackgroundColor)
                }
        }
        .configurationDisplayName("Power Sankey Flow")
        .description("View real-time power flow across adapter, battery, and system load.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct PowerSankeyWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: StasisWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            PowerSankeyWidgetMediumView(data: entry.data)
        case .systemLarge:
            PowerSankeyWidgetLargeView(data: entry.data)
        default:
            PowerSankeyWidgetMediumView(data: entry.data)
        }
    }
}
