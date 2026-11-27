extends Medium
class_name StudioMedium

## StudioMedium - a table show's episode played as raw footage from a creator's chair (next/studio.md): the camera in the middle of the frame
## looks back at the viewer from inside its ring light, its flip screen turned toward them showing what it sees - nobody, only the
## things the hands work, from the other side; a giant fluffy microphone between, low in the frame; the things moved by hands
## nobody sees. THE SOUND IS THE SHOW: every sound a thing makes is made by the motion that makes it, heard from where it happens
## round the microphone ([StudioActs], [StudioSounds]).
##
## One of Table's formats ([constant Medium.REGISTRY] `mode`): Table's agents make each episode from the note's brief, the reader writing
## the hands' acts among its words ([method reader_marks], [method reader_rules]) and the voice resting for each act ([method voiced]);
## the studio sets itself, its things the note's makes ([StudioProps]). Draws from the reading's document: its `source`, the episode's script with its act marks
## ([StudioScript]), and its `medium`, the Medium block (`takes`: each act made again, [method StudioScript.with_takes]; `makes`: the
## make playing each thing - a kept make with the version used, so another version used stands at once - and `places`: where each is
## moved from where the studio stands it, [StudioProps]) and its `environment`, the Environment card's (each lit thing's share of its
## light). The set ([StudioSet], stood again when a make changes) and the acts' motions ([method
## StudioActs.make]) are made on workers; each act is placed in the rest the voice leaves for it
## ([method ReadingFollower.place]; one said `under` begins as the words after it do) and, once begun, kept where it began. Then
## everything is a pure function of show time ([method _pose]): the things' places, the windscreen pressed where a hand touches
## it, the camera and the microphone swaying from a tap, the flip screen's picture and its meters, and the sound - so a render
## draws and hears what the live reading did, and a scrub lands where the reading is.
##
## The viewer's eye is the creator's head, performed from the show's phrases ([HeadBank], [HeadMarks], next/head.md) - leaning in at
## an ear, turning away, looking along the windscreen - from the same performance the voice is heard from, so a voice at the left ear
## is seen from there; a show with no phrases sits in the chair. Either way it sways as the Camera card's chair has it ([constant Cameras.REGISTRY] `creator`, its
## Sway: [method Cameras.swayed]). The subtitles caption the speech.

## An act placed before the next words by at least this much (s), and one said `under` begun this much before its words.
const TAIL := 0.3
## A hand's fingertips on the windscreen: how far apart (m), and where each was a moment ago - how long ago (s) and how much of its
## press is left there.
const FINGER := 0.016
const TRAIL := [[0.0, 1.0], [0.1, 0.55], [0.2, 0.3]]
## How far past the show an act that goes on is made before it is made longer (s), and in what steps.
const HORIZON_SPARE := 20.0
const HORIZON_STEP := 30.0
const UNDER_LEAD := 0.15
## How long the studio fades up from black (s), and how long before an act the show is held for its sound.
const FADE_UP := 1.2
const WAIT_AHEAD := 0.3
## Who the show's clock is held for ([method ShowFeed.wait_for]).
const WAIT_FOR := "the studio's sounds"
## The hands' sound a reader is asked for (s): in the intro (a level check, a first stroke) and the close (going on past the last
## word); and the least and most share of a beat's time that is sound, not words ([method sound_seconds]).
const INTRO_SOUND := 25
const CLOSE_SOUND := 45
const SOUND_SHARE := Vector2(0.5, 0.8)
## How much of a passage's talk the hands go on under.
const UNDER_SHARE := 0.85

var _subs = null
var _doc_key := ""
var _source := ""
var _parsed := {}
var _acts: Array = []
var _made: Array = []                   # each act's motion ([method StudioActs.make]), null until made
var _keys: Array = []                   # each act's sound's windows' keys ([method StudioSounds.make_all])
var _starts: Array = []                 # ...and where each window begins in the act (s)
var _specs := {}                        # every window handed to the sounds
var _horizon := {}                      # an act that goes on -> how long its motion is made (s), or being made
var _t0 := PackedFloat32Array()         # each act's start (INF until placed)
var _t1 := PackedFloat32Array()         # each act's end (INF until known: the word it ends at not yet heard)
var _held := {}                         # an act begun -> its start, kept
var _follower := ReadingFollower.new()
var _built_n := -1
var _spoken_n := 0
var _midway := false
var _now := 0.0
var _last_now := -1.0
var _seed := 1
var _set := {}
var _bases := {}                        # each thing's place as set (the camera's and the microphone's, which a tap sways)
var _build_task := -1
var _build_box := {}
var _make_task := -1
var _make_box := {}
var _make_for := ""                     # the source and takes the acts being made are of
var _marks := {}                        # each act's words as a Refine changed them ([method marks_of])
var _takes := {}                        # each act made again: its own number -> its take ([method StudioScript.with_takes])
var _root3: Node3D
var _cam: Camera3D
var _env: Environment
var _attrs: CameraAttributesPractical
var _screen: StudioScreen
var _sounds := StudioSounds.new()
var _placeholder: GhostScene
var _title: TitleCard
var _blur: IntroBlur
var _stage_was := {}
var _said := ""
var _waiting := false                   # the show held for an act's sound
var _set_for := "-"                     # the makes and places the set stands with (or is being stood with), as JSON
var _head_feel := ""                    # the Reach, Turns and Pace the head was performed with, as JSON
var _surround := Surroundings.sanitize({})  # the Environment card's block: each lit thing's share of its light
var _surround_key := ""
var _head := {}                         # the head's performance ([HeadPlan]), {} where the show has no phrases: the eye sits in the chair
var _look := FreeLook.new()             # the eye as a person looking the paused show over turned it ([method look_by])
var _rendering := not Engine.get_write_movie_path().is_empty()   # a render sees only the show's own eye


