extends SceneTree

## Does "repaint" replace the keyed color with the color asked for, and does "erase" do what it claims
## (which is not the same thing)?
##   godot --path . --script res://tests/masking/repaint_check.gd
## NOT --headless: the dummy renderer returns no viewport image, so a readback check has to run on a real
## GPU (a small window flashes for a second).
##
## - erase subtracts the target's chroma and the light it carried: the keyed color loses its chroma and
##   ends neutral-ish and darker; it is not expected to reach the paint color.
## - repaint lands the keyed color on the chosen color (black means black).
##
## The swatches are graded by how related they are to the key:
## - MEMBER: the wall itself, in three lightings. Both effects act, fully.
## - ADJACENT: skin, 28 degrees off the wall's hue. Erase is gate-free and takes some of it; repaint must
##   not (a replacement is all-or-nothing), which is why repaint selects on an angular cone instead of
##   the raw projection erase uses (see the shader branch).
## - UNRELATED: blue and neutral gray. Nothing may touch these.

const W := 64
const H := 96
const KEY_HUE := 0.1236   # the yellow of a lit interior wall, off a real frame

const MEMBER := 0
const ADJACENT := 1
const UNRELATED := 2

const SWATCHES := [
	["yellow wall (lit)", Color(0.85, 0.72, 0.35), MEMBER],
	["yellow wall (shadowed)", Color(0.42, 0.36, 0.18), MEMBER],
	["yellow wall (washed out)", Color(0.86, 0.82, 0.68), MEMBER],
	["skin", Color(0.78, 0.58, 0.47), ADJACENT],
	["blue shirt", Color(0.20, 0.28, 0.62), UNRELATED],
	["neutral gray", Color(0.50, 0.50, 0.50), UNRELATED],
]

var _fails: PackedStringArray = []


func _initialize() -> void:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	for s in SWATCHES.size():
		for y in range(_band(s), _band(s + 1)):
			for x in W:
				img.set_pixel(x, y, SWATCHES[s][1])
	var tex := ImageTexture.create_from_image(img)

	# Repaint to black (h any, s 0, v 0) at full Reach.
	var painted := await _render(tex, MaskSession.EFFECT_REPAINT, {
		"accent": 0.0, "stick": 0.0, "tint": 0.0, "con": 0.5})
	var erased := await _render(tex, 0, {"accent": 0.0, "stick": 0.0, "tint": 0.0, "con": 0.5})
	# And to a saturated green, so "it just darkens things" cannot pass.
	var greened := await _render(tex, MaskSession.EFFECT_REPAINT, {
		"accent": 0.3333, "stick": 1.0, "tint": 0.85, "con": 0.5})

	print("")
	print("%-26s %-20s %-20s %-20s %s"
		% ["swatch", "source", "erase", "repaint->black", "repaint->green"])
	for s in SWATCHES.size():
		var src: Color = SWATCHES[s][1]
		var e := _sample(erased, s)
		var b := _sample(painted, s)
		var g := _sample(greened, s)
		print("%-26s %-20s %-20s %-20s %s"
			% [SWATCHES[s][0], _fmt(src), _fmt(e), _fmt(b), _fmt(g)])
		match int(SWATCHES[s][2]):
			MEMBER:
				# Switch: the wall must reach the paint, in every lighting.
				_expect(_dist(b, Color(0, 0, 0)) < 0.16,
					"%s: repaint->black left it at %s - the paint did not land"
					% [SWATCHES[s][0], _fmt(b)])
				_expect(_dist(g, Color(0.13, 0.85, 0.13)) < 0.30,
					"%s: repaint->green left it at %s - the paint did not land"
					% [SWATCHES[s][0], _fmt(g)])
				# ...and erase does its own, different thing: kills the chroma.
				_expect(_chroma(e) < _chroma(src) * 0.55,
					"%s: erase left %.3f of the %.3f chroma it was asked to subtract"
					% [SWATCHES[s][0], _chroma(e), _chroma(src)])
			ADJACENT:
				# Repaint holds off almost entirely; erase is allowed its share, but must be gentler here than on
				# the wall itself.
				_expect(_dist(b, src) < 0.12,
					"%s: repaint->black moved it to %s - the cone is too wide, " % [SWATCHES[s][0], _fmt(b)]
					+ "this is the face beside the wall")
				_expect(_dist(g, src) < 0.12,
					"%s: repaint->green moved it to %s - the cone is too wide, " % [SWATCHES[s][0], _fmt(g)]
					+ "this is the face beside the wall")
				_expect(_chroma(e) > _chroma(src) * 0.45,
					"%s: erase took %.3f of its %.3f chroma - that is wall-grade "
					% [SWATCHES[s][0], _chroma(src) - _chroma(e), _chroma(src)]
					+ "subtraction on something only adjacent to the key")
			UNRELATED:
				# Hold: nothing that shares no component with the key may move.
				_expect(_dist(b, src) < 0.03,
					"%s: repaint->black moved it to %s" % [SWATCHES[s][0], _fmt(b)])
				_expect(_dist(g, src) < 0.03,
					"%s: repaint->green moved it to %s" % [SWATCHES[s][0], _fmt(g)])
				_expect(_dist(e, src) < 0.03,
					"%s: erase moved it to %s" % [SWATCHES[s][0], _fmt(e)])

	await _check_region()
	await _check_smoothing()

	print("")
	if _fails.is_empty():
		print("repaint_check: PASS - repaint lands the keyed color on the chosen ",
			"color, erase subtracts its chroma, the region confines it, and the ",
			"edge is anti-aliased.")
		quit(0)
	else:
		for f in _fails:
			print("repaint_check: FAIL - ", f)
		quit(1)


