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
## The regions what drifts in the air keeps to (studio space, m): round the work at the microphone, far off behind the camera (out of
## focus, the room's depth), and the room. Where shafts come from (degrees round and up, [method Surroundings.toward]: high on the
## viewer's left, as through the room's windows), what they fall onto and from how high; how far from the eye the fog is worked out (m).
const AIR_NEAR := AABB(Vector3(-0.5, 0.85, -1.0), Vector3(1.0, 0.6, 0.75))
const AIR_FAR := AABB(Vector3(-2.0, 0.2, -3.2), Vector3(4.0, 2.4, 1.9))
const AIR_ROOM := AABB(Vector3(-2.0, 0.0, -2.8), Vector3(4.0, 2.6, 3.6))
const RAYS_FROM := Vector2(250.0, 50.0)
const RAYS_ONTO := AABB(Vector3(-1.4, 0.0, -1.8), Vector3(2.8, 0.0, 2.2))
const RAYS_REACH := 2.2
const FOG_LENGTH := 6.0
## How near the eye a held block's nearest surface comes (m): the head never passes through, or right up against, what the hands hold
## up; and how far either side of the moment the head's coming is looked for (s), so the blocks ease aside before it and back after.
const EYE_CLEAR := 0.24
const CLEAR_AHEAD := 0.75
const CLEAR_STEPS := 6
## Where a push from the eye goes: out in front, toward the camera and a little down ([constant FRONT]) - never round behind the head or
## swung about it; how little of the way from the eye that is taken to win (a cosine), and the most it moves a block (m).
const FRONT := Vector3(0.0, -0.35, -0.94)
const FRONT_LEAST := 0.35
const PUSH_MOST := 0.25
## How far outside the windscreen's fur a held block stays (m), and how far a block reaches from the pair's middle (m).
const FUR_CLEAR := 0.01
const BLOCK_REACH := 0.07
## How the hands holding the blocks sway: how far they drift (m), how far they turn (degrees) and their own number.
const HELD_DRIFT := 0.005
const HELD_TURN := 3.0
const HELD_SEED := 7717
## How thick the room's walls, floor and ceiling are taken to be (m): its inside, for the cutaway, is its box less this all round.
const ROOM_WALL := 0.3
## An act's sound's Level on the Sound card, least and most (dB).
const LEVEL_LEAST := -30.0
const LEVEL_MOST := 12.0

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
var _levels := {}                       # how loud and how muffled each act's sound is heard ([method levels_of])
var _mic_voice := PackedByteArray()     # the voice as the microphone received it, each ear a byte at a time ([method VoiceFX.meter_at])
var _mic_key := 0
var _mic_gain := 0.0                    # the recorder's input gain (dB): the take's, which the hands' sounds are brought up by too
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
var _air: Effects.Air = null           # what drifts in the air round the studio ([method _dress_environment])
var _rays: Node3D = null                # its shafts of light
var _dressed := "-"                     # what is round the scene as it was last dressed, as JSON
var _table_seen := ""                   # the episode table read for it, by file and time
var _table_els: Array = []              # ...and its air and sound as elements ([TableSurroundings])
var _room_cut := -1                     # whether the room is cut away for an eye outside it ([method _cut_room]); -1 not yet said
var _tufts: Array = []                  # the brush's tufts of hairs ([method _tufts_of]), and the make they are of
var _tufts_for: PropRig = null


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
	# (built with the studio's one number, never the session's: the windscreen the hands' sounds are made on is the same here, on the
	# Pipeline card and in a render, so every sound made for it is the one played)
	var m := makes.duplicate(true)
	var pl := places.duplicate(true)
	_build_task = WorkerThreadPool.add_task(func() -> void: box["set"] = StudioSet.build(StudioSet.SEED, m, pl))


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
	_mount_screen()
	_shine_things()
	_room_cut = -1
	# the acts are made again for this set, and the head's gazes aimed at its things
	_make_for = ""
	_built_n = -1