# --- for the agents who make an episode for it (asked by path: [TableProducer], [EpisodeWalk]) ---------------------------------

## [param text] (an episode's script) as its voice reads it: the voice talks over the hands, save an act said `alone` - a quiet rest
## as long as it, where it is written ([constant CardReading.QUIET_MARK]).
static func voiced(text: String, _doc: Dictionary = {}) -> String:
	var mark := RegEx.create_from_string(StudioScript.MARK)
	var out := ""
	var at := 0
	for m in mark.search_all(text):
		out += text.substr(at, m.get_end() - at)
		at = m.get_end()
		var act := StudioScript.act_of(m.get_string(1), m.get_string(2), [])
		if not bool(act["under"]):
			out += " <!-- quiet: %s -->" % String.num(float(act["secs"]) + StudioScript.AFTER, 2)
	return out + text.substr(at)


## The marks a reader may write in its passages here: the hands' acts and where they end ([constant StudioScript.EITHER]) and the
## head's phrases it calls ([constant HeadMarks.MARK]).
static func reader_marks() -> String:
	return "(?:%s)|(?:%s)" % [StudioScript.EITHER, HeadMarks.MARK]


## What the reader is told of them: rules/table/studio.yaml, with every word an act's mark may use, from [StudioActs]' rows - and,
## from [param told] ([method TableProducer._own_work_of]), its passage's planned work and about how long its sound runs
## ([method sound_seconds]).
static func reader_rules(told: Dictionary = {}) -> String:
	var planned := String(told.get("work", "")).strip_edges()
	return Rules.say("table/studio.reader", {"vocabulary": StudioActs.vocabulary(), "work": not planned.is_empty(),
		"planned": planned, "seconds": sound_seconds(told), "phrases": _phrases_told(String(told.get("show", ""))), "has_phrases": not _phrases_told(String(told.get("show", ""))).is_empty()})


## The show's head phrases as the reader is told them, a line each ([HeadBank]); "" for a show with none yet.
static func _phrases_told(show: String) -> String:
	var out := PackedStringArray()
	for p in HeadBank.read(show):
		out.append("- %s: %s" % [String((p as Dictionary)["name"]), String((p as Dictionary)["line"])])
	return "\n".join(out)


## What is wrong with the marks in passage [param text] ([param told] as [method reader_rules] has it), "" for nothing: a word a mark
## does not know, a closing mark that ends nothing, and far less of the hands' sound than the passage was asked for (an act that goes
## on counted for as long as a steady voice takes to reach where it ends) - the reader is asked once more, told this.
static func reader_check(text: String, told: Dictionary = {}) -> String:
	var faults := PackedStringArray()
	var d := StudioScript.parse(text)
	var odd := PackedStringArray()
	for u in d["unknown"]:
		odd.append("\"%s\"" % String((u as Array)[1]))
	for n in HeadMarks.unknown(text, HeadBank.read(String(told.get("show", "")))):
		odd.append("\"%s\" (no phrase of the head is called that)" % n)
	if not odd.is_empty():
		faults.append("these words are in no list a mark may use: %s" % ", ".join(odd))
	var stray: PackedStringArray = d.get("stray", PackedStringArray())
	if not stray.is_empty():
		faults.append("these closing marks end nothing open: %s" % ", ".join(Array(stray).map(func(v: String) -> String: return "<!-- %s -->" % v)))
	var asked := sound_seconds(told)
	if not String(told.get("work", "")).strip_edges().is_empty() and asked > 0:
		var made := 0.0
		var lengths := StudioScript.lengths(d)
		for a in d["acts"]:
			made += float(lengths.get(int((a as Dictionary)["i"]), float((a as Dictionary)["secs"])))
		if made < float(asked) * 0.5:
			faults.append("its marks give the hands %d seconds of sound where about %d were asked for" % [roundi(made), asked])
	return "; ".join(faults)


