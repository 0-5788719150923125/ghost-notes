extends Control
class_name VoiceShape

## VoiceShape - a voice across a paragraph, drawn and dragged ([ReaderBrowser]): the mix as bands, one a reader,
## their edges curves through [constant VoiceBlend.POINTS] points, and a lane for each of [constant VoiceBlend.LANES],
## a curve from -1 (bottom) to 1 (top). Left to right is a paragraph, its first word to its last; every word reads
## where it stands ([method VoiceBlend.curve_at], the curve drawn here being the host's), so the voice moves within a
## sentence as it moves across the paragraph.
##
## Drag a point to move it, or the line between points to move all of it; double-click a lane to flatten it (a lane
## already flat, to zero). [signal edited] when a drag lets go: [member weights] and [member lanes] are then the shape.
##
## While a test plays, THE PLAYHEAD: [member follow] says where the voice being heard is across its paragraph, asked
## every frame; a line is drawn there through every lane, a mark where it crosses each curve and the values there in each
## lane's corner. It sweeps each paragraph without stopping and starts again at the next.

signal edited

const GUTTER := 58.0
const MIX_H := 136.0
const LANE_H := 72.0
## How far inside its box a curve runs, so a point at either end, the top or the bottom is drawn whole.
const PAD := 7.0
const GAP := 10.0
const CAPTION := 16.0
const HIT := 9.0
const SAMPLES := 64
const COLORS := [Color("e07a5f"), Color("5b9bd5"), Color("81b29a"), Color("f2cc8f"), Color("a58ad1"), Color("5fb3b3")]

## The readers, top band first: their pack names.
var names := PackedStringArray()
## Each reader's share at each point, adding to 1 at every point.
var weights: Array = []
## Each lane's points, -1 to 1.
var lanes := {}

## Asked every frame for where the voice being heard is across its paragraph, 0 to 1: -1 when nothing plays.
var follow := Callable()

var _head := -1.0                # what [member follow] said last
var _drag := {}                  # while a drag is held: {lane, edge, k (-1 the whole line), from, start}
var _hover := Vector2(-1, -1)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = ("Across each paragraph, its first word (left) to its last (right): the voice moves word by word "
		+ "along these. Drag a point to move it, or the line between points to move all of it; double-click a lane "
		+ "to flatten it.")
	for lane in VoiceBlend.LANES:
		lanes[lane] = _even([0.0])


## Show readers [param who] weighted [param w] (one array of points a reader, any length) and lanes [param l]
## (`{lane: points}`), every curve laid on [constant VoiceBlend.POINTS] points.
func set_shape(who: PackedStringArray, w: Array, l: Dictionary) -> void:
	names = who
	weights = []
	for k in VoiceBlend.POINTS:
		var s := VoiceBlend.shares_at(w, _x(k))
		for r in who.size():
			if weights.size() <= r:
				weights.append([])
			(weights[r] as Array).append(s[r] if r < s.size() else 0.0)
	for lane in VoiceBlend.LANES:
		lanes[lane] = _even(l.get(lane, [0.0]))
	custom_minimum_size = Vector2(380, _height())
	queue_redraw()


func _even(points: Array) -> Array:
	var out: Array = []
	for k in VoiceBlend.POINTS:
		out.append(VoiceBlend.curve_at(points, _x(k)))
	return out


func _x(k: int) -> float:
	return float(k) / float(VoiceBlend.POINTS - 1)


func _mixes() -> bool:
	return names.size() >= 2


func _height() -> float:
	return (MIX_H + GAP if _mixes() else 0.0) + VoiceBlend.LANES.size() * (LANE_H + GAP) + CAPTION


## Where each part is drawn: `mix` (when there are two readers or more) and each lane, by name.
func _rects() -> Dictionary:
	var out := {}
	var y := 0.0
	var w := maxf(40.0, size.x - GUTTER - 4.0)
	if _mixes():
		out["mix"] = Rect2(GUTTER, y, w, MIX_H)
		y += MIX_H + GAP
	for lane in VoiceBlend.LANES:
		out[lane] = Rect2(GUTTER, y, w, LANE_H)
		y += LANE_H + GAP
	return out


