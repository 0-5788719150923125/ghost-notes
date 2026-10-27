extends RefCounted
class_name CardFaces

## CardFaces - a card's face, its back and its booklet page, composed in 2D for the table.
##
## THE PAINTER PAINTS PICTURES; THE DECK PRINTS CARDS. A generated picture is the card's
## illustration and nothing else (see [TablePrompts.card_image]) - the stock, the frame, the
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

## A face's pixels: its SHORT side [constant FACE_PX]'s width - a card held sideways as sharp across its height as a
## tall one across its width - or, for a written card's lines of writing, [constant WRITTEN_PX].
static func face_px(look: Dictionary) -> Vector2i:
	var size := CardTable.card_size(look)
	var short := WRITTEN_PX if CardTable.written(look) else FACE_PX.x
	if size.x > size.y:
		return Vector2i(roundi(float(short) * size.x / size.y), short)
	return Vector2i(short, roundi(float(short) * size.y / size.x))
const WRITTEN_PX := 720
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
## [param dst] as [method _cover] does - the picture cut to the window's shape. [param part] is the part
## of that picture drawn (`{crop, mirror, tint}`, [method stand_in]) - all of it, as it is, when empty.
static func _cover_shape(ci: CanvasItem, tex: Texture2D, dst: Rect2, hole: PackedVector2Array, part := {}) -> void:
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
	var crop: Rect2 = part.get("crop", Rect2(0.0, 0.0, 1.0, 1.0))
	src = Rect2(src.position + crop.position * src.size, crop.size * src.size)
	var uvs := PackedVector2Array()
	for p in hole:
		var u := (p - dst.position) / dst.size
		if bool(part.get("mirror", false)):
			u.x = 1.0 - u.x
		uvs.append((src.position + u * src.size) / ts)
	ci.draw_polygon(hole, PackedColorArray([part.get("tint", Color.WHITE)]), uvs, tex)


## How much of a painting stands in for one nobody painted ([method stand_in]): this share of its width
## and height, so two to three times its size - and how far the deck's own color tints it.
const STAND_IN_SHARE := Vector2(0.34, 0.5)
const STAND_IN_TINT := 0.22


