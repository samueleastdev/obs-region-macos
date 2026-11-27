# obs-region-macos

**Capture a fixed region of your screen in OBS on macOS.** Draws the crop
rectangle on screen as a guide, prints the Crop/Pad numbers, and snaps
windows into it with a hot key.

One 171 KB binary. No dependencies, no OBS plugin, no menu bar app.

```sh
capturezone zone --centre 1920x1080    # the outline appears, ctrl+opt+cmd+z snaps a window into it
capturezone crop                       # the four numbers OBS wants
```

---

## Does OBS have region capture on macOS?

No. OBS on macOS offers macOS Screen Capture with three methods, Display,
Window and Application, and there is no fourth. You cannot draw a box and
record it the way **⇧⌘5** does.

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

OBS source: macOS Screen Capture, Display, GF340E
OBS canvas and output: 1920x1080

Crop/Pad filter, Relative ticked:
  Left    760
  Top     180
  Right   760
  Bottom  180
```

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

1. `capturezone crop` and keep the output.
2. OBS, **Settings, Video**: set Base (Canvas) and Output (Scaled) to the
   size it printed.
3. **Add Source, macOS Screen Capture**, Method **Display**, the display it
   named.
4. Right-click the source, **Filters, +, Crop/Pad**. Leave **Relative**
   ticked and enter the four numbers.
5. Right-click the source, **Transform, Fit to Screen** (⌘F).
6. `capturezone zone --centre 1920x1080` and leave it running while you work.

## Install

```sh
git clone https://github.com/samueleastdev/obs-region-macos
cd obs-region-macos
swift build -c release
ln -sf "$PWD/.build/release/capturezone" /usr/local/bin/capturezone
```

Needs the Swift toolchain, which comes with Xcode or the Command Line Tools
(`xcode-select --install`). macOS 13 or later.

## Commands

```sh
capturezone list                           # displays, and the numbers to place a zone
capturezone zone --centre 1920x1080        # draw it, stay running, Ctrl-C to stop
capturezone zone --rect 760,180,1920,1080  # place it by hand instead
capturezone crop                           # the OBS Crop/Pad numbers
capturezone snap --app "Google Chrome"     # put a window in it, once
```

While `zone` is running, **ctrl+opt+cmd+z** puts the frontmost window in the
rectangle. `--hotkey ctrl+shift+1` picks another, `--no-hotkey` registers
none. Also `--colour RRGGBB` and `--width N`.

The zone is remembered in `~/.config/capturezone/zone.json`, so `snap` and
`crop` do not need it spelled out again.

## Do I have to pay for something to do this?

No, and that is most of the point. Every app below solves this, among many
other things, and every one of them is a good app. None of them is needed
if a visible rectangle and a crop filter is all you are missing.

Prices are one-time unless marked, and were checked in November 2026.

| | Price | What it gives you here | Still worth it when |
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
rectangle. That is a 171 KB binary, not a purchase.

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

The hot key is registered through Carbon's `RegisterEventHotKey`, which
needs **no permission at all**. The modern alternative, a `CGEventTap`,
reads every keystroke on the machine and macOS quite rightly makes you grant
Input Monitoring for it. This is told about one combination and sees nothing
else.

## Permissions

Drawing the outline needs nothing at all.

Moving a window needs Accessibility. A command line tool inherits the
permission of whatever launched it, so the entry to tick in **System
Settings, Privacy & Security, Accessibility** is your terminal, not
capturezone. The first `snap` will ask.

## What it will not do

Move a window that is full screen, or one that refuses to be resized. No
window manager can.

Make a 1920x1080 display actually exist. That is a virtual display driver,
which means private API or DriverKit, and is what BetterDisplay is for.

Follow a window around. The zone is a fixed rectangle on the screen, by
design: a capture that moves is a capture you cannot frame.

## Licence

MIT.
