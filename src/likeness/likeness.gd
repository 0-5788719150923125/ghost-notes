extends Medium
class_name LikenessMedium

## LikenessMedium - an actor reads the note, in their own room (next/likeness.md, "The second build"):
## ONE STILL OF THEM and a model of how they move - their head's own motion, their blinks, their mouths
## for the voice's sounds ([LikenessPlan]). Every pixel of them is a real pixel of theirs, bent; no footage
## plays, so no hand, prop or jump cut is ever seen (2026-10-21, the user on the first build: "the random
## gestures and the globe and such, which are cropped by the jump-cuts").
##
## WHAT IT DRAWS FROM: the reading's document (`_subs.document`) carries `likeness` - the actor's folder,
## the set, the still, the seed - which the Likeness card hands the reading ([LikenessCard]); the words
## and the phones come from the voice as they are said (`_subs.words`, `_subs.phones`). The set's files
## and the actor's motion are the Actor's ([ActorFolder], [ActorSteps]).
##
## ONE MESH OVER THE WHOLE FRAME, DRAWN WITH ONE CANVAS SHADER ([LikenessFace], likeness_warp.gdshader):
## the still read through the mesh, the face turned by the head's motion, the lips and lids bent to the
## mouths and eyes drawn in where their own were.
##
## A PURE FUNCTION OF THE SHOW'S TIME: what is drawn at a moment depends on the plan and the phones, never
## on what was drawn before - so a seek lands where it should and an export draws what was heard.

const SHADER := preload("res://src/likeness/likeness_warp.gdshader")

var _subs = null
var _doc_key := ""
var _ready_set := false
var _why := ""
var _face := LikenessFace.new()
var _plan := LikenessPlan.new()
var _follower := ReadingFollower.new()
var _spoken_n := 0
var _built_n := -1
var _phones_n := -1
var _now := 0.0
var _tried_ms := 0                 # when a set that was not ready was last tried

var _back: Node2D
var _layer: Warp
var _note: Label
var _still_tex: ImageTexture = null
var _library_tex: Texture2DArray = null
var _library_task := -1
var _library_box: Array = []
var _mask_mouth: ImageTexture = null
var _mask_eyes: ImageTexture = null
## THE SET AND STILL LOADED, kept from one Play to the next: the library is a texture of tens of images
## and the still a full frame, both decoded once. Its files' times are in it, so a set made again is
## loaded again.
var _loaded := ""
var _placeholder: GhostScene


## One drawing of the mesh: the still, read through it.
class Warp extends Node2D:
	var tex: ImageTexture = null
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func _draw() -> void:
		if tex == null or points.is_empty() or indices.is_empty():
			return
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors, uvs,
			PackedInt32Array(), PackedFloat32Array(), tex.get_rid())


## The black behind the frame, where the stage is not the still's shape.
class Back extends Node2D:
	var area := Vector2(1920, 1080)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, area), Color.BLACK)


# --- mount ---------------------------------------------------------------------------------------

func mount(st: SubViewport) -> void:
	super.mount(st)
	_placeholder = GhostScene.new()
	_placeholder.init_with_seed(1, "drift")
	_placeholder.visible = false
	add_child(_placeholder)
	_back = Back.new()
	add_child(_back)
	_layer = Warp.new()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_layer.material = mat
	add_child(_layer)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 28)
	_note.modulate = Color(1, 1, 1, 0.75)
	add_child(_note)
	on_stage_resized(Vector2(st.size))


func begin_session() -> void:
	_doc_key = ""


func release() -> void:
	_subs = null
	_doc_key = ""
	if _library_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_library_task)
		_library_task = -1


# --- the Medium contract --------------------------------------------------------------------------

func owns_cast() -> bool:
	return true


func take_over(_outgoing: GhostScene) -> GhostScene:
	return _placeholder


func owns_bookend() -> bool:
	return true


## The words stay the overlay's to show.
func bind_captions(subs) -> bool:
	_subs = subs
	_doc_key = ""
	return false


func on_stage_resized(sz: Vector2) -> void:
	if _back == null:
		return
	_back.area = sz
	_back.queue_redraw()
	var src := _face.size if _ready_set else Vector2(1920, 1080)
	var k := minf(sz.x / src.x, sz.y / src.y)
	_layer.scale = Vector2(k, k)
	_layer.position = (sz - src * k) * 0.5
	_note.position = Vector2(sz.x * 0.1, sz.y * 0.3)
	_note.size = Vector2(sz.x * 0.8, sz.y * 0.4)


