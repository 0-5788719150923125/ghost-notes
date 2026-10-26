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
## THEM AS SPLATS (the note's renderer "gaussian": [SplatHead], next/likeness.md "A head of splats", "The whole of
## them", "The body as the still holds it"): their head and body over the avatar's own learned room, under what
## stands before them - the avatar as the Fit step left it (`fit`), its body fitted to one still, which is the
## one played; the still's 2D layer is not drawn.
var _renderer := "2d"
var _splat_layer: Node2D
var _splat: SplatHead = null
var _splat_crop := Vector2.ZERO
var _still_scores := PackedFloat32Array()
var _still_scale := 1.0
var _still_rot := Basis.IDENTITY
var _still_shift := Vector3.ZERO
var _shut := Vector2(0.8, 0.8)
## The still's bones (the Face rig's `poses.json`): where each stands, its axes, its unit, whether it is seen.
var _bone_at := PackedVector3Array()
var _bone_axes: Array = []
var _bone_unit := PackedFloat32Array()
var _bone_shown := PackedByteArray()
## Which of the 2D body's bones ([constant LikenessFace.BONES]) moves each splat bone (rig.py's BODY: the 2D
## ones less the head), and how surely a bone must be seen in the still for its splats to be drawn (train.py's SEEN).
const BONE_MOVES := [0, 2, 3, 4, 5, 6, 7, 8, 9]
const SEEN := 0.3
## The faces the player mixes, made once ([method SplatHead.face_of]): the still's, each sound's (their own mouth
## for it, from their rest, pushed past their own: [method own_mouths]), and the still's with the lids shut.
var _still_face := PackedFloat32Array()
var _class_faces := {}
var _shut_face := PackedFloat32Array()
var _look_faces := {}                 # glance -> the still's face looking that way (the Face rig's `looks`)
## ...and each one's expression, for the splats' own shifts ([method SplatHead.expr_of]), mixed alike.
var _still_expr := PackedFloat32Array()
var _class_exprs := {}
var _shut_expr := PackedFloat32Array()
var _look_exprs := {}
## THEIR FACE'S OWN WAYS OF MOVING as the splats take them ([method LikenessPlan.face]): each way's face and
## expression less the still's, made once a load.
var _way_faces: Array = []
var _way_exprs: Array = []
## How far past their own each sound's mouth is played (their mouth scarcely moves while they talk: a
## still's mouth shapes read as nothing): the actor's Articulation setting, as the 2D library's - never past how far
## their own lips part, nor a score past [constant TOP] of their own range (`visemes.json`'s `range`).
var _push := 2.0
const TOP := "99"
## The most a sound's mouth may turn any of the face's triangles from the face at rest, in degrees ([method unfolded]).
const FOLD_MOST := 40.0


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
	var avatar := sd.path_join("avatar").path_join("fit")
	if stills.is_empty() or not FileAccess.file_exists(avatar + ".json" if splats else sd.path_join("library.json")):
		return "The actor's set in use is not built yet: Generate on the Actor card builds it."
	var k := clampi(still, 0, stills.size() - 1)
	# A BODY FITTED TO ONE STILL is played on that still, until the one picked is fitted too (Generate)
	var fitted: Variant = ActorFolder.read_json(avatar + ".json") if splats else null
	if fitted is Dictionary and (fitted as Dictionary).has("still"):
		k = clampi(int((fitted as Dictionary)["still"]), 0, stills.size() - 1)
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
	_take_face_ways()
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


