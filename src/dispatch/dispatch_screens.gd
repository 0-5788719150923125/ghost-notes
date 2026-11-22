extends Node
class_name DispatchScreens

## DispatchScreens - what the desk's screens show, drawn in 2D (next/dispatch.md): the terminal's text on black, the radar's sweep
## and blip, the oscilloscope's trace (each green unless the Props card picks its color, [method set_inks]), the receiver's SDR
## screen (its spectrum and waterfall, [DispatchSpectrum]), a phone's two little screens, the printer's paper; and, drawn once, the chart
## of the council's hours, the receiver's dial at 20.1, the radar's gain scale and a phone's keypad. Words printed on a thing (a
## phone's tape, GOOD and BAD, the handbook's spine) are its make's own ([constant Props.SHAPES] `face`'s `text`).
##
## Each is a viewport of its own, drawn only as what it shows changes ([method DeskMedium]'s rule): the radar's sweep and
## the scope's trace move every frame, the terminal only as a key is struck. The medium hands each a state ([method
## show_terminal], [method show_radar], ...) and the set's glass shows its texture through `shaders/dispatch_screen.gdshader`.
##
## Redacted words on the terminal ([constant DispatchScript.REDACT]) and the coordinates beside the radar's blip are drawn as
## written; [DispatchCensor] hides them over the camera's finished picture, where [method redactions] and [method
## radar_redactions] say they lie. The place the coordinates come to is held in a readout at the scope's foot.

const TERM_SIZE := Vector2i(1120, 840)
const RADAR_SIZE := Vector2i(512, 512)
const SCOPE_SIZE := Vector2i(256, 200)
## The SDR screen (a 5" panel's 5:3) and its parts top to bottom (px): the bar with the frequency, the spectrum, the scale
## of frequencies under it; the waterfall fills the rest.
const SPECTRUM_SIZE := Vector2i(500, 300)
const SPECTRUM_BAR := 24.0
const SPECTRUM_PLOT := 104.0
const SPECTRUM_SCALE := 16.0
## Where the SDR screen's frequencies are labeled (Hz off the dial's), the passband it is set to (Hz either side), and its colors:
## the program's grays, its line, the tuned frequency's mark, the values it reads out.
const SPECTRUM_TICKS := [-4000.0, -2000.0, 0.0, 2000.0, 4000.0]
const SPECTRUM_PASS := 3000.0
const SDR_GROUND := Color(0.075, 0.08, 0.09)
const SDR_BAR := Color(0.13, 0.14, 0.155)
const SDR_PLOT := Color(0.1, 0.105, 0.115)
const SDR_GRID := Color(0.32, 0.34, 0.37, 0.55)
const SDR_LABEL := Color(0.62, 0.65, 0.7)
const SDR_LINE := Color(0.36, 0.8, 0.92)
const SDR_TUNED := Color(0.95, 0.18, 0.12, 0.85)
const SDR_VALUE := Color(1.0, 0.7, 0.22)
const SDR_CENTER := Color(0.4, 0.95, 0.45)
const PHONE_SIZE := Vector2i(300, 368)
## A phone's keypad, drawn once for every phone: its size (px).
const KEYPAD_SIZE := Vector2i(262, 400)
const PAPER_SIZE := Vector2i(768, 3584)
## A printed line's height in the paper's picture (px), and the lines to a panel of it: a perforation every so many.
const PAPER_LINE := 15.0
const PAPER_FOLD := 38
const GAIN_SIZE := Vector2i(256, 256)
## The flip clock's face and the digits its cards are cut from (one atlas, drawn once: a card's halves are its regions);
## the tablet's screen, landscape, and its browser bar's height (px).
const CLOCK_SIZE := Vector2i(448, 200)
const DIGIT_CELL := Vector2i(96, 160)
const TABLET_SIZE := Vector2i(1200, 1600)
## The chart ([method _draw_chart]): its sheet, laid out in [constant CHART_SHEET] units and drawn [constant CHART_SCALE]
## times over so it reads close up; its plot's corner and side; and the three sources, each a box of Io's phase against
## the planet's central meridian (degrees, `cml` and `phase` from and to; Radio JOVE's), and its share of the pen's dots.
const CHART_SHEET := Vector2(840, 600)
const CHART_SCALE := 2.0
const CHART_PLOT := Vector2(78, 104)
const CHART_SIDE := 400.0
const CHART_SOURCES := {
	"Io-A": {"cml": Vector2(200, 270), "phase": Vector2(205, 260), "dots": 0.34},
	"Io-B": {"cml": Vector2(105, 185), "phase": Vector2(80, 110), "dots": 0.46},
	"Io-C": {"cml": Vector2(280, 360), "phase": Vector2(225, 250), "dots": 0.2},
}
## The pen's dots on it, one a night it was heard, and how many of them land in a box; how many nights before tonight it
## was printed.
const CHART_DOTS := 2400
const CHART_IN_BOXES := 0.7
const CHART_PRINTED := 2617
## The printer's type and the pen's hand on the chart.
const PRINT_FACE := "res://fonts/cards/CourierPrime-Regular.ttf"
const PEN_FACE := "res://fonts/hands/Caveat-Variable.ttf"
## Tonight's date, as the chart writes it ([method Macros.tonight]).
const Macros := preload("res://src/data/macros.gd")
## How many phone screens can be lit at once (the one in hand, the ones on the desk, one ringing or texting).
const PHONE_FACES := 5
## The terminal's type: its face, its size (px), its line (px), where its first line and first column are.
const MONO := "res://fonts/cards/CourierPrime-Bold.ttf"
const TERM_FONT := 22
const TERM_LINE := 33.0
const TERM_MARGIN := Vector2(78.0, 70.0)
## The terminal's own phosphor and its dark, the radar's own glow and its glass, and the receiver's oscilloscope's: what is drawn is
## what the glass shows (its tint white), so a color picked ([method set_inks]) is seen at its own hue.
const PHOSPHOR := Color(0.4315, 1.0, 0.5059)
const SCREEN_DARK := Color(0.0056, 0.016, 0.0074)
const RADAR_GLOW := Color(0.2706, 1.0, 0.3569)
const RADAR_GLASS := Color(0.0085, 0.05, 0.017)
## The radar's writing (px): its letters and lines (the readout's; the coordinates' smaller, held clear of the blip's halo by
## their gap, so the censor's box round them never meets the blip); how many degrees of the coordinates beside the blip the scope's radius spans
## from 0, 0 at its middle (hidden, never a real place: they only move as he moves); and the place's readout - its widest line,
## its margin, and how far below the scope's middle its foot is (a share of the radius, inside the bearing ticks); it is centered.
const RADAR_FONT := 15
const RADAR_LINE := 17.0
const TAG_FONT := 11
const TAG_LINE := 13.0
const TAG_GAP := 24.0
const RADAR_SPAN := 0.08
const READOUT_WIDE := 150.0
const READOUT_PAD := 7.0
const READOUT_FOOT := 0.8
const SCOPE_GLOW := Color(0.2863, 1.0, 0.3765)
const SCOPE_GLASS := Color(0.0045, 0.02, 0.009)

var terminal: SubViewport
var keypad: SubViewport
var radar: SubViewport
var scope: SubViewport
var spectrum: SubViewport
var paper: SubViewport
var chart: SubViewport
## Tonight's date, {year, month, day}: the night the chart is printed round ([method set_night]); the clock's until handed.
var night := {}
var dial: SubViewport
var gain: SubViewport
var clock: SubViewport
var digits: SubViewport
var tablet: SubViewport
var faces: Array = []             # the phone screens' viewports
var _term: Face
var _radar: Face
var _scope: Face
var _spectrum: Face
var _paper: Face
var _clock: Face
var _tablet: Face
var _faces: Array = []
var _mono: Font
var _print: Font                 # the chart's type and the pen's hand: held, as a font let go after a draw takes its glyphs with it
var _pen: Font
var _term_ink := PHOSPHOR        # the terminal's text and its dark, the radar's glow and its glass ([method set_inks])
var _term_dark := SCREEN_DARK
var _radar_ink := RADAR_GLOW
var _radar_glass := RADAR_GLASS
var _scope_ink := SCOPE_GLOW
var _scope_glass := SCOPE_GLASS


func _init() -> void:
	name = "DispatchScreens"
	_mono = load(MONO)
	_print = load(PRINT_FACE)
	_pen = load(PEN_FACE)


