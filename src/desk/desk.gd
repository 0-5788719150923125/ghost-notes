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
## the words of its dictation, on the average never faster than [constant DeskScript.MAX_PACE] of the
## pen's own pace nor slower than [constant DeskScript.MIN_PACE]; where it would lag, the voice waits
## at the dictation's end, a rest the script already gave it, and nowhere inside it.
##
## THE PEN IS ELASTIC, AND NEVER STOPS MID-WRITING (the user, 2026-10-17: "the pen stopping at weird
## moments - like halfway between drawing a straight line, pausing for a second or two ... If the
## speech is gaining too far ahead, speed-up the pen. If the pen is too far ahead of the speech, slow
## down the motions. But NEVER should we just be stopping"). The ink's clock was the share of the
## words said, which stands still in every gap between two words - a comma, a breath, a rest - so the
## nib froze mid-stroke; and where the voice rested FOR the pen, the pen, waiting for words, rested
## too. Now it follows the voice's progress smoothed, with a steady share under it ([method elastic]):
## it slows over a pause and speeds over a run of words, and is never still until its line is done.
##
## A PURE FUNCTION OF THE VOICE'S TIME. A pad item is written at `_ink_time`, a function of the words'
## times and now, so any moment can be drawn without the ones before it: a seek lands on the page as it
## was. A READING STARTED MID-WAY (a scrub that starts the voice again from a later chunk) begins where
## its first words are (the document's `start_words`, as the card table and the tablet find theirs):
## everything before them was said long ago, so it is written on the first frame - matched from the
## top instead, no word of the new reading was ever found, and the pen stood still to the end (the
## user, 2026-10-16: "scrubbing the timeline seems to have broken the pen completely"). The camera alone eases (as the book's and the tablet's do), and lands at once on a seek.
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
## which also keeps what it has just written, to the left of the nib, in view. THE HAND IS ALIVE (the
## user, 2026-10-16: "A hand holding a pen would never keep it at a perfectly static angle"): the lean
## sways slowly about that direction ([method lean]), turns a little with where on the page the nib
## is, as a forearm pivoting at the elbow turns it, and its top trails the nib's travel; off the paper
## the nib drifts a few millimeters ([method drift]) - never while it writes, where it is the ink's.
##
## THE PEN POINTS AT WHAT IS SPOKEN OF ([DeskScript]'s `point`; the user: "never POINTING to any of
## it ... after 2 minutes of no movement - it's very hard to get my attention back on track"): at the
## word, the nib comes down close over the named thing - sweeping along under it when it is wide - and
## stays beside its right end, low on its height, so the pen's body leans away over clean paper and
## never onto the line below; the camera goes there.

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
## THE PEN IS ELASTIC ([method elastic]): the voice's progress through a dictation is smoothed over
## this many seconds, and this share of the pen's progress runs steady - the least it ever moves at,
## against its average pace over the dictation.
const ELASTIC_WINDOW := 1.5
const ELASTIC_FLOOR := 0.3
## POINTING: how close over the paper the nib comes; a thing this wide (px) or wider is swept under
## (this far below it) in the first [constant POINT_SWEEP] seconds; where the nib stays, this far right
## of the thing's end; and the least time a point is held.
const POINT_LIFT := 0.0035
const POINT_WIDE := 90.0
const POINT_SWEEP := 0.9
const POINT_GAP := 14.0
const POINT_MIN := 1.0
## THE HAND IS ALIVE: the lean's slow sway (degrees, about the vertical and in its rise), its turn
## across the page's width (degrees from the left edge to the right), how far the top trails the nib
## (seconds of its travel, at most [constant TRAIL_MAX] degrees), measured over [constant MOTION_DT];
## and the nib's drift off the paper (px, and meters of lift), full at rest and none while it writes.
const SWAY_YAW := 5.0
const SWAY_TILT := 3.0
const REACH_YAW := 10.0
const TRAIL := 1.7
const TRAIL_MAX := 7.0
const MOTION_DT := 0.1
const DRIFT_PX := 12.0
const DRIFT_LIFT := 0.003
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
var _records := {}                 # item id -> its typeset record (a part's box in `anchors`)
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
var _canvas: PadCanvas             # the page being written: its dry ink
var _wet: PadCanvas                # and over it, what the pen is writing now
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