## THEM AS SPLATS from set folder [param sd], played from still [param k]: the avatar and its room, the still's
## pose, scores and bones, their eyes' shut score, glances and own mouth for each sound (the Face rig's `poses.json`;
## [method own_mouths], with `visemes.json` of the actor in [param dir]).
func _load_splat(sd: String, dir: String, k: int) -> String:
	if _splat == null:
		_splat = SplatHead.new()
		_splat_layer.add_child(_splat)
	var err := _splat.load_avatar(sd.path_join("avatar").path_join("fit"))
	if not err.is_empty():
		return "The actor's splats are not ready: %s. Generate on the Actor card makes them." % err
	var plate := _picture(sd.path_join("avatar").path_join("fit.plate.png"))
	if plate != null:
		_room.tex = plate
		_room.queue_redraw()
	_layer.visible = false
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
	_bone_at = PackedVector3Array()
	_bone_axes = []
	_bone_unit = PackedFloat32Array()
	_bone_shown = PackedByteArray()
	for bd in sp.get("bones", []):
		var o: Array = (bd as Dictionary)["origin"]
		var ax: Array = (bd as Dictionary)["axes"]
		_bone_at.append(Vector3(o[0], o[1], o[2]))
		_bone_axes.append(Basis(Vector3(ax[0][0], ax[0][1], ax[0][2]), Vector3(ax[1][0], ax[1][1], ax[1][2]),
			Vector3(ax[2][0], ax[2][1], ax[2][2])))
		_bone_unit.append(float((bd as Dictionary)["unit"]))
		_bone_shown.append(1 if float((bd as Dictionary)["seen"]) >= SEEN else 0)
	var a: Variant = ActorFolder.read_json(dir.path_join("actor.json"))
	_push = float(ActorSteps.settings_of((a as Dictionary).get("settings", {}) if a is Dictionary else {})["articulation"])
	var v: Variant = ActorFolder.read_json(dir.path_join("visemes.json"))
	var mouths: Variant = (poses as Dictionary).get("mouths")
	if not (v is Dictionary) or not (mouths is Dictionary) or not ((mouths as Dictionary).get("sounds") is Dictionary):
		return "The actor's set is from before their own mouths: Generate on the Actor card makes it again."
	_still_face = _splat.face_of(_still_scores)
	_still_expr = _splat.expr_of(_still_scores)
	# where the neck's splats stood: the still's frames, from which they take the torso's move
	_splat.hold_still(_still_face, _still_scale, _still_rot, _still_shift)
	var own := own_mouths(_splat, rest_mouth(_still_scores, v), mouths, _push, top_of(v))
	_class_faces = own["faces"]
	_class_exprs = own["exprs"]
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


## THE STILL'S SCORES WITH THEIR MOUTH AT REST: the mouth's scores of [param visemes] (`visemes.json`) at its "rest"
## sound's - where every sound's mouth moves from ([method own_mouths]), and silence.
static func rest_mouth(still: PackedFloat32Array, visemes: Dictionary) -> PackedFloat32Array:
	var out := still.duplicate()
	var names: Array = visemes.get("names", [])
	var rest: Array = ((visemes.get("classes", {}) as Dictionary).get("rest", {}) as Dictionary).get("blend", [])
	for j in mini(names.size(), rest.size()):
		var at := SplatHead.SCORES.find(String(names[j]))
		if at >= 0 and at < out.size():
			out[at] = clampf(float(rest[j]), 0.0, 1.0)
	return out


## THE MOST EACH SCORE MAY BE PUSHED TO: their own [constant TOP] percentile of each of the mouth's scores in
## [param visemes] (`range`), by its place among the 52.
static func top_of(visemes: Dictionary) -> Dictionary:
	var out := {}
	var names: Array = visemes.get("names", [])
	var r: Variant = visemes.get("range")
	var top: Array = (r as Dictionary).get(TOP, []) if r is Dictionary else []
	for j in mini(names.size(), top.size()):
		var at := SplatHead.SCORES.find(String(names[j]))
		if at >= 0:
			out[at] = float(top[j])
	return out


