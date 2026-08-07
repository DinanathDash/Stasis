import Defaults
import SwiftUI

struct PowerSankeyView: View {
    let powerSource: PowerSource
    let isCharging: Bool
    let batteryPower: Double
    let adapterPower: Double
    let systemPower: Double
    let outputPower: Double
    let outputPortPowers: [Double]
    let outputIcons: [String]
    var hasMultiPort: Bool = false
    var connectedAccessories: [AccessoryType] = []
    let adapterConnected: Bool

    private func safeIcon(at index: Int) -> String {
        if index < outputIcons.count {
            return outputIcons[index]
        }
        return "cable.connector"
    }

    private enum Layout {
        static let nodeWidth: CGFloat = 60
        static let gap: CGFloat = 5
        static let spacerHeight: CGFloat = 20
        static let largeNodeHeight: CGFloat = 100
        static let viewHeight: CGFloat = 125
        static let flowOpacity: Double = 0.15
        static let powerLabelSize: CGFloat = 13
        static let powerLabelSpacing: CGFloat = 45
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                flowsAndLabels

                HStack {
                    leftNodes
                    Spacer()
                    rightNodes
                }
            }
        }
        .frame(height: Layout.viewHeight)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func flowLabel(for power: Double, leftY: CGFloat, rightY: CGFloat, width: CGFloat, midX: CGFloat) -> some View {
        let angle = atan2(2 * (rightY - leftY), width)
        return PowerLabel(power: power)
            .rotationEffect(.radians(angle))
            .position(x: midX, y: (leftY + rightY) / 2)
    }

    @ViewBuilder
    private var flowsAndLabels: some View {
        let hasAnyOutput = outputPower > 0
        let hasTwoOutputs = outputPortPowers.count >= 2
        
        switch powerSource {
        case .acAdapter:
            if batteryPower > 0 {
                Canvas { context, size in
                    if outputPower > 0 {
                        drawTripleSplitSankeyFlow(context: context, size: size)
                    } else {
                        drawSplitSankeyFlow(context: context, size: size)
                    }
                }
                GeometryReader { geo in
                    let w = geo.size.width - 2 * (Layout.nodeWidth + Layout.gap)
                    let midX = geo.size.width / 2
                    let H = geo.size.height
                    let LH = Layout.largeNodeHeight
                    let gap = Layout.spacerHeight
                    
                    if outputPower > 0 {
                        let leftTop = (H / 2) - (LH / 2)
                        let left1 = leftTop + LH / 6
                        let left2 = leftTop + LH / 2
                        let left3 = leftTop + 5 * LH / 6
                        
                        let totalGap = gap * 2
                        let segH = (H - totalGap) / 3
                        let right1 = segH / 2
                        let right2 = segH + gap + segH / 2
                        let right3 = (2 * segH) + (2 * gap) + segH / 2
                        
                        flowLabel(for: batteryPower, leftY: left1, rightY: right1, width: w, midX: midX)
                        flowLabel(for: systemPower, leftY: left2, rightY: right2, width: w, midX: midX)
                        flowLabel(for: outputPower, leftY: left3, rightY: right3, width: w, midX: midX)
                    } else {
                        let leftTop = (H / 2) - (LH / 2)
                        let left1 = leftTop + LH / 4
                        let left2 = leftTop + 3 * LH / 4
                        
                        let smallH = (H - gap) / 2
                        let right1 = smallH / 2
                        let right2 = H - smallH / 2
                        
                        flowLabel(for: batteryPower, leftY: left1, rightY: right1, width: w, midX: midX)
                        flowLabel(for: systemPower, leftY: left2, rightY: right2, width: w, midX: midX)
                    }
                }
            } else {
                Canvas { context, size in
                    if outputPortPowers.count >= 2 {
                        drawTripleSplitSankeyFlow(context: context, size: size)
                    } else if outputPower > 0 {
                        drawSplitSankeyFlow(context: context, size: size)
                    } else {
                        drawSimpleFlow(context: context, size: size)
                    }
                }
                GeometryReader { geo in
                    let w = geo.size.width - 2 * (Layout.nodeWidth + Layout.gap)
                    let midX = geo.size.width / 2
                    let H = geo.size.height
                    let LH = Layout.largeNodeHeight
                    let gap = Layout.spacerHeight
                    
                    if outputPortPowers.count >= 2 {
                        let leftTop = (H / 2) - (LH / 2)
                        let left1 = leftTop + LH / 6
                        let left2 = leftTop + LH / 2
                        let left3 = leftTop + 5 * LH / 6
                        
                        let totalGap = gap * 2
                        let segH = (H - totalGap) / 3
                        let right1 = segH / 2
                        let right2 = segH + gap + segH / 2
                        let right3 = (2 * segH) + (2 * gap) + segH / 2
                        
                        flowLabel(for: systemPower, leftY: left1, rightY: right1, width: w, midX: midX)
                        flowLabel(for: outputPortPowers[0], leftY: left2, rightY: right2, width: w, midX: midX)
                        flowLabel(for: outputPortPowers[1], leftY: left3, rightY: right3, width: w, midX: midX)
                    } else if outputPower > 0 {
                        let leftTop = (H / 2) - (LH / 2)
                        let left1 = leftTop + LH / 4
                        let left2 = leftTop + 3 * LH / 4
                        
                        let smallH = (H - gap) / 2
                        let right1 = smallH / 2
                        let right2 = H - smallH / 2
                        
                        flowLabel(for: systemPower, leftY: left1, rightY: right1, width: w, midX: midX)
                        flowLabel(for: outputPower, leftY: left2, rightY: right2, width: w, midX: midX)
                    } else {
                        flowLabel(for: adapterPower, leftY: H / 2, rightY: H / 2, width: w, midX: midX)
                    }
                }
            }

        case .both:
            Canvas { context, size in
                drawMergeSankeyFlow(context: context, size: size)
            }
            GeometryReader { geo in
                let w = geo.size.width - 2 * (Layout.nodeWidth + Layout.gap)
                let midX = geo.size.width / 2
                let H = geo.size.height
                let LH = Layout.largeNodeHeight
                let gap = Layout.spacerHeight
                
                let smallH = (H - gap) / 2
                let left1 = smallH / 2
                let left2 = H - smallH / 2
                
                let right1 = (H / 2) - (LH / 4)
                let right2 = (H / 2) + (LH / 4)
                
                flowLabel(for: batteryPower, leftY: left1, rightY: right1, width: w, midX: midX)
                flowLabel(for: adapterPower, leftY: left2, rightY: right2, width: w, midX: midX)
            }

        case .battery:
            Canvas { context, size in
                if adapterConnected {
                    if hasTwoOutputs {
                        drawTopHalfToTripleSplitSankeyFlow(context: context, size: size)
                    } else if hasAnyOutput {
                        drawTopHalfToSplitSankeyFlow(context: context, size: size)
                    } else {
                        drawTopHalfToCenteredSimpleFlow(context: context, size: size)
                    }
                } else {
                    if hasTwoOutputs {
                        drawTripleSplitSankeyFlow(context: context, size: size)
                    } else if hasAnyOutput {
                        drawSplitSankeyFlow(context: context, size: size)
                    } else {
                        drawSimpleFlow(context: context, size: size)
                    }
                }
            }
            GeometryReader { geo in
                let w = geo.size.width - 2 * (Layout.nodeWidth + Layout.gap)
                let midX = geo.size.width / 2
                let H = geo.size.height
                let LH = Layout.largeNodeHeight
                let gap = Layout.spacerHeight
                
                if adapterConnected {
                    let nodeH = (H - gap) / 2
                    if hasTwoOutputs {
                        let totalGap = gap * 2
                        let segH = (H - totalGap) / 3
                        
                        let left1 = nodeH / 6
                        let right1 = segH / 2
                        
                        let left2 = nodeH / 2
                        let right2 = segH + gap + (segH / 2)
                        
                        let left3 = 5 * nodeH / 6
                        let right3 = (2 * segH) + (2 * gap) + (segH / 2)
                        
                        flowLabel(for: systemPower, leftY: left1, rightY: right1, width: w, midX: midX)
                        flowLabel(for: outputPortPowers[0], leftY: left2, rightY: right2, width: w, midX: midX)
                        flowLabel(for: outputPortPowers[1], leftY: left3, rightY: right3, width: w, midX: midX)
                    } else if hasAnyOutput {
                        let left1 = nodeH / 4
                        let right1 = nodeH / 2
                        
                        let left2 = 3 * nodeH / 4
                        let right2 = H - (nodeH / 2)
                        
                        flowLabel(for: systemPower, leftY: left1, rightY: right1, width: w, midX: midX)
                        flowLabel(for: outputPower, leftY: left2, rightY: right2, width: w, midX: midX)
                    } else {
                        let left1 = nodeH / 2
                        let right1 = H / 2
                        flowLabel(for: systemPower, leftY: left1, rightY: right1, width: w, midX: midX)
                    }
                    
                    // Adapter Label (0W)
                    PowerLabel(power: 0)
                        .opacity(0.3)
                        .position(x: midX, y: H - (nodeH / 2))
                } else {
                    if hasTwoOutputs {
                        let leftTop = (H / 2) - (LH / 2)
                        let left1 = leftTop + LH / 6
                        let left2 = leftTop + LH / 2
                        let left3 = leftTop + 5 * LH / 6
                        
                        let totalGap = gap * 2
                        let segH = (H - totalGap) / 3
                        let right1 = segH / 2
                        let right2 = segH + gap + segH / 2
                        let right3 = (2 * segH) + (2 * gap) + segH / 2
                        
                        flowLabel(for: systemPower, leftY: left1, rightY: right1, width: w, midX: midX)
                        flowLabel(for: outputPortPowers[0], leftY: left2, rightY: right2, width: w, midX: midX)
                        flowLabel(for: outputPortPowers[1], leftY: left3, rightY: right3, width: w, midX: midX)
                    } else if hasAnyOutput {
                        let leftTop = (H / 2) - (LH / 2)
                        let left1 = leftTop + LH / 4
                        let left2 = leftTop + 3 * LH / 4
                        
                        let smallH = (H - gap) / 2
                        let right1 = smallH / 2
                        let right2 = H - smallH / 2
                        
                        flowLabel(for: systemPower, leftY: left1, rightY: right1, width: w, midX: midX)
                        flowLabel(for: outputPower, leftY: left2, rightY: right2, width: w, midX: midX)
                    } else {
                        flowLabel(for: systemPower, leftY: H / 2, rightY: H / 2, width: w, midX: midX)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var leftNodes: some View {
        let hasAnyOutput = outputPower > 0
        VStack(spacing: 0) {
            switch powerSource {
            case .acAdapter:
                if batteryPower > 0 {
                    NodeView(
                        icon: "bolt.fill",
                        value: abs(adapterPower),
                        isLeftSide: true
                    )
                    .frame(height: Layout.largeNodeHeight)
                } else {
                    if hasAnyOutput {
                        NodeView(
                            icon: "powerplug.fill",
                            value: nil,
                            isLeftSide: true
                        )
                        .frame(height: Layout.largeNodeHeight)
                    } else {
                        NodeView(
                            icon: "powerplug.fill",
                            value: nil,
                            isLeftSide: true
                        )
                    }
                }
            case .both:
                NodeView(icon: "battery.100", value: nil, isLeftSide: true)
                Spacer(minLength: Layout.spacerHeight)
                NodeView(icon: "powerplug.fill", value: nil, isLeftSide: true)
            case .battery:
                if adapterConnected {
                    NodeView(icon: "battery.100", value: nil, isLeftSide: true)
                    Spacer(minLength: Layout.spacerHeight)
                    NodeView(icon: "powerplug.fill", value: nil, isLeftSide: true)
                        .opacity(0.3)
                } else {
                    if hasAnyOutput {
                        NodeView(icon: "battery.100", value: nil, isLeftSide: true)
                            .frame(height: Layout.largeNodeHeight)
                    } else {
                        NodeView(icon: "battery.100", value: nil, isLeftSide: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var rightNodes: some View {
        VStack(spacing: 0) {
            let hasTwoOutputs = outputPortPowers.count >= 2
            let hasAnyOutput = outputPower > 0
            switch powerSource {
            case .acAdapter:
                if batteryPower > 0 {
                    NodeView(
                        icon: "battery.100.bolt",
                        value: nil,
                        isLeftSide: false
                    )
                    Spacer(minLength: Layout.spacerHeight)
                    NodeView(
                        icon: "laptopcomputer",
                        value: nil,
                        isLeftSide: false
                    )
                    if outputPower > 0 {
                        Spacer(minLength: Layout.spacerHeight)
                        NodeView(
                            icon: safeIcon(at: 0),
                            value: nil,
                            isLeftSide: false
                        )
                    }
                } else {
                    NodeView(
                        icon: "laptopcomputer",
                        value: nil,
                        isLeftSide: false
                    )
                    if outputPower > 0 {
                        Spacer(minLength: Layout.spacerHeight)
                        NodeView(
                            icon: safeIcon(at: 0),
                            value: nil,
                            isLeftSide: false
                        )
                        if hasTwoOutputs {
                            Spacer(minLength: Layout.spacerHeight)
                            NodeView(
                                icon: safeIcon(at: 1),
                                value: nil,
                                isLeftSide: false
                            )
                        }
                    }
                }
            case .both:
                NodeView(
                    icon: "laptopcomputer",
                    value: systemPower,
                    isLeftSide: false
                )
                .frame(height: Layout.largeNodeHeight)
            case .battery:
                if adapterConnected {
                    if hasTwoOutputs {
                        NodeView(icon: "laptopcomputer", value: nil, isLeftSide: false)
                        Spacer(minLength: Layout.spacerHeight)
                        NodeView(icon: safeIcon(at: 0), value: nil, isLeftSide: false)
                        Spacer(minLength: Layout.spacerHeight)
                        NodeView(icon: safeIcon(at: 1), value: nil, isLeftSide: false)
                    } else if hasAnyOutput {
                        NodeView(icon: "laptopcomputer", value: nil, isLeftSide: false)
                        Spacer(minLength: Layout.spacerHeight)
                        NodeView(icon: safeIcon(at: 0), value: nil, isLeftSide: false)
                    } else {
                        NodeView(icon: "laptopcomputer", value: nil, isLeftSide: false)
                            .frame(height: (Layout.viewHeight - Layout.spacerHeight) / 2)
                    }
                } else {
                    if hasTwoOutputs {
                        NodeView(icon: "laptopcomputer", value: nil, isLeftSide: false)
                        Spacer(minLength: Layout.spacerHeight)
                        NodeView(icon: safeIcon(at: 0), value: nil, isLeftSide: false)
                        Spacer(minLength: Layout.spacerHeight)
                        NodeView(icon: safeIcon(at: 1), value: nil, isLeftSide: false)
                    } else if hasAnyOutput {
                        NodeView(icon: "laptopcomputer", value: nil, isLeftSide: false)
                        Spacer(minLength: Layout.spacerHeight)
                        NodeView(icon: safeIcon(at: 0), value: nil, isLeftSide: false)
                    } else {
                        NodeView(icon: "laptopcomputer", value: nil, isLeftSide: false)
                    }
                }
            }
        }
    }

    private func drawMergeSankeyFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap
        let smallHeight = (size.height - Layout.spacerHeight) / 2

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: 0),
            bottomLeft: CGPoint(x: leftX, y: smallHeight),
            topRight: CGPoint(
                x: rightX,
                y: size.height / 2 - Layout.largeNodeHeight / 2
            ),
            bottomRight: CGPoint(x: rightX, y: size.height / 2)
        )

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: size.height - smallHeight),
            bottomLeft: CGPoint(x: leftX, y: size.height),
            topRight: CGPoint(x: rightX, y: size.height / 2),
            bottomRight: CGPoint(
                x: rightX,
                y: size.height / 2 + Layout.largeNodeHeight / 2
            )
        )
    }

    private func drawSplitSankeyFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap
        let smallHeight = (size.height - Layout.spacerHeight) / 2

        drawTube(
            context: context,
            topLeft: CGPoint(
                x: leftX,
                y: size.height / 2 - Layout.largeNodeHeight / 2
            ),
            bottomLeft: CGPoint(x: leftX, y: size.height / 2),
            topRight: CGPoint(x: rightX, y: 0),
            bottomRight: CGPoint(x: rightX, y: smallHeight)
        )

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: size.height / 2),
            bottomLeft: CGPoint(
                x: leftX,
                y: size.height / 2 + Layout.largeNodeHeight / 2
            ),
            topRight: CGPoint(x: rightX, y: size.height - smallHeight),
            bottomRight: CGPoint(x: rightX, y: size.height)
        )
    }

    private func drawTripleSplitSankeyFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap

        let totalGap = Layout.spacerHeight * 2
        let segmentHeight = (size.height - totalGap) / 3
        let midY = size.height / 2
        let leftTop = midY - Layout.largeNodeHeight / 2

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: leftTop),
            bottomLeft: CGPoint(x: leftX, y: leftTop + Layout.largeNodeHeight / 3),
            topRight: CGPoint(x: rightX, y: 0),
            bottomRight: CGPoint(x: rightX, y: segmentHeight)
        )

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: leftTop + Layout.largeNodeHeight / 3),
            bottomLeft: CGPoint(x: leftX, y: leftTop + (2 * Layout.largeNodeHeight / 3)),
            topRight: CGPoint(x: rightX, y: segmentHeight + Layout.spacerHeight),
            bottomRight: CGPoint(x: rightX, y: (2 * segmentHeight) + Layout.spacerHeight)
        )

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: leftTop + (2 * Layout.largeNodeHeight / 3)),
            bottomLeft: CGPoint(x: leftX, y: leftTop + Layout.largeNodeHeight),
            topRight: CGPoint(x: rightX, y: (2 * segmentHeight) + (2 * Layout.spacerHeight)),
            bottomRight: CGPoint(x: rightX, y: size.height)
        )
    }

    private func drawSimpleFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: 0),
            bottomLeft: CGPoint(x: leftX, y: size.height),
            topRight: CGPoint(x: rightX, y: 0),
            bottomRight: CGPoint(x: rightX, y: size.height)
        )
    }

    private func drawTopHalfToCenteredSimpleFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap
        let nodeHeight = (size.height - Layout.spacerHeight) / 2

        let rightNodeTop = (size.height - nodeHeight) / 2
        let rightNodeBottom = rightNodeTop + nodeHeight

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: 0),
            bottomLeft: CGPoint(x: leftX, y: nodeHeight),
            topRight: CGPoint(x: rightX, y: rightNodeTop),
            bottomRight: CGPoint(x: rightX, y: rightNodeBottom)
        )
    }

    private func drawTopHalfToSplitSankeyFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap
        let nodeHeight = (size.height - Layout.spacerHeight) / 2

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: 0),
            bottomLeft: CGPoint(x: leftX, y: nodeHeight / 2),
            topRight: CGPoint(x: rightX, y: 0),
            bottomRight: CGPoint(x: rightX, y: nodeHeight)
        )

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: nodeHeight / 2),
            bottomLeft: CGPoint(x: leftX, y: nodeHeight),
            topRight: CGPoint(x: rightX, y: size.height - nodeHeight),
            bottomRight: CGPoint(x: rightX, y: size.height)
        )
    }

    private func drawTopHalfToTripleSplitSankeyFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap
        let leftNodeHeight = (size.height - Layout.spacerHeight) / 2
        
        let totalGap = Layout.spacerHeight * 2
        let segmentHeight = (size.height - totalGap) / 3

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: 0),
            bottomLeft: CGPoint(x: leftX, y: leftNodeHeight / 3),
            topRight: CGPoint(x: rightX, y: 0),
            bottomRight: CGPoint(x: rightX, y: segmentHeight)
        )

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: leftNodeHeight / 3),
            bottomLeft: CGPoint(x: leftX, y: 2 * leftNodeHeight / 3),
            topRight: CGPoint(x: rightX, y: segmentHeight + Layout.spacerHeight),
            bottomRight: CGPoint(x: rightX, y: (2 * segmentHeight) + Layout.spacerHeight)
        )

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: 2 * leftNodeHeight / 3),
            bottomLeft: CGPoint(x: leftX, y: leftNodeHeight),
            topRight: CGPoint(x: rightX, y: (2 * segmentHeight) + (2 * Layout.spacerHeight)),
            bottomRight: CGPoint(x: rightX, y: size.height)
        )
    }

    /// Draws a unified curved "tube" between four specific corners
    private func drawTube(
        context: GraphicsContext,
        topLeft: CGPoint,
        bottomLeft: CGPoint,
        topRight: CGPoint,
        bottomRight: CGPoint
    ) {
        let controlX = topLeft.x + (topRight.x - topLeft.x) * 0.5

        let path = Path { p in
            p.move(to: topLeft)
            p.addCurve(
                to: topRight,
                control1: CGPoint(x: controlX, y: topLeft.y),
                control2: CGPoint(x: controlX, y: topRight.y)
            )
            p.addLine(to: bottomRight)
            p.addCurve(
                to: bottomLeft,
                control1: CGPoint(x: controlX, y: bottomRight.y),
                control2: CGPoint(x: controlX, y: bottomLeft.y)
            )
            p.closeSubpath()
        }

        context.fill(
            path,
            with: .color(Color.primary.opacity(Layout.flowOpacity))
        )
    }
}

