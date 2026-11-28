extends VBoxContainer
class_name StudioFormat

## StudioFormat - the Studio's rows on the Medium card ([StudioMedium], next/studio.md): a table show's episode played as raw footage
## from a creator's chair. A format of [MediumCard], shown where Table brings the Medium card.
##
## THE STUDIO'S SOUNDS ARE THE PIPELINE'S ([method pipeline]): one row for each act of the episode up now (its script, written by
## Table's reader with the hands' act marks in it, [StudioScript]), made on the music host from the act's motion ([StudioSounds],
## hosts/music/contact.py). Each is made on its own as soon as it is missing (after a restart, a refine, a take); a row's ⟳ makes
## ANOTHER TAKE of its act - the hands do it again,
## another performance, and its sound is made from that (`takes` in the Medium's block, [method StudioScript.with_takes]); the take
## before is kept. The playing studio takes a new take at once ([method _redress_live]).
##
## THE STUDIO'S THINGS ARE THE PIPELINE'S TOO: a row for each (the camera, its tripod, the ring light, the microphone, the blocks, the
## brush, the green screen), each a make an agent designs for this note ([RoleDesign]) and the library holds - Generate designs the
## ones not designed, a row's ⟳ designs another kind of it (the one before stays in the library). They stand on the Props card
## ([StudioProps]), refined and chosen there; the choice is kept in the Medium's block (`makes`) and the playing studio stands again
## with it ([method _redress_live]).
##
## What the acts are made on - where the microphone is, its windscreen, the camera - is the studio's own set ([StudioSet]) as its makes
## are, stood on a worker for this card again whenever a make changes.

## Its keys in the Medium's block: each act made again, its own number (as text) -> its take; each thing's make, its role -> its
## choice ([PropMakes]); and where each thing is moved from where the studio stands it, its role -> its place ([constant
## StudioSet.PLACE_FIELDS]).
const KNOBS := {"takes": {}, "makes": {}, "places": {}, "marks": {}, "levels": {}}
## How many of a thing's place changes can be undone.
const PLACE_UNDO := 40
## What a make an agent designed is asked once it is looked at in the studio.
const CHECK_ASK := "You designed this for the studio. Look at it where the studio stands it: are its named points where they belong (the scene puts it by them), is its size right beside the others, does it rest on what it should and pass into nothing? Put right whatever is wrong - its points and parts as a new version, where it stands as a place - and change nothing that is right."
## How often it looks at the episode up now and its script (seconds).
const LOOK_EVERY := 0.5

var _knobs := KNOBS.duplicate(true)
var _place_undo := {}                   # role -> its places before each change, the latest last ([method undo_place])
var _places_read := {}                  # the places as this card last held them when the block was read
var _panel: ReadingPanel = null
var _section: Section
var _maker := StudioSounds.new()
var _geo := {}
var _geo_task := -1
var _geo_box := {}
var _plan_task := -1
var _plan_box := {}
var _planned_of := ""                   # the script and takes the rows were last made from
var _script := ""                       # the episode's script, as last read
var _script_at := ""                    # ...and the file and time it was read at
var _acts: Array = []                   # its acts, with their takes
var _folder := ""                       # the note's folder, where each act's Refine conversation is kept
var _keys: Array = []                   # each act's sound's windows' keys ([method StudioSounds.make_all])
var _look_t := 0.0
var _ask_after_plan := false            # a take asked for: its sound asked as soon as its motion is made
var _show := ""                         # the show its things are designed for: the note's title and the studio
var _geo_for := "-"                     # the makes the set's geometry was stood with, as JSON
var _design_errors := {}                # a thing whose design failed -> why
var _head_key := ""                     # the show the head's phrases are kept by ([HeadBank])
var _props: StudioProps = null          # the studio's things on the Props card: their library and its versions
var _head_error := ""                   # why the head's phrases could not be designed, the last time