## A PAINTING NOBODY PAINTED, for a card nobody drew ([member Face.part]): a PART of one of the deck's
## own paintings - `{crop, mirror, tint}`, [constant STAND_IN_SHARE] of it somewhere in it, mirrored or
## not, tinted toward one of [param palette]'s colors - seeded by [param seed], so the card always shows
## the same one. Painting a card costs a painter's run, and a card that is only glanced at in its box is
## never painted: enlarged, mirrored and tinted, a corner of another card's picture is the deck's
## hand and colors and no picture the viewer has seen.
static func stand_in(palette: Array, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var share := rng.randf_range(STAND_IN_SHARE.x, STAND_IN_SHARE.y)
	var at := Vector2(rng.randf(), rng.randf()) * (1.0 - share)
	var mirror := rng.randf() < 0.5
	var tint := Color.WHITE
	if not palette.is_empty():
		tint = Color.WHITE.lerp(CardTable.color(String(palette[rng.randi_range(0, palette.size() - 1)])).lightened(0.5), STAND_IN_TINT)
	return {"crop": Rect2(at, Vector2(share, share)), "mirror": mirror, "tint": tint}


## A picture not painted yet: a soft field of the deck's own colors, seeded per card - a
## picture still arriving, never a gray broken plate - inside the window [param hole] when it has one.
static func _placeholder(ci: CanvasItem, r: Rect2, palette: Array, seed: int, hole := PackedVector2Array()) -> void:
	for piece in placeholder_pieces(r, palette, seed, hole):
		ci.draw_colored_polygon(piece[0], piece[1])


## [method _placeholder]'s field as `[[polygon, color], ...]`: the window filled, then soft discs cut to
## it. Only what can be drawn: a disc grazing a curved window (an oval) leaves a sliver of three points
## all but in a line, which the renderer cannot triangulate ("Invalid polygon data", 2026-10-08).
static func placeholder_pieces(r: Rect2, palette: Array, seed: int, hole := PackedVector2Array()) -> Array:
	if palette.is_empty():
		palette = CardTable.FALLBACK_PALETTE
	if hole.is_empty():
		hole = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var a := CardTable.color(String(palette[0])) if not palette.is_empty() else Color(0.2, 0.2, 0.3)
	var out: Array = [[hole, a.darkened(0.2)]]
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
				if drawable(piece):
					out.append([piece, c])
	return out


## Whether [param poly] can be drawn as a filled polygon: the renderer triangulates it as this does.
static func drawable(poly: PackedVector2Array) -> bool:
	return poly.size() >= 3 and not Geometry2D.triangulate_polygon(poly).is_empty()


## THE ORNAMENT ROUND THE CARD'S EDGE ([constant CardTable.ORNAMENTS]), along [method edge_path] - in the
## frame's ink and accent, on face and back alike.
static func ornament(ci: CanvasItem, look: Dictionary, ink: Color, accent: Color) -> void:
	var kind := ornament_of(look)
	if kind == "none":
		return
	var sz := Vector2(face_px(look))
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
## ornament round its edge ([constant CardTable.ORNAMENTS]) keeps a wider border for it: the ornament's
## line, its own width, then the frame's outermost rule ([method frame_reach]) - so the rules never crowd it.
## A BORDERLESS card's picture is the whole card, face and back: its type is set over it ([method type_boxes]).
static func window(back := false, look: Dictionary = {}) -> Rect2:
	var sz := Vector2(face_px(look))
	if borderless(look) or (back and CardTable.written(look)):
		return Rect2(Vector2.ZERO, sz)
	if CardTable.written(look):
		return sketch_rect(look)
	var m := sz.x * 0.06
	if ornament_of(look) != "none":
		m = sz.x * (ORNAMENT_INSET + ORNAMENT_BAND + frame_reach(look))
	var top := 0.0 if back else sz.y * 0.075
	var bottom := 0.0 if back else sz.y * 0.105
	return Rect2(Vector2(m, m + top), Vector2(sz.x - 2.0 * m, sz.y - 2.0 * m - top - bottom))


## THE ARCH ROUND A BACK'S DESIGN (feedback 0006: "that border should be shifted upward on the card, so that it's
## around the rectangular part"). A back's painting runs to the edges and keeps its own marks inside the middle
## four sixths ([code]cards/painter.back[/code]), its ornate rectangle among them, so the arch is fitted to
## that: its foot stands [constant BACK_PAD] under the painting's last sixth, and its springing line
## [constant BACK_PAD] above the first, the dome a shallower arch between there and [param win]'s top rather than a
## half circle that would cut the rectangle's corners. The painting keeps the scale it has in [param win] - only
## the frame and the cut move. Returns `{win, dome}`: the arch's box, and its dome's height for [method outline].
static func back_arch(look: Dictionary, win: Rect2) -> Dictionary:
	var sz := Vector2(face_px(look))
	var pad := sz.x * BACK_PAD
	var foot := minf(sz.y * 5.0 / 6.0 + pad, win.end.y)
	var spring := maxf(sz.y / 6.0 - pad, win.position.y)
	var half := win.size.x * 0.5 - win.size.x * 0.07
	var dome := clampf((spring - win.position.y) / half, 0.15, 1.0)
	return {"win": Rect2(win.position, Vector2(win.size.x, foot - win.position.y)), "dome": dome}


## How far the back's arch stands clear of the painting's middle four sixths (a share of the card's width).
const BACK_PAD := 0.012


## A card with details on its front reserves the lower part of the face for its printed text - a
## borderless one sets that text over its painting, which still fills the card.
static func front_window(look: Dictionary, details := false) -> Rect2:
	var full := window(false, look)
	if CardTable.written(look):
		return full
	return Rect2(full.position, Vector2(full.size.x, full.size.y * 0.48)) if details and not borderless(look) else full


## WHERE A WRITTEN CARD'S PICTURE SITS ([constant CardTable.SKETCHES]), pixels: a square in the top corner beside
## its title, or a band across its top.
static func sketch_rect(look: Dictionary) -> Rect2:
	var sz := Vector2(face_px(look))
	var m := minf(sz.x, sz.y) * WRITTEN_MARGIN
	var f: Dictionary = look.get("frame", {}) if look.get("frame") is Dictionary else {}
	if String(f.get("sketch", "corner")) == "band":
		return Rect2(m, m, sz.x - 2.0 * m, sz.y * 0.3)
	var side := minf(sz.x, sz.y) * SKETCH_SIDE
	return Rect2(sz.x - m - side, m, side, side)


## A written card's margin and its corner picture's side, shares of the card's short side.
const WRITTEN_MARGIN := 0.06
const SKETCH_SIDE := 0.36
## Its lines' pitch at the largest and the smallest, shares of the short side: the writing set as large as lets
## every line fit.
const PITCH := Vector2(0.115, 0.05)


## A WRITTEN CARD'S WRITING LAID OUT ([member Face.writing]): its title [param title] on the head line, and
## [param lines] each on a rule of its own, wrapped onto the next one, indented, where it runs long - beside a corner
## picture, a line stops short of it. As large as fits every line, from [constant PITCH]'s largest down; past its
## smallest, what does not fit is left off with an ellipsis. `{pitch, size, head, rules: [y], title: {at, size},
## rows: [{text, at}]}` - pixels, in [param font] at its hand's [param scale] ([constant CardTable.HANDS]).
static func written_layout(look: Dictionary, title: String, lines: PackedStringArray, font: Font, scale := 1.0) -> Dictionary:
	var sz := Vector2(face_px(look))
	var short := minf(sz.x, sz.y)
	var m := short * WRITTEN_MARGIN
	var pic := sketch_rect(look)
	var corner := pic.position.y <= m + 0.5 and pic.size.x < sz.x * 0.6
	var head := (m + short * 0.17) if corner else (pic.end.y + short * 0.13)
	var title_w := (pic.position.x - m * 1.5) if corner else (sz.x - 2.0 * m)
	var ts := mini(int(short * 0.1), _fit(font, title, int(short * 0.1), title_w))
	var out := {"head": head, "title": {"at": Vector2(m, head - font.get_descent(ts) - short * 0.012), "size": ts, "width": title_w}}
	var bottom := sz.y - m * 0.7
	var px := short * PITCH.x
	while true:
		var fs := int(px * 0.74 * scale)
		var indent := float(fs) * 0.9
		var rows: Array = []
		var y := head + px
		var fits := true
		for line in lines:
			var words := String(line).strip_edges().split(" ", false)
			var cur := ""
			var lead := 0.0
			var k := 0
			while fits and k <= words.size():
				# the rule's room: short of a corner picture beside it
				var right := (pic.position.x - m * 0.6) if corner and y - px * 0.25 < pic.end.y else (sz.x - m)
				if k < words.size():
					var next := words[k] if cur.is_empty() else cur + " " + words[k]
					if cur.is_empty() or font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= right - m - lead:
						cur = next
						k += 1
						continue
				if cur.is_empty():
					break
				if y > bottom:
					fits = false
					break
				rows.append({"text": cur, "at": Vector2(m + lead, y - px * 0.16)})
				y += px
				cur = ""
				lead = indent
				if k >= words.size():
					break
			if not fits:
				break
		if fits or px <= short * PITCH.y:
			if not fits and not rows.is_empty():
				(rows[rows.size() - 1] as Dictionary)["text"] = String((rows[rows.size() - 1] as Dictionary)["text"]) + " ..."
			var rules: Array = []
			var ry := head + px
			while ry <= bottom + 0.5:
				rules.append(ry)
				ry += px
			out["pitch"] = px
			out["size"] = fs
			out["rows"] = rows
			out["rules"] = rules
			return out
		px = maxf(short * PITCH.y, px - 1.0)
	return out


static func borderless(look: Dictionary) -> bool:
	var f: Dictionary = look.get("frame", {}) if look.get("frame") is Dictionary else {}
	return String(f.get("style", "")) == "borderless"


## Where a borderless card's type goes ([method type_boxes]): each band's top and foot as shares of the
## card's height, the type [constant TYPE_INSET] of its width in from each side; and its veil's reach
## past the type at full strength, and the fade beyond that (shares of the height).
const TYPE_INSET := 0.08
const NUMERAL_BAND := Vector2(0.03, 0.095)
const NAME_BAND := Vector2(0.885, 0.965)
const PANEL_BAND := Vector2(0.5, 0.965)
const VEIL_PAD := 0.012
const VEIL_FADE := 0.07
## The keyline round each letter set on a painting, a share of its size: the veil's color at full
## strength, so every stroke's edge stands on the stock however the painting shows through the veil.
const KEYLINE := 0.1


## A BORDERLESS CARD'S TYPE, set on its painting (pixels): `numeral`, a band at the top; `name`, a band at
## the foot; `panel`, its details over the lower half when the front prints them. Under each, a VEIL of
## the stock ([method CardTable.veil_alpha]) runs from the card's nearer edge to [constant VEIL_PAD] past
## the type at full strength, then fades into the painting over [constant VEIL_FADE] - the painting's own
## foot gone pale or dark, never a plate - and the type is fit to the width the veil runs (the old `bleed`
## fit its name wider than its plate, [constant CardTable.FRAMES]).
static func type_boxes(look: Dictionary) -> Dictionary:
	var sz := Vector2(face_px(look))
	var x := sz.x * TYPE_INSET
	var w := sz.x - 2.0 * x
	var out := {}
	for k in [["numeral", NUMERAL_BAND], ["name", NAME_BAND], ["panel", PANEL_BAND]]:
		var b: Vector2 = k[1]
		out[k[0]] = Rect2(x, sz.y * b.x, w, sz.y * (b.y - b.x))
	return out


## The largest size up to [param size] at which [param text] in [param font], ringed by its keyline
## ([constant KEYLINE]), fits inside [param box] - across it and from its ascent to its descent.
static func fit_box(font: Font, text: String, size: int, box: Rect2) -> int:
	var s := size
	while s > 10:
		var ring := keyline(s)
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x + ring <= box.size.x \
				and font.get_ascent(s) + font.get_descent(s) + ring <= box.size.y:
			break
		s -= 1
	return s


static func keyline(size: int) -> int:
	return maxi(2, roundi(float(size) * KEYLINE))


## THE PAINTING NO TYPE IS SET OVER (pixels): where the foil may key its highlights - the window, or on a
## borderless card what lies clear of its veils at their full strength ([method type_boxes]): a light
## ink's letters, keyed with the painting's highlights, glowed. [param numbered]: a numeral is printed;
## [param named]: a name is.
static func bare(look: Dictionary, details := false, numbered := false, named := true) -> Rect2:
	var win := front_window(look, details)
	if not borderless(look):
		return win
	var sz := Vector2(face_px(look))
	var boxes := type_boxes(look)
	var pad := sz.y * VEIL_PAD
	var top := (boxes["numeral"] as Rect2).end.y + pad if numbered else 0.0
	var foot := sz.y
	if details:
		foot = (boxes["panel"] as Rect2).position.y - pad
	elif named:
		foot = (boxes["name"] as Rect2).position.y - pad
	return Rect2(0.0, top, sz.x, foot - top)


## Where the ornament runs, this far in from the card's edge, and the room it takes itself (shares of the
## card's width).
const ORNAMENT_INSET := 0.045
const ORNAMENT_BAND := 0.04

## How far each frame style's outermost mark stands outside the picture's window (a share of the card's
## width, the stroke's own width included) - what [method Face._frame] draws, so the room kept round the
## window and the type set under it clears it. Keep each entry at or over what its branch draws.
const FRAME_REACH := {"line": 0.021, "double": 0.028, "corners": 0.039, "deco": 0.038, "borderless": 0.0}


static func frame_reach(look: Dictionary) -> float:
	var f: Dictionary = look.get("frame", {}) if look.get("frame") is Dictionary else {}
	return float(FRAME_REACH.get(String(f.get("style", "line")), FRAME_REACH["line"]))


static func ornament_of(look: Dictionary) -> String:
	var f: Dictionary = look.get("frame", {}) if look.get("frame") is Dictionary else {}
	return String(f.get("ornament", "none"))


static func window_of(look: Dictionary) -> String:
	var f: Dictionary = look.get("frame", {}) if look.get("frame") is Dictionary else {}
	return String(f.get("window", "rect"))


## THE WINDOW'S OUTLINE ([constant CardTable.WINDOWS]) round the picture's box [param r], grown outward by
## [param g] pixels - every rule of the frame is the same shape a little further out, so a grown outline is
## an offset of it, not the shape scaled. Closed, clockwise on screen, the first point not repeated.
## [param dome] is how tall an arch's dome stands, as a share of a half circle's height ([method back_arch]).
static func outline(shape: String, r: Rect2, g := 0.0, dome := 1.0) -> PackedVector2Array:
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
			var ry := (w * 0.5 - sh) * dome + g
			var ys := r.position.y + (w * 0.5 - sh) * dome
			pts.append(Vector2(x0, y1))
			pts.append(Vector2(x0, ys))
			pts.append(Vector2(x0 + sh, ys))
			for a in _arc(Vector2.ZERO, 1.0, PI, TAU, 40).slice(1, 40):
				pts.append(Vector2(rr.get_center().x + a.x * R, ys + a.y * ry))
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
	var sz := Vector2(face_px(look))
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
	var details := false
	## A BACK WITH THE CARD'S TEXT ON IT ([constant CardTable.TEXTS] `back`): [member card]'s booklet
	## printed in a panel over the printing's back, as a baseball card's stats are.
	var printed := false
	## A CARD NOBODY WROTE, printed as the others are ([member printed]): the panel's type ruled where a
	## name, a few facts and a paragraph would be set - the unseen cards in a box, whose backs have to be
	## the drawn cards' kind of back. [member card] carries only a `key`, which seeds the lines. On a
	## FRONT it is a card with no name to print: its band is left bare, its details ruled.
	var anonymous := false
	## THE PART OF [member art] THIS FACE SHOWS ([method CardFaces.stand_in]) when the picture is
	## another card's, standing in for one nobody painted - all of it when empty, as a drawn card's is.
	var part := {}
	var seed := 0

	func _draw() -> void:
		var sz := Vector2(CardFaces.face_px(look))
		var frame: Dictionary = look.get("frame", {})
		var style := String(frame.get("style", "line"))
		var stock := CardTable.color(String(frame.get("stock", "#efe6d2")))
		var ink := CardTable.color(String(frame.get("ink", "#1d1a2b")))
		var accent := CardTable.color(String(frame.get("accent", "#c9a227")))
		# the whole face is stock: the card's slab is cut to its corners ([method CardTable.corner_radius])
		draw_rect(Rect2(Vector2.ZERO, sz), stock)
		# A WRITTEN CARD is ruled first, its picture laid on the stock, its writing over the rules
		var written := CardTable.written(look) and not back
		var layout := {}
		if written:
			var wr := _writing_of()
			layout = CardFaces.written_layout(look, String(wr["title"]), wr["lines"], _hand(), float(_hand_row().get("scale", 1.0)))
			_ruling(layout, sz, accent)
		var win := CardFaces.window(true, look) if back else CardFaces.front_window(look, details)
		var shape := CardFaces.window_of(look)
		# a back's arch is fitted to its design ([method CardFaces.back_arch]); the painting stays as it lies in win
		var frame_win := win
		var dome := 1.0
		if back and shape == "arch" and not CardFaces.borderless(look):
			var fit := CardFaces.back_arch(look, win)
			frame_win = fit["win"]
			dome = fit["dome"]
		var hole := CardFaces.outline(shape, frame_win, 0.0, dome)
		if art != null:
			# a reversed card is printed the right way up: the TABLE turns it over
			CardFaces._cover_shape(self, art, win, hole, part)
		else:
			CardFaces._placeholder(self, win, look.get("palette", []),
				hash([seed, String(card.get("key", "back"))]), hole)
		# a borderless card is its painting: no rules round it, no ornament, its type set on it - and a written one
		# is its writing
		var bare_card := CardFaces.borderless(look)
		if not bare_card and not CardTable.written(look):
			_frame(style, shape, frame_win, ink, accent, sz, dome)
			CardFaces.ornament(self, look, ink, accent)
		if written:
			_writing(layout, ink, sz)
		elif details and not back:
			_printed_front(win, stock, ink, accent)
		elif not back and not anonymous:
			if bare_card:
				_painted_lettering(ink, stock, sz)
			else:
				_lettering(win, ink, sz)
		elif printed:
			_printed_back(win, stock, ink, accent)

	## WHAT A WRITTEN CARD SAYS: its designer's `writing` - its title and its lines - else its name, and its entry's
	## text a line to each line written.
	func _writing_of() -> Dictionary:
		var w: Dictionary = card.get("writing", {}) if card.get("writing") is Dictionary else {}
		var lines := PackedStringArray(DataPath.strings(w.get("lines", [])))
		if lines.is_empty() and card.get("booklet") is Dictionary:
			lines = String((card["booklet"] as Dictionary).get("upright", "")).split("\n", false)
		return {"title": String(w.get("title", card.get("name", ""))) if not anonymous else "", "lines": lines if not anonymous else PackedStringArray()}

	## The hand a written card is written in ([constant CardTable.HANDS]), its row and its font.
	func _hand_row() -> Dictionary:
		var f: Dictionary = look.get("frame", {}) if look.get("frame") is Dictionary else {}
		return CardTable.HANDS.get(String(f.get("hand", "neat")), CardTable.HANDS["neat"])

	func _hand() -> Font:
		return CardTable.font(String(_hand_row()["file"]))

	## A WRITTEN CARD'S STOCK, ruled ([constant CardTable.RULINGS]) to [param layout]'s pitch ([method
	## CardFaces.written_layout]): faint blue lines from edge to edge under a line of [param accent] below the title, or
	## graph paper's squares - or nothing, on plain stock.
	func _ruling(layout: Dictionary, sz: Vector2, accent: Color) -> void:
		var f: Dictionary = look.get("frame", {}) if look.get("frame") is Dictionary else {}
		var kind := String(f.get("ruling", "ruled"))
		if kind == "plain" or layout.is_empty():
			return
		var head := float(layout["head"])
		var px := float(layout["pitch"])
		var w := maxf(1.5, minf(sz.x, sz.y) * 0.003)
		if kind == "grid":
			var step := px * 0.5
			var x := fposmod(sz.x * 0.5, step)
			while x < sz.x:
				draw_line(Vector2(x, 0.0), Vector2(x, sz.y), Color(RULE_BLUE, 0.3), w * 0.6)
				x += step
			var y := fposmod(head, step)
			while y < sz.y:
				draw_line(Vector2(0.0, y), Vector2(sz.x, y), Color(RULE_BLUE, 0.3), w * 0.6)
				y += step
		else:
			for ry in layout["rules"]:
				draw_line(Vector2(0.0, float(ry)), Vector2(sz.x, float(ry)), RULE_BLUE, w)
		draw_line(Vector2(0.0, head), Vector2(sz.x, head), Color(accent, 0.85), w * 1.4)

	## An index card's blue.
	const RULE_BLUE := Color(0.42, 0.58, 0.82, 0.55)

	## A WRITTEN CARD'S WRITING, as [param layout] sets it, in [param ink] - or, on a card nobody wrote (one of a box's
	## own, [member anonymous]), ink scribbled where a title and a few lines would be.
	func _writing(layout: Dictionary, ink: Color, sz: Vector2) -> void:
		var hand := _hand()
		var t: Dictionary = layout["title"]
		if anonymous:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([seed, String(card.get("key", "")), "scribbles"])
			var px := float(layout["pitch"])
			var m := minf(sz.x, sz.y) * CardFaces.WRITTEN_MARGIN
			var scrawl := func(x0: float, x1: float, y: float, thick: float) -> void:
				var x := x0
				while x < x1 - thick:
					var run := minf(thick * rng.randf_range(2.0, 7.0), x1 - x)
					draw_rect(Rect2(x, y - thick, run, thick), Color(ink, 0.5))
					x += run + thick * 1.1
			scrawl.call(m, m + float(t["width"]) * rng.randf_range(0.4, 0.75), (t["at"] as Vector2).y, px * 0.2)
			var rules: Array = layout["rules"]
			for i in mini(rules.size(), rng.randi_range(3, maxi(3, rules.size()))):
				scrawl.call(m, sz.x * rng.randf_range(0.35, 0.85), float(rules[i]) - px * 0.2, px * 0.12)
			return
		draw_string(hand, t["at"], String(_writing_of()["title"]), HORIZONTAL_ALIGNMENT_LEFT, float(t["width"]), int(t["size"]), ink)
		for r in layout["rows"]:
			draw_string(hand, (r as Dictionary)["at"], String((r as Dictionary)["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(layout["size"]), ink)

	## THE PAINTING NO TYPE IS SET OVER on this front ([method CardFaces.bare]) - where foil may key it.
	func bare() -> Rect2:
		return CardFaces.bare(look, details, not anonymous and not String(card.get("numeral", "")).is_empty(), not anonymous)

	## The illustration and the card's facts share its front. The name and text are type, not
	## part of the generated picture, so they stay consistent across a printing.
	func _printed_front(win: Rect2, stock: Color, ink: Color, accent: Color) -> void:
		if CardFaces.borderless(look):
			# running text over the painting: a veil of the stock under the whole panel, planned for it
			var panel_box: Rect2 = CardFaces.type_boxes(look)["panel"]
			var v := CardTable.veil_of(ink, stock, CardTable.PANEL_CONTRAST, CardTable.PANEL_HEAVIEST)
			_veil(panel_box, v["veil"], v["alpha"])
			if not anonymous:
				_painted_numeral(ink, stock)
			_details(panel_box, v["ink"], accent)
			return
		var full := CardFaces.window(false, look)
		# the frame's rules stand outside the window: the type starts clear of them, not under them
		var reach := CardFaces.frame_reach(look) * float(CardFaces.face_px(look).x)
		var below := reach + 12.0
		var panel := Rect2(Vector2(win.position.x, win.end.y + below),
			Vector2(win.size.x, Vector2(CardFaces.face_px(look)).y - full.position.x - win.end.y - below))
		var text_ink := CardTable.legible_ink(ink, stock, CardTable.TEXT_CONTRAST)
		var number := String(card.get("numeral", ""))
		if not anonymous and not number.is_empty():
			var face := CardTable.font(String(look.get("title_face", "roman")))
			var w := panel.size.x - 24.0
			var num_size := CardFaces._fit(face, number, 34, w)
			draw_string(face, Vector2(panel.position.x + 12.0, full.position.y - below), number, HORIZONTAL_ALIGNMENT_CENTER, w,
				num_size, text_ink)
		_details(panel, text_ink, accent)

	## THE CARD'S FACTS in [param panel]: its name, a rule, its keywords and its text, as large as fits.
	func _details(panel: Rect2, text_ink: Color, accent: Color) -> void:
		var face := CardTable.font(String(look.get("title_face", "roman")))
		var book := CardTable.font(CardTable.BOOK_FACE)
		var italic := CardTable.font(CardTable.BOOK_ITALIC)
		var x := panel.position.x + 12.0
		var w := panel.size.x - 24.0
		var y := panel.position.y + 5.0
		if anonymous:
			_ruled_type(Rect2(x, y, w, panel.end.y - 5.0 - y), text_ink, accent)
			return
		var name := String(card.get("name", ""))
		var ns := CardFaces._fit(face, name, 42, w)
		y += face.get_ascent(ns)
		draw_string(face, Vector2(x, y), name, HORIZONTAL_ALIGNMENT_CENTER, w, ns, text_ink)
		y += face.get_descent(ns) + 10.0
		draw_line(Vector2(x, y), Vector2(x + w, y), accent, 2.0, true)
		y += 9.0
		var b: Dictionary = card.get("booklet", {}) if card.get("booklet") is Dictionary else {}
		var facts := DataPath.strings(b.get("keywords", [])).slice(0, 3)
		for fact in facts:
			var fs := CardFaces._fit(italic, String(fact), 24, w)
			y += italic.get_ascent(fs)
			draw_string(italic, Vector2(x, y), String(fact), HORIZONTAL_ALIGNMENT_LEFT, w, fs, text_ink)
			y += italic.get_descent(fs) + 3.0
		var body := String(b.get("upright", "")).strip_edges()
		if body.is_empty():
			return
		y += 6.0
		var room := panel.end.y - y - 5.0
		var size := 26
		while size > 13 and book.get_multiline_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, w, size).y > room:
			size -= 1
		draw_multiline_string(book, Vector2(x, y + book.get_ascent(size)), body,
			HORIZONTAL_ALIGNMENT_LEFT, w, size, -1, text_ink)

	## THE CARD'S TEXT ON ITS BACK: a panel of the card's stock over the back's design - its name, its
	## facts (the booklet's keywords) and its text, set to fill the panel.
	func _printed_back(win: Rect2, stock: Color, ink: Color, accent: Color) -> void:
		var panel := win.grow(-win.size.x * 0.07)
		# The reverse's printing replaces its artwork with paper. Keeping the dark
		# design under a translucent panel made long entries almost invisible in
		# candlelight, especially on dark stock.
		var paper := stock.lightened(0.8)
		CardFaces._box(self, panel, paper, win.size.x * 0.03)
		CardFaces._box(self, panel.grow(-6.0), accent, win.size.x * 0.025, false, 3.0)
		var text_ink := CardTable.legible_ink(ink, paper, CardTable.TEXT_CONTRAST)
		var face := CardTable.font(String(look.get("title_face", "roman")))
		var book := CardTable.font(CardTable.BOOK_FACE)
		var italic := CardTable.font(CardTable.BOOK_ITALIC)
		var m := panel.size.x * 0.08
		var x := panel.position.x + m
		var w := panel.size.x - 2.0 * m
		var y := panel.position.y + m
		if anonymous:
			_ruled_type(Rect2(x, y, w, panel.end.y - m - y), text_ink, accent)
			return
		var name := String(card.get("name", ""))
		var ns := CardFaces._fit(face, name, 46, w)
		y += face.get_ascent(ns)
		draw_string(face, Vector2(x, y), name, HORIZONTAL_ALIGNMENT_CENTER, w, ns, text_ink)
		y += face.get_descent(ns) + 8.0
		var b: Dictionary = card.get("booklet", {}) if card.get("booklet") is Dictionary else {}
		var kw := DataPath.strings(b.get("keywords", []))
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

	## TYPE NOBODY WROTE, in [param room]: ruled word by word where a printed back sets it - a centered
	## name, a few facts between the accent's rules, a paragraph ending on a short line.
	func _ruled_type(room: Rect2, ink: Color, accent: Color) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed, String(card.get("key", "")), "ruled type"])
		var x := room.position.x
		var w := room.size.x
		var y := room.position.y
		var words := func(from: float, to: float, top: float, thick: float) -> void:
			var cx := from
			while cx < to - thick:
				var run := minf(thick * rng.randf_range(1.5, 6.0), to - cx)
				draw_rect(Rect2(cx, top, run, thick), Color(ink, 0.55))
				cx += run + thick * 0.9
		var name_w := w * rng.randf_range(0.45, 0.85)
		words.call(x + (w - name_w) * 0.5, x + (w + name_w) * 0.5, y + 12.0, 20.0)
		y += 54.0
		draw_line(Vector2(x, y), Vector2(x + w, y), accent, 2.0, true)
		y += 14.0
		for i in rng.randi_range(2, 5):
			words.call(x, x + w * rng.randf_range(0.3, 0.75), y, 11.0)
			y += 30.0
		y += 2.0
		draw_line(Vector2(x, y), Vector2(x + w, y), accent, 2.0, true)
		y += 16.0
		var lines := mini(int((room.end.y - y) / 28.0), maxi(2, int((room.end.y - y) / 28.0 * rng.randf_range(0.55, 1.0))))
		for i in lines:
			words.call(x, x + w * (rng.randf_range(0.3, 0.8) if i == lines - 1 else 1.0), y, 10.0)
			y += 28.0

	## THE RULES ROUND THE PICTURE, in the window's own shape ([method CardFaces.outline]).
	func _frame(style: String, shape: String, win: Rect2, ink: Color, accent: Color, sz: Vector2, dome := 1.0) -> void:
		var r := sz.x * 0.02
		var line := func(g: float, col: Color, w: float) -> void:
			draw_polyline(CardFaces.closed(CardFaces.outline(shape, win, g, dome)), col, w, true)
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
				var o := CardFaces.outline(shape, win, off, dome)
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

	## A BORDERLESS CARD'S NAME AND NUMERAL, set on its painting ([method CardFaces.type_boxes]), each on a
	## veil of the stock planned for it ([method CardTable.veil_of]).
	func _painted_lettering(ink: Color, stock: Color, sz: Vector2) -> void:
		var face := CardTable.font(String(look.get("title_face", "roman")))
		var name := String(card.get("name", ""))
		if String(look.get("title_face", "roman")) in ["roman", "deco", "sign", "typed"]:
			name = name.to_upper()
		_painted_line(face, name, CardFaces.type_boxes(look)["name"], int(sz.y * 0.052), ink, stock)
		_painted_numeral(ink, stock)

	func _painted_numeral(ink: Color, stock: Color) -> void:
		var num := String(card.get("numeral", ""))
		if not num.is_empty():
			_painted_line(CardTable.font(String(look.get("title_face", "roman"))), num, CardFaces.type_boxes(look)["numeral"],
				int(float(CardFaces.face_px(look).y) * 0.045), ink, stock)

	## ONE LINE OF TYPE ON THE PAINTING, centered in [param band] as large as fits up to [param cap]: its
	## veil, then the keyline round its letters in the veil's color ([constant CardFaces.KEYLINE]), then the
	## letters - at [constant CardTable.TEXT_CONTRAST] against whatever the painting under them is.
	func _painted_line(face: Font, text: String, band: Rect2, cap: int, ink: Color, stock: Color) -> void:
		var v := CardTable.veil_of(ink, stock, CardTable.TEXT_CONTRAST, CardTable.VEIL_HEAVIEST)
		_veil(band, v["veil"], v["alpha"])
		var size := CardFaces.fit_box(face, text, cap, band)
		var at := Vector2(band.position.x, band.get_center().y + (face.get_ascent(size) - face.get_descent(size)) * 0.5)
		draw_string_outline(face, at, text, HORIZONTAL_ALIGNMENT_CENTER, band.size.x, size, CardFaces.keyline(size), v["veil"])
		draw_string(face, at, text, HORIZONTAL_ALIGNMENT_CENTER, band.size.x, size, v["ink"])

	## THE VEIL under [param band]: [param color] at [param alpha], across the whole card, from the card's
	## nearer edge to [constant CardFaces.VEIL_PAD] past the band - then eased out to nothing over
	## [constant CardFaces.VEIL_FADE], in strips whose edges carry a smoothstep's values.
	func _veil(band: Rect2, color: Color, alpha: float) -> void:
		var sz := Vector2(CardFaces.face_px(look))
		var pad := sz.y * CardFaces.VEIL_PAD
		var fade := sz.y * CardFaces.VEIL_FADE
		var at_top := band.get_center().y < sz.y * 0.5
		var edge := band.end.y + pad if at_top else band.position.y - pad
		var away := 1.0 if at_top else -1.0
		draw_rect(Rect2(0.0, 0.0, sz.x, edge) if at_top else Rect2(0.0, edge, sz.x, sz.y - edge), Color(color, alpha))
		var strips := 12
		for i in strips:
			var y0 := edge + away * fade * float(i) / float(strips)
			var y1 := edge + away * fade * float(i + 1) / float(strips)
			var c0 := Color(color, alpha * (1.0 - smoothstep(0.0, 1.0, float(i) / float(strips))))
			var c1 := Color(color, alpha * (1.0 - smoothstep(0.0, 1.0, float(i + 1) / float(strips))))
			draw_polygon(PackedVector2Array([Vector2(0.0, y0), Vector2(sz.x, y0), Vector2(sz.x, y1), Vector2(0.0, y1)]),
				PackedColorArray([c0, c0, c1, c1]))


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
		var kw := DataPath.strings(b.get("keywords", []))
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

	## How far a glyph's ink rises above its baseline (x) and hangs below it (y), per unit of font size.
	static func _ink_extent(font: Font, ch: String) -> Vector2:
		var rids := font.get_rids()
		if rids.is_empty() or ch.is_empty():
			return Vector2.ZERO
		var ts := TextServerManager.get_primary_interface()
		var gi := ts.font_get_glyph_index(rids[0], 100, ch.unicode_at(0), 0)
		var pts: PackedVector3Array = ts.font_get_glyph_contours(rids[0], 100, gi).get("points", PackedVector3Array())
		var lo := 0.0
		var hi := 0.0
		for p in pts:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
		return Vector2(-lo, hi) / 100.0

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
		var base := y + book.get_height(size) * 2.0 + book.get_ascent(size)
		# A capital that hangs below its baseline (J, Q) must not reach the fourth line: it is raised
		# by the overhang past the room under the third line and shrunk so its top stays put.
		var ext := _ink_extent(face, cap)
		if ext.y > 0.0:
			var room := maxf(book.get_height(size) - size * 0.75 - 2.0, 0.0)
			if ext.y * cs > room:
				var scaled := (ext.x * cs + room) / (ext.x + ext.y)
				base -= ext.y * scaled - room
				cs = int(scaled)
		var cw := face.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x + 12.0
		draw_string(face, Vector2(x, base), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, accent)
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
		if shown.size() % 2 == 1 and shown.size() > 1:
			shown = shown.slice(0, shown.size() - 1)  # two columns stay even
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
