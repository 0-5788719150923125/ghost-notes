extends RefCounted
class_name SheetWriting

## SheetWriting - WORDS WRITTEN ON A SHEET by the work ([constant Motions.LAWS] `write`): a name on a slip, a label, a line
## on a page, written by an unseen pen as the act goes on.
##
## The user, 2026-10-29, of the-quiet-crucible 707668's poison "name on a slip": "a little white square kind of looks like
## nothing ... The slip should show writing, if the script says it should". Nothing on a table carries words as it is set;
## the work writes them, when the script says so.
##
## IN A RECIPE'S OWN HAND: the words are set in one of [constant CardTable.HANDS] - the hands a written card is written in -
## and drawn on the processor from the font's own glyphs ([method picture]: no viewport and no renderer, so it is the same
## in a gate, a render and the app), into a picture whose red is the ink and whose green is when each point of it is put
## down: line by line, left to right. A thin skin over the sheet's top - bent and folded as the sheet is
## ([method Props.sheet_lift]) - shows that picture as far as the pen has got (`shaders/sheet_writing.gdshader`).

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


## THE WORDS' PICTURE: [param text] (lines split by "\n", and broken further at spaces to suit a box [param aspect] wide
## for its height) in hand [param hand] ([constant CardTable.HANDS]): R the ink's coverage, G when it is put down.
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


## THE WORDS ON SHEET [param sheet] ([method Props.sheet_top]), in [param hand] and [param ink]: a skin over its top, in the
## space the sheet was built in, its [code]written[/code] how far the pen has got (0 at first).
static func node(sheet: Dictionary, text: String, hand: String, ink: Color) -> MeshInstance3D:
	var w := float(sheet["w"])
	var l := float(sheet["l"])
	var margin := MARGIN if String(sheet.get("outline", "")) in ["rect", "points"] else MARGIN_ROUND
	var room := Vector2(w * (1.0 - 2.0 * margin), l * (1.0 - 2.0 * margin))
	var img := picture(text, hand, room.x / maxf(room.y, 1e-6))
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
