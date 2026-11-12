extends RefCounted
class_name SheetWriting

## SheetWriting: words written on a sheet by the work ([constant Motions.LAWS] `write`) - a name on a slip, a label, a line on a page,
## written by an unseen pen as the act goes on. Nothing on a table carries words as it is set; the work writes them, when the script says
## so.
##
## In a recipe's own hand: the words are in one of [constant CardTable.HANDS] - the hands a written card is written in - written by a pen
## in that hand's strokes ([Handwriting], [method words]) and drawn on the processor ([method TableInk.picture_of_schedule]: no viewport
## and no renderer, so it is the same in a gate, a render and the app), into a picture whose red is the ink and whose green is when each
## point of it is put down, stroke by stroke as the hand writes - a pen seen follows the same strokes ([Pen]). A typewriter's words are
## set from the font's own glyphs instead ([method picture]), line by line, left to right. A thin
## skin over the sheet's top - bent and folded as the sheet is ([method Props.sheet_lift]) - shows that picture as far as the pen has got
## (`shaders/sheet_writing.gdshader`).
##
## A page, written a line at a time ([method page], next/proof.md): several writes on one sheet go one under another from its head, as
## lines on a page do, all at one size - words in the sheet's hand, and what TeX lays out ([TableInk]: a formula, a drawing, words with
## math) in the Hershey hand - so a lesson's working fills a page as it is done. Write K of N puts its ink down while the sheet's
## `written` goes from K/N to (K+1)/N ([method TableWork._order_writing]), its picture's time packed into that share, and the shader's pen
## front made N times as sharp to keep it a line. A page that would run off the sheet is written smaller to fit, and says so (`shrunk`):
## the next lines belong on another sheet.

const SHADER := preload("res://shaders/sheet_writing.gdshader")
## The share of a sheet's width and length kept clear round its words, and more for an outline that narrows at its ends
## (a leaf, an oval) than for one that does not.
const MARGIN := 0.12
const MARGIN_ROUND := 0.22
## The size the words are set at for their picture (pixels an em), and the space round them in it (pixels).
const PX := 96
const PAD := 6
## How far over the sheet's top the words lie (meters), and how finely the skin follows its bend.
const ABOVE := 0.00015
const GRID := Vector2i(16, 6)
## The most lines the words are broken into to suit the sheet's shape.
const MOST_LINES := 4
## Words a pen writes: a line's height against the hand's own (its reach above and below the line), the least it is (a TeX line,
## [constant TableInk.LINE_PT]), and the pixels a TeX point their picture on a sheet of its own is drawn at.
const WORDS_LEADING := 1.12
const WORDS_PX := 8.0
## How sharp the pen's front is in a sheet's `written` (the shader's `sharp`): a page's is this times its writes.
const SHARP := 100.0
## A page: the room between its writes (a share of a line), the largest a hand writes (meters a TeX point: a 15 pt line about 9 mm), and
## the most pixels a page's picture is on its longer side.
const PAGE_GAP := 0.45
const PAGE_MOST_SCALE := 0.0006
const PAGE_MOST_PX := 2048
## Writing smaller than this share of the page's own size is said to be shrunk to fit.
const SHRUNK_BY := 0.8
## How much taller a line of words in a hand is laid than TeX's line, so their letters stand as tall as TeX's on one page.
const WORDS_TALLER := 1.35
## A write's time, for a pen seen ([method TableWork._pen_nib]): the seconds it takes to come down to its first stroke, and to lift clear
## after its last, at the hand's own pace - the ink is put down between - and the seconds a hand takes over a letter of words.
const PEN_LEAD := 0.6
const PEN_TAIL := 0.45
const WORD_LETTER := 0.12


## The hand [param hand] ([constant CardTable.HANDS]) is written in by a pen ([Handwriting]), or "" for one that is set (a typewriter's).
static func stroke_hand(hand: String) -> String:
	return String((CardTable.HANDS.get(hand, CardTable.HANDS["neat"]) as Dictionary).get("strokes", ""))