## Build them, once: [param _labels] (the phones' names) are their makes' own to show now.
func build(_labels: PackedStringArray) -> void:
	if terminal == null:
		terminal = _vp(TERM_SIZE, true)
		_term = Face.new(self, "terminal")
		terminal.add_child(_term)
		radar = _vp(RADAR_SIZE, true)
		_radar = Face.new(self, "radar")
		radar.add_child(_radar)
		scope = _vp(SCOPE_SIZE, true)
		_scope = Face.new(self, "scope")
		scope.add_child(_scope)
		spectrum = _vp(SPECTRUM_SIZE, true)
		_spectrum = Face.new(self, "spectrum")
		# the waterfall's cells crisp, as the program draws them
		_spectrum.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spectrum.add_child(_spectrum)
		paper = _vp(PAPER_SIZE, true)
		_paper = Face.new(self, "paper")
		paper.add_child(_paper)
		for k in PHONE_FACES:
			var vp := _vp(PHONE_SIZE, true)
			var f := Face.new(self, "phone")
			vp.add_child(f)
			faces.append(vp)
			_faces.append(f)
		chart = _vp(Vector2i(CHART_SHEET * CHART_SCALE), false)
		chart.add_child(Face.new(self, "chart"))
		dial = _vp(Vector2i(512, 256), false)
		dial.add_child(Face.new(self, "dial"))
		gain = _vp(GAIN_SIZE, false)
		gain.transparent_bg = true
		gain.add_child(Face.new(self, "gain"))
		keypad = _vp(KEYPAD_SIZE, false)
		keypad.add_child(Face.new(self, "keypad"))
		digits = _vp(Vector2i(DIGIT_CELL.x * 10, DIGIT_CELL.y), false)
		digits.transparent_bg = true
		digits.add_child(Face.new(self, "digits"))
		clock = _vp(CLOCK_SIZE, true)
		_clock = Face.new(self, "clock")
		clock.add_child(_clock)
		tablet = _vp(TABLET_SIZE, true)
		_tablet = Face.new(self, "tablet")
		tablet.add_child(_tablet)


## What the desk's build is handed of these ([method DispatchSet.build]): the chart, the dial, the keypad and the gain scale, by
## name - taken on the main thread, so the build may run on a worker.
func textures() -> Dictionary:
	return {"chart": chart.get_texture(), "dial": dial.get_texture(), "keypad": keypad.get_texture(), "gain": gain.get_texture()}


func _vp(size: Vector2i, live: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.set_meta("live", live)
	add_child(vp)
	return vp


# --- what the medium hands them ---------------------------------------------------------------------------------------

## Tonight's date, `YYYY-MM-DD` (the clock's for anything else): the chart printed again round it where it changed.
func set_night(written: String) -> void:
	var d := Macros.date_of(written)
	if d.is_empty():
		d = Macros.tonight()
	if d == night:
		return
	night = d
	if chart != null:
		(chart.get_child(0) as CanvasItem).queue_redraw()
		chart.render_target_update_mode = SubViewport.UPDATE_ONCE

## The terminal's text drawn in [param term], the radar in [param glow] and the receiver's oscilloscope in [param trace] from here,
## each dark going with it ([method tinted]): a screen drawn again where its color changed.
func set_inks(term: Color, glow: Color, trace: Color) -> void:
	if term != _term_ink:
		_term_ink = term
		_term_dark = tinted(SCREEN_DARK, PHOSPHOR, term)
		if _term != null:
			_term.queue_redraw()
			terminal.render_target_update_mode = SubViewport.UPDATE_ONCE
	if glow != _radar_ink:
		_radar_ink = glow
		_radar_glass = tinted(RADAR_GLASS, RADAR_GLOW, glow)
		if _radar != null:
			_radar.queue_redraw()
			radar.render_target_update_mode = SubViewport.UPDATE_ONCE
	if trace != _scope_ink:
		_scope_ink = trace
		_scope_glass = tinted(SCOPE_GLASS, SCOPE_GLOW, trace)
		if _scope != null:
			_scope.queue_redraw()
			scope.render_target_update_mode = SubViewport.UPDATE_ONCE


## [param own], a color made to go with [param from], made to go with [param to] instead: [param to]'s hue, its saturation and
## brightness scaled by how far [param to]'s are from [param from]'s (a pale tint stays paler than the color, a gray one goes
## gray). [param own] itself where the two are the same color to 8 bits.
static func tinted(own: Color, from: Color, to: Color) -> Color:
	if from.to_html(false) == to.to_html(false):
		return own
	var s := clampf(own.s * to.s / maxf(from.s, 0.001), 0.0, 1.0)
	var v := clampf(own.v * to.v / maxf(from.v, 0.001), 0.0, 1.0)
	return Color.from_hsv(to.h if to.s > 0.001 else own.h, s, v, own.a)


## The terminal as [param st] has it: `{lines: PackedStringArray, asleep, cursor (bool), t}`; drawn again only when it changed.
func show_terminal(st: Dictionary) -> void:
	_show(terminal, _term, st)


## Where the redacted words lie on the terminal's [param lines] (its lines from the top, as [method show_terminal] is
## handed them): `{rect, key}` for each run - its rect (px) from the run's first letter to past its last, a line high about
## the letters' middle; its key, its words and column, the same however it scrolls.
func redactions(lines: PackedStringArray) -> Array:
	var out: Array = []
	for k in lines.size():
		var drawn := DispatchScript.unredacted(String(lines[k]))
		var text := String(drawn["text"])
		var mid := TERM_MARGIN.y + TERM_LINE * float(k) - float(TERM_FONT) * 0.32
		for sp in drawn["spans"]:
			var run: Vector2i = sp
			var x0 := TERM_MARGIN.x + _advance(text.substr(0, run.x))
			var x1 := TERM_MARGIN.x + _advance(text.substr(0, run.y))
			out.append({"rect": Rect2(x0, mid - TERM_LINE * 0.5, x1 - x0, TERM_LINE), "key": hash([text.substr(run.x, run.y - run.x), run.x])})
	return out


func _advance(text: String) -> float:
	return _mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TERM_FONT).x if not text.is_empty() else 0.0


## The radar: `{t (the sweep's clock), rings, blip: {at: Vector2, label, since}, trail: [{at, age}], ping (seconds into the
## last ping, or -1), planes: [{at, heading}], clutter: [{at, fade, chair?}]}`.
func show_radar(st: Dictionary) -> void:
	_show(radar, _radar, st)


## Where the coordinates beside the blip lie on the radar shown now: `{rect, key, line, size}` for each line (px, as [method
## redactions]; its key the same however they change, so one box follows them).
func radar_redactions() -> Array:
	var blip: Dictionary = _radar.state.get("blip", {}) if _radar != null else {}
	if blip.is_empty():
		return []
	var size := Vector2(RADAR_SIZE)
	var out: Array = []
	var k := 0
	for l in _tag(blip["at"] as Vector2, size * 0.5, size.x * 0.47, String(blip.get("label", ""))):
		out.append({"rect": l["rect"], "key": hash(["radar coordinates", k]), "line": TAG_LINE, "size": size})
		k += 1
	return out


## The coordinates written beside a blip at [param at] (the scope's radius 1): its latitude and longitude, from 0, 0 at the
## scope's middle.
static func coordinates(at: Vector2) -> PackedStringArray:
	return PackedStringArray([_degrees(-at.y * RADAR_SPAN, "N", "S", 2), _degrees(at.x * RADAR_SPAN, "E", "W", 3)])


static func _degrees(deg: float, plus: String, minus: String, digits: int) -> String:
	var a := absf(deg)
	var d := floori(a)
	var m := "%.3f" % ((a - float(d)) * 60.0)
	return "%s %s°%s'" % [plus if deg >= 0.0 else minus, str(d).pad_zeros(digits), m.pad_zeros(2)]


## The coordinates beside a blip at [param at] (the scope's radius 1) on a scope of radius [param rad] round [param mid]:
## `{text, base, rect}` a line - its baseline's start and its rect a line high about the letters' middle (px) - [constant
## TAG_GAP] from the blip: on its right unless it is far right, else its left, above or below, the first where the censor's
## box round them clears the readout of [param place].
func _tag(at: Vector2, mid: Vector2, rad: float, place := "") -> Array:
	var p := mid + at * rad
	var lines := coordinates(at)
	var widths: Array = []
	var w := 0.0
	for l in lines:
		widths.append(_mono.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT).x)
		w = maxf(w, float(widths[-1]))
	var h := TAG_LINE * float(lines.size())
	var right := Vector2(p.x + TAG_GAP, p.y - h * 0.5)
	var left := Vector2(p.x - TAG_GAP - w, p.y - h * 0.5)
	var sides := [right, left] if p.x < mid.x + rad * 0.3 else [left, right]
	sides.append_array([Vector2(p.x - w * 0.5, p.y - TAG_GAP - h), Vector2(p.x - w * 0.5, p.y + TAG_GAP)])
	var corner: Vector2 = sides[0]
	if not place.is_empty():
		var avoid: Rect2 = _readout(place, mid, rad)["rect"]
		var pad := Vector2(DispatchCensor.PAD_X, DispatchCensor.HALF_H) * TAG_LINE
		for c in sides:
			if not Rect2(c, Vector2(w, h)).grow_individual(pad.x, pad.y, pad.x, pad.y).intersects(avoid):
				corner = c
				break
	var out: Array = []
	for k in lines.size():
		var x := corner.x if corner.x >= p.x or corner.x + w <= p.x else p.x - float(widths[k]) * 0.5
		var y := corner.y + TAG_LINE * (float(k) + 0.5)
		out.append({"text": lines[k], "base": Vector2(x, y + float(TAG_FONT) * 0.32),
			"rect": Rect2(x, y - TAG_LINE * 0.5, widths[k], TAG_LINE)})
	return out


