extends RefCounted
class_name CardFaces

## CardFaces - a card's face, its back and its booklet page, composed in 2D for the table.
##
## THE PAINTER PAINTS PICTURES; THE DECK PRINTS CARDS. A generated picture is the card's
## illustration and nothing else (see [CardPrompts.card_image]) - the stock, the frame, the
## numeral and the name are printed around it here, from the episode's look, so every card of a
## deck shares one frame exactly and every name is spelled right. The back is the same: the
## painted design inside the deck's frame.
##
## EACH IS A STOPPED SUBVIEWPORT, the comic's trick: drawn once (UPDATE_ONCE), then held as a
## texture in VRAM at no further cost, and drawn again only when something it shows changes - a
## picture landing mid-reading. Never read back to the CPU.

## A tarot card's proportions: 70 x 120 mm.
const ASPECT := 70.0 / 120.0
const FACE_PX := Vector2i(560, 960)
## The booklet page: a little white booklet's page, a touch narrower than the card is tall.
const PAGE_PX := Vector2i(660, 940)
const PAGE_ASPECT := float(PAGE_PX.x) / float(PAGE_PX.y)


## A viewport holding [param canvas], sized [param px], drawn once.
static func viewport(host: Node, canvas: Node2D, px: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = px
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(canvas)
	host.add_child(vp)
	return vp


## Draw [param vp] again, once (its content changed).
static func redraw(vp: SubViewport) -> void:
	if vp == null:
		return
	for c in vp.get_children():
		if c is CanvasItem:
			(c as CanvasItem).queue_redraw()
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## A rounded rectangle, filled or outlined.
static func _box(ci: CanvasItem, r: Rect2, col: Color, radius: float, fill := true, width := 2.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col if fill else Color(0, 0, 0, 0)
	sb.draw_center = fill
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	if not fill:
		sb.set_border_width_all(int(maxf(1.0, width)))
		sb.border_color = col
	ci.draw_style_box(sb, r)


## [param tex] drawn into [param dst] cropped to cover it - the picture's center kept.
static func _cover(ci: CanvasItem, tex: Texture2D, dst: Rect2, flip := false) -> void:
	var ts := Vector2(tex.get_size())
	var want := dst.size.x / dst.size.y
	var have := ts.x / ts.y
	var src := Rect2(Vector2.ZERO, ts)
	if have > want:
		src.size.x = ts.y * want
		src.position.x = (ts.x - src.size.x) * 0.5
	else:
		src.size.y = ts.x / want
		src.position.y = (ts.y - src.size.y) * 0.5
	if flip:
		ci.draw_set_transform(dst.get_center(), PI, Vector2.ONE)
		ci.draw_texture_rect_region(tex, Rect2(-dst.size * 0.5, dst.size), src)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		ci.draw_texture_rect_region(tex, dst, src)


## [param tex] drawn into the window [param hole] (a [method outline] round [param dst]), cropped to cover
## [param dst] as [method _cover] does - the picture cut to the window's shape.
static func _cover_shape(ci: CanvasItem, tex: Texture2D, dst: Rect2, hole: PackedVector2Array) -> void:
	var ts := Vector2(tex.get_size())
	var want := dst.size.x / dst.size.y
	var have := ts.x / ts.y
	var src := Rect2(Vector2.ZERO, ts)
	if have > want:
		src.size.x = ts.y * want
		src.position.x = (ts.x - src.size.x) * 0.5
	else:
		src.size.y = ts.x / want
		src.position.y = (ts.y - src.size.y) * 0.5
	var uvs := PackedVector2Array()
	for p in hole:
		var u := (p - dst.position) / dst.size
		uvs.append((src.position + u * src.size) / ts)
	ci.draw_polygon(hole, PackedColorArray([Color.WHITE]), uvs, tex)


## A picture not painted yet: a soft field of the deck's own colors, seeded per card - a
## picture still arriving, never a gray broken plate - inside the window [param hole] when it has one.
static func _placeholder(ci: CanvasItem, r: Rect2, palette: Array, seed: int, hole := PackedVector2Array()) -> void:
	if palette.is_empty():
		palette = CardTable.FALLBACK_PALETTE
	if hole.is_empty():
		hole = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var a := CardTable.color(String(palette[0])) if not palette.is_empty() else Color(0.2, 0.2, 0.3)
	ci.draw_colored_polygon(hole, a.darkened(0.2))
	for i in 9:
		var c := CardTable.color(String(palette[rng.randi_range(0, maxi(0, palette.size() - 1))]))
		c.a = 0.22
		var p := r.position + Vector2(rng.randf(), rng.randf()) * r.size
		var rad := rng.randf_range(0.12, 0.38) * r.size.x
		for k in 5:
			var disc := PackedVector2Array()
			for j in 24:
				disc.append(p + Vector2.from_angle(TAU * float(j) / 24.0) * rad * (1.0 - float(k) * 0.17))
			for piece in Geometry2D.intersect_polygons(disc, hole):
				ci.draw_colored_polygon(piece, c)


## THE ORNAMENT ROUND THE CARD'S EDGE ([constant CardTable.ORNAMENTS]), along [method edge_path] - in the
## frame's ink and accent, on face and back alike.
static func ornament(ci: CanvasItem, look: Dictionary, ink: Color, accent: Color) -> void:
	var kind := ornament_of(look)
	if kind == "none":
		return
	var sz := Vector2(FACE_PX)
	var w := walk(edge_path(look, sz.x * ORNAMENT_INSET))
	var L := float(w["length"])
	var u := sz.x / 560.0          # sizes below are written for a 560 px face
	match kind:
		"vine":
			var lam := 64.0 * u
			var amp := 6.0 * u
			var n := maxi(roundi(L / lam), 4)
			lam = L / float(n)
			var stem := PackedVector2Array()
			var steps := int(L / (2.0 * u))
			for i in steps + 1:
				var s := L * float(i) / float(steps)
				var at := walked(w, s)
				stem.append((at[0] as Vector2) + (at[2] as Vector2) * amp * sin(TAU * s / lam))
			ci.draw_polyline(stem, ink, 2.2 * u, true)
			for i in n * 2:
				var s := lam * (0.25 + 0.5 * float(i))
				var at := walked(w, s)
				var side := 1.0 if i % 2 == 0 else -1.0
				var base: Vector2 = (at[0] as Vector2) + (at[2] as Vector2) * amp * sin(TAU * s / lam)
				var dir := ((at[1] as Vector2) * 0.55 + (at[2] as Vector2) * side * 0.85).normalized()
				ci.draw_colored_polygon(leaf(base, dir, 20.0 * u, 9.5 * u), accent)
				ci.draw_line(base, base + dir * 15.0 * u, ink, 0.9 * u, true)
				if i % 5 == 2:
					# a curl of tendril, the other way
					var curl := PackedVector2Array()
					for j in 13:
						var a := float(j) / 12.0 * TAU * 0.9
						var rr := 5.0 * u * (1.0 - float(j) / 16.0)
						var c0: Vector2 = base - (at[2] as Vector2) * side * 6.0 * u
						curl.append(c0 + ((at[1] as Vector2) * cos(a) - (at[2] as Vector2) * side * sin(a)) * rr)
					ci.draw_polyline(curl, ink, 1.0 * u, true)
		"serpent":
			# THE BODY: a strip along the path, broadest behind the head and tapering to the tail, which ends in
			# its mouth; its markings along it, then the head - at the top, in the middle
			var head := 30.0 * u
			w["start"] = _nearest(w, Vector2(sz.x * 0.5, 0.0))
			var lam := 120.0 * u
			var steps := int(L / (2.0 * u))
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			var mids: Array = []
			for i in steps + 1:
				var s := lerpf(head * 0.6, L - head * 0.35, float(i) / float(steps))
				var at := walked(w, s)
				var k := s / L
				var half := lerpf(8.5, 1.2, pow(k, 1.4)) * u
				var c: Vector2 = (at[0] as Vector2) + (at[2] as Vector2) * 2.5 * u * sin(TAU * s / lam)
				left.append(c + (at[2] as Vector2) * half)
				right.append(c - (at[2] as Vector2) * half)
				mids.append([c, at[1], at[2], half])
			var body := left.duplicate()
			var back := right.duplicate()
			back.reverse()
			body.append_array(back)
			ci.draw_colored_polygon(body, accent)
			ci.draw_polyline(left, ink, 1.2 * u, true)
			ci.draw_polyline(right, ink, 1.2 * u, true)
			for i in range(0, mids.size(), 4):
				var m: Array = mids[i]
				var c: Vector2 = m[0]
				var t: Vector2 = m[1]
				var nn: Vector2 = m[2]
				var half := float(m[3]) * 0.8
				if i % 12 == 0:
					# a diamond down its back
					ci.draw_colored_polygon(PackedVector2Array([c - t * half * 1.1, c + nn * half * 0.7, c + t * half * 1.1, c - nn * half * 0.7]),
						ink.lerp(accent, 0.35))
				else:
					ci.draw_polyline(PackedVector2Array([c + nn * half - t * half * 0.5, c + t * half * 0.5, c - nn * half - t * half * 0.5]),
						ink.lerp(accent, 0.5), 0.8 * u, true)
			var at0 := walked(w, head * 0.25)
			var hc: Vector2 = at0[0]
			var ht: Vector2 = -(at0[1] as Vector2)
			var hn: Vector2 = at0[2]
			var skull := PackedVector2Array()
			for j in 20:
				var a := TAU * float(j) / 20.0
				var rx := 15.0 * u * (1.0 if cos(a) < 0.0 else 0.75)
				skull.append(hc + ht * cos(a) * rx + hn * sin(a) * (10.0 if cos(a) < 0.0 else 8.0) * u)
			ci.draw_colored_polygon(skull, accent)
			ci.draw_polyline(closed(skull), ink, 1.3 * u, true)
			ci.draw_circle(hc + ht * 4.0 * u + hn * 4.0 * u, 2.2 * u, ink)
			ci.draw_circle(hc + ht * 4.0 * u - hn * 4.0 * u, 2.2 * u, ink)
			# its jaws round the tail
			ci.draw_line(hc + ht * 11.5 * u, hc + ht * 5.0 * u, ink, 1.4 * u, true)
		"laurel":
			var step := 15.0 * u
			var n := int(L / step)
			step = L / float(n)
			var stem := PackedVector2Array()
			for i in int(L / (3.0 * u)) + 1:
				stem.append((walked(w, float(i) * 3.0 * u)[0]) as Vector2)
			ci.draw_polyline(stem, ink, 1.4 * u, true)
			for i in n:
				var at := walked(w, float(i) * step)
				for side in [1.0, -1.0]:
					var dir: Vector2 = ((at[1] as Vector2) * 0.8 + (at[2] as Vector2) * side * 0.6).normalized()
					ci.draw_colored_polygon(leaf(at[0], dir, 13.0 * u, 5.5 * u), accent)
		"beads":
			var step := 10.0 * u
			var n := int(L / step)
			step = L / float(n)
			for i in n:
				var p: Vector2 = walked(w, float(i) * step)[0]
				var r := (4.2 if i % 2 == 0 else 2.3) * u
				ci.draw_circle(p, r, accent)
				ci.draw_arc(p, r, 0.0, TAU, 16, ink, 0.8 * u, true)
				ci.draw_circle(p + Vector2(-0.35, -0.35) * r, r * 0.3, accent.lightened(0.5))
		"rope":
			var band := PackedVector2Array()
			for i in int(L / (3.0 * u)) + 1:
				band.append((walked(w, float(i) * 3.0 * u)[0]) as Vector2)
			ci.draw_polyline(band, accent, 7.0 * u, true)
			var step := 5.5 * u
			for i in int(L / step):
				var at := walked(w, float(i) * step)
				var p: Vector2 = at[0]
				ci.draw_line(p - (at[2] as Vector2) * 3.4 * u - (at[1] as Vector2) * 2.2 * u,
					p + (at[2] as Vector2) * 3.4 * u + (at[1] as Vector2) * 2.2 * u, ink, 1.1 * u, true)
		"stars":
			var step := 30.0 * u
			var n := int(L / step)
			step = L / float(n)
			for i in n:
				var p: Vector2 = walked(w, float(i) * step)[0]
				var big := i % 2 == 0
				ci.draw_colored_polygon(star(p, (7.0 if big else 4.0) * u, (2.0 if big else 1.3) * u, 4), accent)
		"scallops":
			var step := 18.0 * u
			var n := int(L / step)
			step = L / float(n)
			for i in n:
				var a := walked(w, float(i) * step)
				var mid := walked(w, (float(i) + 0.5) * step)
				var c: Vector2 = mid[0]
				var nn: Vector2 = mid[2]
				var t: Vector2 = mid[1]
				var arc := PackedVector2Array()
				for j in 11:
					var th := PI * float(j) / 10.0
					arc.append(c - t * cos(th) * step * 0.5 - nn * sin(th) * step * 0.45)
				ci.draw_polyline(arc, ink, 1.6 * u, true)
				ci.draw_circle(c - nn * step * 0.18, 1.6 * u, accent)
				ci.draw_circle(a[0], 1.0 * u, ink)


## WHERE THE PICTURE GOES on a card face (pixels, [constant FACE_PX]): inside a border of stock, with
## a band above it for the numeral and below it for the name - a back has no bands. A card printed with an
## ornament round its edge ([constant CardTable.ORNAMENTS]) keeps a wider border for it.
static func window(back := false, look: Dictionary = {}) -> Rect2:
	var sz := Vector2(FACE_PX)
	var m := sz.x * (ORNATE_MARGIN if ornament_of(look) != "none" else 0.06)
	var top := 0.0 if back else sz.y * 0.075
	var bottom := 0.0 if back else sz.y * 0.105
	return Rect2(Vector2(m, m + top), Vector2(sz.x - 2.0 * m, sz.y - 2.0 * m - top - bottom))


## The border a card printed with an ornament keeps (a share of its width), and where the ornament runs:
## this far in from the card's edge.
const ORNATE_MARGIN := 0.1
const ORNAMENT_INSET := 0.045


static func ornament_of(look: Dictionary) -> String:
	var f: Dictionary = look.get("frame", {}) if look.get("frame") is Dictionary else {}
	return String(f.get("ornament", "none"))


static func window_of(look: Dictionary) -> String:
	var f: Dictionary = look.get("frame", {}) if look.get("frame") is Dictionary else {}
	return String(f.get("window", "rect"))


## THE WINDOW'S OUTLINE ([constant CardTable.WINDOWS]) round the picture's box [param r], grown outward by
## [param g] pixels - every rule of the frame is the same shape a little further out, so a grown outline is
## an offset of it, not the shape scaled. Closed, clockwise on screen, the first point not repeated.
static func outline(shape: String, r: Rect2, g := 0.0) -> PackedVector2Array:
	var rr := r.grow(g)
	var x0 := rr.position.x
	var y0 := rr.position.y
	var x1 := rr.end.x
	var y1 := rr.end.y
	var w := r.size.x
	var pts := PackedVector2Array()
	match shape:
		"rounded":
			var cr := maxf(w * 0.06 + g, 0.5)
			pts.append_array(_arc(Vector2(x0 + cr, y0 + cr), cr, PI, 1.5 * PI))
			pts.append_array(_arc(Vector2(x1 - cr, y0 + cr), cr, 1.5 * PI, TAU))
			pts.append_array(_arc(Vector2(x1 - cr, y1 - cr), cr, 0.0, 0.5 * PI))
			pts.append_array(_arc(Vector2(x0 + cr, y1 - cr), cr, 0.5 * PI, PI))
		"arch":
			# the shoulders step in by the same amount however far out the rule is; the arch grows with it
			var sh := w * 0.07
			var R := rr.size.x * 0.5 - sh
			var ys := r.position.y + (w * 0.5 - sh)
			pts.append(Vector2(x0, y1))
			pts.append(Vector2(x0, ys))
			pts.append(Vector2(x0 + sh, ys))
			pts.append_array(_arc(Vector2(rr.get_center().x, ys), R, PI, TAU, 40).slice(1, 40))
			pts.append(Vector2(x1 - sh, ys))
			pts.append(Vector2(x1, ys))
			pts.append(Vector2(x1, y1))
		"gothic":
			# two arcs from centers inside the springing line, meeting in a point; grown, the same centers
			var rad := w * 0.6
			var dx := w * 0.5 - rad
			var apex := sqrt(rad * rad - dx * dx)
			var ys := r.position.y + apex
			var ra := rad + g
			var h := sqrt(maxf(ra * ra - dx * dx, 0.0))
			var cl := Vector2(r.position.x + rad, ys)
			var cr2 := Vector2(r.end.x - rad, ys)
			pts.append(Vector2(x0, y1))
			pts.append_array(_arc(cl, ra, PI, TAU + atan2(-h, dx), 20))
			pts.append_array(_arc(cr2, ra, TAU + atan2(-h, -dx), TAU, 20).slice(1, 21))
			pts.append(Vector2(x1, y1))
		"oval":
			var c := rr.get_center()
			for i in 72:
				var a := PI + TAU * float(i) / 72.0
				pts.append(c + Vector2(cos(a) * rr.size.x * 0.5, sin(a) * rr.size.y * 0.5))
		"notched":
			var n := maxf(w * 0.09 - g, 0.5)
			pts.append_array(_arc(Vector2(x0, y0), n, 0.5 * PI, 0.0, 8))
			pts.append_array(_arc(Vector2(x1, y0), n, PI, 0.5 * PI, 8))
			pts.append_array(_arc(Vector2(x1, y1), n, 1.5 * PI, PI, 8))
			pts.append_array(_arc(Vector2(x0, y1), n, TAU, 1.5 * PI, 8))
		"octagon":
			var c := w * 0.08 + g * 0.414
			pts.append_array(PackedVector2Array([Vector2(x0, y0 + c), Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c),
				Vector2(x1, y1 - c), Vector2(x1 - c, y1), Vector2(x0 + c, y1), Vector2(x0, y1 - c)]))
		_:
			pts.append_array(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]))
	return pts


