extends Node
class_name DispatchScreens

## DispatchScreens - WHAT THE DESK'S SCREENS AND LABELS SHOW, drawn in 2D (next/dispatch.md): the terminal's pale green
## text on black (asleep, dark), the radar's sweep and its blip with the place written
## beside it, the oscilloscope's trace, a phone's two little screens, the printer's paper as it feeds; and, drawn once,
## the names on the phones' tape in marker, GOOD and BAD on the switch's, the chart of the council's hours, the handbook's
## spine, the receiver's dial at 20.1.
##
## EACH A VIEWPORT OF ITS OWN, drawn only as what it shows changes ([method DeskMedium]'s rule: "the desk is drawn only
## as it changes") - the radar's sweep and the scope's trace move every frame, the terminal only as a key is struck. The
## medium hands each a state ([method show_terminal], [method show_radar], ...) and the set's glass shows its texture
## through `shaders/dispatch_screen.gdshader`.

const TERM_SIZE := Vector2i(1120, 840)
const RADAR_SIZE := Vector2i(512, 512)
const SCOPE_SIZE := Vector2i(256, 200)
const PHONE_SIZE := Vector2i(300, 368)
## A PHONE'S KEYPAD, drawn once for every phone: its size (px).
const KEYPAD_SIZE := Vector2i(262, 400)
const PAPER_SIZE := Vector2i(768, 3072)
const TAPE_CELL := Vector2i(256, 96)
const TAPE_COLS := 4
## How many phone screens can be lit at once (the one in hand, the ones on the desk, one ringing or texting).
const PHONE_FACES := 5
## THE TERMINAL'S TYPE: its face, its size (px), its line (px), where its first line and first column are.
const MONO := "res://fonts/cards/CourierPrime-Bold.ttf"
const MARKER := "res://fonts/hands/PatrickHand-Regular.ttf"
const TERM_FONT := 22
const TERM_LINE := 33.0
const TERM_MARGIN := Vector2(78.0, 70.0)
## THE COLORS: the terminal's phosphor, its dark; the radar's green.
const PHOSPHOR := Color(0.62, 1.0, 0.68)
const SCREEN_DARK := Color(0.008, 0.016, 0.01)
const RADAR_GREEN := Color(0.32, 1.0, 0.42)

var terminal: SubViewport
var keypad: SubViewport
var radar: SubViewport
var scope: SubViewport
var paper: SubViewport
var tape: SubViewport
var chart: SubViewport
var spine: SubViewport
var dial: SubViewport
var faces: Array = []             # the phone screens' viewports
var _words := {}                  # a word on tape -> its viewport
var _term: Face
var _radar: Face
var _scope: Face
var _paper: Face
var _faces: Array = []
var _mono: Font
var _marker: Font


func _init() -> void:
	name = "DispatchScreens"
	_mono = load(MONO)
	_marker = load(MARKER)


## BUILD THEM for the phones [param labels] (their tape) - the dynamic faces once, the labels drawn again for new labels.
func build(labels: PackedStringArray) -> void:
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
		spine = _vp(Vector2i(512, 140), false)
		spine.add_child(Face.new(self, "spine"))
		dial = _vp(Vector2i(512, 256), false)
		dial.add_child(Face.new(self, "dial"))
		keypad = _vp(KEYPAD_SIZE, false)
		keypad.add_child(Face.new(self, "keypad"))
	word("GOOD")
	word("BAD")
	if tape != null:
		tape.queue_free()
	var rows := maxi(1, ceili(float(labels.size()) / float(TAPE_COLS)))
	tape = _vp(Vector2i(TAPE_CELL.x * TAPE_COLS, TAPE_CELL.y * rows), false)
	var tf := Face.new(self, "tape")
	tf.state = {"labels": labels}
	tape.add_child(tf)


## WHAT THE DESK'S BUILD IS HANDED of these ([method DispatchSet.build]): the tape, the chart, the spine, the dial and the
## switch's words, by name - taken here on the main thread, so the build may run on a worker.
func textures() -> Dictionary:
	return {"tape": tape.get_texture(), "chart": chart.get_texture(), "spine": spine.get_texture(), "dial": dial.get_texture(),
		"keypad": keypad.get_texture(),
		"GOOD": word("GOOD"), "BAD": word("BAD")}