## A page, drawn: paper, rules, and the ink on page [member page] now - all of it, or one [member part].
##
## REDRAWN ONLY WHEN WHAT IT SHOWS HAS CHANGED ([method show_page]). A redraw frees and rebuilds every
## stroke on it - each polyline is a GPU polygon of its own, some 400 on a full page - and redrawn every
## frame, the desk made and threw away tens of thousands a second over a page that stood still, all
## night after an export, until the engine crashed freeing one (2026-10-16: signal 11 in
## `free_polygon`). So the page being written is two: its `dry` ink, redrawn as a formula is finished
## or the page changes, under its `wet`, only what the pen is writing now.
class PadCanvas extends Node2D:
	var desk: DeskMedium
	var page := 0
	## "all"; "dry" - the paper, its rules and the ink finished on it; or "wet" - only the ink still
	## being written, over the dry.
	var part := "all"
	var _shown: Array = []

	## Shows page [param p] as [param state] has it (its part of [method DeskMedium.page_state]):
	## queued for a redraw only when either has changed. True when it was.
	func show_page(p: int, state: Array) -> bool:
		if p == page and state == _shown:
			return false
		page = p
		_shown = state
		queue_redraw()
		return true

	## A new lesson: the next [method show_page] redraws, whatever it shows.
	func forget() -> void:
		page = -1
		_shown = []

	func _draw() -> void:
		if part != "wet":
			draw_rect(Rect2(0, 0, PW, PH), PAPER)
			var y := DeskScript.FIRST_RULE
			while y < PH - 20.0:
				draw_line(Vector2(0, y), Vector2(PW, y), RULE_COLOR, 2.6, true)
				y += DeskScript.RULE
			draw_line(Vector2(MARGIN_X, 0), Vector2(MARGIN_X, PH), MARGIN_COLOR, 2.0)
			draw_line(Vector2(MARGIN_X + 6.0, 0), Vector2(MARGIN_X + 6.0, PH), MARGIN_COLOR, 1.5)
		if desk == null or page < 0:
			return
		for line in desk.page_ink(page, part):
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
	_vp = _page_viewport(["dry", "wet"])
	_canvas = _vp.get_child(0) as PadCanvas
	_wet = _vp.get_child(1) as PadCanvas
	_vp_turn = _page_viewport(["all"])
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


## A page's viewport, drawn by a [PadCanvas] for each of [param parts], the first at the bottom.
func _page_viewport(parts: Array) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(int(PW), int(PH))
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	for part in parts:
		var c := PadCanvas.new()
		c.desk = self
		c.part = String(part)
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
	var start: PackedStringArray = d.get("start_words", PackedStringArray()) \
		if d.get("start_words") is PackedStringArray else PackedStringArray()
	var key := "%d|%s|%d|%s" % [src.hash(), String(desk.get("dir", "")), int(desk.get("seed", 0)),
		" ".join(start)]
	if key == _doc_key:
		return
	_doc_key = key
	load_lesson(src, desk, start, int(d.get("start_index", -1)))