## About how many seconds of the hands' sound a passage's marks take ([param told] as [method reader_rules] has it): the intro's
## and the close's their own; a beat's most of its talk ([constant UNDER_SHARE]: the hands go on under the words), and what the
## episode's share with no words ([constant SOUND_SHARE], the plan's `quiet` where it asks for more) gives beside them where the
## plan asks for quiet.
static func sound_seconds(told: Dictionary) -> int:
	match String(told.get("beat", "")):
		"intro":
			return INTRO_SOUND
		"close":
			return CLOSE_SOUND
	var words: Vector2i = told.get("words", Vector2i(60, 90)) if told.get("words") is Vector2i else Vector2i(60, 90)
	var talk := float(words.x + words.y) * 0.5 * float(told.get("said_word", TablePrompts.SAID_WORD))
	var quiet := float(told.get("quiet", 0.0))
	var alone := talk * quiet / maxf(1.0 - quiet, 0.2) if quiet > SOUND_SHARE.x else 0.0
	return roundi((talk * UNDER_SHARE + alone) / 5.0) * 5


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
	_build_world()
	_blur = IntroBlur.new(ShowOpening.INTRO_SHADER)
	add_child(_blur)
	_title = TitleCard.new()
	_title.face = CardTable.font("roman")
	_title.italic = CardTable.font(CardTable.BOOK_ITALIC)
	_title.ink = Color(0.93, 0.9, 0.86)
	add_child(_title)


func _build_world() -> void:
	_root3 = Node3D.new()
	_root3.name = "StudioWorld"
	add_child(_root3)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.0, 0.0, 0.0)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = StudioSet.AMBIENT
	_env.ambient_light_energy = 1.0
	Tonemaps.dress(_env, 1.0)
	_env.adjustment_enabled = true
	Graphics.dress(_env)
	_cam = Camera3D.new()
	_cam.fov = StudioSet.VFOV
	_cam.near = 0.02
	_cam.far = 30.0
	_cam.environment = _env
	_attrs = CameraAttributesPractical.new()
	_attrs.dof_blur_far_enabled = false
	_cam.attributes = _attrs
	_root3.add_child(_cam)
	_cam.transform = Transform3D(Basis.looking_at(StudioSet.LOOK - StudioSet.EYE, Vector3.UP), StudioSet.EYE)
	_cam.current = true


## The set stood on a worker with the makes [param makes] and the places [param places] ([method StudioSet.build]) where it stands with
## others: once one being stood is landed, it is looked at again.
func _restand(makes: Dictionary, places := {}) -> void:
	var key := JSON.stringify([makes, places])
	if key == _set_for or _build_task >= 0:
		return
	_set_for = key
	_build_box = {}
	var box := _build_box
	var seed := _seed
	var m := makes.duplicate(true)
	var pl := places.duplicate(true)
	_build_task = WorkerThreadPool.add_task(func() -> void: box["set"] = StudioSet.build(seed, m, pl))


## The set, once the worker has made it: put in the world in place of the one before, its flip screen built.
func _land_set() -> void:
	if _build_task < 0 or not WorkerThreadPool.is_task_completed(_build_task):
		return
	WorkerThreadPool.wait_for_task_completion(_build_task)
	_build_task = -1
	var got: Dictionary = _build_box.get("set", {})
	if got.is_empty():
		return
	if not _set.is_empty():
		(_set["root"] as Node).queue_free()
		_bases = {}
	if _screen != null:
		_screen.release()
		_screen.queue_free()
		_screen = null
	_set = got
	_root3.add_child(_set["root"])
	var rigs: Dictionary = _set["rigs"]
	for k in ["camera", "microphone", "tripod"]:
		if rigs.has(k):
			_bases[k] = (rigs[k] as PropRig).node.transform
	_screen = StudioScreen.new()
	add_child(_screen)
	var geo: Dictionary = _set["geo"]
	_screen.mount(self, stage.find_world_3d() if stage != null else _root3.get_world_3d(), _lens_xf(), _env)
	if rigs.has("camera"):
		var face := (rigs["camera"] as PropRig).face("screen")
		if face != null:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_texture = _screen.texture()
			face.material_override = mat
	_shine_things()
	# the acts are made again for this set, and the head's gazes aimed at its things
	_make_for = ""
	_built_n = -1


## Each thing that throws light at its share of it, as the Environment card has it ([method Surroundings.share_of], by its role).
func _shine_things() -> void:
	var rigs: Dictionary = _set.get("rigs", {})
	for k in rigs:
		var role := "block" if String(k).begins_with("block") else String(k)
		(rigs[k] as PropRig).set_light_scale(Surroundings.share_of(_surround, role))


