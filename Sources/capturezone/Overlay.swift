import AppKit

/// The outline, drawn just outside the zone.
///
/// Outside matters. A guide drawn on the boundary is inside the capture, so
/// every recording comes out with a coloured frame around it. The window is
/// the zone grown by one line width on each side and the stroke is centred
/// on the inset boundary, which puts the whole line in the margin and leaves
/// the zone itself untouched.
final class OverlayView: NSView {
    var lineWidth: CGFloat = 2
    var colour: NSColor = .systemTeal

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(rect: bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
        path.lineWidth = lineWidth
        colour.setStroke()
        path.stroke()
    }
}

final class OverlayWindow: NSWindow {
    init(zone: Zone, colour: NSColor, lineWidth: CGFloat) {
        let frame = Screens.cocoaRect(from: zone.cgRect).insetBy(dx: -lineWidth, dy: -lineWidth)
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // The guide must never take a click, or it would be a 2px dead band
        // around whatever is being recorded.
        ignoresMouseEvents = true

        // Above everything. A thin outline obscures nothing worth seeing, and
        // a guide that disappears behind the window being lined up is no
        // guide at all.
        level = .screenSaver

        // Follows the desktop around, rather than belonging to the one it was
        // created on, and stays out of the window cycle.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let view = OverlayView(frame: NSRect(origin: .zero, size: frame.size))
        view.colour = colour
        view.lineWidth = lineWidth
        contentView = view
    }

    // Borderless windows will take key status if asked, and this one taking
    // it would pull focus off the application being positioned.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

extension NSColor {
    /// `#rrggbb`, with or without the hash. Anything else is nil, so the
    /// caller can complain rather than silently drawing in black.
    static func fromHex(_ text: String) -> NSColor? {
        var digits = text.hasPrefix("#") ? String(text.dropFirst()) : text
        if digits.count == 3 {
            digits = digits.map { "\($0)\($0)" }.joined()
        }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xff) / 255,
                       green: CGFloat((value >> 8) & 0xff) / 255,
                       blue: CGFloat(value & 0xff) / 255,
                       alpha: 1)
    }
}
