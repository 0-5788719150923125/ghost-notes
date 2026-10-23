extends Medium
class_name LikenessMedium

## LikenessMedium - an actor reads the note, in their own room (next/likeness.md, "The second build"):
## ONE STILL OF THEM and a model of how they move - their head's own motion, their blinks, their mouths
## for the voice's sounds ([LikenessPlan]). Every pixel of them is a real pixel of theirs, bent; no footage
## plays, so no hand, prop or jump cut is ever seen (2026-10-21, the user on the first build: "the random
## gestures and the globe and such, which are cropped by the jump-cuts").
##
## WHAT IT DRAWS FROM: the reading's document (`_subs.document`) carries `likeness` - the actor's folder,
## the set, the still, the seed - which the Actor card hands the reading ([ActorCard.Publish]); the words
## and the phones come from the voice as they are said (`_subs.words`, `_subs.phones`). The set's files
## and the actor's motion are the Actor's ([ActorFolder], [ActorSteps]).
##
## THEM OVER THEIR ROOM (the third pass, 2026-10-22: "The region around the head smears quite a lot ... on
## the wall, and on the picture on the wall especially"): the room drawn first, still - the still's own
## room, and behind them the room the set's frames showed ([member _room]) - and them over it, cut out by
## their matte, through ONE MESH WITH ONE CANVAS SHADER ([LikenessFace], likeness_warp.gdshader): the head
## turned on the neck, the body carrying it, the lips and lids bent to the mouths and eyes drawn in where
## their own were. What their moving uncovers is the room, never the wall stretched.
##
## WHAT STANDS BEFORE THEM IS DRAWN OVER THEM, still (the fourth pass, 2026-10-22: their bones bend them,
## and a microphone left in their matte bent with them): the still's `front_K.png` - the things that never
## move and hide them - over everything, and under it their picture filled from round it (`body_K.jpg`), so
## they move behind it.
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
var _room: Room
var _layer: Warp
var _front: Room
var _note: Label
var _still_tex: ImageTexture = null
var _matte_tex: ImageTexture = null
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
## A HEAD OF SPLATS (the note's renderer "gaussian": [SplatHead], next/likeness.md "A head of splats"): drawn
## over their body, under what stands before them, from the set's avatar; the 2D mouth and eyes are not drawn.
var _renderer := "2d"
var _splat_layer: Node2D
var _splat: SplatHead = null
var _splat_crop := Vector2.ZERO
var _class_scores := {}               # sound class -> the 52 scores of their mouth for it
var _mouth_scores := PackedInt32Array()   # which of the 52 a sound sets
var _still_scores := PackedFloat32Array()
var _still_scale := 1.0
var _still_rot := Basis.IDENTITY
var _still_shift := Vector3.ZERO
var _shut := Vector2(0.8, 0.8)
var _head_cut: ImageTexture = null
## The faces the player mixes, made once ([method SplatHead.face_of]): the still's, each sound's (its mouth
## pushed past their own), and the still's with the lids shut.
var _still_face := PackedFloat32Array()
var _class_faces := {}
var _shut_face := PackedFloat32Array()
var _look_faces := {}                 # glance -> the still's face looking that way (the Face rig's `looks`)
## ...and each one's expression, for the splats' own shifts ([method SplatHead.expr_of]), mixed alike.
var _still_expr := PackedFloat32Array()
var _class_exprs := {}
var _shut_expr := PackedFloat32Array()
var _look_exprs := {}
## How far past their own each sound's mouth is played (their mouth scarcely moves while they talk: a
## still's mouth shapes read as nothing): the actor's Articulation setting, as the 2D library's.
var _push := 2.0


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


## THE ROOM, behind them: a picture of the frame's size, drawn where the layer is.
class Room extends Node2D:
	var tex: ImageTexture = null

	func _draw() -> void:
		if tex != null:
			draw_texture(tex, Vector2.ZERO)


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
	_room = Room.new()
	add_child(_room)
	_layer = Warp.new()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_layer.material = mat
	add_child(_layer)
	_splat_layer = Node2D.new()
	add_child(_splat_layer)
	_front = Room.new()
	add_child(_front)
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
	for n in [_room, _layer, _splat_layer, _front]:
		(n as Node2D).scale = Vector2(k, k)
		(n as Node2D).position = (sz - src * k) * 0.5
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