struct PowerLabel: View {
    let power: Double
    @Default(.showTwoDecimalPowerValues) private var showTwoDecimalPowerValues

    var body: some View {
        let formattedPower = PowerValueFormatter.string(
            from: power,
            showTwoDecimalPlaces: showTwoDecimalPowerValues
        )
        Text("\(formattedPower) W")
            .font(.system(size: 13, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}

struct NodeView: View {
    let icon: String
    let value: Double?
    let isLeftSide: Bool
    let cornerRadius: CGFloat = 16.0
    @Default(.showTwoDecimalPowerValues) private var showTwoDecimalPowerValues

    var body: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: isLeftSide ? cornerRadius : 0,
                bottomLeadingRadius: isLeftSide ? cornerRadius : 0,
                bottomTrailingRadius: isLeftSide ? 0 : cornerRadius,
                topTrailingRadius: isLeftSide ? 0 : cornerRadius,
                style: .continuous
            )
            .fill(Color.primary.opacity(0.05))
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: isLeftSide ? cornerRadius : 0,
                    bottomLeadingRadius: isLeftSide ? cornerRadius : 0,
                    bottomTrailingRadius: isLeftSide ? 0 : cornerRadius,
                    topTrailingRadius: isLeftSide ? 0 : cornerRadius,
                    style: .continuous
                )
                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
            )
            .frame(width: 60)