static func for_note(ctx: Dictionary) -> StudioFormat:
	var card := StudioFormat.new()
	card._panel = ctx.get("workspace") as ReadingPanel
	card._folder = String(ctx.get("folder", ""))
	card._maker.reads = false
	# every sound missing is made as soon as it is: after a restart, a refine, a take or a script written again, never waiting for a press
	card._maker.auto = true
	card._section = Section.new(card)
	var title := FrontMatter.field_of(FileAccess.get_file_as_string(String(ctx.get("path", ""))), "title") if not String(ctx.get("path", "")).is_empty() else ""
	card._head_key = HeadBank.key_of(ctx.get("blocks", {}) if ctx.get("blocks") is Dictionary else {}, String(ctx.get("path", "")))
	card._show = "%s%s" % [(title + ": ") if not title.is_empty() else "", Registry.blurb(Medium.REGISTRY, "studio")]
	# the studio's things, on the Props card ([StudioProps])
	card._props = StudioProps.new(card)
	if card._panel != null:
		card._panel.prop_sections.append(card._props)
		# its sounds, on the Sound card ([MadeSounds])
		card._panel.sound_sections.append(Heard.new(card))
	var about := Label.new()
	about.text = "Each episode is raw footage at the studio: its reader writes what the hands do, and every sound is made from that motion, heard from where it happens round the microphone. Its things and its sounds are on the Pipeline card; its things on the Props card too."
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(240, 0)
	card.add_child(about)
	return card


## The studio's own set as its makes are, stood off the app's thread for what the acts are made on - again where a make changed.
func _stand() -> void:
	var key := JSON.stringify([_knobs["makes"], _knobs["places"]])
	if key == _geo_for or _geo_task >= 0:
		return
	_geo_for = key
	_geo_box = {}
	var box := _geo_box
	var makes: Dictionary = (_knobs["makes"] as Dictionary).duplicate(true)
	var places: Dictionary = (_knobs["places"] as Dictionary).duplicate(true)
	_geo_task = WorkerThreadPool.add_task(func() -> void:
		var built := StudioSet.build(1, makes, places)
		box["geo"] = built.get("geo", {})
		var root: Node = built.get("root")
		if root != null:
			root.free())


func _exit_tree() -> void:
	for task in [_geo_task, _plan_task]:
		if int(task) >= 0:
			WorkerThreadPool.wait_for_task_completion(int(task))
	_geo_task = -1
	_plan_task = -1
	_maker.stop()


func _process(delta: float) -> void:
	if _geo_task >= 0 and WorkerThreadPool.is_task_completed(_geo_task):
		WorkerThreadPool.wait_for_task_completion(_geo_task)
		_geo_task = -1
		_geo = _geo_box.get("geo", {})
		# the acts made again on the set as it now stands
		_planned_of = ""
	_stand()
	if _plan_task >= 0 and WorkerThreadPool.is_task_completed(_plan_task):
		WorkerThreadPool.wait_for_task_completion(_plan_task)
		_plan_task = -1
		_keys = _plan_box.get("keys", [])
		_maker.want(_plan_box.get("specs", {}))
	_maker.pump()
	_look_t -= delta
	if _look_t > 0.0:
		return
	_look_t = LOOK_EVERY
	_read_script()
	var of := _script + JSON.stringify(_knobs["takes"]) + JSON.stringify(_knobs["marks"]) + _geo_for + _take_stamp()
	if not _geo.is_empty() and _plan_task < 0 and of != _planned_of:
		_planned_of = of
		_acts = StudioScript.with_takes(StudioScript.parse(_script, _knobs["marks"])["acts"], _knobs["takes"])
		_plan_box = {}
		var box := _plan_box
		var acts := _acts.duplicate(true)
		var geo := _geo
		# an act that goes on is made as long as a steady voice would take to reach where it ends; the playing studio makes more
		# where the words run longer
		var parsed := StudioScript.parse(_script, _knobs["marks"])
		var horizons := StudioScript.lengths(parsed)
		var take := _take_path()
		_plan_task = WorkerThreadPool.add_task(func() -> void:
			# ...and, where the episode has a take, as long as the playing studio will make it from the take's own timing (and a step
			# more), so every window an export plays is made here - a window does not change with how long its act is made
			var timed := take_lengths(parsed, take)
			for k in timed:
				horizons[k] = maxf(float(horizons.get(k, 0.0)), float(timed[k]))
			box.merge(StudioSounds.make_all(acts, geo, horizons), true))


## The episode's take kept, "" for none ([method EpisodeFeed.take]).
func _take_path() -> String:
	var feed: EpisodeFeed = _panel.episode_feed() if _panel != null and is_instance_valid(_panel) else null
	var path := feed.take() if feed != null else ""
	return path if not path.is_empty() and FileAccess.file_exists(path) else ""


