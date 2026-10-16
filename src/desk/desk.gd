extends Medium
class_name DeskMedium

## DeskMedium - a ghost doing math at a desk: a legal pad under a lamp, and a pen that writes on it
## by itself while the teacher talks (next/proof.md, "The desk").
##
## WHAT IT DRAWS FROM: the reading's document (`_subs.document`) - its `source`, the lesson with the
## pen's marks ([DeskScript]), and its `desk`, what the Proof component hands the reading
## ([method ProofEpisode.document]): every formula as TeX laid it out (`ink`, the typeset answer of
## hosts/math/typeset.py) and the episode's seed, which is the hand's.
##
## A PURE FUNCTION OF THE VOICE'S TIME. The voice's words arrive with their times
## ([ReadingFollower]); each pen action is placed in the rest the voice left for it
## ([method ReadingFollower.place]) and then runs at the pen's own pace, under the words that follow
## (a teacher writes while talking - [DeskScript]). A pad item is written by [Ink] at `now - start`,
## so any moment can be drawn without the ones before it: a seek lands on the page as it was. The
## camera alone eases (as the tablet's does), and lands at once on a seek.
##
## THE PAD: a page of a legal pad (8.5 x 11 in), ruled, written top to bottom. A formula sits on a
## rule (its baseline is snapped to one); prose starts at the margin and math a little in; what would
## run off the foot starts a new page, and `new page` tears one off on purpose. A struck line gets a
## stroke through it. Only the page being written is drawn: a torn-off page is gone.
##
## THE PEN has no hand (the user, 2026-10-15: the writer is unseen). While writing, its nib is the
## ink's own nib ([method Ink.at]); between strokes it lifts and travels; after a formula it drifts
## to rest beside it.

## The page, in the canvas's pixels (an 8.5 x 11 sheet).
const PW := 1100.0
const PH := 1424.0
## The sheet in the world, in meters.
const PAD_W := 0.2159
const PAD_H := 0.2794
## TeX points to the page's pixels: 12 pt type is about one rule tall.
const PX_PER_PT := 3.1
## The ruling: rules this far apart from the first, a red margin line, and room at the foot.
const RULE := 46.0
const FIRST_RULE := 196.0
const MARGIN_X := 128.0
const TEXT_X := 150.0
const MATH_X := 196.0
const RIGHT := 50.0
const FOOT := 90.0
## How a pen action is fitted between the words (see [method ReadingFollower.place]).
const LEAD := 0.25
const TAIL := 0.15
## The pen: lifted between strokes, raised at rest, and how long it takes to settle there.
const LIFT := 0.004
const REST_LIFT := 0.022
const REST_EASE := 0.9
const REACH_EASE := 0.45
## The pen's body, in meters.
const PEN_LEN := 0.135
const PEN_R := 0.0048
## The camera: its vertical field of view, how far it stands from the line, and how fast it follows.
## Close enough that a formula reads on a phone (the first look, 2026-10-15, stood at 0.42 m and the
## line was a fifth of the frame wide; at 0.27 m it was a tenth) - and near one page texel to a
## pixel, which keeps the rules from shimmering: the page is a render target, with no mipmaps -
## pitched as a writer's eyes are over the page.
const VFOV := 30.0
const CAM_DIST := 0.205
const CAM_PITCH := 62.0
const FOLLOW_TAU := 2.2
## How far the camera's aim may go toward the page's ends: the first line is near its top.
const FOCUS_MARGIN := 0.16
## The ink and the paper.
const INK := Color(0.10, 0.13, 0.30)
const PAPER := Color(0.985, 0.972, 0.90)
const RULE_COLOR := Color(0.55, 0.72, 0.86, 0.85)
const MARGIN_COLOR := Color(0.86, 0.42, 0.42, 0.8)

