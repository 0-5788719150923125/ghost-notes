extends Node
class_name DispatchScreens

## DispatchScreens - what the desk's screens show, drawn in 2D (next/dispatch.md): the terminal's text on black, the radar's sweep
## and blip, the oscilloscope's trace (each green unless the Props card picks its color, [method set_inks]), a phone's two little screens, the printer's paper; and, drawn once, the chart
## of the council's hours, the receiver's dial at 20.1, the radar's gain scale and a phone's keypad. Words printed on a thing (a
## phone's tape, GOOD and BAD, the handbook's spine) are its make's own ([constant Props.SHAPES] `face`'s `text`).
##
## Each is a viewport of its own, drawn only as what it shows changes ([method DeskMedium]'s rule): the radar's sweep and
## the scope's trace move every frame, the terminal only as a key is struck. The medium hands each a state ([method
## show_terminal], [method show_radar], ...) and the set's glass shows its texture through `shaders/dispatch_screen.gdshader`.
##
## Redacted words on the terminal ([constant DispatchScript.REDACT]) are drawn as written; [DispatchCensor] hides them over
## the camera's finished picture, where [method redactions] says they lie.

const TERM_SIZE := Vector2i(1120, 840)
const RADAR_SIZE := Vector2i(512, 512)
const SCOPE_SIZE := Vector2i(256, 200)
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
const SCOPE_GLOW := Color(0.2863, 1.0, 0.3765)
const SCOPE_GLASS := Color(0.0045, 0.02, 0.009)

var terminal: SubViewport
var keypad: SubViewport
var radar: SubViewport
var scope: SubViewport
var paper: SubViewport
var chart: SubViewport
var dial: SubViewport
var gain: SubViewport
var clock: SubViewport
var digits: SubViewport
var tablet: SubViewport
var faces: Array = []             # the phone screens' viewports
var _term: Face
var _radar: Face
var _scope: Face
var _paper: Face
var _clock: Face
var _tablet: Face
var _faces: Array = []
var _mono: Font
var _term_ink := PHOSPHOR        # the terminal's text and its dark, the radar's glow and its glass ([method set_inks])
var _term_dark := SCREEN_DARK
var _radar_ink := RADAR_GLOW
var _radar_glass := RADAR_GLASS
var _scope_ink := SCOPE_GLOW
var _scope_glass := SCOPE_GLASS


func _init() -> void:
	name = "DispatchScreens"
	_mono = load(MONO)


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
		paper = _vp(PAPER_SIZE, true)
		_paper = Face.new(self, "paper")
		paper.add_child(_paper)
		for k in PHONE_FACES:
			var vp := _vp(PHONE_SIZE, true)
			var f := Face.new(self, "phone")
			vp.add_child(f)
			faces.append(vp)
			_faces.append(f)
		chart = _vp(Vector2i(840, 600), false)
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