## The take as one value to tell a change by: its file and when it was written.
func _take_stamp() -> String:
	var path := _take_path()
	return "%s@%d" % [path, FileAccess.get_modified_time(path)] if not path.is_empty() else ""


## How long each act that goes on ([param parsed]'s, by its index) is made by the playing studio when the voice is the take at
## [param take] (its sidecar's words): from the word it begins at to the word it ends at (or past the last), less nothing and with
## the studio's own spare, rounded up to its steps and one step more ([constant StudioMedium.HORIZON_SPARE], [constant
## StudioMedium.HORIZON_STEP]). `{}` with no take. Pure; a worker's.
static func take_lengths(parsed: Dictionary, take: String) -> Dictionary:
	var out := {}
	if take.is_empty() or not FileAccess.file_exists(take.get_basename() + ".json"):
		return out
	var side: Variant = JSON.parse_string(FileAccess.get_file_as_string(take.get_basename() + ".json"))
	if not (side is Dictionary) or not ((side as Dictionary).get("words") is Array):
		return out
	var f := ReadingFollower.new()
	f.reset(parsed["spoken"])
	f.extend((side as Dictionary)["words"])
	var n := f.said0.size()
	if n == 0:
		return out
	var last := f.st1[n - 1] if f.st1[n - 1] != ReadingFollower.NO_TIME else 0.0
	for a in parsed["acts"]:
		var d: Dictionary = a
		if bool(d["timed"]):
			continue
		var w := int(d["after"])
		var t0 := f.said0[w] if w < n and f.said0[w] != ReadingFollower.NO_TIME else last
		var e := int(d["end"])
		var t1 := f.said0[e] if e >= 0 and e < n and f.said0[e] != ReadingFollower.NO_TIME else last + StudioScript.PAST_LAST
		var need := maxf(t1 - t0, 0.0) + StudioSounds.RELEASE + 1.0
		out[int(d["i"])] = ceilf((need + StudioMedium.HORIZON_SPARE) / StudioMedium.HORIZON_STEP) * StudioMedium.HORIZON_STEP + StudioMedium.HORIZON_STEP
	return out


## The episode up now's script (its folder's `script.md`), read again where the file changed; "" while there is none.
func _read_script() -> void:
	var feed: EpisodeFeed = _panel.episode_feed() if _panel != null and is_instance_valid(_panel) else null
	var dir := feed.folder() if feed != null else ""
	var path := dir.path_join("script.md") if not dir.is_empty() else ""
	var at := "%s@%d" % [path, FileAccess.get_modified_time(path) if not path.is_empty() and FileAccess.file_exists(path) else 0]
	if at == _script_at:
		return
	_script_at = at
	_script = FileAccess.get_file_as_string(path) if not path.is_empty() and FileAccess.file_exists(path) else ""


# --- the block ---------------------------------------------------------------------------------------------------------

func capture() -> Dictionary:
	var out := {}
	for k in ["takes", "makes", "places", "marks", "levels"]:
		if not (_knobs[k] as Dictionary).is_empty():
			out[k] = (_knobs[k] as Dictionary).duplicate(true)
	return out


func apply(cfg: Dictionary) -> void:
	_knobs = KNOBS.duplicate(true)
	if cfg.get("takes") is Dictionary:
		for k in (cfg["takes"] as Dictionary):
			var n := int((cfg["takes"] as Dictionary)[k])
			if n > 0:
				_knobs["takes"][String(k)] = n
	_knobs["makes"] = StudioMedium.makes_of(cfg)
	var was: Dictionary = _places_read
	_knobs["places"] = StudioSet.places_of(cfg)
	_places_read = (_knobs["places"] as Dictionary).duplicate(true)
	# (a place the note's file says otherwise than this card held, said in the log: what a re-read changed)
	for role in StudioSet.ROLES:
		if not was.is_empty() and JSON.stringify(was.get(role, {})) != JSON.stringify(_places_read.get(role, {})):
			print("ghost: studio: %s placed %s, read from the note (it was %s)" % [role, JSON.stringify(_places_read.get(role, {})),
				JSON.stringify(was.get(role, {}))])
	_knobs["marks"] = StudioMedium.marks_of(cfg)
	_knobs["levels"] = StudioMedium.levels_of(cfg)