var _subs = null
var _doc_key := ""
var _seed := 1
var _actions: Array = []           # DeskScript's, each with its layout: {..., page, at: Vector2, k, w, h, d}
var _strokes := {}                 # item id -> Ink.schedule
var _follower := ReadingFollower.new()
var _built_n := -1
var _plan: Array = []              # per action: {start, end} (seconds), INF while not placed yet
var _now := 0.0
var _last_now := -1.0
var _snap := true

var _vp: SubViewport
var _canvas: PadCanvas
var _placeholder: GhostScene
var _root3: Node3D
var _cam: Camera3D
var _env: Environment
var _pad: Node3D
var _pen: Node3D
## THE CHANNEL'S NAME and its byline over the desk while the intro holds - the card table's own title
## screen ([TitleCard]), from the note's Title and Byline.
var _title: TitleCard
var _cam_y := 300.0                # the page line the camera is looking at (px), eased
var _yaw := 0.0


## The page, drawn: paper, rules, and the ink on it now.
class PadCanvas extends Node2D:
	var desk: DeskMedium

	func _draw() -> void:
		draw_rect(Rect2(0, 0, PW, PH), PAPER)
		var y := FIRST_RULE
		while y < PH - 20.0:
			draw_line(Vector2(0, y), Vector2(PW, y), RULE_COLOR, 2.6, true)
			y += RULE
		draw_line(Vector2(MARGIN_X, 0), Vector2(MARGIN_X, PH), MARGIN_COLOR, 2.0)
		draw_line(Vector2(MARGIN_X + 6.0, 0), Vector2(MARGIN_X + 6.0, PH), MARGIN_COLOR, 1.5)
		if desk == null:
			return
		for line in desk.page_ink():
			var pts: PackedVector2Array = line["points"]
			if pts.size() >= 2:
				draw_polyline(pts, INK, float(line["width"]), true)
			elif pts.size() == 1:
				draw_circle(pts[0], float(line["width"]) * 0.5, INK)


# --- mount -------------------------------------------------------------------------------

func mount(st: SubViewport) -> void:
	super.mount(st)
	_placeholder = GhostScene.new()
	_placeholder.init_with_seed(1, "drift")
	_placeholder.visible = false
	add_child(_placeholder)
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(PW), int(PH))
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_canvas = PadCanvas.new()
	_canvas.desk = self
	_vp.add_child(_canvas)
	_build_world()
	_title = TitleCard.new()
	_title.face = CardTable.font("roman")
	_title.italic = CardTable.font(CardTable.BOOK_ITALIC)
	# IN THE PAD'S OWN INK: the card table's light name (chosen to stand out from a painted table)
	# was cream on cream over the paper; dark, its shade turns light round it (CardTable.title_shade)
	_title.ink = INK
	add_child(_title)


