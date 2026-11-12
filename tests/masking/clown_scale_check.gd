extends SceneTree

## Does turning Scale up grow the clown's features, or merge them?
##   godot --path . --position -5000,-5000 --script res://tests/masking/clown_scale_check.gd
## Needs a real renderer (the paint field is a ping-pong SubViewport pair, and the dummy renderer hands
## back no image); runs windowed, offscreen.
##
## Scale multiplies each feature's radius, so the radii are bounded by the anatomy's own spacing (see
## clown_paint's deposit). Measured at the top of the slider:
## - Gap: the midpoint between the nose and the mouth must not be claimed by both channels at once.
## - Brow: well above the eye line stays clear of eye black however wide the patches are told to be.
## - Growth: Scale still does something; the eye patch is measurably bigger at 2.5 than at 0.5.

const W := 256
const H := 144
const EYE_L := Vector2(0.43, 0.41)
const EYE_R := Vector2(0.57, 0.39)
const MOUTH := Vector2(0.51, 0.60)
const NOSE := Vector2(0.50, 0.50)

var _fails: PackedStringArray = []


func _initialize() -> void:
	var res := {}
	for scale in [0.5, 1.0, 2.5]:
		res[scale] = await _run(scale)
		var r: Dictionary = res[scale]
		print("")
		print("--- Scale %.1f ---" % scale)
		print("  nose/mouth midpoint   lip %.3f  nose %.3f   (both at once = the blob)"
			% [r.mid_lip, r.mid_nose])
		print("  brow, well above eyes black %.3f" % r.brow)
		print("  eye patch black       %.3f at the eye, %.3f out toward the temple"
			% [r.eye, r.eye_out])
		print("  paint ON the features nose %.3f  lips %.3f" % [r.nose, r.lip])
		# The gap between two different red features must not be owned by both (either alone is a look; both
		# saturating means they met in the middle).
		_expect(minf(r.mid_lip, r.mid_nose) < 0.45,
			"Scale %.1f: the nose and the lips have merged - the midpoint between "
			% scale + "them carries lip %.2f AND nose %.2f" % [r.mid_lip, r.mid_nose])
		_expect(r.brow < 0.25,
			"Scale %.1f: eye black reached the brow (%.2f) - the patches are "
			% [scale, r.brow] + "smearing up the forehead instead of staying on the eyes")
		# The bound must not have deleted the features it was keeping apart.
		_expect(r.nose > 0.15,
			"Scale %.1f: nothing is painted ON the nose (%.2f) - the spacing bound "
			% [scale, r.nose] + "has capped it out of existence")
		_expect(r.lip > 0.15,
			"Scale %.1f: nothing is painted ON the lips (%.2f)" % [scale, r.lip])

	# ...and Scale still has to be a real control.
	var small: Dictionary = res[0.5]
	var big: Dictionary = res[2.5]
	print("")
	print("Scale 0.5 -> 2.5: eye paint out toward the temple goes %.3f -> %.3f"
		% [small.eye_out, big.eye_out])
	_expect(big.eye_out > small.eye_out + 0.05,
		"Scale stopped growing the features (%.3f -> %.3f out toward the temple) - "
		% [small.eye_out, big.eye_out] + "the anatomy bound is clamping everything flat")

	print("")
	if _fails.is_empty():
		print("clown_scale_check: PASS - Scale grows the features without merging them.")
		quit(0)
	else:
		for f in _fails:
			print("clown_scale_check: FAIL - ", f)
		quit(1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


func _run(scale: float) -> Dictionary:
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
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/clown_paint.gdshader")
		r.material = m
		vp.add_child(r)
		root.add_child(vp)
		vps.append(vp)
		rects.append(r)
	var ping := 0
	for step in 40:
		var m: ShaderMaterial = rects[ping].material
		m.set_shader_parameter("u_prev", vps[1 - ping].get_texture())
		m.set_shader_parameter("u_dt", 0.033)
		m.set_shader_parameter("u_reset", 1 if step == 0 else 0)
		m.set_shader_parameter("u_time", float(step) * 0.033)
		m.set_shader_parameter("u_aspect", float(W) / float(H))
		m.set_shader_parameter("u_eye_l", EYE_L)
		m.set_shader_parameter("u_eye_r", EYE_R)
		m.set_shader_parameter("u_mouth", MOUTH)
		m.set_shader_parameter("u_nose", NOSE)
		m.set_shader_parameter("u_face_c", Vector2(0.5, 0.45))
		m.set_shader_parameter("u_face_r", Vector2(0.14, 0.20))
		m.set_shader_parameter("u_eye_lr", 0.04)
		m.set_shader_parameter("u_eye_rr", 0.033)
		m.set_shader_parameter("u_mouth_r", Vector2(0.05, 0.03))
		m.set_shader_parameter("u_scale", scale)
		vps[ping].render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		ping = 1 - ping
	var img: Image = vps[1 - ping].get_texture().get_image()
	var mid := (NOSE + MOUTH) * 0.5
	# One eye-patch width outboard of the left eye, and well above the eye line.
	var out := EYE_L + Vector2(-0.024, 0.0)
	var brow := Vector2(EYE_L.x, EYE_L.y - 0.16)
	var got := {
		"mid_lip": _at(img, mid).g, "mid_nose": _at(img, mid).b,
		"brow": _at(img, brow).r,
		"eye": _at(img, EYE_L).r, "eye_out": _at(img, out).r,
		"nose": _at(img, NOSE).b, "lip": _at(img, MOUTH).g,
	}
	for vp in vps:
		vp.queue_free()
	await process_frame
	return got


func _at(img: Image, uv: Vector2) -> Color:
	return img.get_pixel(clampi(int(uv.x * float(W)), 0, W - 1),
		clampi(int(uv.y * float(H)), 0, H - 1))