# --- the studio's things ---------------------------------------------------------------------------------------------

## The make playing role [param role] (`{}`: none chosen, [PropMakes]).
func make_of(role: String) -> Dictionary:
	return ((_knobs["makes"] as Dictionary).get(role, {}) as Dictionary).duplicate(true)


## Role [param role] played by [param choice] from now: kept in the block, the playing studio stood again with it. "" done, else why
## not.
func choose(role: String, choice: Dictionary) -> String:
	if not PropMakes.valid_for(role, choice) or not StudioSet.ROLES.has(role):
		return "nothing here takes that"
	if choice.is_empty():
		(_knobs["makes"] as Dictionary).erase(role)
	else:
		_knobs["makes"][role] = PropMakes.chosen(choice)
	_design_errors.erase(role)
	if _panel != null:
		_panel.touch()
	_redress_live()
	return ""


## Whether the acts are about to be made again or are being made: the script or the set changed since they were last planned.
func planning() -> bool:
	return _plan_task >= 0 or (not _script.is_empty() and not _geo.is_empty() and _planned_of != _script + JSON.stringify(_knobs["takes"]) + JSON.stringify(_knobs["marks"]) + _geo_for)


## Whether the show's head has its phrases ([HeadBank]).
func head_designed() -> bool:
	return not HeadBank.read(_head_key).is_empty()


## The show's head phrases designed again by an agent ([HeadDesign]): kept for the show, the ones before a version back; the takes
## placed by them said again.
func design_head() -> void:
	if HeadDesign.running.has(_head_key) or _head_key.is_empty():
		return
	_head_error = ""
	var pick := AgentPick.last_for("refine_prop")
	if String(pick.get("agent", "")).is_empty():
		pick = {"agent": "claude"}
	var got: Dictionary = await HeadDesign.design(_head_key, _show, pick)
	if not is_instance_valid(self):
		return
	if got.has("error"):
		_head_error = String(got["error"])
	elif _panel != null:
		_panel.touch()


## Every thing's make, as the block keeps them.
func make_of_all() -> Dictionary:
	return (_knobs["makes"] as Dictionary).duplicate(true)


## Every thing's place, as the block keeps them.
func places_all() -> Dictionary:
	return (_knobs["places"] as Dictionary).duplicate(true)


## Where role [param role]'s thing is moved from where the studio stands it ({} for nowhere, [constant StudioSet.PLACE_FIELDS]).
func place_of(role: String) -> Dictionary:
	return ((_knobs["places"] as Dictionary).get(role, {}) as Dictionary).duplicate(true)


## Role [param role]'s thing placed at [param place] from now (no version of its prop: the place is this note's): kept in the block,
## the playing studio stood again with it. "" done, else why not.
func set_place(role: String, place: Dictionary, why := "by hand") -> String:
	if not StudioSet.ROLES.has(role):
		return "nothing here takes that"
	var p := StudioSet.place_of(place)
	var was := place_of(role)
	if JSON.stringify(p) == JSON.stringify(was):
		return ""
	# (each change kept to be undone, a thing at a time, and said in the log with what made it)
	var back: Array = _place_undo.get(role, [])
	back.append(was)
	if back.size() > PLACE_UNDO:
		back.pop_front()
	_place_undo[role] = back
	print("ghost: studio: %s placed %s, %s (it was %s)" % [role, JSON.stringify(p) if not p.is_empty() else "where the studio stands it", why,
		JSON.stringify(was) if not was.is_empty() else "where the studio stands it"])
	if p.is_empty():
		(_knobs["places"] as Dictionary).erase(role)
	else:
		_knobs["places"][role] = p
	_places_read = (_knobs["places"] as Dictionary).duplicate(true)
	if _panel != null:
		_panel.touch()
	_redress_live()
	return ""


## Whether role [param role]'s last place change can be undone.
func can_undo_place(role: String) -> bool:
	return not (_place_undo.get(role, []) as Array).is_empty()