func _px(r: Rect2, u: float) -> float:
	return r.position.x + PAD + u * (r.size.x - 2.0 * PAD)


## Where across the paragraph [param x] is, in [param r].
func _u_of(r: Rect2, x: float) -> float:
	return clampf((x - r.position.x - PAD) / maxf(1.0, r.size.x - 2.0 * PAD), 0.0, 1.0)


func _lane_y(r: Rect2, v: float) -> float:
	return r.position.y + PAD + (1.0 - (clampf(v, -1.0, 1.0) + 1.0) / 2.0) * (r.size.y - 2.0 * PAD)


## The value at height [param y] in lane [param r].
func _lane_v(r: Rect2, y: float) -> float:
	return clampf(1.0 - 2.0 * (y - r.position.y - PAD) / maxf(1.0, r.size.y - 2.0 * PAD), -1.0, 1.0)


## The bottom of each band but the last, at [param u]: shares added from the top.
func _edges_at(u: float) -> PackedFloat32Array:
	var s := VoiceBlend.shares_at(weights, u)
	var out := PackedFloat32Array()
	var c := 0.0
	for r in s.size() - 1:
		c += s[r]
		out.append(c)
	return out


func _draw() -> void:
	var font := get_theme_default_font()
	var dim := Color(1, 1, 1, 0.55)
	var rects := _rects()
	for key in rects:
		var r: Rect2 = rects[key]
		draw_rect(r, Color(1, 1, 1, 0.04))
		draw_rect(r, Color(1, 1, 1, 0.16), false, 1.0)
		var label := "Mix" if key == "mix" else Registry.label(VoiceBlend.LANES, key)
		draw_string(font, Vector2(4, r.position.y + 16), label, HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 6, 12)
	if rects.has("mix"):
		_draw_mix(rects["mix"], font)
	for lane in VoiceBlend.LANES:
		_draw_lane(rects[lane], lane, font)
	_draw_head(rects)
	var bottom := _height() - 4.0
	var span: Rect2 = rects[VoiceBlend.LANES.keys()[0]]
	draw_string(font, Vector2(span.position.x, bottom), "paragraph's first word", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, dim)
	draw_string(font, Vector2(span.end.x - 110, bottom), "its last word", HORIZONTAL_ALIGNMENT_RIGHT, 110, 10, dim)


