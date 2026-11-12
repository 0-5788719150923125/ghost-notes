extends SceneTree

## The clown's eye-drip: how far it runs, and whether it follows the face.
##   godot --path . --position -5000,-5000 --script res://tests/masking/clown_drip_check.gd
## Needs a real renderer (the paint field is a ping-pong SubViewport pair).
##
## - Reach: at full Drip a run gets from the eye to the chin (a fraction of the face, not of the frame).
## - Contour: the run bends along the picture's own structure; on a frame with a strong diagonal ridge it
##   must lean toward the ridge rather than fall vertically.
##
## The shape is asserted on a scanline through the left run, at 10% and 90% of its own extent (the start
## is measured, so fixed rows would sit at an unknown fraction along it):
## - Taper: wide where it leaves the lash line, a hairline at the tail (a lane bundle scores about 1x).
## - Single: a pool drains at one point, exactly one span. The control injects a second rivulet a
##   socket-width inboard; a finer comb cannot be used, the run is about six texels wide at its widest.
## - Outboard: it curves outward as it descends. Measured as the shift between the two rows, never
##   against the eye (the drain point already sits outside the eye's center, so a straight run passes).
## - Eyeball: the run does not paint the ring's opening, so the synthetic eyes are annuli.
##
## Verified two-sided by breaking the shader three ways (constant width, zero outward bias, a second
## rivulet): each fails exactly its own assertion.
## Drip width and Drip curve are wound up: at 320px the default lean streak is a two-pixel thread whose
## width cannot be measured to better than 50%.

const W := 320
const H := 320
const CX := 0.5
const CY := 0.40
const RX := 0.26
const RY := 0.34
const EYE_Y := 0.34
## The ring's opening as a fraction of the drawn patch: the editor's opening is 0.9x the measured eye
## against a patch grown to Eye size (2.2x), so the annulus runs 0.42..1.0 of what it draws. A thinner
## ring is one pixel at this resolution and the shader's walk steps over it.
const HOLE := 0.42

var _fails: PackedStringArray = []