## UP FROM BLACK ACROSS THE INTRO, arriving as the held silence ends, as every picture's does ([method
## Director._bookend_fade]; 2026-10-22, the user: "The fade-in/fade-out from the 'intro & outro' component
## does not appear to work here" - it rose in its first second, then sat through the rest), and down to
## it after the last word, black as the outro runs out.
func _brightness(t: float) -> float:
	return clampf(clampf(t / maxf(1.0, feed.lead()), 0.0, 1.0)
		* ShowOpening.end_fade(_now, _follower, _spoken_n, feed.tail()) * feed.live_fade, 0.0, 1.0)


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
	var key := "%s|%s|%d|%d|%d|%s|%s" % [String(lk.get("dir", "")), String(lk.get("set", "")), int(lk.get("still", 0)),
		int(lk.get("seed", 1)), src.hash(), " ".join(start), String(lk.get("renderer", "2d"))]
	if key == _doc_key:
		return
	_doc_key = key
	var err := load_set(String(lk.get("dir", "")), String(lk.get("set", "")), int(lk.get("still", 0)), int(lk.get("seed", 1)),
		String(lk.get("renderer", "2d")))
	_ready_set = err.is_empty()
	_why = err
	load_text(src, start, int(d.get("start_index", -1)))


## LOAD THE SET [param sid] of the actor in [param dir], drawn on its still [param still] by [param renderer]: ""
## when it can be played, else why not. Public for a probe, which hands it one by hand.
func load_set(dir: String, sid: String, still: int, seed_in: int, renderer := "2d") -> String:
	if dir.is_empty() or sid.is_empty():
		return "This Likeness has no actor to play yet: build one on the Actor card."
	var sd := dir.path_join("sets").path_join(sid)
	var st: Variant = ActorFolder.read_json(sd.path_join("stills.json"))
	var stills: Array = (st as Dictionary).get("stills", []) if st is Dictionary else []
	var splats := renderer == "gaussian"
	var avatar := sd.path_join("avatar").path_join("avatar")
	if stills.is_empty() or not FileAccess.file_exists(avatar + ".json" if splats else sd.path_join("library.json")):
		return "The actor's set in use is not built yet: Generate on the Actor card builds it."
	var k := clampi(still, 0, stills.size() - 1)
	var made := "%s|%d|%d|%d|%d|%s|%d" % [sd, k, FileAccess.get_modified_time(sd.path_join("rig.json")),
		FileAccess.get_modified_time(sd.path_join("library.json")), FileAccess.get_modified_time(sd.path_join("stills.json")),
		renderer, FileAccess.get_modified_time(avatar + ".bin")]
	if made != _loaded:
		_loaded = ""
		_renderer = renderer
		var err := _face.load_set(sd.path_join("rig.json"), sd.path_join("library.json"), not splats)
		if not err.is_empty():
			return "The actor is not ready: %s. Generate on the Actor card builds it." % err
		_face.set_still(stills[k], k)
		var st_k: Dictionary = stills[k]
		# THEIR PICTURE: the still, filled from round what stands before them where something does
		var body := sd.path_join("stills").path_join(String(st_k.get("body", "")))
		var img := Image.load_from_file(body) if st_k.has("body") and FileAccess.file_exists(body) else null
		if img == null:
			img = Image.load_from_file(sd.path_join("stills").path_join(String(st_k["file"])))
		if img == null:
			return "The actor's still could not be read: Generate on the Actor card makes it again."
		img.convert(Image.FORMAT_RGBA8)
		_still_tex = ImageTexture.create_from_image(img)
		# THEIR ROOM AND MATTE (a still from before the third pass has neither: drawn whole, as it was)
		_room.tex = _picture(sd.path_join("stills").path_join(String(st_k.get("room", ""))))
		_matte_tex = _mask(sd.path_join("stills").path_join(String(st_k.get("matte", ""))))
		if _room.tex == null:
			_matte_tex = null
		_room.queue_redraw()
		_front.tex = _picture(sd.path_join("stills").path_join(String(st_k.get("front", "")))) if _matte_tex != null else null
		_front.queue_redraw()
		_mask_mouth = _mask(_face.mask_mouth)
		_mask_eyes = _mask(_face.mask_eyes)
		_load_library()
		var e3 := _load_splat(sd, dir, k) if splats else _drop_splat()
		if not e3.is_empty():
			return e3
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