func _build_world() -> void:
	_root3 = Node3D.new()
	add_child(_root3)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.02, 0.018, 0.016)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.55, 0.5, 0.45)
	_env.ambient_light_energy = 0.35
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.adjustment_enabled = true
	_cam = Camera3D.new()
	_cam.fov = VFOV
	_cam.near = 0.02
	_cam.far = 40.0
	_cam.environment = _env
	_root3.add_child(_cam)
	# THE LAMP, up and to the left of the pad, so the pen's shadow falls across the page to the right
	var lamp := SpotLight3D.new()
	# a white page under the tablet's lamp (4.2, set for a dark screen) burned out to no rules at all
	lamp.light_color = Color(1.0, 0.88, 0.72)
	lamp.light_energy = 1.5
	lamp.spot_range = 4.0
	lamp.spot_angle = 42.0
	lamp.spot_angle_attenuation = 1.4
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.005
	lamp.shadow_normal_bias = 0.15
	lamp.shadow_blur = 1.4
	_root3.add_child(lamp)
	lamp.position = Vector3(-0.55, 0.95, -0.25)
	lamp.look_at_from_position(lamp.position, Vector3(0.02, 0.0, 0.02), Vector3.UP)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.72, 0.76, 0.9)
	fill.light_energy = 0.18
	_root3.add_child(fill)
	fill.rotation_degrees = Vector3(-60.0, 35.0, 0.0)

	var desk := MeshInstance3D.new()
	var dm := PlaneMesh.new()
	dm.size = Vector2(8.0, 8.0)
	desk.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.36, 0.22, 0.13)
	dmat.albedo_texture = BookMedium._grime(0x5EED, 0.02, 5, 0.16)
	dmat.uv1_scale = Vector3(14.0, 14.0, 1.0)
	dmat.roughness = 0.6
	dmat.roughness_texture = dmat.albedo_texture
	desk.material_override = dmat
	desk.position = Vector3(0.0, -0.004, 0.0)
	_root3.add_child(desk)

	_pad = Node3D.new()
	_root3.add_child(_pad)
	# the stack under the top sheet, and the pad's cardboard back peeking out
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(PAD_W + 0.004, 0.0035, PAD_H + 0.03)
	back.mesh = bm
	var backmat := StandardMaterial3D.new()
	backmat.albedo_color = Color(0.32, 0.27, 0.22)
	backmat.roughness = 0.9
	back.material_override = backmat
	back.position = Vector3(0.0, -0.0018, -0.012)
	_pad.add_child(back)
	var stack := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(PAD_W, 0.003, PAD_H)
	stack.mesh = sm
	var stackmat := StandardMaterial3D.new()
	stackmat.albedo_color = Color(0.95, 0.93, 0.86)
	stackmat.roughness = 0.95
	stack.material_override = stackmat
	stack.position = Vector3(0.0, -0.0015, 0.0)
	_pad.add_child(stack)
	var sheet := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(PAD_W, PAD_H)
	sheet.mesh = pm
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = _vp.get_texture()
	paper.albedo_color = Color(0.93, 0.92, 0.88)
	paper.roughness = 0.92
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sheet.material_override = paper
	sheet.position = Vector3(0.0, 0.0002, 0.0)
	_pad.add_child(sheet)

	_pen = Node3D.new()
	_root3.add_child(_pen)
	var lacquer := StandardMaterial3D.new()
	lacquer.albedo_color = Color(0.05, 0.06, 0.09)
	lacquer.metallic = 0.3
	lacquer.roughness = 0.28
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.62, 0.32)
	brass.metallic = 0.9
	brass.roughness = 0.3
	# the pen's own frame: its nib at the origin, its body up along +Y
	var tip := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = PEN_R * 0.85
	tm.bottom_radius = 0.0005
	tm.height = 0.02
	tip.mesh = tm
	tip.material_override = brass
	tip.position = Vector3(0.0, 0.01, 0.0)
	_pen.add_child(tip)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = PEN_R
	cm.bottom_radius = PEN_R * 0.92
	cm.height = PEN_LEN
	body.mesh = cm
	body.material_override = lacquer
	body.position = Vector3(0.0, 0.02 + PEN_LEN * 0.5, 0.0)
	_pen.add_child(body)
	var band := MeshInstance3D.new()
	var bandm := CylinderMesh.new()
	bandm.top_radius = PEN_R * 1.04
	bandm.bottom_radius = PEN_R * 1.04
	bandm.height = 0.006
	band.mesh = bandm
	band.material_override = brass
	band.position = Vector3(0.0, 0.02 + PEN_LEN * 0.62, 0.0)
	_pen.add_child(band)


func begin_session() -> void:
	_seed = feed.session_seed()
	_snap = true


func release() -> void:
	_subs = null
	_doc_key = ""


# --- the Medium contract --------------------------------------------------------------------

func owns_cast() -> bool:
	return true


func take_over(_outgoing: GhostScene) -> GhostScene:
	return _placeholder


func owns_bookend() -> bool:
	return true


## The words stay the overlay's to show: the pad shows what is written, not what is said.
func bind_captions(subs) -> bool:
	_subs = subs
	_doc_key = ""
	return false


