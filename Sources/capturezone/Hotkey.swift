import AppKit
import Carbon.HIToolbox

/// A system wide key combination, through the Carbon hot key API.
///
/// Carbon because it is the only route that does not need a permission. The
/// modern alternative, a `CGEventTap`, reads every keystroke on the machine
/// and macOS quite rightly makes the user grant Input Monitoring for it; this
/// registers one combination with the window server and is told when it is
/// pressed, which needs nothing. The API is old, not deprecated.
///
/// The callback is a C function pointer and so cannot capture anything, which
/// is why the actions live in a static table keyed by the id Carbon hands
/// back with the event.
final class Hotkey {
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    private var reference: EventHotKeyRef?
    private let id: UInt32

    init?(_ spec: String, action: @escaping () -> Void) {
        guard let (keyCode, modifiers) = Hotkey.parse(spec) else { return nil }

        Hotkey.installHandler()
        id = Hotkey.nextID
        Hotkey.nextID += 1

        let identifier = EventHotKeyID(signature: OSType(0x435A_4E45), id: id)  // 'CZNE'
        let status = RegisterEventHotKey(keyCode, modifiers, identifier,
                                         GetApplicationEventTarget(), 0, &reference)
        guard status == noErr else { return nil }
        Hotkey.actions[id] = action
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        Hotkey.actions[id] = nil
    }

    private static func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let read = GetEventParameter(event,
                                         EventParamName(kEventParamDirectObject),
                                         EventParamType(typeEventHotKeyID),
                                         nil,
                                         MemoryLayout<EventHotKeyID>.size,
                                         nil,
                                         &identifier)
            guard read == noErr else { return OSStatus(eventNotHandledErr) }
            Hotkey.actions[identifier.id]?()
            return noErr
        }, 1, &spec, nil, nil)
    }

    /// `ctrl+opt+cmd+z`, in any order, case insensitive.
    static func parse(_ spec: String) -> (keyCode: UInt32, modifiers: UInt32)? {
        var modifiers: UInt32 = 0
        var key: UInt32?

        for part in spec.lowercased().split(whereSeparator: { $0 == "+" || $0 == "-" || $0 == " " }) {
            switch part {
            case "cmd", "command", "meta": modifiers |= UInt32(cmdKey)
            case "ctrl", "control": modifiers |= UInt32(controlKey)
            case "opt", "option", "alt": modifiers |= UInt32(optionKey)
            case "shift": modifiers |= UInt32(shiftKey)
            default:
                guard let code = keyCodes[String(part)], key == nil else { return nil }
                key = code
            }
        }

        // A combination with no modifier would swallow the key everywhere on
        // the machine, including inside whatever is being recorded.
        guard let key, modifiers != 0 else { return nil }
        return (key, modifiers)
    }

    /// Letters and digits only. Anything that needs a function key or an
    /// arrow can be added when something wants one.
    private static let keyCodes: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
        "9": 25, "7": 26, "8": 28, "0": 29,
        "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40,
        "n": 45, "m": 46,
    ]
}