## The camera's flip screen built and put on its `screen` face ([StudioScreen]) - with each set, and again where a stop let it go
## while the set stayed ([method release]).
func _mount_screen() -> void:
	if _set.is_empty():
		return
	if _screen != null:
		_screen.release()
		_screen.queue_free()
	_screen = StudioScreen.new()
	add_child(_screen)
	_screen.mount(self, stage.find_world_3d() if stage != null else _root3.get_world_3d(), _lens_xf(), _env)
	var rigs: Dictionary = _set["rigs"]
	if rigs.has("camera"):
		var face := (rigs["camera"] as PropRig).face("screen")
		if face != null:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_texture = _screen.texture()
			face.material_override = mat


## The room seen into from outside: while the eye stands outside its inside (a paused show looked over from far off), what stands
## between the eye and the inside is left out of every part of it (prop.gdshader's cutaway) - from inside, nothing is.
func _cut_room() -> void:
	var rigs: Dictionary = _set.get("rigs", {})
	if not rigs.has("room") or _cam == null or not _cam.is_inside_tree():
		return
	var room: PropRig = rigs["room"]
	var box := StudioScene.box_of(room.node)
	var parent := room.node.get_parent() as Node3D
	if parent != null and parent.is_inside_tree():
		box = parent.global_transform * box
	# (its inside: the walls, floor and ceiling taken off)
	box = box.grow(-ROOM_WALL)
	if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
		return
	var outside := 1 if not box.has_point(_cam.global_position) else 0
	if outside == _room_cut:
		return
	_room_cut = outside
	for mi in room.node.find_children("*", "GeometryInstance3D", true, false):
		var mat := (mi as GeometryInstance3D).material_override as ShaderMaterial
		if mat == null:
			continue
		mat.set_shader_parameter("cut_on", float(outside))
		mat.set_shader_parameter("cut_lo", box.position)
		mat.set_shader_parameter("cut_hi", box.end)


## What is round the studio, as the Environment card has it ([Surroundings]): how bright it is, shafts of light through the room's air,
## fog lying in it and what drifts - haze far off behind the camera, motes round the work, a room's worth - from the note's own elements
## and, at a table show, the episode's (its table's air and sound, [TableSurroundings]: the card lists them in the note's place). The
## sound is the reading's (the bed under the voice), never the studio's. Dressed again only where it changed.
func _dress_environment(d: Dictionary) -> void:
	var spec := _surround.duplicate(true)
	(spec["elements"] as Array).append_array(_episode_elements(d))
	spec = Surroundings.sanitize(spec)
	var key := JSON.stringify(spec)
	if key == _dressed or _env == null:
		return
	_dressed = key
	Tonemaps.dress(_env, Surroundings.brightness(spec))
	var row := Surroundings.light_of(spec)
	if _rays != null:
		_rays.queue_free()
		_rays = null
	if Surroundings.has_shafts(spec):
		_rays = Surroundings.rays(spec, Color.html(String(row["key_color"])), Surroundings.toward(RAYS_FROM.x, RAYS_FROM.y),
			[RAYS_ONTO], RAYS_REACH)
		_root3.add_child(_rays)
	Surroundings.fog_for(_env, spec, 0.0)
	_env.volumetric_fog_length = FOG_LENGTH
	if _air != null:
		_air.release()
		_air = null
	var fx := Surroundings.effects_of(spec, Color.html(String(row["fog"])))
	if not fx.is_empty():
		# its motes spread over the studio as the chair sees it, never over wherever the head happens to be
		_air = Effects.build(fx, {"regions": {"near": AIR_NEAR, "far": AIR_FAR, "room": AIR_ROOM},
			"camera": Transform3D(Basis.looking_at(StudioSet.LOOK - StudioSet.EYE, Vector3.UP), StudioSet.EYE), "fov": StudioSet.VFOV,
			"aspect": 16.0 / 9.0, "around": true}, hash([_seed, "studio air"]))
		_root3.add_child(_air.root)


