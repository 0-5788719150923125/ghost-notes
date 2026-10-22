extends SceneTree

## likeness_determinism_check - a Likeness is a pure function of the show's time (next/likeness.md,
## "Determinism"; the second build): the same moment drawn twice, with other moments drawn between, is
## the same picture, and the head, the eyes and the mouth chosen for it are the same.
##
##   tests/run_quiet.sh likeness_determinism_check
##
## NOT `--headless`: every claim is a rendered frame read back.
##
## THE SET IS MADE, NOT FOUND: a made still (noise, and a face on it: points on an ellipse and inside it,
## with depth), its rig (its body's skin and skeleton too) and masks, a library of made mouths and eyes,
## and made motion with a posture - written into a
## folder of the gate's own, drawn through the real medium ([LikenessMedium]) with its own plan and face.
## Two moments apart are two pictures (the head moves, the mouth speaks).
##
## THE CONTROL: another seed - another performance - draws another picture at the same moment.

const ROOT := "user://likeness_determinism_check"
const W := 320
const H := 180
const OVAL := 36

var _fails := 0
var _checks := 0
var _layout := PackedVector2Array()


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	var dir := ProjectSettings.globalize_path(ROOT)
	Actors._remove_tree(dir)
	var sd := dir.path_join("sets").path_join("s1")
	DirAccess.make_dir_recursive_absolute(sd)
	_make_set(dir, sd)
	var phones := [{"p": "AA", "t0": 1.0, "t1": 1.2}, {"p": "M", "t0": 1.2, "t1": 1.3}, {"p": "UW", "t0": 1.3, "t1": 1.6},
		{"p": "S", "t0": 2.4, "t1": 2.6}, {"p": "IY", "t0": 2.6, "t1": 2.9}]
	var at := 1.1
	var a := await _medium(dir, 1, phones)
	var first := await _draw(a, at)
	await _draw(a, at + 1.3)
	await _draw(a, 0.1)
	var again := await _draw(a, at)
	_ok(first[0] == again[0], "one moment drawn twice, with others between, came out two pictures")
	_ok(first[1] == again[1], "the head, eyes or mouth at one moment changed once others were asked")
	var later := await _draw(a, 2.7)
	_ok(later[0] != first[0], "two moments apart drew the same picture: nothing moves")
	# a medium made fresh draws the same
	var b := await _medium(dir, 1, phones)
	var fresh := await _draw(b, at)
	_ok(fresh[0] == first[0], "a medium made again drew the moment differently")
	# THE CONTROL: another performance draws another picture at the same moment
	var c := await _medium(dir, 7, phones)
	var other := await _draw(c, at)
	_ok(other[0] != first[0], "another seed drew the same picture - the check cannot fail")
	var drawn := (a["m"] as LikenessMedium)._plan.mouth(at).filter(func(e: Array) -> bool: return int(e[0]) >= 0)
	_ok(not drawn.is_empty(), "no library mouth was drawn at a moment the voice speaks: %s" % first[1])
	for med in [a, b, c]:
		(med["m"] as LikenessMedium).release()
		(med["vp"] as SubViewport).queue_free()
	await process_frame
	Actors._remove_tree(dir)
	print("likeness_determinism_check: %s (%d checks, %d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _checks, _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## A medium in a viewport of its own, playing the made set with [param seed_in] and [param phones].
func _medium(dir: String, seed_in: int, phones: Array) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var m := LikenessMedium.new()
	m.mount(vp)
	var err := m.load_set(dir, "s1", 0, seed_in)
	_ok(err.is_empty(), "the made set did not load: %s" % err)
	while m._library_task >= 0 and not WorkerThreadPool.is_task_completed(m._library_task):
		await process_frame
	m._land_library()
	_ok(m._library_tex != null, "the made library did not become a texture array")
	m._plan.set_voice(phones)
	return {"vp": vp, "m": m}


## Show time [param t] drawn: `[the picture's hash, the head, eyes and mouth there]`.
func _draw(med: Dictionary, t: float) -> Array:
	var m: LikenessMedium = med["m"]
	m.draw_at(t)
	for i in 3:
		await process_frame
	var img := (med["vp"] as SubViewport).get_texture().get_image()
	var said := JSON.stringify([Array(m._plan.motion(t)), m._plan.eyes(t), m._plan.mouth(t), str(m._plan.lifts(t)),
		str(m._plan.hands(t))])
	return [img.get_data().hex_encode().sha256_text() if img != null else "", said]


# --- the made set -------------------------------------------------------------------------------------

func _make_set(dir: String, sd: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := Vector2(W * 0.5, H * 0.45)
	var r := Vector2(40.0, 55.0)
	_layout = PackedVector2Array()
	for i in OVAL:
		var a := TAU * float(i) / float(OVAL)
		_layout.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	while _layout.size() < LikenessFace.FACE:
		var p := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if p.length() < 0.92:
			_layout.append(c + p * r)
	# the mouth moves the lower half, the lids a band across the upper
	var weights := PackedFloat32Array()
	var eye_weights := PackedFloat32Array()
	for i in LikenessFace.FACE:
		weights.append(1.0 if i >= OVAL and _layout[i].y > c.y + 8.0 else 0.0)
		eye_weights.append(1.0 if i >= OVAL and absf(_layout[i].y - (c.y - 18.0)) < 6.0 else 0.0)
	var anchors: Array = []
	var anchor_px := PackedVector2Array()
	for i in 7:
		for y in [0.0, 1.0]:
			anchors.append([float(i) / 6.0, y])
	for i in range(1, 6):
		for x in [0.0, 1.0]:
			anchors.append([x, float(i) / 6.0])
	for a in anchors:
		anchor_px.append(Vector2(float(a[0]) * W, float(a[1]) * H))
	var face := LikenessFace.new()
	face.oval = PackedInt32Array(range(OVAL))
	var mean := _layout.duplicate()
	mean.append_array(face.ring(_layout, 1.35))
	mean.append_array(face.ring(_layout, 2.0))
	mean.append_array(anchor_px)
	var tris: Array = []
	var idx := Geometry2D.triangulate_delaunay(mean)
	for t in range(0, idx.size(), 3):
		tris.append([idx[t], idx[t + 1], idx[t + 2]])
	var box := [c.x - 45.0, c.y - 60.0, c.x + 45.0, c.y + 60.0]
	# ITS BODY: the far ring on the torso (the head's half of it), the frame's edge the room's; arms that go
	# with the shoulders
	var skin := {}
	for b in LikenessFace.BONES:
		var col: Array = []
		for i in OVAL + anchors.size():
			col.append(0.5 if i < OVAL and (b == "torso" or b == "head") else 0.0)
		skin[b] = col
	var arm := {"shoulder": [c.x + 60.0, c.y + 90.0], "elbow": [c.x + 70.0, c.y + 140.0], "wrist": [c.x + 40.0, c.y + 170.0],
		"tip": [c.x + 20.0, c.y + 175.0], "rests": false}
	var other := {"shoulder": [c.x - 60.0, c.y + 90.0], "elbow": [c.x - 70.0, c.y + 140.0], "wrist": [c.x - 40.0, c.y + 170.0],
		"tip": [c.x - 20.0, c.y + 175.0], "rests": false}
	var body := {"body": [], "skin": skin, "triangles": tris, "skeleton": {"neck": [c.x, c.y + 90.0], "hip": [c.x, c.y + 220.0],
		"width": 120.0, "l": arm, "r": other}}
	_json(sd.path_join("rig.json"), {"size": [W, H], "layout": _pairs(_layout), "weights": Array(weights),
		"eye_weights": Array(eye_weights), "oval": range(OVAL), "ring1": 1.35, "ring2": 2.0, "ring_moves": 0.6,
		"anchors": anchors, "mean": _pairs(mean), "triangles": tris, "box": box, "image": [64, 64],
		"masks": {"mouth": "mask_mouth.png", "eyes": "mask_eyes.png"}, "stills": [body]})
	for m in [["mask_mouth.png", Rect2i(12, 34, 40, 20)], ["mask_eyes.png", Rect2i(8, 14, 48, 10)]]:
		var mask := Image.create(64, 64, false, Image.FORMAT_L8)
		mask.fill(Color.BLACK)
		mask.fill_rect(m[1], Color.WHITE)
		mask.save_png(sd.path_join(String(m[0])))
	# THE STILL: noise, its face's points with a little depth
	var still := Image.create(W, H, false, Image.FORMAT_RGB8)
	for y in H:
		for x in W:
			still.set_pixel(x, y, Color(rng.randf(), rng.randf(), rng.randf()))
	DirAccess.make_dir_recursive_absolute(sd.path_join("stills"))
	still.save_jpg(sd.path_join("stills").path_join("still_0.jpg"), 0.95)
	var pts: Array = []
	for i in 478:
		var p := _layout[i] if i < LikenessFace.FACE else _layout[0]
		pts.append([p.x / W, p.y / H, -0.05 * (1.0 - (p - c).length() / r.y)])
	_json(sd.path_join("stills.json"), {"stills": [{"file": "still_0.jpg", "thumb": "still_0.jpg", "size": [W, H],
		"points": pts, "light": [0.5, 0.45, 0.4, 0.1, 0.1, 0.1], "yaw": 0.0, "pitch": 0.0}]})
	# THE LIBRARY: a few mouths and eyes, each a color and a shape of its own
	DirAccess.make_dir_recursive_absolute(sd.path_join("library"))
	var mouths: Array = []
	var k := 0
	for cl in ["open", "pbm", "round", "spread", "sz"]:
		for v in 2:
			var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
			img.fill(Color.from_hsv(float(k) / 10.0, 0.6, 0.8))
			img.fill_rect(Rect2i(16, 40 + v, 32, 4 + k), Color(0.3, 0.05, 0.05))
			var file := "mouth_%s_%d.png" % [cl, v]
			img.save_png(sd.path_join("library").path_join(file))
			var shape := _layout.duplicate()
			for i in LikenessFace.FACE:
				if weights[i] > 0.0:
					shape[i] += Vector2(0.0, float(k) * 0.6)
			mouths.append({"class": cl, "file": file, "light": [0.5, 0.45, 0.4, 0.1, 0.1, 0.1], "shape": _pairs(shape)})
			k += 1
	var eyes: Array = []
	for st in ["half", "closed"]:
		var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
		img.fill(Color(0.6, 0.45, 0.4) if st == "half" else Color(0.7, 0.5, 0.45))
		var file := "eye_%s_0.png" % st
		img.save_png(sd.path_join("library").path_join(file))
		var shape := _layout.duplicate()
		for i in LikenessFace.FACE:
			if eye_weights[i] > 0.0:
				shape[i] += Vector2(0.0, 2.0 if st == "half" else 4.0)
		eyes.append({"state": st, "file": file, "light": [0.5, 0.45, 0.4, 0.1, 0.1, 0.1], "shape": _pairs(shape)})
	_json(sd.path_join("library.json"), {"image": [64, 64], "mouths": mouths, "eyes": eyes})
	# THEIR MOTION: two runs of made turns and nods, a blink every second or so
	var runs: Array = []
	for run in 2:
		var rows: Array = []
		for n in 120:
			var t := float(n) / 5.0
			rows.append([3.0 * sin(t * (0.9 + run)), 2.0 * sin(t * 1.7 + run), 1.0 * sin(t * 0.6), 0.02 * sin(t * 0.8),
				0.015 * cos(t * 1.1), 0.01 * sin(t * 0.5), 1.0 * sin(t * 0.7)])
		runs.append({"vid": "v", "t0": 0.0, "talk": "1".repeat(120), "rows": rows})
	# (a posture that holds a second or so, so a shift falls inside the moments drawn)
	_json(dir.path_join("motion.json"), {"rate": 5.0, "axes": ["yaw", "pitch", "roll", "x", "y", "near", "tilt"],
		"sd": [3.0, 2.0, 1.0, 0.02, 0.015, 0.01, 1.0], "blinks_per_min": 50.0, "runs": runs,
		"posture": {"sd": [0.04, 0.03, 0.01, 1.4], "corr": [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]], "tau": 1.0}})


static func _pairs(pts: PackedVector2Array) -> Array:
	var out: Array = []
	for p in pts:
		out.append([p.x, p.y])
	return out


static func _json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