## [param text] written by a pen in hand [param hand] (one [method stroke_hand] names), its own lines broken further at spaces - at
## [param width] TeX points where that is given, else into as many lines (up to [constant MOST_LINES]) as bring the whole nearest to
## [param aspect] wide for its height - each line [param centered] or from the left, [param step] TeX points apart (a page's rules;
## 0 for the hand's own), by the hand seeded [param seed]. `{strokes (the hand's schedule, [method Ink.schedule]: TeX points from
## the block's top left), seconds, size (TeX points), lines, ascent (the first line's baseline, down from the top)}`.
static func words(text: String, hand: String, seed: int, aspect := 1.0, width := 0.0, centered := false, step := 0.0) -> Dictionary:
	var h := Handwriting.of(stroke_hand(hand))
	var own := text.split("\n", false)
	if own.is_empty():
		own = PackedStringArray([" "])
	var lines := _wrapped_hand(own, h, width) if width > 0.0 else _broken_hand(own, h, aspect)
	var asc := Handwriting.ascent_px(h) / Handwriting.PX_PER_PT
	if step <= 0.0:
		step = _words_step(h)
	var made: Array = []
	var widths: Array = []
	var wide := 1.0
	for li in lines.size():
		var got := Handwriting.line(String(lines[li]).split(" ", false), [], seed, "sheet-%d" % li, h)
		made.append(got)
		widths.append(float(got["width"]))
		wide = maxf(wide, float(got["width"]))
	var strokes: Array = []
	for li in made.size():
		var off := Vector2((wide - float(widths[li])) * 0.5 if centered else 0.0, asc + step * float(li))
		for st in (made[li] as Dictionary)["strokes"]:
			var row: Dictionary = (st as Dictionary).duplicate()
			var pts := PackedVector2Array()
			for q in row["points"] as PackedVector2Array:
				pts.append(q + off)
			row["points"] = pts
			# (a word's place over the whole block, so the hand breathes between words and lines alike)
			row["k"] = li * 1000 + int(row.get("k", 0))
			strokes.append(row)
	var sched := Ink.schedule(strokes, seed)
	var tall := step * float(maxi(lines.size() - 1, 0)) + asc + Handwriting.descent_px(h) / Handwriting.PX_PER_PT
	return {"strokes": sched["strokes"], "length": float(sched["length"]), "seconds": maxf(float(sched["length"]), 1e-3),
		"size": Vector2(wide, tall), "lines": lines.size(), "ascent": asc}


## A line of words in hand [param h] ([Handwriting]): its reach above and below the line and a little room, never less than TeX's line.
static func _words_step(h: String) -> float:
	return maxf(TableInk.LINE_PT, (Handwriting.ascent_px(h) + Handwriting.descent_px(h)) / Handwriting.PX_PER_PT * WORDS_LEADING)


## The lines [param own] is written in by hand [param h]: each broken at spaces into as many (up to [constant MOST_LINES] in all) as
## bring the whole nearest to [param aspect] wide for its height.
static func _broken_hand(own: PackedStringArray, h: String, aspect: float) -> PackedStringArray:
	var total := 0.0
	for line in own:
		total += _hand_width(String(line), h)
	var best := own
	var best_off := INF
	for n in range(own.size(), MOST_LINES + 1):
		var lines := _wrapped_hand(own, h, total / float(n) * 1.08)
		if lines.size() != n and n > own.size():
			continue
		var wide := 0.0
		for line in lines:
			wide = maxf(wide, _hand_width(String(line), h))
		var off := absf(log(maxf(wide, 1.0) / (_words_step(h) * float(lines.size())) / maxf(aspect, 1e-3)))
		if off < best_off:
			best_off = off
			best = lines
	return best