## THEIR OWN MOUTH FOR EACH SOUND (the Face rig's `mouths`, hosts/avatar/rig.py; 2026-10-25, the user: "The mouth
## shape barely moves" - played from each sound's scores through the basis, his lips parted 0.044 to 0.062 of his
## face's height while it spoke, his own 0.013 to 0.11): the face [param base] (the still's scores, its mouth at
## rest: [method rest_mouth]) moved by the sound's own move as their face made it - its points and its scores less
## their rest's - pushed [param push] times (Articulation), NEVER PAST HOW FAR THEIR OWN LIPS PART (`gap`, the 1st
## and 99th percentiles of the inner lips' parting over the face's height: a sound that opens stops at the most, one
## that closes at the least), its scores never past their own [param top] ([method top_of]), NOR FOLDING THE FACE
## ([method unfolded]). The expression is the pushed scores', as the face's.
## `{faces: {sound: face}, exprs: {sound: expression}, pushed: {sound: times}}`.
static func own_mouths(splat: SplatHead, base: PackedFloat32Array, mouths: Dictionary, push: float,
		top: Dictionary) -> Dictionary:
	var face := splat.face_of(base)
	var gap: Array = mouths.get("gap", [0.0, 1.0])
	var least := float(gap[0])
	var most := float(gap[1])
	var g0 := lips_parted(face)
	var out := {"faces": {}, "exprs": {}, "pushed": {}}
	var sounds: Dictionary = mouths.get("sounds", {})
	for c in sounds:
		var row: Dictionary = sounds[c]
		var move := PackedFloat32Array()
		for p in row.get("points", []):
			move.append_array(PackedFloat32Array([float(p[0]), float(p[1]), float(p[2])]))
		if move.size() != face.size():
			continue
		var moved := face.duplicate()
		_add(moved, move, 1.0)
		var g1 := lips_parted(moved)
		var k := push
		if g1 > g0 + 1e-6:
			k = minf(k, (most - g0) / (g1 - g0))
		elif g1 < g0 - 1e-6:
			k = minf(k, (g0 - least) / (g0 - g1))
		k = unfolded(splat.tris, face, move, maxf(k, 0.0))
		var f := face.duplicate()
		_add(f, move, k)
		var s := base.duplicate()
		var d: Array = row.get("blend", [])
		for j in mini(d.size(), s.size()):
			s[j] = clampf(s[j] + k * float(d[j]), 0.0, maxf(base[j], float(top.get(j, 1.0))))
		out["faces"][String(c)] = f
		out["exprs"][String(c)] = splat.expr_of(s)
		out["pushed"][String(c)] = k
	return out


## A SOUND'S MOUTH NEVER FOLDS THE FACE (2026-10-25, the user: "needle-like fractures throughout it, especially near
## the face, and especially noticeable when the face moves"): how far [param move] may push [param face] - at most
## [param k] times - before any of its triangles ([param tris]) turns past FOLD_MOST from the face's. A sound's own
## move is the median of their tracked points, and Articulation pushes all of it: on his set, their own mouths turn a
## triangle at most 27 degrees, and pushed three times the corners of the mouth crossed over themselves - P B M 118, F V
## 85, "open" 62 - and the splats bound there swung edge-on, streaks and specks along the beard's edges. Held to 40,
## "open" still parts the lips 0.105 of the face's height (their own 95th percentile, 0.11); P B M and F V stop near
## their own shape, pushed further only 2 to 3 pixels nearer closed. The most k within it, to 1/256 of it.
static func unfolded(tris: PackedInt32Array, face: PackedFloat32Array, move: PackedFloat32Array, k: float) -> float:
	var near: PackedInt32Array = []
	for t in tris.size() / 3:
		for c in 3:
			var at := tris[t * 3 + c] * 3
			if at + 2 < move.size() and absf(move[at]) + absf(move[at + 1]) + absf(move[at + 2]) > 0.0:
				near.append(t)
				break
	var turns := func(w: float) -> bool:
		for t in near:
			var a := tris[t * 3] * 3
			var b := tris[t * 3 + 1] * 3
			var c := tris[t * 3 + 2] * 3
			var p0 := Vector3(face[a], face[a + 1], face[a + 2])
			var p1 := Vector3(face[b], face[b + 1], face[b + 2])
			var p2 := Vector3(face[c], face[c + 1], face[c + 2])
			var n0 := (p1 - p0).cross(p2 - p0).normalized()
			p0 += w * Vector3(move[a], move[a + 1], move[a + 2])
			p1 += w * Vector3(move[b], move[b + 1], move[b + 2])
			p2 += w * Vector3(move[c], move[c + 1], move[c + 2])
			var n1 := (p1 - p0).cross(p2 - p0).normalized()
			if rad_to_deg(acos(clampf(n0.dot(n1), -1.0, 1.0))) > FOLD_MOST:
				return true
		return false
	if not turns.call(k):
		return k
	var lo := 0.0
	var hi := k
	for _i in 8:
		var mid := 0.5 * (lo + hi)
		if turns.call(mid):
			hi = mid
		else:
			lo = mid
	return lo


