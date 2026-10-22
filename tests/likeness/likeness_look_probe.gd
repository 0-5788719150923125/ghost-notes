extends SceneTree

## likeness_look_probe - an actor's set, drawn, for looking (next/likeness.md, "The second build"). Not a
## gate: what it shows is judged by eye.
##
##   xvfb-run -a godot --path . --script tests/likeness/likeness_look_probe.gd -- \
##       --actor <an actor's folder> --set <set id> --out <a folder> [--still K] [--seed N] [--take DIR]
##       [--fps 30] [--width 960]
##
## WHAT IT WRITES into --out:
##   identity.png   the still drawn through its own mesh with nothing moved and no library, beside the
##                  still itself and their difference times eight: the mesh must be invisible
##   sounds.png     the lower face with each sound class's first prototype drawn in, the still's own first
##   eyes.png       the eyes open (the still's), half closed and shut
##   take/NNNNN.png with --take DIR (a `take.json` of `{duration, phones}`, or a take's sidecar `.json` beside
##                  its `.wav`): the medium itself over the take, frame by frame at --fps, --width wide -
##                  the head moving, the blinks, the mouth (ffmpeg makes them a film with the take's sound)
##
## NOT `--headless`: every picture is a rendered frame read back. Nothing is written but --out.

var _actor := ""
var _set := ""
var _out := ""
var _still := 0
var _seed := 1
var _take := ""
var _fps := 30.0
var _width := 960


func _init() -> void:
	_run.call_deferred()


