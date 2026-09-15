import AppKit
import SwiftUI

struct BatteryIndicatorView: View {
    let batteryLevel: Int
    let chargingMode: ChargingMode
    var isLowPowerModeEnabled: Bool = false
    var batteryPercentageVisibility: BatteryPercentageVisibility = .insideIcon
    var showState: Bool = true

    private var isPowered: Bool {
        chargingMode != .discharging
    }

    private var shouldShowInsidePercentage: Bool {
        batteryPercentageVisibility == .insideIcon || (batteryPercentageVisibility == .insideIconAndNextToItWhenPowered && !isPowered)
    }

    private var shouldShowOutsidePercentage: Bool {
        switch batteryPercentageVisibility {
        case .hidden:
            return false
        case .nextToIcon:
            return true
        case .insideIcon:
            return false
        case .insideIconAndNextToItWhenPowered:
            return isPowered
        }
    }

    private var fillColor: Color {
        if showState && batteryLevel <= 10 && chargingMode == .discharging {
            return .red
        }
        if isLowPowerModeEnabled {
            // Standard LPM yellow
            return Color(red: 1.0, green: 214 / 255, blue: 0.0)
        }
        return .primary
    }

    private enum Layout {
        static let batteryHeight: CGFloat = 12.5
        static let batteryWidth: CGFloat = 24.5
        static let terminalWidth: CGFloat = 1.5
        static let terminalHeight: CGFloat = 5.0
        static let cornerRadius: CGFloat = 4.0
    }

    private var menuBarPercentageFont: Font {
        Font.system(size: 12, weight: .medium)
    }

    var body: some View {
        HStack(spacing: 4) {
            if shouldShowOutsidePercentage {
                Text(batteryLevel.formattedPercentage)
                    .font(menuBarPercentageFont)
                    .fontWeight(.regular)
                    .monospacedDigit()
            }

            HStack(spacing: 1) {
                // Battery Body
                Canvas { context, size in
                    let rect = CGRect(origin: .zero, size: size)
                    let clipPath = Path(roundedRect: rect, cornerRadius: Layout.cornerRadius)
                    context.clip(to: clipPath)
                    
                    // We must use a transparency layer so .destinationOut punches through the drawn shapes, not ignored.
                    context.drawLayer { layerContext in
                        // Empty background - slightly more whitish tone (opacity 0.50)
                        layerContext.fill(clipPath, with: .color(Color.primary.opacity(0.50)))
                        
                        // Filled part
                        let fillWidth = max(0, size.width * CGFloat(batteryLevel) / 100)
                        let fillRect = CGRect(x: 0, y: 0, width: fillWidth, height: size.height)
                        layerContext.fill(Path(fillRect), with: .color(fillColor))
                        
                        // Punch-out text/icon using Canvas blending
                        if shouldShowInsidePercentage || (showState && isPowered) {
                            layerContext.blendMode = .destinationOut
                            
                            let textWidth: CGFloat
                            let gap: CGFloat = 0.5
                            
                            if shouldShowInsidePercentage, let textSymbol = layerContext.resolveSymbol(id: "text") {
                                textWidth = textSymbol.size.width
                            } else {
                                textWidth = 0
                            }
                            
                            let iconSize: CGSize
                            let isPlug = (showState && chargingMode == .pluggedIn)
                            
                            if isPowered, let iconSymbol = layerContext.resolveSymbol(id: isPlug ? "plug" : "bolt") {
                                // Plug is rotated -90 degrees, so its visual width is its layout height
                                iconSize = isPlug ? CGSize(width: iconSymbol.size.height, height: iconSymbol.size.width) : iconSymbol.size
                            } else {
                                iconSize = .zero
                            }
                            
                            let totalWidth = (textWidth > 0 ? textWidth : 0) + (textWidth > 0 && iconSize.width > 0 ? gap : 0) + iconSize.width
                            let startX = (size.width - totalWidth) / 2
                            
                            if shouldShowInsidePercentage, let textSymbol = layerContext.resolveSymbol(id: "text") {
                                let textX = startX + textWidth / 2
                                layerContext.draw(textSymbol, at: CGPoint(x: textX, y: size.height / 2), anchor: .center)
                            }
                            
                            if isPowered {
                                let iconX = startX + (textWidth > 0 ? textWidth + gap : 0) + iconSize.width / 2
                                if isPlug, let plugSymbol = layerContext.resolveSymbol(id: "plug") {
                                    var plugContext = layerContext
                                    plugContext.translateBy(x: iconX, y: size.height / 2)
                                    plugContext.rotate(by: .degrees(-90))
                                    plugContext.draw(plugSymbol, at: .zero, anchor: .center)
                                } else if let boltSymbol = layerContext.resolveSymbol(id: "bolt") {
                                    layerContext.draw(boltSymbol, at: CGPoint(x: iconX, y: size.height / 2), anchor: .center)
                                }
                            }
                        }
                    }
                } symbols: {
                    if shouldShowInsidePercentage {
                        Text("\(batteryLevel)")
                            .font(.system(size: 10, weight: .semibold))
                            .fixedSize()
                            .tag("text")
                            .foregroundStyle(.black)
                    }
                    
                    if showState && chargingMode == .charging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: shouldShowInsidePercentage ? 7.5 : 10.5, weight: .semibold))
                            .tag("bolt")
                            .foregroundStyle(.black)
                    } else if showState && chargingMode == .pluggedIn {
                        Image(systemName: "powerplug.fill")
                            .font(.system(size: shouldShowInsidePercentage ? 7.0 : 10.0, weight: .semibold))
                            .tag("plug")
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: Layout.batteryWidth, height: Layout.batteryHeight)

                // Battery Terminal
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 1.5,
                    topTrailingRadius: 1.5
                )
                .fill(Color.primary.opacity(0.4))
                .frame(width: Layout.terminalWidth, height: Layout.terminalHeight)
            }
        }
        .foregroundStyle(.primary)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        ForEach([100, 80, 50, 20, 10, 5], id: \.self) { level in
            HStack(spacing: 20) {
                BatteryIndicatorView(
                    batteryLevel: level,
                    chargingMode: .discharging,
                    batteryPercentageVisibility: .insideIcon
                )
                BatteryIndicatorView(
                    batteryLevel: level,
                    chargingMode: .charging,
                    batteryPercentageVisibility: .insideIcon
                )
                BatteryIndicatorView(
                    batteryLevel: level,
                    chargingMode: .discharging,
                    isLowPowerModeEnabled: true,
                    batteryPercentageVisibility: .insideIcon
                )
            }
        }
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}
