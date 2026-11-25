extends Node

## Boot - the earliest hook (first autoload), for things that must happen before the window is drawn into.
## In export-render mode (--export) it keeps the render window off-screen and unfocused so it barely flickers
## into view (the OS maps the window during engine init, so a flash cannot be avoided entirely).
##
## Never minimize a Movie Maker window: Godot skips rendering a minimized window, the movie writer re-captures
## the last buffer while audio advances, and the recording freezes (a black video on Wayland). The exporter
## shrinks the OS window instead (window_*_override in override.cfg): the movie records the viewport, which in
## the export's "viewport" stretch mode is independent of the window size.

func _enter_tree() -> void:
	if not OS.get_cmdline_user_args().has("--export"):
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-5000, -5000))   # X11 honors this


## The product's name, for everything a person sees: the window title and the home screen. The code keeps
## "ghost" for its directory, settings file and frontmatter key. The project's `application/config/name` is this
## name too, so project.godot names the user:// folder outright (`custom_user_dir_name`, held by docs.py's
## `check_user_dir`) or Godot would rename it.
const NAME := "Ghost Notes"
const TAGLINE := "A Spectral Experience"
const TITLE := NAME + ": " + TAGLINE


## Editor projects have a source directory. Exported projects run from an embedded pack;
## override.cfg must sit beside the executable for the next process to read it.
static func project_dir() -> String:
	return ProjectSettings.globalize_path("res://") if OS.has_feature("editor") \
		else OS.get_executable_path().get_base_dir()


static func project_args() -> PackedStringArray:
	return PackedStringArray(["--path", project_dir()]) if OS.has_feature("editor") \
		else PackedStringArray()

## How much of its screen the window opens on, each way.
const WINDOW_SHARE := 0.75
## Engine arguments that say where or how big the window is - a launch that gives one keeps it.
const WINDOW_ARGS := ["--resolution", "--position", "-f", "--fullscreen", "-m", "--maximized"]

## The phone shell (next/notes.md step 11): a phone or tablet, or `--handheld` / `GHOST_HANDHELD=1` on the
## desktop. The flag decides, not the window size. [member handheld_for_test] is a gate's seam.
static var handheld_for_test := false


static func handheld() -> bool:
	return handheld_for_test or OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--handheld") \
		or OS.get_environment("GHOST_HANDHELD") == "1"


## The window opens at three quarters of its screen, centered on the space the desktop leaves free (panels
## and docks excluded). The project's 1920x1080 is the stage, which the canvas_items stretch scales to any
## window; Godot's default would open a window that size, a quarter of a 4K screen. Only for a person's
## session: a render, a probe or a headless run keeps the size it was given, as does a launch that names a size,
## a position or a mode. [param force] is the probe's seam. True when the window was resized.
##
## Maximized instead where three quarters would be smaller than the 1920x1080 the interface is laid out in
## ([method maximizes]: a laptop's screen, a 1080p monitor), which would draw every word smaller than designed.
## It also gets the window out of Godot's first size: opened at 1920x1080 on a 1920-wide screen, it is as wide
## as the screen, KWin takes it as maximized across and holds it there, and a resize to three quarters kept
## only the new height - a window the screen's full width and short of its height.
func fit_window(force := false) -> bool:
	if not force:
		if DisplayServer.get_name() == "headless" or Settings.is_read_only():
			return false
		for a in OS.get_cmdline_args():
			if WINDOW_ARGS.has(String(a).get_slice("=", 0)):
				return false
	var win := get_window()
	if win == null or win.mode != Window.MODE_WINDOWED:
		return false
	var area := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	if area.size.x <= 0 or area.size.y <= 0:
		return false
	var size := Vector2i(roundi(area.size.x * WINDOW_SHARE), roundi(area.size.y * WINDOW_SHARE))
	win.size = size
	win.position = area.position + (area.size - size) / 2
	# the size above stays what un-maximizing comes back to
	if maximizes(area.size):
		win.mode = Window.MODE_MAXIMIZED
	return true


## Whether a window on [param area] of free screen opens maximized: three quarters of it would be smaller than the
## interface's 1920x1080 either way.
static func maximizes(area: Vector2i) -> bool:
	var design := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 1920),
		ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	return area.x * WINDOW_SHARE < design.x - 0.5 or area.y * WINDOW_SHARE < design.y - 0.5


## The phone shell on the desktop opens in a phone's shape (portrait, most of the screen's height) for a
## person; a phone fills its own screen, and a probe keeps the size it was given.
func _fit_handheld() -> void:
	if OS.has_feature("mobile") or DisplayServer.get_name() == "headless" or Settings.is_read_only():
		return
	var win := get_window()
	if win == null or win.mode != Window.MODE_WINDOWED:
		return
	var area := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var h := roundi(area.size.y * 0.85)
	var size := Vector2i(roundi(h * 9.0 / 16.0), h)
	win.size = size
	win.position = area.position + (area.size - size) / 2


## Tooltip wrapping, applied to the whole app, AS EACH TOOLTIP IS SHOWN: Godot's tooltip label has no autowrap and no theme
## item to turn it on, so a long description runs off the screen. The label Godot builds to show a tooltip (its theme type
## variation `TooltipLabel`) is re-flowed as it enters the tree, before its panel is sized ([method fold_tooltip]): real
## newlines at a measured pixel width, in the font and size it draws with, a word longer than a line broken where the line
## ends. So every tooltip is folded - a control's, a menu item's, a tree item's, one a control works out where the pointer
## is, one rewritten every frame - and no control's own `tooltip_text` is ever changed. Blank-line paragraph breaks are kept.
const TIP_MAX_PX := 480.0
## The theme type variation Godot gives the label it shows a tooltip in.
const TIP_LABEL := &"TooltipLabel"


