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

## The window opens at three quarters of its screen, centered on the space the desktop leaves free (panels
## and docks excluded). The project's 1920x1080 is the stage, which the canvas_items stretch scales to any
## window; Godot's default would open a window that size, a quarter of a 4K screen. Only for a person's
## session: a render, a probe or a headless run keeps the size it was given, as does a launch that names a size,
## a position or a mode. [param force] is the probe's seam. True when the window was resized.
## The phone shell (next/notes.md step 11): a phone or tablet, or `--handheld` / `GHOST_HANDHELD=1` on the
## desktop. The flag decides, not the window size. [member handheld_for_test] is a gate's seam.
static var handheld_for_test := false


static func handheld() -> bool:
	return handheld_for_test or OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--handheld") \
		or OS.get_environment("GHOST_HANDHELD") == "1"


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
	return true


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


## Tooltip wrapping, applied to the whole app.
##
## Godot's tooltip label has no autowrap and no theme item to turn it on, so a long description runs off the
## screen. The text is re-flowed instead: real newlines inserted at a measured pixel width, in the font and size
## the tooltip draws with. Hooked from `node_added`, so it covers every mode, dialog and later-added control.
##
## Re-flowing is idempotent (a wrapped paragraph collapses to one line and re-wraps identically), so it can
## run on every hover and a tooltip rewritten at runtime stays wrapped. Blank-line paragraph breaks are kept.
const TIP_MAX_PX := 480.0


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
	# A menu's items are not controls: each item's tooltip is re-flowed as the menu opens, after whatever fills
	# it has run
	if n is PopupMenu:
		var pop: PopupMenu = n
		if not pop.about_to_popup.is_connected(wrap_items):
			pop.about_to_popup.connect(wrap_items.bind(pop))
		return
	if not (n is Control):
		return
	var c: Control = n
	# On hover, because that also catches tooltips rewritten after the control was built.
	if not c.mouse_entered.is_connected(_wrap_tooltip):
		c.mouse_entered.connect(_wrap_tooltip.bind(c))
	# And once now, for controls that never emit mouse_entered themselves (a Label defaults to
	# MOUSE_FILTER_IGNORE) but whose tooltip is surfaced through an ancestor.
	_wrap_tooltip.call_deferred(c)


func _wrap_tooltip(c: Control) -> void:
	if not is_instance_valid(c) or c.tooltip_text.is_empty():
		return
	var wrapped := wrap_tip(c.tooltip_text, TIP_MAX_PX)
	if wrapped != c.tooltip_text:
		c.tooltip_text = wrapped


## Every item of [param pop] with a tooltip, its tooltip re-flowed ([method wrap_tip]).
static func wrap_items(pop: PopupMenu) -> void:
	if not is_instance_valid(pop):
		return
	for i in pop.item_count:
		var tip := pop.get_item_tooltip(i)
		if tip.is_empty():
			continue
		var wrapped := wrap_tip(tip, TIP_MAX_PX)
		if wrapped != tip:
			pop.set_item_tooltip(i, wrapped)


## Re-flow `text` so no line exceeds `max_px` in the tooltip's own font. Public, so anything that
## builds a tooltip string by hand can pre-wrap it the same way.
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
			var w := String(word)
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
