extends Medium
class_name DispatchMedium

## DispatchMedium - one desk, late at night, in a hollow under the ground, seen from the chair (next/dispatch.md). The man
## who works it is never seen: the viewer sits where he sits, and everything on the desk moves on its own.
##
## It draws from the reading's document: its `source`, the note with its marks ([DispatchScript]); its `dispatch`, what
## the Dispatch desk's rows on the Medium card hand ([method DispatchFormat.document]): the desk's `seed` and each
## picture's file (`pictures`). The desk ([DispatchSet]) is built from the note's `desk:` block (the phones' labels) and
## the seed; the roots ([DispatchRoots]) from the seed.
##
## The desk acts in the rests the voice leaves for it ([method _place]): each action of the script before its spoken
## word, placed back from that word by what the script wrote after it in the same silence (or on from the word before
## when the next is not heard yet) and, once begun, kept where it began ([member _held]; a live reading's words arrive a
## sentence at a time). Everything on the desk is then a pure function of show time ([method _pose]), so a render draws
## what the live reading drew and a scrub lands where the reading is.
##
## The camera sits in the chair and turns to what is active ([method _attention], [constant SPOTS]): a phone ringing, the
## terminal while it types or shows something, the radar on a ping, the receiver while it plays static, a picture landing
## on a screen, the printer, the bell, the lamp switched (the whole desk, to see it go dark). `look:` turns it on purpose
## and it stays, as the gain knob holds it on the radar. It leans toward what it looks at and its lens closes in on the
## small things, on critically damped springs ([constant SPRING_TAU]); with nothing new for a while it eases back to the
## whole desk, with a slow breath of wander under it. Every look holds long enough to settle ([constant LOOK_LEAST]), a
## ping to the end of the sentence said over it ([constant PING_HOLD]), and it never leaves a thing only to come straight
## back ([constant AWAY_LEAST]).
##
## A phone in hand is held to the ear: it rises out of its row, flips open and floats up beside the camera, in the frame's
## lower right, its screen saying who is on it and for how long, and goes back the same way. A call is speed-dialed: the
## phone comes up before the eye, 1 is held and Send pressed, then it goes to the ear for the rings. One on hold lies open
## on the desk in front of the rows. A phone ringing buzzes and rattles in its row. A text chimes and the phone comes up
## open before the eye with the message on its screen, never captioned; a reply is typed into it as it is said, under the
## message, and sent; then it goes home.
##
## The subtitles caption what cannot be read on the desk, as the letter's do: speech, never the words typed on the
## terminal as they are said ([method _captioned]); a text is read on its phone and nowhere else.
##
## Redacted words on the terminal are hidden over the frame ([DispatchCensor], [method _censor_at]): drawn after the 3D
## and before a picture over the whole screen, so a picture covers it.

## The spots the camera turns to, and `look:` names ([method DispatchSet._spots] says where each is).
const SPOTS := {
	"home": {"label": "The desk", "blurb": "The whole desk, seen from the chair."},
	"terminal": {"label": "The terminal", "blurb": "Close on the terminal's screen, near enough to read it."},
	"keyboard": {"label": "The keyboard", "blurb": "Down at the keyboard."},
	"phones": {"label": "The phones", "blurb": "The two rows of phones, their names on the tape."},
	"radar": {"label": "The radar", "blurb": "The round green scope, its sweep and the blip."},
	"receiver": {"label": "The receiver", "blurb": "The shortwave receiver, its dial, needle and the scope on it."},
	"printer": {"label": "The printer", "blurb": "The printer at the desk's end and its paper falling to the heap."},
	"chart": {"label": "The chart", "blurb": "The chart of the council's hours, taped down."},
	"handbook": {"label": "The handbook", "blurb": "The fat binder labeled HANDBOOK."},
	"switch": {"label": "The switch", "blurb": "The switch box, GOOD above and BAD below."},
	"mug": {"label": "The mug", "blurb": "The mug in its ring of old coffee."},
	"feed": {"label": "The security monitor", "blurb": "The little black-and-white monitor."},
	"satellite": {"label": "The satellite's monitor", "blurb": "The flat monitor that looks down from orbit."},
	"tv": {"label": "The television", "blurb": "The small old television with its rabbit ears."},
}
## The camera's springs (seconds): how long it takes to settle on what it turns to (critically damped); and how long after
## the last thing it looked at it waits before easing back to the whole desk.
const SPRING_TAU := 0.95
const HOME_AFTER := 7.0
## Its wander (m at the aim, a slow breath) and how fast.
const WANDER := Vector3(0.010, 0.006, 0.006)
const WANDER_RATE := 0.11
## The radar: its sweep's round (seconds), how many of its paints of the target it keeps fading behind the newest,
## aircraft drifting across it (a pass's seconds, how often one starts).
const SWEEP := 2.5
const TRAIL := 6
const PLANE_PASS := 70.0
const PLANE_EVERY := 160.0
## The target's track ([method track_of]): how far he goes on the scope a second of a ping's seconds (its radius 1), a
## step's least and most, the step of a ping that says no seconds, how far a place's comma puts it off its head, how
## sharply the track turns (radians), how far out the whole track may reach; a bare ping's leg at most (seconds), and a
## paint's give-or-take.
const TRACK_PACE := 0.018
const WALK_WORD := 0.42
const STEP_LEAST := 0.05
const STEP_MOST := 0.4
const STEP_BARE := 0.13
const STEP_OFF := 0.04
const TURN_MOST := 0.7
const TRACK_EDGE := 0.82
const LEG_MOST := 14.0
## The radar's clutter ([method clutter_at]): the most blips the scope ever paints (at gain 10), how sharply their number
## grows with the knob, the building they stand in round him (on the scope, its edge 1), how near him the nearest may be,
## how far the few who move drift (one in [constant CLUTTER_MOVING]), and how long a blip the gain no longer reaches takes
## to fade (seconds). Each blip is painted by the sweep as the target is, dimmer and with no name, and a little off where
## it was each round.
const CLUTTER_MOST := 40
const CLUTTER_CURVE := 1.25
const CLUTTER_BUILDING := Vector2(0.40, 0.18)
const CLUTTER_NEAR := 0.022
const CLUTTER_MOVING := 4
const CLUTTER_DRIFT := 0.012
const CLUTTER_FADE := 4.0
const CLUTTER_JITTER := 0.004
## The chair's own blip: from this gain the scope paints whoever sits at this desk too, as faint as the clutter and
## with no name, just off the desk's mark at its middle on the chair's side; it fades with the clutter as the knob goes down.
const CHAIR_GAIN := 9
const CHAIR_AT := Vector2(0.0, 0.04)
## The lamp going out: the filament's glow dies over this long (seconds), and comes up over the first part of it.
const LAMP_FADE := 0.18
## The camera on the radar as the target sets off (seconds, at least): it stays while he walks, to the ping where he
## arrives, [constant MOVING_HOLD_MOST] at most, so a drive is a glance, never a stare.
const MOVING_LOOK := 3.0
const MOVING_HOLD_MOST := 12.0
## A ping holds the radar (seconds from its ring): at least this long, on to the end of the sentence being said then if it
## ends by the most; then it lingers this long and goes home. A still blip is not watched for long.
const PING_HOLD := 5.0
const PING_HOLD_MOST := 9.0
const PING_LINGER := 1.0
## What the camera turns to is seen (seconds; the springs take about three of them to settle): every look holds at least
## [constant LOOK_LEAST] from its start, unless something else begins first; and the camera never leaves a thing for less
## than [constant AWAY_LEAST] - a look back at it sooner than that joins the two, and it stays.
const LOOK_LEAST := 5.0
const AWAY_LEAST := 7.0
## A look cut by the next sooner than this (seconds) is not taken: the camera would only swerve toward it.
const GLANCE_LEAST := 2.5
## What the camera turns to to read (the terminal's words, a phone's message, a picture): always looked at.
const TO_READ := ["session", "type", "screen", "strike", "text", "reply", "picture", "live"]
const PAINT_JITTER := 0.006
## A phone at the ear, in the camera's frame (m): where it floats, and how it is turned (degrees: tipped, turned, rolled).
const EAR := Vector3(0.165, -0.105, -0.36)
const EAR_TURN := Vector3(58.0, -28.0, -18.0)
## A phone held up to be read or dialed, in the camera's frame (m): low in the middle of the picture, open, its screen to
## the eye and leaning back a little (degrees about its width: 90 holds it straight up at the eye).
const READ := Vector3(0.0, -0.118, -0.27)
const READ_LEAN := 74.0
## A phone ringing rattles this far (m) and turns this much (degrees).
const RATTLE := 0.0025
const RATTLE_TURN := 3.0
## The mug, drunk from: where its foot comes to in the camera's own frame (m: well under the eye and barely in front of it,
## the mouth, so the whole mug is out of the picture whichever way the camera looks); and how high it is lifted clear of
## the desk on its way.
const MUG_MOUTH := Vector3(0.03, -0.17, -0.01)
const MUG_CLEAR := 0.06
## The terminal's cursor blinks this often (seconds), and stays after typing this long.
const BLINK := 0.53
const CURSOR_AFTER := 4.0
## The live picture: its camera behind the chair, and its viewport's size.
const LIVE_EYE := Vector3(0.32, 1.48, 1.95)
const LIVE_AIM := Vector3(-0.05, 0.86, -0.15)
const LIVE_SIZE := Vector2i(480, 360)
## What the show is told it waits for while the desk is built ([method ShowFeed.wait_for]).
const WAIT_FOR := "the desk"
## A gate's: build on a worker as the app does, though a gate's frames otherwise wait for nothing.
static var away_in_tests := false
## A picture over the whole screen: its fade.
const IMAGE_FADE := DispatchScript.IMAGE_FADE
## The least lead an action has after the word before it (seconds).
const LEAD := 0.12
## The terminal's glass (`shaders/dispatch_screen.gdshader`): its bulge, scanlines and bloom; the censor follows its bulge.
const TERMINAL_GLASS := {"curve": 0.12, "lines": 0.32, "line_count": 300.0, "bloom": 0.7}
## The environment: the hollow's fog and its ambient light.
const FOG := Color(0.11, 0.12, 0.135)
const AMBIENT := Color(0.18, 0.2, 0.24)

var _subs = null
var _doc_key := ""
var _seed := 1
var _parsed := {}
## Which spoken words end a sentence ([method DispatchScript.sentence_ends]).
var _ends := PackedByteArray()
var _actions: Array = []
var _spans: Array = []
var _moves: Array = []
var _spoken_n := 0
var _typed_words := PackedByteArray()   # a spoken word -> 1 when it is typed on the terminal as it is said
var _follower := ReadingFollower.new()
var _built_n := -1
var _t0 := PackedFloat32Array()        # each action's start (INF until placed)
var _sp := PackedFloat32Array()        # ...and its speed (1, or quicker where its silence was short)
var _held := {}                         # an action begun -> [t0, speed]
var _chars := {}                        # a typed block's action -> each of its characters' moments
var _phone_moves: Array = []            # {label, from, to, t0, dur, slot, how}
var _attn: Array = []                   # {t0, t1, spot: Dictionary, sticky}
var _legs: Array = []                   # the target's track: {i, place, from, to, t0 (he leaves), t1 (he arrives)}
var _clutter: Array = []                # where the radar's clutter stands round him, nearest first ([method clutter_of])
var _leg_known := {}                    # a bare ping's action -> the show time a plan first placed it
var _sound_plan: Array = []
var _sound_rev := 0
var _now := 0.0
var _last_now := -1.0
var _snap := true
var _labels := PackedStringArray()
var _built_for := ""
var _pictures := {}                     # a picture's key -> its texture
var _build_task := -1                   # the set's build on a worker, -1 for none
var _pic_task := -1                     # ...the pictures' decoding
var _decoded := {}                      # ...what it decoded, waiting to be made textures
var _made := {}                         # ...what it made, waiting to be put in
var _waiting := false                   # the show held for it

var _placeholder: GhostScene
var _root3: Node3D
var _cam: Camera3D
var _attrs: CameraAttributesPractical
var _env: Environment
var _set: DispatchSet
var _set_node: Node3D
var _roots: DispatchRoots
var _roots_node: Node3D
var _screens: DispatchScreens
var _sounds: DispatchSounds
var _blur: IntroBlur
var _censor: DispatchCensor
var _after_censor: BackBufferCopy       # what reads the frame after the censor (the intro's blur) reads it censored
var _title: TitleCard
var _plate: LetterMedium.Plate
var _live_vp: SubViewport
var _live_cam: Camera3D
var _stage_was := {}
var _fill: DirectionalLight3D
var _mats := {}                         # a screen's or phone face's ShaderMaterial, by name