func _draw_mix(r: Rect2, font: Font) -> void:
	var n := names.size()
	var tops: Array = []          # per sample, the edges from the top: 0, edges..., 1
	for j in SAMPLES + 1:
		var e := _edges_at(float(j) / SAMPLES)
		var col := [0.0]
		for v in e:
			col.append(v)
		col.append(1.0)
		tops.append(col)
	for b in n:
		var poly := PackedVector2Array()
		for j in SAMPLES + 1:
			poly.append(Vector2(_px(r, float(j) / SAMPLES), r.position.y + float(tops[j][b]) * r.size.y))
		for j in range(SAMPLES, -1, -1):
			poly.append(Vector2(_px(r, float(j) / SAMPLES), r.position.y + float(tops[j][b + 1]) * r.size.y))
		var c: Color = COLORS[b % COLORS.size()]
		draw_colored_polygon(poly, Color(c, 0.5))
		var mid := r.position.y + (float(tops[0][b]) + float(tops[0][b + 1])) / 2.0 * r.size.y
		if (float(tops[0][b + 1]) - float(tops[0][b])) * r.size.y >= 14.0:
			draw_string(font, Vector2(r.position.x + PAD + 10, mid + 5), _short(names[b]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	for e in n - 1:
		var line := PackedVector2Array()
		for j in SAMPLES + 1:
			line.append(Vector2(_px(r, float(j) / SAMPLES), r.position.y + float(tops[j][e + 1]) * r.size.y))
		draw_polyline(line, Color(1, 1, 1, 0.85), 1.5, true)
		for k in VoiceBlend.POINTS:
			draw_circle(_handle("mix", e, k, r), 4.5, Color.WHITE)
	if _inside(r) or playhead() >= 0.0:
		var u := _u_of(r, _hover.x) if _inside(r) else playhead()
		var s := VoiceBlend.shares_at(weights, u)
		var said := PackedStringArray()
		for b in n:
			said.append("%s %d%%" % [_short(names[b]), roundi(100.0 * s[b])])
		_readout(r, " · ".join(said), font)


func _draw_lane(r: Rect2, lane: String, font: Font) -> void:
	var zero := _lane_y(r, 0.0)
	draw_dashed_line(Vector2(r.position.x, zero), Vector2(r.end.x, zero), Color(1, 1, 1, 0.25), 1.0, 4.0)
	var c := Color(0.55, 0.75, 1.0) if lane == "breath" else Color(1.0, 0.7, 0.4)
	var points: Array = lanes[lane]
	var x := _px(r, 0.0)
	while x <= _px(r, 1.0):
		var v := VoiceBlend.curve_at(points, _u_of(r, x))
		draw_line(Vector2(x, zero), Vector2(x, _lane_y(r, v)), Color(c, 0.28), 2.0)
		x += 2.0
	var line := PackedVector2Array()
	for j in SAMPLES + 1:
		var u := float(j) / SAMPLES
		line.append(Vector2(_px(r, u), _lane_y(r, VoiceBlend.curve_at(points, u))))
	draw_polyline(line, c, 1.5, true)
	for k in VoiceBlend.POINTS:
		draw_circle(_handle(lane, -1, k, r), 4.5, Color.WHITE)
	if _inside(r) or playhead() >= 0.0:
		var v := VoiceBlend.curve_at(points, _u_of(r, _hover.x) if _inside(r) else playhead())
		_readout(r, "%s %s%.2f" % [Registry.label(VoiceBlend.LANES, lane), "+" if v > 0.0 else "", v], font)


## The playhead: a line through every lane where the voice being heard is, and a mark on each curve there.
func _draw_head(rects: Dictionary) -> void:
	var u := playhead()
	if u < 0.0 or rects.is_empty():
		return
	var head := Color(1.0, 0.86, 0.35)
	var top: Rect2 = rects[rects.keys()[0]]
	var low: Rect2 = rects[rects.keys()[rects.size() - 1]]
	var x := _px(top, u)
	draw_line(Vector2(x, top.position.y), Vector2(x, low.end.y), head, 3.0)
	if rects.has("mix"):
		var r: Rect2 = rects["mix"]
		for e in _edges_at(u):
			draw_circle(Vector2(x, r.position.y + e * r.size.y), 4.0, head)
	for lane in VoiceBlend.LANES:
		draw_circle(Vector2(x, _lane_y(rects[lane], VoiceBlend.curve_at(lanes[lane], u))), 4.0, head)


func _readout(r: Rect2, text: String, font: Font) -> void:
	draw_string(font, Vector2(r.end.x - 260, r.position.y + 14), text, HORIZONTAL_ALIGNMENT_RIGHT, 254, 11,
		Color(1, 1, 1, 0.8))


## Whether the readout is shown over [param r]: the mouse over it, or what is dragged in it.
func _inside(r: Rect2) -> bool:
	if not _drag.is_empty():
		return String(_drag.get("lane", "")) == _lane_at(r)
	return r.has_point(_hover)


func _lane_at(r: Rect2) -> String:
	var rects := _rects()
	for key in rects:
		if (rects[key] as Rect2) == r:
			return String(key)
	return ""


func _short(reader: String) -> String:
	return reader.get_slice("_", 1) if reader.contains("_") else reader


## Where point [param k] of [param lane] (of edge [param edge], in the mix) is drawn in [param r].
func _handle(lane: String, edge: int, k: int, r: Rect2) -> Vector2:
	var x := _px(r, _x(k))
	if lane == "mix":
		return Vector2(x, r.position.y + _edges_at(_x(k))[edge] * r.size.y)
	return Vector2(x, _lane_y(r, float(lanes[lane][k])))


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_press(mb.position, mb.double_click)
		elif not _drag.is_empty():
			_drag = {}
			edited.emit()
		if is_inside_tree():
			accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		_hover = mm.position
		if not _drag.is_empty():
			drag_to(mm.position.y)
		queue_redraw()


func _process(_delta: float) -> void:
	if not follow.is_valid() or (is_inside_tree() and not is_visible_in_tree()):
		return
	var now := float(follow.call())
	if not is_equal_approx(now, _head):
		_head = now
		queue_redraw()


## Where the playhead is across the paragraph, or -1 when nothing plays.
func playhead() -> float:
	return _head


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _drag.is_empty():
		_hover = Vector2(-1, -1)
		queue_redraw()


## A press at [param at]: a point taken, a line taken whole, or (a double-click) a lane flattened.
func _press(at: Vector2, twice: bool) -> void:
	var rects := _rects()
	for key in rects:
		var r: Rect2 = rects[key]
		if not r.grow(HIT).has_point(at):
			continue
		if twice:
			flatten(String(key))
			edited.emit()
			return
		var edges := names.size() - 1 if key == "mix" else 1
		for e in edges:
			for k in VoiceBlend.POINTS:
				if _handle(String(key), e if key == "mix" else -1, k, r).distance_to(at) <= HIT:
					take(String(key), e if key == "mix" else -1, k, at.y)
					return
		if key == "mix":
			var e := _edges_at(_u_of(r, at.x))
			var best := -1
			for b in e.size():
				if best < 0 or absf(r.position.y + e[b] * r.size.y - at.y) < absf(r.position.y + e[best] * r.size.y - at.y):
					best = b
			if best >= 0:
				take("mix", best, -1, at.y)
			return
		take(String(key), -1, -1, at.y)
		return


## Take point [param k] (-1, the whole line) of [param lane] - its [param edge], in the mix - pressed at height
## [param from]: [method drag_to] then moves it.
func take(lane: String, edge: int, k: int, from: float) -> void:
	_drag = {"lane": lane, "edge": edge, "k": k, "from": from,
		"start": weights.duplicate(true) if lane == "mix" else (lanes[lane] as Array).duplicate()}


## What is taken, moved to height [param y].
func drag_to(y: float) -> void:
	var lane := String(_drag["lane"])
	var r: Rect2 = _rects().get(lane, Rect2())
	if r.size.y <= 0.0:
		return
	var k := int(_drag["k"])
	if lane != "mix":
		var start: Array = _drag["start"]
		var points: Array = lanes[lane]
		var dv := _lane_v(r, y) - _lane_v(r, float(_drag["from"]))
		for j in VoiceBlend.POINTS:
			if k < 0:
				points[j] = snappedf(clampf(float(start[j]) + dv, -1.0, 1.0), 0.01)
			elif j == k:
				points[j] = snappedf(_lane_v(r, y), 0.01)
		queue_redraw()
		return
	var e := int(_drag["edge"])
	var start_w: Array = _drag["start"]
	var dy := (y - float(_drag["from"])) / r.size.y
	for j in VoiceBlend.POINTS:
		if k >= 0 and j != k:
			continue
		var s: Array = []
		for b in names.size():
			s.append(float(start_w[b][j]))
		var lo := 0.0
		for b in e:
			lo += float(s[b])
		var hi := lo + float(s[e]) + float(s[e + 1])
		var at := lo + float(s[e])
		var want := (y - r.position.y) / r.size.y if k >= 0 else at + dy
		at = clampf(want, lo, hi)
		weights[e][j] = snappedf(at - lo, 0.001)
		weights[e + 1][j] = snappedf(hi - at, 0.001)
	queue_redraw()


## [param lane] made flat: each reader at its mean share; a lane at its mean, or at zero where it already was flat.
func flatten(lane: String) -> void:
	if lane == "mix":
		for b in weights.size():
			var m := 0.0
			for v in weights[b]:
				m += float(v) / float(VoiceBlend.POINTS)
			for j in VoiceBlend.POINTS:
				weights[b][j] = snappedf(m, 0.001)
	elif lanes.has(lane):
		var points: Array = lanes[lane]
		var m := 0.0
		var flat := true
		for v in points:
			m += float(v) / float(VoiceBlend.POINTS)
			flat = flat and is_equal_approx(float(v), float(points[0]))
		for j in VoiceBlend.POINTS:
			points[j] = 0.0 if flat else snappedf(m, 0.01)
	queue_redraw()