func advance(_features, delta: float, bookend: float) -> void:
	var t := maxf(feed.show_time(), 0.0)
	var slen := feed.show_length()
	var b := bookend if slen > 0.0 and t > slen * 0.5 else clampf(t / 1.2, 0.0, 1.0)
	_env.adjustment_brightness = clampf(b * feed.live_fade, 0.0, 1.0)
	_ensure_doc()
	_now = _subs.now() if _subs != null and is_instance_valid(_subs) else t
	if absf(_now - _last_now) > 1.0:
		_snap = true
	_last_now = _now
	if _subs != null and is_instance_valid(_subs) and not _actions.is_empty():
		var words: Array = _subs.words
		_follower.extend(words)
		if words.size() != _built_n:
			_built_n = words.size()
			_build_plan()
	_place_pen()
	_tick_camera(delta)
	_canvas.queue_redraw()
	_title.alpha = _title_alpha(_now)
	_title.queue_redraw()


# --- the document ------------------------------------------------------------------------------

func _ensure_doc() -> void:
	if _subs == null or not is_instance_valid(_subs):
		return
	var d: Dictionary = _subs.document
	_title.channel = String(d.get("title", ""))
	_title.byline = String(d.get("byline", ""))
	var src := String(d.get("source", ""))
	var desk: Dictionary = d.get("desk", {}) if d.get("desk") is Dictionary else {}
	var key := "%d|%s|%d" % [src.hash(), String(desk.get("dir", "")), int(desk.get("seed", 0))]
	if key == _doc_key:
		return
	_doc_key = key
	load_lesson(src, desk)


## LOAD A LESSON: [param source] (the lesson's text, the pen's marks in it) and [param desk] (`{ink,
## seed}` - the typeset items and the hand's seed). Public for a gate, which hands it one by hand.
func load_lesson(source: String, desk: Dictionary) -> void:
	_seed = int(desk.get("seed", _seed))
	var typeset: Dictionary = desk.get("ink", {}) if desk.get("ink") is Dictionary else {}
	var records := {}
	for r in typeset.get("items", []):
		if r is Dictionary and bool((r as Dictionary).get("ok", false)):
			records[String((r as Dictionary)["id"])] = r
	var outlines: Dictionary = typeset.get("fonts", {}) if typeset.get("fonts") is Dictionary else {}
	_strokes = {}
	var lengths := {}
	for id in records:
		var got := Ink.strokes_of(records[id], _seed, outlines)
		var sched := Ink.schedule(got["strokes"], _seed)
		_strokes[id] = sched
		lengths[id] = float(sched["length"])
	var parsed: Dictionary = DeskScript.parse(source, lengths)
	_actions = lay_out(parsed["actions"], records)
	_follower.reset(parsed["spoken"])
	_built_n = -1
	_plan = []
	for i in _actions.size():
		_plan.append({"start": INF, "end": INF})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["desk-pad", _seed])
	_yaw = deg_to_rad(rng.randf_range(-6.0, 3.0))
	_pad.rotation.y = _yaw
	_snap = true


## WHERE EACH ACTION WRITES: its page and its place on it ([constant PX_PER_PT] scaled, baselines on
## the rules, a new page where the next would run off the foot). [param records]: id -> typeset item.
## A pure function of the actions and the layouts, so a gate can hold it.
static func lay_out(actions: Array, records: Dictionary) -> Array:
	var out: Array = []
	var page := 0
	var cursor := FIRST_RULE - RULE
	var last_written := -1
	for a in actions:
		var act: Dictionary = (a as Dictionary).duplicate()
		act["i"] = out.size()
		act["page"] = page
		match String(act["kind"]):
			"new page":
				page += 1
				cursor = FIRST_RULE - RULE
				act["page"] = page
			"strike":
				act["of"] = last_written
			"pad", "pad-text":
				var r: Dictionary = records.get(String(act["id"]), {})
				var w := float(r.get("w", 0.0)) * PX_PER_PT
				var h := float(r.get("h", 8.0)) * PX_PER_PT
				var d := float(r.get("d", 2.0)) * PX_PER_PT
				var x := MATH_X if String(act["kind"]) == "pad" else TEXT_X
				var room := PW - RIGHT - x
				var k := minf(1.0, room / w) if w > 0.0 else 1.0
				var base := _snap_rule(cursor + 10.0 + h * k)
				if base + d * k > PH - FOOT and cursor > FIRST_RULE:
					page += 1
					base = _snap_rule(FIRST_RULE - RULE + 10.0 + h * k)
				act["page"] = page
				act["at"] = Vector2(x, base)
				act["k"] = k
				act["w"] = w * k
				act["h"] = h * k
				act["d"] = d * k
				cursor = base + d * k
				last_written = out.size()
		out.append(act)
	return out


