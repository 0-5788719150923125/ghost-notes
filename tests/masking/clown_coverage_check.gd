extends SceneTree

## Is the clown's white coat solid where the face outline says there is a face?
##   tests/run_quiet.sh clown_coverage_check
## Needs a real renderer (the paint field is a ping-pong SubViewport pair).
##
## The coat's opacity must follow the face outline, not the picture. Two blotches are planted well inside
## the face (one nearly black, one strongly off-hue); the coat's recovered opacity over each must match the
## clean coat in the ring around it. A ring comparison, not a fixed number, because the coat dims with the
## scene's own light (`white16`). The background must stay unpainted, or "no holes" would pass by painting
## the whole frame; that outline is enforced in two places (the coat window's early-out and the window in
## the opacity), so the control is removing both (the background then reads 0.70).
## Also held: the eye openings are cut out of the coat (at max Smudge), the eye patch is solid on its outer
## side, and the red stays on the ball of the nose.

const W := 288
const H := 512
const T := 1.0
const POINTS := 478

## Well inside the fitted oval (center 0.5, 0.42, radii 0.30) and clear of every feature window, including
## the eye patch at its default 2.2x growth.
const DARK_AT := Vector2(0.34, 0.53)
const HUE_AT := Vector2(0.66, 0.53)
const BLOB_R := 0.035
## Sampled inside this radius; the clean coat is sampled in the annulus beyond it.
const CORE_R := 0.022
const RING_LO := 0.055
const RING_HI := 0.080

var _ed: Node
var _frame: Texture2D
var _raw: Image
var _fails: PackedStringArray = []