## At a table show, the episode's air and sound as Environment elements ([method TableSurroundings.elements_of]), from its table as it
## is written now - read again only when the file changes, looked at once a second.
func _episode_elements(d: Dictionary) -> Array:
	var ep: Dictionary = d.get("table", {}) if d.get("table") is Dictionary else {}
	var dir := String(ep.get("dir", ""))
	if dir.is_empty():
		return []
	var now := Time.get_ticks_msec()
	if now - _table_polled < 1000:
		return _table_els
	_table_polled = now
	var path := dir.path_join("table.json")
	var seen := "%s|%d" % [path, FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0]
	if seen == _table_seen:
		return _table_els
	_table_seen = seen
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var plan: Dictionary = ep.get("plan", {}) if ep.get("plan") is Dictionary else {}
	var look: Variant = plan.get("look", {})
	var palette: Array = CardTable.sanitize_look(look if look is Dictionary else {}).get("palette", [])
	_table_els = TableSurroundings.elements_of(table, int(ep.get("seed", 0)), palette) if table is Dictionary else []
	return _table_els

var _table_polled := -100000


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
	# (its pictures let go; built again with the set still standing when the show comes back, [method _mount_screen])
	if _screen != null:
		_screen.release()
		_screen.queue_free()
		_screen = null
	for task in [_build_task, _make_task]:
		if int(task) >= 0:
			WorkerThreadPool.wait_for_task_completion(int(task))
	_build_task = -1
	_make_task = -1


func _exit_tree() -> void:
	_sounds.stop()
	if _air != null:
		_air.release()
		_air = null
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
	if _air != null:
		_air.tick(_now)
	Surroundings.tick_rays(_rays, _now)
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
	if _screen == null and not _set.is_empty():
		_mount_screen()
	if _screen != null:
		_screen.set_time(_now)
		var lv := _mic_levels(_now)
		_screen.set_levels(lv.x, lv.y, delta)
	if _sounds.status != _said:
		_said = _sounds.status
		if not _said.is_empty():
			print("ghost: studio: " + _said)


## The close: 1 until the last sound ([method _last_sound]), then down to black over the outro.
func _end_fade() -> float:
	return ShowOpening.fade_out(_now, _last_sound(), feed.tail())


## Where the close begins (show time, s): the end of the last word - INF until it is heard. The picture and every sound fade to black
## over the outro from there; the hands at work go on under it and fade with it ([method _end_of]), never holding it.
func _last_sound() -> float:
	var last := _follower.known_last()
	if _spoken_n == 0 or last < _spoken_n - 1:
		return INF
	# (nothing the hands do holds it: they go on under the outro and fade with it)
	return _follower.st1[last]


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
	# ...and what is round the scene: the note's own elements and, at a table show, the episode's (its table's air and sound, where the
	# card lists them), dressed as they change
	_dress_environment(d)
	# the voice as the microphone received it, as the take measured it ([member VoiceFX.meter])
	var mv := String(d.get("mic_voice", ""))
	if mv.hash() != _mic_key:
		_mic_key = mv.hash()
		_mic_voice = Marshalls.base64_to_raw(mv) if not mv.is_empty() else PackedByteArray()
	# ...and the recorder's input gain the take was brought up by: the hands' sounds come up with it
	var mg := float(d.get("mic_gain", 0.0)) if (d.get("mic_gain") is float or d.get("mic_gain") is int) else 0.0
	if not is_equal_approx(mg, _mic_gain):
		_mic_gain = mg
		_place_sounds()
	# each act's sound as loud and as muffled as the Sound card says, heard at once (nothing is made again)
	var lv := levels_of(block)
	if JSON.stringify(lv) != JSON.stringify(_levels):
		_levels = lv
		_place_sounds()
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