## The first rule at or below [param y].
static func _snap_rule(y: float) -> float:
	var n := ceilf((y - FIRST_RULE) / RULE)
	return FIRST_RULE + maxf(n, 0.0) * RULE


## WHEN EACH ACTION HAPPENS: placed in the voice's rest for it, then performed at the pen's pace,
## never before the one before it has finished. An action whose words have not arrived waits.
func _build_plan() -> void:
	var placed := _follower.place(_actions, 0.0, LEAD, TAIL)
	var prev_end := -INF
	for i in _actions.size():
		_plan[i] = {"start": INF, "end": INF}
	for e in placed:
		var a: Dictionary = (e as Dictionary)["a"]
		var i := int(a.get("i", -1))
		if i < 0 or i >= _actions.size():
			continue
		var start := maxf(float((e as Dictionary)["t0"]), prev_end)
		var end := start + float(a.get("write", 0.0))
		_plan[i] = {"start": start, "end": end}
		prev_end = end


# --- what is on the page now ----------------------------------------------------------------

## The page being written at [member _now]: the page of the last action begun.
func _page_now() -> int:
	var page := 0
	for i in _actions.size():
		var start := float(_plan[i]["start"])
		if start > _now:
			break
		var a: Dictionary = _actions[i]
		# a torn page goes half way through its tearing
		if String(a["kind"]) == "new page" and _now < start + float(a["write"]) * 0.5:
			continue
		page = int(a["page"])
	return page


## THE INK ON THE PAGE NOW, in the page's pixels: [{points, width}] - what [PadCanvas] draws.
func page_ink() -> Array:
	var out: Array = []
	if _actions.is_empty():
		return out
	var page := _page_now()
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var start := float(_plan[i]["start"])
		if start > _now or int(a["page"]) != page:
			continue
		match String(a["kind"]):
			"pad", "pad-text":
				var sched: Dictionary = _strokes.get(String(a["id"]), {})
				if sched.is_empty():
					continue
				var at: Vector2 = a["at"]
				var k := float(a["k"]) * PX_PER_PT
				for s in Ink.at(sched, _now - start)["ink"]:
					var pts := PackedVector2Array()
					for p in (s as Dictionary)["points"]:
						pts.append(at + (p as Vector2) * k)
					out.append({"points": pts, "width": maxf(2.4, float((s as Dictionary)["width"]) * k * 1.35)})
			"strike":
				var of := int(a.get("of", -1))
				if of < 0 or int((_actions[of] as Dictionary)["page"]) != page:
					continue
				var line := _strike_line(_actions[of])
				var u := clampf((_now - start) / maxf(float(a["write"]), 0.01), 0.0, 1.0)
				out.append({"points": PackedVector2Array([line[0], line[0].lerp(line[1], u)]), "width": 3.2})
	return out


## The stroke a cross-out draws through a written action: across its middle, a little rising.
static func _strike_line(a: Dictionary) -> Array:
	var at: Vector2 = a.get("at", Vector2.ZERO)
	var w := float(a.get("w", 100.0))
	var h := float(a.get("h", 30.0))
	return [at + Vector2(-14.0, -h * 0.32), at + Vector2(w + 14.0, -h * 0.45)]


# --- the pen ---------------------------------------------------------------------------------

