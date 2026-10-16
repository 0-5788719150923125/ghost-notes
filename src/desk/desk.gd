extends Medium
class_name DeskMedium

## DeskMedium - a ghost doing math at a desk: a legal pad under a lamp, and a pen that writes on it
## by itself while the teacher reads aloud what it writes (next/proof.md, "The desk").
##
## WHAT IT DRAWS FROM: the reading's document (`_subs.document`) - its `source`, the lesson with the
## pen's marks ([DeskScript]); its `desk`, what the Proof component hands the reading
## ([method ProofEpisode.document]): every formula as TeX laid it out (`ink`) and the episode's seed,
## which is the hand's; and its `title` and `byline`, the channel's, for the title screen.
##
## IT OPENS AND CLOSES AS THE CARD TABLE DOES ([ShowOpening], the user, 2026-10-16: "the intro/outro
## doesn't inherit the behavior from cards mode"): the channel's name over the desk thrown far out of
## focus while the intro holds, the focus pulled as the lesson's first word is said, and black a beat
## after its last word, as the outro runs out.
##
## THE PEN WRITES WHAT THE VOICE SAYS, AS IT SAYS IT ([DeskScript], the user the same day: "we need to
## narrate the text being written, as it is being written"): a formula's writing runs across exactly
## the words of its dictation, the ink's own clock driven by how far through those words the voice is
## ([method _ink_time]) - never faster than [constant DeskScript.MAX_PACE] of the pen's own pace nor
## slower than [constant DeskScript.MIN_PACE]; where it would lag the voice waits at the dictation's
## end, a rest the script already gave it.
##
## A PURE FUNCTION OF THE VOICE'S TIME. A pad item is written at `_ink_time`, a function of the words'
## times and now, so any moment can be drawn without the ones before it: a seek lands on the page as it
## was. The camera alone eases (as the book's and the tablet's do), and lands at once on a seek.
##
## THE PAD: a page of a legal pad (8.5 x 11 in), ruled, filled top to bottom - every formula on the next
## rules ([method DeskScript.lay_out]) - and TURNED only when the next would run off the foot: the
## written sheet lifts at its foot, swings up over the binding and is gone, and the clean page is under
## it (the user: "a page with text on it is just 'wiped' clean, for seemingly no reason ... use all of
## the available space on a page, and then turn the page if we need more space"). A struck line gets a
## stroke through it.
##
## THE CAMERA IS THE BOOK'S KIND ([BookMedium]: "something closer to what we did with the 'book' medium,
## with a further zoom and mostly vertical orientation ... the actor swapping for a calculator, or a
## tablet, or a laptop"): a long lens, looking down at the desk from high and a little in front; wide
## over the intro and as a page turns, closer while the pen writes, following the line being written
## through one slow critically damped spring; each page its own slight yaw and tilt, and a wander over
## minutes, so it never sits dead still and never reads as a move.
##
## THE PEN has no hand (the writer is unseen). It leans to the top right of the frame from its nib
## (the user: "it should angle to the top-right, which would be a more natural writing position") -
## which also keeps what it has just written, to the left of the nib, in view.

## The page's canvas (an 8.5 x 11 sheet) and the sheet in the world, in meters.
const PW := DeskScript.PW
const PH := DeskScript.PH
const PAD_W := 0.2159
const PAD_H := 0.2794
## The pen's body, in meters; how high it lifts between strokes and at rest; how it eases there.
const PEN_LEN := 0.135
const PEN_R := 0.0048
const LIFT := 0.004
const REST_LIFT := 0.022
const REST_EASE := 0.9
const REACH_EASE := 0.45
## The pen comes down this long before its dictation's first word.
const PEN_LEAD := 0.2
## How it leans from its nib: up, to the right, and away from the writer - the frame's top right.
const PEN_UP := Vector3(0.42, 0.64, -0.40)
## THE CAMERA: a long lens (the book's: a wide one stood close bends the page's lines), wide enough to
## hold the whole pad with room round it for the tools still to come, closer while the pen writes;
## mostly looking down. Distances in meters, pitches in degrees above the desk.
const VFOV := 20.0
const WIDE := {"dist": 1.45, "pitch": 74.0}
const LOCAL := {"dist": 0.82, "pitch": 79.0}
const SPRING_TAU := 3.2
const YAW_SPREAD := 4.0
const YAW_WANDER := 1.5
const ROLL_SPREAD := 1.0
const TILT_SPREAD := 1.5
const ANGLE_SLOW := 3.0
## How long the framing looks ahead of the pen, as the book's does (springs make every move late).
const CAM_LEAD := 2.0
## The ink and the paper.
const INK := Color(0.10, 0.13, 0.30)
const PAPER := Color(0.985, 0.972, 0.90)
const RULE_COLOR := Color(0.55, 0.72, 0.86, 0.85)
const MARGIN_COLOR := Color(0.86, 0.42, 0.42, 0.8)
const MARGIN_X := 128.0

