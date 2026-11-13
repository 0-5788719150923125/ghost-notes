extends Medium
class_name DeskMedium

## DeskMedium - a desk with a legal pad under a lamp, and a pen that writes on it by itself while the voice reads aloud
## what it writes (next/proof.md, "The desk"): the base a Letter is written at ([LetterMedium]). No row of [constant
## Medium.REGISTRY] names it.
##
## Draws from the reading's document (`_subs.document`): `source` (the words with the pen's marks, [DeskScript]), `desk`
## (every formula as TeX laid it out, `ink`, and the hand's `seed`), `title` and `byline`. Opens and closes as the card
## table does ([ShowOpening]): the name over the desk far out of focus while the intro holds, focus pulled at the first
## word, black a beat after the last.
##
## The pen writes what the voice says, as it says it: a formula's writing runs across exactly the words of its dictation,
## on average between [constant DeskScript.MIN_PACE] and [constant DeskScript.MAX_PACE] of the pen's own pace; where it
## would lag, the voice waits at the dictation's end, a rest the script already gave it. The pen is elastic and never stops
## mid-writing: it follows the voice's progress smoothed, with a steady share under it ([method elastic]).
##
## A pure function of the voice's time: a pad item is written at `_ink_time`, a function of the words' times and now, so a
## seek lands on the page as it was. A reading started mid-way begins where its first words are (`start_words`); the camera
## alone eases. A live reading's word times arrive a sentence at a time, so a plan made again holds the past ([method
## _hold_past]): what has begun keeps its start and its page's turn, what is done stays done, a line being written goes on
## from where it is ([method _ink_time]). A reading whose times are all known at once (an export) is never planned again.
##
## A drawing runs on past its dictation, through the talk about it (`about`), at the hand's pace ([constant DRAW_PACE]),
## done [constant DRAW_SETTLE] and the nib's way before the pen's next action is due ([method _drawn_by]). The voice gets no
## added or removed rest.
##
## The pad: a legal pad page (8.5 x 11 in), ruled, filled top to bottom ([method DeskScript.lay_out]) and turned only when
## the next item would run off the foot ([LegalPad]). Each episode's desk is its own ([DeskLook], from the seed), lit by the
## room and candles ([DeskLight]). The camera is the book's kind ([BookMedium]): a long lens from high and a little in
## front, wide over the intro and a page turn, closer while the pen writes, on one slow critically damped spring, with a
## wander over minutes.
##
## The pen has no hand, and is the table's ([Pen]): it leans to the top right of the frame from its nib, swaying slowly,
## turning a little with where the nib is on the page, its top trailing the nib's travel; off the paper the nib drifts a
## few millimeters, never while it writes. It points at what is spoken of ([DeskScript]'s `point`): the nib comes down
## close over the named thing, sweeping along under a wide one, and stays beside its right end so the body leans over
## clean paper. When it does each thing is the desk's, on the voice's words. An idle pen waits beside where it stopped, and
## through a long wait the hand settles there on the paper ([method _settled]); before a page turns it drifts off the pad's
## top right ([constant PARK]), and comes back as its next action begins ([method _waiting]). Every move between actions is continuous and as long as its way ([method _reach]); the plan leaves
## that time ([method _way]).

## The page's canvas (an 8.5 x 11 sheet) and the sheet in the world, in meters.
const PW := DeskScript.PW
const PH := DeskScript.PH
const PAD_W := LegalPad.W
const PAD_H := LegalPad.H
## The pen's body, in meters; how it eases to where it waits ([constant Pen.REST_LIFT] up).
const PEN_LEN := 0.135
const PEN_R := 0.0048
## The pen's length from nib to top (m), as [DeskMedium] builds it.
const PEN_TOP := PEN_LEN + 0.02
## The pick-up ([method _pick_up_pose]): how long it takes, from lying on the desk to over the first stroke (seconds);
## where the fingers hold it, up from the nib (m); the share of the way it is turned up into the hand over, and the share
## it is raised alone before it is carried; and how high its grip arcs over the pad (m) - its nib clears the pad's edge by
## about the height the desk's pen waits at ([constant Pen.REST_LIFT]).
const PICK_UP := 2.2
const PICK_GRIP := 0.05
const PICK_TURN := 0.45
const PICK_CARRY := 0.25
const PICK_ARC := 0.05
## The set-down ([method _set_down_pose]): how long after the pen's last action it begins (seconds) - the nib settles
## beside where it stopped first, as after any line ([constant DeskMedium.REST_EASE]); the way back is the pick-up's,
## [constant PICK_UP] long.
const SET_DOWN_AFTER := 1.0
const REST_EASE := 0.9
const REACH_EASE := 0.45
## The pen comes down this long before its dictation's first word.
const PEN_LEAD := 0.2
## A word not heard yet is guessed at the pace the voice has kept over its last this many words heard, its pauses with them
## ([method _pace]); before this many are heard, at [constant DeskScript.SAID_WORD].
const PACE_WORDS := 40
const PACE_FIRST := 8
## A line under way that a plan made again has behind where it should be catches up over this long at the least (seconds;
## [method _ink_time]).
const CATCH_UP := 0.6
## A write's end guessed from words not heard yet is never sooner than this long from now ([method _build_plan]): overtaken,
## the plan is made again ([method take_words]).
const GUESS_AHEAD := 1.0
## A long wait: where the pen waits this long or longer between two actions, the hand settles ([constant Pen.SETTLED_LIFT]) -
## from this long after the last ends, over this long - and lifts the pen again over this long before it sets off for the
## next ([method _settled]). A shorter pause the pen waits out held up.
const SETTLE_WAIT := 5.0
const SETTLE_AFTER := 1.5
const SETTLE_EASE := 1.4
const SETTLE_RISE := 0.7
## A drawing takes its time (see the class note): never quicker than its dictation, and on past it, through the talk about
## it, to as slow as the hand's own pace - done this long, and the nib's way, before the pen's next action is due.
const DRAW_PACE := 1.0
const DRAW_SETTLE := 1.0
## The pen is elastic ([method elastic]): the voice's progress through a dictation is smoothed over this many seconds, and
## this share of the pen's progress runs steady - the least it ever moves at, against its average pace.
const ELASTIC_WINDOW := 1.5
const ELASTIC_FLOOR := 0.3
## The least time a point is held ([Pen]'s pointing).
const POINT_MIN := 1.0
## Out of the way ([method _parks]): off the pad - this long after its last action ends, over this long - to this place (px
## of the page: right of its edge, level with its top margin).
const PARK_AFTER := 1.0
const PARK_EASE := 2.5
const PARK := Vector2(DeskScript.PW + 90.0, DeskScript.FIRST_RULE * 0.5)
## It goes right first, and is off the pad this long after it sets off: a page never turns sooner after the last action
## before it (the sheet lifts at its foot, where that action was). It comes back over the new page once this share of the
## turn is over: the sheet folded under and the pad's head down again ([method LegalPad.tilt]).
const PARK_CLEAR := 1.0
const PARK_BACK := 0.93
## How fast the nib travels to its next action between two (px of the page a second, on the average).
const REACH_SPEED := 1000.0
## The camera: a long lens (a wide one stood close bends the page's lines), wide enough to hold the whole pad with room
## round it, closer while the pen writes; mostly looking down. Distances in meters, pitches in degrees above the desk.
const VFOV := 20.0
const WIDE := {"dist": 1.45, "pitch": 74.0}
## The room's light where the desk's look writes none ([DeskLight]): a warm gray.
const AMBIENT := Color(0.55, 0.5, 0.45)
const AMBIENT_ENERGY := 0.35
const LOCAL := {"dist": 0.82, "pitch": 79.0}
const SPRING_TAU := 3.2
const YAW_SPREAD := 4.0
const YAW_WANDER := 1.5
const ROLL_SPREAD := 1.0
const TILT_SPREAD := 1.5
const ANGLE_SLOW := 3.0
## How long the framing looks ahead of the pen, as the book's does (springs make every move late).
const CAM_LEAD := 2.0
## A page turn is seen whole: the camera stands back this long before it (its springs are slow) and aims this far down the
## page, so the pad's head, where the page goes round, is in the shot.
const TURN_BACK := 3.0
const TURN_AIM := 0.36
## The page's margin line, from its left edge (px). Its colors, the paper's and the ink's are the desk's look's ([member
## look]).
const MARGIN_X := 128.0
## A faint line ([constant Ink.FAINT], a figure's grid): how thin it may be drawn (px) and how light.
const FAINT_W := 1.3
const FAINT_ALPHA := 0.38

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
var _first_pen := 0               # the pen picked up first: the desk's own, or a letter's first ink
var _held := {}                    # action -> what was shown of it when the plan was made again
## Worked out once, not every frame: the plans made so far, which a frame's answers are kept for ([method _pages]), and
## each finished action's ink, the same at any later moment ([method _done_ink_of]).
var _plan_rev := 0
var _guessed_until := INF           # the soonest a write's end, guessed from words not heard yet, is overtaken
var _done_ink := {}
var _pages_now := NAN
var _pages_rev := -1
var _pages_got := Vector2i.ZERO
var _by_page := {}                  # a page -> its actions, in order ([method _page_actions]), for the actions in _by_page_of
var _turning: Array = []            # ...and the actions a page is turned for, in order
var _by_kind := {}                  # ...and each kind's ([method _of_kind])
var _by_page_of: Array = []
## Where the pen's walk goes on from ([method pen_at]): the actions before [member _pen_k] are all done at any moment
## from [member _pen_upto] on, the last of them the pen did [member _pen_last] - for the plan [member _pen_rev].
var _pen_k := 0
var _pen_last := -1
var _pen_upto := -INF
var _pen_rev := -1
var _ink_t := {}                    # [method _ink_time] by moment, then action, for the plan [member _ink_t_rev]
var _ink_t_rev := -1
var _now := 0.0
var _last_now := -1.0
var _snap := true