var _c_aim := Vector3.ZERO
var _v_aim := Vector3.ZERO
var _c_eye := Vector3.ZERO
var _v_eye := Vector3.ZERO
var _c_fov := 50.0
var _v_fov := 0.0


# --- mount -------------------------------------------------------------------------------------------------------------

func mount(st: SubViewport) -> void:
	super.mount(st)
	_stage_was = {}
	for key in TableMedium.STAGE:
		_stage_was[key] = st.get(key)
		st.set(key, TableMedium.STAGE[key])
	_placeholder = GhostScene.new()
	_placeholder.init_with_seed(1, "drift")
	_placeholder.visible = false
	add_child(_placeholder)
	_screens = DispatchScreens.new()
	add_child(_screens)
	_build_world()
	_censor = DispatchCensor.new()
	add_child(_censor)
	_plate = LetterMedium.Plate.new()
	_plate.material = ShaderMaterial.new()
	(_plate.material as ShaderMaterial).shader = LetterMedium._plate_shader()
	add_child(_plate)
	_after_censor = BackBufferCopy.new()
	_after_censor.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_after_censor.visible = false
	add_child(_after_censor)
	_blur = IntroBlur.new(ShowOpening.INTRO_SHADER)
	add_child(_blur)
	_title = TitleCard.new()
	_title.face = CardTable.font("typed")
	_title.italic = CardTable.font("typed")
	_title.ink = Color(0.62, 1.0, 0.68)
	add_child(_title)
	_sounds = DispatchSounds.new(self)


func _build_world() -> void:
	_root3 = Node3D.new()
	add_child(_root3)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.006, 0.007, 0.008)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = AMBIENT
	_env.ambient_light_energy = 0.22
	# the tonemapper, as the Look has it ([Tonemaps]): Filmic unless a note picks another, at the exposure tuned under Filmic
	Tonemaps.dress(_env, 1.1)
	_env.glow_enabled = true
	_env.glow_intensity = 0.55
	_env.glow_bloom = 0.04
	_env.glow_hdr_threshold = 1.0
	_env.fog_enabled = true
	_env.fog_light_color = FOG
	_env.fog_density = 0.2
	_env.fog_aerial_perspective = 0.0
	_env.fog_sky_affect = 0.0
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.035
	_env.volumetric_fog_albedo = Color(0.7, 0.72, 0.75)
	_env.volumetric_fog_length = 8.0
	_env.adjustment_enabled = true
	# bounce light, as the Graphics panel has it (off unless chosen: it changes the look)
	Graphics.dress(_env)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.near = 0.03
	_cam.far = 30.0
	_cam.environment = _env
	_attrs = CameraAttributesPractical.new()
	_attrs.dof_blur_far_enabled = false
	_cam.attributes = _attrs
	_root3.add_child(_cam)
	# a faint cold light from somewhere above, so the roots stand out of the dark
	_fill = DirectionalLight3D.new()
	_fill.light_color = Color(0.55, 0.62, 0.75)
	_fill.light_energy = 0.1
	_fill.rotation_degrees = Vector3(-62.0, 25.0, 0.0)
	_root3.add_child(_fill)
	# ...and down through a crack in the ceiling behind the desk: cold light falling through the fog onto the roots there
	var crack := SpotLight3D.new()
	crack.light_color = Color(0.62, 0.7, 0.82)
	crack.light_energy = 6.0
	crack.spot_range = 7.0
	crack.spot_angle = 26.0
	crack.spot_angle_attenuation = 0.8
	crack.shadow_enabled = true
	crack.light_volumetric_fog_energy = 2.5
	_root3.add_child(crack)
	crack.look_at_from_position(Vector3(0.5, 3.35, -1.6), Vector3(-0.1, 0.4, -1.1), Vector3.UP)


## The desk built for [param labels] and [param seed] (again only when either changed): the screens' labels here, then the
## set and its roots, on a worker while the show waits (a half second, most of it the roots), out of the tree, put in as
## they land ([method _land_set]). A render and a gate build where they stand: their frames wait for nothing ([method
## TablePhysics.render_waits]).
func _build_set(labels: PackedStringArray, seed: int) -> void:
	var key := "%s|%d" % [",".join(labels), seed]
	if key == _built_for:
		return
	_built_for = key
	if _build_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1
	_screens.build(labels)
	var tex := _screens.textures()
	if is_inside_tree() and (away_in_tests or not TablePhysics.render_waits()):
		_waiting = true
		feed.wait_for(WAIT_FOR, true)
		_build_task = WorkerThreadPool.add_task(_make_set.bind(labels, seed, tex), false, "the dispatch desk")
		return
	_make_set(labels, seed, tex)
	_land_set()


## The set and its roots, made out of the tree (a worker's, or the caller's).
func _make_set(labels: PackedStringArray, seed: int, tex: Dictionary) -> void:
	var s := DispatchSet.new()
	var node := s.build(labels, seed, tex)
	var r := DispatchRoots.new()
	var rn := r.build(seed, s.footprints, s.held_rect())
	_made = {"set": s, "node": node, "roots": r, "roots_node": rn}


## The set that was made, put in: the last one freed, the new one in the world, every glass's material, the live picture's
## camera; the plan's camera and sounds, which read the set, made again; the show let go on.
func _land_set() -> void:
	if _made.is_empty():
		return
	if _set_node != null:
		_set_node.queue_free()
	if _roots_node != null:
		_roots_node.queue_free()
	_set = _made["set"]
	_set_node = _made["node"]
	_roots = _made["roots"]
	_roots_node = _made["roots_node"]
	_made = {}
	_root3.add_child(_set_node)
	_root3.add_child(_roots_node)
	_mats = {}
	_set.terminal_screen.material_override = _screen_mat("terminal", _screens.terminal.get_texture(), DispatchScreens.PHOSPHOR.lerp(Color.WHITE, 0.2),
		TERMINAL_GLASS)
	_set.radar_screen.material_override = _screen_mat("radar", _screens.radar.get_texture(), Color(0.85, 1.0, 0.85),
		{"curve": 0.05, "lines": 0.12, "bloom": 0.9, "round_mask": 1.0, "brightness": 1.5})
	_set.scope_screen.material_override = _screen_mat("scope", _screens.scope.get_texture(), Color(0.9, 1.0, 0.9),
		{"curve": 0.08, "lines": 0.2, "bloom": 0.8})
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = _screens.paper.get_texture()
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	pm.roughness = 0.9
	_set.paper.material_override = pm
	for k in _set.screens:
		var sc: Dictionary = _set.screens[k]
		var opts: Dictionary = {"feed": {"curve": 0.1, "lines": 0.4, "mono": 1.0, "snow": 0.35, "line_count": 220.0},
			"satellite": {"curve": 0.0, "lines": 0.0, "bloom": 0.25},
			"tv": {"curve": 0.14, "lines": 0.3, "line_count": 240.0, "bloom": 0.5}}[k]
		(sc["mesh"] as MeshInstance3D).material_override = _screen_mat(k, null, Color(1, 1, 1), opts)
	for i in _set.phones.size():
		var ph: Dictionary = _set.phones[i]
		(ph["inner"] as MeshInstance3D).material_override = _screen_mat("inner %d" % i, null, Color(1, 1, 1),
			{"curve": 0.0, "lines": 0.0, "bloom": 0.15, "brightness": 1.1})
		(ph["outer"] as MeshInstance3D).material_override = _screen_mat("outer %d" % i, null, Color(1, 1, 1),
			{"curve": 0.0, "lines": 0.0, "bloom": 0.15, "brightness": 1.1})
	_live_vp = SubViewport.new()
	_live_vp.size = LIVE_SIZE
	_live_vp.own_world_3d = false
	_live_vp.world_3d = _root3.get_world_3d()
	_live_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_live_cam = Camera3D.new()
	_live_cam.fov = 46.0
	_live_cam.environment = _env
	_live_vp.add_child(_live_cam)
	_set_node.add_child(_live_vp)
	_live_cam.look_at_from_position(LIVE_EYE, LIVE_AIM, Vector3.UP)
	_snap = true
	if _built_n > 0:
		_build_attention()
		_build_sound()
	if _waiting:
		_waiting = false
		feed.wait_for(WAIT_FOR, false)


func _screen_mat(name: String, tex: Texture2D, tint: Color, opts: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/dispatch_screen.gdshader")
	m.set_shader_parameter("has_face", tex != null)
	if tex != null:
		m.set_shader_parameter("face", tex)
	m.set_shader_parameter("tint", tint)
	for k in opts:
		m.set_shader_parameter(String(k), opts[k])
	_mats[name] = m
	return m


func begin_session() -> void:
	_seed = feed.session_seed()
	_snap = true


func release() -> void:
	_subs = null
	_doc_key = ""


func _exit_tree() -> void:
	if _build_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1
		_made = {}
	if _pic_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_pic_task)
		_pic_task = -1
	if _waiting:
		_waiting = false
		feed.wait_for(WAIT_FOR, false)
	if _sounds != null:
		_sounds.stop()
	if stage != null and is_instance_valid(stage) and not _stage_was.is_empty():
		for key in _stage_was:
			stage.set(key, _stage_was[key])


# --- the Medium contract ------------------------------------------------------------------------------------------------

func owns_cast() -> bool:
	return true


func take_over(_outgoing: GhostScene) -> GhostScene:
	return _placeholder


func owns_bookend() -> bool:
	return true


## The subtitles are the desk's to caption ([method _captioned]).
func bind_captions(subs) -> bool:
	_subs = subs
	_doc_key = ""
	if subs != null and "captions" in subs:
		subs.captions = _captioned
	return false


func on_stage_resized(_size: Vector2) -> void:
	for n in [_blur, _title, _plate]:
		if n != null:
			(n as CanvasItem).queue_redraw()


## Is the line from subtitle word [param w0] to [param w1] captioned? Yes, unless every word of it is typed on the
## terminal as it is said (read there); always while a picture covers the screen.
func _captioned(w0: int, w1: int, _t: float) -> bool:
	if LetterMedium.cover_of(_plate.layers) >= 0.5:
		return true
	var map: Array = _follower.map
	for w in range(w0, w1 + 1):
		var si := int(map[w]) if w >= 0 and w < map.size() else -1
		if si < 0:
			continue
		if si >= _typed_words.size() or _typed_words[si] == 0:
			return true
	return false


func advance(_features, delta: float, _bookend: float) -> void:
	var t := maxf(feed.show_time(), 0.0)
	_ensure_doc()
	if _build_task >= 0 and WorkerThreadPool.is_task_completed(_build_task):
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1
		_land_set()
	if _pic_task >= 0 and WorkerThreadPool.is_task_completed(_pic_task):
		WorkerThreadPool.wait_for_task_completion(_pic_task)
		_pic_task = -1
		_land_pictures()
	_now = _subs.now() if _subs != null and is_instance_valid(_subs) else t
	if absf(_now - _last_now) > 1.0:
		_snap = true
	if _now < _last_now - 1.0:
		_held = {}
		_built_n = -1
	_last_now = _now
	if _subs != null and is_instance_valid(_subs) and not _parsed.is_empty():
		take_words(_subs.words)
	_env.adjustment_brightness = clampf(clampf(t / 1.2, 0.0, 1.0) * _end_fade() * feed.live_fade, 0.0, 1.0)
	var opening := _opening()
	ShowOpening.lens(ShowOpening.pull(feed.opening, _now, opening, _built_n > 0), _blur, _attrs)
	_title.alpha = ShowOpening.title_alpha(feed.opening, _now, opening, _built_n > 0)
	_title.queue_redraw()
	if _set != null:
		# the camera first: a phone at the ear and the mug lifted are held where it is this frame, never the last
		_tick_camera(delta)
		_pose(_now)
		_censor_at(_now)
	_show_pictures()
	_sounds.tick(_now, self)


## The outro, after the desk is done: once the voice has said its last word and the desk has done what follows it (the
## lamp switched off, a last line on the terminal, its sleep: rests the voice holds after its last word), the desk fades
## to black a beat later, black as the outro runs out.
func _end_fade() -> float:
	return ShowOpening.end_fade(_now - _after_last(), _follower, _spoken_n, feed.tail())


## How long the desk goes on after the voice's last word: the end of the rests it holds there (0 for none, or before the last
## word is heard).
func _after_last() -> float:
	var last := _word_t1(_spoken_n - 1)
	if last == INF:
		return 0.0
	var out := 0.0
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if int(a["after"]) >= _spoken_n and _t0[i] < INF:
			out = maxf(out, _t0[i] + float(a["rest"]) / _sp[i] + float(a["back"]) - last)
	return out