## Where the lens is and which way it looks (+z out of the glass), as the camera stands now.
func _lens_xf() -> Transform3D:
	var rigs: Dictionary = _set.get("rigs", {})
	var geo: Dictionary = _set.get("geo", {})
	if not rigs.has("camera"):
		return Transform3D(Basis.IDENTITY, StudioSet.LENS)
	var cam: PropRig = rigs["camera"]
	var at: Vector3 = geo.get("lens", StudioSet.LENS)
	var local := cam.node.transform.affine_inverse() * at
	return Transform3D(cam.node.transform.basis, cam.node.transform * local)


func begin_session() -> void:
	_seed = feed.session_seed()


func release() -> void:
	if _waiting:
		_waiting = false
		feed.wait_for(WAIT_FOR, false)
	_subs = null
	_doc_key = ""
	_sounds.stop()
	if _screen != null:
		_screen.release()
	for task in [_build_task, _make_task]:
		if int(task) >= 0:
			WorkerThreadPool.wait_for_task_completion(int(task))
	_build_task = -1
	_make_task = -1


func _exit_tree() -> void:
	_sounds.stop()
	if stage != null and is_instance_valid(stage) and not _stage_was.is_empty():
		for key in _stage_was:
			stage.set(key, _stage_was[key])


# --- the Medium contract -------------------------------------------------------------------------------------------------

func owns_cast() -> bool:
	return true


func take_over(_outgoing: GhostScene) -> GhostScene:
	return _placeholder


func owns_bookend() -> bool:
	return true


## The eye turned [param yaw] and tipped [param pitch] radians about what it looks at, drawn to [param reach] times as far, while the show
## is paused ([StageLook], [method Director.look_by]); it eases back once the show plays ([FreeLook]). Never in a render.
func look_by(yaw: float, pitch: float, reach := 1.0) -> void:
	if not _rendering:
		_look.look_by(yaw, pitch, reach)


## The words stay the overlay's to show: what is said is captioned.
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
	_land_set()
	_ensure_doc()
	_take_made()
	_now = _subs.now() if _subs != null and is_instance_valid(_subs) else t
	if _now < _last_now - 1.0:
		_held = {}
		_built_n = -1
	_last_now = _now
	# (followed whether or not the script has acts: the title stands until the first word is heard)
	if _subs != null and is_instance_valid(_subs):
		take_words(_subs.words)
	_env.adjustment_brightness = clampf(clampf(t / FADE_UP, 0.0, 1.0) * _end_fade() * feed.live_fade, 0.0, 1.0)
	var opening := _opening()
	var style := ShowOpening.style_of(feed.opening, _midway)
	ShowOpening.lens(ShowOpening.pull(style, _now, opening, _built_n > 0), _blur, _attrs)
	_title.alpha = ShowOpening.title_alpha(style, _now, opening, _built_n > 0)
	_title.fisheye = feed.fisheye()
	_title.queue_redraw()
	_pose(_now, delta)
	_sounds.now = _now
	_sounds.pump()
	_hold_for_sounds()
	_sounds.fade_from = _last_sound()
	_sounds.outro = feed.tail()
	_sounds.tick(_now, self)
	if _screen != null:
		_screen.set_time(_now)
		var lv := _sounds.level_at(_now)
		_screen.set_levels(lv.x, lv.y, delta)
	if _sounds.status != _said:
		_said = _sounds.status
		if not _said.is_empty():
			print("ghost: studio: " + _said)


## The close: 1 until the last sound ([method _last_sound]), then down to black over the outro.
func _end_fade() -> float:
	return ShowOpening.fade_out(_now, _last_sound(), feed.tail())


## When the footage's last sound ends (show time, s): the last word, or the end of an act written after it - INF until the last word
## is heard. The hands at work as the words end go on under the outro and fade with it ([method _end_of]).
func _last_sound() -> float:
	var last := _follower.known_last()
	if _spoken_n == 0 or last < _spoken_n - 1:
		return INF
	var t := _follower.st1[last]
	# (the hands at work as the words end go on through the outro, fading with it: only an act written after the last word holds it)
	for i in mini(_t0.size(), _acts.size()):
		if _t0[i] < INF and int((_acts[i] as Dictionary)["after"]) >= _spoken_n:
			if _t1[i] == INF:
				return INF
			t = maxf(t, _t1[i] + StudioSounds.RELEASE)
	return t


## The studio opens a settle before its first word: INF until it is heard.
func _opening() -> float:
	if _follower.said0.is_empty() or _follower.said0[0] == ReadingFollower.NO_TIME:
		return INF
	var t := _follower.said0[0]
	return t - Openings.settle(t)


# --- the document and the acts -------------------------------------------------------------------------------------------