## LOAD A LESSON: [param source] (the lesson's text, the pen's marks in it) and [param desk] (`{ink,
## seed}` - the typeset items and the hand's seed); for a reading started mid-way, its first words
## [param start] (normalized), [param near] the index they are about. Public for a gate, which hands
## it one by hand.
func load_lesson(source: String, desk: Dictionary, start := PackedStringArray(), near := -1) -> void:
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
	_records = records
	var parsed: Dictionary = DeskScript.parse(source, lengths, records)
	_actions = parsed["actions"]
	var spoken: PackedStringArray = parsed["spoken"]
	_spoken_n = spoken.size()
	var from := TabletScript.find_run(spoken, start, near) if not start.is_empty() else -1
	var est := PackedFloat32Array()
	if from > 0:
		# the past, spaced as a steady voice would have said it, rests and all
		for w in DeskScript.rehearsal(parsed):
			est.append(float((w as Dictionary)["t0"]))
	_follower.reset(spoken, from, est)
	_built_n = -1
	_plan = []
	for i in _actions.size():
		_plan.append({"start": INF, "end": INF, "turn_at": INF})
	_snap = true
	for c in [_canvas, _wet, _canvas_turn]:
		if c != null:
			(c as PadCanvas).forget()


## WHEN EACH ACTION HAPPENS. A written item starts as its dictation's first word is said (the pen down
## [constant PEN_LEAD] before it) and ends as the words do - no sooner than the pen can write it at
## [constant DeskScript.MAX_PACE], no later than at [constant DeskScript.MIN_PACE] - and never before
## the one before it has ended. One with no dictation, and a strike, are performed in the rest before
## the next words. A POINT is there as its word is said and held to its sentence's end, never into
## the time the pen needs to reach what comes next. A page turn comes in the rest before the item that
## needs it, never over writing still going on, and the item waits for it. An action whose words have
## not arrived waits.
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
		if String(a["kind"]) in DeskScript.WRITES and span > 0:
			var t0 := _word_t0(after)
			if t0 == INF:
				break
			start = maxf(t0 - PEN_LEAD, prev_end)
			var said := _word_t1(after + span - 1)
			end = clampf(said if said < INF else start + float(span) * DeskScript.EST_WORD,
				start + write / DeskScript.MAX_PACE, start + write / DeskScript.MIN_PACE)
		elif String(a["kind"]) == "point":
			var t0 := _word_t0(after)
			if t0 == INF:
				break
			start = maxf(t0, prev_end)
			var said := _word_t1(after + maxi(span, 1) - 1)
			end = maxf(said if said < INF else start + float(span) * DeskScript.EST_WORD, start + POINT_MIN)
			if i + 1 < _actions.size():
				var next := _word_t0(int((_actions[i + 1] as Dictionary).get("after", 0)))
				if next < INF:
					end = maxf(minf(end, next - PEN_LEAD - REACH_EASE), start + 0.3)
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
## of [method Ink.schedule]): a dictated item's by [method elastic], over its dictation's words; one
## written in silence at an even pace, across the rest the voice gives it.
func _ink_time(i: int) -> float:
	var a: Dictionary = _actions[i]
	var start := float(_plan[i]["start"])
	var end := float(_plan[i]["end"])
	var length := _length(i)
	var span := int(a.get("span", 0))
	if span <= 0:
		return length * clampf((_now - start) / maxf(end - start, 0.01), 0.0, 1.0)
	var times := _dictation(int(a["after"]), span, start)
	return length * elastic(_now, start, end, times[0], times[1])


## The times of the [param span] words from [param after]: [t0s, t1s], a word not heard yet placed
## after the last that was, a steady word apart ([constant DeskScript.EST_WORD]).
func _dictation(after: int, span: int, start: float) -> Array:
	var t0s := PackedFloat32Array()
	var t1s := PackedFloat32Array()
	var last := start + PEN_LEAD
	for j in span:
		var t0 := _word_t0(after + j)
		var t1 := _word_t1(after + j)
		if t0 == INF or t1 == INF:
			t0 = last + 0.05
			t1 = t0 + DeskScript.EST_WORD * 0.9
		t0s.append(t0)
		t1s.append(t1)
		last = t1
	return [t0s, t1s]


