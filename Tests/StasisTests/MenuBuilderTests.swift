import Defaults
import XCTest
@testable import Stasis

@MainActor
final class MenuBuilderTests: XCTestCase {
    func testShouldShowManageChargingToggleIsAlwaysTrue() {
        XCTAssertTrue(MenuBuilder.shouldShowManageChargingToggle)
    }

    func testSetManageChargingFalseDisablesManageCharging() {
        let originalValue = Defaults[.manageCharging]
        defer { Defaults[.manageCharging] = originalValue }

        MenuBuilder.setManageCharging(false)

        XCTAssertFalse(Defaults[.manageCharging])
    }

    func testSetManageChargingTrueEnablesManageCharging() {
        let originalValue = Defaults[.manageCharging]
        defer { Defaults[.manageCharging] = originalValue }

        MenuBuilder.setManageCharging(true)

        XCTAssertTrue(Defaults[.manageCharging])
    }

    func testManageChargingStatusTextWhenEnabled() {
        XCTAssertEqual(
            NotchHUDManager.manageChargingStatusText(isEnabled: true),
            String(localized: "Managed Charging Enabled")
        )
    }

    func testManageChargingStatusTextWhenDisabled() {
        XCTAssertEqual(
            NotchHUDManager.manageChargingStatusText(isEnabled: false),
            String(localized: "Charge Limit Disabled")
        )
    }
}
