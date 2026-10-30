extends Node2D
class_name TableBlueprint

## TableBlueprint - the reader's table drawn as a plan, for the set dresser to lay its things out on
## (the user, 2026-10-18: "draw a literal blueprint: black lines on white paper, with measurements ...
## then simply ask the model to place props onto the blueprint at certain points, and with certain
## orientations"). Before it, a thing named a zone and the table hunted that zone for room: the set
## dresser of True Tarot #15853 moved a felt pad to lie under wherever the hunt had put its journal, and
## a glass of grass was LEFT OFF, "not in front of another group", until it was named into another
## zone. Now each thing is written where it stands ([method TableThings.stand_at]) and this is what
## the set dresser plans it on:
##
##   - paper ruled in centimeters from the middle of the reading - where a thing's `at` is measured
##     from, as a layer's is - with rulers along the top and the left, the reader at the bottom;
##   - the top's outline, heavy; each layer's, dashed, with its name; the floor past the top hatched;
##   - gray wherever the camera does not see, its frame's edge dashed;
##   - HOW TALL A THING CAN STAND AND BE SEEN WHOLE ([method CardTable.headroom_at]): a line for each of
##     [constant HEIGHTS] - straight, the frame's top being a plane through the lens;
##   - where the cards go, hatched: the spread's cards, the deck, the shuffle; the reader's workspace,
##     dotted; the line the flames stand behind;
##   - each thing as it stands: its foot, its number (as put lists them), a tick toward its front, lit
##     ones warm; where it was written, dashed red, when it had to move, crossed out when it found no
##     room; its number red when it is taller than its spot shows.
##
## The names, sizes and troubles go in words beside it ([SetDresserTools]): a drawing of dozens of
## things with every name on it could not be read. Drawn in a SubViewport of its own ([method
## TablePreview.blueprint]); where everything falls on the sheet is worked out by static functions a
## gate can check without a renderer ([method view], [method outline], [method seen], [method height_line]).

## The sheet, pixels, and the margins round the drawing (left and top hold the rulers and the
## heading, the bottom the reader and the key).
const SHEET := Vector2i(1280, 960)
const MARGIN_TL := Vector2(64.0, 78.0)
const MARGIN_BR := Vector2(24.0, 84.0)
## How far round what matters the drawing reaches (meters): what the camera sees of the top, the
## cards and every thing.
const PAD := 0.05
## The heights drawn, centimeters.
const HEIGHTS := [5, 10, 15, 20, 30, 45]
const PAPER := Color("#fbfaf5")
const INK := Color("#141414")
const FAINT := Color("#5a5a5a")
const GRID := Color("#e7e6e0")
const GRID10 := Color("#cfcdc4")
const UNSEEN := Color("#d6d5cf")
const HEIGHT_INK := Color("#2f5d8a")
const LIT := Color("#f6d98b")
const FOOT := Color("#ece6d8")
const TROUBLE := Color("#c0392b")
const FONT_SIZE := 14
const SMALL := 12

## What [method TableThings.blueprint] handed over, and `numbers`: each thing's number, by name.
var data := {}