## A word on a strip of tape (the switch's GOOD and BAD), drawn once.
func word(text: String) -> Texture2D:
	if not _words.has(text):
		var vp := _vp(Vector2i(320, 104), false)
		var f := Face.new(self, "word")
		f.state = {"text": text}
		vp.add_child(f)
		_words[text] = vp
	return (_words[text] as SubViewport).get_texture()


## The tape atlas's cell (UV) of phone [param i] of [param n].
static func tape_cell(i: int, n: int) -> Rect2:
	var rows := maxi(1, ceili(float(n) / float(TAPE_COLS)))
	return Rect2(float(i % TAPE_COLS) / float(TAPE_COLS), float(i / TAPE_COLS) / float(rows), 1.0 / float(TAPE_COLS), 1.0 / float(rows))


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

## THE TERMINAL as [param st] has it: `{lines: PackedStringArray, asleep, cursor (bool), t}` - drawn again only when it
## changed.
func show_terminal(st: Dictionary) -> void:
	_show(terminal, _term, st)


## THE RADAR: `{t (the sweep's clock), blip: {at: Vector2, label, since}, trail: [{at, age}], ping (seconds into the last
## ping, or -1), planes: [{at, heading}]}`.
func show_radar(st: Dictionary) -> void:
	_show(radar, _radar, st)


## THE SCOPE: `{t, level (0-1), storm}`.
func show_scope(st: Dictionary) -> void:
	_show(scope, _scope, st)


## THE PAPER: `{lines: PackedStringArray (newest last), feed (0-1 of the line being fed), partial (characters of the line
## being printed)}`.
func show_paper(st: Dictionary) -> void:
	_show(paper, _paper, st)


## PHONE SCREEN [param k]: `{mode: call | hold | calling | text | ring | idle, label, words, secs}`.
func show_phone(k: int, st: Dictionary) -> void:
	_show(faces[k], _faces[k], st)


func _show(vp: SubViewport, f: Face, st: Dictionary) -> void:
	if st == f.state:
		return
	f.state = st
	f.queue_redraw()
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# --- the faces --------------------------------------------------------------------------------------------------------

## ONE FACE, drawn by its kind.
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
			"tape": screens._draw_tape(self, state)
			"word": screens._draw_word(self, state)
			"chart": screens._draw_chart(self)
			"spine": screens._draw_spine(self)
			"dial": screens._draw_dial(self)
			"keypad": screens._draw_keypad(self)


## THE TERMINAL: its lines from the top, a block cursor after the last when it is on; asleep, dark (2026-11-06, the
## author: the cover's star "was in the source image, but we do not need it in this one").
func _draw_terminal(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(TERM_SIZE)
	c.draw_rect(Rect2(Vector2.ZERO, size), SCREEN_DARK)
	if bool(st.get("asleep", true)):
		return
	var lines: PackedStringArray = st.get("lines", PackedStringArray())
	var y := TERM_MARGIN.y
	for line in lines:
		c.draw_string(_mono, Vector2(TERM_MARGIN.x, y), String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, TERM_FONT, PHOSPHOR)
		y += TERM_LINE
	if bool(st.get("cursor", false)):
		var last := String(lines[lines.size() - 1]) if not lines.is_empty() else ""
		var cw := _mono.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, TERM_FONT).x
		var cy := TERM_MARGIN.y + TERM_LINE * float(maxi(lines.size() - 1, 0))
		c.draw_rect(Rect2(TERM_MARGIN.x + cw * float(last.length()) + 2.0, cy - float(TERM_FONT) * 0.78, cw * 0.9, float(TERM_FONT) * 0.95), PHOSPHOR)