## The readout of the place [param place] on a scope of radius [param rad] round [param mid]: its box, centered with its foot
## held at [constant READOUT_FOOT], and its lines, each centered in it - parted at a comma, then wrapped to [constant
## READOUT_WIDE] - `{rect, lines: [{text, base}]}` (px).
func _readout(place: String, mid: Vector2, rad: float) -> Dictionary:
	var lines := PackedStringArray()
	var parts := place.split(", ", false)
	for i in parts.size():
		var line := ""
		for word in (parts[i] + ("," if i < parts.size() - 1 else "")).split(" ", false):
			var next := word if line.is_empty() else line + " " + word
			if not line.is_empty() and _mono.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, RADAR_FONT).x > READOUT_WIDE:
				lines.append(line)
				next = word
			line = next
		if not line.is_empty():
			lines.append(line)
	var widths := PackedFloat32Array()
	var w := 0.0
	for l in lines:
		widths.append(_mono.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, RADAR_FONT).x)
		w = maxf(w, widths[-1])
	var size := Vector2(w, RADAR_LINE * float(lines.size())) + Vector2.ONE * READOUT_PAD * 2.0
	var box := Rect2(mid + Vector2(-size.x * 0.5, READOUT_FOOT * rad - size.y), size)
	var out: Array = []
	for k in lines.size():
		out.append({"text": lines[k], "base": Vector2(mid.x - widths[k] * 0.5, box.position.y + READOUT_PAD + RADAR_LINE * (float(k) + 0.78))})
	return {"rect": box, "lines": out}


## The scope ([method DispatchScope.shown]): a figure `{figure, glow, trails}` - its points (the glass's half height 1), how
## brightly the beam draws each, and the figures before it - or a sweep `{trace, was}`, the sweep and the one before it.
func show_scope(st: Dictionary) -> void:
	_show(scope, _scope, st)


## The SDR screen: `{tex (the waterfall's ring, [member DispatchSpectrum.texture]), top (its newest row's image row), trace
## (the spectrum's line, a column each on its scale, 0-1), power}`; dark with no power.
func show_spectrum(st: Dictionary) -> void:
	_show(spectrum, _spectrum, st)


## The paper: `{lines: PackedStringArray (newest last), feed (0-1 of the line being fed), partial (characters of the line
## being printed), fed (all of it fed, in lines: where its holes and perforations are)}`.
func show_paper(st: Dictionary) -> void:
	_show(paper, _paper, st)


## The flip clock: `{from, to (HH:MM), u (0-1 of the cards turning from one to the other)}`.
func show_clock(st: Dictionary) -> void:
	_show(clock, _clock, st)


## The tablet: `{power (0-1), page: TabletPage (none: a blank tab), scroll, lit (its words read, [method TabletPage.draw]),
## tabs (their titles) and tab, url (what the bar says), typing and typed (the bar), box (a search typed into the page's
## own), post (a reply typed into its message box), kb, key and key_k (the keyboard, the key under the finger), load (0-1),
## can_back, tap: Vector2 and tap_u, seed, minutes (the time), battery, now, textures:
## Callable}`; dark with no power.
func show_tablet(st: Dictionary) -> void:
	_show(tablet, _tablet, st)


## A crash's glass: its ground the text's color at this share (the screen's glow and gain bring it up to the color, where a
## full one blows out to white and floods the letters), and its words this many times the terminal's font.
const CRASH_GROUND := 0.5
const CRASH_FONT := 2


## A call's time as a phone shows it: minutes and seconds padded to two digits, and once it has run an hour, the
## [Clock]'s h:mm:ss.
static func call_time(secs: int) -> String:
	if secs >= 3600:
		return Clock.text(float(secs))
	return "%02d:%02d" % [secs / 60, secs % 60]


## Phone screen [param k]: `{mode: call | hold | calling | text | ring | idle, label, words, secs}`.
func show_phone(k: int, st: Dictionary) -> void:
	_show(faces[k], _faces[k], st)


func _show(vp: SubViewport, f: Face, st: Dictionary) -> void:
	if st == f.state:
		return
	f.state = st
	f.queue_redraw()
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# --- the faces --------------------------------------------------------------------------------------------------------

## One face, drawn by its kind.
class Face extends Node2D:
	var screens: DispatchScreens
	var kind := ""
	var state := {}

	func _init(s: DispatchScreens, k: String) -> void:
		screens = s
		kind = k

	func _draw() -> void:
		match kind:
			"terminal": screens._draw_terminal(self, state)
			"radar": screens._draw_radar(self, state)
			"scope": screens._draw_scope(self, state)
			"spectrum": screens._draw_spectrum(self, state)
			"paper": screens._draw_paper(self, state)
			"phone": screens._draw_phone(self, state)
			"chart": screens._draw_chart(self)
			"dial": screens._draw_dial(self)
			"gain": screens._draw_gain(self)
			"keypad": screens._draw_keypad(self)
			"digits": screens._draw_digits(self)
			"clock": screens._draw_clock(self, state)
			"tablet": screens._draw_tablet(self, state)


