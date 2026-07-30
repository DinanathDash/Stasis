import SwiftUI
import WidgetKit

@main
struct StasisWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BatteryStatusWidget()
        PowerSankeyWidget()
    }
}