## How loud and how muffled a Medium block [param block] has the acts' sounds heard: `{own number or "all": {db, muffle}}` - `db` a
## level (0 as made), `muffle` 0 (as made) to 1 (through thick cloth, [method StudioSounds.muffled]); "all" every act's, under its own.
static func levels_of(block: Dictionary) -> Dictionary:
	var out := {}
	var m: Dictionary = block.get("levels", {}) if block.get("levels") is Dictionary else {}
	for k in m:
		if not (m[k] is Dictionary) or not (String(k).is_valid_int() or String(k) == "all"):
			continue
		var d: Dictionary = m[k]
		var db := clampf(float(d.get("db", 0.0)) if (d.get("db") is float or d.get("db") is int) else 0.0, LEVEL_LEAST, LEVEL_MOST)
		var mu := clampf(float(d.get("muffle", 0.0)) if (d.get("muffle") is float or d.get("muffle") is int) else 0.0, 0.0, 1.0)
		if absf(db) > 0.001 or mu > 0.001:
			out[String(k)] = {"db": db, "muffle": mu}
	return out


## What act [param act] is heard as, from [param levels] ([method levels_of]): `{gain, muffle}` - its own level over every act's and
## its mark's (`-6 dB`, [StudioScript]), and its own muffle with every act's and its mark's.
static func tone_of(levels: Dictionary, act: Dictionary) -> Dictionary:
	var own: Dictionary = levels.get(str(int(act.get("own", act.get("seed", 0)))), {})
	var all: Dictionary = levels.get("all", {})
	return {"gain": db_to_linear(float(own.get("db", 0.0)) + float(all.get("db", 0.0)) + float(act.get("db", 0.0))),
		"muffle": clampf(float(own.get("muffle", 0.0)) + float(all.get("muffle", 0.0)) + float(act.get("muffle", 0.0)), 0.0, 1.0)}


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