## THE RADAR: dark green glass, its range rings and cross, the sweep going round with its glow fading behind it, the desk
## at its middle; the target's blip, lit as the sweep passes and fading after, its place written small beside it; the
## places before it fading out; a ping's ring opening out from the blip; and an aircraft's small mark drifting across now
## and then.
func _draw_radar(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(RADAR_SIZE)
	var mid := size * 0.5
	var rad := size.x * 0.47
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0))
	c.draw_circle(mid, rad, Color(0.01, 0.05, 0.02))
	var t := float(st.get("t", 0.0))
	var sweep := fposmod(t / DispatchMedium.SWEEP, 1.0) * TAU - PI * 0.5
	# the glow behind the sweep
	for k in 48:
		var a0 := sweep - float(k + 1) * 0.035
		var a1 := sweep - float(k) * 0.035
		var al := 0.32 * pow(1.0 - float(k) / 48.0, 2.0)
		c.draw_colored_polygon(PackedVector2Array([mid, mid + Vector2.from_angle(a0) * rad, mid + Vector2.from_angle(a1) * rad]), Color(RADAR_GREEN, al))
	for k in 4:
		c.draw_arc(mid, rad * float(k + 1) / 4.0, 0.0, TAU, 96, Color(RADAR_GREEN, 0.28), 1.6, true)
	c.draw_line(mid - Vector2(rad, 0), mid + Vector2(rad, 0), Color(RADAR_GREEN, 0.18), 1.2)
	c.draw_line(mid - Vector2(0, rad), mid + Vector2(0, rad), Color(RADAR_GREEN, 0.18), 1.2)
	for k in 36:
		var a := float(k) / 36.0 * TAU
		var inner := 0.95 if k % 3 == 0 else 0.975
		c.draw_line(mid + Vector2.from_angle(a) * rad * inner, mid + Vector2.from_angle(a) * rad, Color(RADAR_GREEN, 0.4), 1.4)
	c.draw_line(mid, mid + Vector2.from_angle(sweep) * rad, Color(RADAR_GREEN, 0.95), 2.6, true)
	# the desk, at its middle
	c.draw_rect(Rect2(mid - Vector2(4, 4), Vector2(8, 8)), Color(RADAR_GREEN, 0.9))
	for p in st.get("planes", []):
		var pd: Dictionary = p
		var at := mid + (pd["at"] as Vector2) * rad
		var hd := Vector2.from_angle(float(pd.get("heading", 0.0)))
		var lit := _lit(at - mid, sweep)
		c.draw_colored_polygon(PackedVector2Array([at + hd * 7.0, at - hd * 5.0 + hd.orthogonal() * 4.5, at - hd * 2.5, at - hd * 5.0 - hd.orthogonal() * 4.5]),
			Color(RADAR_GREEN, 0.35 + 0.6 * lit))
	for tr in st.get("trail", []):
		var td: Dictionary = tr
		var at := mid + (td["at"] as Vector2) * rad
		c.draw_circle(at, 3.6, Color(RADAR_GREEN, 0.55 * clampf(float(td.get("fade", 1.0 - float(td["age"]) / 4.0)), 0.0, 1.0)))
	var blip: Dictionary = st.get("blip", {})
	if not blip.is_empty():
		var at := mid + (blip["at"] as Vector2) * rad
		var lit := _lit(at - mid, sweep)
		var since := float(blip.get("since", 99.0))
		var fresh := clampf(1.0 - since / 1.2, 0.0, 1.0)
		c.draw_circle(at, 7.0 + 4.0 * fresh, Color(RADAR_GREEN, 0.25 + 0.4 * lit))
		c.draw_circle(at, 4.5, Color(RADAR_GREEN.lightened(0.4), 0.55 + 0.45 * maxf(lit, fresh)))
		var label := String(blip.get("label", ""))
		var right := at.x < mid.x + rad * 0.3
		var pos := at + Vector2(12.0 if right else -12.0, -10.0)
		var w := _mono.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		if not right:
			pos.x -= w
		c.draw_string(_mono, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(RADAR_GREEN, 0.85))
		var ping := float(st.get("ping", -1.0))
		if ping >= 0.0 and ping < DispatchScript.PING_LEN:
			var u := ping / DispatchScript.PING_LEN
			for k in 2:
				var uu := clampf(u - float(k) * 0.18, 0.0, 1.0)
				if uu > 0.0:
					c.draw_arc(at, 8.0 + uu * rad * 0.55, 0.0, TAU, 72, Color(RADAR_GREEN, 0.85 * (1.0 - uu)), 2.2, true)
	# the glass's edge
	c.draw_arc(mid, rad, 0.0, TAU, 128, Color(0.0, 0.0, 0.0), 8.0, true)


## How lit a mark at [param at] (from the middle) still is: the sweep passed it, and its phosphor fades behind.
static func _lit(at: Vector2, sweep: float) -> float:
	var behind := fposmod(sweep - at.angle(), TAU)
	return exp(-behind / 1.6)