            VStack(spacing: 4) {
                if icon == "HubIcon" {
                    Image("HubIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                if let value {
                    let formattedPower = PowerValueFormatter.string(
                        from: value,
                        showTwoDecimalPlaces: showTwoDecimalPowerValues
                    )
                    Text("\(formattedPower) W")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NodeView(icon: "battery.100.bolt", value: 36.5, isLeftSide: true).frame(
        height: 100
    )
}

#Preview {
    let items: [(PowerSource, Bool, Double, Double, Double, Double, [Double])] = [
        (.both, false, -20.16, 36.0, 56.16, 0, []),
        (.acAdapter, true, 20.0, 30.0, 7.0, 3.0, [3.0]),
        (.battery, false, -18.63, 0.0, 18.63, 0, []),
        (.acAdapter, false, 0.0, 25.0, 11.0, 14.0, [9.0, 5.0]),
        (.acAdapter, false, 23, 39, 16, 0, []),
    ]
    LazyVGrid(
        columns: [
            GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()),
        ],
        spacing: 16
    ) {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            PowerSankeyView(
                powerSource: item.0,
                isCharging: item.1,
                batteryPower: item.2,
                adapterPower: item.3,
                systemPower: item.4,
                outputPower: item.5,
                outputPortPowers: item.6,
                outputIcons: [],
                adapterConnected: true
            )
            .frame(height: 125)
        }
    }
    .padding(12)
    .frame(width: 900)
}