func advance(_features, _delta: float, _bookend: float) -> void:
	var t := maxf(feed.show_time(), 0.0)
	_ensure_doc()
	_now = _subs.now() if _subs != null and is_instance_valid(_subs) else t
	_note.visible = not _ready_set
	if not _ready_set:
		# AN ACTOR STILL BEING MADE is tried again every few seconds: its set may be ready now
		if Time.get_ticks_msec() - _tried_ms > 3000:
			_tried_ms = Time.get_ticks_msec()
			_doc_key = ""
		_note.text = _why
		_layer.points = PackedVector2Array()
		_layer.queue_redraw()
		return
	_take_voice()
	_land_library()
	modulate = Color.WHITE * _brightness(t)
	modulate.a = 1.0
	draw_at(_now)


## UP FROM BLACK as the session starts, and down to it after the last word, over the outro.
func _brightness(t: float) -> float:
	return clampf(clampf(t / 1.0, 0.0, 1.0) * ShowOpening.end_fade(_now, _follower, _spoken_n, feed.tail())
		* feed.live_fade, 0.0, 1.0)


# --- the document: which actor, which set, which still ---------------------------------------------

func _ensure_doc() -> void:
	if _subs == null or not is_instance_valid(_subs):
		if _doc_key.is_empty():
			_doc_key = "none"
			_ready_set = false
			_why = "A Likeness plays while the note is read: press Play."
		return
	var d: Dictionary = _subs.document
	var lk: Dictionary = d.get("likeness", {}) if d.get("likeness") is Dictionary else {}
	var src := String(d.get("source", ""))
	var start: PackedStringArray = d.get("start_words", PackedStringArray()) \
		if d.get("start_words") is PackedStringArray else PackedStringArray()
	var key := "%s|%s|%d|%d|%d|%s" % [String(lk.get("dir", "")), String(lk.get("set", "")), int(lk.get("still", 0)),
		int(lk.get("seed", 1)), src.hash(), " ".join(start)]
	if key == _doc_key:
		return
	_doc_key = key
	var err := load_set(String(lk.get("dir", "")), String(lk.get("set", "")), int(lk.get("still", 0)), int(lk.get("seed", 1)))
	_ready_set = err.is_empty()
	_why = err
	load_text(src, start, int(d.get("start_index", -1)))


## LOAD THE SET [param sid] of the actor in [param dir], drawn on its still [param still]: "" when it can
## be played, else why not. Public for a probe, which hands it one by hand.
func load_set(dir: String, sid: String, still: int, seed_in: int) -> String:
	if dir.is_empty() or sid.is_empty():
		return "This Likeness has no actor to play yet: build one on the Actor card."
	var sd := dir.path_join("sets").path_join(sid)
	var st: Variant = ActorFolder.read_json(sd.path_join("stills.json"))
	var stills: Array = (st as Dictionary).get("stills", []) if st is Dictionary else []
	if stills.is_empty() or not FileAccess.file_exists(sd.path_join("library.json")):
		return "The actor's set in use is not built yet: Generate on the Actor card builds it."
	var k := clampi(still, 0, stills.size() - 1)
	var made := "%s|%d|%d|%d|%d" % [sd, k, FileAccess.get_modified_time(sd.path_join("rig.json")),
		FileAccess.get_modified_time(sd.path_join("library.json")), FileAccess.get_modified_time(sd.path_join("stills.json"))]
	if made != _loaded:
		_loaded = ""
		var err := _face.load_set(sd.path_join("rig.json"), sd.path_join("library.json"))
		if not err.is_empty():
			return "The actor is not ready: %s. Generate on the Actor card builds it." % err
		_face.set_still(stills[k])
		var img := Image.load_from_file(sd.path_join("stills").path_join(String((stills[k] as Dictionary)["file"])))
		if img == null:
			return "The actor's still could not be read: Generate on the Actor card makes it again."
		img.convert(Image.FORMAT_RGBA8)
		_still_tex = ImageTexture.create_from_image(img)
		_mask_mouth = _mask(_face.mask_mouth)
		_mask_eyes = _mask(_face.mask_eyes)
		_load_library()
		_loaded = made
	var err2 := _plan.setup(dir.path_join("motion.json"), _face, seed_in)
	if not err2.is_empty():
		return "The actor is not ready: %s. Generate on the Actor card makes it." % err2
	var colors := PackedColorArray()
	for uv in _face.lay_uv:
		colors.append(Color(uv.x, uv.y, 0.0, 1.0))
	_layer.colors = colors
	_layer.indices = _face.triangles
	_layer.tex = _still_tex
	_layer.uvs = _face.base_uvs()
	_phones_n = -1
	if stage != null:
		on_stage_resized(Vector2(stage.size))
	return ""