var _vp: SubViewport               # the page being written: the dry page under the wet ink
var _vp_dry: SubViewport           # ...its paper, rules and finished ink, inside it
var _vp_turn: SubViewport          # the page turning away
var _canvas: PadCanvas             # the page being written: its dry ink
var _wet: PadCanvas                # and over it, what the pen is writing now
var _canvas_turn: PadCanvas
var _placeholder: GhostScene
var _root3: Node3D
var _cam: Camera3D
var _attrs: CameraAttributesPractical
var _env: Environment
var _pad: LegalPad
var _desk: Node3D                  # the desk's top and the things on it
## The desk's light beyond its lamp: the room's and the candles' ([DeskLight]).
var _light := DeskLight.new()
var _stage_was := {}                  # the stage's own settings, given back on leaving it
var _lamp: SpotLight3D
var _fill: DirectionalLight3D
var _lacquer: StandardMaterial3D   # the pen's body
var _trim: StandardMaterial3D      # ...and its metal
var _pen: Node3D
var _dressed := -1                 # the seed the desk was last dressed for
## The desk's look ([method DeskLook.of]): its colors and what is on it, from the episode's seed.
var look: Dictionary = DeskLook.of(1)
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
## Redrawn only when what it shows has changed ([method show_page]): a redraw frees and rebuilds every stroke on it (each
## polyline is a GPU polygon of its own, some 400 on a full page), so redrawing every frame is costly and has crashed the
## engine in `free_polygon`. The page being written is therefore two: its `dry` ink, redrawn as a formula is finished or
## the page changes, under its `wet`, only what the pen is writing now.
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
		if desk == null:
			return
		var look: Dictionary = desk.look
		if part != "wet":
			draw_rect(Rect2(0, 0, PW, PH), look["paper"])
			var y := DeskScript.FIRST_RULE
			while y < PH - 20.0:
				draw_line(Vector2(0, y), Vector2(PW, y), look["rule"], 2.6, true)
				y += DeskScript.RULE
			draw_line(Vector2(MARGIN_X, 0), Vector2(MARGIN_X, PH), look["margin"], 2.0)
			draw_line(Vector2(MARGIN_X + 6.0, 0), Vector2(MARGIN_X + 6.0, PH), look["margin"], 1.5)
		if page < 0:
			return
		var ink: Color = look["ink"]
		# what is shown is what was worked out for it this frame ([method DeskMedium.page_state]): the dry its
		# finished actions, the wet `[action, share, ...]` - never the page walked again
		var lines: Array = []
		match part:
			"dry":
				for i in _shown:
					lines.append_array(desk._done_ink_of(int(i)))
			"wet":
				for k in range(0, _shown.size(), 2):
					lines.append_array(desk._ink_of(int(_shown[k])))
			_:
				lines = desk.page_ink(page, part)
		for line in lines:
			var pts: PackedVector2Array = line["points"]
			var own: Color = line.get("color", ink)
			var c := Color(own, FAINT_ALPHA) if bool(line.get("faint", false)) else own
			if pts.size() >= 2:
				draw_polyline(pts, c, float(line["width"]), true)
			elif pts.size() == 1:
				draw_circle(pts[0], float(line["width"]) * 0.5, c)


# --- mount -------------------------------------------------------------------------------

func mount(st: SubViewport) -> void:
	super.mount(st)
	# the stage as the card table sets it ([constant TableMedium.STAGE]): the lamp's shadow in a slot of its own of a big
	# atlas, debanded (the stage's own atlas shows a diagonal moire of the lamp's shadow map on the page and desk)
	_stage_was = {}
	for key in TableMedium.STAGE:
		_stage_was[key] = st.get(key)
		st.set(key, TableMedium.STAGE[key])
	_light.medium = self
	_placeholder = GhostScene.new()
	_placeholder.init_with_seed(1, "drift")
	_placeholder.visible = false
	add_child(_placeholder)
	# a page is rendered only when it changes: its finished ink is a viewport of its own, rendered as a line is finished;
	# the page the pad shows is that under the line being written, rendered as the pen moves; the turning page once a turn
	# ([method _show_pages])
	_vp_dry = _page_viewport(["dry"])
	_canvas = _vp_dry.get_child(0) as PadCanvas
	_vp = _page_viewport([])
	# inside the page it is drawn under, so it is rendered before it
	remove_child(_vp_dry)
	_vp.add_child(_vp_dry)
	var under := TextureRect.new()
	under.texture = _vp_dry.get_texture()
	_vp.add_child(under)
	_wet = PadCanvas.new()
	_wet.desk = self
	_wet.part = "wet"
	_vp.add_child(_wet)
	_vp_turn = _page_viewport(["all"])
	_canvas_turn = _vp_turn.get_child(0) as PadCanvas
	_build_world()
	_blur = IntroBlur.new(ShowOpening.INTRO_SHADER)
	add_child(_blur)
	_title = TitleCard.new()
	_title.face = CardTable.font("roman")
	_title.italic = CardTable.font(CardTable.BOOK_ITALIC)
	# in the pad's own ink: the card table's light name is cream on cream over the paper; dark, its shade turns light
	# round it (CardTable.title_shade)
	_title.ink = look["ink"]
	add_child(_title)
	_dress()


## A page's viewport, drawn by a [PadCanvas] for each of [param parts], the first at the bottom.
func _page_viewport(parts: Array) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(int(PW), int(PH))
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
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
	_env.ambient_light_color = AMBIENT
	_env.ambient_light_energy = AMBIENT_ENERGY
	# The tonemapper, as the Look has it ([Tonemaps]): Filmic unless a note picks another, at the exposure tuned under Filmic
	Tonemaps.dress(_env, 1.0)
	_env.adjustment_enabled = true
	# Bounce light, as the Graphics panel has it (off unless chosen: it changes the look)
	Graphics.dress(_env)
	_cam = Camera3D.new()
	_cam.fov = VFOV
	_cam.near = 0.05
	_cam.far = 40.0
	_cam.environment = _env
	_attrs = CameraAttributesPractical.new()
	_attrs.dof_blur_far_enabled = false
	_cam.attributes = _attrs
	_root3.add_child(_cam)
	# the lamp, up and to the left of the pad, so the pen's shadow falls across the page to the right; where exactly, how
	# warm and how bright are the desk's look's
	_lamp = SpotLight3D.new()
	_lamp.spot_range = 4.0
	_lamp.spot_angle = 42.0
	_lamp.spot_angle_attenuation = 1.4
	_lamp.shadow_enabled = true
	_lamp.shadow_bias = 0.005
	_lamp.shadow_normal_bias = 0.15
	_lamp.shadow_blur = ShadowFilter.blur(2.8)
	_root3.add_child(_lamp)
	_fill = DirectionalLight3D.new()
	_fill.light_energy = 0.18
	_root3.add_child(_fill)
	_fill.rotation_degrees = Vector3(-60.0, 35.0, 0.0)

	_pad = LegalPad.new()
	_root3.add_child(_pad)

	_pen = Node3D.new()
	_root3.add_child(_pen)
	_lacquer = StandardMaterial3D.new()
	_lacquer.metallic = 0.3
	_lacquer.roughness = 0.28
	_trim = StandardMaterial3D.new()
	_trim.metallic = 0.9
	_trim.roughness = 0.3
	# the pen's own frame: its nib at the origin, its body up along +Y
	_pen.add_child(_cyl(PEN_R * 0.85, 0.0005, 0.02, 0.01, _trim))
	_pen.add_child(_cyl(PEN_R, PEN_R * 0.92, PEN_LEN, 0.02 + PEN_LEN * 0.5, _lacquer))
	_pen.add_child(_cyl(PEN_R * 1.04, PEN_R * 1.04, 0.006, 0.02 + PEN_LEN * 0.62, _trim))