## THE SCOPE: a dim grid, and the trace across it - a hum's slow sine at rest, the static's jumping noise in a storm.
func _draw_scope(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(SCOPE_SIZE)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.02, 0.01))
	for k in range(1, 8):
		var x := size.x * float(k) / 8.0
		c.draw_line(Vector2(x, 0), Vector2(x, size.y), Color(RADAR_GREEN, 0.12), 1.0)
	for k in range(1, 6):
		var y := size.y * float(k) / 6.0
		c.draw_line(Vector2(0, y), Vector2(size.x, y), Color(RADAR_GREEN, 0.12), 1.0)
	var t := float(st.get("t", 0.0))
	var level := float(st.get("level", 0.0))
	var storm := String(st.get("storm", ""))
	var pts := PackedVector2Array()
	var seed := int(t * 60.0)
	for i in 129:
		var x := size.x * float(i) / 128.0
		var u := float(i) / 128.0
		var y := sin(u * TAU * 3.0 + t * 2.0) * 4.0
		if level > 0.0:
			var n := DispatchSounds.hash01(seed, i) * 2.0 - 1.0
			if storm == "surf":
				y += (n * 0.6 + sin(u * TAU * 7.0 + t * 9.0) * 0.4) * level * size.y * 0.32
			else:
				var spike := 1.0 if DispatchSounds.hash01(seed + 3, i) < 0.06 * level else 0.0
				y += (n * 0.25 + spike * n * 1.6) * level * size.y * 0.4
		pts.append(Vector2(x, size.y * 0.5 + y))
	c.draw_polyline(pts, Color(RADAR_GREEN.lightened(0.2), 0.9), 2.0, true)