var _subs = null
var _doc_key := ""
var _seed := 1
var _actions: Array = []           # DeskScript's, laid out
var _spoken_n := 0
var _strokes := {}                 # item id -> Ink.schedule
var _follower := ReadingFollower.new()
var _built_n := -1
var _plan: Array = []              # per action: {start, end, turn_at} (seconds), INF while not placed
var _now := 0.0
var _last_now := -1.0
var _snap := true

var _vp: SubViewport               # the page being written
var _vp_turn: SubViewport          # the page turning away
var _canvas: PadCanvas
var _canvas_turn: PadCanvas
var _placeholder: GhostScene
var _root3: Node3D
var _cam: Camera3D
var _attrs: CameraAttributesPractical
var _env: Environment
var _pad: Node3D
var _hinge: Node3D                 # the turning sheet hangs from the pad's binding
var _pen: Node3D
var _blur: IntroBlur
var _title: TitleCard
# the camera's springs
var _c_aim := Vector3.ZERO
var _v_aim := Vector3.ZERO
var _c_dist := 1.45
var _v_dist := 0.0
var _c_pitch := 74.0
var _v_pitch := 0.0
var _c_yaw := 0.0
var _v_yaw := 0.0
var _c_roll := 0.0
var _v_roll := 0.0


## A page, drawn: paper, rules, and the ink on page [member page] now.
class PadCanvas extends Node2D:
	var desk: DeskMedium
	var page := 0

	func _draw() -> void:
		draw_rect(Rect2(0, 0, PW, PH), PAPER)
		var y := DeskScript.FIRST_RULE
		while y < PH - 20.0:
			draw_line(Vector2(0, y), Vector2(PW, y), RULE_COLOR, 2.6, true)
			y += DeskScript.RULE
		draw_line(Vector2(MARGIN_X, 0), Vector2(MARGIN_X, PH), MARGIN_COLOR, 2.0)
		draw_line(Vector2(MARGIN_X + 6.0, 0), Vector2(MARGIN_X + 6.0, PH), MARGIN_COLOR, 1.5)
		if desk == null:
			return
		for line in desk.page_ink(page):
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
	_vp = _page_viewport()
	_canvas = _vp.get_child(0) as PadCanvas
	_vp_turn = _page_viewport()
	_canvas_turn = _vp_turn.get_child(0) as PadCanvas
	_build_world()
	# THE OPENING, the card table's: the intro's blur over the desk, and the name over the blur
	_blur = IntroBlur.new(ShowOpening.INTRO_SHADER)
	add_child(_blur)
	_title = TitleCard.new()
	_title.face = CardTable.font("roman")
	_title.italic = CardTable.font(CardTable.BOOK_ITALIC)
	# IN THE PAD'S OWN INK: the card table's light name (chosen to stand out from a painted table)
	# was cream on cream over the paper; dark, its shade turns light round it (CardTable.title_shade)
	_title.ink = INK
	add_child(_title)