static func _mask(path: String) -> ImageTexture:
	var img := Image.load_from_file(path) if FileAccess.file_exists(path) else null
	return ImageTexture.create_from_image(img) if img != null else null


## THE LIBRARY'S IMAGES as one texture array, decoded on a worker: the mouth and eyes are drawn once it
## is in (an export decodes them in step).
func _load_library() -> void:
	_library_tex = null
	var files := _face.files.duplicate()
	var box: Array = []
	_library_box = box
	if not Engine.get_write_movie_path().is_empty():
		box.append_array(_decode(files))
		_land_library()
		return
	_library_task = WorkerThreadPool.add_task(func() -> void: box.append_array(_decode(files)), false, "likeness library")


static func _decode(files: Array) -> Array:
	var out: Array = []
	for f in files:
		var img := Image.load_from_file(String(f))
		if img == null:
			return []
		if img.get_format() != Image.FORMAT_RGB8:
			img.convert(Image.FORMAT_RGB8)
		out.append(img)
	return out


func _land_library() -> void:
	if _library_tex != null:
		return
	if _library_task >= 0:
		if not WorkerThreadPool.is_task_completed(_library_task):
			return
		WorkerThreadPool.wait_for_task_completion(_library_task)
		_library_task = -1
	if _library_box.is_empty():
		return
	var arr := Texture2DArray.new()
	if arr.create_from_images(_library_box) == OK:
		_library_tex = arr
	_library_box = []


## THE TEXT'S SPOKEN WORDS, for the follower that times the end's fade. Public for a probe.
func load_text(source: String, start := PackedStringArray(), near := -1) -> void:
	var spoken := PackedStringArray()
	for w in Manuscript.unspoken(Manuscript.strip_frontmatter(source)).split(" ", false):
		for piece in String(w).split("\n", false):
			var n := TabletScript.norm(String(piece))
			if not n.is_empty():
				spoken.append(n)
	_spoken_n = spoken.size()
	var from := TabletScript.find_run(spoken, start, near) if not start.is_empty() else -1
	_follower.reset(spoken, from)
	_built_n = -1


## THE VOICE SO FAR: its words to the follower, its phones to the plan when more have come.
func _take_voice() -> void:
	if _subs == null or not is_instance_valid(_subs):
		return
	var words: Array = _subs.words
	if words.size() != _built_n:
		_built_n = words.size()
		_follower.extend(words)
	var phones: Array = _subs.get("phones") if _subs.get("phones") is Array else []
	if phones.size() != _phones_n:
		_phones_n = phones.size()
		_plan.set_voice(phones)


# --- drawing --------------------------------------------------------------------------------------

## DRAW SHOW TIME [param t]: the still, its head turned, its lips and lids bent to the mouth and eyes the
## plan says there, those drawn in. Public for a probe.
func draw_at(t: float) -> void:
	if _still_tex == null:
		return
	var mouth := _plan.mouth(t)
	var eyes := _plan.eyes(t)
	var posed := _face.pose(_plan.head(t))
	_layer.points = _face.vertices(posed, _face.target(posed, mouth, eyes))
	var mat := _layer.material as ShaderMaterial
	var on := _library_tex != null and _mask_mouth != null and _mask_eyes != null
	mat.set_shader_parameter("library_on", 1.0 if on else 0.0)
	if on:
		mat.set_shader_parameter("library", _library_tex)
		mat.set_shader_parameter("mouth_mask", _mask_mouth)
		mat.set_shader_parameter("eye_mask", _mask_eyes)
		_layers_of(mat, "m", mouth)
		_layers_of(mat, "e", eyes)
	_layer.queue_redraw()


## Hand the shader [param mix]'s library images (the still's own, -1, is what their weights leave).
func _layers_of(mat: ShaderMaterial, p: String, mix: Array) -> void:
	var layers := Vector2.ZERO
	var weights := Vector2.ZERO
	var k := 0
	for e in mix:
		var img := int(e[0])
		if img < 0 or k > 1:
			continue
		layers[k] = float(img)
		weights[k] = float(e[1])
		var matched := _face.match_light(img)
		mat.set_shader_parameter("%s_gain%d" % [p, k], matched[0])
		mat.set_shader_parameter("%s_off%d" % [p, k], matched[1])
		k += 1
	mat.set_shader_parameter("%s_layers" % p, layers)
	mat.set_shader_parameter("%s_weights" % p, weights)