func _draw() -> void:
	var v := view(data, Vector2(SHEET))
	var room: Rect2 = v["room"]
	var room_poly := Geo.of_rect(room)
	var cam: Transform3D = data["camera"]
	var fov := float(data["fov"])
	var font := ThemeDB.fallback_font
	# the labels of the room's lines, written over everything once it is drawn
	var late: Array = []
	draw_rect(Rect2(Vector2.ZERO, Vector2(SHEET)), PAPER)
	# what the camera does not see, gray; what it sees, paper
	draw_rect(room, UNSEEN)
	var seen_px := _px(v, seen(cam, fov))
	var seen_room: Array = Geometry2D.intersect_polygons(seen_px, room_poly)
	for poly in seen_room:
		draw_colored_polygon(poly, PAPER)
	_grid(v)
	# the floor past the top, where it is seen
	var top_px := _px(v, outline(data["top"]))
	for poly in seen_room:
		for off in Geometry2D.clip_polygons(poly, top_px):
			_hatch(off, 12.0, GRID10, 1.0)
	# where the cards go: nothing stands there
	for r in data.get("keep_out", []):
		var rp := Geo.of_rect(Rect2(_to_px(v, (r as Rect2).position), (r as Rect2).size * float(v["scale"])))
		for piece in Geometry2D.intersect_polygons(rp, room_poly):
			_hatch(piece, 7.0, FAINT, 1.0)
			_line(piece, FAINT, 1.0, room_poly, 0.0, true)
	var card: Vector2 = data.get("card", Vector2(0.07, 0.12))
	for c in data.get("cards", []):
		var poly := _px(v, card_outline((c as Dictionary)["pos"], float((c as Dictionary)["yaw"]), card))
		draw_colored_polygon(poly, PAPER)
		_line(poly, INK, 1.5, room_poly, 0.0, true)
	if data.has("deck"):
		var deck := _px(v, card_outline(data["deck"], 0.0, card))
		draw_colored_polygon(deck, FAINT)
		_label(font, Geo.centroid(deck), "deck", SMALL, PAPER, FAINT)
	var shuffle: Rect2 = data.get("shuffle", Rect2())
	if shuffle.has_area():
		late.append([_to_px(v, Vector2(shuffle.get_center().x, shuffle.position.y)) + Vector2(0.0, -5.0), "the cards' room", INK, true])
	# the work's spot, where the show has work: a cross, named
	if data.get("work") is Vector2:
		var c := _to_px(v, data["work"])
		_line(PackedVector2Array([c + Vector2(-9.0, -9.0), c + Vector2(9.0, 9.0)]), INK, 2.0, room_poly, 0.0, false)
		_line(PackedVector2Array([c + Vector2(-9.0, 9.0), c + Vector2(9.0, -9.0)]), INK, 2.0, room_poly, 0.0, false)
		late.append([c + Vector2(0.0, 22.0), "the work's spot", INK, true])
	# the reader's workspace, and the line the flames stand behind
	var ws: Rect2 = data.get("workspace", Rect2())
	if ws.has_area():
		var wp := Geo.of_rect(Rect2(_to_px(v, ws.position), ws.size * float(v["scale"])))
		for piece in Geometry2D.intersect_polygons(wp, room_poly):
			_line(piece, INK, 1.0, room_poly, 2.0, true)
			var b := Geo.bounds(piece)
			_label(font, Vector2(b.get_center().x, minf(b.end.y - 10.0, b.position.y + 22.0)), "the reader's hands", SMALL, INK, PAPER)
	var area: Rect2 = v["area"]
	var flames := float(data.get("flames_behind", 0.0))
	if flames > area.position.y and flames < area.end.y:
		var a := _to_px(v, Vector2(area.position.x, flames))
		var b := _to_px(v, Vector2(area.end.x, flames))
		_line(PackedVector2Array([a, b]), TROUBLE, 1.0, room_poly, 6.0, false)
		late.append([Vector2(a.x + 64.0, a.y - 6.0), "flames stand behind this line", TROUBLE, false])
	# the cloths, dashed and named; the top, heavy
	for l in data.get("layers", []):
		var lp := _px(v, outline((l as Dictionary)["o"]))
		_line(lp, INK, 1.0, room_poly, 6.0, true)
		var inside: Array = Geometry2D.intersect_polygons(lp, room_poly)
		if not inside.is_empty() and not String((l as Dictionary)["name"]).is_empty():
			var lb := Geo.bounds(inside[0])
			_label(font, Vector2(lb.position.x + 6.0, lb.position.y + 14.0), String((l as Dictionary)["name"]), SMALL, FAINT, PAPER, false)
	_line(top_px, INK, 3.0, room_poly, 0.0, true)
	# where a foot must stay inside the top ([constant Tables.THING_EDGE])
	var inset: Dictionary = (data["top"] as Dictionary).duplicate()
	inset["grow"] = float(inset.get("grow", 0.0)) - Tables.THING_EDGE
	_line(_px(v, outline(inset)), INK, 1.0, room_poly, 2.0, true)
	# how tall a thing can be and be seen whole
	for h in HEIGHTS:
		var seg := height_line(cam, fov, float(h) * 0.01, area)
		if seg.size() < 2:
			continue
		var px := _px(v, seg)
		_line(px, HEIGHT_INK, 1.0, room_poly, 0.0, false)
		var left := px[0] if px[0].x < px[1].x else px[1]
		_label(font, left + Vector2(4.0, -5.0), "%d cm" % int(h), SMALL, HEIGHT_INK, PAPER, false)
	_things(v, font, room_poly, cam, fov)
	for l in late:
		_label(font, l[0], String(l[1]), SMALL, l[2], PAPER, bool(l[3]))
	_rulers(v, font)
	_key(font)