## The show opens on the desk at rest: the title and the blur clear a settle ([method Openings.settle]) before the first
## word or the first thing the desk does, so the desk is seen whole first, never under the title; INF until either is
## placed.
func _opening() -> float:
	var first := _word_t0(0)
	for i in _t0.size():
		if int((_actions[i] as Dictionary)["after"]) == 0 and _t0[i] < first:
			first = _t0[i]
	return first - Openings.settle(first) if first < INF else INF


# --- the document --------------------------------------------------------------------------------------------------------

func _ensure_doc() -> void:
	if _subs == null or not is_instance_valid(_subs):
		return
	var d: Dictionary = _subs.document
	_title.channel = String(d.get("title", ""))
	_title.byline = String(d.get("byline", d.get("author", "")))
	var src := String(d.get("source", ""))
	var dispatch: Dictionary = d.get("dispatch", {}) if d.get("dispatch") is Dictionary else {}
	var start: PackedStringArray = d.get("start_words", PackedStringArray()) \
		if d.get("start_words") is PackedStringArray else PackedStringArray()
	var key := "%d|%d|%d|%s" % [src.hash(), int(dispatch.get("seed", 0)), hash(dispatch.get("pictures", {})), " ".join(start)]
	if key == _doc_key:
		return
	_doc_key = key
	load_note(src, dispatch, start, int(d.get("start_index", -1)))


## Load a note: [param source] (its text, its marks in it) and [param dispatch] (`{seed, pictures}`, either missing); for a
## reading started mid-way its first words [param start] (normalized), [param near] the index they are about. Public for a
## gate, which hands it one by hand.
func load_note(source: String, dispatch: Dictionary, start := PackedStringArray(), near := -1) -> void:
	var seed := int(dispatch.get("seed", 0))
	if seed <= 0:
		seed = 1 + absi(source.hash()) % 99999
	_seed = seed
	_clutter = clutter_of(seed)
	_parsed = DispatchScript.parse(source)
	_actions = _parsed["actions"]
	_spans = _parsed["spans"]
	_moves = LetterMedium.moves_of(_spans, _seed)
	for i in _spans.size():
		if not (_moves[i] as Dictionary).is_empty():
			(_spans[i] as Dictionary)["move"] = _moves[i]
	var spoken: PackedStringArray = _parsed["spoken"]
	_spoken_n = spoken.size()
	_ends = DispatchScript.sentence_ends(_parsed)
	_typed_words = PackedByteArray()
	_typed_words.resize(_spoken_n)
	for a in _actions:
		if String((a as Dictionary)["kind"]) == "type":
			for si in range(int(a["from"]), int(a["to"])):
				if si < _spoken_n:
					_typed_words[si] = 1
	_labels = _parsed["phones"]
	_build_set(_labels, _seed)
	_load_pictures(dispatch.get("pictures", {}) if dispatch.get("pictures") is Dictionary else {})
	var from := TabletScript.find_run(spoken, start, near) if not start.is_empty() else -1
	var est := PackedFloat32Array()
	if from > 0:
		for w in DispatchScript.rehearsal(_parsed):
			est.append(float((w as Dictionary)["t0"]))
	_follower.reset(spoken, from, est)
	_built_n = -1
	_held = {}
	_leg_known = {}
	_t0 = PackedFloat32Array()
	_t0.resize(_actions.size())
	_t0.fill(INF)
	_sp = PackedFloat32Array()
	_sp.resize(_actions.size())
	_sp.fill(1.0)
	_chars = {}
	_snap = true


## The pictures' files, decoded on a worker in the app and put up as they land (a picture not landed yet leaves its screen
## as it was); in a render and a gate, here.
func _load_pictures(paths: Dictionary) -> void:
	if _pic_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_pic_task)
		_pic_task = -1
	_pictures = {}
	_decoded = {}
	if paths.is_empty():
		return
	if is_inside_tree() and (away_in_tests or not TablePhysics.render_waits()):
		_pic_task = WorkerThreadPool.add_task(_decode.bind(paths.duplicate()), false, "the dispatch desk's pictures")
		return
	_decode(paths)
	_land_pictures()


func _decode(paths: Dictionary) -> void:
	var out := {}
	for key in paths:
		var img := Image.load_from_file(String(paths[key]))
		if img == null or img.is_empty():
			continue
		img.generate_mipmaps()
		out[String(key)] = img
	_decoded = out


func _land_pictures() -> void:
	for key in _decoded:
		_pictures[key] = ImageTexture.create_from_image(_decoded[key])
	_decoded = {}


## The voice's words so far, matched, and the plan made again when more came. Public for a gate, which hands it words as a
## live reading would.
func take_words(words: Array) -> void:
	var grown := words.size() != _built_n
	if grown and not (_built_n > 0 and words.size() > _built_n):
		_held = {}
	_follower.extend(words)
	if grown:
		_built_n = words.size()
		_build_plan()


# --- the plan ----------------------------------------------------------------------------------------------------------

func _word_t0(si: int) -> float:
	if si < 0 or si >= _follower.said0.size() or _follower.said0[si] == ReadingFollower.NO_TIME:
		return INF
	return _follower.said0[si]


func _word_t1(si: int) -> float:
	if si < 0 or si >= _follower.said1.size() or _follower.said1[si] == ReadingFollower.NO_TIME:
		return INF
	return _follower.said1[si]


## When each action happens, and then everything that follows from it: each placed in its silence ([method _place]), what
## has begun kept; then the typed characters' moments, the phones' moves, where the camera looks, and what is heard.
func _build_plan() -> void:
	for i in _actions.size():
		if _held.has(i):
			_t0[i] = float(_held[i][0])
			_sp[i] = float(_held[i][1])
			continue
		var got := _place(i)
		_t0[i] = got.x
		_sp[i] = got.y
		if got.x <= _now and got.x < INF:
			_held[i] = [got.x, got.y]
	_chars = {}
	for i in _actions.size():
		if String((_actions[i] as Dictionary)["kind"]) in ["type", "reply"]:
			_chars[i] = _char_times(i)
	_build_phones()
	_build_track()
	if _set != null:
		_build_attention()
		_build_sound()


## Where action [param i] falls: `(t0, speed)`. Back from the word after it by what the script wrote after it in the same
## silence and its own rest; never before the word before it ended (squeezed quicker where the silence came out short).
## With the word after it not heard yet, on from the word before by what was written before it. INF until either is.
func _place(i: int) -> Vector2:
	var a: Dictionary = _actions[i]
	var n := int(a["after"])
	var rest := float(a["rest"])
	var next0 := _word_t0(n) if n < _spoken_n else INF
	var prev1 := _word_t1(n - 1) if n > 0 else -INF
	if next0 < INF:
		var t := next0 - float(a["back"]) - rest
		if prev1 > -INF and t < prev1 + LEAD:
			var room := next0 - float(a["back"]) - (prev1 + LEAD)
			var s := clampf(room / maxf(rest, 0.01), 0.3, 1.0)
			return Vector2(prev1 + LEAD, 1.0 / s)
		return Vector2(t, 1.0)
	if prev1 > -INF and prev1 < INF:
		return Vector2(prev1 + LEAD + float(a["fwd"]), 1.0)
	return Vector2(INF, 1.0)


## When action [param i] ends: its start and its length, at its speed.
func _end_of(i: int) -> float:
	return _t0[i] + float((_actions[i] as Dictionary)["len"]) / _sp[i]


## A typed block's characters, each's moment ([constant DispatchScript.AHEAD_WORDS]): the first words at a typist's pace
## in the rest before the voice, done as it begins; each word after typed while the voice says the one that many before
## it, through to the next one's start, at most [constant DispatchScript.KEY_QUICK] a key and always done before it is
## itself said, so the voice reads behind the keys and is never waiting on them. A reply's keys under each word as it is
## said. INF for a word not heard yet.
func _char_times(i: int) -> PackedFloat32Array:
	var a: Dictionary = _actions[i]
	var text := String(a["text"])
	var out := PackedFloat32Array()
	out.resize(text.length())
	out.fill(INF)
	if _t0[i] == INF:
		return out
	var spans: Array = a["spans"]
	var from := int(a["from"])
	var last := _t0[i] + DispatchScript.TYPE_LEAD * 0.6
	var ahead := String(a["kind"]) == "type"
	var n := DispatchScript.AHEAD_WORDS
	var first := _word_t0(from)
	for k in spans.size():
		var span: Dictionary = spans[k]
		var c0 := int(span["c0"])
		var c1 := int(span["c1"])
		var keys := float(maxi(c1 - c0, 1))
		var s: float
		var e: float
		if ahead:
			var said := _word_t0(from + k)
			if k < n:
				s = last
				e = s + keys * DispatchScript.KEY_EACH
				if first < INF:
					e = minf(e, first - 0.05)
			else:
				var w0 := _word_t0(from + k - n)
				var w1 := _word_t0(from + k - n + 1)
				if w0 == INF or w1 == INF:
					break
				s = maxf(w0, last)
				e = maxf(w1, s + keys * DispatchScript.KEY_QUICK)
				if said < INF:
					e = minf(e, said - 0.05)
			e = maxf(e, s + 0.01)
		else:
			var w0 := _word_t0(from + k)
			var w1 := _word_t1(from + k)
			if w0 == INF or w1 == INF:
				break
			s = maxf(w0 - DispatchScript.REPLY_AHEAD, last)
			e = maxf(w1 - DispatchScript.REPLY_AHEAD * 0.3, s + 0.04 * float(c1 - c0))
		for c in range(c0, c1):
			out[c] = s + (float(c - c0) + 0.5) / keys * (e - s)
		last = e
	return out


## The phones' moves from the calls, hang-ups, rings and texts: `{label, from, to, t0, dur, slot, how}` - from and to
## "row", "ear" or "desk".
func _build_phones() -> void:
	_phone_moves = []
	var on_desk: Array = []                  # what lies open on the desk, by slot
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var t := _t0[i]
		if t == INF:
			continue
		var s := _sp[i]
		match String(a["kind"]):
			"call":
				for p in a["parts"]:
					var part: Dictionary = p
					var label := String(part["label"])
					var at := t + float(part["at"]) / s
					match String(part["move"]):
						"lay_down":
							var slot := on_desk.find("")
							if slot < 0:
								slot = on_desk.size()
								on_desk.append(label)
							else:
								on_desk[slot] = label
							_phone_moves.append({"label": label, "from": "ear", "to": "desk", "t0": at, "dur": DispatchScript.LAY_DOWN / s, "slot": slot})
						"pick_up":
							var slot := on_desk.find(label)
							if slot >= 0:
								on_desk[slot] = ""
							_phone_moves.append({"label": label, "from": "desk", "to": "ear", "t0": at, "dur": DispatchScript.PICK_UP / s, "slot": slot})
						"dial":
							var until := t + float(a["rest"]) / s
							_phone_moves.append({"label": label, "from": "row", "to": "read", "t0": at, "dur": DispatchScript.LIFT / s,
								"how": "dial", "dialed": at + DispatchScript.LIFT / s, "until": until, "slot": -1, "began": t})
							_phone_moves.append({"label": label, "from": "read", "to": "ear", "t0": at + (DispatchScript.LIFT + DispatchScript.DIAL
								- DispatchScript.TO_EAR) / s, "dur": DispatchScript.TO_EAR / s, "how": "dial", "until": until, "slot": -1, "began": t})
							continue
						_:
							_phone_moves.append({"label": label, "from": "row", "to": "ear", "t0": at, "dur": DispatchScript.LIFT / s,
								"how": String(part["move"]), "until": t + float(a["rest"]) / s, "slot": -1, "began": t})
			"hang_up":
				var label := String(a["label"])
				var slot := on_desk.find(label)
				var from := "ear"
				if slot >= 0:
					on_desk[slot] = ""
					from = "desk"
				_phone_moves.append({"label": label, "from": from, "to": "row", "t0": t, "dur": DispatchScript.HANG_UP / s, "slot": slot})
	# The texts, once the calls are laid out: each phone up out of its row to be read (when the calls leave it there), and
	# home again once read and answered - unless it texts again in a moment, when it stays up
	var up := {}                             # a phone held up -> the move that brought it, its `down` when it goes home
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "text" or _t0[i] == INF:
			continue
		var label := String(a["label"])
		var arrives := _t0[i] + DispatchScript.TEXT_CHIME / _sp[i]
		if up.has(label):
			var open_mv: Dictionary = up[label]
			if arrives < float(open_mv["down"]) + DispatchScript.TEXT_AGAIN:
				open_mv["down"] = maxf(float(open_mv["down"]), _read_until(i))
				continue
			_put_down(open_mv)
			up.erase(label)
		if _call_place(label, arrives) != "row":
			continue
		var mv := {"label": label, "from": "row", "to": "read", "t0": arrives, "dur": DispatchScript.READ_LIFT / _sp[i], "slot": -1,
			"down": _read_until(i)}
		_phone_moves.append(mv)
		up[label] = mv
	for label in up:
		_put_down(up[label])
	_phone_moves.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t0"]) < float(y["t0"]))