## The desk dressed in [member look]: its top and the things on it, the pad's paper and binding, the pen, the lamp and the
## title's ink - once for each seed, as a lesson is loaded.
func _dress() -> void:
	if _root3 == null or _dressed == _seed:
		return
	_dressed = _seed
	if _desk != null:
		_desk.queue_free()
	var dressed := DeskLook.dress(look, _seed, LegalPad.DESK_Y)
	_desk = dressed["node"]
	_root3.add_child(_desk)
	_pad.seed = _seed
	_pad.build(look, _vp.get_texture(), _vp_turn.get_texture())
	var lamp: Dictionary = look["lamp"]
	_lamp.light_color = lamp["color"]
	_lamp.light_energy = float(lamp["energy"]) * float(lamp.get("share", 1.0))
	_lamp.visible = float(lamp.get("share", 1.0)) > 0.0
	_lamp.position = lamp["at"]
	_lamp.look_at_from_position(_lamp.position, Vector3(0.02, 0.0, 0.02), Vector3.UP)
	_fill.light_color = look["fill"]
	# the room's light and the candles ([DeskLight]); the old flat fill only where the look writes no room
	_env.ambient_light_color = AMBIENT
	_env.ambient_light_energy = AMBIENT_ENERGY
	_light.build(look, dressed["lit"], _seed)
	_fill.visible = not _light.lights_room()
	# ...what casts a candle's shadow cut fine enough for its paraboloids ([ShadowCasters], [method TableLight.candle_shadow])
	ShadowCasters.cut_under(_root3)
	var pen: Dictionary = look["pen"]
	_lacquer.albedo_color = pen["body"]
	_trim.albedo_color = pen["trim"]
	_title.ink = look["ink"]
	for c in [_canvas, _wet, _canvas_turn]:
		(c as PadCanvas).forget()


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
	if _now < _last_now - 1.0:
		# back in time: what was shown is not the past any more
		_held = {}
		_built_n = -1
	_last_now = _now
	if _subs != null and is_instance_valid(_subs) and not _actions.is_empty():
		take_words(_subs.words)
	# Up from black as the session starts, down to it after the last word - the desk owns its
	# bookend, as the card table does; an outro mark's fade still is the feed's
	_env.adjustment_brightness = clampf(clampf(t / 1.2, 0.0, 1.0)
		* _end_fade() * feed.live_fade, 0.0, 1.0)
	var opening := _opening()
	ShowOpening.lens(ShowOpening.pull(feed.opening, _now, opening, _built_n > 0), _blur, _attrs)
	_title.alpha = ShowOpening.title_alpha(feed.opening, _now, opening, _built_n > 0)
	_title.queue_redraw()
	_show_pages()
	_place_pen()
	_tick_camera(delta)
	_light.tick(_now)


func _exit_tree() -> void:
	_light.release()
	if stage != null and is_instance_valid(stage) and not _stage_was.is_empty():
		for key in _stage_was:
			stage.set(key, _stage_was[key])


## The close: 1 until the lesson is over, then down to black over the outro ([method ShowOpening.end_fade]).
func _end_fade() -> float:
	return ShowOpening.end_fade(_now, _follower, _spoken_n, feed.tail())


## The voice's words so far (the overlay's growing `words`), matched, and the plan made again when more came. More of the
## same reading keeps what the page shows ([method _hold_past]) - taken before the new times are, since they move where a
## dictation's unheard words were guessed; a new one (fewer words) starts clean. Public for a gate, which hands it words
## as a live reading would.
func take_words(words: Array) -> void:
	var grown := words.size() != _built_n
	if grown:
		if _built_n > 0 and words.size() > _built_n:
			_hold_past()
		else:
			_held = {}
	_follower.extend(words)
	if grown:
		_built_n = words.size()
		_build_plan()
	elif _now >= _guessed_until:
		# ...a write's end guessed from words not heard yet, overtaken in a pause before they come: made again from now
		_hold_past()
		_build_plan()


## The lesson opens a settle before its first word, which the pen's first dictation is ([method Openings.settle]: the
## desk seen sharp, the name gone, before the teacher speaks): INF until it is heard.
func _opening() -> float:
	var t := _word_t0(0)
	return t - Openings.settle(t) if t < INF else INF


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


## Load a lesson: [param source] (the lesson's text, the pen's marks in it) and [param desk] (`{ink, seed}` - the typeset
## items and the hand's seed); for a reading started mid-way, its first words [param start] (normalized), [param near] the
## index they are about. Public for a gate, which hands it one by hand.
func load_lesson(source: String, desk: Dictionary, start := PackedStringArray(), near := -1) -> void:
	_seed = int(desk.get("seed", _seed))
	look = DeskLook.of(_seed)
	_dress()
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
	_begin(parsed["spoken"], start, near, func() -> PackedFloat32Array: return DeskScript.word_starts(parsed))


## The desk begun again on [member _actions], read as [param spoken] (every spoken word, normalized): the voice followed on
## those words - from [param start]'s run, near word [param near], for a reading started mid-way, each word's time from the
## top then [param est_of] (`() -> PackedFloat32Array`, asked only then) - and the plan, the pages and the camera from
## nothing. A lesson, a letter and an episode each lay out their actions and begin here.
func _begin(spoken: PackedStringArray, start: PackedStringArray, near: int, est_of: Callable) -> void:
	_spoken_n = spoken.size()
	var from := TabletScript.find_run(spoken, start, near) if not start.is_empty() else -1
	_follower.reset(spoken, from, est_of.call() if from > 0 else PackedFloat32Array())
	_built_n = -1
	_held = {}
	_plan = []
	_plan_rev += 1
	_done_ink = {}
	for i in _actions.size():
		_plan.append({"start": INF, "end": INF, "turn_at": INF})
	_snap = true
	for c in [_canvas, _wet, _canvas_turn]:
		if c != null:
			(c as PadCanvas).forget()


## When each action happens. A written item starts as its dictation's first word is said (the pen down [constant PEN_LEAD]
## before it) and ends as the words do, between [constant DeskScript.MAX_PACE] and [constant DeskScript.MIN_PACE] of the
## pen's own pace, never before the one before it has ended; a drawing goes on past its words ([method _drawn_by]). An item
## with no dictation, and a strike, are performed in the rest before the next words. A point is there as its word is said,
## held to its sentence's end. A page turn comes in the rest before the item that needs it, never over writing still going
## on nor before the pen is off the pad ([constant PARK_CLEAR]). No action begins before the nib can get there from the
## last ([method _way]); an action whose words have not arrived waits. What [member _held] keeps of the past is kept: a
## start, a turn, a done action's end; one under way ends no sooner than the pen can finish it from where it is.
func _build_plan() -> void:
	_plan_rev += 1
	_guessed_until = INF
	var prev_end := -INF
	var last := -1                  # the last action the pen does
	for i in _actions.size():
		_plan[i] = {"start": INF, "end": INF, "turn_at": INF}
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var held: Dictionary = _held.get(i, {})
		if held.has("start") and held.has("end"):
			# done before the plan was made again, and kept as it was: all that is worked out below for it is overwritten
			# (a live reading makes the plan again as each sentence's words arrive)
			_plan[i] = {"start": float(held["start"]), "end": float(held["end"]), "turn_at": float(held.get("turn_at", INF))}
			prev_end = float(held["end"])
			if not (String(a["kind"]) == "point" and target_box(a).size.x < 0.0):
				last = i
			continue
		var ready := prev_end + (_way(last, i) if last >= 0 else 0.0)
		if last < 0:
			ready = maxf(ready, _first_floor())
		var after := int(a.get("after", 0))
		var span := int(a.get("span", 0))
		var write := float(a.get("write", 0.0))
		var start := INF
		var end := INF
		if String(a["kind"]) in DeskScript.WRITES and span > 0:
			# ...ahead of the voice by what its own first words take to say, where the medium's pen leads ([method _lead_of])
			var lead := _lead_of(i)
			var due := _due(i, _word_t0(after))
			if due == INF:
				break
			start = float(held.get("start", maxf(due - lead - _early(i), ready)))
			var said := _word_t1(after + span - 1)
			end = clampf(said - lead if said < INF else maxf(_guess(after + span - 1, true) - lead, _now + GUESS_AHEAD),
				start + write / DeskScript.MAX_PACE, start + write / DeskScript.MIN_PACE)
			end = _paced_end(i, start, end)
			if String(a["kind"]) == "draw":
				end = maxf(end, minf(start + write / DRAW_PACE, _drawn_by(i)))
			if said == INF and end < start + write / DeskScript.MIN_PACE - 0.01:
				# (made again a little before it comes, so the guess is never taken for the write being done)
				_guessed_until = minf(_guessed_until, end - GUESS_AHEAD * 0.5)
		elif String(a["kind"]) == "point":
			var t0 := _word_t0(after)
			if t0 == INF:
				break
			start = float(held.get("start", maxf(t0, ready)))
			var said := _word_t1(after + maxi(span, 1) - 1)
			# held its `linger` past its words, where the script rests the voice for it (a letter's, LetterScript.POINT_LINGER)
			end = maxf((said if said < INF else start + float(span) * DeskScript.EST_WORD) + float(a.get("linger", 0.0)),
				start + POINT_MIN)
			if i + 1 < _actions.size():
				var next := _word_t0(int((_actions[i + 1] as Dictionary).get("after", 0)))
				if next < INF:
					end = maxf(minf(end, next - PEN_LEAD - REACH_EASE), start + 0.3)
		else:
			var before := _word_t1(after - 1) if after > 0 else maxf(feed.intro_hold, 0.6) + _blank() - 0.25
			if before == INF:
				break
			# an action the writer decides on first (a letter's strike, [constant LetterScript.DECIDE]): the
			# voice and the pen both done, then that long, the pen held still
			var decide := float(a.get("decide", 0.0))
			var due := maxf(before, prev_end) + decide if decide > 0.0 else before + 0.25
			start = float(held.get("start", maxf(due, ready)))
			end = _paced_end(i, start, start + write)
		var turn_at := float(held.get("turn_at", INF))
		if bool(a.get("turn", false)) and not held.has("start"):
			var back := DeskScript.TURN * PARK_BACK + _travel(PARK.distance_to(_action_point(a, true)))
			if not held.has("turn_at"):
				turn_at = maxf(start - back - 0.1, prev_end + PARK_CLEAR)
			# ...and what waits a while once the page is over (a letter's drawing, for the camera: its `settle`)
			var late := maxf(turn_at + DeskScript.TURN + 0.05 + float(a.get("settle", 0.0)), turn_at + back) - start
			if late > 0.0:
				start += late
				end = _replanned_end(i, start, end + late)
		if held.has("end"):
			end = float(held["end"])
		elif held.has("at"):
			end = maxf(end, float(held["at"]) + maxf((1.0 - float(held.get("u", 0.0))) * write / _quickest(i), 0.3))
		_plan[i] = {"start": start, "end": end, "turn_at": turn_at}
		prev_end = end
		if not (String(a["kind"]) == "point" and target_box(a).size.x < 0.0):
			last = i