## Role [param role]'s last place change undone: back where it was before it. "" done, else why not.
func undo_place(role: String) -> String:
	var back: Array = _place_undo.get(role, [])
	if back.is_empty():
		return "nothing to undo"
	var p: Dictionary = back.pop_back()
	var err := set_place(role, p, "undone")
	# (the undo is no change to be undone itself)
	(_place_undo[role] as Array).pop_back()
	return err


## Whether role [param role] has a make that can play it now.
func designed(role: String) -> bool:
	var c := make_of(role)
	return not PropMakes.spec(role, c, 1).is_empty()


## The key [method design] runs role [param role]'s design under ([member RoleDesign.running]).
func _design_key(role: String) -> String:
	return "%s|%s" % [_show.get_slice(":", 0), role]


## Role [param role] designed by an agent and played by what it makes; [param another] asks for another kind of the make playing it
## now (which stays in the library).
func design(role: String, another := false) -> void:
	if RoleDesign.running.has(_design_key(role)):
		return
	_design_errors.erase(role)
	var others: Array = []
	for r in StudioSet.ROLES:
		var e := ThingLibrary.read(String(make_of(String(r)).get("kept", "")))
		if String(r) != role and not e.is_empty():
			others.append({"name": String(e["name"]), "line": String(e.get("line", ""))})
	var was := {}
	if another:
		var e := ThingLibrary.read(String(make_of(role).get("kept", "")))
		if not e.is_empty():
			was = {"name": String(e["name"]), "line": String(e.get("line", ""))}
	var pick := AgentPick.last_for("refine_prop")
	if String(pick.get("agent", "")).is_empty():
		pick = {"agent": "claude"}
	var got: Dictionary = await RoleDesign.design(_design_key(role), role, _show, pick, others, was)
	if not is_instance_valid(self):
		return
	if not got.has("name"):
		_design_errors[role] = String(got.get("error", "it could not be designed"))
		return
	var name := String(got["name"])
	choose(role, {"kept": name})
	await _check_design(role, name, pick)


## What an agent designed for role [param role] (kept as [param name]) looked at where the studio stands it, by [param pick]: shown the
## prop and the studio round it ([StudioScene]), it puts right what is wrong - a point, a size, how it rests - as a refine does: a
## corrected version used, a place kept.
func _check_design(role: String, name: String, pick: Dictionary) -> void:
	if _props == null:
		return
	var versions := _props.library.versions_of()
	var e := ThingLibrary.read(name)
	if e.is_empty() or versions == null:
		return
	RoleDesign.running[_design_key(role)] = {"line": "looking at it in the studio"}
	var got: Dictionary = await versions.refine(name, int(e.get("used", 0)), CHECK_ASK, pick,
		func(line: String) -> void: RoleDesign.running[_design_key(role)] = {"line": "looking at it in the studio: " + line},
		_props.scene_of("role:" + role))
	RoleDesign.running.erase(_design_key(role))
	if not is_instance_valid(self):
		return
	if int(got.get("index", -1)) >= 0:
		ThingLibrary.use_version(name, int(got["index"]))
		_props.library.refresh()
		choose(role, {"kept": String(ThingLibrary.read(name).get("name", name))})


## Where act [param i]'s sound stands, all its windows together ([constant PipelineRow.STATES]): made once every one is, failed where
## one could not be, running while one is being made.
func state_of_act(i: int) -> String:
	var ks: PackedStringArray = _keys[i] if i < _keys.size() and _keys[i] != null else PackedStringArray()
	if ks.is_empty():
		return "queued"
	var states := {}
	for k in ks:
		states[_maker.state_of(k)] = true
	for st in ["failed", "running", "queued", "missing"]:
		if states.has(st):
			return st
	return "made"


## Why act [param i]'s sound could not be made: its first window's reason.
func why_act(i: int) -> String:
	for k in (_keys[i] if i < _keys.size() and _keys[i] != null else PackedStringArray()):
		if not _maker.why(k).is_empty():
			return _maker.why(k)
	return ""


## Act [param i] named as a row says it: its number, what the hand does, which hand, and its take.
func act_name(i: int) -> String:
	var a: Dictionary = _acts[i]
	return "%d. %s %s, %s, %s hand%s%s" % [i + 1, String(a["verb"]), String(a["thing"]), String(a["side"]), String(a.get("hand", "right")),
		"s" if String(a.get("hand", "")) == "both" else "", (" (take %d)" % (int(a.get("take", 0)) + 1)) if int(a.get("take", 0)) > 0 else ""]