## Where the head camera rests its eyes (the Camera card's `creator` Tilt and Pan): `(tilt, pan)` degrees, up and to the right.
func _aim() -> Vector2:
	var e := Cameras.entry_of(Cameras.sanitize(feed.cameras if feed != null else [], true, "studio"), "creator")
	return Vector2(Cameras.value(e, "tilt"), Cameras.value(e, "pan"))


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
	# every act ends with the outro at the latest, faded out with the picture
	if _spoken_n > 0 and last >= _spoken_n - 1:
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
		var tone := tone_of(_levels, _acts[i]) if i < _acts.size() else {"gain": 1.0, "muffle": 0.0}
		for j in ks.size():
			var w0 := _t0[i] + st[j]
			if w0 > _t1[i] + StudioSounds.RELEASE:
				break
			placed.append({"key": ks[j], "t0": w0, "end": _t1[i], "gain": float(tone["gain"]) * db_to_linear(_mic_gain), "muffle": tone["muffle"]})
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
	# ...aimed where the Camera card's head camera rests its eyes (its Tilt and Pan, under every move: the eyes alone, never the voice)
	var aim := _aim()
	if not aim.is_zero_approx():
		eye.basis = Basis(Vector3.UP, -deg_to_rad(aim.y)) * eye.basis * Basis(Vector3.RIGHT, deg_to_rad(aim.x))
	# ...and as a person looking the paused show over turned it ([FreeLook]): held while paused, eased back once it plays
	_cam.transform = _look.eye(eye, dt, feed != null and feed.paused() and not _rendering)
	_cut_room()
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
		if u < 0.0 or t > end + float(m.get("go", StudioActs.GO)) + float(m.get("apart", 0.0)) + 0.3 or (whole and u > float(m["secs"]) + 0.3):
			continue
		# where it ends the hand lifts and what it brought is carried back - unless the act, made whole, does that itself
		var lifted := 0.0 if end == INF else clampf((t - end) / StudioSounds.RELEASE, 0.0, 1.0)
		var held_u := u if (whole or end == INF) else minf(u, end - _t0[i])
		for k in (m["tracks"] as Dictionary):
			var xf: Variant = _thing_at(i, String(k), t)
			if xf != null:
				posed[k] = xf
		var hand := String((_acts[i] as Dictionary).get("hand", "right"))
		var slot := 0 if hand == "left" else 1
		for tc in m["touches"]:
			if slot < 2:
				touches[slot] = {"track": tc, "u": minf(held_u, float(m["secs"])), "fade": 1.0 - lifted}
			slot += 1
		for k in (m["shake"] as Dictionary):
			shake[k] = float(shake[k]) + Gesture.at((m["shake"] as Dictionary)[k], minf(held_u, float(m["secs"]))) * (1.0 - lifted)
	# the blocks held clear of the eye: pushed away, together, while the head comes near them, back where they were held once it is past
	# ...and never into the windscreen: what the eye pushed into the fur pushed back out of it, the two worked out together
	var clear := _clear_of_eye(t) if posed.has("block_a") or posed.has("block_b") else Vector3.ZERO
	clear += _round_the_fur(posed, clear)
	if not clear.is_zero_approx():
		for k in ["block_a", "block_b"]:
			if posed.has(k):
				posed[k] = (posed[k] as Transform3D).translated(clear)
	# ...and swaying gently as hands holding them do, the pair as one (a knock or a scrape between them stays in touch)
	var sway := _hands_sway(posed, t)
	for k in ["block_a", "block_b"]:
		if posed.has(k):
			posed[k] = sway * (posed[k] as Transform3D)
	# ...each hand its own once the blocks are apart: the second block's sway its own as far as it is from the held one (in touch, the
	# pair's alone, so a knock or a scrape stays in touch)
	if posed.has("block_a") and posed.has("block_b"):
		var apart := clampf(((posed["block_a"] as Transform3D).origin.distance_to((posed["block_b"] as Transform3D).origin) - 0.03) / 0.06, 0.0, 1.0)
		if apart > 0.0:
			var own := Gesture.idle(HELD_SEED + 40, t, HELD_DRIFT) * apart
			var turn := Basis.from_euler(Vector3(Gesture.wave(HELD_SEED + 41, t, 6.0, 2.6), Gesture.wave(HELD_SEED + 42, t, 7.5, 3.1),
				Gesture.wave(HELD_SEED + 43, t, 5.5, 2.4)) * deg_to_rad(HELD_TURN) * apart)
			var a: Transform3D = posed["block_a"]
			posed["block_a"] = Transform3D(turn * a.basis, a.origin + own)
	for k in ["block_a", "block_b", "brush"]:
		if not rigs.has(k):
			continue
		# (the brush's hairs bent by how it is dragged and pressed, below, once it is where it is)
		# held, it drifts as a hand does (the blocks have swayed already, above); laid on the desk out of shot, it lies still
		(rigs[k] as PropRig).node.transform = ((posed[k] as Transform3D) if k != "brush" else (posed[k] as Transform3D).translated(
			Gesture.idle(hash(k) % 1000, t, 0.0018))) if posed.has(k) else rests.get(k, Transform3D())
	if rigs.has("brush"):
		_bend_bristles(rigs["brush"], t)
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


## What the camera's meters show at show time [param t]: each ear's peak (dBFS) of what is recorded - what the microphone receives,
## at the recorder's input gain: the voice as the take measured it at the capsule (its direct voice alone: no echo, room, ambience or
## bed, nothing laid on after) and the hands' sounds and the room tone ([method StudioSounds.peak_at], already at that gain). Two peaks are added as they could meet at worst (amplitude), so a peak
## is never missed.
func _mic_levels(t: float) -> Vector2:
	var hands := _sounds.peak_at(t)
	if _mic_voice.is_empty():
		return hands
	var voice := VoiceFX.meter_at(_mic_voice, t) + Vector2(_mic_gain, _mic_gain)
	var add := func(a: float, b: float) -> float: return linear_to_db(db_to_linear(a) + db_to_linear(b))
	return Vector2(add.call(hands.x, voice.x), add.call(hands.y, voice.y))