func _page_viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(int(PW), int(PH))
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var c := PadCanvas.new()
	c.desk = self
	vp.add_child(c)
	return vp


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
	_cam.near = 0.05
	_cam.far = 40.0
	_cam.environment = _env
	# the lens's own blur is the opening's, as the card table's is ([ShowOpening])
	_attrs = CameraAttributesPractical.new()
	_attrs.dof_blur_far_enabled = false
	_cam.attributes = _attrs
	_root3.add_child(_cam)
	# THE LAMP, up and to the left of the pad, so the pen's shadow falls across the page to the right
	# - a white page under the tablet's lamp (4.2, set for a dark screen) burned out to no rules at all
	var lamp := SpotLight3D.new()
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
	# the pad's cardboard back peeking out, and the stack under the top sheet
	_pad.add_child(_box(Vector3(PAD_W + 0.004, 0.0035, PAD_H + 0.03), Vector3(0.0, -0.0018, -0.012),
		Color(0.32, 0.27, 0.22), 0.9))
	_pad.add_child(_box(Vector3(PAD_W, 0.003, PAD_H), Vector3(0.0, -0.0015, 0.0), Color(0.95, 0.93, 0.86), 0.95))
	var sheet := _sheet(_vp.get_texture())
	sheet.position = Vector3(0.0, 0.0002, 0.0)
	_pad.add_child(sheet)
	# THE TURNING SHEET hangs from the binding (the pad's top edge): written on its face, plain paper
	# on its back, rotated about the edge as it turns over
	_hinge = Node3D.new()
	_hinge.position = Vector3(0.0, 0.0006, -PAD_H * 0.5)
	_hinge.visible = false
	_pad.add_child(_hinge)
	var face := _sheet(_vp_turn.get_texture())
	face.position = Vector3(0.0, 0.0, PAD_H * 0.5)
	_hinge.add_child(face)
	var back := MeshInstance3D.new()
	var bpm := PlaneMesh.new()
	bpm.size = Vector2(PAD_W, PAD_H)
	back.mesh = bpm
	var backmat := StandardMaterial3D.new()
	backmat.albedo_color = Color(0.93, 0.91, 0.84)
	backmat.roughness = 0.95
	back.material_override = backmat
	back.rotation = Vector3(0.0, 0.0, PI)       # facing down: seen once the sheet is over
	back.position = Vector3(0.0, -0.0002, PAD_H * 0.5)
	_hinge.add_child(back)

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
	_pen.add_child(_cyl(PEN_R * 0.85, 0.0005, 0.02, 0.01, brass))
	_pen.add_child(_cyl(PEN_R, PEN_R * 0.92, PEN_LEN, 0.02 + PEN_LEN * 0.5, lacquer))
	_pen.add_child(_cyl(PEN_R * 1.04, PEN_R * 1.04, 0.006, 0.02 + PEN_LEN * 0.62, brass))