## How long act [param i] runs, in words: its seconds, or until what ends it.
func length_line(i: int) -> String:
	var a: Dictionary = _acts[i]
	var n := (_keys[i] as PackedStringArray).size() if i < _keys.size() and _keys[i] != null else 0
	var windows := " in %d windows" % n if n > 1 else ""
	match String(a.get("ends", "")):
		"mark":
			return "goes on under the words to its closing mark" + windows
		"hand":
			return "goes on under the words until the hand turns to the next act" + windows
		"end":
			return "goes on under the words to the end" + windows
	return "%d s%s%s" % [roundi(float(a["secs"])), ", alone" if bool(a.get("alone", false)) else "", windows]


## The conversation about act [param i]'s sound ([TextRefine], [WriterChat]): a writer who changes the act's words - what the hands
## do, from which its sound is made - kept in the block by the act's own number, and played at once; the script stays as written.
func chat_for(i: int) -> WriterChat:
	if i < 0 or i >= _acts.size():
		return null
	var own := str(int((_acts[i] as Dictionary).get("own", (_acts[i] as Dictionary)["seed"])))
	var chat := WriterChat.at(TextRefine.folder_for(_folder, "act-" + own))
	var verb := String((_acts[i] as Dictionary)["verb"])
	chat.read_text = func() -> String: return _words_of(own)
	chat.apply = func(at: int, gone: int, put: String) -> void:
		var was := _words_of(own)
		set_words(own, was.substr(0, at) + put + was.substr(at + gone))
	chat.about = func() -> Dictionary:
		return {"what": "the sound of act %d (%s)" % [i + 1, verb], "title": "", "act": true, "verb": verb,
			"vocabulary": StudioActs.vocabulary(), "parts": [], "marks": [], "has_parts": false, "has_marks": false}
	return chat


## Act (by its own number [param own]) words as they stand: as a Refine changed them, else as the script has them.
func _words_of(own: String) -> String:
	if (_knobs["marks"] as Dictionary).has(own):
		return String(_knobs["marks"][own])
	for a in _acts:
		if str(int((a as Dictionary).get("own", (a as Dictionary)["seed"]))) == own:
			return String((a as Dictionary)["words"])
	return ""


## Act [param own]'s words set to [param words] (its verb kept): kept in the block, the act made again from them and played at once.
func set_words(own: String, words: String) -> void:
	_knobs["marks"][own] = words.strip_edges()
	if _panel != null:
		_panel.touch()
	_redress_live()
	_ask_after_plan = true


## How loud and how muffled act [param i]'s sound is heard (-1: every act's): `{db, muffle}` ([method StudioMedium.levels_of]).
func level_of(i: int) -> Dictionary:
	var d: Dictionary = (_knobs["levels"] as Dictionary).get(_level_key(i), {})
	return {"db": float(d.get("db", 0.0)), "muffle": float(d.get("muffle", 0.0))}


## Act [param i]'s sound (-1: every act's) heard [param db] louder and [param muffle] muffled from now: kept in the block, heard at
## once, nothing made again.
func set_level(i: int, db: float, muffle: float) -> void:
	var k := _level_key(i)
	if k.is_empty():
		return
	var levels: Dictionary = _knobs["levels"]
	levels[k] = {"db": db, "muffle": muffle}
	_knobs["levels"] = StudioMedium.levels_of({"levels": levels})
	if _panel != null:
		_panel.touch()
	_redress_live()


## The key act [param i]'s level is kept under: its own number, "all" for -1, "" for none.
func _level_key(i: int) -> String:
	if i < 0:
		return "all"
	if i >= _acts.size():
		return ""
	return str(int((_acts[i] as Dictionary).get("own", (_acts[i] as Dictionary)["seed"])))


## Act [param i] made again: its next take, kept in the block and played at once.
func _another_take(i: int) -> void:
	if i < 0 or i >= _acts.size():
		return
	var own := str(int((_acts[i] as Dictionary).get("own", (_acts[i] as Dictionary)["seed"])))
	_knobs["takes"][own] = int((_knobs["takes"] as Dictionary).get(own, 0)) + 1
	if _panel != null:
		_panel.touch()
	_redress_live()
	# its sound asked for as soon as its new motion is made
	_section.tell("Another take of act %d: the hands do it again, and its sound is made from that." % (i + 1))
	_ask_after_plan = true