## How the held blocks sway at show time [param t], as the hands holding them never quite stay still: a slow drift of a few
## millimeters ([constant HELD_DRIFT]) and a turn of about a degree ([constant HELD_TURN]), about the pair's own middle - the identity
## where neither is held.
func _hands_sway(posed: Dictionary, t: float) -> Transform3D:
	var held: Array = []
	for k in ["block_a", "block_b"]:
		if posed.has(k):
			held.append((posed[k] as Transform3D).origin)
	if held.is_empty():
		return Transform3D.IDENTITY
	var mid := Vector3.ZERO
	for p in held:
		mid += p as Vector3
	mid /= float(held.size())
	var turn := Basis.from_euler(Vector3(Gesture.wave(HELD_SEED, t, 7.0, 3.0), Gesture.wave(HELD_SEED + 1, t, 8.0, 3.5),
		Gesture.wave(HELD_SEED + 2, t, 6.5, 2.8)) * deg_to_rad(HELD_TURN))
	var drift := Gesture.idle(HELD_SEED + 3, t, HELD_DRIFT)
	return Transform3D(Basis.IDENTITY, mid + drift) * Transform3D(turn, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -mid)


## How far the held blocks are pushed at show time [param t] to keep their nearest surface [constant EYE_CLEAR] from the eye and out of
## the windscreen: what each moment a while either side of [param t] needs ([constant CLEAR_AHEAD]), averaged, each weighed less the
## further it is from [param t] - so they ease aside before the head comes and back slowly once it is past, never flipping from one
## way to another. Zero where none is near.
func _clear_of_eye(t: float) -> Vector3:
	var sum := Vector3.ZERO
	var weight := 0.0
	var steps := CLEAR_STEPS
	for j in range(-steps, steps + 1):
		var w := 1.0 - absf(float(j)) / float(steps + 1)
		var at := t + CLEAR_AHEAD * float(j) / float(steps)
		# (at each moment the push from the eye and then out of the fur, together, so the two never fight from frame to frame)
		sum += _push_at(at) * w
		weight += w
	return sum / weight


## The held blocks where the acts have them at show time [param t] (before any push or sway): `{block_a, block_b}`, each held.
func _blocks_at(t: float) -> Dictionary:
	var out := {}
	for k in ["block_a", "block_b"]:
		for i in mini(_made.size(), _t0.size()):
			var p: Variant = _thing_at(i, k, t)
			if p != null:
				out[k] = p
	return out


## How far the held blocks must move at show time [param t] for their nearest surface to stand [constant EYE_CLEAR] from the eye then
## (the blocks already moved [param moved]): out in front ([constant FRONT]), as far as the nearer block is inside it.
func _push_at(t: float, moved := Vector3.ZERO) -> Vector3:
	var eye := _eye_at(t) - moved
	var size: Vector3 = (_set.get("geo", {}) as Dictionary).get("block_size", Vector3(0.15, 0.02, 0.05))
	var lo := Vector3(-size.x * 0.5, 0.0, -size.z * 0.5)
	var hi := Vector3(size.x * 0.5, size.y, size.z * 0.5)
	var push := Vector3.ZERO
	var held := _blocks_at(t)
	for k in held:
		var b: Transform3D = held[k]
		var near := b * (b.affine_inverse() * eye).clamp(lo, hi)
		var d := near - eye
		if d.length() < EYE_CLEAR and d.length() > 1e-5:
			# always the one way, out in front (toward the camera and a little down: never round behind the head, never swung about it),
			# as far as clears the eye, and no further than [constant PUSH_MOST]
			var away := d.normalized()
			var need := FRONT * minf((EYE_CLEAR - d.length()) / maxf(away.dot(FRONT), FRONT_LEAST), PUSH_MOST)
			if need.length() > push.length():
				push = need
	return push


## How far the held blocks (as [param posed] has them, moved by [param shift]) must move for the pair never to pass into the windscreen -
## held, pushed or carried from one side of it to another: their middle kept outside a ball round the windscreen as wide as its fur and
## a block more ([constant FUR_CLEAR], [constant BLOCK_REACH]). A moving point pressed out onto a ball moves smoothly, so nothing jumps.
func _round_the_fur(posed: Dictionary, shift: Vector3) -> Vector3:
	var geo: Dictionary = _set.get("geo", {})
	if not (geo.get("fur_c") is Vector3):
		return Vector3.ZERO
	var held: Array = []
	for k in ["block_a", "block_b"]:
		if posed.has(k):
			held.append((posed[k] as Transform3D).origin + shift)
	if held.is_empty():
		return Vector3.ZERO
	var mid := Vector3.ZERO
	for p in held:
		mid += p as Vector3
	mid /= float(held.size())
	var c: Vector3 = geo["fur_c"]
	var reach := float(geo.get("fur_r", 0.088)) + float(geo.get("fur_len", 0.024)) + FUR_CLEAR + BLOCK_REACH
	var d := mid - c
	if d.length() >= reach:
		return Vector3.ZERO
	return (d.normalized() if d.length() > 1e-5 else Vector3.UP) * (reach - d.length())


