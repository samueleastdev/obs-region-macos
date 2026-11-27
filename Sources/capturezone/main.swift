import AppKit

// Unbuffered, because every command that prints anything then blocks: a
// buffered stdout shows nothing at all until the process is killed.
setbuf(stdout, nil)

// ---------------------------------------------------------------------------
// Arguments
// ---------------------------------------------------------------------------

/// `--key value` and `--flag`, which is the whole grammar. Written out rather
/// than pulled in, because swift-argument-parser is a network fetch and this
/// is four options.
struct Options {
    private var values: [String: String] = [:]
    private var flags: Set<String> = []

    init(_ arguments: [String]) {
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            guard argument.hasPrefix("--") else { index += 1; continue }
            let key = String(argument.dropFirst(2))
            // A negative coordinate starts with one dash, not two, so a value
            // is anything that is not the next option.
            if index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") {
                values[key] = arguments[index + 1]
                index += 2
            } else {
                flags.insert(key)
                index += 1
            }
        }
    }

    func string(_ names: String...) -> String? { names.compactMap { values[$0] }.first }
    func flag(_ name: String) -> Bool { flags.contains(name) }
    func int(_ names: String...) -> Int? { names.compactMap { values[$0] }.first.flatMap(Int.init) }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let usage = """
capturezone: hold a fixed capture region on screen, and put windows in it.

  capturezone list
      Every display, with the numbers needed to place a zone on one.

  capturezone zone --centre 1920x1080 [--display 2]
  capturezone zone --rect 760,180,1920,1080
      Draw the outline and stay running. The zone is remembered, so the other
      commands do not need it again. Ctrl-C to stop.

      --colour RRGGBB   outline colour, default 00E5FF
      --width N         outline thickness in points, default 2
      --hotkey SPEC     snap the frontmost window into the zone,
                        default ctrl+opt+cmd+z
      --no-hotkey       do not register one
      --no-menu-bar     do not add the menu bar item
      --quiet           just the zone, without the OBS instructions

  capturezone snap [--app "Google Chrome"]
      Put a window in the remembered zone, once.

  capturezone crop
      The OBS Crop/Pad numbers for the remembered zone.

Sizes are in pixels, the same as OBS reports them. Positions are in points
from the top left of the primary display, the same as the Displays pane.
"""

// ---------------------------------------------------------------------------
// Shared resolution
// ---------------------------------------------------------------------------

func resolveZone(_ options: Options, allowStored: Bool = true) -> Zone {
    if let text = options.string("rect") {
        let parts = text.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4, !parts.contains(where: { $0 == nil }) else {
            fail("--rect wants four numbers, as in --rect 760,180,1920,1080")
        }
        let numbers = parts.map { CGFloat($0!) }
        return Zone(CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3]))
    }

    if let text = options.string("centre", "center") {
        let parts = text.lowercased().split(separator: "x").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2, let width = parts[0], let height = parts[1] else {
            fail("--centre wants a pixel size, as in --centre 1920x1080")
        }
        let screen: NSScreen
        if let number = options.int("display") {
            guard let found = Screens.screen(number: number) else {
                fail("There is no display \(number). Run: capturezone list")
            }
            screen = found
        } else {
            guard let primary = Screens.primary else { fail("No displays found.") }
            screen = primary
        }
        return Zone.centred(pixelWidth: CGFloat(width), pixelHeight: CGFloat(height), on: screen)
    }

    if allowStored, let stored = Zone.load() {
        return stored
    }

    fail("No zone given and none remembered. Start with: capturezone zone --centre 1920x1080")
}