## THE PEN'S CLOCK, ELASTIC: how far through its writing (0 to 1) the pen is at [param now], for
## writing planned from [param start] to [param end] across words said at [param t0s] to [param t1s].
## A pure function, so a seek lands where the pen would be.
##
## The voice's progress through the words (a word counts as it is said) is smoothed over
## [constant ELASTIC_WINDOW], so a pause in it is a slope and not a step, and its time is stretched
## onto the pen's - the pen that lags runs the whole way behind, evenly, rather than slowing as the
## voice ends. [constant ELASTIC_FLOOR] of the pen's progress runs steady from its start to its end, so
## the pen never stands still while it writes: over a long pause it slows to about that share of its
## average pace, and makes it up over the words after. Then it is set to run from 0 at
## [param start] to 1 at [param end] exactly.
static func elastic(now: float, start: float, end: float, t0s: PackedFloat32Array,
		t1s: PackedFloat32Array) -> float:
	if now <= start:
		return 0.0
	if now >= end or t0s.is_empty():
		return clampf((now - start) / maxf(end - start, 0.01), 0.0, 1.0)
	var warp := maxf(t1s[t1s.size() - 1] - start, 0.01) / (end - start)
	var lo := _elastic_mix(start, start, end, warp, t0s, t1s)
	var hi := _elastic_mix(end, start, end, warp, t0s, t1s)
	return clampf((_elastic_mix(now, start, end, warp, t0s, t1s) - lo) / maxf(hi - lo, 1e-6), 0.0, 1.0)


## [method elastic] before it is set to run from 0 to 1: the smoothed voice at the pen's time, mixed
## with the steady share.
static func _elastic_mix(now: float, start: float, end: float, warp: float, t0s: PackedFloat32Array,
		t1s: PackedFloat32Array) -> float:
	var t := start + (now - start) * warp
	var h := ELASTIC_WINDOW * 0.5
	var voice := (_said_area(t + h, t0s, t1s) - _said_area(t - h, t0s, t1s)) / ELASTIC_WINDOW
	return (1.0 - ELASTIC_FLOOR) * voice + ELASTIC_FLOOR * (now - start) / (end - start)


## The share of words [param t0s]..[param t1s] said, summed over time up to [param t]: its integral,
## so that a window's mean is two calls. A word counts evenly across its own time; a word that starts
## before the last has ended starts as it ends.
static func _said_area(t: float, t0s: PackedFloat32Array, t1s: PackedFloat32Array) -> float:
	var step := 1.0 / float(t0s.size())
	var area := 0.0
	var level := 0.0
	var x := t0s[0]
	for j in t0s.size():
		var a := maxf(t0s[j], x)
		var b := maxf(t1s[j], a + 0.001)
		if t <= a:
			return area + level * maxf(t - x, 0.0)
		area += level * (a - x)
		if t <= b:
			var d := t - a
			return area + level * d + 0.5 * step * d * d / (b - a)
		area += (level + 0.5 * step) * (b - a)
		level += step
		x = b
	return area + (t - x)


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
	var now := page_state(p.x)
	_canvas.show_page(p.x, now["dry"])
	_wet.show_page(p.x, now["wet"])
	_hinge.visible = p.y >= 0
	if p.y >= 0:
		_canvas_turn.show_page(p.y, page_state(p.y)["all"])
		var ta := INF
		for i in _actions.size():
			if int((_actions[i] as Dictionary)["page"]) == p.x and float(_plan[i]["turn_at"]) < INF:
				ta = float(_plan[i]["turn_at"])
				break
		var u := clampf((_now - ta) / DeskScript.TURN, 0.0, 1.0)
		# lifted at its foot and swung up over the binding, a touch faster through the top
		_hinge.rotation.x = -PI * (u * u * (3.0 - 2.0 * u))


## THE INK ON PAGE [param page] NOW, in the page's pixels: [{points, width}] - what [PadCanvas] draws;
## all of it, or the [param part] finished (`dry`) or still being written (`wet`).
func page_ink(page: int, part := "all") -> Array:
	var out: Array = []
	for i in _on_page(page):
		if part != "all" and (_written(i) >= 1.0) != (part == "dry"):
			continue
		out.append_array(_ink_of(i))
	return out