## Each thing as it stood, numbered; where it was written when it moved; each that found no room.
func _things(v: Dictionary, font: Font, room_poly: PackedVector2Array, cam: Transform3D, fov: float) -> void:
	var numbers: Dictionary = data.get("numbers", {})
	var s := float(v["scale"])
	for t in data.get("things", []):
		var d: Dictionary = t
		var at: Vector2 = d["at"]
		var foot := _px(v, d["foot"])
		if foot.size() < 3:
			# a strand laid across the table: the stretch it covers
			var bb: Rect2 = d["bb"]
			_line(Geo.of_rect(Rect2(_to_px(v, bb.position), bb.size * s)), INK, 1.0, room_poly, 6.0, true)
			continue
		var written: Variant = d.get("written")
		if written != null and float(d.get("moved", 0.0)) > 0.004:
			var was := _px(v, Geo.moved(d["foot"], (written as Vector2) - at))
			_line(was, TROUBLE, 1.5, room_poly, 6.0, true)
			_line(PackedVector2Array([_to_px(v, written), _to_px(v, at)]), TROUBLE, 1.0, room_poly, 0.0, false)
		draw_colored_polygon(foot, LIT if int(d.get("lit", 0)) > 0 else FOOT)
		_line(foot, INK, 2.0, room_poly, 0.0, true)
		var c := _to_px(v, at)
		var reach := 0.0
		for q in foot:
			reach = maxf(reach, q.distance_to(c))
		var front: Vector2 = d.get("front", Vector2(0.0, 1.0))
		var tip := c + front * maxf(reach + 7.0, 16.0)
		draw_line(c + front * 9.0, tip, INK, 2.0, true)
		draw_line(tip, tip - front.rotated(0.5) * 6.0, INK, 2.0, true)
		draw_line(tip, tip - front.rotated(-0.5) * 6.0, INK, 2.0, true)
		var tall := float(d.get("height", 0.0)) > CardTable.headroom_at(cam, fov, at) + 0.005
		var label := "box" if bool(d.get("box", false)) else str(numbers.get(String(d["name"]), "?"))
		_badge(font, c, label, tall)
	for u in data.get("unstood", []):
		var w := _to_px(v, (u as Dictionary)["written"])
		draw_line(w + Vector2(-8, -8), w + Vector2(8, 8), TROUBLE, 3.0, true)
		draw_line(w + Vector2(-8, 8), w + Vector2(8, -8), TROUBLE, 3.0, true)
		_label(font, w + Vector2(0.0, 22.0), str(numbers.get(String((u as Dictionary)["name"]), "?")), SMALL, TROUBLE, PAPER)


## A thing's number in a ring, red when the thing is taller than its spot shows.
func _badge(font: Font, at: Vector2, text: String, trouble: bool) -> void:
	var w := maxf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL).x * 0.5 + 4.0, 9.0)
	draw_circle(at, w, Color("#f6d5d0") if trouble else PAPER)
	draw_arc(at, w, 0.0, TAU, 32, TROUBLE if trouble else INK, 1.5, true)
	_label(font, at + Vector2(0.0, 4.5), text, SMALL, TROUBLE if trouble else INK, Color(0, 0, 0, 0))


## The paper's grid: a faint line every 5 cm, a firmer one every 10 - counted from the middle of the
## reading, as the rulers are.
func _grid(v: Dictionary) -> void:
	var room: Rect2 = v["room"]
	var area: Rect2 = v["area"]
	for axis in 2:
		var lo := ceili((area.position[axis] - Tables.ORIGIN[axis]) * 20.0)
		var hi := floori((area.end[axis] - Tables.ORIGIN[axis]) * 20.0)
		for i in range(lo, hi + 1):
			var p := Tables.ORIGIN[axis] + i * 0.05
			var a := _to_px(v, Vector2(p, area.position.y) if axis == 0 else Vector2(area.position.x, p))
			var color := GRID10 if i % 2 == 0 else GRID
			if axis == 0:
				draw_line(Vector2(a.x, room.position.y), Vector2(a.x, room.end.y), color, 1.0)
			else:
				draw_line(Vector2(room.position.x, a.y), Vector2(room.end.x, a.y), color, 1.0)


