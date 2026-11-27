import AppKit
import ApplicationServices

/// Moving another application's window, which only the Accessibility API can
/// do. It speaks the same Core Graphics coordinates and points that `Zone`
/// holds, so nothing is converted here.
enum Snap {

    enum Failure: Error, CustomStringConvertible {
        case notTrusted
        case noApplication(String)
        case noWindow(String)
        case refused(String)

        var description: String {
            switch self {
            case .notTrusted:
                return """
                capturezone is not trusted for Accessibility, so it cannot move windows.

                A command run from a terminal inherits the terminal's permission, so the
                entry to tick is the terminal, not capturezone:
                  System Settings > Privacy & Security > Accessibility
                """
            case .noApplication(let name):
                return "No running application called \(name)."
            case .noWindow(let name):
                return "\(name) has no focused window to move."
            case .refused(let name):
                return """
                \(name) refused to be positioned. Windows that are full screen, or that
                have a fixed size, cannot be moved by any window manager.
                """
            }
        }
    }

    /// Asks once, and puts the entry in the Accessibility list with the
    /// prompt so the user has something to tick.
    @discardableResult
    static func requestTrust() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func move(appNamed name: String?, to zone: Zone) throws {
        let app: NSRunningApplication
        if let name {
            guard let found = NSWorkspace.shared.runningApplications.first(where: {
                $0.localizedName?.caseInsensitiveCompare(name) == .orderedSame
                    || $0.bundleIdentifier?.caseInsensitiveCompare(name) == .orderedSame
            }) else { throw Failure.noApplication(name) }
            app = found
        } else {
            guard let front = NSWorkspace.shared.frontmostApplication else {
                throw Failure.noApplication("frontmost")
            }
            app = front
        }
        try move(app, to: zone)
    }

    /// Moving a known application, rather than one looked up by name. The
    /// menu bar needs this: by the time a menu item is chosen the frontmost
    /// application is this one, so the target has to have been remembered
    /// before the menu opened.
    static func move(_ app: NSRunningApplication, to zone: Zone) throws {
        guard AXIsProcessTrusted() else { throw Failure.notTrusted }

        let label = app.localizedName ?? "The application"
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        // Checked against the type id rather than cast and hoped for. The
        // attribute is documented to be an AXUIElement, but a forced cast
        // on anything else is a crash where an error will do, and this runs
        // against whatever application happens to be in front.
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let raw = value,
              CFGetTypeID(raw) == AXUIElementGetTypeID()
        else { throw Failure.noWindow(label) }
        let window = raw as! AXUIElement

        // Position, then size, then position again. One pass is not enough:
        // a window moved to a display it does not yet fit on is clamped to
        // that display, and a window resized before it is moved is clamped
        // by the one it is leaving. Setting the position a second time, once
        // the size is right, settles it.
        var moved = set(.position, zone.cgRect.origin, on: window)
        moved = set(.size, zone.cgRect.size, on: window) && moved
        moved = set(.position, zone.cgRect.origin, on: window) && moved
        guard moved else { throw Failure.refused(label) }
    }

    private enum Attribute {
        case position, size

        var name: CFString {
            switch self {
            case .position: return kAXPositionAttribute as CFString
            case .size: return kAXSizeAttribute as CFString
            }
        }
    }

    private static func set(_ attribute: Attribute, _ point: CGPoint, on window: AXUIElement) -> Bool {
        var value = point
        guard let wrapped = AXValueCreate(.cgPoint, &value) else { return false }
        return AXUIElementSetAttributeValue(window, attribute.name, wrapped) == .success
    }

    private static func set(_ attribute: Attribute, _ size: CGSize, on window: AXUIElement) -> Bool {
        var value = size
        guard let wrapped = AXValueCreate(.cgSize, &value) else { return false }
        return AXUIElementSetAttributeValue(window, attribute.name, wrapped) == .success
    }
}