## Where the eye is at show time [param t]: the creator's head as performed ([HeadPlan]), else the chair.
func _eye_at(t: float) -> Vector3:
	if _head.is_empty() or _set.is_empty():
		return StudioSet.EYE
	var lis: Transform3D = (_set["geo"] as Dictionary)["listener"]
	return lis * (HeadPlan.pose_at(_head, t)["eyes"] as Vector3)


## Where act [param i] has thing [param k] at show time [param t], null where it has it nowhere then: along its track; carried back
## to where it rests once the act ends (unless the act, made whole, does that itself); and brought from wherever the act before it
## left it - a thing another act still holds is taken from there, never from where it rests.
func _thing_at(i: int, k: String, t: float) -> Variant:
	if i >= mini(_made.size(), _t0.size()) or _t0[i] == INF or _made[i] == null:
		return null
	var m: Dictionary = _made[i]
	var tracks: Dictionary = m["tracks"]
	if not tracks.has(k):
		return null
	var u := t - _t0[i]
	var end := _t1[i]
	var secs := float(m["secs"])
	var come := float(m.get("come", StudioActs.COME))
	var go := float(m.get("go", StudioActs.GO))
	# (two hands take a pair back one after the other: the held block after the one that worked it)
	var late := float(m.get("apart", 0.0)) if k == "block_b" else 0.0
	var whole := bool((_acts[i] as Dictionary)["timed"]) and end >= _t0[i] + secs - 0.05
	# taken up again by another act soon after: never put back first - held where its work ended, the next act carrying it on from
	# there (whichever poses it later wins)
	var next := _next_taker(i, k)
	var handed := next >= 0 and _t0[next] <= _t0[i] + secs + 0.5
	if handed:
		whole = false
		end = minf(end, _t0[next])
	if u < 0.0 or t > end + go + late + 0.3 or (whole and u > secs + 0.3):
		return null
	var rests: Dictionary = (_set["geo"] as Dictionary)["rests"]
	var held_u := u if (whole or end == INF) else minf(u, end - _t0[i])
	if handed:
		held_u = minf(held_u, float(m.get("held_until", INF)))
	var xf := StudioActs.pose_at(tracks[k], minf(held_u, secs))
	if not whole and end < INF and t > end + late and rests.has(k):
		xf = StudioActs.carried(xf, rests[k], Gesture.min_jerk((t - end - late) / go))
	if u < come and rests.has(k):
		var from: Variant = null
		for j in i:
			var p: Variant = _thing_at(j, k, _t0[i])
			if p != null:
				from = p
		if from != null:
			# (two hands, one after the other: the held block first, the other [constant StudioActs.HANDS_APART] after it)
			var apart := float(m.get("apart", 0.0))
			var start := apart if k == "block_a" else 0.0
			var span := maxf(come - apart, 0.1) if apart > 0.0 else come
			xf = StudioActs.carried(from, StudioActs.pose_at(tracks[k], minf(come, secs)), Gesture.min_jerk(clampf((u - start) / span, 0.0, 1.0)))
	return xf


## The first act after act [param i] that takes up thing [param k] too, -1 for none (looked for among the few acts after it).
func _next_taker(i: int, k: String) -> int:
	for j in range(i + 1, mini(i + 6, mini(_made.size(), _t0.size()))):
		if _made[j] != null and _t0[j] != INF and ((_made[j] as Dictionary)["tracks"] as Dictionary).has(k):
			return j
	return -1


