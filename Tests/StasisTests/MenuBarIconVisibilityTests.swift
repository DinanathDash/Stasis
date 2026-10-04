import Defaults
import XCTest
@testable import Stasis

@MainActor
final class MenuBarIconVisibilityTests: XCTestCase {
    func testShowBatteryGraphicInStatusIconDefaultsToTrue() {
        XCTAssertTrue(Defaults.Keys.showBatteryGraphicInStatusIcon.defaultValue)
    }

    func testStatusItemIsAlwaysVisible() {
        XCTAssertTrue(StatusBarManager.statusItemIsAlwaysVisible)
    }

    func testStatusBarDisplayModeReflectsBatteryGraphicSetting() {
        XCTAssertEqual(StatusBarDisplayMode(showBatteryGraphic: false), .percentageOnly)
        XCTAssertEqual(StatusBarDisplayMode(showBatteryGraphic: true), .batteryGraphic)
    }
}