## Points round an arc, [param a0] to [param a1] (radians, screen-wise: y down), [param n] steps.
static func _arc(c: Vector2, r: float, a0: float, a1: float, n := 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / float(n))
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## [param pts] closed for a polyline.
static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if not pts.is_empty():
		out.append(pts[0])
	return out


## THE CARD'S OWN EDGE, [param inset] pixels in: a rectangle rounded as the card is cut ([method
## CardTable.corner_radius]) - the line an ornament runs along.
static func edge_path(look: Dictionary, inset: float) -> PackedVector2Array:
	var sz := Vector2(FACE_PX)
	var r := Rect2(Vector2(inset, inset), sz - Vector2(inset, inset) * 2.0)
	var cr := maxf(CardTable.corner_radius(look) / 0.07 * sz.x - inset, sz.x * 0.03)
	var pts := PackedVector2Array()
	pts.append_array(_arc(Vector2(r.position.x + cr, r.position.y + cr), cr, PI, 1.5 * PI))
	pts.append_array(_arc(Vector2(r.end.x - cr, r.position.y + cr), cr, 1.5 * PI, TAU))
	pts.append_array(_arc(Vector2(r.end.x - cr, r.end.y - cr), cr, 0.0, 0.5 * PI))
	pts.append_array(_arc(Vector2(r.position.x + cr, r.end.y - cr), cr, 0.5 * PI, PI))
	return pts