## The region. A color key cannot separate two things of the same color; position can. The same key color
## top and bottom, a box over the top half only, and the bottom must survive.
func _check_region() -> void:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			img.set_pixel(x, y, Color(0.85, 0.72, 0.35))   # one uniform keyed color
	var tex := ImageTexture.create_from_image(img)
	var got := await _render(tex, MaskSession.EFFECT_REPAINT,
		{"accent": 0.0, "stick": 0.0, "tint": 0.0, "con": 0.5,
		 "region": Vector4(0.0, 0.0, 1.0, 0.5), "regsoft": 0.0})
	var top := got.get_pixel(W / 2, int(H * 0.2))
	var bottom := got.get_pixel(W / 2, int(H * 0.8))
	print("")
	print("region (top half only): top %s  bottom %s" % [_fmt(top), _fmt(bottom)])
	_expect(_dist(top, Color(0, 0, 0)) < 0.16,
		"inside the region the paint did not land (%s)" % _fmt(top))
	_expect(_dist(bottom, Color(0.85, 0.72, 0.35)) < 0.03,
		"OUTSIDE the region the paint landed anyway (%s) - the box does not confine it"
		% _fmt(bottom))
	# The default box (whole frame) must not vignette: a layer with no region renders as it would without
	# regions.
	var full := await _render(tex, MaskSession.EFFECT_REPAINT,
		{"accent": 0.0, "stick": 0.0, "tint": 0.0, "con": 0.5,
		 "region": Vector4(0.0, 0.0, 1.0, 1.0), "regsoft": 0.5})
	for p in [Vector2i(1, 1), Vector2i(W - 2, 1), Vector2i(W / 2, H / 2), Vector2i(1, H - 2)]:
		_expect(_dist(full.get_pixel(p.x, p.y), Color(0, 0, 0)) < 0.16,
			"a full-frame region left %s unpainted at (%d,%d) - the default box is "
			% [_fmt(full.get_pixel(p.x, p.y)), p.x, p.y] + "vignetting")

	# The flush edge and the uniform interior: a box taken over the whole upper half must leave no band of
	# the removed color at the top of the picture (row 0 specifically), a side flush with the frame's edge
	# is not faded, and the default Region edge must not turn the box into a gradient.
	for soft in [0.0, 0.5]:
		var flush := await _render(tex, MaskSession.EFFECT_REPAINT,
			{"accent": 0.0, "stick": 0.0, "tint": 0.0, "con": 0.5,
			 "region": Vector4(0.0, 0.0, 1.0, 0.5), "regsoft": soft})
		var row0 := flush.get_pixel(W / 2, 0)
		print("flush-to-top box, edge %.1f: row 0 %s, row %d %s"
			% [soft, _fmt(row0), int(H * 0.25), _fmt(flush.get_pixel(W / 2, int(H * 0.25)))])
		_expect(_dist(row0, Color(0, 0, 0)) < 0.16,
			"edge %.1f: the box is flush with the top of the frame but row 0 is %s - "
			% [soft, _fmt(row0)] + "a band of the removed color survives at the border")
		# Uniform inside: every row from the top down to where the border shoulder begins must be painted the
		# same. The shoulder runs inward from the box's bottom edge (0.5) by soft x half the box's smaller side
		# (0.5); softening happens at the border, never across the inside.
		var shoulder := 0.5 - maxf(soft * 0.25, 0.02)
		var inner_max := 0.0
		for y in range(0, int(H * shoulder)):
			inner_max = maxf(inner_max, _dist(flush.get_pixel(W / 2, y), Color(0, 0, 0)))
		_expect(inner_max < 0.16,
			"edge %.1f: inside the box the paint varies (worst %.3f from the paint " % [soft, inner_max]
			+ "color) - a region is a selection, not a gradient")