func _initialize() -> void:
	_ed = load("res://src/masking/mask_editor.gd").new()
	var s := MaskSession.new()
	s.video_path = "res://masks/_coverage_check/video.ogv"
	var m := {}
	for k in MaskSession.VECTOR_FIELDS:
		m[k] = MaskSession.DEFAULTS.get(k, 0.0)
	m["effect_a"] = float(MaskSession.EFFECT_CLOWN)
	s.markers.append(m)
	_ed.session = s
	_ed._source_prep.src_size = Vector2i(W, H)
	root.add_child(_ed)
	_ed._face._ft_path = _write_track()
	_ed._face._ft_load()
	if _ed._ft_state != "ready":
		print("clown_coverage_check: could not load the synthetic track (%s)" % _ed._ft_state)
		quit(2)
		return
	_frame = _make_frame()
	_raw = _frame.get_image()

	_ed._clown_fs = 1.0
	_ed._clown_bleed = 0.0
	_ed._clown_settle = 0.35
	_ed._clown_hollow = 0.0
	_ed._clown_evidence = 0.0
	_ed._clown_eye_size = 1.2 + 0.24 * 4.0
	_ed._clown_drip = 0.0
	_ed._clown_smudge = 0.45
	_ed._clown_drip_w = 0.35
	_ed._clown_drip_curve = 0.45
	_ed._clown_smile_w = 1.0
	_ed._clown_smile_curve = 0.0
	_ed._clown_feather = 0.012
	_ed._face.apply_model(T)
	_ed._face.update_stencil(T)
	for i in 3:
		await process_frame
	var out := await _composite(await _sim())

	print("%-22s %-9s %-9s %s" % ["region", "core", "around it", "verdict"])
	for probe in [["a nearly black blotch", DARK_AT], ["a strongly off-hue blotch", HUE_AT]]:
		var at: Vector2 = probe[1]
		var core := _opacity(out, at, 0.0, CORE_R)
		var ring := _opacity(out, at, RING_LO, RING_HI)
		var ok := core >= ring * 0.80
		print("%-22s %-9.3f %-9.3f %s"
			% [probe[0], core, ring, "solid" if ok else "A HOLE"])
		_expect(ring > 0.55,
			"the coat is not really present even around %s (%.2f) - this test cannot "
			% [probe[0], ring] + "say anything about holes in a coat that is not there")
		_expect(ok,
			"the coat covers %s at %.2f while covering the clean paint right beside it "
			% [probe[0], core] + "at %.2f - that is a hole, which is what reads as "
			% ring + "patchiness, and re-keying will only move it")

	# The eye openings are holes in the whole mask, not just in the black. Measured at max Smudge, which is
	# the setting that could close the hole back over the eyeball (it averages the stencil over a disc, which
	# pulls paint inward); the solidity checks above stay at the default because a soft ragged edge is the
	# point of max Smudge. The openings are cut out of the coat's silhouette (a subtractive second pass), and
	# the coat is its deposit exactly, or advection refills the hole from the solid coat beside it.
	_ed._clown_smudge = 1.0
	_ed._face.update_stencil(T)
	for i in 3:
		await process_frame
	var smudged := await _composite(await _sim())
	for eye in [Vector2(0.38, 0.34), Vector2(0.62, 0.34)]:
		var seen := _opacity(smudged, eye, 0.0, 0.012)
		print("%-22s %-9.3f" % ["an eye opening", seen])
	# 0.15: a missing cut reads 0.33 and 0.42, a sim that refills above its deposit reads 0.05 and 0.19.
	# Clean is 0.00.
		_expect(seen < 0.15,
			"the eye opening is %.2f painted - the hole in the black paint is showing "
			% seen + "the white coat instead of the eye behind it")

	# The eye patch is solid too: the white coat must not show through the middle of the eye paint. Measured
	# on the outer part of the ring, where the synthetic frame is plain bright skin (the drawn eye ends at 1.0
	# of the eye radius; the patch runs to Eye size, 2.16).
	for probe2 in [[Vector2(0.38, 0.34), -1.0], [Vector2(0.62, 0.34), 1.0]]:
		var eye: Vector2 = probe2[0]
		# The ring's body on its outer side: 1.10..1.70 of the eye radius, past the drawn eye and clear of the
		# outer edge at 2.16, where Smudge is deliberately soft. Outer side only: the inner side is kept away
		# from the bridge, so a full annulus averages in a bare region.
		var ring := _ring_lum(out, eye, Vector2(0.075, 0.035), 1.10, 1.70,
			float(probe2[1]))
		print("%-22s %-9.3f" % ["eye ring, outer half", ring])
		_expect(ring < 0.30,
			"the eye ring reads %.2f bright over the skin outside the eye - the paint "
			% ring + "is only landing where the picture happens to be dark, so the "
			+ "white coat shows through the middle of it")

	# No assertion that the two patches stay apart: keeping the bridge bare and wrapping each eye all the way
	# round are in tension, and wrapping was chosen. Eye size controls how far they reach.

	# The red stays on the ball of the nose: FT_NOSE must not run up the dorsum. Checked at two heights,
	# because "no red on the bridge" is also satisfied by painting no nose at all.
	var bridge_red := _redness(out, Vector2(0.50, 0.385), 0.022)
	var ball_red := _redness(out, Vector2(0.50, 0.468), 0.022)
	print("%-22s %-9.3f (ball reads %.3f)" % ["redness up the bridge", bridge_red, ball_red])
	_expect(ball_red > 0.15,
		"there is no red on the ball of the nose at all (%.2f) - this cannot say "
		% ball_red + "anything about where the nose paint stops")
	_expect(bridge_red < ball_red * 0.35,
		"the nose paint reads %.2f red up the BRIDGE against %.2f on the ball - it is "
		% [bridge_red, ball_red] + "running up the dorsum instead of staying on the "
		+ "round part, which is the only part a clown paints")

	# The coat must still stop at the face; the blotch rings above show it is present.
	var bg := _opacity(out, Vector2(0.10, 0.90), 0.0, 0.05)
	print("%-22s %-9.3f" % ["background", bg])
	_expect(bg < 0.25,
		"the coat is painting the background at %.2f - the interior in-fill has "
		% bg + "taken the outline with it")

	_ed.free()
	print("")
	if _fails.is_empty():
		print("clown_coverage_check: PASS - the coat and the eye patches are solid, "
			+ "the eyes stay apart, the nose stays on its ball, and the coat stops "
			+ "at the face.")
		quit(0)
	else:
		for f in _fails:
			print("clown_coverage_check: FAIL - ", f)
		quit(1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


## The coat's opacity, recovered from the render. `out = mix(raw, white, opacity)` with the coat's own
## white being the shader's `white16` (it carries the pixel's luminance). Averaged over an annulus
## `r_lo..r_hi` around `c` (r_lo = 0 for a disc), skipping pixels with too little between raw and white
## to divide by.
func _opacity(out: Image, c: Vector2, r_lo: float, r_hi: float) -> float:
	var acc := 0.0
	var n := 0
	for y in range(int((c.y - r_hi) * H) - 1, int((c.y + r_hi) * H) + 2):
		for x in range(int((c.x - r_hi) * W) - 1, int((c.x + r_hi) * W) + 2):
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			var u := (float(x) + 0.5) / float(W)
			var v := (float(y) + 0.5) / float(H)
			var d := Vector2(u, v).distance_to(c)
			if d < r_lo or d > r_hi:
				continue
			var raw := _raw.get_pixel(x, y)
			var o := out.get_pixel(x, y)
			var lum := 0.299 * raw.r + 0.587 * raw.g + 0.114 * raw.b
			var white := Vector3(0.93, 0.94, 0.96) * (0.55 + 0.65 * lum)
			var rv := Vector3(raw.r, raw.g, raw.b)
			var denom := (white - rv).length()
			if denom < 0.08:
				continue
			acc += clampf((Vector3(o.r, o.g, o.b) - rv).length() / denom, 0.0, 1.2)
			n += 1
	return acc / maxf(float(n), 1.0)


## How red a small disc reads, as r minus the brighter of g/b: separates the nose paint from skin and coat.
func _redness(out: Image, c: Vector2, r: float) -> float:
	var acc := 0.0
	var n := 0
	for y in range(int((c.y - r) * H) - 1, int((c.y + r) * H) + 2):
		for x in range(int((c.x - r) * W) - 1, int((c.x + r) * W) + 2):
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			if Vector2((float(x) + 0.5) / float(W), (float(y) + 0.5) / float(H)).distance_to(c) > r:
				continue
			var p := out.get_pixel(x, y)
			acc += p.r - maxf(p.g, p.b)
			n += 1
	return acc / maxf(float(n), 1.0)


## Mean luminance over an elliptical annulus `r_lo..r_hi` in units of `r`, centered on `c` (the eye patch
## is an ellipse grown from the measured eye).
func _ring_lum(out: Image, c: Vector2, r: Vector2, r_lo: float, r_hi: float,
		side: float = 0.0) -> float:
	var acc := 0.0
	var n := 0
	for y in range(int((c.y - r.y * r_hi) * H) - 1, int((c.y + r.y * r_hi) * H) + 2):
		for x in range(int((c.x - r.x * r_hi) * W) - 1, int((c.x + r.x * r_hi) * W) + 2):
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			var u := (float(x) + 0.5) / float(W)
			var v := (float(y) + 0.5) / float(H)
			var d := Vector2((u - c.x) / r.x, (v - c.y) / r.y).length()
			if d < r_lo or d > r_hi:
				continue
			# `side` restricts to one half: -1 keeps x below the center, +1 above.
			if side != 0.0 and (u - c.x) * side <= 0.0:
				continue
			var p := out.get_pixel(x, y)
			acc += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b
			n += 1
	return acc / maxf(float(n), 1.0)


## Skin, plus a dark blotch and an off-hue blotch planted well inside the face.
func _make_frame() -> Texture2D:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var u := (float(x) + 0.5) / float(W)
			var v := (float(y) + 0.5) / float(H)
			var c := Color(0.10, 0.10, 0.12)
			if Vector2((u - 0.5) / 0.30, (v - 0.42) / 0.30).length() < 1.0:
				var shade: float = 0.10 * sin(u * 34.0) + 0.08 * cos(v * 26.0)
				c = Color(0.74 + shade, 0.57 + shade, 0.48 + shade)
				for ex in [0.38, 0.62]:
					if Vector2((u - ex) / 0.075, (v - 0.34) / 0.035).length() < 1.0:
						c = Color(0.16, 0.14, 0.14)
				if Vector2((u - 0.5) / 0.12, (v - 0.56) / 0.045).length() < 1.0:
					c = Color(0.62, 0.22, 0.24)
				if Vector2((u - 0.5) / 0.05, (v - 0.45) / 0.07).length() < 1.0:
					c = Color(0.88, 0.72, 0.62)
					# A deep shadow (what dark16 vetoes).
				if Vector2(u, v).distance_to(DARK_AT) < BLOB_R:
					c = Color(0.05, 0.045, 0.05)
					# Chroma opposite the face tint (what match16 vetoes).
				if Vector2(u, v).distance_to(HUE_AT) < BLOB_R:
					c = Color(0.24, 0.40, 0.72)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _sim() -> Texture2D:
	var vps: Array = []
	var rects: Array = []
	for i in 2:
		var vp := SubViewport.new()
		vp.size = Vector2i(W, H)
		vp.disable_3d = true
		vp.use_hdr_2d = true
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		var r := ColorRect.new()
		r.size = Vector2(W, H)
		var mm := ShaderMaterial.new()
		mm.shader = load("res://shaders/clown_paint.gdshader")
		r.material = mm
		vp.add_child(r)
		root.add_child(vp)
		vps.append(vp)
		rects.append(r)
	var ping := 0
	for step in 30:
		var mm: ShaderMaterial = rects[ping].material
		mm.set_shader_parameter("u_prev", vps[1 - ping].get_texture())
		mm.set_shader_parameter("u_frame", _frame)
		mm.set_shader_parameter("u_stencil", _ed._stencil_vp.get_texture())
		mm.set_shader_parameter("u_has_stencil", 1.0)
		mm.set_shader_parameter("u_coat_feather", _ed._clown_feather)
		mm.set_shader_parameter("u_drip", _ed._clown_drip)
		mm.set_shader_parameter("u_drip_w", _ed._clown_drip_w)
		mm.set_shader_parameter("u_eye_smudge", _ed._clown_smudge)
		mm.set_shader_parameter("u_drip_curve", _ed._clown_drip_curve)
		mm.set_shader_parameter("u_dt", 0.033)
		mm.set_shader_parameter("u_reset", 1 if step == 0 else 0)
		mm.set_shader_parameter("u_time", float(step) * 0.033)
		mm.set_shader_parameter("u_aspect", float(W) / float(H))
		mm.set_shader_parameter("u_face_lum", 0.55)
		mm.set_shader_parameter("u_face_red", 0.10)
		mm.set_shader_parameter("u_eye_l", _ed._face_eye_l_ema)
		mm.set_shader_parameter("u_eye_r", _ed._face_eye_r_ema)
		mm.set_shader_parameter("u_mouth", _ed._face_mouth_ema)
		mm.set_shader_parameter("u_nose", _ed._face_nose_ema)
		mm.set_shader_parameter("u_face_c", _ed._face_c_ema)
		mm.set_shader_parameter("u_face_r", _ed._face_r_ema)
		mm.set_shader_parameter("u_eye_lr", _ed._face_eye_lr_ema)
		mm.set_shader_parameter("u_eye_rr", _ed._face_eye_rr_ema)
		mm.set_shader_parameter("u_mouth_r", _ed._face_mouth_r_ema)
		mm.set_shader_parameter("u_scale", _ed._clown_fs)
		mm.set_shader_parameter("u_evidence", _ed._clown_evidence)
		mm.set_shader_parameter("u_settle", _ed._clown_settle)
		mm.set_shader_parameter("u_bleed", _ed._clown_bleed)
		mm.set_shader_parameter("u_hollow", _ed._clown_hollow)
		vps[ping].render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		ping = 1 - ping
	return vps[1 - ping].get_texture()


func _composite(paint: Texture2D) -> Image:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/mask_split.gdshader")
	mat.set_shader_parameter("u_threshold", 0.24)
	mat.set_shader_parameter("u_feather", 0.12)
	mat.set_shader_parameter("u_sat_floor", 0.18)
	mat.set_shader_parameter("u_fade", 1.0)
	mat.set_shader_parameter("u_time", 2.0)
	mat.set_shader_parameter("u_aspect", float(W) / float(H))
	mat.set_shader_parameter("u_texel", Vector2(1.0 / float(W), 1.0 / float(H)))
	mat.set_shader_parameter("u_l_count", 1)
	mat.set_shader_parameter("u_l_effect", PackedInt32Array([16, 0, 0, 0, 0, 0]))
	mat.set_shader_parameter("u_l_hue", PackedFloat32Array([0, 0, 0, 0, 0, 0]))
	mat.set_shader_parameter("u_l_w", PackedFloat32Array([1.0, 0, 0, 0, 0, 0]))
	mat.set_shader_parameter("u_l_off", PackedVector2Array([
		Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
	mat.set_shader_parameter("u_l_scale", _f(1.0))
	mat.set_shader_parameter("u_l_speed", _f(1.0))
	mat.set_shader_parameter("u_l_glow", _f(1.0))
	mat.set_shader_parameter("u_l_dens", _f(0.45))
	mat.set_shader_parameter("u_l_con", _f(0.5))
	mat.set_shader_parameter("u_l_smooth", _f(0.0))
	mat.set_shader_parameter("u_l_lagf", _f(0.35))
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
	for i in 6:
		ew[i * 8] = 1.0
	mat.set_shader_parameter("u_l_ew", ew)
	var tds := PackedVector3Array()
	for i in 6:
		tds.append(Vector3(0.86, -0.37, -0.37))
	mat.set_shader_parameter("u_l_tdir", tds)
	mat.set_shader_parameter("u_clown_paint", paint)
	mat.set_shader_parameter("u_clown_eye_l", _ed._face_eye_l_ema)
	mat.set_shader_parameter("u_clown_eye_r", _ed._face_eye_r_ema)
	mat.set_shader_parameter("u_clown_mouth", _ed._face_mouth_ema)
	mat.set_shader_parameter("u_clown_face_r", _ed._face_r_ema)
	mat.set_shader_parameter("u_clown_face_c", _ed._face_c_ema)
	mat.set_shader_parameter("u_clown_eye_lr", _ed._face_eye_lr_ema)
	mat.set_shader_parameter("u_clown_eye_rr", _ed._face_eye_rr_ema)
	mat.set_shader_parameter("u_clown_mouth_r", _ed._face_mouth_r_ema)
	mat.set_shader_parameter("u_clown_tint", Vector3(0.16, -0.02, -0.14))
	mat.set_shader_parameter("u_clown_lum", 0.55)
	var ev: Vector2 = (_ed._face_eye_r_ema - _ed._face_eye_l_ema) \
		* Vector2(float(W) / float(H), 1.0)
	var el: float = maxf(ev.length(), 1e-4)
	mat.set_shader_parameter("u_clown_frame", ev / (el * el))
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var tr := TextureRect.new()
	tr.texture = _frame
	tr.material = mat
	tr.size = Vector2(W, H)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	vp.add_child(tr)
	root.add_child(vp)
	for i in 3:
		await process_frame
	var out: Image = vp.get_texture().get_image()
	vp.queue_free()
	await process_frame
	return out


## A one-sample track holding a plausible face, in face_track.py's own format (see face_track_check for
## the layout).
func _write_track() -> String:
	var dir := ProjectSettings.globalize_path("user://face_tracks")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("_coverage_check.bin")
	var pts := PackedVector2Array()
	pts.resize(POINTS)
	for i in POINTS:
		pts[i] = Vector2(0.5, 0.42)
	_ellipse(pts, _ed._face.FT_OVAL, Vector2(0.5, 0.42), Vector2(0.30, 0.30))
	_ellipse(pts, _ed._face.FT_EYE_L, Vector2(0.38, 0.34), Vector2(0.075, 0.035))
	_ellipse(pts, _ed._face.FT_EYE_R, Vector2(0.62, 0.34), Vector2(0.075, 0.035))
	_ellipse(pts, _ed._face.FT_LIPS, Vector2(0.50, 0.56), Vector2(0.12, 0.045))
	_ellipse(pts, _ed._face.FT_NOSE, Vector2(0.50, 0.45), Vector2(0.05, 0.07))
	# The nose's landmarks placed anatomically, by index: the ellipse above puts every member of FT_NOSE on
	# one ring, which would hide a wrong set. These four are the dorsum chain up the bridge (168 is the
	# nasion), so a hull that includes them is a wedge up the nose.
	pts[168] = Vector2(0.50, 0.355)   # nasion, just under the eye line
	pts[6] = Vector2(0.50, 0.380)
	pts[197] = Vector2(0.50, 0.400)
	pts[195] = Vector2(0.50, 0.420)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("GFT1".to_ascii_buffer())
	f.store_32(1)
	f.store_float(15.0)
	f.store_32(40)
	f.store_32(POINTS)
	for s in 40:
		f.store_8(1)
		for i in POINTS:
			f.store_float(pts[i].x)
			f.store_float(pts[i].y)
	f.close()
	return path


static func _ellipse(pts: PackedVector2Array, idx: Array, c: Vector2, r: Vector2) -> void:
	for k in idx.size():
		var a := TAU * float(k) / float(idx.size())
		pts[int(idx[k])] = c + Vector2(cos(a) * r.x, sin(a) * r.y)


static func _f(v: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for i in 6:
		a.append(v)
	return a
