# Free OBS Region Capture for macOS

[![licence: MIT](https://img.shields.io/badge/licence-MIT-blue.svg)](LICENSE)
[![platform: macOS 13+](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](#install)
[![language: Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](Package.swift)

**OBS has no region capture on macOS.** This draws the crop rectangle on
your screen so you can see it, prints the Crop/Pad numbers OBS needs, and
puts windows in it with a hot key or from the menu bar.

Free and open source, MIT. One 200 KB binary, no dependencies, no OBS
plugin, nothing to configure.

### Watch it work

[![Free OBS Screen Capture Tool for Ultrawide Monitors](https://i.ytimg.com/vi/3mfIPXjS-dY/maxresdefault.jpg)](https://www.youtube.com/watch?v=3mfIPXjS-dY)

```
$ capturezone zone --centre 1920x1080
Zone: 1920x1080 pt at 760,180 = 1920x1080 px on GF340E

OBS, once:
  1  Settings, Video: Base and Output both 1920x1080
  2  Add Source, macOS Screen Capture, Method Display, GF340E
  3  That source, Filters, +, Crop/Pad, Relative ticked:
       Left 760   Top 180   Right 760   Bottom 180
  4  That source, Transform, Fit to Screen

The outline is drawn just outside the zone, so it is never in the capture.
Menu bar: fit the window you were last in, hide the outline, copy the values.
Press ctrl+opt+cmd+z to put the frontmost window in it.
Ctrl-C to stop.
```

The outline appears, and the numbers for OBS come with it.

---

## Does OBS have region capture on macOS?

No. OBS on macOS offers **macOS Screen Capture** with three methods, Display,
Window and Application, and there is no fourth. You cannot draw a box and
record it the way **⇧⌘5** does. The older Display Capture source, now marked
deprecated, has no region either.

The supported answer is to capture a whole display and crop it with the
**Crop/Pad** filter, which works and costs nothing. The part nobody solves
is that **the crop is invisible on your actual screen**, so you end up
dragging windows into a rectangle you cannot see and checking the OBS
preview after every nudge.

That is the entire problem this fixes.

## How do I record 1920x1080 from an ultrawide monitor?

Crop the display down. On a 3440x1440 ultrawide, a centred 1920x1080 means
trimming 760 pixels off each side and 180 off the top and bottom.

```
$ capturezone crop
Zone: 1920x1080 pt at 760,180 = 1920x1080 px on GF340E

OBS, once:
  1  Settings, Video: Base and Output both 1920x1080
  2  Add Source, macOS Screen Capture, Method Display, GF340E
  3  That source, Filters, +, Crop/Pad, Relative ticked:
       Left 760   Top 180   Right 760   Bottom 180
  4  That source, Transform, Fit to Screen
```

`zone` prints the same thing, so in practice you never need `crop`. It is
there for when the zone is set already and you just want the numbers back.

### Crop values for common monitors

A centred 1920x1080, on a display with a backing scale of 1:

| Monitor | Left and Right | Top and Bottom |
|---|---|---|
| 2560x1080 ultrawide | 320 | 0 |
| 3440x1440 ultrawide | 760 | 180 |
| 3840x1600 ultrawide | 960 | 260 |
| 5120x1440 super ultrawide | 1600 | 180 |
| 2560x1440 | 320 | 180 |
| 3840x2160 4K | 960 | 540 |

Run `capturezone crop` rather than reading these off, if the region is not
centred or the display is Retina. Scaling is where this goes wrong: on a
display with a backing scale of 2, a 1920x1080 recording is a 960x540 area
of the desktop, and `capturezone list` prints both numbers for every screen
you have.

## Setting it up in OBS, start to finish

`capturezone zone --centre 1920x1080` prints these with your own display's
numbers filled in, but in full:

1. **Settings, Video**: set Base (Canvas) and Output (Scaled) to `1920x1080`.
2. **Add Source, macOS Screen Capture**. Set **Method** to **Display
   Capture**, not Window Capture, then pick your monitor. Window Capture
   follows one application's window and cannot be cropped to a fixed area of
   the screen.
3. Right-click that source in the **Sources** list, **Filters**. Bottom
   left, under Effect Filters, **+**, **Crop/Pad**.
4. Leave **Relative** ticked and enter the four numbers.
5. Right-click the source in the preview, **Transform, Fit to Screen**
   (⌘F).

Leave `capturezone zone` running while you work, and drag windows into the
outline. **ctrl+opt+cmd+z** puts the frontmost one there exactly.

## Install

### Just use Claude

Paste this into [Claude Code](https://claude.com/claude-code), or any coding
agent with a terminal:

> Clone https://github.com/samueleastdev/obs-region-macos, build it with
> `swift build -c release`, and symlink `.build/release/capturezone` onto my
> PATH. Then run `capturezone list`, and start a centred 1920x1080 zone on
> my main display. Tell me the OBS Crop/Pad numbers it prints so I can set
> OBS up.

It will install the Xcode Command Line Tools first if you do not have them.

### By hand

```sh
git clone https://github.com/samueleastdev/obs-region-macos
cd obs-region-macos
swift build -c release
ln -sf "$PWD/.build/release/capturezone" /usr/local/bin/capturezone
```

Needs the Swift toolchain, which comes with Xcode or the Command Line Tools
(`xcode-select --install`). macOS 13 or later, Apple Silicon or Intel.

If `/usr/local/bin` is not writable, `~/.local/bin` is on the PATH in most
shells and needs no `sudo`.

## Commands

```sh
capturezone list                            # displays, and the numbers to place a zone
capturezone zone --centre 1920x1080         # draw it, stay running, Ctrl-C to stop
capturezone zone --centre 1920x1080 --display 2
capturezone zone --rect 760,180,1920,1080   # place it by hand instead
capturezone crop                            # the OBS Crop/Pad numbers
capturezone snap --app "Google Chrome"      # put a window in it, once
capturezone help
```

Options on `zone`:

| | |
|---|---|
| `--display N` | which screen to centre on, numbered as `list` numbers them |
| `--colour RRGGBB` | outline colour, default `00E5FF` |
| `--width N` | outline thickness in points, default `2` |
| `--hotkey SPEC` | default `ctrl+opt+cmd+z`, any modifier plus a letter or digit |
| `--no-hotkey` | register none |
| `--no-menu-bar` | no menu bar item |
| `--quiet` | just the zone, without the OBS instructions |

Sizes are given in **pixels**, the same as OBS reports them. Positions are
**points** from the top left of the primary display, the same as the
Displays arrangement pane. The two differ by the backing scale, and `list`
prints both for every screen.

The zone is remembered in `~/.config/capturezone/zone.json`, so `snap` and
`crop` do not need it spelled out again.

## Can I right-click a window and fit it to the zone?

Not literally. A context menu belongs to the application drawing it, and
macOS gives nothing outside that application any way to add a line to it.
That is a deliberate design, not a gap.

Three things that do work:

**The hot key.** ctrl+opt+cmd+z while `zone` is running. Nothing to set up,
works in every application.

**The menu bar.** While `zone` is running there is a dashed rectangle in the
menu bar. Its first item names whatever you were last in, so it reads
**Fit Google Chrome to zone**. It also hides the outline and copies the OBS
values to the clipboard.

It names the application that *was* front rather than the one that is,
because opening a menu makes capturezone frontmost and by then the window
you were looking at is nobody's idea of the front one. It watches
activations and keeps the last one that was not us.

**The Services menu**, which is the closest macOS gets to the original idea:

1. Open **Shortcuts**, make a new shortcut, add a **Run Shell Script**
   action.
2. Script: `/usr/local/bin/capturezone snap`
3. In the shortcut's **ⓘ** sidebar, tick **Use as Quick Action** and
   **Services Menu**.

It then appears under right-click, **Services**, in applications that show
services without a selection, and always under an application menu's own
Services submenu. Coverage is not universal, which is why it is third on
this list. The first run asks to grant Accessibility to Shortcuts rather
than to capturezone, because the permission follows whatever launches the
command.

## Troubleshooting

**The hot key does nothing, but the outline is there.** That is exactly what
missing Accessibility looks like: drawing needs no permission, moving a
window does. Tick your **terminal** in System Settings, Privacy & Security,
Accessibility, then run it again. The permission follows whatever launched
the command, which is why it is the terminal and not capturezone.

**"Could not register ctrl+opt+cmd+z."** Something else on the machine holds
it. Pick another with `--hotkey ctrl+shift+1`.

**The OBS preview does not match the outline.** Either Fit to Screen was not
applied after the crop, or the canvas is not the size the crop produces.
`capturezone crop` prints both numbers; check them against Settings, Video.

**Every number is double what I expected.** A Retina or scaled display.
`capturezone list` shows the backing scale and both sizes. Keep giving sizes
in pixels and let it do the conversion.

**A window will not move.** Full screen windows and fixed size windows
cannot be positioned by anything, this included. Leave full screen first.

**The outline turned up in my recording.** It cannot come from the zone it
is drawn around, which it sits outside by design. Check you are not also
capturing a second display, and that the Crop/Pad numbers match the zone
rather than an older one.

## Do I have to pay for something to do this?

No, and that is most of the point. Every app below solves this, among many
other things, and every one of them is a good app. None is needed if a
visible rectangle and a crop filter is all you are missing.

Prices are one-time unless marked, and were checked in November 2026.

| Tool | Price | What it gives you here | Still worth it when |
|---|---|---|---|
| [Rectangle](https://rectangleapp.com) | Free, MIT | Halves and thirds only. **Custom sizes are Pro**, so the free version cannot place a 1920x1080 window. | You want tiling generally |
| [Rectangle Pro](https://rectangleapp.com/pro) | $9.99 | Custom window sizes, so it solves the placing half | You want snap areas, per-app rules, gestures |
| [BetterDisplay](https://github.com/waydabber/BetterDisplay) | Free, Pro $21.99 | A real virtual 1920x1080 display, which OBS captures whole with no cropping. **Virtual screens are in the free tier.** | You want a genuine extra screen, HiDPI control, DDC brightness |
| [CleanShot X](https://cleanshot.com) | $35 | Region recording, in its own recorder | You want annotation, scrolling capture, a cloud link |
| [Screen Studio](https://screen.studio) | $9/mo billed yearly | Region recording, in its own recorder | You want automatic zooms and polished edits |
| macOS **⇧⌘5** | Free, built in | Records a region to a file | You only need a file |

**The honest summary.** If you want a *file* of part of your screen, stop
reading and press ⇧⌘5. If you want a *live source in OBS* for streaming,
compositing with a camera, or scene switching, the Crop/Pad filter already
does the work for free and the only thing missing was being able to see the
rectangle. That is a 200 KB binary, not a purchase.

The one case where money genuinely buys a better answer is BetterDisplay's
virtual display. A real 1920x1080 screen you can drag windows onto beats a
guide outline, and it is free. It is also a display driver, which is a much
bigger thing to install than this.

## How it works

The outline is a borderless `NSWindow` at `.screenSaver` level with
`ignoresMouseEvents`, so it floats over everything, follows you between
desktops and never takes a click.

**It is drawn one line width outside the zone, never on it.** A guide drawn
on the boundary ends up inside the capture, and every recording comes out
with a coloured frame around it. Verified by sampling the pixels: with a
3pt outline on a zone starting at x=760, the stroke occupies 757, 758 and
759, and 760 is untouched.

Snapping uses the Accessibility API, the same thing every window manager on
macOS uses. Position, then size, then position again, because a window moved
to a display it does not yet fit on gets clamped to it.

The hot key goes through Carbon's `RegisterEventHotKey`, which needs **no
permission at all**. The modern alternative, a `CGEventTap`, reads every
keystroke on the machine and macOS quite rightly makes you grant Input
Monitoring for it. This is told about one combination and sees nothing else.

## Permissions

| | |
|---|---|
| Drawing the outline | nothing at all |
| The hot key | nothing at all |
| Moving a window | Accessibility, granted to your terminal |

A command line tool inherits the permission of whatever launched it, so the
entry to tick in **System Settings, Privacy & Security, Accessibility** is
your terminal, not capturezone. The first `snap` will ask.

### What it can and cannot see

Accessibility is a broad permission and you should not hand it to a program
off the internet without knowing what it does with it. The whole of this
one's use of it is three calls, all in
[`Snap.swift`](Sources/capturezone/Snap.swift):

| | |
|---|---|
| Reads | `kAXFocusedWindow` of one application: a handle, not any content |
| Writes | that window's `kAXPosition` and `kAXSize` |
| Never touches | window contents, text, the screen, the clipboard, other applications |

It makes **no network calls of any kind**. There is no telemetry, no update
check, and no dependency that could add one: the package has zero external
packages and `grep` for `URLSession` comes back empty.

It writes exactly one file, `~/.config/capturezone/zone.json`, holding four
numbers.

The hot key sees nothing. `RegisterEventHotKey` has the window server
deliver one combination, where a `CGEventTap` would receive every keystroke
on the machine and need Input Monitoring for it.

## What it will not do

Move a window that is full screen, or one that refuses to be resized. No
window manager can.

Make a 1920x1080 display actually exist. That is a virtual display driver,
which means private API or DriverKit, and is what BetterDisplay is for.

Follow a window around. The zone is a fixed rectangle on the screen, by
design: a capture that moves is a capture you cannot frame.

## Licence

MIT. See [LICENSE](LICENSE).