## The scope: `{t, level (0-1), storm, voice (0-1)}`.
func show_scope(st: Dictionary) -> void:
	_show(scope, _scope, st)


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
## `cursor_at` (column, row) when `cursor` is on, and an `alert` boxed over the middle of the panel; dark when asleep.
func _draw_terminal(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(TERM_SIZE)
	c.draw_rect(Rect2(Vector2.ZERO, size), _term_dark)
	if bool(st.get("asleep", true)):
		return
	var lines: PackedStringArray = st.get("lines", PackedStringArray())
	var cw := _mono.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, TERM_FONT).x
	var bar: Vector2i = st.get("bar", Vector2i(-1, -1))
	var pick: Vector3i = st.get("chosen", Vector3i(-1, 0, 0))
	for k in lines.size():
		var y := TERM_MARGIN.y + TERM_LINE * float(k)
		var text := String(DispatchScript.unredacted(String(lines[k]))["text"])
		var ink := _term_ink
		var span := Vector2i(bar.x, bar.y) if k == 0 and bar.x >= 0 else (Vector2i(pick.y, pick.z) if k == pick.x else Vector2i(-1, -1))
		if span.x >= 0:
			var x0 := TERM_MARGIN.x + _advance(text.substr(0, span.x)) - 4.0
			var x1 := TERM_MARGIN.x + _advance(text.substr(0, span.y)) + 4.0
			c.draw_rect(Rect2(x0, y - TERM_LINE * 0.74, x1 - x0, TERM_LINE * 0.98), _term_ink)
			ink = _term_dark
		c.draw_string(_mono, Vector2(TERM_MARGIN.x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, TERM_FONT, ink)
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
## at its middle; the target's blip, lit as the sweep passes and fading after, its place written small beside it; the
## places before it fading out; a ping's ring opening out from the blip; an aircraft's small mark drifting across now
## and then; and with the gain turned up, clutter round him, smaller and dimmer, with no name (at the top of the knob one
## on the desk itself, the chair's).
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
		var label := String(blip.get("label", ""))
		var right := at.x < mid.x + rad * 0.3
		var pos := at + Vector2(12.0 if right else -12.0, -10.0)
		var w := _mono.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		if not right:
			pos.x -= w
		c.draw_string(_mono, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(_radar_ink, 0.85))
		var ping := float(st.get("ping", -1.0))
		if ping >= 0.0 and ping < DispatchScript.PING_LEN:
			var u := ping / DispatchScript.PING_LEN
			for k in 2:
				var uu := clampf(u - float(k) * 0.18, 0.0, 1.0)
				if uu > 0.0:
					c.draw_arc(at, 8.0 + uu * rad * 0.55, 0.0, TAU, 72, Color(_radar_ink, 0.85 * (1.0 - uu)), 2.2, true)
	c.draw_arc(mid, rad, 0.0, TAU, 128, Color(0.0, 0.0, 0.0), 8.0, true)


## How lit a mark at [param at] (from the middle) still is: the sweep passed it, and its phosphor fades behind.
static func _lit(at: Vector2, sweep: float) -> float:
	var behind := fposmod(sweep - at.angle(), TAU)
	return exp(-behind / 1.6)


## The scope: a dim grid, and the trace across it - a hum's slow sine at rest, the static's jumping noise in a storm, and
## a voice coming in on the receiver as a fast wave swelling and shrinking along it.
func _draw_scope(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(SCOPE_SIZE)
	c.draw_rect(Rect2(Vector2.ZERO, size), _scope_glass)
	for k in range(1, 8):
		var x := size.x * float(k) / 8.0
		c.draw_line(Vector2(x, 0), Vector2(x, size.y), Color(_scope_ink, 0.12), 1.0)
	for k in range(1, 6):
		var y := size.y * float(k) / 6.0
		c.draw_line(Vector2(0, y), Vector2(size.x, y), Color(_scope_ink, 0.12), 1.0)
	var t := float(st.get("t", 0.0))
	var level := float(st.get("level", 0.0))
	var storm := String(st.get("storm", ""))
	var voice := float(st.get("voice", 0.0))
	var pts := PackedVector2Array()
	var seed := int(t * 60.0)
	for i in 129:
		var x := size.x * float(i) / 128.0
		var u := float(i) / 128.0
		var y := sin(u * TAU * 3.0 + t * 2.0) * 4.0
		if voice > 0.0:
			var swell := 0.55 + 0.45 * sin(u * TAU * 1.3 + t * 7.0)
			y += (sin(u * TAU * 11.0 + t * 37.0) * 0.6 + sin(u * TAU * 23.0 + t * 53.0) * 0.3
				+ sin(u * TAU * 37.0 + t * 19.0) * 0.15) * swell * voice * size.y * 0.3
		if level > 0.0:
			var n := DispatchSounds.hash01(seed, i) * 2.0 - 1.0
			if storm == "surf":
				y += (n * 0.6 + sin(u * TAU * 7.0 + t * 9.0) * 0.4) * level * size.y * 0.32
			else:
				var spike := 1.0 if DispatchSounds.hash01(seed + 3, i) < 0.06 * level else 0.0
				y += (n * 0.25 + spike * n * 1.6) * level * size.y * 0.4
		pts.append(Vector2(x, size.y * 0.5 + y))
	c.draw_polyline(pts, Color(_scope_ink.lightened(0.2), 0.9), 2.0, true)


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
	var clock := "%02d:%02d" % [secs / 60, secs % 60]
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



## The chart: the hobbyist's table printed out - dates and hours in three columns headed IO-A, IO-B and IO-C, some rows
## circled in pen.
func _draw_chart(c: CanvasItem) -> void:
	var size := Vector2(840, 600)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.94, 0.93, 0.89))
	var ink := Color(0.1, 0.1, 0.12)
	c.draw_string(_mono, Vector2(40, 54), "JOVIAN DECAMETRIC STORM PREDICTIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ink)
	c.draw_string(_mono, Vector2(40, 86), "20.1 MHz   TIMES UT", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	var cols := [40.0, 250.0, 450.0, 650.0]
	var heads := ["DATE", "IO-A", "IO-B", "IO-C"]
	for k in 4:
		c.draw_string(_mono, Vector2(cols[k], 136), heads[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	c.draw_line(Vector2(36, 146), Vector2(size.x - 36, 146), ink, 2.0)
	var r := RandomNumberGenerator.new()
	r.seed = 2001
	var circled := [1, 4, 6, 9]
	for row in 11:
		var y := 182.0 + float(row) * 36.0
		c.draw_string(_mono, Vector2(cols[0], y), "NOV %02d" % (row + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
		for k in 3:
			if r.randf() < 0.55:
				var h := r.randi_range(0, 23)
				var m := r.randi_range(0, 59)
				var s := "%02d:%02d-%02d:%02d" % [h, m, (h + r.randi_range(1, 3)) % 24, r.randi_range(0, 59)]
				c.draw_string(_mono, Vector2(cols[k + 1], y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
		if row in circled:
			var pen := Color(0.12, 0.18, 0.55, 0.85)
			var mid := Vector2(cols[2] + 70.0 + r.randf_range(-20, 20), y - 7.0)
			var pts := PackedVector2Array()
			for i in 33:
				var a := float(i) / 32.0 * TAU * 1.08
				pts.append(mid + Vector2(cos(a) * (96.0 + r.randf_range(-3, 3)), sin(a) * (17.0 + r.randf_range(-2, 2))))
			c.draw_polyline(pts, pen, 2.4, true)


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


## The receiver's dial: a lit face with the bands' numbers along it and the cursor at 20.1.
func _draw_dial(c: CanvasItem) -> void:
	var size := Vector2(512, 256)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.78, 0.66, 0.42))
	var ink := Color(0.12, 0.08, 0.04)
	for k in 21:
		var x := 40.0 + float(k) * 21.6
		c.draw_line(Vector2(x, 120), Vector2(x, 150 if k % 5 == 0 else 138), ink, 2.0)
	for k in 5:
		var mhz := 18 + k
		c.draw_string(_mono, Vector2(28.0 + float(k) * 108.0, 190), "%d" % mhz, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink)
	c.draw_string(_mono, Vector2(40, 70), "MHz", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ink)
	var x := 40.0 + (20.1 - 18.0) / 5.0 * 432.0
	c.draw_line(Vector2(x, 90), Vector2(x, 230), Color(0.7, 0.05, 0.03), 4.0)
	c.draw_string(_mono, Vector2(x - 40, 250), "20.1", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.05, 0.03))


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
			st.get("textures", func(_k: String) -> Texture2D: return null))
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