## What page [param page] shows at [member _now], as its [PadCanvas]es key it: the actions finished
## on it (`dry`), each still being written with how much of it is (`wet`), and both (`all`).
func page_state(page: int) -> Dictionary:
	var dry: Array = []
	var wet: Array = []
	for i in _on_page(page):
		var u := _written(i)
		if u >= 1.0:
			dry.append(i)
		else:
			wet.append_array([i, u])
	return {"dry": dry, "wet": wet, "all": dry + wet}


## The actions begun on page [param page] by [member _now], in order (a strike, on the page of what it
## strikes).
func _on_page(page: int) -> Array:
	var out: Array = []
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if float(_plan[i]["start"]) > _now or int(a["page"]) != page or String(a["kind"]) == "point":
			continue
		if String(a["kind"]) == "strike":
			var of := int(a.get("of", -1))
			if of < 0 or int((_actions[of] as Dictionary)["page"]) != page:
				continue
		out.append(i)
	return out


## How long action [param i] takes the pen: its ink's, else what the script gave it.
func _length(i: int) -> float:
	var a: Dictionary = _actions[i]
	return float((_strokes.get(String(a["id"]), {}) as Dictionary).get("length", a.get("write", 0.0)))


## How much of action [param i] is written at [member _now], 0 to 1.
func _written(i: int) -> float:
	var a: Dictionary = _actions[i]
	if String(a["kind"]) == "strike":
		return clampf((_now - float(_plan[i]["start"])) / maxf(float(a["write"]), 0.01), 0.0, 1.0)
	var length := _length(i)
	return 1.0 if length <= 0.0 else clampf(_ink_time(i) / length, 0.0, 1.0)


## Action [param i]'s ink at [member _now], as polylines in the page's pixels.
func _ink_of(i: int) -> Array:
	var a: Dictionary = _actions[i]
	var out: Array = []
	match String(a["kind"]):
		"pad", "pad-text", "draw":
			var sched: Dictionary = _strokes.get(String(a["id"]), {})
			if sched.is_empty():
				return out
			var at: Vector2 = a["at"]
			var k := float(a["k"]) * DeskScript.PX_PER_PT
			for s in Ink.at(sched, _ink_time(i))["ink"]:
				var pts := PackedVector2Array()
				for q in (s as Dictionary)["points"]:
					pts.append(at + (q as Vector2) * k)
				out.append({"points": pts, "width": maxf(2.4, float((s as Dictionary)["width"]) * k * 1.35)})
		"strike":
			var line := _strike_line(_actions[int(a["of"])])
			out.append({"points": PackedVector2Array([line[0], line[0].lerp(line[1], _written(i))]), "width": 3.2})
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
	var last_lift := LIFT
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var start := float(_plan[i]["start"])
		var end := float(_plan[i]["end"])
		if start == INF:
			break
		var pointing := String(a["kind"]) == "point"
		if pointing and target_box(a).size.x < 0.0:
			continue        # at nothing on this page: the pen stays where it is
		var down := POINT_LIFT if pointing else LIFT
		if _now < start:
			# on its way to the next action: from where it rested to where the action begins
			var u := clampf(1.0 - (start - _now) / REACH_EASE, 0.0, 1.0)
			var from := _rest_near(last_point) if last_end > -INF else rest
			if float(_plan[i]["turn_at"]) < INF and _now < start - 0.05:
				from = rest
			return {"p": from.lerp(_action_point(a, true), _ease(u)), "lift": lerpf(REST_LIFT, down, _ease(u))}
		if _now < end:
			return _pen_during(a, i, start)
		last_end = end
		last_point = _action_point(a, false)
		last_lift = down
	if last_end == -INF:
		return {"p": rest, "lift": REST_LIFT}
	var v := clampf((_now - last_end) / REST_EASE, 0.0, 1.0)
	return {"p": last_point.lerp(_rest_near(last_point), _ease(v)), "lift": lerpf(last_lift, REST_LIFT, _ease(v))}