## [param own] lines broken at spaces so none runs past [param width] TeX points in hand [param h] (a word longer than that stands alone).
static func _wrapped_hand(own: PackedStringArray, h: String, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	for line in own:
		var cur := ""
		for word in String(line).split(" ", false):
			var next := word if cur.is_empty() else cur + " " + word
			if not cur.is_empty() and _hand_width(next, h) > width:
				out.append(cur)
				cur = word
			else:
				cur = next
		out.append(cur)
	return out


## How wide [param line] is written in hand [param h] (TeX points): its words' advances and the spaces between.
static func _hand_width(line: String, h: String) -> float:
	var words := line.split(" ", false)
	var w := 0.0
	for word in words:
		w += Handwriting.advance(String(word), h)
	return w + Handwriting.space(h) * float(maxi(words.size() - 1, 0))


## The words' picture in a hand that is set, never written (a typewriter's, [method stroke_hand] ""): [param text] (lines split by
## "\n", and broken further at spaces to suit a box [param aspect] wide for its height) in hand [param hand] ([constant
## CardTable.HANDS]): R the ink's coverage, G when it is put down, line by line, left to right.
static func picture(text: String, hand: String, aspect: float) -> Image:
	var row: Dictionary = CardTable.HANDS.get(hand, CardTable.HANDS["neat"])
	var font: FontFile = load(String(row["file"]))
	var px := int(round(float(PX) * float(row.get("scale", 1.0))))
	var ts := TextServerManager.get_primary_interface()
	var lines := _broken(text, font, px, aspect)
	var shaped: Array = []
	var width := 1.0
	var ascent := 0.0
	var descent := 0.0
	for line in lines:
		var sid := ts.create_shaped_text()
		ts.shaped_text_add_string(sid, String(line), font.get_rids(), px)
		shaped.append(sid)
		width = maxf(width, ts.shaped_text_get_width(sid))
		ascent = maxf(ascent, ts.shaped_text_get_ascent(sid))
		descent = maxf(descent, ts.shaped_text_get_descent(sid))
	var step := ascent + descent
	var img := Image.create(int(ceil(width)) + PAD * 2, int(ceil(step * lines.size())) + PAD * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 1.0))
	for li in shaped.size():
		var sid: RID = shaped[li]
		var line_w := maxf(ts.shaped_text_get_width(sid), 1.0)
		var pen := float(PAD) + (width - line_w) * 0.5
		var base := float(PAD) + step * float(li) + ascent
		for g in ts.shaped_text_get_glyphs(sid):
			var gd: Dictionary = g
			var rid: RID = gd["font_rid"]
			var size := Vector2i(int(gd["font_size"]), 0)
			var idx := int(gd["index"])
			ts.font_render_glyph(rid, size, idx)
			var ti := ts.font_get_glyph_texture_idx(rid, size, idx)
			if ti >= 0:
				var uv := ts.font_get_glyph_uv_rect(rid, size, idx)
				var cache := ts.font_get_texture_image(rid, size, ti)
				var at := Vector2(pen, base) + ts.font_get_glyph_offset(rid, size, idx) + (gd["offset"] as Vector2)
				for yy in int(uv.size.y):
					for xx in int(uv.size.x):
						var x := int(at.x) + xx
						var y := int(at.y) + yy
						if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
							continue
						var cov := cache.get_pixel(int(uv.position.x) + xx, int(uv.position.y) + yy).a
						if cov <= 0.0:
							continue
						# put down line by line, left to right along the line - the last point at 0.98, so all of it is
						# written by the pen's end
						var when := (float(li) + clampf((float(x) - (float(PAD) + (width - line_w) * 0.5)) / line_w, 0.0, 1.0)) / float(lines.size()) * 0.98
						var was := img.get_pixel(x, y)
						img.set_pixel(x, y, Color(maxf(was.r, cov), when if was.r <= 0.0 else minf(was.g, when), 0.0, 1.0))
			pen += float(gd["advance"])
		ts.free_rid(sid)
	img.generate_mipmaps()
	return img