func _ensure_doc() -> void:
	if _subs == null or not is_instance_valid(_subs):
		return
	var d: Dictionary = _subs.document
	_title.channel = String(d.get("title", ""))
	_title.byline = String(d.get("byline", ""))
	var src := String(d.get("source", ""))
	var start: PackedStringArray = d.get("start_words", PackedStringArray()) if d.get("start_words") is PackedStringArray else PackedStringArray()
	var block: Dictionary = d.get("medium", {}) if d.get("medium") is Dictionary else {}
	var takes: Dictionary = block.get("takes", {}) if block.get("takes") is Dictionary else {}
	var marks := marks_of(block)
	_restand(makes_of(block), StudioSet.places_of(block))
	# the Environment card's shares of what throws light ([method Surroundings.share_of]), applied as they change
	var env := Surroundings.sanitize(d.get("environment"))
	var ek := JSON.stringify(env)
	if ek != _surround_key:
		_surround_key = ek
		_surround = env
		_shine_things()
	var key := "%d|%s|%s|%s" % [src.hash(), " ".join(start), JSON.stringify(takes), JSON.stringify(marks)]
	if key == _doc_key:
		return
	_doc_key = key
	_takes = takes
	_marks = marks
	load_script(src, start, int(d.get("start_index", -1)))


## The words a Medium block [param block] keeps for its acts as a Refine changed them: `{own number: words}`.
static func marks_of(block: Dictionary) -> Dictionary:
	var out := {}
	var m: Dictionary = block.get("marks", {}) if block.get("marks") is Dictionary else {}
	for k in m:
		if m[k] is String and String(k).is_valid_int() and not String(m[k]).strip_edges().is_empty():
			out[String(k)] = String(m[k]).strip_edges()
	return out


## The makes a Medium block [param block] chooses for the studio's things: `{role: choice}` ([PropMakes]), each one a role can take.
static func makes_of(block: Dictionary) -> Dictionary:
	var out := {}
	var m: Dictionary = block.get("makes", {}) if block.get("makes") is Dictionary else {}
	for role in m:
		if PropMakes.valid_for(String(role), m[role]) and not (m[role] as Dictionary).is_empty():
			out[String(role)] = (m[role] as Dictionary).duplicate(true)
	return out


## A script loaded: its acts read, the voice followed on its words (from [param start]'s run near word [param near], for a
## reading started part way), and the acts' motions made again on a worker where the script changed. Public for a gate.
func load_script(source: String, start := PackedStringArray(), near := -1) -> void:
	_source = source
	_parsed = StudioScript.parse(source, _marks)
	_acts = StudioScript.with_takes(_parsed["acts"], _takes)
	var spoken: PackedStringArray = _parsed["spoken"]
	_spoken_n = spoken.size()
	var from := TabletScript.find_run(spoken, start, near) if not start.is_empty() else -1
	_midway = not start.is_empty()
	_follower.reset(spoken, from, StudioScript.word_starts(_parsed) if from > 0 else PackedFloat32Array())
	_built_n = -1
	_held = {}
	_t0 = PackedFloat32Array()
	_t0.resize(_acts.size())
	_t0.fill(INF)
	_t1 = _t0.duplicate()
	if _make_for != _making_of():
		_made = []
		_keys = []
		_starts = []


## What the acts are made of: the script, their takes and their words as changed.
func _making_of() -> String:
	return _source + JSON.stringify(_takes) + JSON.stringify(_marks)


## The acts' motions and sounds, made on a worker once the set stands ([method StudioActs.make]); taken when done. An act that goes
## on is made a stretch ahead of the show and made longer as the show comes to the end of it (the same where they overlap, so
## the windows already made stay made); only the acts that want it are made again.
func _take_made() -> void:
	if _set.is_empty() or _acts.is_empty():
		return
	if _make_task >= 0:
		if not WorkerThreadPool.is_task_completed(_make_task):
			return
		WorkerThreadPool.wait_for_task_completion(_make_task)
		_make_task = -1
		var got := _make_box
		if String(got.get("for", "")) == _make_for:
			var which: Array = got.get("which", [])
			for j in which.size():
				var i := int(which[j])
				_made[i] = (got["made"] as Array)[j]
				_keys[i] = (got["keys"] as Array)[j]
				_starts[i] = (got["starts"] as Array)[j]
			_specs.merge(got.get("specs", {}), true)
			_sounds.want(_specs)
			_place_sounds()
	if _make_for != _making_of():
		_make_for = _making_of()
		_made = []
		_made.resize(_acts.size())
		_keys = []
		_keys.resize(_acts.size())
		_starts = []
		_starts.resize(_acts.size())
		_specs = {}
		_horizon = {}
	var which: Array = []
	var horizons := {}
	for a in _acts:
		var i := int((a as Dictionary)["i"])
		var open := not bool((a as Dictionary)["timed"])
		var need := _need(i) if open else 0.0
		if _made[i] != null and (not open or need <= float(_horizon.get(i, 0.0)) - HORIZON_SPARE):
			continue
		if open:
			horizons[i] = ceilf((need + HORIZON_SPARE) / HORIZON_STEP) * HORIZON_STEP
			_horizon[i] = horizons[i]
		which.append((a as Dictionary).duplicate(true))
	if which.is_empty():
		return
	_make_box = {}
	var box := _make_box
	var geo: Dictionary = _set["geo"]
	var of := _make_for
	var idx: Array = which.map(func(a: Dictionary) -> int: return int(a["i"]))
	_make_task = WorkerThreadPool.add_task(func() -> void:
		box.merge(StudioSounds.make_all(which, geo, horizons), true)
		box["which"] = idx
		box["for"] = of)