## How long the nib needs to get from action [param last] to action [param next]: its way at [constant REACH_SPEED],
## never under [constant REACH_EASE] - none for a point at nothing on its page, which the pen leaves be. [method
## _build_plan] leaves it between them, so no reach is squeezed into nothing.
func _way(last: int, next: int) -> float:
	var b: Dictionary = _actions[next]
	if String(b["kind"]) == "point" and target_box(b).size.x < 0.0:
		return 0.0
	var from := PARK if _parks(last, next) else _action_point(_actions[last], false)
	return _travel(from.distance_to(_action_point(b, true)))


## How long the nib takes over [param px] of the page between two actions: at [constant REACH_SPEED],
## never under [constant REACH_EASE].
func _travel(px: float) -> float:
	return maxf(px / REACH_SPEED, REACH_EASE)


## The latest drawing [param i] may end: as the talk about it ends (a drawing with none, the next mark right after its
## line, has the voice's rest before it), and [constant DRAW_SETTLE] and the nib's way before the pen's next action is due
## (a write's pen down, a point's word, a page's turn early enough for the pen to come back behind the sheet; [method
## _build_plan] gives each the same time). A word not heard yet is guessed a steady word on from the last that was
## ([method _guess]).
func _drawn_by(i: int) -> float:
	var a: Dictionary = _actions[i]
	var about := int(a.get("about", 0))
	var by := _guess(int(a["after"]) + int(a["span"]) + about - 1, true) if about > 0 else INF
	for j in range(i + 1, _actions.size()):
		var b: Dictionary = _actions[j]
		var kind := String(b["kind"])
		if kind == "point" and target_box(b).size.x < 0.0:
			continue
		var after := int(b.get("after", 0))
		var due := _guess(after, false)
		if kind in DeskScript.WRITES and int(b.get("span", 0)) > 0:
			due -= PEN_LEAD
		elif kind != "point":
			due = _guess(after - 1, true) + 0.25
		if bool(b.get("turn", false)):
			var back := DeskScript.TURN * PARK_BACK + _travel(PARK.distance_to(_action_point(b, true)))
			due = minf(due - _way(i, j), due - back - 0.1 - PARK_CLEAR)
		else:
			due -= _way(i, j)
		return minf(by, due - DRAW_SETTLE)
	return by


## When spoken word [param si] begins (or [param ends]): heard, or guessed at the voice's own pace ([method _pace]) on from
## the last word heard - and never sooner than now, as a word the voice has not reached is not said yet; INF before any is.
func _guess(si: int, ends: bool) -> float:
	var t := _word_t1(si) if ends else _word_t0(si)
	if t < INF:
		return t
	var k := mini(si, _follower.said1.size()) - 1
	while k >= 0 and _follower.said1[k] == ReadingFollower.NO_TIME:
		k -= 1
	if k < 0:
		return INF
	return maxf(_follower.said1[k], _now) + float(si - k - (0 if ends else 1)) * _pace()


## The pace the voice has kept (seconds a word, its pauses with them): over its last [constant PACE_WORDS] words heard, never
## quicker than [constant DeskScript.EST_WORD]; [constant DeskScript.SAID_WORD] before [constant PACE_FIRST] are heard.
func _pace() -> float:
	var known := _follower.known_last()
	if known < PACE_FIRST:
		return DeskScript.SAID_WORD
	var back := maxi(known - PACE_WORDS, 0)
	var t0 := _word_t0(back)
	var t1 := _word_t1(known)
	if t0 == INF or t1 == INF:
		return DeskScript.SAID_WORD
	return clampf((t1 - t0) / float(known - back + 1), DeskScript.EST_WORD, 1.5)


## What the page has shown, taken as the plan is about to be made again at [member _now]: for each action begun, its start
## and when it began to be held; its end once done, else how much of it is written; and a page turn begun. [method
## _build_plan] keeps them, and [method _ink_time] goes on from them.
func _hold_past() -> void:
	var held := {}
	for i in _actions.size():
		var p: Dictionary = _plan[i]
		var h := {}
		if float(p["turn_at"]) <= _now:
			h["turn_at"] = float(p["turn_at"])
		if float(p["start"]) <= _now:
			h["start"] = float(p["start"])
			h["at"] = _now
			if float(p["end"]) <= _now:
				h["end"] = float(p["end"])
			else:
				h["u"] = _written(i)
		if not h.is_empty():
			held[i] = h
	_held = held


## When spoken word [param si] began and ended: INF while the voice has not reached it. A word it went past without
## matching has the time it was most likely said ([member ReadingFollower.said0]), so a word that waited for one does not
## hold every action after it.
func _word_t0(si: int) -> float:
	if si < 0 or si >= _follower.said0.size() or _follower.said0[si] == ReadingFollower.NO_TIME:
		return INF
	return _follower.said0[si]


func _word_t1(si: int) -> float:
	if si < 0 or si >= _follower.said1.size() or _follower.said1[si] == ReadingFollower.NO_TIME:
		return INF
	return _follower.said1[si]


## How far through its writing action [param i] is at [member _now], as the ink's own clock (seconds of [method
## Ink.schedule]): a dictated item's by [method elastic], over its dictation's words; one written in silence at an even
## pace, across the rest the voice gives it. One under way when the plan was made again ([member _held]) goes on from what
## was written then, so the ink never goes back or jumps: ahead of the new plan, the rest of it spread over what the plan has
## left of it; behind it, catching up over [constant CATCH_UP] or what its quickest pace takes, whichever is longer.
func _ink_time(i: int) -> float:
	# asked of the line being written four or five times a frame (the page, its wet ink, the pen now and a moment before),
	# and each works the dictation out word by word
	if _ink_t_rev != _plan_rev or _ink_t.size() > 8:
		_ink_t = {}
		_ink_t_rev = _plan_rev
	# by the moment exactly (a float key is the whole double), then the action
	var at_now: Dictionary = _ink_t.get_or_add(_now, {})
	if at_now.has(i):
		return at_now[i]
	var got := _ink_time_now(i)
	at_now[i] = got
	return got


func _ink_time_now(i: int) -> float:
	var u := _share(i, _now)
	var h: Dictionary = _held.get(i, {})
	if h.has("u"):
		var at := float(h["at"])
		var u0 := float(h["u"])
		var from := _share(i, at)
		if u0 < from - 0.001:
			# ...behind where the plan made again has it (words came that it was waiting for): it catches up, eased, at most at
			# its quickest, and keeps with the plan from there
			var catch := maxf((from - u0) * _length(i) / DeskScript.MAX_PACE, CATCH_UP)
			return _length(i) * lerpf(u0, maxf(u, from), _ease(clampf((_now - at) / catch, 0.0, 1.0)))
		var rest := (u - from) / (1.0 - from) if from < 0.98 \
			else (_now - at) / maxf(float(_plan[i]["end"]) - at, 0.01)
		u = u0 + (1.0 - u0) * clampf(rest, 0.0, 1.0)
	return _length(i) * u


## How far through its writing action [param i] is at [param t] by the plan alone, 0 to 1.
func _share(i: int, t: float) -> float:
	var a: Dictionary = _actions[i]
	var start := float(_plan[i]["start"])
	var end := float(_plan[i]["end"])
	var span := int(a.get("span", 0))
	if span <= 0:
		return clampf((t - start) / maxf(end - start, 0.01), 0.0, 1.0)
	var lead := _lead_of(i)
	var times := _dictation(int(a["after"]), span, start + lead)
	if lead > 0.0:
		# ...the pen keeping time with the words that much early
		var t0s: PackedFloat32Array = times[0]
		var t1s: PackedFloat32Array = times[1]
		for j in t0s.size():
			t0s[j] -= lead
			t1s[j] -= lead
		times = [t0s, t1s]
	return elastic(t, start, end, times[0], times[1])