## The lines [param text] is written in: its own, each broken at spaces into as many (up to [constant MOST_LINES] in all)
## as bring the whole nearest to [param aspect] wide for its height.
static func _broken(text: String, font: FontFile, px: int, aspect: float) -> PackedStringArray:
	var own := text.split("\n", false)
	if own.is_empty():
		return PackedStringArray([" "])
	var height := font.get_height(px)
	var best := own
	var best_off := INF
	for n in range(own.size(), MOST_LINES + 1):
		var lines := _wrapped(own, font, px, n)
		if lines.size() != n and n > own.size():
			continue
		var wide := 0.0
		for line in lines:
			wide = maxf(wide, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
		var off := absf(log(maxf(wide, 1.0) / (height * float(lines.size())) / maxf(aspect, 1e-3)))
		if off < best_off:
			best_off = off
			best = lines
	return best


## [param own] lines broken at spaces into about [param n] lines in all, the longest broken first.
static func _wrapped(own: PackedStringArray, font: FontFile, px: int, n: int) -> PackedStringArray:
	var total := 0.0
	for line in own:
		total += font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var target := total / float(n)
	var out := PackedStringArray()
	for line in own:
		var cur := ""
		for word in line.split(" ", false):
			var next := word if cur.is_empty() else cur + " " + word
			if not cur.is_empty() and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > target * 1.08:
				out.append(cur)
				cur = word
			else:
				cur = next
		out.append(cur)
	return out


## The words on sheet [param sheet] ([method Props.sheet_top]), in [param hand] and [param ink]: a skin over its top, in the space the
## sheet was built in, its [code]written[/code] how far the pen has got (0 at first).
static func node(sheet: Dictionary, text: String, hand: String, ink: Color, seed := 1) -> MeshInstance3D:
	var w := float(sheet["w"])
	var l := float(sheet["l"])
	var margin := MARGIN if String(sheet.get("outline", "")) in ["rect", "points"] else MARGIN_ROUND
	var room := Vector2(w * (1.0 - 2.0 * margin), l * (1.0 - 2.0 * margin))
	var img: Image
	if stroke_hand(hand).is_empty():
		img = picture(text, hand, room.x / maxf(room.y, 1e-6))
	else:
		var got := words(text, hand, seed, room.x / maxf(room.y, 1e-6), 0.0, true)
		var size: Vector2 = got["size"]
		img = TableInk.picture_of_schedule(got, size, 0.0, minf(WORDS_PX, float(PAGE_MOST_PX) / maxf(size.x, size.y)))
		img.generate_mipmaps()
	var aspect := float(img.get_width()) / float(img.get_height())
	var box := Vector2(room.x, room.x / aspect) if aspect > room.x / maxf(room.y, 1e-6) else Vector2(room.y * aspect, room.y)
	var x0 := float(sheet["x0"]) - box.x * 0.5
	var z0 := float(sheet["z0"]) + l * 0.5 - box.y * 0.5
	var bend := float(sheet["bend"])
	var fold := float(sheet["fold"])
	var thick := float(sheet["thick"])
	var place: Transform3D = sheet["place"]
	var top := func(x: float, z: float) -> Vector3:
		return Vector3(x, thick + ABOVE + Props.sheet_lift(x - float(sheet["x0"]), z - float(sheet["z0"]), w, l, bend, fold), z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in GRID.y:
		for i in GRID.x:
			var corners: Array = []
			for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var u := float(q[0]) / float(GRID.x)
				var v := float(q[1]) / float(GRID.y)
				var x := x0 + u * box.x
				var z := z0 + v * box.y
				var p: Vector3 = top.call(x, z)
				var n: Vector3 = ((top.call(x, z + 0.001) as Vector3) - (top.call(x, z - 0.001) as Vector3)).cross(
					(top.call(x + 0.001, z) as Vector3) - (top.call(x - 0.001, z) as Vector3)).normalized()
				corners.append([place * p, (place.basis * n).normalized(), Vector2(u, v)])
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(corners[k][1])
				st.set_uv(corners[k][2])
				st.add_vertex(corners[k][0])
	var mesh := MeshInstance3D.new()
	mesh.name = "written"
	mesh.mesh = st.commit()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("words", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("ink", ink)
	mat.set_shader_parameter("written", 0.0)
	mesh.material_override = mat
	return mesh


## The room a sheet's writing has (meters, across and down the sheet): the sheet less its margins.
static func room_of(sheet: Dictionary) -> Vector2:
	var w := float(sheet["w"])
	var l := float(sheet["l"])
	var margin := MARGIN if String(sheet.get("outline", "")) in ["rect", "points"] else MARGIN_ROUND
	return Vector2(w * (1.0 - 2.0 * margin), l * (1.0 - 2.0 * margin))


## A page of writes (see the class note): [param items] in the order they are written - each `{text, hand}` for words in a hand, or
## `{rec}` for TeX's record of a formula, a drawing or words with math ([method TableInk.record_in]) - laid one under another from the
## head of a room [param room] (meters) and written by the hand seeded [param seed] ([param outlines] the ink's `fonts`).
## `{image, sharp, shrunk, missing, layout}`: R the ink, G when it is put down - item K of N in K/N to (K+1)/N, its ink between its lead
## and its tail ([constant PEN_LEAD], [constant PEN_TAIL]). `layout` is where everything is, for a pen seen and for what points
## ([method TableWork._pen_nib], [method TableWork._point_nib]): `{scale (meters a point), pt (the page's size in points), items: [{x, y,
## w, h (its box), ox, oy (a record's origin: x 0 on its baseline), strokes, seconds, lead, ink (its time's shares), lines (words'),
## anchors ({name: Rect2}, the page's points)}]}`.
static func page(items: Array, room: Vector2, seed: int, outlines: Dictionary = {}) -> Dictionary:
	var n := maxi(items.size(), 1)
	# each item's size in TeX points: TeX's own for a record; words a pen writes, their strokes' ([method words]); a typewriter's, their
	# picture, a line of it a line's height
	var sizes: Array = []
	var typed: Array = []
	var written: Array = []
	var widest := TableInk.PAD_WIDTH
	var tall := 0.0
	for it in items:
		var d: Dictionary = it
		var sz := Vector2(TableInk.PAD_WIDTH, TableInk.LINE_PT)
		var said: Image = null
		if d.has("strike"):
			# (a line crossed out takes no room of its own: it is drawn through the line it strikes)
			sizes.append(Vector2.ZERO)
			typed.append(null)
			written.append({})
			continue
		var hw: Dictionary = {}
		if d.get("rec") is Dictionary and not (d["rec"] as Dictionary).is_empty():
			sz = TableInk.size_of(d["rec"])
		elif not stroke_hand(String(d.get("hand", "neat"))).is_empty():
			# words a pen writes: in the hand's strokes, wrapped at a page's width
			hw = words(String(d.get("text", " ")), String(d.get("hand", "neat")), seed, 1.0, TableInk.PAD_WIDTH)
			sz = hw["size"]
		else:
			var text := String(d.get("text", " "))
			var lines := _broken(text, _font_of(String(d.get("hand", "neat"))), PX, TableInk.PAD_WIDTH / TableInk.LINE_PT)
			said = picture(text, String(d.get("hand", "neat")), TableInk.PAD_WIDTH / TableInk.LINE_PT)
			# (a hand's picture carries its ascent, descent and margin: its words come out as tall as TeX's at this share more)
			var h := TableInk.LINE_PT * WORDS_TALLER * float(maxi(lines.size(), 1))
			sz = Vector2(h * float(said.get_width()) / float(maxi(said.get_height(), 1)), h)
		sizes.append(sz)
		typed.append(said)
		written.append(hw)
		widest = maxf(widest, sz.x)
		tall += sz.y + (TableInk.LINE_PT * PAGE_GAP if sizes.size() > 1 else 0.0)
	# One size for the page: as wide as its widest line, no larger than a hand writes - and smaller, said, when it runs off
	var natural := minf(room.x / widest, PAGE_MOST_SCALE)
	var scale := minf(natural, room.y / maxf(tall, 1.0))
	var shrunk := scale < natural * SHRUNK_BY
	var pt := room / scale
	var px := minf(4.0, float(PAGE_MOST_PX) / maxf(pt.x, pt.y))
	var img := Image.create(maxi(int(ceil(pt.x * px)), 2), maxi(int(ceil(pt.y * px)), 2), false, Image.FORMAT_RGBAH)
	img.fill(Color(0.0, 1.0, 0.0, 1.0))
	var missing := PackedStringArray()
	var laid: Array = []
	var y := 0.0
	for k in items.size():
		var d: Dictionary = items[k]
		# A line crossed out: a stroke of the hand through an earlier line, drawn straight onto the page in its own share of time
		if d.has("strike"):
			laid.append(_strike(img, laid, int(d["strike"]), px, k, n, seed))
			continue
		var part: Image
		var rec: Dictionary = d["rec"] if d.get("rec") is Dictionary else {}
		var seconds := 0.0
		var strokes: Array = []
		if not rec.is_empty():
			var got := TableInk.picture_of(rec, seed, px, outlines)
			part = got["image"]
			missing.append_array(got["missing"])
			seconds = float(got["seconds"])
			strokes = got["strokes"]
		elif not (written[k] as Dictionary).is_empty():
			var hw: Dictionary = written[k]
			part = TableInk.picture_of_schedule(hw, hw["size"], 0.0, px)
			seconds = float(hw["seconds"])
			strokes = hw["strokes"]
		else:
			part = typed[k]
			part.clear_mipmaps()
			part.convert(Image.FORMAT_RGBAH)
			part.resize(maxi(int(round((sizes[k] as Vector2).x * px)), 1), maxi(int(round((sizes[k] as Vector2).y * px)), 1), Image.INTERPOLATE_BILINEAR)
			seconds = maxf(1.0, float(String(d.get("text", "")).strip_edges().length()) * WORD_LETTER)
		# a drawing stands in the middle of its line, words and formulas at its start
		var x0 := int(round((pt.x - float(part.get_width()) / px) * 0.5 * px)) if bool(rec.get("figure", false)) else 0
		var total := PEN_LEAD + seconds + PEN_TAIL
		var lead := PEN_LEAD / total
		var ink := seconds / total
		_blit(img, part, Vector2i(x0, int(round(y * px))), float(k) / float(n), 1.0 / float(n), lead, ink)
		# ...and where it is, for a pen seen and for what points at it
		var at := {"x": float(x0) / px, "y": y, "w": float(part.get_width()) / px, "h": (sizes[k] as Vector2).y, "strokes": strokes,
			"seconds": seconds, "lead": lead, "ink": ink, "lines": maxi(int(round((sizes[k] as Vector2).y / (TableInk.LINE_PT * WORDS_TALLER))), 1),
			"anchors": {}}
		if not (written[k] as Dictionary).is_empty():
			# (a pen's words: their strokes from the block's top left)
			at["ox"] = float(x0) / px + float(TableInk.PAD_PX) / px
			at["oy"] = y + float(TableInk.PAD_PX) / px
		if not rec.is_empty():
			at["ox"] = float(x0) / px + float(TableInk.PAD_PX) / px
			at["oy"] = y + float(TableInk.PAD_PX) / px + float(rec.get("h", 0.0))
			var named: Dictionary = rec.get("anchors", {}) if rec.get("anchors") is Dictionary else {}
			for nm in named:
				var b: Variant = named[nm]
				if b is Array and (b as Array).size() == 4:
					(at["anchors"] as Dictionary)[String(nm)] = Rect2(float(at["ox"]) + float(b[0]), float(at["oy"]) + float(b[1]),
						float(b[2]) - float(b[0]), float(b[3]) - float(b[1]))
		laid.append(at)
		y += (sizes[k] as Vector2).y + TableInk.LINE_PT * PAGE_GAP
	img.generate_mipmaps()
	return {"image": img, "sharp": SHARP * float(n), "shrunk": shrunk, "missing": missing,
		"layout": {"scale": scale, "pt": pt, "items": laid}}


## How fast a hand crosses a line out, against its writing speed ([constant Ink.PEN_SPEED]), and how far past the line's ends it runs
## (TeX points).
const STRIKE_SPEED := 2.2
const STRIKE_PAST := 2.0


## Line [param target] of [param laid] crossed out on [param img] ([param px] pixels a point) as item [param k] of [param n]: a slightly
## uneven stroke through the middle of its box, drawn at a hand's pace in that item's share of the page's time - and its layout entry, its
## stroke for a pen seen to follow. A target that is not an earlier line strikes nothing.
static func _strike(img: Image, laid: Array, target: int, px: float, k: int, n: int, seed: int) -> Dictionary:
	var none := {"x": 0.0, "y": 0.0, "w": 0.0, "h": 0.0, "strokes": [], "seconds": 0.0, "lead": 0.0, "ink": 0.0, "lines": 1, "anchors": {}}
	if target < 0 or target >= laid.size() or float((laid[target] as Dictionary)["w"]) <= 0.0:
		return none
	var b: Dictionary = laid[target]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["desk-ink-strike", seed, k])
	var y0 := float(b["y"]) + float(b["h"]) * rng.randf_range(0.45, 0.6)
	var y1 := float(b["y"]) + float(b["h"]) * rng.randf_range(0.4, 0.55)
	var pts := PackedVector2Array()
	for i in 13:
		var f := float(i) / 12.0
		pts.append(Vector2(lerpf(float(b["x"]) - STRIKE_PAST, float(b["x"]) + float(b["w"]) + STRIKE_PAST, f),
			lerpf(y0, y1, f) + sin(f * PI * 2.0 + rng.randf() * 0.5) * 0.6))
	var length := 0.0
	for i in range(1, pts.size()):
		length += pts[i - 1].distance_to(pts[i])
	var seconds := length / (Ink.PEN_SPEED * STRIKE_SPEED)
	var total := PEN_LEAD + seconds + PEN_TAIL
	var lead := PEN_LEAD / total
	var ink := seconds / total
	var base := float(k) / float(n)
	var share := 1.0 / float(n)
	var r := maxf(0.62 * px * 0.5, 0.6)
	var at := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		var wa := base + (lead + at / length * ink) * share
		at += seg
		var wb := base + (lead + at / length * ink) * share
		TableInk._segment(img, pts[i - 1] * px, pts[i] * px, r, wa, wb, 1.0)
	return {"x": float(b["x"]), "y": float(b["y"]), "w": float(b["w"]), "h": float(b["h"]), "ox": 0.0, "oy": 0.0,
		"strokes": [{"points": pts, "t0": 0.0, "t1": seconds}], "seconds": seconds, "lead": lead, "ink": ink, "lines": 1, "anchors": {}}


## [param part]'s ink laid onto [param img] at [param at], its time put into [param base] + [param share] of the page's - the part's own
## 0 to 0.98 into the [param ink] share of that after the [param lead] share.
static func _blit(img: Image, part: Image, at: Vector2i, base: float, share: float, lead := 0.0, ink := 1.0) -> void:
	for yy in part.get_height():
		var y := at.y + yy
		if y < 0 or y >= img.get_height():
			continue
		for xx in part.get_width():
			var x := at.x + xx
			if x < 0 or x >= img.get_width():
				continue
			var c := part.get_pixel(xx, yy)
			if c.r <= 0.0:
				continue
			var was := img.get_pixel(x, y)
			var when := base + (lead + clampf(c.g, 0.0, 0.98) / 0.98 * ink) * share
			img.set_pixel(x, y, Color(maxf(was.r, c.r), minf(was.g, when), 0.0, 1.0))


static func _font_of(hand: String) -> FontFile:
	var row: Dictionary = CardTable.HANDS.get(hand, CardTable.HANDS["neat"])
	return load(String(row["file"]))


## The page on sheet [param sheet] ([method Props.sheet_top]): a skin over the whole of its room, showing [param pic] ([method page]'s
## answer) in [param ink], its [code]written[/code] how far the pen has got (0 at first).
static func page_node(sheet: Dictionary, pic: Dictionary, ink: Color) -> MeshInstance3D:
	var w := float(sheet["w"])
	var l := float(sheet["l"])
	var box := room_of(sheet)
	var x0 := float(sheet["x0"]) - box.x * 0.5
	var z0 := float(sheet["z0"]) + l * 0.5 - box.y * 0.5
	var bend := float(sheet["bend"])
	var fold := float(sheet["fold"])
	var thick := float(sheet["thick"])
	var place: Transform3D = sheet["place"]
	var top := func(x: float, z: float) -> Vector3:
		return Vector3(x, thick + ABOVE + Props.sheet_lift(x - float(sheet["x0"]), z - float(sheet["z0"]), w, l, bend, fold), z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in GRID.y:
		for i in GRID.x:
			var corners: Array = []
			for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var u := float(q[0]) / float(GRID.x)
				var v := float(q[1]) / float(GRID.y)
				var p: Vector3 = top.call(x0 + u * box.x, z0 + v * box.y)
				var nrm: Vector3 = ((top.call(x0 + u * box.x, z0 + v * box.y + 0.001) as Vector3) - (top.call(x0 + u * box.x, z0 + v * box.y - 0.001) as Vector3)).cross(
					(top.call(x0 + u * box.x + 0.001, z0 + v * box.y) as Vector3) - (top.call(x0 + u * box.x - 0.001, z0 + v * box.y) as Vector3)).normalized()
				corners.append([place * p, (place.basis * nrm).normalized(), Vector2(u, v)])
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(corners[k][1])
				st.set_uv(corners[k][2])
				st.add_vertex(corners[k][0])
	var mesh := MeshInstance3D.new()
	mesh.name = "written"
	mesh.mesh = st.commit()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("words", ImageTexture.create_from_image(pic["image"]))
	mat.set_shader_parameter("ink", ink)
	mat.set_shader_parameter("written", 0.0)
	mat.set_shader_parameter("sharp", float(pic.get("sharp", SHARP)))
	mesh.material_override = mat
	return mesh