## A phone held up to be read [param mv] goes home at its `down` (not while what it waits for is unheard).
func _put_down(mv: Dictionary) -> void:
	if float(mv["down"]) < INF:
		_phone_moves.append({"label": mv["label"], "from": "read", "to": "row", "t0": float(mv["down"]), "dur": DispatchScript.READ_DOWN,
			"slot": -1})


## Where the calls have phone [param label] at [param t]: "row", "ear", "desk" (or on its way).
func _call_place(label: String, t: float) -> String:
	var at := "row"
	for m in _phone_moves:
		var d: Dictionary = m
		if String(d["label"]) == label and float(d["t0"]) <= t:
			at = String(d["to"])
	return at


## When a text is done with: read - and, where the room answers it, the answer typed and sent ([constant
## DispatchScript.REPLY_SEND] after its last key); INF while the answer is not heard yet.
func _read_until(i: int) -> float:
	var a: Dictionary = _actions[i]
	var done := _t0[i] + float(a["rest"]) / _sp[i]
	var label := String(a["label"])
	for k in range(i + 1, _actions.size()):
		var b: Dictionary = _actions[k]
		if String(b.get("label", "")) != label:
			continue
		if String(b["kind"]) == "reply":
			return maxf(done, _sent_at(k))
		if String(b["kind"]) == "text":
			break
	return done


## When reply [param k] is sent: its last key, and a beat; INF until it is heard.
func _sent_at(k: int) -> float:
	var times: PackedFloat32Array = _chars.get(k, PackedFloat32Array())
	if times.is_empty() or times[times.size() - 1] == INF:
		return INF
	return times[times.size() - 1] + DispatchScript.REPLY_SEND / _sp[k]


## The next text from [param label] after action [param i], -1 for none.
func _next_text(label: String, i: int) -> int:
	for k in range(i + 1, _actions.size()):
		var b: Dictionary = _actions[k]
		if String(b["kind"]) == "text" and String(b["label"]) == label:
			return k
	return -1


## The camera's attention: what it turns to and from when to when ([method _attention]).
func _build_attention() -> void:
	_attn = []
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var t := _t0[i]
		if t == INF:
			continue
		var e := _end_of(i)
		var n0 := _attn.size()
		match String(a["kind"]):
			"call":
				var label := String(a["label"])
				var lift_at := t + float((a["parts"] as Array).back()["at"]) / _sp[i]
				_attn.append({"t0": t, "t1": lift_at + DispatchScript.LIFT * 0.7, "spot": _phone_spot(label, 34.0)})
			"hang_up":
				_attn.append({"t0": t, "t1": t + DispatchScript.HANG_UP, "spot": _spot("phones")})
			"ring":
				_attn.append({"t0": t, "t1": e, "spot": _phone_spot(String(a["label"]), 26.0)})
			"text", "reply":
				var until := _read_until(i) if String(a["kind"]) == "text" else _sent_at(i)
				_attn.append({"t0": t, "t1": (until if until < INF else e) + 0.3, "spot": _spot("home")})
			"ping":
				# held a while as it pings, to the end of a sentence, then let go of quickly: a still blip is not watched
				_attn.append({"t0": t, "t1": e + 0.5, "hold": _ping_hold(i), "spot": _spot("radar"), "linger": PING_LINGER})
			"moving":
				# as he sets off, and while he walks - until the ping where he arrives, or a drive's first moments (a long way
				# is no long stare); passing through a place on the way, nothing
				if bool(a.get("passing", false)):
					continue
				var arrive := t + MOVING_LOOK
				for k in range(i + 1, _actions.size()):
					if String((_actions[k] as Dictionary)["kind"]) == "ping":
						if _t0[k] < INF:
							arrive = maxf(arrive, _t0[k])
						break
				_attn.append({"t0": t, "t1": minf(arrive, t + MOVING_HOLD_MOST), "spot": _spot("radar")})
			"sound":
				_attn.append({"t0": t, "t1": e + 1.5, "spot": _spot("radar")})
			"session":
				_attn.append({"t0": t, "t1": e + 1.5, "spot": _spot("terminal")})
			"static":
				_attn.append({"t0": t, "t1": e + 0.8, "spot": _spot("receiver")})
			"print":
				_attn.append({"t0": t, "t1": e + 0.8, "spot": _spot("printer")})
			"type":
				var last := int(a["to"]) - 1
				var done := _word_t1(last) if last >= int(a["from"]) else t + 2.0
				_attn.append({"t0": t, "t1": (done if done < INF else t + 30.0) + 2.5, "spot": _spot("terminal")})
			"screen":
				var lines := String(a["text"]).count("\n") + 1
				_attn.append({"t0": t, "t1": t + 3.0 + 0.5 * float(lines), "spot": _spot("terminal")})
			"strike", "sleep":
				_attn.append({"t0": t, "t1": e + 1.0, "spot": _spot("terminal")})
			"off", "picture", "live":
				_attn.append({"t0": t, "t1": e + (1.0 if String(a["kind"]) == "off" else 3.5), "spot": _spot(String(a["screen"]))})
			"look":
				var at := String(a["at"])
				_attn.append({"t0": t, "t1": INF, "spot": _spot(at if SPOTS.has(at) else "home"), "sticky": true})
			"lift":
				# the whole desk: the mug is seen to rise toward the chair and leave the picture past its lower edge
				_attn.append({"t0": t, "t1": e, "spot": _spot("home")})
			"switch":
				_attn.append({"t0": t, "t1": e + 1.6, "spot": _spot("switch")})
			"gain":
				# the knob turned and the scope watched, as a look holds it, until something else is active
				_attn.append({"t0": t, "t1": INF, "spot": _spot("radar"), "sticky": true})
			"bell":
				_attn.append({"t0": t, "t1": _bell_at(i) + 1.5, "spot": _spot("terminal")})
			"lamp":
				_attn.append({"t0": t, "t1": e + 2.5, "spot": _spot("home")})
		if _attn.size() > n0:
			(_attn.back() as Dictionary)["kind"] = String(a["kind"])
	_attn = _settled(_attn)


## What is turned to is seen: [param attn]'s looks in order, those the camera would only swerve through or turn away and
## straight back for dropped ([method _looks_taken]); each held at least [constant LOOK_LEAST] (a ping to its sentence's
## end) but never past what begins next, so nothing is gone back to; a `look:` until the next; and the camera kept on what
## it was on rather than eased home for less than [constant AWAY_LEAST] before it turns again - unless what comes next is
## the whole desk, where it goes as it would have.
func _settled(attn: Array) -> Array:
	attn.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t0"]) < float(y["t0"]))
	var out := _looks_taken(attn)
	for k in out.size():
		var w: Dictionary = out[k]
		var next0 := float((out[k + 1] as Dictionary)["t0"]) if k + 1 < out.size() else INF
		if bool(w.get("sticky", false)):
			w["t1"] = next0
		w["t1"] = maxf(float(w["t1"]), minf(maxf(float(w["t0"]) + LOOK_LEAST, float(w.get("hold", 0.0))), next0))
	var home: Dictionary = _spot("home")
	for k in range(out.size() - 1):
		var w: Dictionary = out[k]
		var nxt: Dictionary = out[k + 1]
		if nxt["spot"] != home and float(nxt["t0"]) < float(w["t1"]) + float(w.get("linger", HOME_AFTER)) + AWAY_LEAST:
			w["t1"] = maxf(float(w["t1"]), float(nxt["t0"]))
	return out


## The looks the camera takes of [param attn] (sorted by start): none cut by the next before it could be got to
## ([constant GLANCE_LEAST]), and none away from a thing for less than [constant LOOK_LEAST] between two looks at it, so
## it never swerves toward one thing on its way to another, nor turns away and straight back. Kept whatever comes: a look
## that outlasts what begins over it (the camera comes back to it), a `look:`, and words to be read ([constant TO_READ]).
func _looks_taken(attn: Array) -> Array:
	var out: Array = []
	for k in attn.size():
		var w: Dictionary = attn[k]
		if bool(w.get("sticky", false)) or String(w.get("kind", "")) in TO_READ or k + 1 >= attn.size():
			out.append(w)
			continue
		var nxt: Dictionary = attn[k + 1]
		var cover := float(nxt["t1"])
		for j in range(k + 2, attn.size()):
			if float((attn[j] as Dictionary)["t0"]) > cover or cover >= float(w["t1"]):
				break
			cover = maxf(cover, float((attn[j] as Dictionary)["t1"]))
		var outlasts := float(w["t1"]) > cover + 0.5
		var cut := float(nxt["t0"]) - float(w["t0"]) < GLANCE_LEAST
		var was: Dictionary = out.back() if not out.is_empty() else {}
		var between: bool = not was.is_empty() and nxt["spot"] == was["spot"] and w["spot"] != was["spot"] \
			and float(nxt["t0"]) - float(w["t0"]) < LOOK_LEAST \
			and float(was["t1"]) + float(was.get("linger", HOME_AFTER)) >= float(w["t0"])
		if (cut or between) and not outlasts:
			continue
		out.append(w)
	return out


## How long ping [param i] holds the radar: [constant PING_HOLD] from its ring, on to the end of the sentence being said
## then if it ends by [constant PING_HOLD_MOST], and never before its ring is over.
func _ping_hold(i: int) -> float:
	var t := _t0[i]
	var least := maxf(t + PING_HOLD, _end_of(i) + 0.5)
	var most := maxf(t + PING_HOLD_MOST, least)
	for si in range(int((_actions[i] as Dictionary)["after"]), _ends.size()):
		var e := _word_t1(si)
		if e == INF or e > most:
			break
		if e >= least and _ends[si] == 1:
			return e + 0.3
	return least


func _spot(key: String) -> Dictionary:
	return _set.spots.get(key, _set.spots["home"])


## A spot close on phone [param label] in its row, the lens [param fov] wide; on its lid's little screen for a text.
func _phone_spot(label: String, fov: float, lid := false) -> Dictionary:
	var i := _labels.find(label)
	if i < 0:
		return _spot("phones")
	var home := _set.phone_home(i)
	var aim := home.origin + Vector3(0, DispatchSet.PHONE.y, 0.02 if lid else 0.0)
	var eye := DispatchSet.EYE + (aim - DispatchSet.EYE).normalized() * (0.30 if lid else 0.18)
	return {"aim": aim, "eye": eye, "fov": fov}