func _pen_during(a: Dictionary, i: int, start: float) -> Dictionary:
	match String(a["kind"]):
		"pad", "pad-text", "draw":
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
		"point":
			var path := point_path(a)
			var u := clampf((_now - start) / POINT_SWEEP, 0.0, 1.0)
			var p: Vector2 = (path[0] as Vector2).lerp(path[1], _ease(u / 0.7)) if u < 0.7 \
				else (path[1] as Vector2).lerp(path[2], _ease((u - 0.7) / 0.3))
			return {"p": p, "lift": POINT_LIFT}
	return {"p": Vector2(PW * 0.84, DeskScript.FIRST_RULE + DeskScript.RULE * 2.0), "lift": REST_LIFT}


## Where an action's writing begins ([param first]) or ends, on the page.
func _action_point(a: Dictionary, first: bool) -> Vector2:
	match String(a["kind"]):
		"pad", "pad-text", "draw":
			var strokes: Array = (_strokes.get(String(a["id"]), {}) as Dictionary).get("strokes", [])
			if not strokes.is_empty():
				var pts: PackedVector2Array = (strokes[0 if first else strokes.size() - 1] as Dictionary)["points"]
				return (a["at"] as Vector2) + pts[0 if first else pts.size() - 1] * float(a["k"]) * DeskScript.PX_PER_PT
			return a.get("at", Vector2(PW * 0.5, PH * 0.3))
		"strike":
			var of := int(a.get("of", -1))
			if of >= 0:
				return _strike_line(_actions[of])[0 if first else 1]
		"point":
			return point_path(a)[0 if first else 2]
	return Vector2(PW * 0.84, DeskScript.FIRST_RULE + DeskScript.RULE * 2.0)


## WHAT A POINT POINTS AT, on the page (px): the box of the thing it names - a part's, from its ink
## record's `anchors`, else the whole thing's - or a box of negative size when that is not on the page
## the point is made over (or was never written).
func target_box(a: Dictionary) -> Rect2:
	var none := Rect2(Vector2.ZERO, Vector2(-1.0, -1.0))
	var of := int(a.get("of", -1))
	if of < 0 or of >= _actions.size():
		return none
	var t: Dictionary = _actions[of]
	if int(t["page"]) != int(a["page"]) or not t.has("at"):
		return none
	var at: Vector2 = t["at"]
	var part := String(a.get("part", ""))
	var anchors: Dictionary = (_records.get(String(t["id"]), {}) as Dictionary).get("anchors", {})
	var b: Array = anchors.get(part, []) if not part.is_empty() and anchors.get(part) is Array else []
	if b.size() == 4:
		var k := float(t["k"]) * DeskScript.PX_PER_PT
		return Rect2(at + Vector2(float(b[0]), float(b[1])) * k,
			Vector2(float(b[2]) - float(b[0]), float(b[3]) - float(b[1])) * k)
	return Rect2(at.x, at.y - float(t["h"]), float(t["w"]), float(t["h"]) + float(t["d"]))


## THE NIB'S WAY WHILE IT POINTS: `[down, along, stays]` - it comes down under a wide thing (a
## formula, a curve) and sweeps along under it, then stays beside its right end, low on its height;
## at a small one (a dot, a label, a short line) it comes straight to that place. Beside the end, the
## pen's body leans away over clean paper, and never onto a line below (an aligned block's next line
## is closer than a rule).
func point_path(a: Dictionary) -> Array:
	var b := target_box(a)
	var stays := Vector2(b.end.x + POINT_GAP * 0.5, b.position.y + b.size.y * 0.7)
	if b.size.x >= POINT_WIDE:
		var y := b.end.y + POINT_GAP * 0.5
		return [Vector2(b.position.x + b.size.x * 0.1, y), Vector2(b.end.x - b.size.x * 0.05, y), stays]
	return [stays, stays, stays]


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
	var p: Vector2 = at["p"]
	var lift := float(at["lift"])
	var keep := _now
	_now = keep - MOTION_DT
	var before: Vector2 = pen_at()["p"]
	_now = keep
	var moved := (p - before) / MOTION_DT
	var d := drift(_now, _seed, lift)
	var up := lean(PEN_UP, _now, _seed, p.x / PW,
		Vector3(moved.x / PW * PAD_W, 0.0, moved.y / PH * PAD_H))
	var nib := _world(p + (d["dp"] as Vector2), lift + float(d["dlift"]))
	var x := up.cross(Vector3.FORWARD).normalized()
	var z := x.cross(up).normalized()
	_pen.global_transform = Transform3D(Basis(x, up, z), nib)


