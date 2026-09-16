import AppKit
import SwiftUI

struct BatteryIndicatorView: View {
    let batteryLevel: Int
    let chargingMode: ChargingMode
    var isLowPowerModeEnabled: Bool = false
    var batteryPercentageVisibility: BatteryPercentageVisibility = .insideIcon
    var showState: Bool = true

    @Environment(\.colorScheme) var colorScheme

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
                    
                    let drawElements: (inout GraphicsContext, String, Bool, Bool) -> Void = { ctx, tagSuffix, drawText, drawIcon in
                        let textWidth: CGFloat
                        let gap: CGFloat = 0.5
                        
                        if shouldShowInsidePercentage, let textSymbol = ctx.resolveSymbol(id: "text_" + tagSuffix) {
                            textWidth = textSymbol.size.width
                        } else {
                            textWidth = 0
                        }
                        
                        let iconSize: CGSize
                        let isPlug = (showState && chargingMode == .pluggedIn)
                        
                        if isPowered, let iconSymbol = ctx.resolveSymbol(id: (isPlug ? "plug_" : "bolt_") + tagSuffix) {
                            iconSize = isPlug ? CGSize(width: iconSymbol.size.height, height: iconSymbol.size.width) : iconSymbol.size
                        } else {
                            iconSize = .zero
                        }
                        
                        let totalWidth = (textWidth > 0 ? textWidth : 0) + (textWidth > 0 && iconSize.width > 0 ? gap : 0) + iconSize.width
                        let startX = (size.width - totalWidth) / 2
                        
                        if drawText && shouldShowInsidePercentage, let textSymbol = ctx.resolveSymbol(id: "text_" + tagSuffix) {
                            let textX = startX + textWidth / 2
                            ctx.draw(textSymbol, at: CGPoint(x: textX, y: size.height / 2), anchor: .center)
                        }
                        
                        if drawIcon && isPowered {
                            let iconX = startX + (textWidth > 0 ? textWidth + gap : 0) + iconSize.width / 2
                            if isPlug, let plugSymbol = ctx.resolveSymbol(id: "plug_" + tagSuffix) {
                                var plugContext = ctx
                                plugContext.translateBy(x: iconX, y: size.height / 2)
                                plugContext.rotate(by: .degrees(-90))
                                plugContext.draw(plugSymbol, at: .zero, anchor: .center)
                            } else if let boltSymbol = ctx.resolveSymbol(id: "bolt_" + tagSuffix) {
                                ctx.draw(boltSymbol, at: CGPoint(x: iconX, y: size.height / 2), anchor: .center)
                            }
                        }
                    }
                    
                    context.drawLayer { layerContext in
                        // Empty background - light outline tone (opacity 0.25)
                        layerContext.fill(clipPath, with: .color(Color.primary.opacity(0.25)))
                        
                        let fillWidth = max(0, size.width * CGFloat(batteryLevel) / 100)
                        let fillRect = CGRect(x: 0, y: 0, width: fillWidth, height: size.height)
                        
                        let isNormalFill = !(showState && batteryLevel <= 10 && chargingMode == .discharging) && !isLowPowerModeEnabled
                        
                        if isNormalFill {
                            // Text over empty part (primary color)
                            var emptyContext = layerContext
                            drawElements(&emptyContext, "primary", true, false)
                            
                            // Filled part
                            layerContext.fill(Path(fillRect), with: .color(fillColor))
                            
                            // Text over filled part (destinationOut hole)
                            var fillMaskContext = layerContext
                            fillMaskContext.clip(to: Path(fillRect))
                            fillMaskContext.blendMode = .destinationOut
                            drawElements(&fillMaskContext, "inverse", true, false)
                            
                            // Icon over everything (destinationOut hole)
                            var iconContext = layerContext
                            iconContext.blendMode = .destinationOut
                            drawElements(&iconContext, "inverse", false, true)
                        } else {
                            // Filled part
                            layerContext.fill(Path(fillRect), with: .color(fillColor))
                            
                            // Text and Icon over everything (black)
                            var allContext = layerContext
                            drawElements(&allContext, "black", true, true)
                        }
                    }
                } symbols: {
                    ForEach(["primary", "inverse", "black"], id: \.self) { suffix in
                        let color: Color = {
                            if suffix == "primary" { return .primary }
                            if suffix == "inverse" { return colorScheme == .dark ? .black : .white }
                            return .black
                        }()
                        
                        if shouldShowInsidePercentage {
                            Text("\(batteryLevel)")
                                .font(.system(size: 10, weight: .semibold))
                                .fixedSize()
                                .tag("text_\(suffix)")
                                .foregroundStyle(color)
                        }
                        
                        if showState && chargingMode == .charging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: shouldShowInsidePercentage ? 7.5 : 10.5, weight: .semibold))
                                .tag("bolt_\(suffix)")
                                .foregroundStyle(color)
                        } else if showState && chargingMode == .pluggedIn {
                            Image(systemName: "powerplug.fill")
                                .font(.system(size: shouldShowInsidePercentage ? 7.0 : 10.0, weight: .semibold))
                                .tag("plug_\(suffix)")
                                .foregroundStyle(color)
                        }
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
