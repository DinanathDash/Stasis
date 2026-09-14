import AppKit

// CoreGraphics Private APIs for Maximum Z-Index Space
private typealias CGSConnectionID = UInt
private typealias CGSSpaceID = UInt64
@_silgen_name("_CGSDefaultConnection")
private func _CGSDefaultConnection() -> CGSConnectionID
@_silgen_name("CGSSpaceCreate")
private func CGSSpaceCreate(_ cid: CGSConnectionID, _ unknown: Int, _ options: NSDictionary?) -> CGSSpaceID
@_silgen_name("CGSSpaceSetAbsoluteLevel")
private func CGSSpaceSetAbsoluteLevel(_ cid: CGSConnectionID, _ space: CGSSpaceID, _ level: Int)
@_silgen_name("CGSAddWindowsToSpaces")
private func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)
@_silgen_name("CGSShowSpaces")
private func CGSShowSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)

class TopWindowElevator {
    static let shared = TopWindowElevator()

    private let cgsSpaceID: CGSSpaceID

    // SkyLight Lock Screen Private APIs
    private var slsConnection: Int32 = 0
    private var slsSpace: Int32 = 0
    private var SLSSpaceAddWindowsAndRemoveFromSpaces: (@convention(c) (Int32, Int32, CFArray, Int32) -> Int32)?

    private init() {
        // 1. Create a CGS Space with maximum possible absolute level to appear above everything (including other notches)
        let cid = _CGSDefaultConnection()
        let flag = 0x1 // 1 is required to prevent Finder from drawing desktop icons in this space
        cgsSpaceID = CGSSpaceCreate(cid, flag, nil)
        CGSSpaceSetAbsoluteLevel(cid, cgsSpaceID, 2_147_483_647) // Int32.max
        CGSShowSpaces(cid, [cgsSpaceID] as NSArray)

        // 2. Setup SkyLight space specifically for Lock Screen visibility
        if let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/SkyLight.framework")),
           let SLSMainConnectionIDPointer = CFBundleGetFunctionPointerForName(bundle, "SLSMainConnectionID" as CFString),
           let SLSSpaceCreatePointer = CFBundleGetFunctionPointerForName(bundle, "SLSSpaceCreate" as CFString),
           let SLSSpaceSetAbsoluteLevelPointer = CFBundleGetFunctionPointerForName(bundle, "SLSSpaceSetAbsoluteLevel" as CFString),
           let SLSShowSpacesPointer = CFBundleGetFunctionPointerForName(bundle, "SLSShowSpaces" as CFString),
           let SLSSpaceAddWindowsAndRemoveFromSpacesPointer = CFBundleGetFunctionPointerForName(bundle, "SLSSpaceAddWindowsAndRemoveFromSpaces" as CFString)
        {
            let SLSMainConnectionID = unsafeBitCast(SLSMainConnectionIDPointer, to: (@convention(c) () -> Int32).self)
            let SLSSpaceCreate = unsafeBitCast(SLSSpaceCreatePointer, to: (@convention(c) (Int32, Int32, Int32) -> Int32).self)
            let SLSSpaceSetAbsoluteLevel = unsafeBitCast(SLSSpaceSetAbsoluteLevelPointer, to: (@convention(c) (Int32, Int32, Int32) -> Int32).self)
            let SLSShowSpaces = unsafeBitCast(SLSShowSpacesPointer, to: (@convention(c) (Int32, CFArray) -> Int32).self)
            self.SLSSpaceAddWindowsAndRemoveFromSpaces = unsafeBitCast(SLSSpaceAddWindowsAndRemoveFromSpacesPointer, to: (@convention(c) (Int32, Int32, CFArray, Int32) -> Int32).self)

            self.slsConnection = SLSMainConnectionID()
            self.slsSpace = SLSSpaceCreate(self.slsConnection, 1, 0)
            let _ = SLSSpaceSetAbsoluteLevel(self.slsConnection, self.slsSpace, 400) // kSLSSpaceAbsoluteLevelNotificationCenterAtScreenLock
            let _ = SLSShowSpaces(self.slsConnection, [self.slsSpace] as CFArray)
        }
    }

    func elevate(window: NSWindow) {
        // Add to max level CGS Space
        let cid = _CGSDefaultConnection()
        CGSAddWindowsToSpaces(cid, [window.windowNumber] as NSArray, [cgsSpaceID] as NSArray)

        // Add to SkyLight lock screen space
        if let addWindows = self.SLSSpaceAddWindowsAndRemoveFromSpaces {
            let _ = addWindows(self.slsConnection, self.slsSpace, [window.windowNumber] as CFArray, 7)
        }
    }
}