## WHERE THE NIB IS NOW, on the page (px), and how high above it (m): writing, it is the ink's nib;
## between strokes it lifts and travels; after an action it drifts to rest beside it; before the
## first, it waits at the page's right.
func pen_at() -> Dictionary:
	var rest := Vector2(PW * 0.82, FIRST_RULE + RULE * 3.0)
	var last_end := -INF
	var last_point := rest
	var page := _page_now()
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var start := float(_plan[i]["start"])
		var end := float(_plan[i]["end"])
		if start == INF:
			break
		var kind := String(a["kind"])
		var first := _action_first_point(a)
		if _now < start:
			# on its way to the next action: from where it rested to where the action begins
			var u := clampf(1.0 - (start - _now) / REACH_EASE, 0.0, 1.0)
			var from := _rest_near(last_point) if last_end > -INF else rest
			return {"p": from.lerp(first, _ease(u)), "lift": lerpf(REST_LIFT, LIFT, _ease(u))}
		if _now < end:
			return _pen_during(a, i, start)
		last_end = end
		if int(a["page"]) == page or kind == "new page":
			last_point = _action_last_point(a)
	if last_end == -INF:
		return {"p": rest, "lift": REST_LIFT}
	var v := clampf((_now - last_end) / REST_EASE, 0.0, 1.0)
	return {"p": last_point.lerp(_rest_near(last_point), _ease(v)), "lift": lerpf(LIFT, REST_LIFT, _ease(v))}


func _pen_during(a: Dictionary, _i: int, start: float) -> Dictionary:
	var local := _now - start
	match String(a["kind"]):
		"pad", "pad-text":
			var sched: Dictionary = _strokes.get(String(a["id"]), {})
			var at: Vector2 = a["at"]
			var k := float(a["k"]) * PX_PER_PT
			var strokes: Array = sched.get("strokes", [])
			var prev := Vector2.INF
			var prev_t1 := 0.0
			for s in strokes:
				var st: Dictionary = s
				var t0 := float(st["t0"])
				var t1 := float(st["t1"])
				var pts: PackedVector2Array = st["points"]
				if local < t0:
					# lifted, travelling from the last stroke's end to this one's start
					var from: Vector2 = prev if prev != Vector2.INF else pts[0]
					var u := clampf((local - prev_t1) / maxf(t0 - prev_t1, 0.05), 0.0, 1.0)
					return {"p": at + from.lerp(pts[0], _ease(u)) * k, "lift": sin(u * PI) * LIFT}
				if local <= t1:
					var now_ink := Ink.at({"strokes": [st]}, local)
					var nib: Vector2 = now_ink["pen"] if now_ink["pen"] != Vector2.INF else pts[pts.size() - 1]
					return {"p": at + nib * k, "lift": 0.0}
				prev = pts[pts.size() - 1]
				prev_t1 = t1
			return {"p": at + (prev if prev != Vector2.INF else Vector2.ZERO) * k, "lift": LIFT}
		"strike":
			var of := int(a.get("of", -1))
			if of >= 0:
				var line := _strike_line(_actions[of])
				var u := clampf((_now - start) / maxf(float(a["write"]), 0.01), 0.0, 1.0)
				return {"p": (line[0] as Vector2).lerp(line[1], u), "lift": 0.0}
	return {"p": Vector2(PW * 0.82, FIRST_RULE + RULE * 3.0), "lift": REST_LIFT}


func _action_first_point(a: Dictionary) -> Vector2:
	match String(a["kind"]):
		"pad", "pad-text":
			var sched: Dictionary = _strokes.get(String(a["id"]), {})
			var strokes: Array = sched.get("strokes", [])
			if not strokes.is_empty():
				var pts: PackedVector2Array = (strokes[0] as Dictionary)["points"]
				return (a["at"] as Vector2) + pts[0] * float(a["k"]) * PX_PER_PT
			return a.get("at", Vector2(PW * 0.5, PH * 0.3))
		"strike":
			var of := int(a.get("of", -1))
			if of >= 0:
				return _strike_line(_actions[of])[0]
	return Vector2(PW * 0.82, FIRST_RULE + RULE * 3.0)