## How long act [param i] (one that goes on) must be made for now (s): to its end where that is known, else well past the show.
func _need(i: int) -> float:
	if _t1[i] < INF and _t0[i] < INF:
		return _t1[i] - _t0[i] + StudioSounds.RELEASE + 1.0
	if _t0[i] < INF:
		return maxf(StudioSounds.OPEN_LEAST, _now - _t0[i] + StudioSounds.AHEAD * 2.0)
	return StudioSounds.OPEN_LEAST


## The voice's words so far, matched, and the acts placed again where more came. Public for a gate.
func take_words(words: Array) -> void:
	_follower.extend(words)
	if words.size() == _built_n:
		return
	_built_n = words.size()
	_place_acts()
	_place_head(words)


## The head performed on [param words] from the show's phrases (the document's `head`, [HeadBank]) and the phrases the script calls
## ([HeadMarks]), a move's look at the lens or the flip screen aimed where they are on this set.
func _place_head(words: Array) -> void:
	var bank: Array = (_subs.document.get("head", []) as Array) if _subs != null and is_instance_valid(_subs) and _subs.document.get("head") is Array else []
	if bank.is_empty():
		_head = {}
		return
	var targets := {}
	if not _set.is_empty():
		var lis: Transform3D = (_set["geo"] as Dictionary)["listener"]
		targets["lens"] = lis.affine_inverse() * ((_set["geo"] as Dictionary)["lens"] as Vector3)
		var rigs: Dictionary = _set["rigs"]
		if rigs.has("camera") and (rigs["camera"] as PropRig).face("screen") != null:
			var face := (rigs["camera"] as PropRig).face("screen")
			targets["screen"] = lis.affine_inverse() * ((rigs["camera"] as PropRig).node.transform * _in_rig(face, (rigs["camera"] as PropRig).node))
	_head_feel = JSON.stringify(_feel())
	_head = HeadMarks.plan(_source, words, bank, targets, _feel())


## Each hand on the windscreen ([param hands]: per hand `{track, u, fade}` or null) as the fingertips that press it: three across the
## stroke, each with where it was a moment ago pressing less ([constant TRAIL]), so the fur is combed along the stroke and springs
## back behind it. [param lis] is the listener; [param middle] the windscreen's own middle, what the fingertips spread round.
static func _fingers(hands: Array, lis: Transform3D, middle: Vector3) -> Array:
	var out: Array = []
	for h in hands:
		if h == null:
			continue
		var tc: Dictionary = (h as Dictionary)["track"]
		var u := float(h["u"])
		var fade := float(h["fade"])
		for tr in TRAIL:
			var uu := u - float(tr[0])
			if uu < 0.0:
				continue
			var at := Gesture.at3(tc["at"], uu)
			var dep := Gesture.at(tc["depth"], uu) * float(tr[1]) * fade
			if dep <= 0.0:
				continue
			var push := Gesture.at3(tc["push"], uu)
			var nrm := (at - middle).normalized()
			var across := push.cross(nrm)
			if across.length() < 1e-5:
				across = lis.basis.y.cross(nrm)
			across = across.normalized()
			for f in [-1.0, 0.0, 1.0]:
				out.append({"at": at + across * f * FINGER, "depth": dep * (1.0 if f == 0.0 else 0.85), "push": push})
	return out


## How gently the head is performed: the Camera card's head camera ([method HeadPlan.feel_of]), resting at the chair wherever the
## microphone is placed.
func _feel() -> Dictionary:
	var block: Dictionary = _subs.document.get("medium", {}) if _subs != null and is_instance_valid(_subs) and _subs.document.get("medium") is Dictionary else {}
	return HeadPlan.feel_of(feed.cameras if feed != null else [], StudioSet.places_of(block).get("microphone", {}))


## Where node [param n] is in rig node [param root]'s own space.
static func _in_rig(n: Node3D, root: Node3D) -> Vector3:
	var xf := Transform3D.IDENTITY
	var at: Node = n
	while at != null and at != root and at is Node3D:
		xf = (at as Node3D).transform * xf
		at = at.get_parent()
	return xf.origin