func _arg(args: PackedStringArray, name: String, dflt: String) -> String:
	var i := args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else dflt


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_actor = _arg(args, "--actor", "")
	_set = _arg(args, "--set", "")
	_out = _arg(args, "--out", ProjectSettings.globalize_path("user://likeness_look"))
	_still = int(_arg(args, "--still", "0"))
	_seed = int(_arg(args, "--seed", "1"))
	_take = _arg(args, "--take", "")
	_fps = float(_arg(args, "--fps", "30"))
	_width = int(_arg(args, "--width", "960"))
	DirAccess.make_dir_recursive_absolute(_out)
	var sz := Vector2i(1920, 1080)
	var m := await _medium(sz)
	if m == null:
		quit(1)
		return
	var vp := m.get_parent() as SubViewport
	var face := m._face
	# THE IDENTITY: nothing moved, nothing drawn in
	m._plan.runs = []
	m._plan.line = []
	var mat := m._layer.material as ShaderMaterial
	m.draw_at(0.0)
	mat.set_shader_parameter("library_on", 0.0)
	var same := await _grab(vp)
	var real := Image.load_from_file(_actor.path_join("sets").path_join(_set).path_join("stills").path_join(
		String((ActorFolder.read_json(_actor.path_join("sets").path_join(_set).path_join("stills.json")) as Dictionary)["stills"][_still]["file"])))
	real.convert(Image.FORMAT_RGB8)
	var diff := Image.create(sz.x, sz.y, false, Image.FORMAT_RGB8)
	var sum := 0.0
	for y in range(0, sz.y, 2):
		for x in range(0, sz.x, 2):
			var a := real.get_pixel(x, y)
			var b := same.get_pixel(x, y)
			var d := (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
			sum += d
			diff.set_pixel(x, y, Color(d * 8.0, d * 8.0, d * 8.0))
	print("identity: mean difference %.5f (of 1)" % (sum / float(sz.x * sz.y / 4)))
	var crop := _crop_of(face.still_face)
	_save_row([real.get_region(crop), same.get_region(crop), diff.get_region(crop)], "identity.png", 1.0)
	# EACH SOUND'S FIRST PROTOTYPE, the still's own first
	var tiles: Array = []
	var lips := _lips_of(face.still_face)
	tiles.append(await _pose_mouth(m, vp, [[-1, 1.0]], lips))
	for c in ["open", "mid", "round", "spread", "pbm", "fv", "w", "sh", "sz", "tdnl", "kg", "r", "th", "h"]:
		if face.mouths_of.has(c):
			tiles.append(await _pose_mouth(m, vp, [[int(face.mouths_of[c][0]), 1.0]], lips))
	_save_row(tiles, "sounds.png", 1.0)
	# THE EYES: the still's own, half closed, shut
	var eyes_crop := _eyes_of(face.still_face)
	var eye_tiles: Array = []
	for mix in [[[-1, 1.0]], [[int(face.eyes_of.get("half", [-1])[0]), 1.0]], [[int(face.eyes_of.get("closed", [-1])[0]), 1.0]]]:
		m._layer.points = face.vertices(face.still_face, face.target(face.still_face, [[-1, 1.0]], mix))
		mat.set_shader_parameter("library_on", 1.0)
		m._layers_of(mat, "m", [[-1, 1.0]])
		m._layers_of(mat, "e", mix)
		m._layer.queue_redraw()
		eye_tiles.append((await _grab(vp)).get_region(eyes_crop))
	_save_row(eye_tiles, "eyes.png", 1.0)
	if not _take.is_empty():
		await _play_take(sz)
	print("likeness_look_probe: wrote %s" % _out)
	quit(0)


## The medium, in a viewport of [param sz], loaded with the set, its still, its library and motion.
func _medium(sz: Vector2i) -> LikenessMedium:
	var vp := SubViewport.new()
	vp.size = sz
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var m := LikenessMedium.new()
	m.mount(vp)
	var err := m.load_set(_actor, _set, _still, _seed)
	if not err.is_empty():
		print("likeness_look_probe: " + err)
		return null
	while m._library_task >= 0 and not WorkerThreadPool.is_task_completed(m._library_task):
		await process_frame
	m._land_library()
	return m


func _pose_mouth(m: LikenessMedium, vp: SubViewport, mix: Array, crop: Rect2i) -> Image:
	var face := m._face
	var mat := m._layer.material as ShaderMaterial
	m._layer.points = face.vertices(face.still_face, face.target(face.still_face, mix, [[-1, 1.0]]))
	mat.set_shader_parameter("library_on", 1.0)
	m._layers_of(mat, "m", mix)
	m._layers_of(mat, "e", [[-1, 1.0]])
	m._layer.queue_redraw()
	return (await _grab(vp)).get_region(crop)


## THE MEDIUM OVER A TAKE: every frame at [member _fps], the head, the eyes and the mouth its plan says.
func _play_take(sz: Vector2i) -> void:
	var path := _take
	if DirAccess.dir_exists_absolute(_take):
		path = _take.path_join("take.json")
	var t: Variant = ActorFolder.read_json(path)
	if not (t is Dictionary):
		print("likeness_look_probe: no take at %s" % _take)
		return
	var phones: Array = (t as Dictionary).get("phones", [])
	var duration := float((t as Dictionary).get("duration", 0.0))
	if duration <= 0.0:
		for p in phones:
			duration = maxf(duration, float((p as Dictionary)["t1"]))
		duration += 1.0
	var m := await _medium(sz)
	m._plan.set_voice(phones)
	var vp := m.get_parent() as SubViewport
	DirAccess.make_dir_recursive_absolute(_out.path_join("take"))
	var n_frames := int(ceil(duration * _fps))
	var h := int(round(float(_width) * float(sz.y) / float(sz.x)))
	for n in n_frames:
		m.draw_at(float(n) / _fps)
		var img := await _grab(vp)
		img.resize(_width, h, Image.INTERPOLATE_BILINEAR)
		img.save_png(_out.path_join("take").path_join("%05d.png" % n))
	print("take: %d frames of %.1f s, %d phones, in %s" % [n_frames, duration, phones.size(), _out.path_join("take")])


func _grab(vp: SubViewport) -> Image:
	for i in 2:
		await process_frame
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## Round the face [param face]: the box a head is judged in.
func _crop_of(face: PackedVector2Array) -> Rect2i:
	var r := Rect2(face[0], Vector2.ZERO)
	for p in face:
		r = r.expand(p)
	var s := maxf(r.size.x, r.size.y) * 1.6
	return Rect2i(Vector2i(r.get_center() - Vector2(s, s) * 0.5), Vector2i(int(s), int(s))).intersection(Rect2i(Vector2i.ZERO, Vector2i(1920, 1080)))


## Round the lips of [param face].
func _lips_of(face: PackedVector2Array) -> Rect2i:
	var r := Rect2(face[61], Vector2.ZERO)
	for i in [61, 291, 0, 17, 13, 14, 152]:
		r = r.expand(face[i])
	var w := r.size.x * 2.0
	return Rect2i(Vector2i(r.get_center() - Vector2(w * 0.5, w * 0.4)), Vector2i(int(w), int(w * 0.8)))


## Round both eyes of [param face].
func _eyes_of(face: PackedVector2Array) -> Rect2i:
	var r := Rect2(face[33], Vector2.ZERO)
	for i in [33, 133, 263, 362, 159, 145, 386, 374]:
		r = r.expand(face[i])
	return Rect2i(Vector2i(r.position - r.size * Vector2(0.15, 1.2)), Vector2i(r.size * Vector2(1.3, 3.4)))


func _save_row(imgs: Array, name: String, k: float) -> void:
	var h := 0
	var w := 0
	for i in imgs:
		h = maxi(h, (i as Image).get_height())
		w += (i as Image).get_width()
	var row := Image.create(w, h, false, Image.FORMAT_RGB8)
	var x := 0
	for i in imgs:
		var img := i as Image
		img.convert(Image.FORMAT_RGB8)
		row.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, 0))
		x += img.get_width()
	if k != 1.0:
		row.resize(int(w * k), int(h * k))
	row.save_png(_out.path_join(name))