## THE PAPER: continuous paper, its sprocket holes down both edges and a fold's perforation every eleven inches; the lines
## printed, newest nearest the slot (its top), each older line further along it as the paper fed.
func _draw_paper(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(PAPER_SIZE)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.93, 0.92, 0.87))
	var line_h := 15.0
	var shift := float(st.get("feed", 0.0)) * line_h
	# the margins' holes, moving with the paper
	var hole := 21.0
	var off := fposmod(shift, hole)
	var y := off - hole
	while y < size.y:
		for x in [16.0, size.x - 16.0]:
			c.draw_circle(Vector2(x, y), 5.5, Color(0.18, 0.17, 0.15))
		y += hole
	c.draw_line(Vector2(32, 0), Vector2(32, size.y), Color(0.75, 0.74, 0.7), 1.0)
	c.draw_line(Vector2(size.x - 32, 0), Vector2(size.x - 32, size.y), Color(0.75, 0.74, 0.7), 1.0)
	var fold := line_h * 66.0
	var fy := fposmod(shift + float(st.get("total", 0)) * line_h, fold)
	while fy < size.y:
		c.draw_dashed_line(Vector2(0, fy), Vector2(size.x, fy), Color(0.7, 0.69, 0.65), 1.0, 4.0)
		fy += fold
	var lines: PackedStringArray = st.get("lines", PackedStringArray())
	var ink := Color(0.12, 0.13, 0.2, 0.88)
	var partial := String(st.get("partial", ""))
	var yy := 22.0 + shift
	if not partial.is_empty():
		c.draw_string(_mono, Vector2(44, yy), partial, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
	for k in range(lines.size() - 1, -1, -1):
		yy += line_h
		if yy > size.y:
			break
		c.draw_string(_mono, Vector2(44, yy), String(lines[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)


## A PHONE'S SCREEN: amber-lit monochrome - the one in hand its caller's name and the call's clock, one on hold the same and
## ON HOLD, one dialing CALLING; the little one outside a text's sender and words, or a ring's caller.
func _draw_phone(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(PHONE_SIZE)
	var mode := String(st.get("mode", "idle"))
	var lit := Color(0.62, 0.78, 0.5) if mode != "idle" else Color(0.08, 0.1, 0.07)
	c.draw_rect(Rect2(Vector2.ZERO, size), lit)
	if mode == "idle":
		return
	# drawn on a 200-wide screen's measures, scaled to this one's
	var k := size.x / 200.0
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var w := size.x / k
	var ink := Color(0.04, 0.06, 0.03)
	var label := String(st.get("label", ""))
	var secs := int(float(st.get("secs", 0.0)))
	var clock := "%02d:%02d" % [secs / 60, secs % 60]
	# the bars and the battery along the top
	for b in 4:
		c.draw_rect(Rect2(10 + b * 9, 30 - b * 5, 6, 6 + b * 5), ink)
	c.draw_rect(Rect2(w - 44, 14, 32, 16), ink, false, 2.0)
	c.draw_rect(Rect2(w - 40, 18, 20, 8), ink)
	match mode:
		"call", "hold", "calling":
			c.draw_string(_mono, Vector2(0, 98), label, HORIZONTAL_ALIGNMENT_CENTER, w, 30, ink)
			var under := String({"call": clock, "hold": "ON HOLD", "calling": "CALLING"}[mode])
			c.draw_string(_mono, Vector2(0, 150), under, HORIZONTAL_ALIGNMENT_CENTER, w, 26, ink)
			if mode == "hold":
				c.draw_string(_mono, Vector2(0, 196), clock, HORIZONTAL_ALIGNMENT_CENTER, w, 22, ink)
		"dial":
			# SPEED DIAL: the digit held, and who it is
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


## A TEXT THREAD on a phone held up: who it is with across the top, then each message in turn - theirs at the left, the
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


## A PHONE'S KEYPAD (2026-11-06, the author: "Ensure there are numbers, and probably a send/end button"): across the top
## Send (green, a handset) and End (red, a handset hung up) either side of a round navigation key; under them the twelve
## keys, 1 to 9, *, 0 and #, each its digit and the letters under it, on the dark of the phone.
func _draw_keypad(c: CanvasItem) -> void:
	var size := Vector2(KEYPAD_SIZE)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.055))
	var key := Color(0.62, 0.63, 0.65)
	var ink := Color(0.08, 0.08, 0.09)
	var top := size.y * 0.24
	# Send and End, the navigation key between
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
	# the twelve keys
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


## THE PHONES' TAPE: a strip of masking tape a cell, its name across it in black marker, a little crooked.
func _draw_tape(c: CanvasItem, st: Dictionary) -> void:
	var labels: PackedStringArray = st.get("labels", PackedStringArray())
	var cell := Vector2(TAPE_CELL)
	for i in labels.size():
		var at := Vector2(float(i % TAPE_COLS) * cell.x, float(i / TAPE_COLS) * cell.y)
		var r := RandomNumberGenerator.new()
		r.seed = hash(["tape", labels[i]])
		c.draw_rect(Rect2(at, cell), Color(0.87, 0.81, 0.62).darkened(r.randf_range(0.0, 0.08)))
		# the torn ends
		for k in 6:
			var y := cell.y * float(k) / 6.0
			c.draw_rect(Rect2(at + Vector2(0, y), Vector2(r.randf_range(0, 7), cell.y / 6.0)), Color(0, 0, 0, 0.0))
		var size := 58
		var w := _marker.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var scale := minf(1.0, (cell.x - 26.0) / maxf(w, 1.0))
		c.draw_set_transform(at + cell * 0.5 + Vector2(r.randf_range(-6, 6), r.randf_range(-3, 3)), r.randf_range(-0.05, 0.05), Vector2(scale, 1.0))
		for dx in [-1.2, 0.0, 1.2]:
			c.draw_string(_marker, Vector2(-w * 0.5 + dx, size * 0.35), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.05, 0.05, 0.06, 0.92))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_word(c: CanvasItem, st: Dictionary) -> void:
	var size := Vector2(320, 104)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.87, 0.81, 0.62))
	var text := String(st.get("text", ""))
	var w := _marker.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
	for dx in [-1.5, 0.0, 1.5]:
		c.draw_string(_marker, Vector2((size.x - w) * 0.5 + dx, 78), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(0.05, 0.05, 0.06, 0.92))


## THE CHART: the hobbyist's table printed out - dates and hours in three columns headed IO-A, IO-B and IO-C, some rows
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


func _draw_spine(c: CanvasItem) -> void:
	var size := Vector2(512, 140)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.14, 0.26))
	c.draw_rect(Rect2(Vector2(80, 30), Vector2(352, 80)), Color(0.93, 0.92, 0.87))
	var w := _mono.get_string_size("HANDBOOK", HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
	c.draw_string(_mono, Vector2((size.x - w) * 0.5, 90), "HANDBOOK", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(0.08, 0.08, 0.1))


## THE RECEIVER'S DIAL: a lit face with the bands' numbers along it and the cursor at 20.1.
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
	# the cursor at 20.1
	var x := 40.0 + (20.1 - 18.0) / 5.0 * 432.0
	c.draw_line(Vector2(x, 90), Vector2(x, 230), Color(0.7, 0.05, 0.03), 4.0)
	c.draw_string(_mono, Vector2(x - 40, 250), "20.1", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.05, 0.03))