## What is heard and when ([DispatchSounds]): each `{t, t1?, what | kind, at, ...}`, by time.
func _build_sound() -> void:
	var out: Array = []
	var radar_at := _set.desk_at("radar")
	var recv_at := _set.desk_at("receiver")
	var printer_at := _set.desk_at("printer")
	var term_at := _set.desk_at("keyboard")
	for mv in _phone_moves:
		var m: Dictionary = mv
		var i := _labels.find(String(m["label"]))
		var at := _set.phone_home(i).origin if i >= 0 else Vector3.ZERO
		var t := float(m["t0"])
		var dur := float(m["dur"])
		match [String(m["from"]), String(m["to"])]:
			["row", "ear"]:
				out.append({"t": t + dur * 0.25, "what": "flip", "at": at})
			["row", "read"]:
				out.append({"t": t + dur * 0.25, "what": "flip", "at": at})
				if String(m.get("how", "")) == "dial":
					var k := _sp_of(m)
					var dialed := float(m["dialed"])
					out.append({"t": dialed + DispatchScript.SPEED_PRESS / k, "what": "dtmf", "digit": 1, "secs": DispatchScript.SPEED_HOLD / k, "at": at})
					out.append({"t": dialed + DispatchScript.SEND_AT / k, "what": "pad", "at": at})
					var ring_from := dialed + DispatchScript.DIAL / k
					out.append({"t": ring_from, "t1": ring_from + DispatchScript.RING_CYCLE * float(DispatchScript.RINGS - 1) + DispatchScript.RING_ON, "kind": "ringback"})
			["ear", "desk"]:
				out.append({"t": t + dur * 0.9, "what": "lay", "at": at})
			["desk", "ear"]:
				out.append({"t": t + dur * 0.1, "what": "click", "at": at})
			[_, "row"]:
				out.append({"t": t + dur * 0.15, "what": "snap", "at": at})
				out.append({"t": t + dur * 0.92, "what": "lay", "at": at})
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var t := _t0[i]
		if t == INF:
			continue
		var e := _end_of(i)
		match String(a["kind"]):
			"ring":
				var label := String(a["label"])
				var stop := e
				for mv in _phone_moves:
					if String((mv as Dictionary)["label"]) == label and float(mv["t0"]) >= t and float(mv["t0"]) < stop:
						stop = float(mv["t0"])
				var li := _labels.find(label)
				out.append({"t": t, "t1": stop, "kind": "buzz", "pattern": "ring", "ears": DispatchSounds.ears_of(_set.phone_home(li).origin if li >= 0 else Vector3.ZERO)})
			"text":
				var li := _labels.find(String(a["label"]))
				var home := _set.phone_home(li).origin if li >= 0 else Vector3.ZERO
				out.append({"t": t, "what": "chime", "at": home})
				out.append({"t": t, "t1": t + DispatchScript.TEXT_BUZZ, "kind": "buzz", "pattern": "text", "ears": DispatchSounds.ears_of(home)})
			"reply":
				var times: PackedFloat32Array = _chars.get(i, PackedFloat32Array())
				var text := String(a["text"])
				var near := _cam.global_position + Vector3(0.0, -0.12, -0.25)
				for c in times.size():
					if times[c] == INF:
						break
					if text[c] != " ":
						out.append({"t": times[c], "what": "pad", "at": near})
				var sent := _sent_at(i)
				if sent < INF:
					out.append({"t": sent - 0.15, "what": "sent", "at": near})
			"ping":
				out.append({"t": t + 0.25, "what": "ping", "at": radar_at})
				out.append({"t": t + 0.25 + DispatchSounds.PING_ECHO, "what": "echo", "at": radar_at})
				for leg in _legs:
					if int((leg as Dictionary)["i"]) == i and float(leg["t0"]) < t:
						for swept in passes(float(leg["t0"]), t):
							out.append({"t": swept, "what": "tick", "at": radar_at})
			"moving":
				# the radar's alarm as he sets off: a low beep, then two higher (passing through a place on the way, none)
				if bool(a.get("passing", false)):
					continue
				out.append({"t": t, "what": "alarm", "at": radar_at})
				out.append({"t": t + 0.16, "what": "alarm_hi", "at": radar_at})
				out.append({"t": t + 0.34, "what": "alarm_hi", "at": radar_at})
			"session":
				var plan: Dictionary = a["plan"]
				var steps: Array = a["steps"]
				if bool(terminal_at(t - 0.01).get("asleep", true)):
					out.append({"t": t, "what": "crt", "at": term_at})
				for k in steps.size():
					var sp: Dictionary = (plan["steps"] as Array)[k]
					var typed := String((steps[k] as Dictionary)["typed"])
					var keys: PackedFloat32Array = sp["keys"]
					for c in keys.size():
						out.append({"t": t + keys[c] / _sp[i], "what": "space" if typed[c] == " " else "key", "at": term_at})
					if float(sp["enter"]) >= 0.0:
						out.append({"t": t + float(sp["enter"]) / _sp[i], "what": "enter", "at": term_at})
			"static":
				out.append({"t": t, "t1": e, "kind": "static", "storm": String(a["storm"]), "seed": hash([_seed, i])})
			"sound":
				if String(a["sound"]) == "jet":
					out.append({"t": t, "t1": e, "kind": "jet"})
			"print":
				out.append({"t": t, "t1": e, "kind": "print", "lines": (a["lines"] as PackedStringArray).size(), "ears": DispatchSounds.ears_of(printer_at)})
			"switch":
				out.append({"t": t + DispatchScript.SWITCH_AT / _sp[i], "what": "toggle", "at": _set.desk_at("switch")})
			"lift":
				out.append({"t": t + 0.1, "what": "lift", "at": _set.desk_at("mug")})
				out.append({"t": e - 0.05, "what": "thud", "at": _set.desk_at("mug")})
			"gain":
				var from := int(a["from"])
				var to := int(a["to"])
				var step := signi(to - from)
				var d := from
				while d != to:
					d += step
					out.append({"t": _step_at(i, d), "what": "detent", "at": radar_at})
			"bell":
				var rung := _bell_at(i)
				out.append({"t": rung, "t1": rung + DispatchSounds.BELL_LEN, "kind": "bell", "ears": DispatchSounds.ears_of(term_at)})
			"lamp":
				out.append({"t": t + DispatchScript.LAMP_AT / _sp[i], "what": "lamp", "at": _set.desk_at("lamp")})
			"type":
				var times: PackedFloat32Array = _chars.get(i, PackedFloat32Array())
				var text := String(a["text"])
				for c in times.size():
					if times[c] == INF:
						break
					var ch := text[c]
					out.append({"t": times[c], "what": "space" if ch == " " else ("enter" if ch == "\n" else "key"), "at": term_at})
			"strike":
				var decide := float(a["decide"]) / _sp[i]
				var block: Dictionary = _actions[int(a["block"])]
				var n := String(block["text"]).length()
				var back := e - (t + decide)
				for c in mini(n, 160):
					out.append({"t": t + decide + back * float(c) / float(maxi(n, 1)), "what": "key", "at": term_at})
			"sleep", "screen":
				out.append({"t": t + 0.1, "what": "crt", "at": term_at})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t"]) < float(y["t"]))
	_sound_plan = out
	_sound_rev += 1


## The desk's sound plan, and its revision ([DispatchSounds]).
func sound_plan() -> Array:
	return _sound_plan


func sound_rev() -> int:
	return _sound_rev


# --- the desk at a moment ---------------------------------------------------------------------------------------------

## Everything on the desk at [param t]: the phones, the terminal, the radar, the receiver, the printer, the screens, the
## switch, the mug, the roots.
func _pose(t: float) -> void:
	_pose_phones(t)
	_screens.show_terminal(terminal_at(t))
	_screens.show_radar(radar_at(t))
	var st := storm_at(t)
	_screens.show_scope({"t": snappedf(t, 1.0 / 30.0), "level": float(st.get("level", 0.0)), "storm": String(st.get("storm", ""))})
	_set.needle.rotation_degrees = Vector3(0, 0, lerpf(48.0, -48.0, clampf(0.08 + float(st.get("level", 0.0)) * 0.85 + 0.03 * sin(t * 1.3), 0.0, 1.0)))
	_set.terminal_glow.light_energy = 0.03 if bool(terminal_at(t).get("asleep", true)) else 0.16
	_pose_printer(t)
	_pose_screens(t)
	_pose_switch(t)
	_pose_mug(t)
	if _set.gain_knob != null:
		_set.gain_knob.rotation.z = DispatchSet.gain_angle(gain_at(t))
	var lit := lamp_at(t)
	_set.lamp.light_energy = DispatchSet.LAMP_ENERGY * lit
	_set.lamp.visible = lit > 0.0
	_roots.grow(t)
	var blink := fposmod(t, 2.4) < 0.25
	_set.tracker_led.visible = blink


## Where each phone is at [param t], its lid, and what its screens show: in its row, rising to the ear, at the ear, laid open
## on the desk, back to the row; rattling while it rings; its little screen lit by a text. The pool of lit faces goes first
## to the phone in hand, then those on the desk, then one ringing or texting.
func _pose_phones(t: float) -> void:
	var cam_xf := _cam.global_transform
	var ear := cam_xf * Transform3D(Basis.from_euler(EAR_TURN * (PI / 180.0)), EAR)
	var held := cam_xf * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(READ_LEAN)), READ)
	var lit: Array = []                   # [phone index, which screen, state]
	for i in _set.phones.size():
		var ph: Dictionary = _set.phones[i]
		var label := String(ph["label"])
		var home: Transform3D = ph["home"]
		var place := "row"
		var mv := {}
		for m in _phone_moves:
			if String((m as Dictionary)["label"]) == label and float(m["t0"]) <= t:
				mv = m
		var xf := home
		var open := 0.0
		if not mv.is_empty():
			var u := clampf((t - float(mv["t0"])) / maxf(float(mv["dur"]), 0.01), 0.0, 1.0)
			var e := _jerkless(u)
			var a := _where(String(mv["from"]), home, ear, held, int(mv.get("slot", 0)))
			var b := _where(String(mv["to"]), home, ear, held, int(mv.get("slot", 0)))
			xf = _arc(a, b, e, 0.08 if String(mv["from"]) == "row" or String(mv["to"]) == "row" else 0.04)
			place = String(mv["to"]) if u >= 1.0 else "moving"
			var to_open := 0.0 if String(mv["to"]) == "row" else 1.0
			var from_open := 0.0 if String(mv["from"]) == "row" else 1.0
			var ou := clampf(u * 2.2, 0.0, 1.0) if to_open > from_open else clampf(u * 2.5, 0.0, 1.0)
			open = lerpf(from_open, to_open, _jerkless(ou))
			var dialing := String(mv.get("how", "")) == "dial" and t < float(mv.get("until", -INF))
			if dialing and t < float(mv.get("dialed", -INF)) + DispatchScript.SEND_AT / _sp_of(mv):
				var pressed := t >= float(mv.get("dialed", INF)) + DispatchScript.SPEED_PRESS / _sp_of(mv)
				lit.append([i, "inner", {"mode": "dial", "label": label, "digits": "1" if pressed else ""}])
			elif place == "ear" or (place == "moving" and String(mv["to"]) == "ear") or dialing:
				var secs := t - float(mv.get("began", mv["t0"]))
				lit.append([i, "inner", {"mode": "calling" if dialing else "call", "label": label, "secs": snappedf(maxf(secs, 0.0), 1.0)}])
			elif place == "read" or (place == "moving" and (String(mv["to"]) == "read" or String(mv["from"]) == "read")):
				lit.append([i, "inner", _reading(label, t)])
			elif place == "desk" or (place == "moving" and String(mv["to"]) == "desk"):
				lit.append([i, "inner", {"mode": "hold", "label": label, "secs": snappedf(t - float(mv["t0"]), 1.0)}])
		# Ringing: rattling in the row, its little screen saying who; a text: its little screen with the words
		for k in _actions.size():
			var a: Dictionary = _actions[k]
			if String(a.get("label", "")) != label or _t0[k] > t or _t0[k] == INF:
				continue
			var kind := String(a["kind"])
			var e := _end_of(k)
			if kind == "ring" and t < e and place == "row":
				var cyc := fposmod(t - _t0[k], DispatchScript.BUZZ_ON + DispatchScript.BUZZ_OFF)
				if cyc < DispatchScript.BUZZ_ON:
					var j := t * 37.0
					xf = xf.translated(Vector3(sin(j * 1.7) * RATTLE, 0.0, cos(j * 2.3) * RATTLE))
					xf.basis = xf.basis * Basis(Vector3.UP, deg_to_rad(sin(j * 3.1) * RATTLE_TURN))
				lit.append([i, "outer", {"mode": "ring", "label": label}])
			elif kind == "text" and t < _t0[k] + DispatchScript.TEXT_CHIME + DispatchScript.READ_LIFT and place == "row":
				if t - _t0[k] < DispatchScript.TEXT_BUZZ:
					var j := t * 41.0
					xf = xf.translated(Vector3(sin(j * 1.9) * RATTLE * 0.6, 0.0, cos(j * 2.1) * RATTLE * 0.6))
				lit.append([i, "outer", {"mode": "text", "label": label, "words": String(a["words"])}])
		(ph["node"] as Node3D).global_transform = xf
		(ph["hinge"] as Node3D).rotation_degrees = Vector3(-DispatchSet.LID_OPEN * open, 0, 0)
	var used := {}
	var k := 0
	lit.sort_custom(func(x: Array, y: Array) -> bool: return _rank(String(x[2]["mode"])) < _rank(String(y[2]["mode"])))
	for l in lit:
		if k >= DispatchScreens.PHONE_FACES:
			break
		_screens.show_phone(k, l[2])
		var m: ShaderMaterial = _mats["%s %d" % [String(l[1]), int(l[0])]]
		m.set_shader_parameter("has_face", true)
		m.set_shader_parameter("face", (_screens.faces[k] as SubViewport).get_texture())
		m.set_shader_parameter("power", 1.0)
		used["%s %d" % [String(l[1]), int(l[0])]] = true
		k += 1
	for i in _set.phones.size():
		for which in ["inner", "outer"]:
			var name := "%s %d" % [which, i]
			if not used.has(name):
				var m: ShaderMaterial = _mats[name]
				m.set_shader_parameter("has_face", false)
				m.set_shader_parameter("power", 0.0)