func _ready() -> void:
	lend_symbol_fonts()
	if OS.get_cmdline_user_args().has("--apply-update") \
			or OS.get_cmdline_user_args().has("--update-smoke-hold"):
		return
	# Here, not in _enter_tree: autoloads all enter the tree before any is ready, so Settings has not yet decided
	# whether this process is a render or a probe.
	if handheld():
		_fit_handheld()
	elif not OS.get_cmdline_user_args().has("--export"):
		fit_window()
		# the words as large as this screen's pixels ask for, at any window (a render and a probe are read-only: never)
		UiScale.watch(get_window())
	get_window().title = TITLE
	# The window's icon is this machine's ghost ([AppIcon]); project.godot names none. An autoload's ready comes
	# after Godot sets its own icon, so this one stays.
	AppIcon.apply()
	get_tree().node_added.connect(_hook_tooltip)


## Fonts for the symbols the UI uses, found once. Ghost ships no UI font, so text is Godot's own (Open Sans
## SemiBold), which lacks ○ ✓ ✕ ⚙ ⟳ ▶; for each, the shaper would ask the system (fontconfig) on every label layout, 5 to
## 8 ms against 0.2 for plain text. Handed to the default font as fallbacks they are found in 0.15 ms.
##
## Only the sans families fontconfig itself turns to (Noto Sans, then DejaVu Sans), at the default font's weight.
## A font taller than the default is never lent: Godot takes a label's height from the tallest font on the list
## (Noto Sans Symbols 2 made every label 11 px taller). No emoji font either: it would paint ⏸ ⏺ 🎞 🖼 in color.
## What none of these has (an emoji, ⏳, ⤓) still finds its font the slow way. One [SystemFont] per family, since a
## SystemFont is the first of its names that is installed; a machine with neither family lends nothing.
const SYMBOL_FONTS := ["Noto Sans", "DejaVu Sans"]


static func lend_symbol_fonts() -> void:
	var base := ThemeDB.fallback_font
	if base == null or OS.has_feature("mobile") or OS.has_feature("web") or not base.fallbacks.is_empty():
		return
	var have := OS.get_system_fonts()
	var lent: Array[Font] = []
	for family in SYMBOL_FONTS:
		if not have.has(family):
			continue
		var f := SystemFont.new()
		f.font_names = PackedStringArray([family])
		f.font_weight = base.get_font_weight()
		f.font_stretch = base.get_font_stretch()
		if f.get_height(100) <= base.get_height(100):
			lent.append(f)
	base.fallbacks = lent


## The backstop for background programs. Every child ghost starts goes through [Subprocess], which remembers
## it; this kills whatever is still registered when the app closes, so a mode that forgets to clean up still
## cannot leave an `ffmpeg` writing to disk. Boot is the first autoload, so it is the last standing at shutdown.
##
## This is the clean-quit half only. If ghost is killed outright no script runs, which is why `Subprocess` also
## binds each child to this process at the kernel level (see its class doc).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		Subprocess.reap_all()


func _hook_tooltip(n: Node) -> void:
	if n is Label:
		fold_tooltip(n as Label)


## [param label], where it is the label Godot shows a tooltip in, its text re-flowed ([method wrap_tip]) - as it enters the tree, before
## the tooltip's panel takes its size from it. Any other label is left as it is.
static func fold_tooltip(label: Label) -> void:
	if label.theme_type_variation != TIP_LABEL or label.text.is_empty():
		return
	var wrapped := wrap_tip(label.text, TIP_MAX_PX)
	if wrapped != label.text:
		label.text = wrapped


## Re-flow `text` so no line exceeds `max_px` in the tooltip's own font: broken between words, and a word longer than a line (a
## path, a link) broken where the line ends. Public, so anything that builds a tooltip string by hand can fold it the same way.
static func wrap_tip(text: String, max_px := TIP_MAX_PX) -> String:
	var f: Font = ThemeDB.fallback_font
	if f == null or max_px <= 0.0:
		return text
	var fsize := ThemeDB.get_default_theme().get_font_size("font_size", "TooltipLabel")
	if fsize <= 0:
		fsize = ThemeDB.fallback_font_size
	var paras: Array = []
	for para in text.split("\n\n"):
		var lines: Array = []
		var line := ""
		for word in String(para).replace("\n", " ").split(" ", false):
			for w in _pieces(String(word), f, fsize, max_px):
				if line.is_empty():
					line = w
					continue
				var probe := line + " " + w
				if f.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > max_px:
					lines.append(line)
					line = w
				else:
					line = probe
		if not line.is_empty():
			lines.append(line)
		paras.append("\n".join(lines))
	return "\n\n".join(paras)


## [param word] as it is, or - wider than [param max_px] alone - in pieces each as wide as a line holds.
static func _pieces(word: String, f: Font, fsize: int, max_px: float) -> PackedStringArray:
	if f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x <= max_px:
		return PackedStringArray([word])
	var out := PackedStringArray()
	var piece := ""
	for ch in word:
		if not piece.is_empty() and f.get_string_size(piece + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > max_px:
			out.append(piece)
			piece = ""
		piece += ch
	if not piece.is_empty():
		out.append(piece)
	return out