## Each act where it begins and ends: under the words, as the word after its mark begins, until the word it ends at begins (its
## closing mark's, or where another act takes its hand), its seconds, or past the last word; one said `alone` in the rest the voice
## left for it. One begun is kept where it began.
func _place_acts() -> void:
	var holding: Array = []
	for a in _acts:
		var i := int((a as Dictionary)["i"])
		if not _held.has(i):
			if bool((a as Dictionary)["under"]):
				var w := int((a as Dictionary)["after"])
				if w < _follower.said0.size() and _follower.said0[w] != ReadingFollower.NO_TIME:
					_t0[i] = _follower.said0[w] - UNDER_LEAD
				elif w >= _spoken_n and _spoken_n > 0 and _follower.known_last() >= _spoken_n - 1:
					# written after the last word: as it ends
					_t0[i] = _follower.st1[_spoken_n - 1] + 0.3
			else:
				holding.append({"after": int((a as Dictionary)["after"]), "dur": float((a as Dictionary)["secs"]), "i": i})
	var opening := maxf(feed.intro_hold, 0.0) + StudioScript.OPENING * 0.4
	for p in _follower.place(holding, opening, 0.2, TAIL):
		var k := int((p["a"] as Dictionary)["i"])
		if not _held.has(k):
			_t0[k] = float(p["t0"])
	for a in _acts:
		var i := int((a as Dictionary)["i"])
		_t1[i] = _end_of(a, _t0[i])
	for i in _t0.size():
		if _t0[i] < INF and _now >= _t0[i]:
			_held[i] = _t0[i]
	_place_sounds()


## When act [param a] (begun at [param t0]) ends, as far as the words heard so far say: INF while that is not known.
func _end_of(a: Dictionary, t0: float) -> float:
	if t0 == INF:
		return INF
	if not bool(a["under"]):
		return t0 + float(a["secs"])
	var out := INF
	var e := int(a["end"])
	var last := _follower.known_last()
	if e >= 0:
		if e < _follower.said0.size() and _follower.said0[e] != ReadingFollower.NO_TIME:
			out = _follower.said0[e] - UNDER_LEAD
		elif e >= _spoken_n and _spoken_n > 0 and last >= _spoken_n - 1:
			out = _follower.st1[_spoken_n - 1] + 0.3
	elif String(a["ends"]) == "end" and _spoken_n > 0 and last >= _spoken_n - 1:
		out = _follower.st1[_spoken_n - 1] + StudioScript.PAST_LAST
	if bool(a["timed"]):
		out = minf(out, t0 + float(a["secs"]))
	# one begun before the last word ends with the outro at the latest, faded out with the picture
	if int(a["after"]) < _spoken_n and _spoken_n > 0 and last >= _spoken_n - 1:
		out = minf(out, _follower.st1[_spoken_n - 1] + maxf(feed.tail() if feed != null else 0.0, 0.5))
	return maxf(out, t0 + 0.5)


## The show held while an act about to begin, or going on, has no sound for now yet - its motion not made this far, or the window
## sounding now not read (made on the host a few at a time, and quickly): it waits rather than play what an export would hear and
## the live show would not. A sound that cannot be made holds nothing.
func _hold_for_sounds() -> void:
	var want := false
	for i in _t0.size():
		if _t0[i] == INF or _now < _t0[i] - WAIT_AHEAD or _now > _t1[i]:
			continue
		if i >= _made.size() or _made[i] == null or (not bool((_acts[i] as Dictionary)["timed"]) and _now - _t0[i] > float((_made[i] as Dictionary)["secs"]) - 1.0):
			want = true
			break
		var ks: PackedStringArray = _keys[i] if _keys[i] != null else PackedStringArray()
		var st: PackedFloat32Array = _starts[i] if _starts[i] != null else PackedFloat32Array()
		for j in ks.size():
			var w0 := _t0[i] + st[j]
			if w0 <= _now + WAIT_AHEAD and w0 + _sounds.length_of(ks[j]) >= _now and not _sounds.heard(ks[j]):
				want = true
				break
		if want:
			break
	if want != _waiting:
		_waiting = want
		feed.wait_for(WAIT_FOR, want)


## Every act's windows laid where they sound: from where it begins, none past where it ends.
func _place_sounds() -> void:
	var placed: Array = []
	for i in mini(_keys.size(), _t0.size()):
		if _t0[i] == INF or _keys[i] == null:
			continue
		var ks: PackedStringArray = _keys[i]
		var st: PackedFloat32Array = _starts[i]
		for j in ks.size():
			var w0 := _t0[i] + st[j]
			if w0 > _t1[i] + StudioSounds.RELEASE:
				break
			placed.append({"key": ks[j], "t0": w0, "end": _t1[i]})
	_sounds.place(placed)


# --- the pose ----------------------------------------------------------------------------------------------------------

