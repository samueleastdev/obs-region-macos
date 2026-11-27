import AppKit

/// The menu bar item, which exists because the obvious wish, right-clicking
/// a window and choosing "fit to zone", cannot be granted. A context menu
/// belongs to the application drawing it, and macOS has no way for anything
/// outside Chrome to add a line to Chrome's. The nearest honest equivalents
/// are a key press, a Services entry, and this.
final class MenuBar: NSObject, NSMenuDelegate {
    private let item: NSStatusItem
    private let zone: Zone
    private let outline: Outline

    /// The application to act on, remembered rather than asked for.
    ///
    /// Opening this menu makes capturezone the frontmost application, so by
    /// the time an item is chosen `frontmostApplication` is capturezone
    /// itself and the window the user was looking at is no longer anybody's
    /// idea of the front one. Watching activations and keeping the last one
    /// that was not us is the only thing that survives the click.
    private var target: NSRunningApplication?

    init(zone: Zone, outline: Outline) {
        self.zone = zone
        self.outline = outline
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let icon = NSImage(systemSymbolName: "rectangle.dashed",
                              accessibilityDescription: "Capture zone") {
            icon.isTemplate = true
            item.button?.image = icon
        } else {
            item.button?.title = "▣"
        }

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu

        target = NSWorkspace.shared.frontmostApplication
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier
            else { return }
            self?.target = app
        }
    }

    /// Rebuilt every time it opens, so the first line names whatever the
    /// user was actually in.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let name = target?.localizedName
        let fit = NSMenuItem(title: name.map { "Fit \($0) to zone" } ?? "Fit window to zone",
                             action: #selector(fitTarget),
                             keyEquivalent: "")
        fit.target = self
        fit.isEnabled = target != nil
        menu.addItem(fit)

        let shortcut = NSMenuItem(title: "or press ctrl+opt+cmd+z", action: nil, keyEquivalent: "")
        shortcut.isEnabled = false
        menu.addItem(shortcut)

        menu.addItem(.separator())

        let zoneLine = NSMenuItem(title: describe(zone), action: nil, keyEquivalent: "")
        zoneLine.isEnabled = false
        menu.addItem(zoneLine)

        let toggle = NSMenuItem(title: outline.isVisible ? "Hide outline" : "Show outline",
                                action: #selector(toggleOutline),
                                keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        let copy = NSMenuItem(title: "Copy OBS crop values",
                              action: #selector(copyCrop),
                              keyEquivalent: "")
        copy.target = self
        menu.addItem(copy)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit capturezone", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func fitTarget() {
        guard let target else { return }
        Snap.requestTrust()
        do {
            try Snap.move(target, to: zone)
        } catch {
            warn("\(error)")
        }
    }

    @objc private func toggleOutline() {
        outline.setVisible(!outline.isVisible)
    }

    @objc private func copyCrop() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(obsSetup(for: zone), forType: .string)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    /// A failed snap must not be a dialog.
    ///
    /// The menu bar is reachable while something is being recorded, and a
    /// modal sheet appearing over the capture would be worse than the
    /// failure it is reporting. A notification is no good either: the
    /// UserNotifications framework wants a bundle identifier and a command
    /// line tool has none. So the reason goes to the terminal, and the icon
    /// turns into a warning for a moment so the failure is noticed by
    /// someone who is not looking at the terminal.
    private func warn(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))

        let was = item.button?.image
        item.button?.toolTip = message
        item.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                                     accessibilityDescription: "Could not fit the window")
        item.button?.image?.isTemplate = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.item.button?.image = was
        }
    }
}