func _box(size: Vector3, at: Vector3, color: Color, rough: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	m.material_override = mat
	m.position = at
	return m


func _sheet(tex: Texture2D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(PAD_W, PAD_H)
	m.mesh = pm
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = tex
	paper.albedo_color = Color(0.93, 0.92, 0.88)
	paper.roughness = 0.92
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.material_override = paper
	return m


func _cyl(top: float, bottom: float, height: float, y: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	m.mesh = c
	m.material_override = mat
	m.position = Vector3(0.0, y, 0.0)
	return m


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


func on_stage_resized(_size: Vector2) -> void:
	if _blur != null:
		_blur.queue_redraw()
	if _title != null:
		_title.queue_redraw()


func advance(_features, delta: float, _bookend: float) -> void:
	var t := maxf(feed.show_time(), 0.0)
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
	# UP FROM BLACK as the session starts, down to it after the last word - the desk owns its
	# bookend, as the card table does; an outro mark's fade still is the feed's
	_env.adjustment_brightness = clampf(clampf(t / 1.2, 0.0, 1.0)
		* ShowOpening.end_fade(_now, _follower, _spoken_n, feed.tail()) * feed.live_fade, 0.0, 1.0)
	var opening := _opening()
	ShowOpening.lens(ShowOpening.pull(_now, opening, _built_n > 0), _blur, _attrs)
	_title.alpha = ShowOpening.title_alpha(_now, opening, _built_n > 0)
	_title.queue_redraw()
	_show_pages()
	_place_pen()
	_tick_camera(delta)


## THE LESSON OPENS with its first word, which the pen's first dictation is: INF until it is heard.
func _opening() -> float:
	if _follower.st0.size() > 0 and _follower.st0[0] != ReadingFollower.NO_TIME:
		return _follower.st0[0]
	return INF


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
	var parsed: Dictionary = DeskScript.parse(source, lengths, records)
	_actions = parsed["actions"]
	_spoken_n = (parsed["spoken"] as PackedStringArray).size()
	_follower.reset(parsed["spoken"])
	_built_n = -1
	_plan = []
	for i in _actions.size():
		_plan.append({"start": INF, "end": INF, "turn_at": INF})
	_snap = true


## WHEN EACH ACTION HAPPENS. A written item starts as its dictation's first word is said (the pen down
## [constant PEN_LEAD] before it) and ends as the words do - no sooner than the pen can write it at
## [constant DeskScript.MAX_PACE], no later than at [constant DeskScript.MIN_PACE] - and never before
## the one before it has ended. One with no dictation, and a strike, are performed in the rest before
## the next words. A page turn comes in the rest before the item that needs it, never over writing
## still going on, and the item waits for it. An action whose words have not arrived waits.
func _build_plan() -> void:
	var prev_end := -INF
	for i in _actions.size():
		_plan[i] = {"start": INF, "end": INF, "turn_at": INF}
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var after := int(a.get("after", 0))
		var span := int(a.get("span", 0))
		var write := float(a.get("write", 0.0))
		var start := INF
		var end := INF
		if String(a["kind"]) in ["pad", "pad-text"] and span > 0:
			var t0 := _word_t0(after)
			if t0 == INF:
				break
			start = maxf(t0 - PEN_LEAD, prev_end)
			var said := _word_t1(after + span - 1)
			end = clampf(said if said < INF else start + float(span) * DeskScript.EST_WORD,
				start + write / DeskScript.MAX_PACE, start + write / DeskScript.MIN_PACE)
		else:
			var before := _word_t1(after - 1) if after > 0 else maxf(feed.intro_hold, 0.6) - 0.25
			if before == INF:
				break
			start = maxf(before + 0.25, prev_end)
			end = start + write
		var turn_at := INF
		if bool(a.get("turn", false)):
			turn_at = maxf(start - DeskScript.TURN - 0.1, prev_end)
			var late := turn_at + DeskScript.TURN + 0.05 - start
			if late > 0.0:
				start += late
				end += late
		_plan[i] = {"start": start, "end": end, "turn_at": turn_at}
		prev_end = end


func _word_t0(si: int) -> float:
	if si < 0 or si >= _follower.st0.size() or _follower.st0[si] == ReadingFollower.NO_TIME:
		return INF
	return _follower.st0[si]


func _word_t1(si: int) -> float:
	if si < 0 or si >= _follower.st1.size() or _follower.st1[si] == ReadingFollower.NO_TIME:
		return INF
	return _follower.st1[si]


## HOW FAR THROUGH ITS WRITING action [param i] is at [member _now], as the ink's own clock (seconds
## of [method Ink.schedule]): the share of its dictation's words said, kept within the pen's pace -
## the voice ahead pulls the pen faster (to [constant DeskScript.MAX_PACE]), the voice behind slows it
## (to [constant DeskScript.MIN_PACE]).
func _ink_time(i: int) -> float:
	var a: Dictionary = _actions[i]
	var start := float(_plan[i]["start"])
	var length := float((_strokes.get(String(a["id"]), {}) as Dictionary).get("length", a.get("write", 0.0)))
	if _now <= start:
		return 0.0
	if _now >= float(_plan[i]["end"]):
		return length
	var elapsed := _now - start
	var span := int(a.get("span", 0))
	var target := length
	if span > 0:
		target = _said(int(a["after"]), span) * length
	return clampf(target, elapsed * DeskScript.MIN_PACE, minf(elapsed * DeskScript.MAX_PACE, length))


## The share of the [param span] words from [param after] the voice has said at [member _now]: a word
## counts as it is said, and a word not heard yet is not said.
func _said(after: int, span: int) -> float:
	var done := 0.0
	for j in span:
		var t0 := _word_t0(after + j)
		var t1 := _word_t1(after + j)
		if t0 == INF or _now < t0:
			break
		if _now >= t1:
			done += 1.0
		else:
			done += clampf((_now - t0) / maxf(t1 - t0, 0.01), 0.0, 1.0)
			break
	return done / float(maxi(span, 1))


# --- the pages ---------------------------------------------------------------------------------

## The page being written at [member _now], and the one turning away (-1 when none is): a page begins
## as the turn before it does.
func _pages() -> Vector2i:
	var page := 0
	var turning := -1
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var begin := minf(float(_plan[i]["turn_at"]), float(_plan[i]["start"]))
		if begin > _now:
			break
		page = int(a["page"])
		var ta := float(_plan[i]["turn_at"])
		turning = page - 1 if ta < INF and _now < ta + DeskScript.TURN else -1
	return Vector2i(page, turning)


func _show_pages() -> void:
	var p := _pages()
	_canvas.page = p.x
	_canvas.queue_redraw()
	_hinge.visible = p.y >= 0
	if p.y >= 0:
		_canvas_turn.page = p.y
		_canvas_turn.queue_redraw()
		var ta := INF
		for i in _actions.size():
			if int((_actions[i] as Dictionary)["page"]) == p.x and float(_plan[i]["turn_at"]) < INF:
				ta = float(_plan[i]["turn_at"])
				break
		var u := clampf((_now - ta) / DeskScript.TURN, 0.0, 1.0)
		# lifted at its foot and swung up over the binding, a touch faster through the top
		_hinge.rotation.x = -PI * (u * u * (3.0 - 2.0 * u))


## THE INK ON PAGE [param page] NOW, in the page's pixels: [{points, width}] - what [PadCanvas] draws.
func page_ink(page: int) -> Array:
	var out: Array = []
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
				var k := float(a["k"]) * DeskScript.PX_PER_PT
				for s in Ink.at(sched, _ink_time(i))["ink"]:
					var pts := PackedVector2Array()
					for q in (s as Dictionary)["points"]:
						pts.append(at + (q as Vector2) * k)
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
	var rest := Vector2(PW * 0.84, DeskScript.FIRST_RULE + DeskScript.RULE * 2.0)
	var last_end := -INF
	var last_point := rest
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var start := float(_plan[i]["start"])
		var end := float(_plan[i]["end"])
		if start == INF:
			break
		if _now < start:
			# on its way to the next action: from where it rested to where the action begins
			var u := clampf(1.0 - (start - _now) / REACH_EASE, 0.0, 1.0)
			var from := _rest_near(last_point) if last_end > -INF else rest
			if float(_plan[i]["turn_at"]) < INF and _now < start - 0.05:
				from = rest
			return {"p": from.lerp(_action_point(a, true), _ease(u)), "lift": lerpf(REST_LIFT, LIFT, _ease(u))}
		if _now < end:
			return _pen_during(a, i, start)
		last_end = end
		last_point = _action_point(a, false)
	if last_end == -INF:
		return {"p": rest, "lift": REST_LIFT}
	var v := clampf((_now - last_end) / REST_EASE, 0.0, 1.0)
	return {"p": last_point.lerp(_rest_near(last_point), _ease(v)), "lift": lerpf(LIFT, REST_LIFT, _ease(v))}


func _pen_during(a: Dictionary, i: int, start: float) -> Dictionary:
	match String(a["kind"]):
		"pad", "pad-text":
			var local := _ink_time(i)
			var sched: Dictionary = _strokes.get(String(a["id"]), {})
			var at: Vector2 = a["at"]
			var k := float(a["k"]) * DeskScript.PX_PER_PT
			var prev := Vector2.INF
			var prev_t1 := 0.0
			for s in sched.get("strokes", []):
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
	return {"p": Vector2(PW * 0.84, DeskScript.FIRST_RULE + DeskScript.RULE * 2.0), "lift": REST_LIFT}


## Where an action's writing begins ([param first]) or ends, on the page.
func _action_point(a: Dictionary, first: bool) -> Vector2:
	match String(a["kind"]):
		"pad", "pad-text":
			var strokes: Array = (_strokes.get(String(a["id"]), {}) as Dictionary).get("strokes", [])
			if not strokes.is_empty():
				var pts: PackedVector2Array = (strokes[0 if first else strokes.size() - 1] as Dictionary)["points"]
				return (a["at"] as Vector2) + pts[0 if first else pts.size() - 1] * float(a["k"]) * DeskScript.PX_PER_PT
			return a.get("at", Vector2(PW * 0.5, PH * 0.3))
		"strike":
			var of := int(a.get("of", -1))
			if of >= 0:
				return _strike_line(_actions[of])[0 if first else 1]
	return Vector2(PW * 0.84, DeskScript.FIRST_RULE + DeskScript.RULE * 2.0)


## Where the pen rests after writing at [param p]: to its right and a little below, clear of the line.
static func _rest_near(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x + 130.0, DeskScript.MATH_X, PW - 70.0),
		clampf(p.y + 40.0, DeskScript.FIRST_RULE, PH - 80.0))


static func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## A point of the page (px) in the world, [param lift] meters above it.
func _world(p: Vector2, lift: float) -> Vector3:
	var local := Vector3((p.x / PW - 0.5) * PAD_W, 0.0003 + lift, (p.y / PH - 0.5) * PAD_H)
	return _pad.transform * local


func _place_pen() -> void:
	var at := pen_at()
	var nib := _world(at["p"], float(at["lift"]))
	var up := PEN_UP.normalized()
	var x := up.cross(Vector3.FORWARD).normalized()
	var z := x.cross(up).normalized()
	_pen.global_transform = Transform3D(Basis(x, up, z), nib)


# --- the camera -------------------------------------------------------------------------------

## THE FRAMING'S TARGET at [member _now]: how close (0 wide, 1 local) and where on the page. Wide until
## the lesson opens, as a page turns and once the last word is said; local on the line being written -
## looked for [constant CAM_LEAD] ahead, the springs being late.
func _framing() -> Dictionary:
	var k := 0.0
	var line := Vector2(PW * 0.5, PH * 0.5)
	var opening := _opening()
	if opening < INF and _now > opening - 1.0:
		k = 1.0
	var ahead := _now + CAM_LEAD
	var page := _pages().x
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var start := float(_plan[i]["start"])
		if start == INF or start > ahead:
			break
		var ta := float(_plan[i]["turn_at"])
		if ta < INF and _now > ta - 1.5 and _now < ta + DeskScript.TURN + 0.5:
			k = 0.25
		if int(a["page"]) == page and a.has("at"):
			line = Vector2((a["at"] as Vector2).x + float(a["w"]) * 0.5, (a["at"] as Vector2).y)
	var known := _follower.known_last()
	if _spoken_n > 0 and known >= _spoken_n - 1 and _now > _follower.st1[known]:
		k = 0.0
	return {"k": k, "line": line}


func _tick_camera(delta: float) -> void:
	var f := _framing()
	var k := float(f["k"])
	var line: Vector2 = f["line"]
	# the whole pad, its binding too, with the desk round it
	var wide_aim := _world(Vector2(PW * 0.5, PH * 0.45), 0.0)
	# local: the line being written, held a little below the frame's middle, never off the pad
	var local_aim := _world(Vector2(clampf(line.x, PW * 0.35, PW * 0.65), clampf(line.y + 60.0, PH * 0.3, PH * 0.72)), 0.0)
	var aim := wide_aim.lerp(local_aim, k)
	var page := _pages().x
	var yaw := (_hash01(page, 41) - 0.5) * 2.0 * YAW_SPREAD + sin(_now * 0.021 + float(_seed % 97)) * YAW_WANDER
	var pitch := lerpf(float(WIDE["pitch"]), float(LOCAL["pitch"]), k) \
		+ (_hash01(page, 67) - 0.5) * 2.0 * TILT_SPREAD + sin(_now * 0.029 + 1.3) * 0.8
	var dist := lerpf(float(WIDE["dist"]), float(LOCAL["dist"]), k) * (1.0 + 0.012 * sin(_now * 0.033 + 2.1))
	var roll := (_hash01(page, 53) - 0.5) * 2.0 * ROLL_SPREAD + sin(_now * 0.047 + 0.7) * 0.5
	if _snap:
		_snap = false
		_c_aim = aim
		_c_dist = dist
		_c_pitch = pitch
		_c_yaw = yaw
		_c_roll = roll
		_v_aim = Vector3.ZERO
		_v_dist = 0.0
		_v_pitch = 0.0
		_v_yaw = 0.0
		_v_roll = 0.0
	var steps := maxi(1, int(ceil(delta / (1.0 / 60.0))))
	var h := delta / float(steps)
	for _i in steps:
		var res := BookMedium._spring3(_c_aim, _v_aim, aim, SPRING_TAU, h)
		_c_aim = res[0]
		_v_aim = res[1]
		var rd := BookMedium._spring(_c_dist, _v_dist, dist, SPRING_TAU, h)
		_c_dist = rd.x
		_v_dist = rd.y
		var rp := BookMedium._spring(_c_pitch, _v_pitch, pitch, SPRING_TAU, h)
		_c_pitch = rp.x
		_v_pitch = rp.y
		var ry := BookMedium._spring(_c_yaw, _v_yaw, yaw, SPRING_TAU * ANGLE_SLOW, h)
		_c_yaw = ry.x
		_v_yaw = ry.y
		var rr := BookMedium._spring(_c_roll, _v_roll, roll, SPRING_TAU * ANGLE_SLOW, h)
		_c_roll = rr.x
		_v_roll = rr.y
	var p := deg_to_rad(_c_pitch)
	var y := deg_to_rad(_c_yaw)
	var dir := Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p))
	_cam.position = _c_aim + dir * _c_dist
	_cam.look_at(_c_aim, Vector3.UP)
	_cam.rotate_object_local(Vector3.FORWARD, deg_to_rad(_c_roll))


static func _hash01(page: int, salt: int) -> float:
	return float(absi(hash(["desk-cam", page, salt])) % 10007) / 10006.0