## The times of the [param span] words from [param after]: [t0s, t1s], a word not heard yet placed after the last that was
## and never sooner than now - the voice has not said it - a word of the voice's own pace apart ([method _pace]).
func _dictation(after: int, span: int, start: float) -> Array:
	var t0s := PackedFloat32Array()
	var t1s := PackedFloat32Array()
	var last := start + PEN_LEAD
	var pace := -1.0
	for j in span:
		var t0 := _word_t0(after + j)
		var t1 := _word_t1(after + j)
		if t0 == INF or t1 == INF:
			if pace < 0.0:
				pace = _pace()
			t0 = maxf(last, _now) + 0.05
			t1 = t0 + pace * 0.9
		t0s.append(t0)
		t1s.append(t1)
		last = t1
	return [t0s, t1s]


## The pen's clock, elastic: how far through its writing (0 to 1) the pen is at [param now], for writing planned from
## [param start] to [param end] across words said at [param t0s] to [param t1s]. A pure function, so a seek lands where the
## pen would be.
##
## The voice's progress through the words is smoothed over [constant ELASTIC_WINDOW], so a pause in it is a slope and not a
## step, and its time is stretched onto the pen's. [constant ELASTIC_FLOOR] of the pen's progress runs steady from its
## start to its end, so the pen never stands still while it writes: over a long pause it slows to about that share of its
## average pace and makes it up over the words after. The result is set to run from 0 at [param start] to 1 at [param end]
## exactly.
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
	# asked several times a frame (the pages, the camera's arc and framing): the same moment, the same plan
	if _now == _pages_now and _plan_rev == _pages_rev:
		return _pages_got
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
	_pages_now = _now
	_pages_rev = _plan_rev
	_pages_got = Vector2i(page, turning)
	return _pages_got


func _show_pages() -> void:
	var p := _pages()
	var now := page_state(p.x)
	var dry := _canvas.show_page(p.x, now["dry"])
	var wet := _wet.show_page(p.x, now["wet"])
	if dry:
		_vp_dry.render_target_update_mode = SubViewport.UPDATE_ONCE
	if dry or wet:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if p.y < 0:
		_pad.show_turned(p.x, -1.0)
		return
	if _canvas_turn.show_page(p.y, page_state(p.y)["all"]):
		_vp_turn.render_target_update_mode = SubViewport.UPDATE_ONCE
	var ta := INF
	for i in _page_actions(p.x):
		if float(_plan[i]["turn_at"]) < INF:
			ta = float(_plan[i]["turn_at"])
			break
	_pad.show_turned(p.y, clampf((_now - ta) / DeskScript.TURN, 0.0, 1.0))


## The ink on page [param page] now, in the page's pixels: [{points, width}] - what [PadCanvas] draws; all of it, or the
## [param part] finished (`dry`) or still being written (`wet`).
func page_ink(page: int, part := "all") -> Array:
	var out: Array = []
	for i in _on_page(page):
		var done := _written(i) >= 1.0
		if part != "all" and done != (part == "dry"):
			continue
		out.append_array(_done_ink_of(i) if done else _ink_of(i))
	return out


## A finished action's ink, made once: all of it, at any moment after its end ([method _ink_of]).
func _done_ink_of(i: int) -> Array:
	if not _done_ink.has(i):
		_done_ink[i] = _ink_of(i)
	return _done_ink[i]


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
	for i in _page_actions(page):
		var a: Dictionary = _actions[i]
		if float(_plan[i]["start"]) > _now or int(a["page"]) != page or String(a["kind"]) == "point":
			continue
		if String(a["kind"]) == "strike":
			var of := int(a.get("of", -1))
			if of < 0 or int((_actions[of] as Dictionary)["page"]) != page:
				continue
		out.append(i)
	return out


## The actions laid on page [param page], in order - made once a lesson or a letter is laid out, since the pages, the pen
## and the camera ask every frame.
func _page_actions(page: int) -> Array:
	_index()
	return _by_page.get(page, [])


## The actions of [param kind] (a tap, a point...), in order ([method _page_actions]'s index).
func _of_kind(kind: String) -> Array:
	_index()
	return _by_kind.get(kind, [])


## The actions a page is turned for, in order ([method _page_actions]'s index).
func _turn_actions() -> Array:
	_index()
	return _turning


func _index() -> void:
	if is_same(_by_page_of, _actions):
		return
	_by_page = {}
	_turning = []
	_by_kind = {}
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		(_by_page.get_or_add(int(a["page"]), []) as Array).append(i)
		(_by_kind.get_or_add(String(a["kind"]), []) as Array).append(i)
		if bool(a.get("turn", false)):
			_turning.append(i)
	_by_page_of = _actions


## How long action [param i] takes the pen: its ink's, else what the script gave it.
func _length(i: int) -> float:
	var a: Dictionary = _actions[i]
	return float((_strokes.get(String(a["id"]), {}) as Dictionary).get("length", a.get("write", 0.0)))


## How much of action [param i] is written at [member _now], 0 to 1.
func _written(i: int) -> float:
	var a: Dictionary = _actions[i]
	if String(a["kind"]) == "strike":
		return clampf((_now - float(_plan[i]["start"])) / maxf(float(a["write"]), 0.01), 0.0, 1.0)
	# done is done: past its end its share is 1 whatever the dictation ([method _share], held or not); this is asked of
	# every action on the page every frame, where the dictation is worked out word by word
	if _now >= float(_plan[i]["end"]):
		return 1.0
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
			var k := float(a["k"]) * DeskScript.PX_PER_PT
			# onto the page in one native step, never point by point: a line of handwriting is thousands of them, and the
			# line being written is drawn again every frame
			var to_page := Transform2D(0.0, Vector2(k, k), 0.0, a["at"] as Vector2)
			for s in Ink.at(sched, _ink_time(i))["ink"]:
				var pts: PackedVector2Array = to_page * PackedVector2Array((s as Dictionary)["points"])
				var faint := bool((s as Dictionary).get("faint", false))
				out.append({"points": pts, "width": maxf(FAINT_W if faint else 2.4, float((s as Dictionary)["width"]) * k * 1.35),
					"faint": faint})
		"strike":
			var walked := _along(_struck_path(a), _written(i))
			for j in range(0, walked.size() - 1, 2):
				out.append({"points": PackedVector2Array([walked[j], walked[j + 1]]), "width": 3.2})
	# in its pen's ink: a letter's action names the ink it is written in ([constant LetterScript.COLOR]); none, the desk's
	var named := String(a.get("ink", ""))
	if not named.is_empty():
		var col := NotebookLayout.ink_color(named)
		for d in out:
			(d as Dictionary)["color"] = col
	return out


## The stroke a cross-out draws through a written action: across its middle, a little rising - the whole of it, or
## from [param from] to [param to] px along it alone (a letter's words struck inside a line, LetterScript.STRUCK),
## running past them a little less.
static func _strike_line(a: Dictionary, from := 0.0, to := -1.0) -> Array:
	var at: Vector2 = a.get("at", Vector2.ZERO)
	var w := float(a.get("w", 100.0))
	var h := float(a.get("h", 30.0))
	if to < 0.0:
		return [at + Vector2(-14.0, -h * 0.32), at + Vector2(w + 14.0, -h * 0.45)]
	return [at + Vector2(from - 5.0, -h * 0.34), at + Vector2(to + 5.0, -h * 0.40)]


## The stroke strike [param s] draws through what it strikes (its `of`): across its words alone where it names
## them (`x0`, `x1`).
func _struck_line(s: Dictionary) -> Array:
	var a: Dictionary = _actions[int(s["of"])]
	return _strike_line(a, float(s.get("x0", 0.0)), float(s.get("x1", -1.0)))


## Where a line of type is crossed out, per row of words ([param gap] TeX points apart at least): each row's baseline in the
## record's points and the x it spans, `[[y, x0, x1]]` top down - a sub- or superscript is its row's, never a row.
static func _rows_of(record: Dictionary, gap := 9.0) -> Array:
	var ink: Array = []
	for g in record.get("glyphs", []):
		ink.append([float((g as Dictionary)["y"]), float(g["x"]), float(g["x"]) + float(g["w"])])
	for r in record.get("rules", []):
		ink.append([float((r as Dictionary)["y"]), float(r["x"]), float(r["x"]) + float(r["w"])])
	ink.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var rows: Array = []
	var seen := {}                  # a row's rounded baseline -> how many glyphs sit on it
	var last := -INF
	for q in ink:
		var y := float(q[0])
		if rows.is_empty() or y - last > gap:
			rows.append([y, float(q[1]), float(q[2])])
			seen = {}
		var row: Array = rows.back()
		row[1] = minf(float(row[1]), float(q[1]))
		row[2] = maxf(float(row[2]), float(q[2]))
		var key := roundf(y * 2.0)
		seen[key] = int(seen.get(key, 0)) + 1
		if int(seen[key]) >= int(seen.get(roundf(float(row[0]) * 2.0), 0)):
			row[0] = y
		last = y
	return rows