## THE HEAD OF SPLATS of set folder [param sd], played from still [param k]: the avatar, the still's pose and
## scores, their eyes' shut score (the Face rig's `poses.json`), and each sound's mouth as scores (`visemes.json`
## of the actor in [param dir]: its mouth's scores over the still's own).
func _load_splat(sd: String, dir: String, k: int) -> String:
	if _splat == null:
		_splat = SplatHead.new()
		_splat_layer.add_child(_splat)
	var err := _splat.load_avatar(sd.path_join("avatar").path_join("avatar"))
	if not err.is_empty():
		return "The actor's head is not ready: %s. Generate on the Actor card makes it." % err
	var poses: Variant = ActorFolder.read_json(sd.path_join("avatar").path_join("poses.json"))
	var stills: Array = (poses as Dictionary).get("stills", []) if poses is Dictionary else []
	if k >= stills.size() or not (stills[k] is Dictionary):
		return "The actor's head was not found in this still: pick another on the Actor card."
	var sp: Dictionary = stills[k]
	_still_scale = float(sp["scale"])
	var r: Array = sp["rot"]
	_still_rot = Basis(Vector3(r[0][0], r[1][0], r[2][0]), Vector3(r[0][1], r[1][1], r[2][1]), Vector3(r[0][2], r[1][2], r[2][2]))
	var sh: Array = sp["shift"]
	_still_shift = Vector3(sh[0], sh[1], sh[2])
	_still_scores = PackedFloat32Array(sp["blend"])
	var shut: Array = (poses as Dictionary).get("shut", [0.8, 0.8])
	_shut = Vector2(float(shut[0]), float(shut[1]))
	_splat_crop = Vector2(_splat.crop[0], _splat.crop[1])
	_splat.position = _splat_crop
	_splat.visible = true
	_head_cut = _cut_of(_face.still_face, _face.size)
	_class_scores = {}
	_mouth_scores = PackedInt32Array()
	var a: Variant = ActorFolder.read_json(dir.path_join("actor.json"))
	_push = float(ActorSteps.settings_of((a as Dictionary).get("settings", {}) if a is Dictionary else {})["articulation"])
	var v: Variant = ActorFolder.read_json(dir.path_join("visemes.json"))
	if v is Dictionary:
		var names: Array = (v as Dictionary).get("names", [])
		for n in names:
			_mouth_scores.append(SplatHead.SCORES.find(String(n)))
		var classes: Dictionary = (v as Dictionary).get("classes", {})
		for c in classes:
			var b: Array = (classes[c] as Dictionary).get("blend", [])
			var out := _still_scores.duplicate()
			for j in mini(b.size(), _mouth_scores.size()):
				var at := _mouth_scores[j]
				if at >= 0:
					out[at] = clampf(_still_scores[at] + (float(b[j]) - _still_scores[at]) * _push, 0.0, 1.0)
			_class_scores[String(c)] = out
	_still_face = _splat.face_of(_still_scores)
	_still_expr = _splat.expr_of(_still_scores)
	_class_faces = {}
	_class_exprs = {}
	for c in _class_scores:
		_class_faces[c] = _splat.face_of(_class_scores[c])
		_class_exprs[c] = _splat.expr_of(_class_scores[c])
	var closed := _still_scores.duplicate()
	closed[9] = _shut.x
	closed[10] = _shut.y
	_shut_face = _splat.face_of(closed)
	_shut_expr = _splat.expr_of(closed)
	_look_faces = {}
	_look_exprs = {}
	var looks: Dictionary = (poses as Dictionary).get("looks", {})
	for g in looks:
		var d: Array = looks[g]
		var look := _still_scores.duplicate()
		for j in mini(d.size(), look.size()):
			look[j] = clampf(look[j] + float(d[j]), 0.0, 1.0)
		_look_faces[String(g)] = _splat.face_of(look)
		_look_exprs[String(g)] = _splat.expr_of(look)
	return ""


func _drop_splat() -> String:
	if _splat != null:
		_splat.queue_free()
		_splat = null
	_head_cut = null
	return ""


## WHERE THE STILL'S HEAD IS CUT OUT under a head of splats, in its own picture's terms: the trainer's region
## above the mouth (hosts/avatar/train.py, `Frames._reach`) - an ellipse round the face grown up for the hair
## and out for the ears, feathered - drawn from the still's face points [param face] at a quarter of [param size].
static func _cut_of(face: PackedVector2Array, size: Vector2) -> ImageTexture:
	if face.size() < 292:
		return null
	var lo := Vector2(INF, INF)
	var hi := -lo
	for i in mini(468, face.size()):
		lo = lo.min(face[i])
		hi = hi.max(face[i])
	var w := hi.x - lo.x
	var h := hi.y - lo.y
	var mouth_y := (face[61].y + face[291].y) * 0.5
	var top := lo.y - 0.45 * h
	var c := Vector2((lo.x + hi.x) * 0.5, (top + hi.y) * 0.5)
	var r := Vector2(0.95 * w, (hi.y - top) * 0.5)
	var q := 4.0
	var iw := int(ceil(size.x / q))
	var ih := int(ceil(size.y / q))
	var img := Image.create(iw, ih, false, Image.FORMAT_L8)
	for y in ih:
		var py := (float(y) + 0.5) * q
		if py >= mouth_y:
			continue
		for x in iw:
			var d := (Vector2((float(x) + 0.5) * q, py) - c) / r
			var v := clampf((1.08 - d.length()) / 0.08, 0.0, 1.0)
			if v > 0.0:
				img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)