## The takes and the makes handed to the reading's live document as they stand, so the playing studio takes them at once.
func _redress_live() -> void:
	var subs: Node = _panel.subtitles if _panel != null and is_instance_valid(_panel) else null
	if subs == null or not is_instance_valid(subs):
		return
	var doc: Dictionary = subs.get("document")
	var block: Dictionary = doc.get("medium", {}) if doc.get("medium") is Dictionary else {}
	block["takes"] = (_knobs["takes"] as Dictionary).duplicate(true)
	block["makes"] = (_knobs["makes"] as Dictionary).duplicate(true)
	block["places"] = (_knobs["places"] as Dictionary).duplicate(true)
	block["marks"] = (_knobs["marks"] as Dictionary).duplicate(true)
	block["levels"] = (_knobs["levels"] as Dictionary).duplicate(true)
	doc["medium"] = block


# --- the Pipeline's ----------------------------------------------------------------------------------------------------

## What it hands the note's Pipeline card.
func pipeline() -> PipelineSection:
	return _section


## The studio's things, a row each, and its sounds, a row an act.
## The studio's sounds as the Sound card lists them: each act's, in the order they are heard, made from its motion ([ShowSounds]).
class Heard extends ShowSounds:
	var card: StudioFormat

	func _init(c: StudioFormat) -> void:
		card = c

	func heading() -> String:
		return "Made from the hands' acts"

	func chat_of(key: String) -> WriterChat:
		return card.chat_for(int(key.trim_prefix("act:")) - 1) if key.begins_with("act:") else null

	func level_of(key: String) -> Dictionary:
		return card.level_of(int(key.trim_prefix("act:")) - 1 if key.begins_with("act:") else -1)

	func set_level(key: String, db: float, muffle: float) -> void:
		card.set_level(int(key.trim_prefix("act:")) - 1 if key.begins_with("act:") else -1, db, muffle)

	func sounds() -> Array:
		var out: Array = []
		for i in card._acts.size():
			var a: Dictionary = card._acts[i]
			var ks: PackedStringArray = card._keys[i] if i < card._keys.size() else PackedStringArray()
			var state := card.state_of_act(i)
			var line: String = {"made": card.length_line(i), "running": "being made", "failed": card.why_act(i)}.get(state, "not made yet")
			out.append({"key": "act:%d" % (i + 1), "name": card.act_name(i), "line": line, "tip": String(a["words"]),
				"path": ProjectSettings.globalize_path(StudioSounds.wav_of(ks[0])) if state == "made" and not ks.is_empty() else ""})
		return out