func describe(_ zone: Zone) -> String {
    let screen = Screens.holding(zone)
    let scale = screen?.backingScaleFactor ?? 1
    let pixels = "\(Int(zone.width * scale))x\(Int(zone.height * scale))"
    let where_ = screen.map { " on \($0.localizedName)" } ?? ""
    return "\(Int(zone.width))x\(Int(zone.height)) pt at \(Int(zone.x)),\(Int(zone.y))"
        + " = \(pixels) px\(where_)"
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

func listDisplays() {
    print("Positions are points from the top left of the primary display.\n")
    for (index, screen) in NSScreen.screens.enumerated() {
        let bounds = Screens.cgRect(from: screen.frame)
        let scale = screen.backingScaleFactor
        let points = "\(Int(bounds.width))x\(Int(bounds.height))"
        let pixels = "\(Int(bounds.width * scale))x\(Int(bounds.height * scale))"
        let primary = index == 0 ? "  [primary]" : ""
        print("  \(index + 1)  \(screen.localizedName)")
        print("     origin \(Int(bounds.minX)),\(Int(bounds.minY))   "
            + "\(points) pt   scale \(scale)   \(pixels) px\(primary)")
    }
    print("\nA centred 1920x1080 on display 1:  capturezone zone --centre 1920x1080")
}

/// The whole OBS recipe for a zone.
///
/// Printed by `crop`, and by `zone` as well, because the moment the outline
/// appears the next thing wanted is the four numbers that make OBS agree
/// with it, and sending someone off to run a second command for them was
/// making one job into two sittings.
func obsSetup(for zone: Zone) -> String {
    guard let screen = Screens.holding(zone) else {
        return "That zone is not on any display, so there are no OBS numbers for it."
    }
    let scale = screen.backingScaleFactor
    let display = Screens.cgRect(from: screen.frame)

    let left = Int((zone.x - display.minX) * scale)
    let top = Int((zone.y - display.minY) * scale)
    let right = Int((display.maxX - (zone.x + zone.width)) * scale)
    let bottom = Int((display.maxY - (zone.y + zone.height)) * scale)
    let canvas = "\(Int(zone.width * scale))x\(Int(zone.height * scale))"

    var lines = [
        "OBS, once:",
        "  1  Settings, Video: Base and Output both \(canvas)",
        "  2  Add Source, macOS Screen Capture, Method Display, \(screen.localizedName)",
        "  3  That source, Filters, +, Crop/Pad, Relative ticked:",
        "       Left \(left)   Top \(top)   Right \(right)   Bottom \(bottom)",
        "  4  That source, Transform, Fit to Screen",
    ]
    if [left, top, right, bottom].contains(where: { $0 < 0 }) {
        lines.append("")
        lines.append("A negative number means the zone hangs off the edge of the display.")
    }
    return lines.joined(separator: "\n")
}

func printCrop(_ options: Options) {
    let zone = resolveZone(options)
    print("Zone: \(describe(zone))\n")
    print(obsSetup(for: zone))
}

func snapOnce(_ options: Options) {
    let zone = resolveZone(options)
    Snap.requestTrust()
    do {
        try Snap.move(appNamed: options.string("app"), to: zone)
        print("Snapped to \(describe(zone))")
    } catch {
        fail("\(error)")
    }
}

func runZone(_ options: Options) {
    let zone = resolveZone(options)
    zone.save()

    let colourText = options.string("colour", "color") ?? "00E5FF"
    guard let colour = NSColor.fromHex(colourText) else {
        fail("--colour wants a hex value, as in --colour 00E5FF")
    }
    let width = CGFloat(options.int("width") ?? 2)

    let app = NSApplication.shared
    // No Dock icon and no menu bar. This is a guide, not an application.
    app.setActivationPolicy(.accessory)

    let outline = Outline(zone: zone, colour: colour, lineWidth: width)
    let menuBar = options.flag("no-menu-bar") ? nil : MenuBar(zone: zone, outline: outline)

    print("Zone: \(describe(zone))")
    if !options.flag("quiet") {
        print("")
        print(obsSetup(for: zone))
        print("")
        print("The outline is drawn just outside the zone, so it is never in the capture.")
    }
    if menuBar != nil {
        print("Menu bar: fit the window you were last in, hide the outline, copy the values.")
    }

    var hotkey: Hotkey?
    if !options.flag("no-hotkey") {
        let spec = options.string("hotkey") ?? "ctrl+opt+cmd+z"
        hotkey = Hotkey(spec) {
            Snap.requestTrust()
            do {
                try Snap.move(appNamed: nil, to: zone)
            } catch {
                FileHandle.standardError.write(Data("\(error)\n".utf8))
            }
        }
        if hotkey == nil {
            fail("Could not register \(spec). It needs a modifier and one letter or digit, "
                + "and another application may already hold it.")
        }
        print("Press \(spec) to put the frontmost window in it.")
    }
    withExtendedLifetime((hotkey, outline, menuBar)) {
        print("Ctrl-C to stop.")
        app.run()
    }
}

// ---------------------------------------------------------------------------

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { print(usage); exit(1) }
let options = Options(Array(arguments.dropFirst()))

switch command {
case "list": listDisplays()
case "zone": runZone(options)
case "snap": snapOnce(options)
case "crop": printCrop(options)
case "help", "-h", "--help": print(usage)
default: fail("No command called \(command).\n\n" + usage)
}
