# The app's icon

Asked 2026-10-31: "The icon for this project kind of sucks. I also don't like how we've pre-created
it, and shipped as a static thing with the project ... a simple picture of a ghost ... with the color
changed depending upon what is generated ... hash on something machine-stable, such that different
users get different icons." Then: "Don't forget about mobile", and "If mobile icons are fixed, then we
can at least generate novel ones for every build, so that new updates always come with a new icon."

## What an app can change, and where

| Where the icon shows | Who draws it | Can it differ per machine? |
| --- | --- | --- |
| A desktop window (taskbar, Alt-Tab, title bar) | the running app, `DisplayServer.set_icon(Image)` | yes, at every launch |
| Android's launcher | the package's `res/mipmap-*` (adaptive: foreground, background, monochrome) | no: fixed per build |
| iOS's home screen | the bundle's asset catalog | no: fixed per build |
| A Windows `.exe`, a macOS `.app` | resources written at export | no: fixed per build |

Godot sets its own icon in `Main::start` (the project's `config/icon`, else its logo); autoloads
become ready after that, so Boot's `set_icon` is the one that stays (read back under Xvfb: Godot's
128 px logo first, then the 256 px ghost, the pixels matching). X11 takes it as `_NET_WM_ICON`;
native Wayland (Godot 4.6+, godotengine/godot#107096) through `xdg-toplevel-icon-v1`, which KWin has.

A phone can only CHOOSE among icons already in its package: Android by enabling one of several
`activity-alias` entries (`PackageManager.setComponentEnabledSetting`, a native plugin; some launchers
drop the shortcut when it changes), iOS by `setAlternateIconName` (the system shows an alert each
time). So a device-picked ghost would be N ghosts baked per build, the device choosing by its id - not
built.

## Built (2026-10-31)

- `src/platform/app_icon.gd` (`AppIcon`): a ghost as data rows - bodies (an SVG path each), poses
  (arms pinned at the shoulders), eyes, mouths, props (a note, two beamed notes, sparkles), backdrop
  styles (tile, disc, aura) - composed into one SVG with colors from a salted SHA-256 and drawn by the
  engine's ThorVG (`Image.load_svg_from_string`). Layers for the platforms that put an icon together
  themselves: whole, square (opaque, iOS), backdrop, figure (inside Android's 66/108 safe circle),
  mono (white, the face cut out by a luminance mask).
- THE WINDOW'S: `Boot._ready` -> `AppIcon.apply()`, seeded by `OS.get_unique_id()` (machine-id on
  Linux), hashed with the salt `ghost-icon`. `icon.svg` and `config/icon` are gone.
- THE PACKAGE'S: `scripts/build.sh` runs `src/platform/app_icon_tool.gd` before exporting, seeded by
  the commit (a dirty tree's by the moment too; `GHOST_ICON_SEED` picks one), into `dist/icons/`; the
  Android preset's `launcher_icons/*` name those files. A scratch project's APK carried all four
  byte for byte.
- EVERY GHOST STANDS IN THE MIDDLE (same day: "quite a few of the ghosts are off-center ... allow
  for the two to overlap a bit, so long as the note or stars aren't covering the face"): a body's
  drawn box is centered (its row's `middle`, measured), one size with a prop or without, and a prop's
  box perches on the head (its inner bottom corner on the row's `perch`, above the eyes and outside
  the cheeks, through the ghost's own lean and mirror) - over the head's outline, never the face.
- Gate: `tests/platform/app_icon_check.gd`. Probe: `tests/platform/app_icon_probe.gd` writes
  `dist/app_icons/sheet.png` (36 ghosts, this machine's ringed) and `this_machine.png` (every size,
  dark and light, and a phone's masks).

## Open

- A real `scripts/build.sh android` run (not made while a render was running) and the ghost on a
  phone.
- iOS: no preset yet. The files are written (`ios_1024.png`, `_dark`, `_tinted`); the preset's
  `icons/icon_1024x1024`, `icons/icon_1024x1024_dark` and `icons/icon_1024x1024_tinted` should name
  them.
- Windows' `.exe` keeps Godot's icon (`application/modify_resources=false`): an `.ico` from the
  build's ghost and the preset's `application/icon` would carry it. macOS has no preset.
- Exporting from the editor without build.sh finds no icons and fails ("No project icon specified").
- More rows when wanted: poses, props (a page, a pen), a hat.