## How far the inner lips of face [param v] (its points, three numbers each) part, over the face's height (the
## forehead's top, MediaPipe's 10, to the chin, 152) - as the Face rig measures their own (`gap`).
static func lips_parted(v: PackedFloat32Array) -> float:
	var p := func(i: int) -> Vector3: return Vector3(v[i * 3], v[i * 3 + 1], v[i * 3 + 2])
	return (p.call(13) - p.call(14)).length() / maxf((p.call(10) - p.call(152)).length(), 1e-6)


## Each of their face's own ways of moving ([member LikenessPlan.face_basis]) as a face and an expression less the
## still's - the rig and the expressions are linear in the scores, so a moment mixes them by how far along each.
func _take_face_ways() -> void:
	_way_faces = []
	_way_exprs = []
	if _splat == null or _renderer != "gaussian":
		return
	for b in _plan.face_basis:
		var s := _still_scores.duplicate()
		for i in mini(_plan.face_names.size(), (b as PackedFloat32Array).size()):
			var at := SplatHead.SCORES.find(_plan.face_names[i])
			if at >= 0 and at < s.size():
				s[at] += (b as PackedFloat32Array)[i]
		var f := _splat.face_of(s)
		var x := _splat.expr_of(s)
		for j in f.size():
			f[j] -= _still_face[j]
		for j in x.size():
			x[j] -= _still_expr[j]
		_way_faces.append(f)
		_way_exprs.append(x)


func _drop_splat() -> String:
	if _splat != null:
		_splat.queue_free()
		_splat = null
	_layer.visible = true
	return ""


## THEM AS SPLATS AT [param t]: their face - the still's own, moved toward each sound shaping the mouth by its
## share ([method LikenessPlan.mouth_mix]: every pull, smoothed; its face made once, their own mouth for it pushed
## past their own by Articulation, silence their mouth at rest), moved its own ways as their face moved ([method LikenessPlan.face]), toward the lids shut
## as far as the blink, toward a glance - the head as the still holds it, turned by their motion [param moved] about
## the neck and carried by the torso; and their body's bones as the still holds them, each moved as the 2D body's
## bone is ([param moves]: [method LikenessFace.bones]).
func _pose_splat(t: float, moved: PackedFloat32Array, moves: Array) -> void:
	var v := _still_face.duplicate()
	var e := _still_expr.duplicate()
	var mix := _plan.mouth_mix(t)
	for c in mix:
		var w := float(mix[c])
		if w > 1e-3 and _class_faces.has(c):
			_toward(v, _class_faces[c], _still_face, w)
			_toward(e, _class_exprs[c], _still_expr, w)
	# THEIR FACE'S OWN MOTION: brows, lids, cheeks and the mouth's corners as they moved with the head's piece
	var ways := _plan.face(t)
	for k in mini(ways.size(), _way_faces.size()):
		if absf(ways[k]) > 1e-4:
			_add(v, _way_faces[k], ways[k])
			_add(e, _way_exprs[k], ways[k])
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
	var to_crop := Transform2D(0.0, -_splat_crop)
	var torso: Transform2D = moves[0] if not moves.is_empty() else Transform2D.IDENTITY
	_splat.pose_face(v, _still_scale, turn * _still_rot, pv + turn * (_still_shift - pv), to_crop * torso * to_crop.affine_inverse())
	var bone_moves: Array = []
	for m in BONE_MOVES:
		bone_moves.append(to_crop * (moves[m] if m < moves.size() else Transform2D.IDENTITY) * to_crop.affine_inverse())
	_splat.pose_bones(_bone_at, _bone_axes, _bone_unit, bone_moves, _bone_shown)
	_splat.upload()
	_splat.transform = Transform2D(0.0, _splat_crop)


## [param v] moved by [param w] of [param d], in place.
static func _add(v: PackedFloat32Array, d: PackedFloat32Array, w: float) -> void:
	for j in mini(v.size(), d.size()):
		v[j] += w * d[j]


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
		_pose_splat(t, moved, bones)
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