## The brush's hairs at show time [param t] ([Bristles], as a brush laying paint bends them): trailing as it is dragged across what it
## sweeps and bent over as it is pressed leaning, a moment behind as a stiff spring follows; straight in the air.
func _bend_bristles(rig: PropRig, t: float) -> void:
	var tufts := _tufts_of(rig)
	if tufts.is_empty():
		return
	var at := -1
	for i in mini(_made.size(), _t0.size()):
		if _thing_at(i, "brush", t) != null:
			at = i
	var bent := [Vector3.ZERO, 0.0]
	if at >= 0:
		var m: Dictionary = _made[at]
		var track: Dictionary = (m["tracks"] as Dictionary)["brush"]
		var press: PackedFloat32Array = (m.get("press", {}) as Dictionary).get("brush", PackedFloat32Array())
		var normals: PackedVector3Array = (m.get("normals", {}) as Dictionary).get("brush", PackedVector3Array())
		var t0 := _t0[at]
		var end := _t1[at]
		var secs := float(m["secs"])
		var tip_v: Vector3 = (_set["geo"] as Dictionary).get("brush_tip_v", Vector3(0.0, float((_set["geo"] as Dictionary)["brush_tip"]), 0.0))
		var first: Dictionary = tufts[0]
		var target := func(tt: float) -> Array:
			var u := tt - t0
			if u < 0.0 or tt > end or press.is_empty():
				return [Vector3.ZERO, 0.0]
			var x := clampi(int(minf(u, secs) * Gesture.RATE), 0, press.size() - 1)
			var p0 := StudioActs.pose_at(track, minf(maxf(u - 0.03, 0.0), secs))
			var p1 := StudioActs.pose_at(track, minf(u + 0.03, secs))
			var v := ((p1 * tip_v) - (p0 * tip_v)) / 0.06
			var axis := (p1.basis * (first["axis"] as Vector3)).normalized()
			var n: Vector3 = normals[x] if x < normals.size() else Vector3.ZERO
			var ahead := -(axis - n * axis.dot(n)) if n.length_squared() > 0.5 else Vector3.ZERO
			return Bristles.target(v, press[x], float(first["len"]), axis, ahead, float(first["bends"]))
		bent = Bristles.response(target, t)
	for tf in tufts:
		if not is_instance_valid((tf as Dictionary)["mesh"]):
			_tufts_for = null
			return
		var mi: MeshInstance3D = (tf as Dictionary)["mesh"]
		var mat: ShaderMaterial = (tf as Dictionary)["mat"]
		mat.set_shader_parameter("bristle_bend", mi.global_basis.inverse() * (bent[0] as Vector3) if mi.is_inside_tree() else Vector3.ZERO)
		mat.set_shader_parameter("bristle_splay", float(bent[1]))
		mat.set_shader_parameter("bristle_lay", Vector2.ZERO)


## [param rig]'s tufts of hairs (a brush's: [Bristles]), each `{mesh, mat, axis, len, bends}` - its hairs' way out from their root in
## the rig's own space, and how long they are (m); gathered once a make.
func _tufts_of(rig: PropRig) -> Array:
	if _tufts_for == rig:
		return _tufts
	_tufts_for = rig
	_tufts = []
	if not rig.node.is_inside_tree():
		_tufts_for = null
		return _tufts
	var inv := rig.node.global_transform.affine_inverse()
	for mi in rig.node.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).material_override as ShaderMaterial
		if mat == null or not mat.has_meta("tuft"):
			continue
		var tuft: Dictionary = mat.get_meta("tuft")
		var rel := inv * (mi as MeshInstance3D).global_transform
		_tufts.append({"mesh": mi, "mat": mat, "axis": (rel.basis * (tuft["axis"] as Vector3)).normalized(),
			"len": float(tuft["len"]) * (mi as MeshInstance3D).global_basis.get_scale().y / maxf(rig.node.global_basis.get_scale().y, 1e-4),
			"bends": Bristles.bends_of(String(tuft.get("kind", "round")))})
	return _tufts