func _initialize() -> void:
	# Reach, on a flat face so nothing bends the run.
	var chin := CY + RY
	var span := chin - EYE_Y
	print("eye at y=%.2f, chin at y=%.2f -> %.2f of the frame between them" % [EYE_Y, chin, span])
	var reached := {}
	for drip in [0.0, 0.35, 1.0]:
		var f := await _run(drip, false)
		var low := -1.0
		for y in range(int(EYE_Y * H) + 6, H):
			var hit := false
			# Nearly the whole width: once the run curves outboard the tail leaves a narrow window.
			for x in range(int(W * 0.05), int(W * 0.95)):
				if f.get_pixel(x, y).r > 0.25:
					hit = true
					break
			if hit:
				low = (float(y) + 0.5) / float(H)
		reached[drip] = low
		var frac := (low - EYE_Y) / span if low > 0.0 else 0.0
		print("  Drip %.2f -> paint reaches y=%.3f, which is %.0f%% of the way from "
			% [drip, low, frac * 100.0] + "the eye to the chin")
	var full: float = (float(reached[1.0]) - EYE_Y) / span
	_expect(full > 0.80,
		"at full Drip the run only gets %.0f%% of the way to the chin - the reach "
		% (full * 100.0) + "or the taper is cutting it short")
	_expect(float(reached[0.35]) < float(reached[1.0]) - 0.02,
		"Drip barely changes how far the run gets (%.3f at 0.35 vs %.3f at 1.0)"
		% [reached[0.35], reached[1.0]])

	# Contour: the same face over a strong diagonal ridge. A run that ignores the picture falls straight
	# down from the eye; one that follows it leans.
	var straight := await _run(1.0, false)
	var ridged := await _run(1.0, true)
	var lean_flat := _lean(straight)
	var lean_ridge := _lean(ridged)
	print("")
	print("mean horizontal lean of the run: flat frame %+.4f, over a diagonal ridge %+.4f"
		% [lean_flat, lean_ridge])
	_expect(absf(lean_ridge - lean_flat) > 0.008,
		"the run lies in the same place over a flat frame and over a strong ridge "
		+ "(%.4f vs %.4f) - it is ignoring the picture's structure and just falling "
		% [lean_flat, lean_ridge] + "straight down the screen")

	# Shape: taper, single, outboard. Measured on the left half only, at rows found from the run's own
	# extent.
	var y0 := 1.0
	var y1 := 0.0
	for yy in range(int((EYE_Y + 0.02) * H), H):
		if not _spans(straight, (float(yy) + 0.5) / float(H)).is_empty():
			y0 = minf(y0, (float(yy) + 0.5) / float(H))
			y1 = maxf(y1, (float(yy) + 0.5) / float(H))
	print("")
	print("the left run occupies y %.3f .. %.3f" % [y0, y1])
	var near := _spans(straight, lerpf(y0, y1, 0.10))
	var far := _spans(straight, lerpf(y0, y1, 0.90))
	print("left run: %d span(s) at 10%% down it totaling %.3f wide, "
		% [near.size(), _width(near)] + "%d span(s) at 90%% down it totaling %.3f"
		% [far.size(), _width(far)])
	# Taper: wide at the source, one thin streak at the tail.
	var taper := _width(near) / maxf(_width(far), 1e-4)
	print("  taper (near width / far width): %.2fx" % taper)
	_expect(_width(far) > 0.001, "the left run has no material 90% of the way down it")
	_expect(taper > 2.0,
		"the run is %.2fx as wide at the eye as it is down the cheek - it does not "
		% taper + "taper, it is a streak of constant thickness")
	# Single: a pool drains at one point. Counted at the wide end, where parallel threads would show; at the
	# tail the run is thinner than the comb's spacing.
	_expect(near.size() <= 1,
		"the left run leaves the socket as %d separate streaks - a pool drains at "
		% near.size() + "its lowest point, it does not fan into a comb")
	# Outboard: it must curve, drifting further outboard as it descends. Measured as the shift between the
	# two rows, not against the eye (a straight-down run scores 0.028 against the eye and would pass).
	if not far.is_empty() and not near.is_empty():
		var cx_far := _center(far)
		var cx_near := _center(near)
		print("  the run leaves the socket at x=%.3f and is at x=%.3f down the cheek: "
			% [cx_near, cx_far] + "%+.3f OUTBOARD over that descent" % (cx_near - cx_far))
		_expect(cx_far < cx_near - 0.020,
			"the run is at x=%.3f where it leaves the socket and x=%.3f down the cheek "
			% [cx_near, cx_far] + "- it is falling straight toward the nose and the lips "
			+ "instead of curving out across the cheek")

	# Eyeball: nothing of the run may land inside the ring's opening.
	var worst := 0.0
	var worst_at := Vector2.ZERO
	for y in range(int((EYE_Y - 0.045) * H), int((EYE_Y + 0.045) * H)):
		for x in range(W):
			var u := (float(x) + 0.5) / float(W)
			var v := (float(y) + 0.5) / float(H)
			for ex in [CX - 0.10, CX + 0.10]:
				# The central half of the opening: the synthetic hole is about four texels tall, so a sample near
				# its rim reads the ring through bilinear filtering.
				if Vector2((u - ex) / 0.055, (v - EYE_Y) / 0.030).length() < HOLE * 0.55:
					if straight.get_pixel(x, y).r > worst:
						worst = straight.get_pixel(x, y).r
						worst_at = Vector2(u, v)
	print("")
	print("strongest paint inside the eye openings: %.3f (at %.3f, %.3f)"
		% [worst, worst_at.x, worst_at.y])
	_expect(worst < 0.20,
		"the run puts %.2f of paint inside the ring's opening - it is spilling over "
		% worst + "the eyeball, which is the one boundary the eye mask exists to keep")

	print("")
	if _fails.is_empty():
		print("clown_drip_check: PASS - the run reaches the chin, tapers, runs outboard, "
			+ "bends with the face and keeps off the eyeball.")
		quit(0)
	else:
		for f in _fails:
			print("clown_drip_check: FAIL - ", f)
		quit(1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


## The painted spans across one scanline of the left half, as (x0, x1) in uv. Gaps of a couple of pixels
## are bridged (the run's ragged width can pinch it to nothing for a texel).
func _spans(f: Image, uy: float) -> Array:
	var y := clampi(int(uy * float(H)), 0, H - 1)
	var out: Array = []
	var run_x0 := -1
	var gap := 0
	for x in range(int(W * 0.10), int(W * (CX - 0.005))):
		if f.get_pixel(x, y).r > 0.25:
			if run_x0 < 0:
				run_x0 = x
			gap = 0
		elif run_x0 >= 0:
			gap += 1
			if gap > 3:
				out.append(Vector2(float(run_x0) / float(W), float(x - gap) / float(W)))
				run_x0 = -1
	if run_x0 >= 0:
		out.append(Vector2(float(run_x0) / float(W), CX - 0.005))
	return out


## The midpoint of the painted material on a scanline, across all its spans.
func _center(spans: Array) -> float:
	var acc := 0.0
	var w := 0.0
	for sp in spans:
		var s2: Vector2 = sp
		acc += (s2.x + s2.y) * 0.5 * (s2.y - s2.x)
		w += s2.y - s2.x
	return acc / maxf(w, 1e-4)


func _width(spans: Array) -> float:
	var w := 0.0
	for s in spans:
		w += s.y - s.x
	return w


## How far the painted run sits from the face's center line, averaged down the cheek (a contour-following
## march changes it, a vertical one does not).
func _lean(f: Image) -> float:
	var acc := 0.0
	var n := 0
	for y in range(int((EYE_Y + 0.06) * H), int((CY + RY) * H)):
		for x in range(int(W * 0.15), int(W * 0.85)):
			var v := f.get_pixel(x, y).r
			if v > 0.25:
				acc += ((float(x) + 0.5) / float(W)) - CX
				n += 1
	return acc / maxf(float(n), 1.0)


func _run(drip: float, ridge: bool) -> Image:
	var sten := _stencil()
	var frame := _frame(ridge)
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
	for step in 40:
		var mm: ShaderMaterial = rects[ping].material
		mm.set_shader_parameter("u_prev", vps[1 - ping].get_texture())
		mm.set_shader_parameter("u_frame", frame)
		mm.set_shader_parameter("u_stencil", sten)
		mm.set_shader_parameter("u_has_stencil", 1.0)
		mm.set_shader_parameter("u_coat_feather", 0.012)
		mm.set_shader_parameter("u_drip", drip)
			# Wound up: the shape law is under test, and the default streak is too thin to measure at 320px.
		mm.set_shader_parameter("u_drip_w", 1.15)
		mm.set_shader_parameter("u_drip_curve", 1.4)
		mm.set_shader_parameter("u_dt", 0.033)
		mm.set_shader_parameter("u_reset", 1)   # the deposit is what is under test
		mm.set_shader_parameter("u_time", 3.0)
		mm.set_shader_parameter("u_aspect", 1.0)
		mm.set_shader_parameter("u_face_lum", 0.6)
		mm.set_shader_parameter("u_face_red", 0.12)
		mm.set_shader_parameter("u_face_c", Vector2(CX, CY))
		mm.set_shader_parameter("u_face_r", Vector2(RX, RY))
		mm.set_shader_parameter("u_eye_l", Vector2(CX - 0.10, EYE_Y))
		mm.set_shader_parameter("u_eye_r", Vector2(CX + 0.10, EYE_Y))
		mm.set_shader_parameter("u_mouth", Vector2(CX, 0.58))
		mm.set_shader_parameter("u_nose", Vector2(CX, 0.47))
		mm.set_shader_parameter("u_eye_lr", 0.035)
		mm.set_shader_parameter("u_eye_rr", 0.035)
		mm.set_shader_parameter("u_mouth_r", Vector2(0.05, 0.03))
		mm.set_shader_parameter("u_scale", 1.0)
		mm.set_shader_parameter("u_evidence", 0.0)
		mm.set_shader_parameter("u_settle", 0.2)
		mm.set_shader_parameter("u_bleed", 0.0)
		mm.set_shader_parameter("u_hollow", 0.0)
		vps[ping].render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		ping = 1 - ping
	var img: Image = vps[1 - ping].get_texture().get_image()
	for vp in vps:
		vp.queue_free()
	await process_frame
	return img


func _stencil() -> Texture2D:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var u := (float(x) + 0.5) / float(W)
			var v := (float(y) + 0.5) / float(H)
			var a := 0.0
			var e := 0.0
			if Vector2((u - CX) / RX, (v - CY) / RY).length() < 1.0:
				a = 1.0
				# A ring, like the real stencil: an annulus whose opening clears the eyeball at the stored Hollow.
			for ex in [CX - 0.10, CX + 0.10]:
				var d := Vector2((u - ex) / 0.055, (v - EYE_Y) / 0.030).length()
				if d < 1.0 and d > HOLE:
					e = 1.0
			img.set_pixel(x, y, Color(e, 0, 0, a))
	return ImageTexture.create_from_image(img)


## Flat skin, or skin with a strong diagonal ridge (a stand-in for a cheekbone), the only difference
## between the two runs.
func _frame(ridge: bool) -> Texture2D:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var u := (float(x) + 0.5) / float(W)
			var v := (float(y) + 0.5) / float(H)
			var l := 0.0
			if ridge:
				# A diagonal sawtooth: luminance moves about 0.2 over 0.03 of the frame like a cheekbone (0.05
				# across the march's 0.0072 tap spacing, above the deflection's knee), and its tangent keeps one
				# direction so the deflection accumulates.
				l = 0.45 * fposmod((u - v) * 10.0, 1.0)
			img.set_pixel(x, y, Color(0.55 + l, 0.42 + l * 0.8, 0.36 + l * 0.7))
	return ImageTexture.create_from_image(img)