## The way the pen crosses out what strike [param s] strikes, as a polyline of strokes taken in pairs of points: one stroke
## through a line of words, and through a block of several rows (TeX wrapped it) one stroke across each, left to right, the
## pen lifted between them. The segment from one row's end to the next row's start is that travel, never ink ([method _ink_of]).
func _struck_path(s: Dictionary) -> PackedVector2Array:
	var line := _struck_line(s)
	var a: Dictionary = _actions[int(s["of"])]
	var rows: Array = _rows_of(_records.get(String(a.get("id", "")), {})) if not s.has("x1") else []
	if rows.size() < 2:
		return PackedVector2Array([line[0], line[1]])
	var out := PackedVector2Array()
	var at: Vector2 = a["at"]
	var scale := float(a["k"]) * DeskScript.PX_PER_PT
	var h := float(a.get("h", 30.0))
	for r in rows.size():
		var row: Array = rows[r]
		var y := at.y + float(row[0]) * scale
		var left := Vector2(at.x + float(row[1]) * scale - 14.0, y - h * 0.32)
		var right := Vector2(at.x + float(row[2]) * scale + 14.0, y - h * 0.45)
		out.append(left)
		out.append(right)
	return out


## The first part of polyline [param path], [param u] (0 to 1) of its length.
static func _along(path: PackedVector2Array, u: float) -> PackedVector2Array:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	var want := total * clampf(u, 0.0, 1.0)
	var out := PackedVector2Array([path[0]])
	for i in range(1, path.size()):
		var seg := path[i - 1].distance_to(path[i])
		if want >= seg:
			out.append(path[i])
			want -= seg
			continue
		out.append(path[i - 1].lerp(path[i], want / seg if seg > 0.0 else 0.0))
		break
	return out


# --- the pen ---------------------------------------------------------------------------------

## Where the nib is now, on the page (px), and how high above it (m): writing, it is the ink's nib;
## between strokes it lifts and travels; between actions it waits ([method _waiting]) and reaches the
## next as it begins ([method _reach]); before the first, it waits where [method _before_first] says.
func pen_at() -> Dictionary:
	var rest := _before_first()
	var last := -1                  # the last action the pen did
	# from where the last walk found all done: a done action stays done as the time goes on, and which points aim at
	# nothing is the layout's
	if _pen_rev != _plan_rev:
		_pen_rev = _plan_rev
		_pen_k = 0
		_pen_last = -1
		_pen_upto = -INF
	var from := 0
	if _now >= _pen_upto:
		from = _pen_k
		last = _pen_last
	for i in range(from, _actions.size()):
		var a: Dictionary = _actions[i]
		if String(a["kind"]) == "point" and target_box(a).size.x < 0.0:
			if i == _pen_k:
				_pen_k += 1
			continue        # at nothing on this page: the pen stays where it is
		var start := float(_plan[i]["start"])
		if start == INF:
			return _waiting(last, i) if last >= 0 else rest
		if _now < start:
			var wait := _waiting(last, i) if last >= 0 else rest
			var u := _ease(clampf(1.0 - (start - _now) / _reach(last, i), 0.0, 1.0))
			return {"p": (wait["p"] as Vector2).lerp(_action_point(a, true), u),
				"lift": lerpf(float(wait["lift"]), _down(a), u), "still": float(wait.get("still", 0.0)) * (1.0 - u)}
		if _now < float(_plan[i]["end"]):
			return _pen_during(a, i, start)
		last = i
		if i == _pen_k:
			_pen_k += 1
			_pen_last = i
			_pen_upto = maxf(_pen_upto, float(_plan[i]["end"]))
	return _waiting(last, -1) if last >= 0 else rest


## Where the nib waits at [member _now], after action [param last] and before action [param next] (-1:
## none comes): it settles beside the end of what it did, a little lifted; and where [method _parks]
## says - a page is to turn - it drifts on from there to [constant PARK], before a turn at once, as the
## sheet will lift. One continuous way from where the action left the nib. `still`: how settled the hand
## is ([method _settled]), the nib lowered that much.
func _waiting(last: int, next: int) -> Dictionary:
	var a: Dictionary = _actions[last]
	var end := float(_plan[last]["end"])
	var from := _action_point(a, false)
	var s := _ease(clampf((_now - end) / REST_EASE, 0.0, 1.0))
	var p := from.lerp(_rest_near(from), s)
	var lift := lerpf(_down(a), Pen.REST_LIFT, s)
	if _parks(last, next):
		var turning := next >= 0 and bool((_actions[next] as Dictionary).get("turn", false))
		var v := (_now - end - (0.0 if turning else PARK_AFTER)) / PARK_EASE
		# right first, off the written lines (and out from under a sheet about to turn), then up the
		# pad's edge
		var cleared := PARK_CLEAR / PARK_EASE
		p = Vector2(lerpf(p.x, PARK.x, _ease(clampf(v / cleared, 0.0, 1.0))),
			lerpf(p.y, PARK.y, _ease(clampf((v - cleared * 0.75) / (1.0 - cleared * 0.75), 0.0, 1.0))))
	var still := _settled(last, next)
	return {"p": p, "lift": lerpf(lift, Pen.SETTLED_LIFT, still), "still": still}


## How settled the hand is at [member _now] in the wait after action [param last] (0 to 1): where the pen waits [constant
## SETTLE_WAIT] or longer before it sets off for action [param next] (-1: none comes), from [constant SETTLE_AFTER] after the
## last ends, over [constant SETTLE_EASE], and up again over [constant SETTLE_RISE] before it sets off.
func _settled(last: int, next: int) -> float:
	var end := float(_plan[last]["end"])
	var go := INF
	if next >= 0 and float(_plan[next]["start"]) < INF:
		go = float(_plan[next]["start"]) - _reach(last, next)
	if go - end < SETTLE_WAIT:
		return 0.0
	return _ease(clampf((_now - end - SETTLE_AFTER) / SETTLE_EASE, 0.0, 1.0)) * _ease(clampf((go - _now) / SETTLE_RISE, 0.0, 1.0))


## When action [param i] ends now that a page turned for it has moved its start to [param start] ([method _build_plan]):
## [param end], moved with it. A medium whose pen keeps to the voice rather than its start answers for itself ([EpisodeDesk]).
func _replanned_end(_i: int, _start: float, end: float) -> float:
	return end


## How much sooner than its words written action [param i] may begin, the pen free ([method _build_plan]): none here - a
## medium whose pen has room to keep an even pace answers for itself ([EpisodeDesk]).
func _early(_i: int) -> float:
	return 0.0


## The soonest the pen's first action begins ([method _build_plan]): whenever its words come, here. A medium that shows its
## desk first answers for itself ([EpisodeDesk]).
func _first_floor() -> float:
	return -INF





## Does the pen get out of the way between action [param _last] and action [param next] (-1: the lesson's
## end)? Only for a page [param next] turns: a hand waiting, however long, rests where it stopped, the way
## back to the page shortest from there. Read off the script, never the voice's times, so it never changes
## its mind as a voice's words arrive. A medium with more reasons answers for itself ([LetterMedium]).
func _parks(_last: int, next: int) -> bool:
	return next >= 0 and bool((_actions[next] as Dictionary).get("turn", false))


## How long the nib takes to reach action [param next] after action [param last] (-1: none came): its way from where it
## waits at [constant REACH_SPEED], never quicker than [constant REACH_EASE], and never longer than the wait, so it sets
## off from where the last action left it (over a page being turned, once [constant PARK_BACK] of the turn is over).
func _reach(last: int, next: int) -> float:
	var to := _action_point(_actions[next], true)
	if last < 0:
		return _travel((_before_first()["p"] as Vector2).distance_to(to))
	var from := PARK if _parks(last, next) else _rest_near(_action_point(_actions[last], false))
	var free := float(_plan[last]["end"])
	if float(_plan[next]["turn_at"]) < INF:
		free = maxf(free, float(_plan[next]["turn_at"]) + DeskScript.TURN * PARK_BACK)
	return minf(_travel(from.distance_to(to)), maxf(float(_plan[next]["start"]) - free, 0.01))


## How high the nib is as action [param a] begins and ends: on the paper for writing, just over it for
## a point.
static func _down(a: Dictionary) -> float:
	return Pen.POINT_LIFT if String(a["kind"]) == "point" else 0.0


