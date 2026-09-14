import AppKit
import SwiftUI

final class DynamicallyResizingHostingView<V: View>: NSHostingView<V> {
    weak var menuItem: NSMenuItem?
    private let menuWidth: CGFloat = 300

    @inline(never)
    deinit {}

    override var fittingSize: NSSize {
        let size = super.fittingSize
        return NSSize(width: menuWidth, height: size.height)
    }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(width: menuWidth, height: size.height)
    }

    override func layout() {
        super.layout()
        if let menuItem = menuItem, let menu = menuItem.menu {
            let currentHeight = fittingSize.height
            if abs(frame.height - currentHeight) > 0.5 {
                frame.size.height = currentHeight
                menu.update()
            }
        }
    }
}

struct SignificantEnergyMenuView: View {
    let service: SignificantEnergyService
    @State private var isExpanded: Bool = false

    private var apps: [SignificantEnergyApp] {
        service.apps
    }

    private var currentContentHeight: CGFloat {
        if apps.isEmpty {
            return 105.0
        } else {
            let rows = min(apps.count, 5)
            return CGFloat(rows) * 28.0
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                    expandedContentView
                }
            }
        }
        .frame(width: 300, alignment: .top)
    }

    private var headerView: some View {
        HStack {
            Text("Significant Energy Apps")
                .foregroundColor(.secondary)
                .font(.callout)
            Spacer(minLength: 16)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            isExpanded.toggle()
        }
    }

    private var expandedContentView: some View {
        Group {
            if apps.isEmpty {
                emptyStateView
            } else {
                appsListView
            }
        }
        .frame(height: currentContentHeight, alignment: .top)
        .clipped()
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.green)
            }
            VStack(spacing: 2) {
                Text("No Significant Energy Apps")
                    .font(.callout.weight(.medium))
                    .foregroundColor(.primary)
                Text("All applications are running efficiently")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var appsListView: some View {
        ScrollView(.vertical, showsIndicators: apps.count > 5) {
            VStack(spacing: 0) {
                ForEach(apps) { app in
                    SignificantEnergyAppRowView(app: app)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.bottom, 4)
    }
}

struct SignificantEnergyAppRowView: View {
    let app: SignificantEnergyApp

    var body: some View {
        Button {
            app.activate()
        } label: {
            HStack(spacing: 10) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundColor(.secondary)
                }
                Text(app.name)
                    .foregroundColor(.primary)
                    .font(.callout)
                    .lineLimit(1)
                Spacer(minLength: 16)
                Text(String(format: "%.1f", app.powerScore))
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundColor(scoreColor(for: app.powerScore))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func scoreColor(for score: Double) -> Color {
        if score >= 30.0 {
            return .red
        } else if score >= 10.0 {
            return .orange
        } else {
            return .blue
        }
    }
}
