extends SceneTree

## Is the rain actually rain?
##   godot --path . --position -5000,-5000 --script res://tests/scene_kit/rain_check.gd
## Needs a real renderer (it reads pixels back).
##
## Three claims:
##
##   Independence  Every drop goes its own way. Hashing each lane once makes every drop down a lane repeat one
##                 position, caliber and angle; hashing on the cell index as well gives each pass its own. Measured
##                 as the overlap between the x positions carrying rain at one moment and at another: shared tracks
##                 mean near-total overlap, independent drops little.
##   Amount        Turning it down empties the sky, not merely thins each drop (coverage moves the lane count).
##   Depth         At Depth 0 nothing falls in front of the subject: the far sheet is confined to background, the
##                 only depth cue available without a depth buffer.

## Wide on purpose: a near lane is a 26th of the frame and a drop a pixel or two across, so at 400px a lane offers
## only about six distinguishable positions and the independence measure hits that ceiling; at 1200 a lane is ~46px.
const W := 1200
const H := 600

var _fails: PackedStringArray = []


func _initialize() -> void:
	# A frame split into background (dark, flat) and subject (lit, structured), so
	# the depth heuristic has both to work with.
	var src := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var lit := x > W / 2
			var n := 0.06 * float((x * 7 + y * 13) % 5)   # a little structure
			src.set_pixel(x, y, Color(0.05, 0.05, 0.06) if not lit
				else Color(0.62 + n, 0.48 + n, 0.42 + n))
	var tex := ImageTexture.create_from_image(src)

	# Independence: watch one lane over many moments. A lane hashed once puts every drop it produces at one x, so a window
	# one lane wide collects crossings at a single position however long you watch; hashed per drop, the crossings scatter
	# across the window. (Whole-column and whole-frame measures saturate: nearly every lane holds a drop somewhere, and
	# across ~200 lanes snapshots of fixed and random offsets look alike.)
	var win_lo := int(W * 0.30)
	var win_hi := win_lo + int(float(W) / 26.0)   # exactly one near lane
	var lane_x := []
	var lane_n := 0
	for step in 30:
		var img := await _render(tex, 1.0, 1.0, 0.0, 2.0 + float(step) * 0.211)
		for c in _centers(img, src):
			if c < win_lo or c > win_hi:
				continue
			lane_n += 1
			var dup := false
			for d in lane_x:
				if absf(float(c) - float(d)) <= 1.0:
					dup = true
					break
			if not dup:
				lane_x.append(c)
	var ratio := float(lane_x.size()) / maxf(float(lane_n), 1.0)
	print("independence: within ONE lane, %d crossings over 30 moments landed on %d "
		% [lane_n, lane_x.size()] + "distinct x -> %.2f" % ratio)
	_expect(lane_n > 20, "too few crossings in the sampled lane (%d)" % lane_n)
	# Measured: 0.13 with a per-lane hash (every drop on one track), 0.60+ with a per-drop hash; 0.35 sits between with room on both sides.
	_expect(ratio > 0.35,
		"within one lane, %d crossings landed on only %d distinct positions (%.2f) - "
		% [lane_n, lane_x.size(), ratio]
		+ "every drop is running down the same track")

	# AMOUNT: the sky empties.
	var drizzle := _wetness(await _render(tex, 0.12, 1.0, 0.3, 5.0), src)
	var downpour := _wetness(await _render(tex, 1.0, 1.0, 0.3, 5.0), src)
	print("amount: drizzle %.5f, downpour %.5f  (%.1fx)"
		% [drizzle, downpour, downpour / maxf(drizzle, 1e-6)])
	_expect(downpour > drizzle * 3.0,
		"Amount barely changes how much falls (%.5f vs %.5f) - it is thinning the "
		% [drizzle, downpour] + "drops rather than emptying the sky")
	_expect(drizzle > 0.0,
		"a drizzle produced no rain at all - the existence gate is too tight")

	# DEPTH: at 0, nothing in front of the subject.
	var behind := await _render(tex, 0.8, 0.0, 0.3, 7.0)
	var on_subj := _wetness_where(behind, src, true)
	var on_bg := _wetness_where(behind, src, false)
	print("depth 0: rain on subject %.5f, on background %.5f" % [on_subj, on_bg])
	_expect(on_bg > 0.0005, "Depth 0 produced no rain on the background either")
	_expect(on_subj < on_bg * 0.06,
		"at Depth 0 the rain still falls in front of the subject (%.5f vs %.5f on "
		% [on_subj, on_bg] + "background) - the far sheet is not confined to background")

	print("")
	if _fails.is_empty():
		print("rain_check: PASS - drops go their own way, Amount empties the sky, ",
			"and Depth keeps the far sheet behind the subject.")
		quit(0)
	else:
		for f in _fails:
			print("rain_check: FAIL - ", f)
		quit(1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


## Which x positions carry rain on one row, over the background half. One row, not the whole column: a column's full
## height asks whether the lane ever has a drop, which saturates (88% overlap for scattered rain); a single row asks
## whether a drop crosses here now and crosses the same here a moment later.
## The center x of every streak crossing a set of rows, over the background half. Centers rather than wet pixels: a
## streak is several pixels wide, and counting each would report a wide drop as several distinct positions.
func _centers(got: Image, src: Image) -> Array:
	var out := []
	for row in [int(H * 0.30), int(H * 0.50), int(H * 0.70)]:
		var run_start := -1
		for x in range(2, W - 2):
			var wet := _diff(got, src, x, row) > 0.06
			if wet and run_start < 0:
				run_start = x
			elif not wet and run_start >= 0:
				out.append((run_start + x - 1) / 2)
				run_start = -1
		if run_start >= 0:
			out.append((run_start + W - 3) / 2)
	return out


func _wetness(got: Image, src: Image) -> float:
	var acc := 0.0
	var n := 0
	for y in range(10, H - 10, 2):
		for x in range(2, W / 2 - 2, 2):
			acc += _diff(got, src, x, y)
			n += 1
	return acc / maxf(float(n), 1.0)


func _wetness_where(got: Image, src: Image, subject: bool) -> float:
	var acc := 0.0
	var n := 0
	var lo := W / 2 + 6 if subject else 2
	var hi := W - 6 if subject else W / 2 - 6
	for y in range(10, H - 10, 2):
		for x in range(lo, hi, 2):
			acc += _diff(got, src, x, y)
			n += 1
	return acc / maxf(float(n), 1.0)


static func _diff(got: Image, src: Image, x: int, y: int) -> float:
	var a := got.get_pixel(x, y)
	var b := src.get_pixel(x, y)
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _render(frame: Texture2D, amount: float, depth: float, squall: float,
		t: float) -> Image:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/mask_split.gdshader")
	mat.set_shader_parameter("u_threshold", 0.24)
	mat.set_shader_parameter("u_feather", 0.12)
	mat.set_shader_parameter("u_sat_floor", 0.18)
	mat.set_shader_parameter("u_fade", 1.0)
	mat.set_shader_parameter("u_time", t)
	mat.set_shader_parameter("u_aspect", 1.0)
	mat.set_shader_parameter("u_texel", Vector2(1.0 / W, 1.0 / H))
	mat.set_shader_parameter("u_l_count", 1)
	mat.set_shader_parameter("u_l_effect", PackedInt32Array([19, 0, 0, 0, 0, 0]))
	mat.set_shader_parameter("u_l_hue", PackedFloat32Array([0, 0, 0, 0, 0, 0]))
	mat.set_shader_parameter("u_l_w", PackedFloat32Array([1.0, 0, 0, 0, 0, 0]))
	mat.set_shader_parameter("u_l_off", PackedVector2Array([
		Vector2(0.15, 0), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
	mat.set_shader_parameter("u_l_scale", _f(1.0))
	mat.set_shader_parameter("u_l_speed", _f(1.0))
	mat.set_shader_parameter("u_l_glow", _f(1.0))
	mat.set_shader_parameter("u_l_dens", _f(amount))
	mat.set_shader_parameter("u_l_con", _f(depth))
	mat.set_shader_parameter("u_l_smooth", _f(squall))
	mat.set_shader_parameter("u_l_lagf", _f(0.0))
	mat.set_shader_parameter("u_l_stick", _f(0.0))
	mat.set_shader_parameter("u_l_tint", _f(0.0))
	mat.set_shader_parameter("u_l_accent", _f(0.0))
	mat.set_shader_parameter("u_l_elag", PackedInt32Array([0, 0, 0, 0, 0, 0]))
	var regs := PackedVector4Array()
	for i in 6:
		regs.append(Vector4(0, 0, 1, 1))
	mat.set_shader_parameter("u_l_region", regs)
	mat.set_shader_parameter("u_l_regsoft", _f(0.0))
	var ew := PackedFloat32Array()
	ew.resize(48)
	for l in 6:
		ew[l * 8] = 1.0
	mat.set_shader_parameter("u_l_ew", ew)
	var tds := PackedVector3Array()
	for i in 6:
		tds.append(Vector3(0.86, -0.37, -0.37))
	mat.set_shader_parameter("u_l_tdir", tds)
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var tr := TextureRect.new()
	tr.texture = frame
	tr.material = mat
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(W, H)
	vp.add_child(tr)
	root.add_child(vp)
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	await process_frame
	return img


static func _f(v: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for i in 6:
		a.append(v)
	return a
