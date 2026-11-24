extends RefCounted
class_name UiScale

## UiScale - how large the interface is drawn on a person's screen.
##
## The window stretches its canvas (`canvas_items`, 1920 x 1080 units, project.godot), so a unit is as many pixels as
## the window is wide over 1920 or high over 1080, whichever is less. That ties the size of the words to the size of
## the window rather than to the screen: a 4K screen's window of three quarters draws a unit at 1.5 pixels, and a
## 1920 x 1200 laptop's whole screen draws it at one - two thirds as large on a screen with as many pixels to the inch,
## and smaller again in a smaller window.
##
## So a unit is never drawn smaller than the screen's pixel density asks for ([method wanted]: its DPI over
## [constant REF_DPI], 1.46 at a 14-inch 1920 x 1200's 161): the window's [member Window.content_scale_factor] makes up
## what its size does not, and the canvas is that much smaller in units. A window large enough already (a 4K screen's)
## is drawn as it always was. Never past [constant LEAST], the least canvas the panels and the show beside them fit in.
## On top of that, a person's own zoom, a step at a time ([method step]: Ctrl+= and Ctrl+-, Ctrl+0 back), kept in
## `[display] ui_zoom`.
##
## Only a person's session on a desktop ([method watch], from [Boot]): a render, a probe, a headless run and the phone
## shell (its own scale) keep a unit to a unit. The stage is drawn in pixels: main sizes it by the canvas a unit to a
## unit, so a larger interface never draws the show coarser.

const SECTION := "display"
const KEY := "ui_zoom"
## The DPI a unit is drawn a pixel at: a desktop monitor's (a 24-inch 1080p is 92, a 27-inch 1440p 109).
const REF_DPI := 110.0
## A DPI outside this is a screen saying nothing true about its size (a TV's placeholder millimeters): it is taken as
## [constant REF_DPI].
const DPI_TRUSTED := Vector2(60.0, 400.0)
## The least canvas the interface is laid out in, in units: a side panel, the show beside it, the row and the transport.
const LEAST := Vector2(1280.0, 720.0)
## A person's zoom, step by step: 1.0 is the screen's own size.
const ZOOMS := [0.67, 0.75, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0]

static var _window: WeakRef = null


## Size [param win]'s interface for its screen now and whenever it is resized - for a person's session alone (see the
## class doc). True when it is watched.
static func watch(win: Window) -> bool:
	if win == null or DisplayServer.get_name() == "headless" or Settings.is_read_only():
		return false
	_window = weakref(win)
	if not win.size_changed.is_connected(refit):
		win.size_changed.connect(refit)
	refit()
	return true


## The watched window, or null (a render, a probe, the phone shell).
static func window() -> Window:
	return _window.get_ref() as Window if _window != null else null


## The interface sized again: the screen's own scale, the person's zoom, within [constant LEAST]. Reached on every
## resize; setting the factor resizes the canvas, which reaches here again and changes nothing.
static func refit() -> void:
	var win := window()
	if win == null:
		return
	var f := factor_for(Vector2(win.size), DisplayServer.screen_get_dpi(win.current_screen), zoom())
	if not is_equal_approx(f, win.content_scale_factor):
		win.content_scale_factor = f


## The content scale a window [param px] pixels large takes on a screen of [param dpi], at the person's [param z].
static func factor_for(px: Vector2, dpi: int, z: float) -> float:
	var k := stretch(px)
	if k <= 0.0:
		return 1.0
	var f := maxf(1.0, wanted(dpi) / k) * z
	return clampf(f, 0.5, most(px))


## How many pixels a unit is at [param px] by the stretch alone: the window over the design's 1920 x 1080.
static func stretch(px: Vector2) -> float:
	var design := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 1920),
		ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	if design.x <= 0.0 or design.y <= 0.0:
		return 0.0
	return minf(px.x / design.x, px.y / design.y)


## The least pixels a unit is drawn at on a screen of [param dpi] (1 where the DPI says nothing true).
static func wanted(dpi: int) -> float:
	if float(dpi) < DPI_TRUSTED.x or float(dpi) > DPI_TRUSTED.y:
		return 1.0
	return maxf(1.0, float(dpi) / REF_DPI)


## The largest content scale a window [param px] large holds: its canvas no smaller than [constant LEAST].
static func most(px: Vector2) -> float:
	var k := stretch(px)
	if k <= 0.0:
		return 1.0
	var canvas := px / k
	return maxf(1.0, minf(canvas.x / LEAST.x, canvas.y / LEAST.y))


## The person's zoom, one of [constant ZOOMS].
static func zoom() -> float:
	var z := float(Settings.read(SECTION, KEY, 1.0))
	return z if z > 0.0 else 1.0


## One step larger ([param by] 1) or smaller (-1), or back to the screen's own size (0). Returns what it is now, as a
## person reads it ([method describe]); "" where nothing is watched.
static func step(by: int) -> String:
	var win := window()
	if win == null:
		return ""
	var z := 1.0
	if by != 0:
		var at := 0
		var now := zoom()
		for i in ZOOMS.size():
			if absf(float(ZOOMS[i]) - now) < absf(float(ZOOMS[at]) - now):
				at = i
		z = float(ZOOMS[clampi(at + signi(by), 0, ZOOMS.size() - 1)])
	Settings.write(SECTION, KEY, z)
	refit()
	return describe()


## How large the interface is now, as a person reads it: "Interface 146%", with whose size it is.
static func describe() -> String:
	var win := window()
	if win == null:
		return ""
	var pct := roundi(stretch(Vector2(win.size)) * win.content_scale_factor * 100.0)
	var z := zoom()
	var whose := "this screen's own size" if is_equal_approx(z, 1.0) else "zoomed to %d%% of this screen's size" % roundi(z * 100.0)
	if win.content_scale_factor >= most(Vector2(win.size)) - 0.001 and z > 1.0:
		whose = "the largest this window holds"
	return "Interface %d%% - %s" % [pct, whose]