## Everything at show time [param t]: each thing where its act (or its rest) has it, the windscreen pressed where it is touched,
## the camera and the microphone swayed by a tap, the eye breathing.
func _pose(t: float, dt: float) -> void:
	# the head performed again where the Camera card's Reach, Turns or Pace changed
	if not _head.is_empty() and JSON.stringify(_feel()) != _head_feel and _subs != null and is_instance_valid(_subs):
		_place_head(_subs.words)
	var eye := Transform3D(Basis.looking_at(StudioSet.LOOK - StudioSet.EYE, Vector3.UP), StudioSet.EYE)
	# the eye is the creator's head where the script places it ([HeadMarks]): the same plan the voice is placed by
	if not _head.is_empty() and not _set.is_empty():
		var lis: Transform3D = (_set["geo"] as Dictionary)["listener"]
		var hp := HeadPlan.pose_at(_head, t)
		var look: Vector3 = lis.basis * (hp["look"] as Vector3)
		# (the head's own up: a lean ear toward shoulder rolls the picture)
		var up: Vector3 = lis.basis * (hp["up"] as Vector3)
		eye = Transform3D(Basis.looking_at(look, up if absf(look.normalized().dot(up.normalized())) < 0.97 else Vector3.UP), lis * (hp["eyes"] as Vector3))
	# ...and as a person looking the paused show over turned it ([FreeLook]): held while paused, eased back once it plays
	_cam.transform = _look.eye(eye, dt, feed != null and feed.paused() and not _rendering)
	if _set.is_empty():
		return
	var rigs: Dictionary = _set["rigs"]
	var geo: Dictionary = _set["geo"]
	var rests: Dictionary = geo["rests"]
	var touches := [null, null]
	var shake := {"camera": 0.0, "mic": 0.0}
	var posed := {}
	for i in mini(_made.size(), _t0.size()):
		if _t0[i] == INF or _made[i] == null:
			continue
		var m: Dictionary = _made[i]
		var u := t - _t0[i]
		var end := _t1[i]
		var timed := bool((_acts[i] as Dictionary)["timed"])
		var whole := timed and end >= _t0[i] + float(m["secs"]) - 0.05
		if u < 0.0 or t > end + StudioActs.GO + 0.3 or (whole and u > float(m["secs"]) + 0.3):
			continue
		# where it ends the hand lifts and what it brought is carried back - unless the act, made whole, does that itself
		var lifted := 0.0 if end == INF else clampf((t - end) / StudioSounds.RELEASE, 0.0, 1.0)
		var held_u := u if (whole or end == INF) else minf(u, end - _t0[i])
		for k in (m["tracks"] as Dictionary):
			var xf := StudioActs.pose_at((m["tracks"] as Dictionary)[k], minf(held_u, float(m["secs"])))
			if not whole and end < INF and t > end and rests.has(k):
				xf = StudioActs.carried(xf, rests[k], Gesture.min_jerk((t - end) / StudioActs.GO))
			posed[k] = xf
		var hand := String((_acts[i] as Dictionary).get("hand", "right"))
		var slot := 0 if hand == "left" else 1
		for tc in m["touches"]:
			if slot < 2:
				touches[slot] = {"track": tc, "u": minf(held_u, float(m["secs"])), "fade": 1.0 - lifted}
			slot += 1
		for k in (m["shake"] as Dictionary):
			shake[k] = float(shake[k]) + Gesture.at((m["shake"] as Dictionary)[k], minf(held_u, float(m["secs"]))) * (1.0 - lifted)
	for k in ["block_a", "block_b", "brush"]:
		if not rigs.has(k):
			continue
		# held, it drifts as a hand does; laid on the desk out of shot, it lies still
		(rigs[k] as PropRig).node.transform = (posed[k] as Transform3D).translated(Gesture.idle(hash(k) % 1000, t, 0.0018)) \
			if posed.has(k) else rests.get(k, Transform3D())
	if rigs.has("microphone"):
		var mic: PropRig = rigs["microphone"]
		var a := float(shake["mic"])
		mic.node.transform = (_bases["microphone"] as Transform3D) * Transform3D(Basis.from_euler(Vector3(a, 0.0, a * 0.45)), Vector3.ZERO)
		mic.touch_all(_fingers(touches, (geo["listener"] as Transform3D), geo.get("fur_c", (geo["listener"] as Transform3D).origin)))
	if rigs.has("camera"):
		var a2 := float(shake["camera"])
		var cam_rig: PropRig = rigs["camera"]
		cam_rig.node.transform = (_bases["camera"] as Transform3D) * Transform3D(Basis.from_euler(Vector3(a2, 0.0, a2 * 0.4)), Vector3.ZERO)
		if _screen != null:
			# the lens where the camera's sway has taken it
			var lens_local := (_bases["camera"] as Transform3D).affine_inverse() * (geo["lens"] as Vector3)
			_screen.place(Transform3D(cam_rig.node.transform.basis, cam_rig.node.transform * lens_local))