func _pen_during(a: Dictionary, i: int, start: float) -> Dictionary:
	match String(a["kind"]):
		"pad", "pad-text", "draw":
			var sched: Dictionary = _strokes.get(String(a["id"]), {})
			var nib := Pen.on_strokes(sched.get("strokes", []), _ink_time(i))
			return {"p": (a["at"] as Vector2) + (nib["at"] as Vector2) * float(a["k"]) * DeskScript.PX_PER_PT,
				"lift": float(nib["lift"])}
		"strike":
			var of := int(a.get("of", -1))
			if of >= 0:
				var u := clampf((_now - start) / maxf(float(a["write"]), 0.01), 0.0, 1.0)
				var walked := _along(_struck_path(a), u)
				# (an odd count: the pen is on its way from one row's end to the next row's start)
				return {"p": walked[walked.size() - 1], "lift": Pen.REST_LIFT * 0.5 if walked.size() % 2 == 1 else 0.0}
		"point":
			return {"p": Pen.pointing(point_path(a), _now - start, float(_plan[i]["end"]) - start), "lift": Pen.POINT_LIFT}
	return {"p": Vector2(PW * 0.84, DeskScript.FIRST_RULE + DeskScript.RULE * 2.0), "lift": Pen.REST_LIFT}


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
				var path := _struck_path(a)
				return path[0] if first else path[path.size() - 1]
		"point":
			return point_path(a)[0 if first else 2]
	return Vector2(PW * 0.84, DeskScript.FIRST_RULE + DeskScript.RULE * 2.0)


## What a point points at, on the page (px): the box of the thing it names - a part's, from its ink
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


## The nib's way while point [param a] lasts, on the page (px): [method Pen.point_path] of what it points at - beside the
## end, the pen's body leans away over clean paper, never onto a line below (an aligned block's next line is closer than a
## rule).
func point_path(a: Dictionary) -> Array:
	return Pen.point_path(target_box(a), DeskScript.PX_PER_PT)


## Where the pen rests after writing at [param p] ([method Pen.rest_near]), kept over the page.
static func _rest_near(p: Vector2) -> Vector2:
	var r := Pen.rest_near(p, DeskScript.PX_PER_PT)
	return Vector2(clampf(r.x, DeskScript.MATH_X, PW - 70.0), clampf(r.y, DeskScript.FIRST_RULE, PH - 80.0))


static func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## A point of the page (px) in the world, [param lift] meters above it.
func _world(p: Vector2, lift: float) -> Vector3:
	var local := Vector3((p.x / PW - 0.5) * PAD_W, 0.0003 + lift, (p.y / PH - 0.5) * PAD_H)
	return _pad.transform * local


# --- the pen at rest -----------------------------------------------------------------------------
# The pen lies beside the pad's right edge ([method DeskLook.pen_rest]) until it is needed, is picked up as its first
# stroke comes ([method _pick_up_pose]), and is set down a beat after its last action ([method _set_down_pose]).

## Before the first thing is done the nib waits over its first stroke, where the pen is carried to from the desk ([method
## _pick_up_pose]); with nothing to do at all, beside the page's head.
func _before_first() -> Dictionary:
	var i := _first_done()
	if i < 0:
		return {"p": Vector2(PW * 0.84, DeskScript.FIRST_RULE + DeskScript.RULE * 2.0), "lift": Pen.REST_LIFT}
	return {"p": _action_point(_actions[i], true), "lift": Pen.REST_LIFT}


## The first action the pen does - a point at nothing on its page it leaves be, as [method pen_at] does; -1 for none.
func _first_done() -> int:
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if not (String(a["kind"]) == "point" and target_box(a).size.x < 0.0):
			return i
	return -1


## When the pen is picked up: `(from, to)`, seconds - [constant PICK_UP] long, over as the nib sets off to its first stroke
## ([method _reach]). A first action not placed yet is when [method _first_guess] says; INF while neither is known, and for
## a desk whose pen does nothing: it lies where it is.
func _pick_up() -> Vector2:
	var i := _first_done()
	if i < 0 or i >= _plan.size():
		return Vector2(INF, INF)
	var start := float(_plan[i]["start"])
	if start == INF:
		start = _first_guess()
		if start == INF:
			return Vector2(INF, INF)
	var to := start - _reach(-1, i)
	return Vector2(to - PICK_UP, to)


## The pen picked up from where it lies ([method DeskLook.pen_rest]): `{xf, f}` as [method _tap_pose] gives it, the pose
## whole - lying on its widest until [method _pick_up] begins; then held by its grip ([constant PICK_GRIP] up from the
## nib), raised and turned up into the hand over the first [constant PICK_TURN] of the way, carried over the pad from
## [constant PICK_CARRY] of it in an arc [constant PICK_ARC] high, and brought down to the desk's own pose [param base],
## which it is as the pick-up ends; {} from then on.
func _pick_up_pose(base: Transform3D) -> Dictionary:
	var w := _pick_up()
	if w.y < INF and _now >= w.y:
		return {}
	var u := clampf((_now - w.x) / PICK_UP, 0.0, 1.0) if w.x < INF else 0.0
	return {"xf": _lift(base, _first_pen, u), "f": 1.0}


## The last action the pen does - a point at nothing on its page it leaves be, as [method _first_done]; -1 for none.
func _last_done() -> int:
	for i in range(_actions.size() - 1, -1, -1):
		var a: Dictionary = _actions[i]
		if not (String(a["kind"]) == "point" and target_box(a).size.x < 0.0):
			return i
	return -1


## When the pen is set down: `(from, to)`, seconds - [constant SET_DOWN_AFTER] after its last action ends (and anything
## that keeps it in hand past that, [method _released_by]), and [constant PICK_UP] long. INF while that action is not placed
## yet, and for a desk whose pen does nothing: it never left the desk.
func _set_down() -> Vector2:
	var i := _last_done()
	if i < 0 or i >= _plan.size():
		return Vector2(INF, INF)
	var end := float(_plan[i]["end"])
	if end == INF:
		return Vector2(INF, INF)
	end = _released_by(end)
	if end == INF:
		return Vector2(INF, INF)
	return Vector2(end + SET_DOWN_AFTER, end + SET_DOWN_AFTER + PICK_UP)


## The pen set down where it lies ([method DeskLook.pen_rest]) once its writing is done: `{xf, f}` as [method
## _pick_up_pose] gives it, the pick-up's way back ([method _lift]) from the desk's own pose [param base] (the pen in
## hand, at its own place), lying there from then on; {} before [method _set_down] begins.
func _set_down_pose(base: Transform3D) -> Dictionary:
	var w := _set_down()
	if w.x == INF or _now <= w.x:
		return {}
	return {"xf": _lift(base, _pen_in_hand(), 1.0 - clampf((_now - w.x) / PICK_UP, 0.0, 1.0)), "f": 1.0}


## Pen [param k] on its way between its place and the hand: lying where it is at [param u] 0; held by its grip ([constant
## PICK_GRIP] up from the nib), raised and turned up into the hand over the first [constant PICK_TURN] of the way, carried
## over the pad from [constant PICK_CARRY] of it in an arc [constant PICK_ARC] high, and brought down to the desk's own
## pose [param base], which it is at 1. A pen put down goes the same way back.
func _lift(base: Transform3D, k: int, u: float) -> Transform3D:
	var lying := _lying(k)
	if u <= 0.0:
		return lying
	var turned := Basis(lying.basis.get_rotation_quaternion().slerp(base.basis.get_rotation_quaternion(),
		_ease(clampf((u - 0.05) / PICK_TURN, 0.0, 1.0))))
	var grip := (lying.origin + lying.basis.y * PICK_GRIP).lerp(base.origin + base.basis.y * PICK_GRIP,
		_ease(clampf((u - PICK_CARRY) / (1.0 - PICK_CARRY), 0.0, 1.0)))
	grip.y += PICK_ARC * _ease(clampf(u / 0.4, 0.0, 1.0)) * (1.0 - _ease(clampf((u - 0.55) / 0.45, 0.0, 1.0)))
	return Transform3D(turned, grip - turned.y * PICK_GRIP)


## Pen [param k] lying at its place ([method DeskLook.pen_rest]), on its widest.
func _lying(k: int) -> Transform3D:
	var rest := DeskLook.pen_rest(look, LegalPad.DESK_Y, k)
	var lie := Vector3.UP * PEN_R * 1.04
	var nib: Vector3 = _pad.transform * ((rest["nib"] as Vector3) + lie)
	return Pen.frame(nib, _pad.transform * ((rest["top"] as Vector3) + lie) - nib)


## From [param a] to [param b] by [param f], turned about the pen's middle where the fingers hold it, and
## lifted clear of the page on the way.
static func _blend(a: Transform3D, b: Transform3D, f: float) -> Transform3D:
	if f <= 0.0:
		return a
	if f >= 1.0:
		return b
	var qa := a.basis.get_rotation_quaternion()
	var qb := b.basis.get_rotation_quaternion()
	var basis := Basis(qa.slerp(qb, f))
	var mid := (a.origin + a.basis.y * PEN_TOP * 0.5).lerp(b.origin + b.basis.y * PEN_TOP * 0.5, f)
	mid += Vector3.UP * sin(PI * f) * 0.05
	return Transform3D(basis, mid - basis.y * PEN_TOP * 0.5)


## When a first stroke not placed yet is due: INF here (the pen lies until the first action is placed); a letter guesses it.
func _first_guess() -> float:
	return INF


## How long the pen stays in hand past its last action's [param end]: no longer here; a letter's point at the camera holds it.
func _released_by(end: float) -> float:
	return end