## THE PEN'S LEAN at [param now]: [param base] swayed slowly about the vertical and in its rise (the
## phases the hand's [param seed]'s), turned toward the page's top as the nib goes left
## ([param x_share], 0 at the page's left edge, 1 at its right - a forearm pivoting at the elbow), and
## its top trailing [param motion], the nib's travel across the desk (m/s). A unit vector, always within
## a few degrees of [param base]. Pure: the same moment is the same lean.
static func lean(base: Vector3, now: float, seed: int, x_share: float, motion: Vector3) -> Vector3:
	var ph := _phases(seed)
	var up := base.normalized()
	var yaw := SWAY_YAW * (0.65 * sin(TAU * now / 7.3 + ph[0]) + 0.35 * sin(TAU * now / 3.1 + ph[1])) \
		+ REACH_YAW * (0.7 - clampf(x_share, 0.0, 1.0))
	up = up.rotated(Vector3.UP, deg_to_rad(yaw))
	var flat := Vector3(up.x, 0.0, up.z)
	if flat.length() > 0.001:
		var tilt := SWAY_TILT * sin(TAU * now / 5.7 + ph[2])
		up = up.rotated(Vector3.UP.cross(flat).normalized(), deg_to_rad(tilt))
	var trail := Vector3(motion.x, 0.0, motion.z) * -TRAIL
	var most := tan(deg_to_rad(TRAIL_MAX))
	if trail.length() > most:
		trail = trail.normalized() * most
	return (up + trail).normalized()


## THE NIB'S DRIFT off the paper at [param now]: `{dp, dlift}` (px, m) - slow, a few millimeters, in
## proportion to how high it is held ([param lift] of [constant REST_LIFT]): full at rest, slight while
## it points, none while it writes, where the nib is the ink's.
static func drift(now: float, seed: int, lift: float) -> Dictionary:
	var w := clampf(lift / REST_LIFT, 0.0, 1.0)
	var ph := _phases(seed)
	var dx := 0.6 * sin(TAU * now / 9.1 + ph[3]) + 0.4 * sin(TAU * now / 4.3 + ph[4])
	var dy := 0.6 * sin(TAU * now / 8.3 + ph[5]) + 0.4 * sin(TAU * now / 3.7 + ph[6])
	return {"dp": Vector2(dx, dy) * DRIFT_PX * w, "dlift": DRIFT_LIFT * sin(TAU * now / 6.1 + ph[7]) * w}


## The hand's phases, from its seed: eight angles.
static func _phases(seed: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in 8:
		out.append(TAU * _hash01(seed, 700 + k))
	return out


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
		if String(a["kind"]) == "point":
			# a point is framed on what it points at
			var b := target_box(a)
			if b.size.x >= 0.0 and int(a["page"]) == page:
				line = b.get_center()
			continue
		if int(a["page"]) == page and a.has("at"):
			# a drawing is framed on its middle; a line of writing, on its baseline
			var up := float(a.get("h", 0.0)) * 0.5 if String(a["kind"]) == "draw" else 0.0
			line = Vector2((a["at"] as Vector2).x + float(a["w"]) * 0.5, (a["at"] as Vector2).y - up)
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