## The terminal ([method DispatchTerminal.rows_of]): its rows from the top (redacted words as themselves; [DispatchCensor]
## hides them over the picture), the title row in inverse across the panel (`bar`, its columns), a chosen option's row in inverse
## across its words (`chosen`: row, first and last column), a block cursor at
## `cursor_at` (column, row) when `cursor` is on, and an `alert` boxed over the middle of the panel; dark when asleep. A
## crash is the glass in the screen's color edge to edge, its words in black at the middle, a line each part of them.
func _draw_terminal(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(TERM_SIZE)
	c.draw_rect(Rect2(Vector2.ZERO, size), _term_dark)
	if bool(st.get("asleep", true)):
		return
	var crash := String(st.get("crash", ""))
	if not crash.is_empty():
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(_term_ink.r * CRASH_GROUND, _term_ink.g * CRASH_GROUND, _term_ink.b * CRASH_GROUND))
		var big := TERM_FONT * CRASH_FONT
		var parts := DispatchTerminal.wrapped(String(DispatchScript.unredacted(crash)["text"]), DispatchTerminal.COLUMNS / CRASH_FONT - 6)
		var step := TERM_LINE * float(CRASH_FONT)
		var top := size.y * 0.5 - step * (float(parts.size()) * 0.5 - 0.75)
		for k in parts.size():
			c.draw_string(_mono, Vector2(0.0, top + step * float(k)), String(parts[k]), HORIZONTAL_ALIGNMENT_CENTER, size.x, big,
				Color.BLACK)
		return
	var lines: PackedStringArray = st.get("lines", PackedStringArray())
	var cw := _mono.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, TERM_FONT).x
	var bar: Vector2i = st.get("bar", Vector2i(-1, -1))
	var pick: Vector3i = st.get("chosen", Vector3i(-1, 0, 0))
	for k in lines.size():
		var y := TERM_MARGIN.y + TERM_LINE * float(k)
		var text := String(DispatchScript.unredacted(String(lines[k]))["text"])
		var span := Vector2i(bar.x, bar.y) if k == 0 and bar.x >= 0 else (Vector2i(pick.y, pick.z) if k == pick.x else Vector2i(-1, -1))
		if span.x < 0:
			c.draw_string(_mono, Vector2(TERM_MARGIN.x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, TERM_FONT, _term_ink)
			continue
		# only the cells inside the bar are dark; the rest of the row keeps its ink
		var x0 := TERM_MARGIN.x + _advance(text.substr(0, span.x)) - 4.0
		var x1 := TERM_MARGIN.x + _advance(text.substr(0, span.y)) + 4.0
		c.draw_rect(Rect2(x0, y - TERM_LINE * 0.74, x1 - x0, TERM_LINE * 0.98), _term_ink)
		var parts := [[0, span.x, _term_ink], [span.x, span.y, _term_dark], [span.y, text.length(), _term_ink]]
		for part in parts:
			var a: int = part[0]
			var b: int = part[1]
			if b <= a:
				continue
			c.draw_string(_mono, Vector2(TERM_MARGIN.x + _advance(text.substr(0, a)), y), text.substr(a, b - a),
				HORIZONTAL_ALIGNMENT_LEFT, -1, TERM_FONT, part[2])
	if bool(st.get("cursor", false)):
		var at: Vector2i = st.get("cursor_at", Vector2i(0, maxi(lines.size() - 1, 0)))
		var cy := TERM_MARGIN.y + TERM_LINE * float(at.y)
		c.draw_rect(Rect2(TERM_MARGIN.x + cw * float(at.x) + 2.0, cy - float(TERM_FONT) * 0.78, cw * 0.9, float(TERM_FONT) * 0.95), _term_ink)
	var alert: PackedStringArray = st.get("alert", PackedStringArray())
	if not alert.is_empty():
		var wide := 0
		for l in alert:
			wide = maxi(wide, String(l).length())
		var cols := float(wide + 6)
		var mid_col := float(DispatchTerminal.COLUMNS) * 0.5
		var top_row := float(DispatchTerminal.BODY_TOP + DispatchTerminal.BODY_ROWS / 2) - float(alert.size() + 2) * 0.5
		var box := Rect2(TERM_MARGIN.x + cw * (mid_col - cols * 0.5), TERM_MARGIN.y + TERM_LINE * (top_row - 0.74),
			cw * cols, TERM_LINE * float(alert.size() + 2))
		c.draw_rect(box, _term_dark)
		c.draw_rect(box, _term_ink, false, 3.0)
		c.draw_rect(box.grow(-7.0), _term_ink, false, 1.5)
		for k in alert.size():
			var l := String(alert[k])
			var x := TERM_MARGIN.x + cw * (mid_col - float(l.length()) * 0.5)
			c.draw_string(_mono, Vector2(x, TERM_MARGIN.y + TERM_LINE * (top_row + 1.0 + float(k))), l, HORIZONTAL_ALIGNMENT_LEFT, -1, TERM_FONT, _term_ink)


## The radar: dark green glass, its range rings and cross, the sweep going round with its glow fading behind it, the desk
## at its middle; the target's blip, lit as the sweep passes and fading after, his coordinates written small beside it (hidden
## over the frame, [method radar_redactions]) and the place they come to held in the readout at its foot; the places
## before it fading out; a ping's ring opening out from the blip; an aircraft's small mark drifting across now
## and then; and with the gain turned up, clutter round him, smaller and dimmer, with no name (at the top of the knob one
## on the desk itself, the chair's). Only the glass shows marks: an aircraft comes in from past its edge and leaves past it.
func _draw_radar(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(RADAR_SIZE)
	var mid := size * 0.5
	var rad := size.x * 0.47
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0))
	c.draw_circle(mid, rad, _radar_glass)
	var t := float(st.get("t", 0.0))
	var sweep := fposmod(t / DispatchMedium.SWEEP, 1.0) * TAU - PI * 0.5
	for k in 48:
		var a0 := sweep - float(k + 1) * 0.035
		var a1 := sweep - float(k) * 0.035
		var al := 0.32 * pow(1.0 - float(k) / 48.0, 2.0)
		c.draw_colored_polygon(PackedVector2Array([mid, mid + Vector2.from_angle(a0) * rad, mid + Vector2.from_angle(a1) * rad]), Color(_radar_ink, al))
	var rings := clampi(int(st.get("rings", DispatchScript.SCOPE_RINGS)), 1, 12)
	for k in rings:
		c.draw_arc(mid, rad * float(k + 1) / float(rings), 0.0, TAU, 96, Color(_radar_ink, 0.28), 1.6, true)
	c.draw_line(mid - Vector2(rad, 0), mid + Vector2(rad, 0), Color(_radar_ink, 0.18), 1.2)
	c.draw_line(mid - Vector2(0, rad), mid + Vector2(0, rad), Color(_radar_ink, 0.18), 1.2)
	for k in 36:
		var a := float(k) / 36.0 * TAU
		var inner := 0.95 if k % 3 == 0 else 0.975
		c.draw_line(mid + Vector2.from_angle(a) * rad * inner, mid + Vector2.from_angle(a) * rad, Color(_radar_ink, 0.4), 1.4)
	c.draw_line(mid, mid + Vector2.from_angle(sweep) * rad, Color(_radar_ink, 0.95), 2.6, true)
	c.draw_rect(Rect2(mid - Vector2(4, 4), Vector2(8, 8)), Color(_radar_ink, 0.9))
	for p in st.get("planes", []):
		var pd: Dictionary = p
		var at := mid + (pd["at"] as Vector2) * rad
		var hd := Vector2.from_angle(float(pd.get("heading", 0.0)))
		var lit := _lit(at - mid, sweep)
		c.draw_colored_polygon(PackedVector2Array([at + hd * 7.0, at - hd * 5.0 + hd.orthogonal() * 4.5, at - hd * 2.5, at - hd * 5.0 - hd.orthogonal() * 4.5]),
			Color(_radar_ink, 0.35 + 0.6 * lit))
	for cl in st.get("clutter", []):
		var cd: Dictionary = cl
		var at := mid + (cd["at"] as Vector2) * rad
		c.draw_circle(at, 3.3, Color(_radar_ink, float(cd["fade"]) * (0.18 + 0.5 * _lit(at - mid, sweep))))
	for tr in st.get("trail", []):
		var td: Dictionary = tr
		var at := mid + (td["at"] as Vector2) * rad
		c.draw_circle(at, 3.6, Color(_radar_ink, 0.55 * clampf(float(td.get("fade", 1.0 - float(td["age"]) / 4.0)), 0.0, 1.0)))
	var blip: Dictionary = st.get("blip", {})
	if not blip.is_empty():
		var at := mid + (blip["at"] as Vector2) * rad
		var lit := _lit(at - mid, sweep)
		var since := float(blip.get("since", 99.0))
		var fresh := clampf(1.0 - since / 1.2, 0.0, 1.0)
		c.draw_circle(at, 7.0 + 4.0 * fresh, Color(_radar_ink, 0.25 + 0.4 * lit))
		c.draw_circle(at, 4.5, Color(_radar_ink.lightened(0.4), 0.55 + 0.45 * maxf(lit, fresh)))
		for l in _tag(blip["at"] as Vector2, mid, rad, String(blip.get("label", ""))):
			c.draw_string(_mono, l["base"], String(l["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT, Color(_radar_ink, 0.85))
		var ping := float(st.get("ping", -1.0))
		if ping >= 0.0 and ping < DispatchScript.PING_LEN:
			var u := ping / DispatchScript.PING_LEN
			for k in 2:
				var uu := clampf(u - float(k) * 0.18, 0.0, 1.0)
				if uu > 0.0:
					c.draw_arc(at, 8.0 + uu * rad * 0.55, 0.0, TAU, 72, Color(_radar_ink, 0.85 * (1.0 - uu)), 2.2, true)
		var place := String(blip.get("label", ""))
		if not place.is_empty():
			var ro := _readout(place, mid, rad)
			c.draw_rect(ro["rect"], Color(_radar_glass, 0.92))
			c.draw_rect(ro["rect"], Color(_radar_ink, 0.35), false, 1.2)
			for l in ro["lines"]:
				c.draw_string(_mono, l["base"], String(l["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, RADAR_FONT, Color(_radar_ink, 0.7 + 0.3 * fresh))
	# the black round the glass goes on last, out to the corners: a mark past the glass's edge (a plane coming in or going,
	# clutter, a ping's ring, the coordinates) is never seen over it
	var far := mid.length() + 2.0
	c.draw_arc(mid, (rad + far) * 0.5, 0.0, TAU, 128, Color(0.0, 0.0, 0.0), far - rad)
	c.draw_arc(mid, rad, 0.0, TAU, 128, Color(0.0, 0.0, 0.0), 8.0, true)


## How lit a mark at [param at] (from the middle) still is: the sweep passed it, and its phosphor fades behind.
static func _lit(at: Vector2, sweep: float) -> float:
	var behind := fposmod(sweep - at.angle(), TAU)
	return exp(-behind / 1.6)


## How much of the glass's half height a full-scale trace reaches, and how bright the sweep before it still glows.
const SCOPE_REACH := 0.9
const SCOPE_AFTERGLOW := 0.3


## The scope: a dim grid, and the receiver's output on it as [DispatchScope] draws it - a figure turning in depth, its beam
## brightest where it moves slowest, the figures before it fading on the phosphor; or a sweep across the glass (its hiss a fine
## thread, a pop a spike, a voice its own wave), the sweep before it fading. What is louder than the glass holds runs off it.
func _draw_scope(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(SCOPE_SIZE)
	c.draw_rect(Rect2(Vector2.ZERO, size), _scope_glass)
	for k in range(1, 8):
		var x := size.x * float(k) / 8.0
		c.draw_line(Vector2(x, 0), Vector2(x, size.y), Color(_scope_ink, 0.12), 1.0)
	for k in range(1, 6):
		var y := size.y * float(k) / 6.0
		c.draw_line(Vector2(0, y), Vector2(size.x, y), Color(_scope_ink, 0.12), 1.0)
	var lit := _scope_ink.lightened(0.2)
	if st.has("figure"):
		var trails: Array = st.get("trails", [])
		for k in range(mini(trails.size(), DispatchScope.TRAILS.size()) - 1, -1, -1):
			_beam(c, (trails[k] as Array)[0], (trails[k] as Array)[1], float(DispatchScope.TRAILS[k]), lit)
		_beam(c, st["figure"], st.get("glow", PackedFloat32Array()), 1.0, lit)
		return
	for which in [["was", SCOPE_AFTERGLOW], ["trace", 0.9]]:
		var v: PackedFloat32Array = st.get(which[0], PackedFloat32Array())
		if v.size() < 2:
			continue
		var pts := PackedVector2Array()
		pts.resize(v.size())
		for i in v.size():
			pts[i] = Vector2(size.x * float(i) / float(v.size() - 1), size.y * 0.5 * (1.0 - v[i] * SCOPE_REACH))
		c.draw_polyline(pts, Color(lit, float(which[1])), 2.0, true)


## A figure's [param points] (the glass's half height 1, its middle 0) drawn as the beam draws them on the scope's glass: each
## as bright as [param glow] says, at [param fade] of it, in [param lit].
func _beam(c: CanvasItem, points: PackedVector2Array, glow: PackedFloat32Array, fade: float, lit: Color) -> void:
	if points.size() < 2:
		return
	var size := Vector2(SCOPE_SIZE)
	var half := size.y * 0.5 * SCOPE_REACH
	var pts := PackedVector2Array()
	pts.resize(points.size())
	var cols := PackedColorArray()
	cols.resize(points.size())
	for i in points.size():
		pts[i] = size * 0.5 + Vector2(points[i].x, -points[i].y) * half
		cols[i] = Color(lit, (glow[i] if i < glow.size() else 1.0) * fade)
	c.draw_polyline_colors(pts, cols, 1.6, true)


## The SDR screen, as a hobbyist's program draws it: a bar with the frequency tuned and the mode, the spectrum's line over a
## grid of decibels with the passband shaded and the tuned frequency marked, the frequencies under it, and the waterfall
## filling the rest - its newest row at the top ([method DispatchSpectrum.top]), drawn down to the ring's end and on from its
## start. Black with no power.
func _draw_spectrum(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(SPECTRUM_SIZE)
	if float(st.get("power", 1.0)) < 0.5:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
		return
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, size), SDR_GROUND)
	# the bar: the frequency, the mode and passband
	c.draw_rect(Rect2(0, 0, size.x, SPECTRUM_BAR), SDR_BAR)
	var mhz := DispatchSpectrum.FREQ / 1e6
	c.draw_string(font, Vector2(8, 18), "%.3f.000" % mhz, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.88, 0.92, 0.96))
	c.draw_string(font, Vector2(104, 18), "MHz", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SDR_LABEL)
	var mode := "AM   BW %.1fk" % (SPECTRUM_PASS * 2.0 / 1000.0)
	c.draw_string(font, Vector2(size.x - 8 - font.get_string_size(mode, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, 17), mode,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SDR_VALUE)
	# the spectrum: a grid of decibels and frequencies, the passband shaded, the tuned frequency's mark, the line
	var plot := Rect2(0, SPECTRUM_BAR, size.x, SPECTRUM_PLOT)
	c.draw_rect(plot, SDR_PLOT)
	var x_of := func(hz: float) -> float: return (hz / DispatchSpectrum.SPAN + 0.5) * size.x
	var pass0: float = x_of.call(-SPECTRUM_PASS)
	c.draw_rect(Rect2(pass0, plot.position.y, float(x_of.call(SPECTRUM_PASS)) - pass0, plot.size.y), Color(1, 1, 1, 0.05))
	var db := -40.0
	while db > DispatchSpectrum.DB_LOW:
		var y := plot.end.y - (db - DispatchSpectrum.DB_LOW) / (DispatchSpectrum.DB_HIGH - DispatchSpectrum.DB_LOW) * plot.size.y
		c.draw_line(Vector2(0, y), Vector2(size.x, y), SDR_GRID, 1.0)
		c.draw_string(font, Vector2(4, y - 2), "%d dB" % int(db), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SDR_LABEL)
		db -= 20.0
	for hz in SPECTRUM_TICKS:
		var x: float = x_of.call(float(hz))
		c.draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), SDR_GRID, 1.0)
	var trace: PackedFloat32Array = st.get("trace", PackedFloat32Array())
	if trace.size() == DispatchSpectrum.COLS:
		var pts := PackedVector2Array()
		pts.resize(trace.size())
		for k in trace.size():
			pts[k] = Vector2((float(k) + 0.5) / float(trace.size()) * size.x, plot.end.y - trace[k] * plot.size.y)
		c.draw_polyline(pts, SDR_LINE, 1.5, true)
	c.draw_line(Vector2(size.x * 0.5, plot.position.y), Vector2(size.x * 0.5, plot.end.y), SDR_TUNED, 1.0)
	# the scale of frequencies
	var scale_y := plot.end.y
	c.draw_rect(Rect2(0, scale_y, size.x, SPECTRUM_SCALE), SDR_GROUND)
	for hz in SPECTRUM_TICKS:
		var x: float = x_of.call(float(hz))
		var label := "%.3f" % ((DispatchSpectrum.FREQ + float(hz)) / 1e6)
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		c.draw_line(Vector2(x, scale_y), Vector2(x, scale_y + 3), SDR_LABEL, 1.0)
		c.draw_string(font, Vector2(clampf(x - w * 0.5, 2.0, size.x - w - 2.0), scale_y + 13), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			SDR_CENTER if is_zero_approx(float(hz)) else SDR_LABEL)
	# the waterfall, newest at the top: the ring from its newest row to its end, then on from its start
	var tex: Texture2D = st.get("tex")
	if tex == null:
		return
	var wf := Rect2(0, scale_y + SPECTRUM_SCALE, size.x, size.y - scale_y - SPECTRUM_SCALE)
	var rows := float(DispatchSpectrum.ROWS)
	var top := int(st.get("top", 0))
	var first := float(DispatchSpectrum.ROWS - top)
	var row_h := wf.size.y / rows
	c.draw_texture_rect_region(tex, Rect2(wf.position, Vector2(wf.size.x, first * row_h)),
		Rect2(0, top, DispatchSpectrum.COLS, first))
	if top > 0:
		c.draw_texture_rect_region(tex, Rect2(wf.position.x, wf.position.y + first * row_h, wf.size.x, float(top) * row_h),
			Rect2(0, 0, DispatchSpectrum.COLS, top))


## The paper as it lies from the slot (the picture's foot) back along itself: continuous paper, sprocket holes down both edges
## and a perforation every panel ([constant PAPER_FOLD] lines), each where `fed` lines of feeding have brought it; the lines
## printed, the newest nearest the slot, each older line further along as the paper fed.
func _draw_paper(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(PAPER_SIZE)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.93, 0.92, 0.87))
	var shift := float(st.get("feed", 0.0)) * PAPER_LINE
	var fed := float(st.get("fed", 0.0)) * PAPER_LINE
	var fold := PAPER_LINE * float(PAPER_FOLD)
	var hole := fold / 22.0
	var y := size.y - fposmod(fed, hole)
	while y > 8.0:
		for x in [16.0, size.x - 16.0]:
			c.draw_circle(Vector2(x, y), 5.5, Color(0.18, 0.17, 0.15))
		y -= hole
	c.draw_line(Vector2(32, 0), Vector2(32, size.y), Color(0.75, 0.74, 0.7), 1.0)
	c.draw_line(Vector2(size.x - 32, 0), Vector2(size.x - 32, size.y), Color(0.75, 0.74, 0.7), 1.0)
	var fy := size.y - fposmod(fed, fold)
	while fy > 0.0:
		c.draw_dashed_line(Vector2(0, fy), Vector2(size.x, fy), Color(0.7, 0.69, 0.65), 1.0, 4.0)
		fy -= fold
	var lines: PackedStringArray = st.get("lines", PackedStringArray())
	var ink := Color(0.12, 0.13, 0.2, 0.88)
	var partial := String(st.get("partial", ""))
	var yy := size.y - 10.0 - shift
	if not partial.is_empty():
		c.draw_string(_mono, Vector2(44, yy), partial, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
	for k in range(lines.size() - 1, -1, -1):
		yy -= PAPER_LINE
		if yy < 24.0:
			break
		c.draw_string(_mono, Vector2(44, yy), String(lines[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)


## A phone's screen: amber-lit monochrome - the one in hand, or one laid open on the desk mid-call (`hold`), its caller's
## name and the call's clock, one dialing CALLING; the little one outside a text's sender and words, or a ring's caller.
func _draw_phone(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(PHONE_SIZE)
	var mode := String(st.get("mode", "idle"))
	var lit := Color(0.62, 0.78, 0.5) if mode != "idle" else Color(0.08, 0.1, 0.07)
	c.draw_rect(Rect2(Vector2.ZERO, size), lit)
	if mode == "idle":
		return
	var k := size.x / 200.0
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var w := size.x / k
	var ink := Color(0.04, 0.06, 0.03)
	var label := String(st.get("label", ""))
	var secs := int(float(st.get("secs", 0.0)))
	var clock := call_time(secs)
	for b in 4:
		c.draw_rect(Rect2(10 + b * 9, 30 - b * 5, 6, 6 + b * 5), ink)
	c.draw_rect(Rect2(w - 44, 14, 32, 16), ink, false, 2.0)
	c.draw_rect(Rect2(w - 40, 18, 20, 8), ink)
	match mode:
		"call", "hold", "calling":
			c.draw_string(_mono, Vector2(0, 98), label, HORIZONTAL_ALIGNMENT_CENTER, w, 30, ink)
			var under := "CALLING" if mode == "calling" else clock
			c.draw_string(_mono, Vector2(0, 150), under, HORIZONTAL_ALIGNMENT_CENTER, w, 26, ink)
		"dial":
			var digits := String(st.get("digits", ""))
			c.draw_string(_mono, Vector2(0, 118), digits, HORIZONTAL_ALIGNMENT_CENTER, w, 64, ink)
			if not digits.is_empty():
				c.draw_string(_mono, Vector2(0, 168), "SPEED DIAL", HORIZONTAL_ALIGNMENT_CENTER, w, 18, ink)
				c.draw_string(_mono, Vector2(0, 196), label, HORIZONTAL_ALIGNMENT_CENTER, w, 24, ink)
		"read":
			_draw_thread(c, st, w, ink)
		"text":
			c.draw_string(_mono, Vector2(10, 70), label, HORIZONTAL_ALIGNMENT_LEFT, w - 20, 26, ink)
			c.draw_multiline_string(_mono, Vector2(10, 108), String(st.get("words", "")), HORIZONTAL_ALIGNMENT_LEFT, w - 20, 24, 4, ink)
		"ring":
			c.draw_string(_mono, Vector2(0, 100), label, HORIZONTAL_ALIGNMENT_CENTER, w, 30, ink)
			c.draw_string(_mono, Vector2(0, 150), "CALLING", HORIZONTAL_ALIGNMENT_CENTER, w, 24, ink)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A text thread on a phone held up: who it is with across the top, then each message in turn - theirs at the left, the
## answers at the right as they are typed, a cursor while one is, SENT under it once it goes - the newest at the bottom.
func _draw_thread(c: CanvasItem, st: Dictionary, w: float, ink: Color) -> void:
	var h := float(PHONE_SIZE.y) / (float(PHONE_SIZE.x) / 200.0)
	c.draw_string(_mono, Vector2(10, 64), String(st.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, w - 20, 24, ink)
	c.draw_line(Vector2(8, 74), Vector2(w - 8, 74), ink, 2.0)
	var thread: Array = st.get("thread", [])
	var size := 19
	var lines: Array = []                   # [text, at the right, a mark under it]
	for m in thread:
		var e: Array = m
		var out := String(e[0]) == "out"
		var words := String(e[1])
		var wrapped := _wrap(words + ("_" if out and not bool(e[2]) else ""), w - 50, size)
		for li in wrapped.size():
			lines.append([wrapped[li], out, ""])
		if out and bool(e[2]):
			lines.append(["SENT", true, "sent"])
		lines.append(["", false, ""])
	var line_h := float(size) + 5.0
	var room := int((h - 92.0) / line_h)
	if lines.size() > room:
		lines = lines.slice(lines.size() - room)
	var y := 96.0
	for l in lines:
		var ln: Array = l
		var text := String(ln[0])
		if not text.is_empty():
			var px := 14 if String(ln[2]) == "sent" else size
			if bool(ln[1]):
				c.draw_string(_mono, Vector2(40, y), text, HORIZONTAL_ALIGNMENT_RIGHT, w - 50, px, ink)
			else:
				c.draw_string(_mono, Vector2(10, y), text, HORIZONTAL_ALIGNMENT_LEFT, w - 50, px, ink)
		y += line_h


## [param text] in lines no wider than [param width] at [param px].
func _wrap(text: String, width: float, px: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var tried := word if line.is_empty() else line + " " + word
		if _mono.get_string_size(tried, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width and not line.is_empty():
			out.append(line)
			line = word
		else:
			line = tried
	if not line.is_empty():
		out.append(line)
	return out


## A phone's keypad: across the top Send (green, a handset) and End (red, a handset hung up) either side of a round
## navigation key; under them the twelve keys, 1 to 9, *, 0 and #, each its digit and the letters under it.
func _draw_keypad(c: CanvasItem) -> void:
	var size := Vector2(KEYPAD_SIZE)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.055))
	var key := Color(0.62, 0.63, 0.65)
	var ink := Color(0.08, 0.08, 0.09)
	var top := size.y * 0.24
	var side := Vector2(size.x * 0.27, top * 0.62)
	for pair in [[Vector2(size.x * 0.03, top * 0.2), Color(0.16, 0.62, 0.28), false], [Vector2(size.x * 0.70, top * 0.2), Color(0.78, 0.18, 0.15), true]]:
		var at: Vector2 = pair[0]
		c.draw_rect(Rect2(at, side), key)
		_draw_handset(c, at + side * 0.5, side.y * 0.34, pair[1], bool(pair[2]))
	var mid := Vector2(size.x * 0.5, top * 0.5)
	c.draw_circle(mid, top * 0.42, key)
	c.draw_circle(mid, top * 0.17, key.darkened(0.25))
	for a in 4:
		var d := Vector2.UP.rotated(float(a) * PI * 0.5)
		var tip := mid + d * top * 0.34
		c.draw_colored_polygon(PackedVector2Array([tip, tip - d * 8.0 + d.orthogonal() * 6.0, tip - d * 8.0 - d.orthogonal() * 6.0]), ink)
	var keys := [["1", ""], ["2", "ABC"], ["3", "DEF"], ["4", "GHI"], ["5", "JKL"], ["6", "MNO"], ["7", "PQRS"], ["8", "TUV"],
		["9", "WXYZ"], ["*", ""], ["0", "+"], ["#", ""]]
	var cell := Vector2(size.x / 3.0, (size.y - top) / 4.0)
	for i in keys.size():
		var at := Vector2(float(i % 3) * cell.x, top + float(i / 3) * cell.y)
		var r := Rect2(at + Vector2(5, 4), cell - Vector2(10, 8))
		c.draw_rect(r, key)
		var kv: Array = keys[i]
		c.draw_string(_mono, Vector2(r.position.x, r.position.y + r.size.y * 0.58), String(kv[0]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 40, ink)
		if not String(kv[1]).is_empty():
			c.draw_string(_mono, Vector2(r.position.x, r.position.y + r.size.y * 0.9), String(kv[1]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, ink)


## A handset's mark at [param at], [param r] across: lifted (Send) or laid down (End).
func _draw_handset(c: CanvasItem, at: Vector2, r: float, col: Color, down: bool) -> void:
	var tilt := 0.0 if down else -0.6
	var pts := PackedVector2Array()
	for a in 13:
		var u := PI * float(a) / 12.0
		pts.append(at + Vector2(cos(u) * r, -sin(u) * r * 0.55).rotated(tilt))
	for a in range(12, -1, -1):
		var u := PI * float(a) / 12.0
		pts.append(at + Vector2(cos(u) * r * 0.62, -sin(u) * r * 0.25).rotated(tilt))
	c.draw_colored_polygon(pts, col)
	for e in [-1.0, 1.0]:
		c.draw_circle(at + Vector2(e * r * 0.82, r * 0.08).rotated(tilt), r * 0.24, col)



## The chart: the hobbyist's page printed out, a plot with no dates on it - Io's phase up its side against the planet's
## central meridian along its foot, the three sources each a hatched box, his rates and table beside it, and the browser's
## footer with the night it was printed, years before tonight ([member night]). Over it the pen's dots, one a night it was
## heard, the old ones faded, most in a box and the rest where they fell; tonight's dot in Io-B (the receiver opens on its
## crackle), circled.
func _draw_chart(c: CanvasItem) -> void:
	var pr := _print
	var at := func(rot: float, p: Vector2) -> void:
		c.draw_set_transform_matrix(Transform2D(rot, Vector2(CHART_SCALE, CHART_SCALE), 0.0, p * CHART_SCALE))
	at.call(0.0, Vector2.ZERO)
	c.draw_rect(Rect2(Vector2.ZERO, CHART_SHEET), Color(0.93, 0.91, 0.85))
	var ink := Color(0.1, 0.1, 0.12)
	var faint := Color(0.1, 0.1, 0.12, 0.22)
	var footer := Color(0.1, 0.1, 0.12, 0.6)
	var tonight: Dictionary = night if not night.is_empty() else Macros.tonight()
	# where it was folded once to fit a pocket, and a ring from a cup set down on it
	c.draw_line(Vector2(0, 300), Vector2(CHART_SHEET.x, 303), Color(1, 1, 1, 0.35), 3.0)
	c.draw_line(Vector2(0, 302), Vector2(CHART_SHEET.x, 305), Color(0.4, 0.36, 0.3, 0.12), 1.0)
	c.draw_arc(Vector2(790, 560), 46.0, PI * 0.9, PI * 1.75, 40, Color(0.55, 0.4, 0.22, 0.16), 4.0, true)
	c.draw_string(_mono, Vector2(36, 44), "JUPITER DECAMETRIC SOURCES", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ink)
	c.draw_string(pr, Vector2(36, 70), "WHEN TO LISTEN AT 20.1 MHz - GOOD FOR ANY YEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	# the plot: a degree's place, its grid every 30 and numbers every 90
	var o := CHART_PLOT + Vector2(0, CHART_SIDE)
	var pt := func(cml: float, phase: float) -> Vector2: return o + Vector2(cml, -phase) * (CHART_SIDE / 360.0)
	for d in range(0, 361, 30):
		var f := float(d)
		var w := 1.6 if d % 90 == 0 else 0.8
		var line := faint if d % 360 != 0 else ink
		c.draw_line(pt.call(f, 0.0), pt.call(f, 360.0), line, w)
		c.draw_line(pt.call(0.0, f), pt.call(360.0, f), line, w)
		if d % 90 == 0:
			var lab := str(d)
			var lw := pr.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			c.draw_string(pr, Vector2(pt.call(f, 0.0)) + Vector2(-lw * 0.5, 18), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
			c.draw_string(pr, Vector2(pt.call(0.0, f)) + Vector2(-lw - 6, 5), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	c.draw_string(pr, o + Vector2(CHART_SIDE * 0.5 - 118, 40), "CENTRAL MERIDIAN (SYS III)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	at.call(-PI * 0.5, CHART_PLOT + Vector2(-44, CHART_SIDE * 0.5 + 40))
	c.draw_string(pr, Vector2.ZERO, "PHASE OF Io", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	at.call(0.0, Vector2.ZERO)
	for k in CHART_SOURCES:
		var src: Dictionary = CHART_SOURCES[k]
		var cml: Vector2 = src["cml"]
		var phase: Vector2 = src["phase"]
		var box := Rect2(pt.call(cml.x, phase.y), Vector2(cml.y - cml.x, phase.y - phase.x) * (CHART_SIDE / 360.0))
		var u := 0.0
		while u < box.size.x + box.size.y:
			var p0 := box.position + Vector2(minf(u, box.size.x), maxf(u - box.size.x, 0.0))
			var p1 := box.position + Vector2(maxf(u - box.size.y, 0.0), minf(u, box.size.y))
			c.draw_line(p0, p1, Color(0.1, 0.1, 0.12, 0.3), 1.0)
			u += 7.0
		c.draw_rect(box, ink, false, 1.6)
		c.draw_string(_mono, box.position + Vector2(3, -5), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	# beside it: how to read it, his rates, his table
	var lines := [
		"HOW TO USE",
		"Look up Io's phase and the CML",
		"for your hour. Where the two",
		"meet in a box, listen.",
		"",
		"CML  one turn   9h 55m 30s",
		"Io   one turn  42h 28m",
		"",
		"SOURCE  CML      Io PHASE",
		"Io-A   200-270  205-260",
		"Io-B   105-185   80-110",
		"Io-C   280-360  225-250",
		"",
		"Io-B  short bursts, popcorn",
		"Io-A  long bursts, like surf",
	]
	for i in lines.size():
		var head: bool = i == 0 or String(lines[i]).begins_with("SOURCE")
		c.draw_string(_mono if head else pr, Vector2(530, 128 + 22.0 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	var printed := Macros.shifted(tonight, -CHART_PRINTED)
	c.draw_string(pr, Vector2(36, 584), Macros.written(printed, "MM/DD/YYYY") + "  11:52 PM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, footer)
	c.draw_string(pr, Vector2(720, 584), "Page 1 of 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, footer)
	# the pen: a dot a night, oldest first and faded, most of them in a box
	var r := RandomNumberGenerator.new()
	r.seed = "chart-dots".hash()
	var old_ink := Color(0.42, 0.4, 0.38, 0.5)
	var pen := Color(0.12, 0.18, 0.55, 0.85)
	var keys := CHART_SOURCES.keys()
	for i in CHART_DOTS:
		var cml := r.randf() * 360.0
		var phase := r.randf() * 360.0
		if r.randf() < CHART_IN_BOXES:
			var pick := r.randf()
			var src: Dictionary = CHART_SOURCES[keys[-1]]
			for k in keys:
				pick -= float((CHART_SOURCES[k] as Dictionary)["dots"])
				if pick <= 0.0:
					src = CHART_SOURCES[k]
					break
			var sc: Vector2 = src["cml"]
			var sp: Vector2 = src["phase"]
			cml = r.randf_range(sc.x, sc.y)
			phase = r.randf_range(sp.x, sp.y)
		var age := float(i) / float(CHART_DOTS)
		c.draw_circle(pt.call(cml, phase) + Vector2(r.randf_range(-1, 1), r.randf_range(-1, 1)), r.randf_range(1.2, 2.0), old_ink.lerp(pen, age * age))
	# tonight: one more in Io-B, ringed, and his word beside the box
	var tr := RandomNumberGenerator.new()
	tr.seed = ("chart-" + Macros.written(tonight)).hash()
	var bc: Vector2 = (CHART_SOURCES["Io-B"] as Dictionary)["cml"]
	var bp: Vector2 = (CHART_SOURCES["Io-B"] as Dictionary)["phase"]
	var mid: Vector2 = pt.call(tr.randf_range(bc.x + 15.0, bc.y - 15.0), tr.randf_range(bp.x + 6.0, bp.y - 6.0))
	var fresh := Color(0.06, 0.08, 0.4)
	c.draw_circle(mid, 3.4, fresh)
	for turn in 2:
		var ring := PackedVector2Array()
		for i in 41:
			var a := float(i) / 40.0 * TAU * 1.08 + 0.4 + float(turn) * 0.7
			ring.append(mid + Vector2(cos(a) * (24.0 + tr.randf_range(-2.0, 2.0)), sin(a) * (20.0 + tr.randf_range(-2.0, 2.0))))
		c.draw_polyline(ring, fresh, 2.6, true)
	var note: Vector2 = Vector2(pt.call(bc.y, bp.x)) + Vector2(8, 22)
	c.draw_string(_pen, note, "talks the most", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, pen)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


## The radar's gain scale, printed round its knob: a tick and a number for each step, one to ten, from the lower left round
## over the top to the lower right ([method DispatchSet.gain_angle]); clear between, so the face shows through.
func _draw_gain(c: CanvasItem) -> void:
	var size := Vector2(GAIN_SIZE)
	var mid := size * 0.5
	var ink := Color(0.86, 0.84, 0.74)
	var knob := DispatchSet.GAIN_KNOB_R * size.x / DispatchSet.GAIN_FACE
	for n in range(DispatchScript.GAIN_LEAST, DispatchScript.GAIN_MOST + 1):
		var a := DispatchSet.gain_angle(float(n))
		var d := Vector2(-sin(a), -cos(a))
		c.draw_line(mid + d * (knob + 4.0), mid + d * (knob + 12.0), ink, 3.0, true)
		var label := "%d" % n
		var w := _mono.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		c.draw_string(_mono, mid + d * (knob + 30.0) + Vector2(-w.x * 0.5, w.y * 0.3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)


## The receiver's dial: a white face (the prop tints it, [constant DispatchSet.RECEIVER_FIELDS] `paper`) with the band's
## megahertz along it in black, a tick every fifth of one, and the cursor where it is tuned - the SDR screen's own frequency
## ([constant DispatchSpectrum.FREQ]).
const DIAL_MHZ := Vector2(18.0, 22.0)
const DIAL_X := Vector2(40.0, 472.0)


func _draw_dial(c: CanvasItem) -> void:
	var size := Vector2(512, 256)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
	var ink := Color(0.02, 0.02, 0.02)
	var x_of := func(mhz: float) -> float: return lerpf(DIAL_X.x, DIAL_X.y, (mhz - DIAL_MHZ.x) / (DIAL_MHZ.y - DIAL_MHZ.x))
	var ticks := int(round((DIAL_MHZ.y - DIAL_MHZ.x) * 5.0))
	for k in ticks + 1:
		var x: float = x_of.call(DIAL_MHZ.x + float(k) * 0.2)
		c.draw_line(Vector2(x, 120), Vector2(x, 150 if k % 5 == 0 else 138), ink, 3.0)
	for mhz in range(int(DIAL_MHZ.x), int(DIAL_MHZ.y) + 1):
		var label := "%d" % mhz
		var w := _mono.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		c.draw_string(_mono, Vector2(float(x_of.call(float(mhz))) - w * 0.5, 190), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink)
	c.draw_string(_mono, Vector2(40, 70), "MHz", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ink)
	var tuned := DispatchSpectrum.FREQ / 1e6
	var at: float = x_of.call(tuned)
	c.draw_line(Vector2(at, 90), Vector2(at, 230), Color(0.7, 0.05, 0.03), 4.0)
	var said := "%.1f" % tuned
	c.draw_string(_mono, Vector2(at - _mono.get_string_size(said, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x * 0.5, 250), said,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.05, 0.03))


## The digits 0-9 a flip clock's cards show, white, one to a cell: drawn once, each card's halves cut from it.
func _draw_digits(c: CanvasItem) -> void:
	for d in 10:
		var x := float(DIGIT_CELL.x * d)
		var fs := int(DIGIT_CELL.y * 0.86)
		var w := _mono.get_string_size(str(d), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		c.draw_string(_mono, Vector2(x + (float(DIGIT_CELL.x) - w) * 0.5, float(DIGIT_CELL.y) * 0.80), str(d), HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(0.93, 0.92, 0.88))


## The flip clock: four cards and a colon, each card a dark rounded slab split across its middle; a card whose digit changes
## turns over - the top half of the old falling forward to the hinge, then the bottom half of the new swinging down from it.
func _draw_clock(c: CanvasItem, st: Dictionary) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(CLOCK_SIZE)), Color(0.015, 0.015, 0.018))
	var old := String(st.get("from", "--:--")).replace(":", "")
	var now := String(st.get("to", "--:--")).replace(":", "")
	var u := clampf(float(st.get("u", 1.0)), 0.0, 1.0)
	var xs := [16.0, 120.0, 236.0, 340.0]
	var top := 20.0
	var cell := Vector2(DIGIT_CELL)
	var tex := digits.get_texture()
	var card := Color(0.09, 0.09, 0.10)
	# each digit flaps on its own, the rightmost that changes first ([method DispatchScript.flap_starts]), falling as a flap
	# let go does and slapping down ([method DispatchScript.flap_angle])
	var starts := DispatchScript.flap_starts(String(st.get("from", "")), String(st.get("to", "")))
	var since := u * DispatchScript.CLOCK_TURN
	for i in 4:
		var x: float = xs[i]
		var r := Rect2(x, top, cell.x, cell.y)
		var a := old[i] if i < old.length() and old[i].is_valid_int() else ""
		var b := now[i] if i < now.length() and now[i].is_valid_int() else ""
		var v := clampf((since - starts[i]) / DispatchScript.CLOCK_FLAP, 0.0, 1.0) if starts[i] >= 0.0 and u < 1.0 else 1.0
		var turning := a != b and v < 1.0
		var th := DispatchScript.flap_angle(v)
		var half := cell.y * 0.5
		var hinge := top + half
		# the top half: the new digit behind; the old one's top falls forward over it until it passes level
		_card_half(c, tex, Rect2(x, top, cell.x, half), b, true, card)
		if turning and th < PI * 0.5:
			var k := cos(th)
			_card_half(c, tex, Rect2(x, hinge - half * k, cell.x, half * k), a, true, card.darkened(0.25 * (1.0 - k)))
		# the bottom half: the old digit until the new one's bottom swings down over it and bounces off its stop
		_card_half(c, tex, Rect2(x, hinge, cell.x, half), a if turning and th < PI * 0.5 else b, false, card)
		if turning and th >= PI * 0.5:
			var k := -cos(th)
			_card_half(c, tex, Rect2(x, hinge, cell.x, half * k), b, false, card.lightened(0.05 * (1.0 - k)))
		c.draw_line(Vector2(x, hinge), Vector2(x + cell.x, hinge), Color(0.0, 0.0, 0.0), 3.0)
		c.draw_rect(r, Color(0.0, 0.0, 0.0, 0.6), false, 2.0)
	for dy in [-24.0, 24.0]:
		c.draw_circle(Vector2(224.0, top + cell.y * 0.5 + dy), 7.0, Color(0.85, 0.84, 0.8))


func _card_half(c: CanvasItem, tex: Texture2D, dest: Rect2, digit: String, upper: bool, card: Color) -> void:
	if dest.size.y <= 0.5:
		return
	c.draw_rect(dest, card)
	if digit.is_empty():
		return
	var d := int(digit)
	var src := Rect2(float(DIGIT_CELL.x * d), 0.0 if upper else float(DIGIT_CELL.y) * 0.5, float(DIGIT_CELL.x), float(DIGIT_CELL.y) * 0.5)
	c.draw_texture_rect_region(tex, dest, src)


## The tablet ([TabletChrome]): dark when off; awake, the page set by the tablet medium ([TabletPage]), scrolled, the
## words read off it lit as the tablet medium lights them - a blank tab's page where there is none - under the browser: its
## tabs, back, the address bar (typed into while an address is typed, a line loading under it); a search typed into the
## page's own box, a reply into its message box; the status bar with the desk's time; the keyboard while anything is
## typed; a finger's tap a ring.
func _draw_tablet(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(TABLET_SIZE)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0))
	var power := float(st.get("power", 0.0))
	if power <= 0.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
	var page: TabletPage = st.get("page", null)
	var top := TabletChrome.TOP
	var down := Vector2(0.0, top - float(st.get("scroll", 0.0)))
	if page != null:
		page.draw(c, top, float(st.get("scroll", 0.0)), top, size.y, st.get("lit", {}), float(st.get("now", 0.0)),
			st.get("textures", func(_k: String) -> Texture2D: return null),
			{"sent": st.get("sent", []), "sound": st.get("sound", false)})
		if st.has("box"):
			TabletChrome.draw_typed(c, Rect2(page.search_rect.position + down, page.search_rect.size), String(st["box"]))
		if st.has("post"):
			TabletChrome.draw_typed(c, Rect2(page.reply_rect.position + down, page.reply_rect.size - Vector2(160.0, 0.0)), String(st["post"]), 28.0)
	else:
		TabletChrome.draw_start(c, size, int(st.get("seed", 0)))
	var typing := bool(st.get("typing", false))
	TabletChrome.draw_browser(c, size, {"tabs": st.get("tabs", [""]), "tab": int(st.get("tab", 0)), "can_back": bool(st.get("can_back", false)),
		"url": String(st.get("url", "")), "editing": typing, "typed": String(st.get("typed", "")), "load": float(st.get("load", -1.0)),
		"now": float(st.get("now", 0.0))})
	TabletChrome.draw_status(c, size, true, int(st.get("minutes", 0)), float(st.get("battery", 70.0)))
	TabletChrome.draw_keyboard(c, size, float(st.get("kb", 0.0)), String(st.get("key", "")), float(st.get("key_k", 0.0)))
	var tap_u := float(st.get("tap_u", -1.0))
	if tap_u >= 0.0 and tap_u < 1.0:
		var at: Vector2 = st.get("tap", size * 0.5)
		c.draw_circle(at, lerpf(26.0, 56.0, tap_u), Color(0.16, 0.42, 1.0, 0.35 * (1.0 - tap_u)))
	if power < 1.0:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 1.0 - power))