## Which pen is in hand: the first. A letter changes pens ([method LetterMedium._pen_in_hand]).
func _pen_in_hand() -> int:
	return _first_pen


func _place_pen() -> void:
	_pen.global_transform = _pen_xf()


## The pen's transform at [member _now]: its nib where [method pen_at] says, its body leaning as the hand does ([method
## Pen.lean]) and drifting off the paper ([method Pen.drift]). A medium that lays poses of its own over it answers for itself.
func _pen_xf() -> Transform3D:
	var base := _held_xf()
	var pose := _pick_up_pose(base)
	if pose.is_empty():
		pose = _set_down_pose(base)
	return base if pose.is_empty() else _blend(base, pose["xf"], float(pose["f"]))


## The pen in the hand at [member _now]: its nib where [method pen_at] says, its body leaning as the hand does.
func _held_xf() -> Transform3D:
	var at := pen_at()
	var p: Vector2 = at["p"]
	var lift := float(at["lift"])
	var still := float(at.get("still", 0.0))
	var keep := _now
	_now = keep - Pen.MOTION_DT
	var before: Vector2 = pen_at()["p"]
	_now = keep
	var moved := (p - before) / Pen.MOTION_DT
	var up := Pen.lean(Pen.UP, _now, _seed, p.x / PW, Vector3(moved.x / PW * PAD_W, 0.0, moved.y / PH * PAD_H), still)
	var nib := _world(p, lift) + Pen.drift(_now, _seed, lift, still)
	if still > 0.0:
		# ...a settled hand readjusting its hold now and then: the top turned, the nib barely moved
		var hold := Pen.readjust(_now, _seed)
		up = Pen.turned(up, float(hold["yaw"]) * still, float(hold["tilt"]) * still)
		nib += (hold["nib"] as Vector3) * still
	return Pen.frame(nib, up)


# --- the camera -------------------------------------------------------------------------------

## The framing's target at [member _now]: how close (0 wide, 1 local) and where on the page. Wide until
## the lesson opens, as a page turns and once the last word is said; local on the line being written -
## looked for [constant CAM_LEAD] ahead, the springs being late.
func _framing() -> Dictionary:
	var k := 0.0
	var turn := false
	var line := Vector2(PW * 0.5, PH * 0.5)
	var opening := _opening()
	# close once the lesson has opened and the pen is picked up for its first stroke (the springs given their lead); wide
	# through talk before it
	if opening < INF and _now > opening - 1.0 and _now > _pick_up().x - CAM_LEAD:
		k = 1.0
	var ahead := _now + CAM_LEAD
	var page := _pages().x
	# the page's actions and the next's - an earlier page's frame nothing and turned long ago
	for i in _page_actions(page) + _page_actions(page + 1):
		var a: Dictionary = _actions[i]
		var start := float(_plan[i]["start"])
		var ta := float(_plan[i]["turn_at"])
		if ta < INF and _now > ta - TURN_BACK and _now < ta + DeskScript.TURN + 0.3:
			k = 0.0         # a turn, though what it turns for begins further ahead
			turn = true
		if start == INF or start > ahead:
			break
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
	if _ended():
		k = 0.0
	return {"k": k, "line": line, "turn": turn}


## Is the lesson over at [member _now] - its last word said?
func _ended() -> bool:
	var known := _follower.known_last()
	return _spoken_n > 0 and known >= _spoken_n - 1 and _now > _follower.st1[known]


func _tick_camera(delta: float) -> void:
	var f := _framing()
	var k := float(f["k"])
	var line: Vector2 = f["line"]
	# the whole pad, its binding too, with the desk round it - and as a page turns, its head, where
	# the page goes over and round
	var wide_aim := _world(Vector2(PW * 0.5, PH * (TURN_AIM if bool(f["turn"]) else 0.45)), 0.0)
	# local: the line being written, held a little below the frame's middle, never off the pad (as high as the framing's
	# `top` of it allows, 0.3 for none)
	var local_aim := _world(Vector2(clampf(line.x, PW * 0.35, PW * 0.65), clampf(line.y + 60.0, PH * float(f.get("top", 0.3)),
		PH * 0.72)), 0.0)
	var aim := wide_aim.lerp(local_aim, k)
	var page := _pages().x
	var wide: Dictionary = _wide_frame()
	var close: Dictionary = _local_frame()
	var w := _wander_time()
	var yaw := (_hash01(page, 41) - 0.5) * 2.0 * YAW_SPREAD + sin(w * 0.021 + float(_seed % 97)) * YAW_WANDER
	var pitch := lerpf(float(wide["pitch"]), float(close["pitch"]), k) \
		+ (_hash01(page, 67) - 0.5) * 2.0 * TILT_SPREAD + sin(w * 0.029 + 1.3) * 0.8
	var dist := lerpf(float(wide["dist"]), float(close["dist"]), k) * (1.0 + 0.012 * sin(w * 0.033 + 2.1))
	var roll := (_hash01(page, 53) - 0.5) * 2.0 * ROLL_SPREAD + sin(w * 0.047 + 0.7) * 0.5
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
	var tau := _spring_tau()
	var steps := maxi(1, int(ceil(delta / (1.0 / 60.0))))
	var h := delta / float(steps)
	for _i in steps:
		var res := BookMedium._spring3(_c_aim, _v_aim, aim, tau, h)
		_c_aim = res[0]
		_v_aim = res[1]
		var rd := BookMedium._spring(_c_dist, _v_dist, dist, tau, h)
		_c_dist = rd.x
		_v_dist = rd.y
		var rp := BookMedium._spring(_c_pitch, _v_pitch, pitch, tau, h)
		_c_pitch = rp.x
		_v_pitch = rp.y
		var ry := BookMedium._spring(_c_yaw, _v_yaw, yaw, tau * ANGLE_SLOW, h)
		_c_yaw = ry.x
		_v_yaw = ry.y
		var rr := BookMedium._spring(_c_roll, _v_roll, roll, tau * ANGLE_SLOW, h)
		_c_roll = rr.x
		_v_roll = rr.y
	var p := deg_to_rad(_c_pitch)
	var y := deg_to_rad(_c_yaw)
	var dir := Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p))
	_cam.position = _c_aim + dir * _c_dist
	_cam.look_at(_c_aim, Vector3.UP)
	_cam.rotate_object_local(Vector3.FORWARD, deg_to_rad(_c_roll))


## The camera's wide and close framings ([constant WIDE], [constant LOCAL]).
func _wide_frame() -> Dictionary:
	return WIDE


func _local_frame() -> Dictionary:
	return LOCAL


## The time the camera's slow wander is read at: now.
func _wander_time() -> float:
	return _now


## How slowly the camera's springs follow ([constant SPRING_TAU]).
func _spring_tau() -> float:
	return SPRING_TAU


## How long the page lies blank after the intro before anything is done on it (seconds): the settle the voice rests on at
## the desk ([constant Openings.SETTLE], [method DeskScript.parse]) - the desk seen sharp, its name gone, before the teacher speaks.
func _blank() -> float:
	return Openings.SETTLE


## When dictated action [param i] may begin, its first word said at [param t0] (INF while it is not): at the
## desk, as it is said - a little before, the pen's lead. INF holds the plan there until it is known.
## A medium whose pen writes ahead (a letter's, [LetterMedium]) answers for itself.
func _due(_i: int, t0: float) -> float:
	return t0 - PEN_LEAD if t0 < INF else INF


## How many words a written line keeps ahead of the voice saying it: none here - the pen writes each word as it is said. A
## medium whose pen leads answers for itself ([EpisodeDesk]).
func _ahead() -> int:
	return 0


## How far ahead of the voice written action [param i] keeps, seconds: what its own first [method _ahead] words take to say
## (estimated until they are heard, and at most twice the estimate), so a lead never reaches back across a pause before its
## line; none where the pen writes each word as it is said, and none for a line of a word.
func _lead_of(i: int) -> float:
	var a: Dictionary = _actions[i]
	var n := mini(_ahead(), int(a.get("span", 0)) - 1)
	if n <= 0:
		return 0.0
	var t0 := _word_t0(int(a.get("after", 0)))
	var tn := _word_t0(int(a.get("after", 0)) + n)
	if t0 == INF or tn == INF:
		return float(n) * DeskScript.EST_WORD
	return clampf(tn - t0, 0.0, float(n) * DeskScript.EST_WORD * 2.0)


## When action [param i], begun at [param start], ends: [param end], the desk's - a dictated one's the elastic
## pen's, keeping time with its words, and one done in silence its ink's at the hand's pace. A medium that paces
## its pen otherwise answers for itself ([LetterMedium]).
func _paced_end(_i: int, _start: float, end: float) -> float:
	return end


## The quickest action [param i] is ever done, against the hand's pace: one under way when the plan is made again ends no
## sooner than the rest of it takes at this ([method _build_plan]). A medium that dashes some off quicker answers for
## itself ([LetterMedium]'s sketches).
func _quickest(_i: int) -> float:
	return DeskScript.MAX_PACE


static func _hash01(page: int, salt: int) -> float:
	return float(absi(hash(["desk-cam", page, salt])) % 10007) / 10006.0
