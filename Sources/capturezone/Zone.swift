import AppKit

/// A capture region, held in Core Graphics screen coordinates: the origin is
/// the top left of the primary display, Y counts downward, and the numbers
/// are points.
///
/// Points rather than pixels because every API that places something on the
/// screen speaks points: `NSScreen.frame`, and the Accessibility attributes
/// used to move another application's window. Pixels only appear at the two
/// edges of the program, where the caller says what they want OBS to capture
/// and where the crop numbers are printed, and the display's backing scale
/// converts between them.
///
/// Core Graphics rather than Cocoa because this is the system the caller is
/// already thinking in. A screenshot, the Displays arrangement pane and OBS
/// all put (0, 0) at the top left; Cocoa is the odd one out, and the only
/// place it is needed is the moment a window is positioned.
struct Zone: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    init(_ rect: CGRect) {
        x = rect.origin.x.rounded()
        y = rect.origin.y.rounded()
        width = rect.width.rounded()
        height = rect.height.rounded()
    }

    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }

    /// Where the zone was last left, so `snap` and `crop` do not each need
    /// the rectangle spelled out again.
    static let storePath = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".config/capturezone/zone.json")

    static func load() -> Zone? {
        guard let data = try? Data(contentsOf: storePath) else { return nil }
        return try? JSONDecoder().decode(Zone.self, from: data)
    }

    func save() {
        let directory = Zone.storePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Zone.storePath)
    }

    /// A zone of a given pixel size, centred on a display.
    ///
    /// The size is in pixels because that is what the caller is choosing:
    /// 1920x1080 means the recording, not the desktop. On a display with a
    /// backing scale of 2 the window that fills it is half that in points.
    static func centred(pixelWidth: CGFloat, pixelHeight: CGFloat, on screen: NSScreen) -> Zone {
        let scale = screen.backingScaleFactor
        let size = CGSize(width: pixelWidth / scale, height: pixelHeight / scale)
        let bounds = Screens.cgRect(from: screen.frame)
        return Zone(CGRect(x: bounds.midX - size.width / 2,
                           y: bounds.midY - size.height / 2,
                           width: size.width,
                           height: size.height))
    }
}

enum Screens {
    /// The display carrying the menu bar. Its origin is (0, 0) in both
    /// coordinate systems, which is what anchors the conversion between them.
    static var primary: NSScreen? { NSScreen.screens.first }

    /// Cocoa counts upward from the bottom left of the primary display, Core
    /// Graphics downward from the top left. Flipping between them needs the
    /// primary display's height and nothing else, however many other screens
    /// are attached and wherever they sit.
    static func cocoaRect(from cg: CGRect) -> NSRect {
        guard let primary else { return cg }
        return NSRect(x: cg.minX,
                      y: primary.frame.maxY - cg.maxY,
                      width: cg.width,
                      height: cg.height)
    }

    static func cgRect(from cocoa: NSRect) -> CGRect {
        guard let primary else { return cocoa }
        return CGRect(x: cocoa.minX,
                      y: primary.frame.maxY - cocoa.maxY,
                      width: cocoa.width,
                      height: cocoa.height)
    }

    /// The display a zone sits on, which decides the backing scale that
    /// applies to it. Measured from the centre rather than a corner, so a
    /// zone nudged a little past an edge still reports the screen it is
    /// mostly on instead of nothing.
    static func holding(_ zone: Zone) -> NSScreen? {
        let centre = Screens.cocoaRect(from: zone.cgRect).center
        return NSScreen.screens.first { $0.frame.contains(centre) } ?? primary
    }

    static func screen(number: Int) -> NSScreen? {
        let screens = NSScreen.screens
        guard number >= 1, number <= screens.count else { return nil }
        return screens[number - 1]
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }
}

extension NSRect {
    var center: NSPoint { NSPoint(x: midX, y: midY) }
}