static func _rank(mode: String) -> int:
	return {"call": 0, "calling": 0, "dial": 0, "read": 0, "hold": 1, "ring": 2, "text": 2}.get(mode, 3)


## The speed a move [param mv] was made at (its action's), for the moments inside it.
func _sp_of(mv: Dictionary) -> float:
	return clampf(DispatchScript.LIFT / maxf(float(mv["dur"]), 0.001), 1.0, 4.0) if String(mv.get("how", "")) == "dial" else 1.0


## What a phone held up to be read shows at [param t]: `{mode: read, label, thread: [[in | out, words, sent]]}` - the texts
## from it since it last came up, and the room's answers under each, as far as they are typed and whether sent: the latest
## few, as a phone's screen keeps them.
func _reading(label: String, t: float) -> Dictionary:
	var since := -INF
	for m in _phone_moves:
		var d: Dictionary = m
		if String(d["label"]) == label and String(d["to"]) == "read" and float(d["t0"]) <= t + 0.001:
			since = float(d["t0"])
	var thread: Array = []
	for k in _actions.size():
		var a: Dictionary = _actions[k]
		if String(a.get("label", "")) != label or _t0[k] == INF or _t0[k] > t:
			continue
		match String(a["kind"]):
			"text":
				if _t0[k] + DispatchScript.TEXT_CHIME >= since - 0.01:
					thread.append(["in", String(a["words"]), true])
			"reply":
				if not thread.is_empty():
					var times: PackedFloat32Array = _chars.get(k, PackedFloat32Array())
					var n := 0
					while n < times.size() and times[n] <= t:
						n += 1
					thread.append(["out", String(a["text"]).substr(0, n), t >= _sent_at(k) - 0.15])
	if thread.size() > 4:
		thread = thread.slice(thread.size() - 4)
	return {"mode": "read", "label": label, "thread": thread}


## Where a phone is in [param place] ("row", "ear" - [param ear], in the world - "read", held up before the eye
## ([param held]), or "desk", its [param slot]).
func _where(place: String, home: Transform3D, ear: Transform3D, held: Transform3D, slot: int) -> Transform3D:
	match place:
		"read":
			return held
		"ear":
			return ear
		"desk":
			return _set.held_xf(maxi(slot, 0))
	return home


## Between [param a] and [param b] at [param u], lifted [param lift] at the middle of the way.
static func _arc(a: Transform3D, b: Transform3D, u: float, lift: float) -> Transform3D:
	var o := a.origin.lerp(b.origin, u) + Vector3(0, lift * sin(u * PI), 0)
	var q := a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), u)
	return Transform3D(Basis(q), o)


