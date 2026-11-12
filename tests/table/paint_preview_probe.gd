extends Node

## NOT a gate. The painted surface as the show draws it, at any moment, without playing up to it (next/painted_surface.md): an episode's
## table stood from a copy of its folder (a take's sidecar names it), its acts scheduled on the take's word times, and then for each
## moment asked for, the paint alone set to it ([method TablePaint.tick] - no bake, no physics: what is laid is a pure function of show
## time) and the skin's own canvas drawn by the GPU and read back, laid over the bare surface as prop.gdshader lays it. Side by side with
## the painted picture it was copied from, and how far each stands from it (OKLab x 100, on average over the surface, and the share of
## it more than 10 off).
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/paint_preview_probe.gd 1500 --take=<user://generative/take_N.json> \
##       --at=600,1800,2640 --out=<dir>
##
## Read-only: the episode is copied, never written; the pictures go to `--out` (`paint_<t>.png` each, and `paint_strip.png`: the picture,
## then each moment).

const EBP := preload("res://tests/table/episode_bake_probe.gd")
var medium: TableMedium


func _ready() -> void:
	_run.call_deferred()


func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	for a in args:
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return fallback


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var take_path := _arg(args, "take", "")
	var out_dir := _arg(args, "out", "")
	if take_path.is_empty() or out_dir.is_empty():
		print("paint_preview_probe: --take=<a take's .json> and --out=<dir> are needed")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var take: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(take_path))
	var book: Dictionary = (take["book"] as Dictionary).duplicate(true)
	var pay: Dictionary = book["table"]
	var src_dir := String(pay["dir"])
	var copy := _arg(args, "copy", ProjectSettings.globalize_path("res://dist/paint_preview_probe"))
	EBP._copy_dir(src_dir, copy)
	pay["dir"] = copy
	book["table"] = pay
	book["source"] = FileAccess.get_file_as_string(src_dir.path_join("script.md"))
	for key in ["start_words", "start_index", "start_time"]:
		book.erase(key)
	var stage := SubViewport.new()
	stage.size = Vector2i(640, 360)
	stage.own_world_3d = true
	add_child(stage)
	Director.detach()
	medium = Medium.make("table") as TableMedium
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	add_child(subs)
	medium.bind_captions(subs)
	Director.intro_hold = 9.0
	subs.words = []
	subs.document = book
	medium._key = ""
	TableMedium.away_in_tests = false
	var clock := Time.get_ticks_msec()
	medium._ensure_doc()
	var words: Array = []
	var spoken: PackedStringArray = medium._plan.parse.get("spoken", PackedStringArray())
	for j in spoken.size():
		var t0: float = medium._est[j] if j < medium._est.size() else float(j) * 0.4
		var t1: float = medium._est[j + 1] if j + 1 < medium._est.size() else t0 + 0.4
		words.append({"text": spoken[j], "t0": t0, "t1": minf(t1, t0 + 0.6), "sentence": j / 12, "speaker": "Narrator", "emph": 0})
	subs.words = words
	medium._follow.extend(subs.words)
	medium._sched = medium._follow.place(medium._plan.parse["actions"], maxf(Director.intro_hold, 0.6), TableMedium.LEAD, TableMedium.TAIL)
	medium._work.schedule(medium._sched, medium._plan.parse, medium._follow.said0, medium._follow.said1, medium._est, 0.0)
	print("paint_preview_probe: stood and scheduled in %d ms" % (Time.get_ticks_msec() - clock))
	var tp: TablePaint = medium._work.paint
	if tp == null or tp.skins.is_empty():
		print("paint_preview_probe: nothing on this table is painted")
		get_tree().quit(1)
		return
	var sd: Dictionary = tp.skins[0]
	var canvas: Array = sd.get("canvas", [])
	if canvas.is_empty():
		print("paint_preview_probe: the surface has no canvas")
		get_tree().quit(1)
		return
	var vp: SubViewport = canvas[0]
	var bare := tp._bare_of(sd).srgb_to_linear()
	var ref := Image.load_from_file(copy.path_join("face_ref.png"))
	var strip: Array = []
	if ref != null:
		ref.convert(Image.FORMAT_RGBA8)
		ref.resize(vp.size.x, vp.size.y, Image.INTERPOLATE_LANCZOS)
		strip.append(ref)
	for s in _arg(args, "at", "600").split(",", false):
		var t := String(s).to_float()
		tp.tick(t, func(_ch: String) -> Array: return [])
		for _i in 3:
			await get_tree().process_frame
		var got := vp.get_texture().get_image()
		if got == null:
			print("paint_preview_probe: no picture (run it with GHOST_PROBE_GPU=1)")
			get_tree().quit(1)
			return
		got.convert(Image.FORMAT_RGBA8)
		var img := _over_bare(got, bare)
		img.save_png(out_dir.path_join("paint_%06.1f.png" % t))
		strip.append(img)
		if ref != null:
			var off := _off(img, ref)
			print("  %.1f s: off the picture %.1f on average, %.1f%% of the surface over 10" % [t, off.x, off.y * 100.0])
	if not strip.is_empty():
		var sw := (strip[0] as Image).get_width()
		var sh := (strip[0] as Image).get_height()
		var all := Image.create(sw * strip.size(), sh, false, Image.FORMAT_RGBA8)
		all.fill(Color(0.07, 0.07, 0.07))
		for i in strip.size():
			all.blit_rect(strip[i], Rect2i(0, 0, sw, sh), Vector2i(i * sw, 0))
		all.save_png(out_dir.path_join("paint_strip.png"))
	print("paint_preview_probe: done -> %s" % out_dir)
	get_tree().quit(0)


## The skin's color canvas [param canvas] laid over the bare surface [param bare] (linear) as prop.gdshader lays it: its color taken out of
## its coverage, decoded, and mixed over the bare by that coverage - an sRGB picture of the surface seen from its front.
static func _over_bare(canvas: Image, bare: Color) -> Image:
	var w := canvas.get_width()
	var h := canvas.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := canvas.get_pixel(x, y)
			var a := c.a
			var pc := Vector3(c.r, c.g, c.b) / a if a > 1e-4 else Vector3.ZERO
			pc = Vector3(pow(clampf(pc.x, 0.0, 1.0), 2.2), pow(clampf(pc.y, 0.0, 1.0), 2.2), pow(clampf(pc.z, 0.0, 1.0), 2.2))
			var d := Vector3(bare.r, bare.g, bare.b) * (1.0 - a) + pc * a
			out.set_pixel(x, y, Color(d.x, d.y, d.z).linear_to_srgb())
	return out


## How far picture [param img] stands from [param ref] (same size) where the reference is the surface: `Vector2(on average, the share more
## than 10 off)`, OKLab x 100.
static func _off(img: Image, ref: Image) -> Vector2:
	var sum := 0.0
	var n := 0
	var far := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var r := ref.get_pixel(x, y)
			if r.a < 0.5:
				continue
			var a := img.get_pixel(x, y).srgb_to_linear()
			var b := r.srgb_to_linear()
			var d := PaintLayers.lab(a.r, a.g, a.b).distance_to(PaintLayers.lab(b.r, b.g, b.b))
			sum += d
			n += 1
			far += 1 if d > 10.0 else 0
	return Vector2(sum / maxf(float(n), 1.0), float(far) / maxf(float(n), 1.0))
