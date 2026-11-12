extends Node

## Gate that perturbation in scenes/fractal_zoom.gd buys the depth it claims.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/scenes/fractal_depth_check.gd 240
##
## GHOST_PROBE_GPU is required: the claim lives in a fragment program, so it is asked by rendering and
## reading pixels back.
##
## A zoom that has run out of float32 raises no error: every pixel computes the same complex number and
## the frame is one flat color, which on a per-session palette reads as a boring seed. A stray
## `set_shader_parameter("u_ref_len", 0)` after the reference orbit upload turns the perturbed path off
## the same way.
##
## The control: the same scene, anchor and depth are rendered twice with only `u_perturb` changed. Past
## float32's limit the direct path must collapse and the perturbed one must not; structure in the
## perturbed render alone proves nothing, as it would also appear at a scale float32 handles.
##
## Two cheap CPU properties are held too: the anchor is on the boundary (a long but finite escape; the
## interior is a flat hole and the far outside a flat wash), and the zoom stays inside the range its own
## path can resolve however long it runs.

const SEEDS := [11, 23, 47]
const W := 640
const H := 360

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for sv in SEEDS:
		await _run_seed(int(sv))
	print("")
	if _fails.is_empty():
		print("fractal_depth_check: ALL OK - perturbation resolves what float32 cannot.")
	else:
		print("fractal_depth_check: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("   ", f)
	for _i in 6:
		await get_tree().process_frame
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _run_seed(sv: int) -> void:
	# The scene is rolled until it lands on the quadratic Mandelbrot, the only family perturbation is
	# implemented for; forcing the fields by hand would test a configuration the Director cannot produce.
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var sc = null
	var used := -1
	for k in 40:
		var candidate := sv * 101 + k * 7
		var probe = load("res://src/scenes/fractal_zoom.gd").new()
		vp.add_child(probe)
		probe.init_with_seed(candidate, "drift")
		if bool(probe.params.get("perturbed", false)):
			sc = probe
			used = candidate
			break
		vp.remove_child(probe)
		probe.free()
	if sc == null:
		_fails.append("seed %d: no perturbed instance in 40 rolls - the family bag is wrong" % sv)
		vp.queue_free()
		await get_tree().process_frame
		return
	print("")
	print("--- seed %d -> %d: %s ---" % [sv, used, sc.params])

	# --- the anchor is on the boundary: a long escape, but one that finishes ---
	var esc: int = sc._escape(sc._cx, sc._cy, 3000)
	print("  anchor escapes at iteration %d of 3000" % esc)
	_ok(esc > 60, "seed %d: the anchor escapes after only %d iterations - it is out in the flat "
		% [used, esc] + "exterior, and there is nothing at it to zoom into")
	_ok(esc < 3000, "seed %d: the anchor never escapes - it is inside the set, whose interior is "
		% used + "a flat hole, and whose orbit is useless as a reference for the surface")

	# --- the zoom stays inside the range its own path can resolve ---
	var lo: float = sc._zl
	var hi: float = sc._zl
	for _i in 5400:                       # three minutes at the fixed step, well past any hold
		sc._step_zoom(1.0 / 30.0)
		lo = minf(lo, sc._zl)
		hi = maxf(hi, sc._zl)
	print("  over 3 minutes the scale stays in [%s, %s]; its floor is %s"
		% [_sci(exp(lo)), _sci(exp(hi)), _sci(exp(sc._zl_min))])
	_ok(lo >= sc._zl_min - 1e-6, "seed %d: the zoom reached %s, past its own floor of %s - "
		% [used, _sci(exp(lo)), _sci(exp(sc._zl_min))] + "below that the picture is blocks")
	_ok(hi <= sc._zl_max + 1e-6, "seed %d: the zoom reached %s, past its ceiling"
		% [used, _sci(exp(hi))])

	# --- the claim: at a depth float32 cannot hold, perturbation resolves and direct does not ---
	sc._zl = log(exp(sc._zl_min) * 6.0)   # a little above the floor, comfortably past float32
	sc.update(_features(), 1.0 / 30.0)
	for _i in 6:
		await get_tree().process_frame
	var img_on := vp.get_texture().get_image()
	var on := _structure(img_on)
	var b_on := _blocky(img_on)
	if OS.get_cmdline_user_args().has("--dump"):
		_dump(img_on, "depth_on_%d.png" % used)
	sc._mat.set_shader_parameter("u_perturb", false)
	for _i in 6:
		await get_tree().process_frame
	var img_off := vp.get_texture().get_image()
	var off := _structure(img_off)
	var b_off := _blocky(img_off)
	if OS.get_cmdline_user_args().has("--dump"):
		_dump(img_off, "depth_off_%d.png" % used)
	sc._mat.set_shader_parameter("u_perturb", true)
	print("  at %s: perturbed %.1f%% structure / %.1f%% blocky;  direct (the control) %.1f%% / %.1f%%"
		% [_sci(exp(sc._zl)), on * 100.0, b_on * 100.0, off * 100.0, b_off * 100.0])
	_ok(on > 0.15, "seed %d: the PERTURBED render carries only %.1f%% local contrast at %s - a "
		% [used, on * 100.0, _sci(exp(sc._zl))] + "dead frame, so perturbation is not working "
		+ "and the scene is empty at every depth it was written for")
	_ok(b_off > 0.70, "seed %d: the DIRECT render is only %.1f%% blocky at %s, where float32 "
		% [used, b_off * 100.0, _sci(exp(sc._zl))] + "cannot resolve a pixel - it should be "
		+ "almost entirely quantized, so this gate is not standing where it thinks it is")
	_ok(b_on < b_off - 0.20, "seed %d: perturbed %.1f%% blocky against the direct path's %.1f%% "
		% [used, b_on * 100.0, b_off * 100.0] + "- the two paths are drawing the same quantized "
		+ "picture, which is what perturbation being broken looks like")

	sc.queue_free()
	vp.queue_free()
	await get_tree().process_frame


## The measure that separates them is blockiness. A float32 render past its limit is not flat but
## blocky: the complex coordinate quantizes to a few dozen values, giving hard-edged rectangles whose
## edges read as structure (24-32% of the frame differs from its neighborhood, against 44-74% perturbed:
## not a verdict). Inside a quantized block every adjacent pixel pair is byte-identical, while a
## resolved fractal changes almost everywhere it has detail; this counts the share of horizontally
## adjacent pairs that are exactly equal.
func _blocky(img: Image) -> float:
	var n := 0
	var same := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width() - 1):
			n += 1
			if img.get_pixel(x, y) == img.get_pixel(x + 1, y):
				same += 1
	return float(same) / float(maxi(1, n))


## How much of a frame carries local contrast: the cheap "did anything render" read, for the perturbed
## side, where the question is only whether the frame is dead.
func _structure(img: Image) -> float:
	var n := 0
	var busy := 0
	for y in range(0, img.get_height() - 4, 3):
		for x in range(0, img.get_width() - 4, 3):
			var a := img.get_pixel(x, y)
			var b := img.get_pixel(x + 4, y + 4)
			n += 1
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.06:
				busy += 1
	return float(busy) / float(maxi(1, n))


## GDScript's % formatting has no %e, and these numbers are all exponent.
func _sci(x: float) -> String:
	return String.num_scientific(x)


func _features() -> AudioFeatures:
	var f := AudioFeatures.new()
	var bands := PackedFloat32Array()
	bands.resize(Spectrum.BAND_COUNT)
	bands.fill(0.35)
	f.bands = bands
	f.energy = 0.4
	f.beat_period = 0.5
	return f


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


## `--dump` writes the two frames compared above into user://, and says where.
func _dump(img: Image, file: String) -> void:
	var path := ProjectSettings.globalize_path("user://" + file)
	img.save_png(path)
	print("  dumped %s" % path)