## A CLOSED PATH WALKED BY LENGTH: `{pts, at}` - its points (closed) and the length along it to each.
static func walk(pts: PackedVector2Array) -> Dictionary:
	var c := closed(pts)
	var at := PackedFloat32Array([0.0])
	for i in range(1, c.size()):
		at.append(at[i - 1] + c[i].distance_to(c[i - 1]))
	return {"pts": c, "at": at, "length": at[at.size() - 1], "mid": _mean(pts)}


static func _mean(pts: PackedVector2Array) -> Vector2:
	var m := Vector2.ZERO
	for p in pts:
		m += p
	return m / maxf(float(pts.size()), 1.0)


## Where [param s] along a [method walk] is: `[point, tangent, inward normal]` - from its `start`, when it
## has one.
static func walked(w: Dictionary, s: float) -> Array:
	var at: PackedFloat32Array = w["at"]
	var pts: PackedVector2Array = w["pts"]
	var L := float(w["length"])
	s = fposmod(s + float(w.get("start", 0.0)), L)
	var i := at.bsearch(s)
	i = clampi(i, 1, at.size() - 1)
	var seg := maxf(at[i] - at[i - 1], 1e-4)
	var p := pts[i - 1].lerp(pts[i], (s - at[i - 1]) / seg)
	var t := (pts[i] - pts[i - 1]).normalized()
	var n := t.orthogonal()
	if n.dot((w["mid"] as Vector2) - p) < 0.0:
		n = -n
	return [p, t, n]