func _action_last_point(a: Dictionary) -> Vector2:
	match String(a["kind"]):
		"pad", "pad-text":
			var sched: Dictionary = _strokes.get(String(a["id"]), {})
			var strokes: Array = sched.get("strokes", [])
			if not strokes.is_empty():
				var pts: PackedVector2Array = (strokes[strokes.size() - 1] as Dictionary)["points"]
				return (a["at"] as Vector2) + pts[pts.size() - 1] * float(a["k"]) * PX_PER_PT
			return a.get("at", Vector2(PW * 0.5, PH * 0.3))
		"strike":
			var of := int(a.get("of", -1))
			if of >= 0:
				return _strike_line(_actions[of])[1]
	return Vector2(PW * 0.82, FIRST_RULE + RULE * 3.0)


## Where the pen rests after writing at [param p]: below and to the right, clear of what it wrote (at
## +70, +60 px it lay across the end of the line it had just finished - the first look).
static func _rest_near(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x + 160.0, MATH_X, PW - 60.0), clampf(p.y + 130.0, FIRST_RULE, PH - 80.0))


static func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## A point of the page (px) in the world, [param lift] meters above it.
func _world(p: Vector2, lift: float) -> Vector3:
	var local := Vector3((p.x / PW - 0.5) * PAD_W, 0.0003 + lift, (p.y / PH - 0.5) * PAD_H)
	return _pad.transform * local


func _place_pen() -> void:
	var at := pen_at()
	var nib := _world(at["p"], float(at["lift"]))
	# HELD BY A RIGHT HAND THE CAMERA NEVER SEES, from where the camera is: the body runs back toward
	# the writer and to the right, so from the writer's eyes it runs down and right of the nib (the
	# first look leaned it up and away, as if the writer sat across the desk)
	var up := Vector3(0.42, 0.52, 0.74).normalized()
	var x := up.cross(Vector3.FORWARD).normalized()
	var z := x.cross(up).normalized()
	_pen.global_transform = Transform3D(Basis(x, up, z), nib)


# --- the title -------------------------------------------------------------------------------

## The channel's name over the desk while the intro holds, as the card table's is: up by 1.4 s, gone
## as the first word is said - and not again (the lesson ends on the desk fading to black).
func _title_alpha(t: float) -> float:
	var a := clampf((t - 0.3) / 1.1, 0.0, 1.0)
	var first := _follower.st0[0] if _follower.st0.size() > 0 else ReadingFollower.NO_TIME
	if first != ReadingFollower.NO_TIME:
		a *= 1.0 - clampf((t - (first - 0.6)) / 0.9, 0.0, 1.0)
	elif _built_n > 0:
		a = 0.0
	return a


# --- the camera -------------------------------------------------------------------------------

## The line the camera looks at: the one being written, else the last written on the page.
func _focus_y() -> float:
	var y := FIRST_RULE + RULE * 4.0
	var page := _page_now()
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if float(_plan[i]["start"]) > _now:
			break
		if int(a["page"]) == page and a.has("at"):
			y = (a["at"] as Vector2).y
	return clampf(y, PH * FOCUS_MARGIN, PH * (1.0 - FOCUS_MARGIN))


func _tick_camera(delta: float) -> void:
	var want := _focus_y()
	if _snap:
		_cam_y = want
		_snap = false
	else:
		_cam_y += (want - _cam_y) * (1.0 - exp(-delta / FOLLOW_TAU))
	var aim := _world(Vector2(PW * 0.5, _cam_y), 0.0)
	var drift := Vector3(sin(_now * 0.05) * 0.01, 0.0, cos(_now * 0.037) * 0.008)
	var pitch := deg_to_rad(CAM_PITCH)
	var back := Vector3(0.06, sin(pitch), cos(pitch)).normalized() * CAM_DIST
	_cam.position = aim + back + drift
	_cam.look_at(aim + drift * 0.3, Vector3.UP)