## THE HEAD OF SPLATS AT [param t]: their face - the still's own, moved toward each sound pulling at the mouth
## by its pull (its face made once, the mouth pushed past their own by Articulation) and toward the lids shut
## as far as the blink - and the head as the still holds it, turned by their motion [param moved] about the
## neck, carried by the torso ([param torso]).
func _pose_splat(t: float, moved: PackedFloat32Array, torso: Transform2D) -> void:
	var v := _still_face.duplicate()
	var e := _still_expr.duplicate()
	for p in _plan.pulls(t):
		var w := float(p[2])
		if w > 1e-4 and _class_faces.has(String(p[1])):
			_toward(v, _class_faces[String(p[1])], _still_face, w)
			_toward(e, _class_exprs[String(p[1])], _still_expr, w)
	var b := clampf(_plan.blink(t).x, 0.0, 1.0)
	if b > 1e-4:
		_toward(v, _shut_face, _still_face, b)
		_toward(e, _shut_expr, _still_expr, b)
	# A GLANCE: toward the face looking that way, as far as the glance has gone
	var g := _plan.glance(t)
	var gw := float(g[1]) if g.size() > 1 else 0.0
	if gw > 1e-4 and _look_faces.has(String(g[0])):
		_toward(v, _look_faces[String(g[0])], _still_face, gw)
		_toward(e, _look_exprs[String(g[0])], _still_expr, gw)
	_splat.set_expr(e)
	var turn := Basis.IDENTITY
	if moved.size() >= 3:
		turn = Basis.from_euler(Vector3(deg_to_rad(-moved[1]), deg_to_rad(moved[0]), deg_to_rad(moved[2])))
	var pv := _face.pivot() - Vector3(_splat_crop.x, _splat_crop.y, 0.0)
	_splat.pose_face(v, _still_scale, turn * _still_rot, pv + turn * (_still_shift - pv))
	_splat.transform = torso * Transform2D(0.0, _splat_crop)


## [param v] moved [param w] of the way from [param from] toward [param to], in place.
static func _toward(v: PackedFloat32Array, to: PackedFloat32Array, from: PackedFloat32Array, w: float) -> void:
	for j in mini(v.size(), mini(to.size(), from.size())):
		v[j] += w * (to[j] - from[j])


static func _mask(path: String) -> ImageTexture:
	var img := Image.load_from_file(path) if FileAccess.file_exists(path) and not path.ends_with("/") else null
	return ImageTexture.create_from_image(img) if img != null else null


static func _picture(path: String) -> ImageTexture:
	var img := Image.load_from_file(path) if FileAccess.file_exists(path) and not path.ends_with("/") else null
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(img)


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

## DRAW SHOW TIME [param t]: them, their body posed on its bones and their head turned on it, their lips and
## lids bent to the mouth and eyes the plan says there, those drawn in - over the room. Public for a probe.
func draw_at(t: float) -> void:
	if _still_tex == null:
		return
	var mouth := _plan.mouth(t)
	var eyes := _plan.eyes(t)
	var moved := _plan.motion(t)
	var posed := _face.pose(moved)
	var bones := _face.bones(posed, moved, _plan.breath(t), _plan.lifts(t), _plan.hands(t))
	_layer.points = _face.vertices(posed, _face.target(posed, mouth, eyes), bones)
	var mat := _layer.material as ShaderMaterial
	mat.set_shader_parameter("matte", _matte_tex)
	mat.set_shader_parameter("matte_on", 1.0 if _matte_tex != null else 0.0)
	var splats := _renderer == "gaussian" and _splat != null and _splat.splats > 0
	if splats:
		_pose_splat(t, moved, bones[0] as Transform2D)
	mat.set_shader_parameter("head_cut", _head_cut)
	mat.set_shader_parameter("head_cut_on", 1.0 if splats and _head_cut != null and _matte_tex != null else 0.0)
	var on := not splats and _library_tex != null and _mask_mouth != null and _mask_eyes != null
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