## The rulers, the heading, and where the reader sits.
func _rulers(v: Dictionary, font: Font) -> void:
	var room: Rect2 = v["room"]
	var area: Rect2 = v["area"]
	var s := float(v["scale"])
	var every := 10 if s * 0.1 >= 44.0 else 20
	draw_rect(room, INK, false, 1.5)
	for axis in 2:
		var lo := ceili((area.position[axis] - Tables.ORIGIN[axis]) * 100.0)
		var hi := floori((area.end[axis] - Tables.ORIGIN[axis]) * 100.0)
		for cm in range(lo, hi + 1):
			if cm % 5 != 0:
				continue
			var p := Tables.ORIGIN[axis] + cm * 0.01
			var long := cm % every == 0
			if axis == 0:
				var x := _to_px(v, Vector2(p, 0.0)).x
				draw_line(Vector2(x, room.position.y), Vector2(x, room.position.y - (9.0 if long else 4.0)), INK, 1.0)
				if long:
					_label(font, Vector2(x, room.position.y - 13.0), str(cm), SMALL, INK, PAPER)
			else:
				var y := _to_px(v, Vector2(0.0, p)).y
				draw_line(Vector2(room.position.x, y), Vector2(room.position.x - (9.0 if long else 4.0), y), INK, 1.0)
				if long:
					var w := font.get_string_size(str(cm), HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL).x
					draw_string(font, Vector2(room.position.x - 13.0 - w, y + 4.5), str(cm), HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, INK)
	# the middle of the reading: where `at` is counted from
	var o := _to_px(v, Tables.ORIGIN)
	if room.has_point(o):
		draw_line(o + Vector2(-10, 0), o + Vector2(10, 0), INK, 1.5)
		draw_line(o + Vector2(0, -10), o + Vector2(0, 10), INK, 1.5)
		draw_arc(o, 5.0, 0.0, TAU, 20, INK, 1.5)
	draw_string(font, Vector2(room.position.x, 22.0),
		"THE TABLE FROM ABOVE - centimeters from the middle of the reading (+): x to the reader's right, z toward the reader.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)
	draw_string(font, Vector2(room.position.x, 42.0),
		"A thing's number is the one put gives it; its tick points to its front. The room, beyond the table, is at the top.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, FAINT)
	_label(font, Vector2(room.get_center().x, room.end.y + 18.0), "THE READER", FONT_SIZE, INK, PAPER)


## The key along the foot of the sheet.
func _key(font: Font) -> void:
	var y := float(SHEET.y) - 40.0
	var x := MARGIN_TL.x
	var items := [["hatch", "the cards' room: nothing stands there"], ["gray", "unseen by the camera"],
		["height", "the tallest a thing there is seen whole (taller: its top is cut)"], ["dots", "the reader's hands"]]
	for row in 2:
		for it in items:
			var kind := String(it[0])
			var sw := Rect2(Vector2(x, y - 11.0), Vector2(22.0, 13.0))
			match kind:
				"hatch":
					_hatch(Geo.of_rect(sw), 5.0, FAINT, 1.0)
					draw_rect(sw, FAINT, false, 1.0)
				"gray":
					draw_rect(sw, UNSEEN)
				"warm":
					draw_rect(sw, LIT)
					draw_rect(sw, INK, false, 1.5)
				"height":
					draw_line(Vector2(x, y - 4.0), Vector2(x + 22.0, y - 4.0), HEIGHT_INK, 2.0)
				"dots":
					_line(Geo.of_rect(sw), INK, 1.0, PackedVector2Array(), 2.0, true)
				"moved":
					draw_dashed_line(Vector2(x, y - 4.0), Vector2(x + 22.0, y - 4.0), TROUBLE, 2.0, 4.0)
				"edge":
					draw_dashed_line(Vector2(x, y - 4.0), Vector2(x + 22.0, y - 4.0), INK, 1.0, 2.0)
				"red":
					draw_circle(Vector2(x + 11.0, y - 4.0), 7.0, Color("#f6d5d0"))
					draw_arc(Vector2(x + 11.0, y - 4.0), 7.0, 0.0, TAU, 20, TROUBLE, 1.5, true)
			var text := String(it[1])
			draw_string(font, Vector2(x + 28.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, INK)
			x += 28.0 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL).x + 22.0
		y += 22.0
		x = MARGIN_TL.x
		items = [["warm", "a lit thing"], ["edge", "a thing's foot stays inside this line"],
			["moved", "where a thing was written, when it had to move"], ["red", "a thing taller than its spot shows"]]


# --- where everything falls on the sheet (no renderer needed) -------------------------------------------

## WHERE THE TABLE FALLS ON A SHEET of [param sheet] pixels: the stretch of the table drawn (`area`,
## meters - what the camera sees of the top, the cards and every thing, [constant PAD] round them), how
## many pixels a meter is (`scale`), where the table's (0, 0) falls (`origin`) and the drawing's own
## rectangle on the sheet (`room`). x runs to the right, z down: the reader sits at the bottom.
static func view(d: Dictionary, sheet := Vector2(SHEET)) -> Dictionary:
	var area := Rect2()
	var have := false
	if d.get("camera") is Transform3D and d.has("top"):
		for poly in Geometry2D.intersect_polygons(outline(d["top"]), seen(d["camera"], float(d.get("fov", 40.0)))):
			area = Geo.bounds(poly) if not have else area.merge(Geo.bounds(poly))
			have = true
	var card: Vector2 = d.get("card", Vector2(0.07, 0.12))
	for c in d.get("cards", []):
		var r := Geo.bounds(card_outline((c as Dictionary)["pos"], float((c as Dictionary)["yaw"]), card))
		area = r if not have else area.merge(r)
		have = true
	for t in d.get("things", []):
		var r: Rect2 = (t as Dictionary)["bb"]
		area = r if not have else area.merge(r)
		have = true
	for u in d.get("unstood", []):
		var r := Rect2((u as Dictionary)["written"], Vector2.ZERO)
		area = r if not have else area.merge(r)
		have = true
	if not have:
		area = Rect2(Tables.HOLDS.position + Tables.ORIGIN, Tables.HOLDS.size)
	area = area.grow(PAD)
	var room := Rect2(MARGIN_TL, sheet - MARGIN_TL - MARGIN_BR)
	var s := minf(room.size.x / area.size.x, room.size.y / area.size.y)
	return {"area": area, "scale": s, "origin": room.get_center() - area.get_center() * s, "room": room}


## Where [param p] (on the table, meters) falls on the sheet laid out by [param v] ([method view]).
static func _to_px(v: Dictionary, p: Vector2) -> Vector2:
	return (v["origin"] as Vector2) + p * float(v["scale"])


static func _px(v: Dictionary, poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		out.append(_to_px(v, q))
	return out


## THE OUTLINE [param o] ([method Tables.top_outline], [method Tables.layer_outline]) as a polygon of
## [param n] points, walked round from its middle: each where its edge crosses the ray out to it.
static func outline(o: Dictionary, n := 160) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c: Vector2 = o["center"]
	var far := (o["half"] as Vector2).length() * 1.5 + float(o.get("grow", 0.0)) + 0.1
	for i in n:
		var dir := Vector2.from_angle(TAU * i / n)
		var lo := 0.0
		var hi := far
		for step in 24:
			var mid := (lo + hi) * 0.5
			if Tables.sdf(o, c + dir * mid) < 0.0:
				lo = mid
			else:
				hi = mid
		out.append(c + dir * lo)
	return out


## THE CAMERA'S FRAME ON THE TABLE: its edge walked round, each ray to where it meets the table - or
## [param reach] out, where it never comes down to it. A polygon on the table (x, z).
static func seen(cam: Transform3D, fov: float, reach := 3.0) -> PackedVector2Array:
	var k := tan(deg_to_rad(fov * 0.5))
	var edge: Array = []
	for i in 40:
		edge.append(Vector2(float(i) / 20.0 - 1.0, 1.0))
	for i in 40:
		edge.append(Vector2(1.0, 1.0 - float(i) / 20.0))
	for i in 40:
		edge.append(Vector2(1.0 - float(i) / 20.0, -1.0))
	for i in 40:
		edge.append(Vector2(-1.0, -1.0 + float(i) / 20.0))
	var out := PackedVector2Array()
	for e in edge:
		var d := (cam.basis * Vector3((e as Vector2).x * k * 16.0 / 9.0, (e as Vector2).y * k, -1.0)).normalized()
		var q: Vector3
		if d.y < -0.02:
			q = cam.origin + d * minf(-cam.origin.y / d.y, reach)
		else:
			q = cam.origin + Vector3(d.x, 0.0, d.z).normalized() * reach
		out.append(Vector2(q.x, q.z))
	return out


## WHERE A THING [param h] meters tall is just seen whole ([method CardTable.headroom_plane]): the two ends
## of that line across [param area], or none when it does not cross it. Nearer the reader than the line,
## a thing that tall is seen whole; farther back, its top is cut by the frame.
static func height_line(cam: Transform3D, fov: float, h: float, area: Rect2) -> PackedVector2Array:
	var r := CardTable.headroom_plane(cam, fov)
	var g := Vector2(r.x, r.y)
	if is_inf(r.z) or g.length_squared() < 1e-12:
		return PackedVector2Array()
	# the point of the line nearest the area's middle, and the line's way
	var m := area.get_center()
	var p0 := m + g * (h - (m.dot(g) + r.z)) / g.length_squared()
	var way := Vector2(-g.y, g.x).normalized() * (area.size.length() * 2.0)
	var pieces: Array = Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([p0 - way, p0 + way]), Geo.of_rect(area))
	if pieces.is_empty() or (pieces[0] as PackedVector2Array).size() < 2:
		return PackedVector2Array()
	var piece: PackedVector2Array = pieces[0]
	return PackedVector2Array([piece[0], piece[piece.size() - 1]])


## A card of [param size] lying at [param pos] (x, z), turned by [param yaw] as the table turns one.
static func card_outline(pos: Vector2, yaw: float, size: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var l := Vector3((c as Vector2).x * size.x * 0.5, 0.0, (c as Vector2).y * size.y * 0.5)
		var w := Basis(Vector3.UP, yaw) * l
		out.append(pos + Vector2(w.x, w.z))
	return out


# --- the pen ----------------------------------------------------------------------------------------------

## [param poly] drawn as a line ([param closed] round), in dashes [param dash] pixels long (0: solid), only
## where it lies inside [param clip] (the whole sheet when that is empty).
func _line(poly: PackedVector2Array, color: Color, width: float, clip: PackedVector2Array, dash: float, closed: bool) -> void:
	var path := poly.duplicate()
	if closed and path.size() > 2:
		path.append(path[0])
	var pieces: Array = [path] if clip.is_empty() else Geometry2D.intersect_polyline_with_polygon(path, clip)
	for piece in pieces:
		var p: PackedVector2Array = piece
		for i in p.size() - 1:
			if dash > 0.0:
				draw_dashed_line(p[i], p[i + 1], color, width, dash, false, true)
			else:
				draw_line(p[i], p[i + 1], color, width, true)


## [param poly] hatched with diagonal lines [param gap] pixels apart.
func _hatch(poly: PackedVector2Array, gap: float, color: Color, width: float) -> void:
	var b := Geo.bounds(poly)
	var c := b.position.x - b.end.y
	while c < b.end.x - b.position.y:
		var line := PackedVector2Array([Vector2(c + b.position.y, b.position.y), Vector2(c + b.end.y, b.end.y)])
		for piece in Geometry2D.intersect_polyline_with_polygon(line, poly):
			var p: PackedVector2Array = piece
			if p.size() >= 2:
				draw_line(p[0], p[p.size() - 1], color, width, true)
		c += gap * 1.4142


## [param text] centered on [param at] (its baseline), on a halo of [param halo] when that is seen.
func _label(font: Font, at: Vector2, text: String, size: int, color: Color, halo: Color, centered := true) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := at - Vector2(w * 0.5 if centered else 0.0, 0.0)
	if halo.a > 0.0:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, halo)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