## The edge. A hard color boundary keyed per pixel steps from painted to unpainted in one pixel (blocky,
## and it crawls on compressed video); anti-aliased, it spends a few pixels in between. Measured as how
## many rows are strictly between the two extremes.
func _check_smoothing() -> void:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			# Keyed color above the midline, an unrelated blue below it.
			img.set_pixel(x, y, Color(0.85, 0.72, 0.35) if y < H / 2 else Color(0.20, 0.28, 0.62))
	var tex := ImageTexture.create_from_image(img)
	print("")
	var widths := []
	for soft in [0.0, 1.0]:
		var got := await _render(tex, MaskSession.EFFECT_REPAINT,
			{"accent": 0.0, "stick": 0.0, "tint": 0.0, "con": 0.5,
			 "region": Vector4(0.0, 0.0, 1.0, 1.0), "regsoft": 0.0, "smooth": soft})
		var partial := 0
		for y in H:
			var v := got.get_pixel(W / 2, y)
			var painted: float = 1.0 - _dist(v, Color(0.85, 0.72, 0.35)) \
				/ maxf(_dist(Color(0, 0, 0), Color(0.85, 0.72, 0.35)), 1e-4)
			if y < H / 2 and painted > 0.06 and painted < 0.94:
				partial += 1
		widths.append(partial)
		print("smoothing %.1f -> %d transition rows at the boundary" % [soft, partial])
	_expect(int(widths[0]) >= 1,
		"at Smoothing 0 the boundary is still a hard step (%d rows) - some " % widths[0]
		+ "anti-aliasing is meant to be unconditional")
	_expect(int(widths[1]) > int(widths[0]),
		"raising Smoothing (%d rows) did not widen the boundary over Smoothing 0 (%d)"
		% [widths[1], widths[0]])


func _band(i: int) -> int:
	return int(float(i) * float(H) / float(SWATCHES.size()))


func _sample(img: Image, s: int) -> Color:
	return img.get_pixel(W / 2, (_band(s) + _band(s + 1)) / 2)


static func _fmt(c: Color) -> String:
	return "(%.2f,%.2f,%.2f)" % [c.r, c.g, c.b]


static func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## Distance from the neutral axis - what erase is in the business of removing.
static func _chroma(c: Color) -> float:
	var l := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	return Vector3(c.r - l, c.g - l, c.b - l).length()


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


## One layer of `effect` over `tex`, rendered and read back.
func _render(tex: Texture2D, effect: int, p: Dictionary) -> Image:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/mask_split.gdshader")
	_push_defaults(mat)
	mat.set_shader_parameter("u_l_count", 1)
	mat.set_shader_parameter("u_l_effect", PackedInt32Array([effect, 0, 0, 0, 0, 0]))
	mat.set_shader_parameter("u_l_hue", PackedFloat32Array([KEY_HUE, 0, 0, 0, 0, 0]))
	mat.set_shader_parameter("u_l_w", PackedFloat32Array([1.0, 0, 0, 0, 0, 0]))
	mat.set_shader_parameter("u_l_accent", _fill(float(p.accent)))
	mat.set_shader_parameter("u_l_stick", _fill(float(p.stick)))
	mat.set_shader_parameter("u_l_tint", _fill(float(p.tint)))
	mat.set_shader_parameter("u_l_con", _fill(float(p.con)))
	mat.set_shader_parameter("u_l_smooth", _fill(float(p.get("smooth", 0.0))))
	var regs := PackedVector4Array()
	for i in 6:
		regs.append(p.get("region", Vector4(0.0, 0.0, 1.0, 1.0)))
	mat.set_shader_parameter("u_l_region", regs)
	mat.set_shader_parameter("u_l_regsoft", _fill(float(p.get("regsoft", 0.0))))
	# Exactly how mask_editor.gd derives it (see the tdirs loop in _apply_frame_state).
	var tc := Color.from_hsv(KEY_HUE, 1.0, 1.0)
	var tl := 0.299 * tc.r + 0.587 * tc.g + 0.114 * tc.b
	var tdir := Vector3(tc.r - tl, tc.g - tl, tc.b - tl).normalized()
	var tdirs := PackedVector3Array()
	for i in 6:
		tdirs.append(tdir)
	mat.set_shader_parameter("u_l_tdir", tdirs)

	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var tr := TextureRect.new()
	tr.texture = tex
	tr.material = mat
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(W, H)
	vp.add_child(tr)
	root.add_child(vp)
	for i in 4:
		await process_frame
	var got := vp.get_texture().get_image()
	vp.queue_free()
	return got


static func _fill(v: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for i in 6:
		a.append(v)
	return a


func _push_defaults(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("u_threshold", 0.24)
	mat.set_shader_parameter("u_feather", 0.12)
	mat.set_shader_parameter("u_sat_floor", 0.18)
	mat.set_shader_parameter("u_fade", 1.0)
	mat.set_shader_parameter("u_time", 2.0)
	mat.set_shader_parameter("u_aspect", float(W) / float(H))
	mat.set_shader_parameter("u_texel", Vector2(1.0 / float(W), 1.0 / float(H)))
	mat.set_shader_parameter("u_l_off", PackedVector2Array([
		Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
	mat.set_shader_parameter("u_l_scale", _fill(1.0))
	mat.set_shader_parameter("u_l_dens", _fill(0.45))
	mat.set_shader_parameter("u_l_glow", _fill(1.0))
	mat.set_shader_parameter("u_l_speed", _fill(1.0))
	mat.set_shader_parameter("u_l_lagf", _fill(0.0))
	mat.set_shader_parameter("u_l_elag", PackedInt32Array([0, 0, 0, 0, 0, 0]))
	var ew := PackedFloat32Array()
	ew.resize(48)
	for l in 6:
		ew[l * 8] = 1.0
	mat.set_shader_parameter("u_l_ew", ew)
