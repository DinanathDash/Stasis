import SwiftUI

@MainActor
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    init(topCornerRadius: CGFloat = 10, bottomCornerRadius: CGFloat = 16) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    nonisolated var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()

        // Start at the top-left corner
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top-left "ear": concave curve bowing inward
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY)
        )

        // Left edge down to bottom-left
        path.addLine(to: CGPoint(x: rect.minX + topCornerRadius,
                                 y: rect.maxY - bottomCornerRadius))

        // Bottom-left convex rounded corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY)
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius,
                                 y: rect.maxY))

        // Bottom-right convex rounded corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topCornerRadius,
                        y: rect.maxY - bottomCornerRadius),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY)
        )

        // Right edge up to top-right
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius,
                                 y: rect.minY + topCornerRadius))

        // Top-right "ear": concave curve bowing outward
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY)
        )

        // Close along the top edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        return path
    }
}