class Section extends PipelineSection:
	var card: StudioFormat

	func _init(c: StudioFormat) -> void:
		card = c
		owner = c
		title = "The studio"

	func shown() -> bool:
		return true

	func tick() -> void:
		# a take asked for: made once its new motion is
		if card._ask_after_plan and card._plan_task < 0 and card._planned_of == card._script + JSON.stringify(card._knobs["takes"]) + card._geo_for:
			card._ask_after_plan = false
			card._maker.ask_missing()

	func rows() -> Array:
		var out: Array = _thing_rows()
		out.append(_head_row())
		for i in card._acts.size():
			var a: Dictionary = card._acts[i]
			var r := PipelineRow.new()
			r.key = "act:%d" % (i + 1)
			r.group = "Sounds"
			r.label = card.act_name(i)
			var key := "act" if i < card._keys.size() else ""
			r.state = card.state_of_act(i)
			r.said = card.why_act(i) if r.state == "failed" else "%s - %s" % [card.length_line(i), String(a["words"])]
			r.again = "Another take: the hands do this act again - another performance, heard from its motion. The take before is kept."
			r.open = not key.is_empty()
			var at := i
			r.redo = func() -> void: card._another_take(at)
			out.append(r)
		return out

	## The head's phrases: designed, being designed, failed, or not designed yet.
	func _head_row() -> PipelineRow:
		var r := PipelineRow.new()
		r.key = "head"
		r.group = "Things"
		r.label = "The head's phrases"
		var running: Dictionary = HeadDesign.running.get(card._head_key, {})
		var bank := HeadBank.read(card._head_key)
		if not running.is_empty():
			r.state = "running"
			r.said = String(running.get("line", ""))
		elif not card._head_error.is_empty():
			r.state = "failed"
			r.said = card._head_error
		else:
			r.state = "made" if not bank.is_empty() else "missing"
			r.said = "%d habits: %s" % [bank.size(), ", ".join(PackedStringArray(bank.map(func(p: Dictionary) -> String: return String(p["name"]))))] \
				if not bank.is_empty() else "How the creator's head moves: designed by an agent for the show, measured and put right."
		r.again = "Design the head's phrases again: an agent writes the show's habits anew. The ones before are kept a version back." if not bank.is_empty() \
			else "Have an agent design the head's phrases."
		r.asks = "The takes placed by the head's phrases now are said again." if not bank.is_empty() else ""
		r.open = running.is_empty()
		r.redo = func() -> void: card.design_head()
		return r

	## A row for each of the studio's things: designed, being designed, failed, or not designed yet.
	func _thing_rows() -> Array:
		var out: Array = []
		for role in StudioSet.ROLES:
			var rl := String(role)
			var r := PipelineRow.new()
			r.key = "thing:" + rl
			r.group = "Things"
			var made := card.designed(rl)
			r.label = PropMakes.name_of(rl, card.make_of(rl)) if made else String((PropMakes.ROLES[rl] as Dictionary)["label"])
			var running: Dictionary = RoleDesign.running.get(card._design_key(rl), {})
			if not running.is_empty():
				r.state = "running"
				r.said = String(running.get("line", ""))
			elif card._design_errors.has(rl):
				r.state = "failed"
				r.said = String(card._design_errors[rl])
			else:
				r.state = "made" if made else "missing"
				r.said = String((PropMakes.ROLES[rl] as Dictionary)["blurb"]) if not made else "refine it or choose another on the Props card"
			r.again = "Another kind: an agent designs another make of it, and the studio uses that. The one before stays in your library." if made \
				else "Have an agent design it."
			r.open = running.is_empty()
			r.redo = func() -> void: card.design(rl, made)
			out.append(r)
		return out

	func line() -> String:
		var things := 0
		for role in StudioSet.ROLES:
			if card.designed(String(role)):
				things += 1
		var made := 0
		for i in card._keys.size():
			if card.state_of_act(i) == "made":
				made += 1
		var out := "%d of %d things designed" % [things, StudioSet.ROLES.size()]
		return out if card._keys.is_empty() else "%s, %d of %d sounds made" % [out, made, card._keys.size()]

	func make() -> void:
		# the script as it is now, and its acts planned at once: a script written since is made into sounds in this same press
		card._read_script()
		card._look_t = 0.0
		if not card.head_designed():
			card.design_head()
		# the things first: the sounds are made on the set as they stand
		var wanting := false
		for role in StudioSet.ROLES:
			if not card.designed(String(role)) and not RoleDesign.running.has(card._design_key(String(role))):
				wanting = true
				card.design(String(role))
		if not wanting:
			card._maker.ask_missing()

	func make_tip() -> String:
		return "Design the studio's things and the head's phrases not designed yet, each by an agent; then make the sounds not made, each from its act's motion."

	func busy() -> bool:
		if HeadDesign.running.has(card._head_key) or card.planning():
			return true
		for role in StudioSet.ROLES:
			if RoleDesign.running.has(card._design_key(String(role))):
				return true
		return card._maker.busy()

	func export_blocked() -> String:
		var waiting := 0
		for i in card._keys.size():
			if card.state_of_act(i) != "made":
				waiting += 1
		if waiting > 0 or card._maker.busy() or card.planning():
			return "the studio's sounds are still being made (%d act%s waiting): an export plays only what is made - wait for the Pipeline's studio rows, or press Generate" % [waiting, "" if waiting == 1 else "s"]
		return ""

	func missing() -> bool:
		if not card.head_designed():
			return true
		for role in StudioSet.ROLES:
			if not card.designed(String(role)):
				return true
		for i in card._keys.size():
			if card.state_of_act(i) != "made":
				return true
		return card._keys.is_empty() and not card._script.is_empty()

	func stop() -> void:
		card._maker.stop()