## Minimum jerk: a hand's way from 0 to 1.
static func _jerkless(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return x * x * x * (10.0 - 15.0 * x + 6.0 * x * x)


## The terminal at [param t]: `{lines, asleep, cursor, t}` - asleep (dark) until a block wakes it; a shown block replaces
## what it showed, drawn a line at a time; a typed one is added under it a key at a time (a fresh screen after sleep), as is
## a session ([method session_text]); a strike backspaces it, sleep darkens it again. Its lines wrapped to its columns, the last [constant DispatchScript.ROWS].
##
## [param whole]: a redacted run being typed is there whole from its first key ([method session_text]).
func terminal_at(t: float, whole := false) -> Dictionary:
	var screen := ""
	var asleep := true
	var cursor_until := -INF
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var t0 := _t0[i]
		if t0 > t or t0 == INF:
			continue
		match String(a["kind"]):
			"screen":
				var all := String(a["text"]).split("\n")
				var n := clampi(int(floor((t - t0) * _sp[i] / DispatchScript.SCREEN_LINE)) + 1, 1, all.size())
				screen = "\n".join(all.slice(0, n))
				asleep = false
			"session":
				var r := (t - t0) * _sp[i]
				if asleep and r < DispatchScript.WAKE * 0.5:
					continue
				if asleep:
					screen = ""
				asleep = false
				var said := session_text(a, r, whole)
				if not said.is_empty():
					var bare := DispatchScript.PROMPT.strip_edges()
					var last_nl := screen.rfind("\n")
					if screen.substr(last_nl + 1).strip_edges() == bare:
						screen = screen.substr(0, maxi(last_nl, 0))
					screen += ("\n" if not screen.is_empty() else "") + said
				cursor_until = maxf(cursor_until, _end_of(i) + CURSOR_AFTER)
			"type":
				if asleep:
					screen = ""
				asleep = false
				var times: PackedFloat32Array = _chars.get(i, PackedFloat32Array())
				var text := String(a["text"])
				var n := 0
				while n < times.size() and times[n] <= t:
					n += 1
				var shown := text.substr(0, n)
				for k in _actions.size():
					var sa: Dictionary = _actions[k]
					if String(sa["kind"]) == "strike" and int(sa["block"]) == i and _t0[k] <= t:
						var from := _t0[k] + float(sa["decide"]) / _sp[k]
						var back := maxf(_end_of(k) - from, 0.01)
						var gone := int(clampf((t - from) / back, 0.0, 1.0) * float(text.length()))
						shown = shown.substr(0, maxi(shown.length() - gone, 0))
						cursor_until = maxf(cursor_until, _end_of(k) + CURSOR_AFTER)
				screen += ("\n" if not screen.is_empty() else "") + shown
				var end_t := times[times.size() - 1] if not times.is_empty() and times[times.size() - 1] < INF else t
				cursor_until = maxf(cursor_until, maxf(end_t, t0) + CURSOR_AFTER)
			"sleep":
				if t >= t0 + 0.6:
					asleep = true
	var lines := DispatchScript.wrapped(screen, DispatchScript.COLUMNS)
	if lines.size() > DispatchScript.ROWS:
		lines = lines.slice(lines.size() - DispatchScript.ROWS)
	var cursor := t < cursor_until and fposmod(t, BLINK * 2.0) < BLINK
	return {"lines": lines, "asleep": asleep, "cursor": cursor and not asleep}


## A session's transcript [param r] seconds into it (at its own pace): each command's prompt as it comes up, what of it is
## typed, each line of the answer as it is printed, and the bare prompt after the last. [param whole]: a redacted run being
## typed is there to its end from its first key - where the censor's box goes up ([method _censor_at]).
func session_text(a: Dictionary, r: float, whole := false) -> String:
	var plan: Dictionary = a["plan"]
	var steps: Array = a["steps"]
	var out := PackedStringArray()
	for k in steps.size():
		var st: Dictionary = steps[k]
		var sp: Dictionary = (plan["steps"] as Array)[k]
		if bool(st.get("command", true)):
			if r < float(sp["prompt"]):
				return "\n".join(out)
			var keys: PackedFloat32Array = sp["keys"]
			var typed := String(st["typed"])
			var n := 0
			while n < keys.size() and keys[n] <= r:
				n += 1
			while whole and n > 0 and n < typed.length() and DispatchScript.is_redacted(typed.unicode_at(n - 1)) and DispatchScript.is_redacted(typed.unicode_at(n)):
				n += 1
			out.append(DispatchScript.PROMPT + typed.substr(0, n))
		var lines: PackedFloat32Array = sp["lines"]
		var said: PackedStringArray = st["out"]
		for li in lines.size():
			if lines[li] > r:
				return "\n".join(out)
			out.append(said[li])
	if r >= float(plan["prompt"]):
		out.append(DispatchScript.PROMPT)
	return "\n".join(out)

## The target's track on the radar: each ping's place a spot laid out from the script alone ([method track_of]), and a
## leg to it under the voice - from the `moving` mark since the last ping, else over the moments before it ([constant
## LEG_MOST] at most), arriving as it pings; the first found where he is. A live plan's leg without a `moving` never
## begins before the plan knew of its ping.
func _build_track() -> void:
	var stops: Array = []
	var idx: Array = []
	var set_off := -1
	var offs: Array = []
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		match String(a["kind"]):
			"moving":
				if set_off < 0:
					set_off = i
			"ping":
				var words := int(a["after"]) - int((_actions[set_off] as Dictionary)["after"]) if set_off >= 0 else 0
				stops.append({"place": String(a["place"]), "words": words})
				idx.append(i)
				offs.append(set_off)
				set_off = -1
	var spots := track_of(stops)
	_legs = []
	var arrived := -INF
	for k in idx.size():
		var i: int = idx[k]
		var t0 := _t0[i]
		var leave := t0
		if t0 < INF and k > 0:
			var off: int = offs[k]
			if off >= 0 and _t0[off] < t0:
				leave = maxf(_t0[off] + DispatchScript.MOVING * 0.5 / _sp[off], arrived)
			else:
				var known := float(_leg_known.get_or_add(i, _now))
				leave = maxf(maxf(arrived, t0 - LEG_MOST), minf(known, t0))
		_legs.append({"i": i, "place": String((stops[k] as Dictionary)["place"]), "from": spots[maxi(k - 1, 0)],
			"to": spots[k], "t0": leave, "t1": t0})
		if t0 < INF:
			arrived = t0


## Where the target is on the scope at [param t] - between two places on a leg, eased - or Vector2(INF, INF) before the
## radar has found him.
func target_at(t: float) -> Vector2:
	var at := Vector2(INF, INF)
	for leg in _legs:
		var l: Dictionary = leg
		var t0 := float(l["t0"])
		var t1 := float(l["t1"])
		if t0 > t:
			break
		if t >= t1:
			at = l["to"]
			continue
		var u := clampf((t - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0)
		return (l["from"] as Vector2).lerp(l["to"], u * u * (3.0 - 2.0 * u))
	return at


## When the sweep passes the target between [param t0] and [param t1]: once a round, where he is as it comes round.
func passes(t0: float, t1: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if t1 == INF or t0 == INF:
		return out
	for n in range(int(floor(t0 / SWEEP)), int(ceil(t1 / SWEEP)) + 1):
		var p := target_at(float(n) * SWEEP)
		if p.x == INF:
			p = target_at(float(n + 1) * SWEEP)
		if p.x == INF:
			continue
		var swept := (float(n) + fposmod(p.angle() + PI * 0.5, TAU) / TAU) * SWEEP
		if swept >= t0 and swept <= t1 and target_at(swept).x < INF:
			out.append(swept)
	return out


## The radar at [param t]: the sweep's clock; the target as the sweep paints him (where he was as it last passed, the
## paints before it fading behind, a step apart where he is moving), with the place he last came to written beside him and
## its ping's ring; the aircraft drifting across it; the jet, over the middle, while it is heard; with the gain past three,
## the clutter round him ([method clutter_at]).
func radar_at(t: float) -> Dictionary:
	var jet := -1.0
	var jet_len := 1.0
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if _t0[i] > t or _t0[i] == INF:
			continue
		if String(a["kind"]) == "sound" and String(a["sound"]) == "jet" and t < _end_of(i):
			jet = t - _t0[i]
			jet_len = _end_of(i) - _t0[i]
	var st := {"t": t}
	var sweep := fposmod(t / SWEEP, 1.0) * TAU - PI * 0.5
	var now := target_at(t)
	if now.x < INF:
		var swept := t - fposmod(sweep - now.angle(), TAU) / TAU * SWEEP
		var then := target_at(swept)
		if then.x < INF:
			swept = t - fposmod(sweep - then.angle(), TAU) / TAU * SWEEP
		var paints: Array = []
		for k in TRAIL + 1:
			var tk := swept - float(k) * SWEEP
			var pk := target_at(tk)
			if pk.x == INF:
				break
			var n := int(floor(tk / SWEEP))
			pk += Vector2(DispatchSounds.hash01(_seed + 43, n) - 0.5, DispatchSounds.hash01(_seed + 47, n) - 0.5) * 2.0 * PAINT_JITTER
			paints.append(pk)
		var came: Dictionary = {}
		for leg in _legs:
			if float((leg as Dictionary)["t1"]) <= t:
				came = leg
		if not paints.is_empty() and not came.is_empty():
			st["blip"] = {"at": paints[0], "label": String(came["place"]).to_upper(), "since": t - float(came["t1"])}
			st["ping"] = t - float(came["t1"])
			var trail: Array = []
			for k in range(1, paints.size()):
				trail.append({"at": paints[k], "age": float(k), "fade": 1.0 - float(k) / float(TRAIL + 1)})
			st["trail"] = trail
	var planes: Array = []
	var k0 := int(floor((t - PLANE_PASS) / PLANE_EVERY))
	for k in range(maxi(k0, 0), int(floor(t / PLANE_EVERY)) + 1):
		var start := float(k) * PLANE_EVERY + DispatchSounds.hash01(_seed + 31, k) * PLANE_EVERY * 0.5
		var u := (t - start) / PLANE_PASS
		if u < 0.0 or u > 1.0:
			continue
		var ang := DispatchSounds.hash01(_seed + 37, k) * TAU
		var off := (DispatchSounds.hash01(_seed + 41, k) - 0.5) * 1.2
		var d := Vector2.from_angle(ang)
		planes.append({"at": d * lerpf(-1.05, 1.05, u) + d.orthogonal() * off, "heading": ang})
	if jet >= 0.0:
		var u := jet / jet_len
		planes.append({"at": Vector2(lerpf(-1.0, 1.0, u), 0.06), "heading": 0.0})
	st["planes"] = planes
	var clutter := clutter_at(t)
	if not clutter.is_empty():
		st["clutter"] = clutter
	st["t"] = snappedf(t, 1.0 / 30.0)
	return st


## The radar's gain knob at [param t]: where it stands (1 to 10, [constant DispatchScript.GAIN_REST] when the night
## begins), turned steadily from step to step while a `gain:` turns it.
func gain_at(t: float) -> float:
	var level := float(DispatchScript.GAIN_REST)
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "gain" or _t0[i] > t or _t0[i] == INF:
			continue
		var start := _t0[i] + DispatchScript.GAIN_REACH / _sp[i]
		var turn := DispatchScript.gain_turn(int(a["from"]), int(a["to"])) / _sp[i]
		level = lerpf(float(a["from"]), float(a["to"]), clampf((t - start) / maxf(turn, 0.001), 0.0, 1.0))
	return level


## When gain action [param i] turns the knob onto step [param d]: its click.
func _step_at(i: int, d: int) -> float:
	var a: Dictionary = _actions[i]
	var from := int(a["from"])
	var to := int(a["to"])
	var start := _t0[i] + DispatchScript.GAIN_REACH / _sp[i]
	if to == from:
		return start
	return start + DispatchScript.gain_turn(from, to) / _sp[i] * float(d - from) / float(to - from)


## How many clutter blips the scope paints with its gain at [param level]: none at the handbook's three or under, all
## [constant CLUTTER_MOST] at ten.
static func clutter_n(level: int) -> int:
	var u := clampf(float(level - DispatchScript.GAIN_REST) / float(DispatchScript.GAIN_MOST - DispatchScript.GAIN_REST), 0.0, 1.0)
	return roundi(float(CLUTTER_MOST) * pow(u, CLUTTER_CURVE))


## Where the clutter stands round him on desk number [param seed]: offsets on the scope, nearest him first (the rooms of
## one building turned its own way, with him in it off its middle), so each step the knob is turned up paints the next
## nearest. The same every time.
static func clutter_of(seed: int) -> Array:
	var turn := DispatchSounds.hash01(seed + 51, 0) * PI
	var off := (Vector2(DispatchSounds.hash01(seed + 53, 0), DispatchSounds.hash01(seed + 53, 1)) - Vector2(0.5, 0.5)) * CLUTTER_BUILDING * 0.6
	var out: Array = []
	for k in CLUTTER_MOST:
		var p := (Vector2(DispatchSounds.hash01(seed + 55, k), DispatchSounds.hash01(seed + 57, k)) - Vector2(0.5, 0.5)) * CLUTTER_BUILDING
		var at := (p + off).rotated(turn)
		if at.length() < CLUTTER_NEAR:
			at = (at if at.length() > 1e-4 else Vector2.RIGHT).normalized() * CLUTTER_NEAR
		out.append(at)
	out.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.length() < y.length())
	return out


## The clutter on the scope at [param t]: `[{at, fade, chair?}]` - each blip the gain reaches, round where the target was
## when the knob was turned up past three, and from [constant CHAIR_GAIN] the chair's own at the desk ([constant CHAIR_AT],
## `chair: true`); each painted once the sweep has passed it since the knob reached it and a little off where it was each
## round (the few who move drift); a blip the knob no longer reaches fades over a sweep or two and is never painted again.
func clutter_at(t: float) -> Array:
	const CHAIR := -1                    # the chair's key among the blips
	var on := {}                         # a blip -> when the knob reached it
	var off := {}                        # ...and when it no longer did
	var mid := Vector2.ZERO
	var n := 0
	var seated := false                  # the chair painted at the knob's last step
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "gain" or _t0[i] > t or _t0[i] == INF:
			continue
		var from := int(a["from"])
		var to := int(a["to"])
		if n == 0 and clutter_n(to) > 0:
			var here := target_at(_t0[i])
			mid = here if here.x < INF else Vector2.ZERO
		var d := from
		while d != to:
			d += signi(to - from)
			var at := _step_at(i, d)
			if at > t:
				break
			var m := clutter_n(d)
			for k in range(n, m):
				on[k] = at
				off.erase(k)
			for k in range(m, n):
				off[k] = at
			n = m
			if (d >= CHAIR_GAIN) != seated:
				seated = d >= CHAIR_GAIN
				if seated:
					on[CHAIR] = at
					off.erase(CHAIR)
				else:
					off[CHAIR] = at
	var out: Array = []
	var sweep := fposmod(t / SWEEP, 1.0) * TAU - PI * 0.5
	for key in on:
		var k := int(key)
		var fade := 1.0 - clampf((t - float(off[k])) / CLUTTER_FADE, 0.0, 1.0) if off.has(k) else 1.0
		if fade <= 0.0:
			continue
		var at: Vector2 = CHAIR_AT if k == CHAIR else mid + (_clutter[k] as Vector2)
		if k % CLUTTER_MOVING == 1:
			var w := TAU / lerpf(50.0, 110.0, DispatchSounds.hash01(_seed + 63, k))
			at += Vector2(sin(t * w + DispatchSounds.hash01(_seed + 65, k) * TAU), sin(t * w * 0.7 + DispatchSounds.hash01(_seed + 67, k) * TAU)) * CLUTTER_DRIFT
		var swept := t - fposmod(sweep - at.angle(), TAU) / TAU * SWEEP
		if swept < float(on[k]):
			continue
		var rnd := int(floor(swept / SWEEP)) * CLUTTER_MOST + maxi(k, 0)
		var s := _seed + (73 if k == CHAIR else 69)
		at += (Vector2(DispatchSounds.hash01(s, rnd), DispatchSounds.hash01(s + 2, rnd)) - Vector2(0.5, 0.5)) * 2.0 * CLUTTER_JITTER
		var blip := {"at": at, "fade": fade}
		if k == CHAIR:
			blip["chair"] = true
		out.append(blip)
	return out


## When bell [param i] sounds: as the block after it goes up, when one follows in the same silence - a shown block as its
## first line is drawn, a session as it first prompts or prints, a typed one at its first key; else in its own half beat.
func _bell_at(i: int) -> float:
	var own := _t0[i] + DispatchScript.BELL * 0.5 / _sp[i]
	var k := i + 1
	if k >= _actions.size() or _t0[k] == INF or int((_actions[k] as Dictionary)["after"]) != int((_actions[i] as Dictionary)["after"]):
		return own
	var b: Dictionary = _actions[k]
	match String(b["kind"]):
		"screen":
			return _t0[k]
		"session":
			var first: Dictionary = (b["plan"]["steps"] as Array)[0]
			var lines: PackedFloat32Array = first["lines"]
			var at := float(first["prompt"]) if float(first["prompt"]) >= 0.0 else (lines[0] if not lines.is_empty() else 0.0)
			return _t0[k] + at / _sp[k]
		"type":
			var keys: PackedFloat32Array = _chars.get(k, PackedFloat32Array())
			return keys[0] if not keys.is_empty() and keys[0] < INF else _t0[k]
	return own


## The lamp at [param t]: how lit (0 to 1) - on until a `lamp: off`, its filament's glow dying fast from the click and gone
## in [constant LAMP_FADE]; a `lamp: on` brings it up as quickly.
func lamp_at(t: float) -> float:
	var lit := 1.0
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "lamp" or _t0[i] == INF:
			continue
		var at := _t0[i] + DispatchScript.LAMP_AT / _sp[i]
		if at > t:
			continue
		var u := clampf((t - at) / LAMP_FADE, 0.0, 1.0)
		lit = lerpf(lit, 1.0 if bool(a["on"]) else 0.0, 1.0 - (1.0 - u) * (1.0 - u))
	return lit


## What this medium shows as pictures ([method Medium.pictures_of], the note's Pictures card): every picture the script
## puts on a screen or over the frame, each painted as a whole screen's - a `live:` screen is this desk, never painted.
static func pictures_in(body: String) -> Array:
	return Manuscript.images(DispatchScript.pictures_only(body))


## Where each ping's place is on the scope (its middle the desk, its edge 1), from the script alone - [param stops]
## `[{place, words}]` in order: the first its own spot ([method place_on_scope]); each after it a step on from the last,
## as long as the walk the script gives it ([constant TRACK_PACE] a second, [constant WALK_WORD] seconds a word said
## between its `moving` and its ping; [constant STEP_BARE] for a ping with none), turning at most [constant TURN_MOST]
## from the way he was going (a compass word sets the way: north is up); then the whole track centered on the scope, made
## smaller only if it would run off it. A place named before is that same spot, and one whose head (before a comma) was
## named is a little off it. Nothing is to scale.
static func track_of(stops: Array) -> Array:
	var out: Array = []
	var seen := {}
	var way := 0.0
	for k in stops.size():
		var place := String((stops[k] as Dictionary)["place"]).strip_edges()
		var key := place.to_lower()
		var head := key.get_slice(",", 0).strip_edges()
		var at: Vector2
		if seen.has(key):
			at = seen[key]
		elif key != head and seen.has(head):
			at = (seen[head] as Vector2) + Vector2.from_angle(DispatchSounds.hash01(key.hash(), 3) * TAU) * STEP_OFF
		elif out.is_empty():
			at = place_on_scope(place)
			way = DispatchSounds.hash01(key.hash(), 4) * TAU
		else:
			var prev: Vector2 = out.back()
			var words := int((stops[k] as Dictionary).get("words", 0))
			var step := clampf(float(words) * WALK_WORD * TRACK_PACE, STEP_LEAST, STEP_MOST) if words > 0 else STEP_BARE
			var compass := compass_of(key)
			way = compass if not is_nan(compass) else way + (DispatchSounds.hash01(key.hash(), 5) - 0.5) * 2.0 * TURN_MOST
			at = prev + Vector2.from_angle(way) * step
		if not out.is_empty() and ((out.back() as Vector2) - at).length() > 1e-4:
			way = (at - (out.back() as Vector2)).angle()
		if not seen.has(key):
			seen[key] = at
		if not seen.has(head):
			seen[head] = at
		out.append(at)
	# the whole track on the scope: its middle at the scope's, made smaller only where it would run off, keeping its shape
	# and its compass
	if out.is_empty():
		return out
	var box := Rect2(out[0], Vector2.ZERO)
	for p in out:
		box = box.expand(p)
	var mid := box.get_center()
	var reach := 0.0
	for p in out:
		reach = maxf(reach, ((p as Vector2) - mid).length())
	var fit := minf(1.0, TRACK_EDGE / reach) if reach > 0.0 else 1.0
	for k in out.size():
		out[k] = ((out[k] as Vector2) - mid) * fit
	return out


## The way a compass word in [param words] points on the scope (radians, north up), NAN for none.
static func compass_of(words: String) -> float:
	for w in words.to_lower().split(" ", false):
		match w.strip_edges().trim_suffix(","):
			"north", "northward", "northbound":
				return -PI * 0.5
			"south", "southward", "southbound":
				return PI * 0.5
			"east", "eastward", "eastbound":
				return 0.0
			"west", "westward", "westbound":
				return PI
	return NAN


## Where a place is on the scope (its middle the desk, its edge 1): from the place's words, the same every time - its first
## clause the spot, what follows a little off it. Nothing is to scale.
static func place_on_scope(place: String) -> Vector2:
	var head := place.get_slice(",", 0).strip_edges().to_lower()
	var a := DispatchSounds.hash01(head.hash(), 1) * TAU
	var r := lerpf(0.22, 0.82, DispatchSounds.hash01(head.hash(), 2))
	var at := Vector2.from_angle(a) * r
	if place.contains(","):
		var tail := place.get_slice(",", 1).strip_edges().to_lower()
		at += Vector2.from_angle(DispatchSounds.hash01(tail.hash(), 3) * TAU) * 0.06
	return at


## The receiver at [param t]: the storm it is open on, `{storm, level}` - {} for none.
func storm_at(t: float) -> Dictionary:
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) == "static" and _t0[i] <= t and t < _end_of(i):
			var span := _end_of(i) - _t0[i]
			return {"storm": String(a["storm"]), "level": DispatchSounds.storm_level(String(a["storm"]), t - _t0[i], hash([_seed, i]), span)}
	return {}


## The printer at [param t]: its head going across while it prints, the paper's lines - every print's lines so far, the one
## printing a character at a time - and the paper fed.
func _pose_printer(t: float) -> void:
	var lines := PackedStringArray()
	var partial := ""
	var feed := 0.0
	var head := 0.0
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "print" or _t0[i] > t or _t0[i] == INF:
			continue
		var pl: PackedStringArray = a["lines"]
		var u := (t - _t0[i]) * _sp[i] - DispatchScript.PRINT_LEAD
		if u >= float(pl.size()) * DispatchScript.PRINT_LINE:
			lines.append_array(pl)
			lines.append("")
			continue
		var k := int(floor(maxf(u, 0.0) / DispatchScript.PRINT_LINE))
		var w := fposmod(maxf(u, 0.0), DispatchScript.PRINT_LINE) / DispatchScript.PRINT_LINE
		for j in mini(k, pl.size()):
			lines.append(pl[j])
		if u >= 0.0 and k < pl.size():
			var across := clampf(w / 0.82, 0.0, 1.0)
			var line := String(pl[k])
			partial = line.substr(0, int(across * float(line.length()))) if k % 2 == 0 else line.substr(line.length() - int(across * float(line.length())))
			if k % 2 == 1:
				partial = " ".repeat(line.length() - partial.length()) + partial
			head = (across if k % 2 == 0 else 1.0 - across) - 0.5
			feed = clampf((w - 0.82) / 0.18, 0.0, 1.0)
	_screens.show_paper({"lines": lines, "partial": partial, "feed": snappedf(feed, 0.05), "total": lines.size()})
	_set.printer_head.position.x = head * 0.3


## The three screens at [param t]: each the last picture pinned to it (or this desk, live), or dark after an `off`; the feed
## snowy with nothing on it.
func _pose_screens(t: float) -> void:
	var live := false
	for k in _set.screens:
		var key := String(k)
		var shown := ""
		var since := INF
		for i in _actions.size():
			var a: Dictionary = _actions[i]
			if _t0[i] > t or _t0[i] == INF or String(a.get("screen", "")) != key:
				continue
			match String(a["kind"]):
				"picture":
					shown = String(a["key"])
					since = t - _t0[i]
				"live":
					shown = "live"
					since = t - _t0[i]
				"off":
					shown = ""
					since = -(t - _t0[i])
		var m: ShaderMaterial = _mats[key]
		var glow: OmniLight3D = (_set.screens[k] as Dictionary)["glow"]
		var power := 1.0
		var tex: Texture2D = null
		if shown == "live":
			tex = _live_vp.get_texture()
			live = true
		elif not shown.is_empty():
			tex = _pictures.get(shown)
		if since < 0.0:
			power = clampf(1.0 + since / 0.5, 0.0, 1.0)
		elif since < INF:
			power = clampf(since / 0.35, 0.0, 1.0)
		if key == "feed" and tex == null:
			m.set_shader_parameter("snow", 0.85)
			m.set_shader_parameter("has_face", false)
			m.set_shader_parameter("power", 1.0)
			m.set_shader_parameter("brightness", 0.5)
			m.set_shader_parameter("frame", floor(t * 24.0))
			glow.light_energy = 0.32 + 0.06 * sin(t * 17.0) * sin(t * 5.3)
			continue
		if key == "feed":
			m.set_shader_parameter("snow", 0.12)
			m.set_shader_parameter("brightness", 1.4)
			m.set_shader_parameter("frame", floor(t * 24.0))
		m.set_shader_parameter("has_face", tex != null)
		if tex != null:
			m.set_shader_parameter("face", tex)
		m.set_shader_parameter("power", power if (tex != null or since < 0.0) else 0.0)
		glow.light_energy = 0.35 * power if tex != null else 0.0
	_live_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
	if live and _live_cam != null:
		_live_cam.look_at_from_position(LIVE_EYE, LIVE_AIM, Vector3.UP)


## The switch at [param t]: up (GOOD) until it is thrown, each throw at its moment.
func _pose_switch(t: float) -> void:
	var side := "GOOD"
	var u := 1.0
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "switch" or _t0[i] > t or _t0[i] == INF:
			continue
		var at := _t0[i] + DispatchScript.SWITCH_AT / _sp[i]
		var was := side
		side = String(a["side"])
		u = clampf((t - at) / 0.08, 0.0, 1.0) if t < at + 0.08 else 1.0
		if t < at:
			side = was
			u = 1.0
	var up := 28.0
	var want := -up if side == "GOOD" else up
	_set.lever.rotation_degrees = Vector3(want, 0, 0) if u >= 1.0 else Vector3(lerpf(-want, want, u), 0, 0)


## The mug at [param t]: in its ring, or drunk from: lifted upright out of its ring and brought to the mouth, just under
## the eye and out of the picture past its lower edge, held there for the sip, and set back down in its ring. It never
## tips where it is seen.
func _pose_mug(t: float) -> void:
	var xf := _set.mug_home
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "lift" or _t0[i] > t or _t0[i] == INF or t > _end_of(i):
			continue
		var u := (t - _t0[i]) * _sp[i]
		# the mouth, under the eye wherever it is now (it leans and breathes), the mug upright and turned as it stood
		var held := Transform3D(_set.mug_home.basis, _cam.global_transform * MUG_MOUTH)
		var k := 0.0
		if u < DispatchScript.LIFT_UP:
			k = _jerkless(u / DispatchScript.LIFT_UP)
		elif u < DispatchScript.LIFT_UP + DispatchScript.LIFT_HOLD:
			k = 1.0
		else:
			k = 1.0 - _jerkless((u - DispatchScript.LIFT_UP - DispatchScript.LIFT_HOLD) / DispatchScript.LIFT_DOWN)
		xf = _arc(_set.mug_home, held, k, MUG_CLEAR)
	_set.mug.global_transform = xf


## The redacted words on the terminal at [param t], hidden over this frame where the camera sees them ([DispatchCensor]):
## a run being typed is covered to its end from its first key, as an editor's box goes up when a name begins to appear
## (unless finishing it would wrap or scroll the screen: then as it stands).
func _censor_at(t: float) -> void:
	var shown := terminal_at(t)
	var runs: Array = []
	if not bool(shown["asleep"]):
		var lines: PackedStringArray = shown["lines"]
		runs = _screens.redactions(lines)
		if not runs.is_empty():
			var whole: PackedStringArray = terminal_at(t, true)["lines"]
			if whole.size() == lines.size() and whole[0] == lines[0]:
				runs = _screens.redactions(whole)
	_censor.cover(runs, _set.terminal_screen, float(TERMINAL_GLASS["curve"]), _cam, t)
	_after_censor.visible = _censor.visible and _blur.visible


# --- the camera --------------------------------------------------------------------------------------------------------

## What the camera looks at, at [param t]: the latest thing begun that still holds it; with none, what it looked at last,
## until [constant HOME_AFTER] has gone by, then the whole desk.
func _attention(t: float) -> Dictionary:
	var best := {}
	var last_end := -INF
	var last := {}
	var linger := HOME_AFTER
	for e in _attn:
		var d: Dictionary = e
		if float(d["t0"]) > t:
			break
		if t < float(d["t1"]):
			best = d["spot"]
		elif float(d["t1"]) > last_end:
			last_end = float(d["t1"])
			last = d["spot"]
			linger = float(d.get("linger", HOME_AFTER))
	if not best.is_empty():
		return best
	if not last.is_empty() and t - last_end < linger:
		return last
	return _spot("home")


func _tick_camera(delta: float) -> void:
	var want := _attention(_now)
	var aim: Vector3 = want["aim"]
	var eye: Vector3 = want["eye"]
	var fov := float(want["fov"])
	var w := Vector3(sin(_now * WANDER_RATE * TAU + 1.3) * WANDER.x, sin(_now * WANDER_RATE * 0.77 * TAU) * WANDER.y,
		sin(_now * WANDER_RATE * 0.53 * TAU + 2.1) * WANDER.z)
	aim += w
	if _snap:
		_c_aim = aim
		_c_eye = eye
		_c_fov = fov
		_v_aim = Vector3.ZERO
		_v_eye = Vector3.ZERO
		_v_fov = 0.0
		_snap = false
	else:
		var dt := clampf(delta, 0.0, 0.1)
		var steps := maxi(1, ceili(dt / 0.02))
		var h := dt / float(steps)
		for _s in steps:
			var k := h / (SPRING_TAU * SPRING_TAU)
			var c := 2.0 * h / SPRING_TAU
			_v_aim += (aim - _c_aim) * k - _v_aim * c
			_c_aim += _v_aim * h
			_v_eye += (eye - _c_eye) * k - _v_eye * c
			_c_eye += _v_eye * h
			_v_fov += (fov - _c_fov) * k - _v_fov * c
			_c_fov += _v_fov * h
	_cam.fov = _c_fov
	_cam.look_at_from_position(_c_eye, _c_aim, Vector3.UP)


# --- the pictures over the whole screen ---------------------------------------------------------------------------------

## The pictures up now over the desk: each faded in after the word before its passage, dissolving into the next or out after
## its passage's last word, moving its own way ([constant LetterMedium.MOVES]).
func _show_pictures() -> void:
	var layers: Array = []
	var shown: Array = []
	for s in _spans:
		var sp: Dictionary = s
		if _pictures.has(String(sp["key"])) and int(sp["to"]) > int(sp["from"]):
			shown.append(sp)
	for i in shown.size():
		var sp: Dictionary = shown[i]
		var from := int(sp["from"])
		var to := int(sp["to"])
		var nxt: Dictionary = shown[i + 1] if i + 1 < shown.size() else {}
		var under := not nxt.is_empty() and bool(nxt.get("blend", false)) and int(nxt["from"]) == to
		var t0 := (_word_t1(from - 1) + 0.1) if from > 0 else _word_t0(from) - IMAGE_FADE
		var t1 := ((_word_t1(int(nxt["from"]) - 1) + 0.1) if under else _word_t1(to - 1) + 0.1)
		if t0 == INF or _now < t0 or (t1 < INF and _now > t1 + IMAGE_FADE):
			continue
		var a := clampf((_now - t0) / IMAGE_FADE, 0.0, 1.0)
		if not under and t1 < INF:
			a = minf(a, 1.0 - clampf((_now - t1) / IMAGE_FADE, 0.0, 1.0))
		var u := clampf((_now - t0) / maxf(float(to - from) * DeskScript.SAID_WORD + IMAGE_FADE * 2.0, 1.0), 0.0, 1.0)
		var mv: Dictionary = sp.get("move", {"grow": Vector2(1.04, 1.16), "way": Vector2.RIGHT, "drift": 0.5})
		var grow: Vector2 = mv["grow"]
		var tex: Texture2D = _pictures[String(sp["key"])]
		layers.append({"tex": tex, "alpha": a * a * (3.0 - 2.0 * a), "grow": lerpf(grow.x, grow.y, u),
			"drift": (mv["way"] as Vector2) * lerpf(-float(mv["drift"]), float(mv["drift"]), u)})
	if layers != _plate.layers:
		_plate.layers = layers
		_plate.queue_redraw()


# --- for a gate --------------------------------------------------------------------------------------------------------

## Where phone [param label] IS at [param t] in its moves: "row", "ear", "desk" or "moving".
func phone_at(label: String, t: float) -> String:
	var mv := {}
	for m in _phone_moves:
		if String((m as Dictionary)["label"]) == label and float(m["t0"]) <= t:
			mv = m
	if mv.is_empty():
		return "row"
	return String(mv["to"]) if t >= float(mv["t0"]) + float(mv["dur"]) else "moving"


## What the camera turns to at [param t]: the key of [member DispatchSet.spots] its aim is, or "phone" for a phone's own.
func looking_at(t: float) -> String:
	var want := _attention(t)
	for k in _set.spots:
		if (_set.spots[k] as Dictionary)["aim"] == want["aim"]:
			return String(k)
	return "phone"


## Each action's placed start (INF until it is).
func starts() -> PackedFloat32Array:
	return _t0