## How far along [param w] its point nearest [param p] lies.
static func _nearest(w: Dictionary, p: Vector2) -> float:
	var L := float(w["length"])
	var best := 0.0
	var near := INF
	var s := 0.0
	while s < L:
		var d := (walked(w, s)[0] as Vector2).distance_squared_to(p)
		if d < near:
			near = d
			best = s
		s += 2.0
	return best + float(w.get("start", 0.0))


## A leaf's outline: pointed at both ends, from [param base] [param length] along [param dir].
static func leaf(base: Vector2, dir: Vector2, length: float, width: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var side := dir.orthogonal()
	for i in 9:
		var u := float(i) / 8.0
		out.append(base + dir * length * u + side * sin(u * PI) * width * 0.5)
	for i in range(7, 0, -1):
		var u := float(i) / 8.0
		out.append(base + dir * length * u - side * sin(u * PI) * width * 0.5)
	return out


## A star of [param points] points at [param c].
static func star(c: Vector2, outer: float, inner: float, points: int, turn := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points * 2:
		var a := turn - PI * 0.5 + PI * float(i) / float(points)
		out.append(c + Vector2(cos(a), sin(a)) * (outer if i % 2 == 0 else inner))
	return out


## The largest font size up to [param size] at which [param text] fits [param width].
static func _fit(font: Font, text: String, size: int, width: float) -> int:
	var s := size
	while s > 10 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width:
		s -= 1
	return s


## THE PRINTED CARD - face or back. Everything it draws comes from the episode's look and the
## card; the picture is optional (a placeholder until it lands).
class Face:
	extends Node2D

	var look: Dictionary = {}
	var card: Dictionary = {}
	var art: Texture2D = null
	var back := false
	## A BACK WITH THE CARD'S TEXT ON IT ([constant CardTable.TEXTS] `back`): [member card]'s booklet
	## printed in a panel over the printing's back, as a baseball card's stats are.
	var printed := false
	var seed := 0

	func _draw() -> void:
		var sz := Vector2(CardFaces.FACE_PX)
		var frame: Dictionary = look.get("frame", {})
		var style := String(frame.get("style", "line"))
		var stock := CardTable.color(String(frame.get("stock", "#efe6d2")))
		var ink := CardTable.color(String(frame.get("ink", "#1d1a2b")))
		var accent := CardTable.color(String(frame.get("accent", "#c9a227")))
		# the whole face is stock: the card's slab is cut to its corners ([method CardTable.corner_radius])
		draw_rect(Rect2(Vector2.ZERO, sz), stock)
		var win := CardFaces.window(back, look)
		var shape := CardFaces.window_of(look)
		var hole := CardFaces.outline(shape, win)
		if art != null:
			# a reversed card is printed the right way up: the TABLE turns it over
			CardFaces._cover_shape(self, art, win, hole)
		else:
			CardFaces._placeholder(self, win, look.get("palette", []),
				hash([seed, String(card.get("key", "back"))]), hole)
		_frame(style, shape, win, ink, accent, sz)
		CardFaces.ornament(self, look, ink, accent)
		if not back:
			_lettering(win, ink, sz)
		elif printed:
			_printed_back(win, stock, ink, accent)

	## THE CARD'S TEXT ON ITS BACK: a panel of the card's stock over the back's design - its name, its
	## facts (the booklet's keywords) and its text, set to fill the panel.
	func _printed_back(win: Rect2, stock: Color, ink: Color, accent: Color) -> void:
		var panel := win.grow(-win.size.x * 0.07)
		var paper := stock
		paper.a = 0.94
		CardFaces._box(self, panel, paper, win.size.x * 0.03)
		CardFaces._box(self, panel.grow(-6.0), accent, win.size.x * 0.025, false, 3.0)
		var text_ink := CardTable.legible_ink(ink, stock, CardTable.TEXT_CONTRAST)
		var face := CardTable.font(String(look.get("title_face", "roman")))
		var book := CardTable.font(CardTable.BOOK_FACE)
		var italic := CardTable.font(CardTable.BOOK_ITALIC)
		var m := panel.size.x * 0.08
		var x := panel.position.x + m
		var w := panel.size.x - 2.0 * m
		var y := panel.position.y + m
		var name := String(card.get("name", ""))
		var ns := CardFaces._fit(face, name, 46, w)
		y += face.get_ascent(ns)
		draw_string(face, Vector2(x, y), name, HORIZONTAL_ALIGNMENT_CENTER, w, ns, text_ink)
		y += face.get_descent(ns) + 8.0
		var b: Dictionary = card.get("booklet", {}) if card.get("booklet") is Dictionary else {}
		var kw := CardPrompts.strings(b.get("keywords", []))
		if not kw.is_empty():
			draw_line(Vector2(x, y), Vector2(x + w, y), accent, 2.0, true)
			y += 8.0
			# the facts one to a line, as a card's back lists them
			for line in kw.slice(0, 6):
				var ks := CardFaces._fit(italic, String(line), 28, w)
				y += italic.get_ascent(ks)
				draw_string(italic, Vector2(x, y), String(line), HORIZONTAL_ALIGNMENT_LEFT, w, ks, text_ink)
				y += italic.get_descent(ks) + 4.0
			y += 6.0
			draw_line(Vector2(x, y), Vector2(x + w, y), accent, 2.0, true)
			y += 12.0
		var text := String(b.get("upright", "")).strip_edges()
		if text.is_empty():
			return
		var room := panel.end.y - m - y
		var size := 30
		while size > 14 and book.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, size).y > room:
			size -= 1
		draw_multiline_string(book, Vector2(x, y + book.get_ascent(size)), text, HORIZONTAL_ALIGNMENT_LEFT, w,
			size, -1, text_ink)

	## THE RULES ROUND THE PICTURE, in the window's own shape ([method CardFaces.outline]).
	func _frame(style: String, shape: String, win: Rect2, ink: Color, accent: Color, sz: Vector2) -> void:
		var r := sz.x * 0.02
		var line := func(g: float, col: Color, w: float) -> void:
			draw_polyline(CardFaces.closed(CardFaces.outline(shape, win, g)), col, w, true)
		match style:
			"double":
				line.call(sz.x * 0.012, ink, sz.x * 0.009)
				line.call(sz.x * 0.026, accent, sz.x * 0.004)
			"corners":
				line.call(0.0, ink, sz.x * 0.005)
				var L := sz.x * 0.11
				var off := sz.x * 0.022
				var w := sz.x * 0.012
				# a bracket at every corner the outline turns OUT at, sharply - a rectangle's four, an arch's
				# foot and shoulders - never on a curve or where it turns in
				var o := CardFaces.outline(shape, win, off)
				var n := o.size()
				for i in n:
					var c := o[i]
					var din := (c - o[(i - 1 + n) % n]).normalized()
					var dout := (o[(i + 1) % n] - c).normalized()
					if din.cross(dout) < 0.6:
						continue
					draw_polyline(PackedVector2Array([c - din * L, c, c + dout * L]), accent, w, true)
					draw_circle(c, w * 1.4, accent)
			"deco":
				if shape != "rect":
					for i in 3:
						line.call(sz.x * 0.018 * float(i), accent if i == 1 else ink, sz.x * (0.006 if i == 1 else 0.004))
					return
				var g := sz.x * 0.018
				for i in 3:
					var rr := win.grow(g * float(i))
					var st := sz.x * (0.05 + 0.03 * float(i))
					var pts := PackedVector2Array([
						rr.position + Vector2(st, 0), Vector2(rr.end.x - st, rr.position.y),
						Vector2(rr.end.x - st, rr.position.y + st * 0.0), Vector2(rr.end.x, rr.position.y + st),
						Vector2(rr.end.x, rr.end.y - st), Vector2(rr.end.x - st, rr.end.y),
						Vector2(rr.position.x + st, rr.end.y), Vector2(rr.position.x, rr.end.y - st),
						Vector2(rr.position.x, rr.position.y + st), rr.position + Vector2(st, 0)])
					draw_polyline(pts, accent if i == 1 else ink, sz.x * (0.006 if i == 1 else 0.004), true)
			_:
				line.call(0.0, ink, sz.x * 0.006)
				line.call(sz.x * 0.02, ink, sz.x * 0.002)

	func _lettering(win: Rect2, ink: Color, sz: Vector2) -> void:
		var face := CardTable.font(String(look.get("title_face", "roman")))
		var caps := String(look.get("title_face", "roman")) in ["roman", "deco", "sign", "typed"]
		var name := String(card.get("name", ""))
		if caps:
			name = name.to_upper()
		var num := String(card.get("numeral", ""))
		# the bands span the plain border's width, whatever the window: an ornament runs outside them
		var plain := CardFaces.window()
		var band_top := Rect2(Vector2(plain.position.x, sz.y * 0.06 * 0.5), Vector2(plain.size.x, win.position.y - sz.y * 0.03))
		var band_bot := Rect2(Vector2(plain.position.x, win.end.y), Vector2(plain.size.x, sz.y - win.end.y - sz.x * 0.05))
		var pad := sz.x * 0.06
		var size := CardFaces._fit(face, name, int(sz.y * 0.052), band_bot.size.x - pad * 2.0)
		var asc := face.get_ascent(size)
		var desc := face.get_descent(size)
		var y := band_bot.get_center().y + (asc - desc) * 0.5
		draw_string(face, Vector2(band_bot.position.x, y), name, HORIZONTAL_ALIGNMENT_CENTER,
			band_bot.size.x, size, ink)
		if not num.is_empty():
			var ns := int(sz.y * 0.045)
			var ny := band_top.get_center().y + (face.get_ascent(ns) - face.get_descent(ns)) * 0.5
			draw_string(face, Vector2(band_top.position.x, ny), num, HORIZONTAL_ALIGNMENT_CENTER,
				band_top.size.x, ns, ink)


## THE BOOKLET'S COLORS are the card's: its stock for the paper, its ink and accent for the type,
## each kept readable on that paper (the running text at [constant CardTable.TEXT_CONTRAST]).
## [param shade] (0..1) takes a page a hair darker, so two pages are not one sheet.
static func page_colors(look: Dictionary, shade: float) -> Dictionary:
	var frame: Dictionary = look.get("frame", {}) if look.get("frame") is Dictionary else {}
	var stock := CardTable.color(String(frame.get("stock", "#efe6d2")))
	var paper := stock.lerp(stock.darkened(0.04), shade)
	return {"paper": paper,
		"ink": CardTable.legible_ink(CardTable.color(String(frame.get("ink", "#1d1a2b"))), paper,
			CardTable.TEXT_CONTRAST),
		"accent": CardTable.legible_ink(CardTable.color(String(frame.get("accent", "#7a2e3a"))), paper)}


## THE BOOKLET PAGE beside a drawn card: its entry in the deck's little booklet, printed in the
## card's colors ([method page_colors]). Shown, never read aloud.
class Page:
	extends Node2D

	var look: Dictionary = {}
	var card: Dictionary = {}
	var seed := 0

	func _draw() -> void:
		var sz := Vector2(CardFaces.PAGE_PX)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed, "page"])
		var col := CardFaces.page_colors(look, rng.randf())
		var paper: Color = col["paper"]
		var ink: Color = col["ink"]
		var accent: Color = col["accent"]
		CardFaces._box(self, Rect2(Vector2.ZERO, sz), paper, sz.x * 0.012)
		# the page's own grain: a few soft blotches, never a texture that fights the type
		for i in 24:
			var c := paper.darkened(rng.randf_range(0.004, 0.012))
			draw_circle(Vector2(rng.randf(), rng.randf()) * sz, rng.randf_range(20.0, 90.0), c)
		var m := sz.x * 0.1
		var face := CardTable.font(String(look.get("title_face", "roman")))
		var book := CardTable.font(CardTable.BOOK_FACE)
		var italic := CardTable.font(CardTable.BOOK_ITALIC)
		var rev := bool(card.get("reversed", false))
		var b: Dictionary = card.get("booklet", {}) if card.get("booklet") is Dictionary else {}
		var kw := CardPrompts.strings(b.get("keywords", []))
		var text := String(b.get("reversed" if rev and b.has("reversed") else "upright", ""))
		if text.strip_edges().is_empty():
			text = "The booklet is silent on this card."
		var f := {"face": face, "book": book, "italic": italic, "ink": ink, "accent": accent, "paper": paper,
			"rev": rev, "kw": kw, "text": text, "m": m, "sz": sz}
		match String(look.get("page", "classic")):
			"drop":
				_drop(f)
			"banner":
				_banner(f)
			"ledger":
				_ledger(f)
			_:
				_classic(f)

	## THE PAGE AS IT ALWAYS WAS: everything centered, the text justified.
	func _classic(f: Dictionary) -> void:
		var sz: Vector2 = f["sz"]
		var m := float(f["m"])
		var face: Font = f["face"]
		var italic: Font = f["italic"]
		var ink: Color = f["ink"]
		var accent: Color = f["accent"]
		var paper: Color = f["paper"]
		CardFaces._box(self, Rect2(Vector2(m * 0.5, m * 0.5), sz - Vector2(m, m)), accent, 4.0, false, 2.0)
		var x := m
		var w := sz.x - 2.0 * m
		var y := m * 1.25
		var num := String(card.get("numeral", ""))
		if not num.is_empty():
			draw_string(face, Vector2(x, y + 28.0), num, HORIZONTAL_ALIGNMENT_CENTER, w, 30, accent)
			y += 44.0
		var name := String(card.get("name", ""))
		var ns := CardFaces._fit(face, name, 52, w)
		y += face.get_ascent(ns)
		draw_string(face, Vector2(x, y), name, HORIZONTAL_ALIGNMENT_CENTER, w, ns, ink)
		y += face.get_descent(ns) + 10.0
		if bool(f["rev"]):
			y += 30.0
			draw_string(italic, Vector2(x, y), "Reversed", HORIZONTAL_ALIGNMENT_CENTER, w, 28, accent)
		var kw: PackedStringArray = f["kw"]
		if not kw.is_empty():
			y += 40.0
			var line := "  ·  ".join(kw)
			var ks := CardFaces._fit(italic, line, 32, w)
			draw_string(italic, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_CENTER, w, ks, ink.lerp(paper, 0.12))
		# the ornament between the head and the text
		y += 30.0
		var cx := sz.x * 0.5
		draw_line(Vector2(cx - w * 0.22, y), Vector2(cx - 12.0, y), accent, 2.0, true)
		draw_line(Vector2(cx + 12.0, y), Vector2(cx + w * 0.22, y), accent, 2.0, true)
		var d := PackedVector2Array([Vector2(cx, y - 7.0), Vector2(cx + 7.0, y), Vector2(cx, y + 7.0), Vector2(cx - 7.0, y)])
		draw_colored_polygon(d, accent)
		y += 26.0
		_text(f, x, y, w, sz.y - m * 1.1, HORIZONTAL_ALIGNMENT_FILL)

	## A HEADING TO THE LEFT over a rule, the text opening on a drop capital, the keywords at the foot.
	func _drop(f: Dictionary) -> void:
		var sz: Vector2 = f["sz"]
		var m := float(f["m"])
		var face: Font = f["face"]
		var italic: Font = f["italic"]
		var book: Font = f["book"]
		var ink: Color = f["ink"]
		var accent: Color = f["accent"]
		CardFaces._box(self, Rect2(Vector2(m * 0.4, m * 0.4), sz - Vector2(m * 0.8, m * 0.8)), ink, 2.0, false, 1.0)
		var x := m
		var w := sz.x - 2.0 * m
		var y := m * 1.2
		var num := String(card.get("numeral", ""))
		var name := String(card.get("name", ""))
		if not num.is_empty():
			draw_string(italic, Vector2(x, y + 24.0), num, HORIZONTAL_ALIGNMENT_LEFT, w, 28, accent)
			y += 34.0
		var ns := CardFaces._fit(face, name, 50, w)
		y += face.get_ascent(ns)
		draw_string(face, Vector2(x, y), name, HORIZONTAL_ALIGNMENT_LEFT, w, ns, ink)
		y += face.get_descent(ns) + 12.0
		draw_line(Vector2(x, y), Vector2(x + w, y), accent, 3.0, true)
		draw_line(Vector2(x, y + 6.0), Vector2(x + w * 0.6, y + 6.0), accent, 1.0, true)
		y += 22.0
		if bool(f["rev"]):
			draw_string(italic, Vector2(x, y + 24.0), "Reversed", HORIZONTAL_ALIGNMENT_LEFT, w, 26, accent)
			y += 40.0
		# the keywords at the foot, the text above them
		var kw: PackedStringArray = f["kw"]
		var foot := sz.y - m * 1.1
		if not kw.is_empty():
			var line := ", ".join(kw)
			var ks := CardFaces._fit(italic, line, 28, w)
			draw_string(italic, Vector2(x, foot), line, HORIZONTAL_ALIGNMENT_LEFT, w, ks, accent)
			foot -= ks + 18.0
			draw_line(Vector2(x, foot + 4.0), Vector2(x + w * 0.3, foot + 4.0), accent, 1.0, true)
			foot -= 10.0
		var text := String(f["text"]).strip_edges()
		var cap := text.substr(0, 1)
		var rest := text.substr(1)
		var size := 38
		var lines := 3
		while size > 18:
			var hh := book.get_multiline_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, w - size * 3.0, size).y
			if hh <= foot - y:
				break
			size -= 1
		# THE CAPITAL stands as tall as the three lines beside it
		var cs := int(book.get_height(size) * 3.3)
		var cw := face.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x + 12.0
		draw_string(face, Vector2(x, y + book.get_height(size) * 2.0 + book.get_ascent(size)), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, accent)
		# the first lines run beside the capital, the rest under it
		var lh := book.get_height(size)
		var words := rest.split(" ", false)
		var beside := PackedStringArray()
		var i := 0
		var yy := y + book.get_ascent(size)
		for l in lines:
			var row := PackedStringArray()
			while i < words.size() and book.get_string_size(" ".join(row + PackedStringArray([words[i]])), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= w - cw:
				row.append(words[i])
				i += 1
			draw_string(book, Vector2(x + cw, yy), " ".join(row), HORIZONTAL_ALIGNMENT_LEFT, w - cw, size, ink)
			yy += lh
		var tail := " ".join(words.slice(i))
		if not tail.is_empty():
			draw_multiline_string(book, Vector2(x, yy), tail, HORIZONTAL_ALIGNMENT_LEFT, w, size, -1, ink)

	## THE NAME OUT OF A BAND of the accent across the top, the keywords under it, the text centered.
	func _banner(f: Dictionary) -> void:
		var sz: Vector2 = f["sz"]
		var m := float(f["m"])
		var face: Font = f["face"]
		var italic: Font = f["italic"]
		var ink: Color = f["ink"]
		var accent: Color = f["accent"]
		var paper: Color = f["paper"]
		var x := m
		var w := sz.x - 2.0 * m
		var band := Rect2(Vector2(m * 0.5, m * 0.6), Vector2(sz.x - m, 112.0))
		CardFaces._box(self, band, accent, 6.0)
		var on := CardTable.legible_ink(paper, accent)
		var num := String(card.get("numeral", ""))
		var name := String(card.get("name", ""))
		var ns := CardFaces._fit(face, name, 50, w)
		var ny := band.get_center().y + (face.get_ascent(ns) - face.get_descent(ns)) * 0.5 + (10.0 if not num.is_empty() else 0.0)
		draw_string(face, Vector2(x, ny), name, HORIZONTAL_ALIGNMENT_CENTER, w, ns, on)
		if not num.is_empty():
			draw_string(italic, Vector2(x, band.position.y + 30.0), num, HORIZONTAL_ALIGNMENT_CENTER, w, 24, on)
		CardFaces._box(self, Rect2(Vector2(m * 0.5, m * 0.6), sz - Vector2(m, m * 1.2)), accent, 6.0, false, 2.0)
		var y := band.end.y + 44.0
		if bool(f["rev"]):
			draw_string(italic, Vector2(x, y), "Reversed", HORIZONTAL_ALIGNMENT_CENTER, w, 28, accent)
			y += 36.0
		var kw: PackedStringArray = f["kw"]
		if not kw.is_empty():
			var line := " ~ ".join(kw)
			var ks := CardFaces._fit(italic, line, 30, w)
			draw_string(italic, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_CENTER, w, ks, ink.lerp(paper, 0.15))
			y += 22.0
		draw_colored_polygon(CardFaces.star(Vector2(sz.x * 0.5, y + 8.0), 9.0, 3.0, 4), accent)
		y += 32.0
		_text(f, x, y, w, sz.y - m * 1.1, HORIZONTAL_ALIGNMENT_CENTER)

	## THE NAME AND NUMERAL ON ONE LINE over a heavy rule, the keywords listed, then the text, ragged.
	func _ledger(f: Dictionary) -> void:
		var sz: Vector2 = f["sz"]
		var m := float(f["m"])
		var face: Font = f["face"]
		var italic: Font = f["italic"]
		var ink: Color = f["ink"]
		var accent: Color = f["accent"]
		var x := m * 0.9
		var w := sz.x - 1.8 * m
		var y := m * 1.1
		var num := String(card.get("numeral", ""))
		var name := String(card.get("name", ""))
		var nw := face.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x + 16.0 if not num.is_empty() else 0.0
		var ns := CardFaces._fit(face, name, 46, w - nw)
		y += face.get_ascent(ns)
		draw_string(face, Vector2(x, y), name, HORIZONTAL_ALIGNMENT_LEFT, w - nw, ns, ink)
		if not num.is_empty():
			draw_string(face, Vector2(x, y), num, HORIZONTAL_ALIGNMENT_RIGHT, w, 40, accent)
		y += face.get_descent(ns) + 10.0
		draw_rect(Rect2(Vector2(x, y), Vector2(w, 5.0)), ink)
		y += 30.0
		if bool(f["rev"]):
			y += 14.0
			draw_string(italic, Vector2(x, y), "Reversed", HORIZONTAL_ALIGNMENT_LEFT, w, 26, accent)
			y += 34.0
		# the keywords in two columns, filled down the left one first
		var kw: PackedStringArray = f["kw"]
		var shown := kw.slice(0, 6)
		var rows := (shown.size() + 1) / 2
		var cw := w * 0.5
		var row_end := y
		for i in shown.size():
			var col := i / rows
			var kx := x + cw * col
			var ky := y + float(i % rows) * 36.0
			var ks := CardFaces._fit(italic, String(shown[i]), 28, cw - 30.0)
			draw_circle(Vector2(kx + 6.0, ky - ks * 0.3), 4.0, accent)
			draw_string(italic, Vector2(kx + 22.0, ky), String(shown[i]), HORIZONTAL_ALIGNMENT_LEFT, cw - 30.0, ks, ink)
			row_end = maxf(row_end, ky + 8.0)
		y = row_end
		y += 6.0
		draw_line(Vector2(x, y), Vector2(x + w, y), accent, 1.0, true)
		y += 18.0
		_text(f, x, y, w, sz.y - m * 0.9, HORIZONTAL_ALIGNMENT_LEFT)

	## THE ENTRY'S TEXT from [param top] down to [param bottom], as large as fits.
	func _text(f: Dictionary, x: float, top: float, w: float, bottom: float, align: HorizontalAlignment) -> void:
		var book: Font = f["book"]
		var text := String(f["text"])
		var room := bottom - top
		var size := 38
		while size > 18:
			var h := book.get_multiline_string_size(text, align, w, size).y
			if h <= room:
				break
			size -= 1
		# justified, except the paragraph's last line - stretched, it read "others   or   oneself."
		draw_multiline_string(book, Vector2(x, top + book.get_ascent(size)), text, align, w, size, -1, f["ink"],
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND,
			TextServer.JUSTIFICATION_KASHIDA | TextServer.JUSTIFICATION_WORD_BOUND
			| TextServer.JUSTIFICATION_SKIP_LAST_LINE | TextServer.JUSTIFICATION_DO_NOT_SKIP_SINGLE_LINE)
