extends VBoxContainer
class_name StudioFormat

## StudioFormat - the Studio's rows on the Medium card ([StudioMedium], next/studio.md): a table show's episode played as raw footage
## from a creator's chair. A format of [MediumCard], shown where Table brings the Medium card.
##
## THE STUDIO'S SOUNDS ARE THE PIPELINE'S ([method pipeline]): one row for each act of the episode up now (its script, written by
## Table's reader with the hands' act marks in it, [StudioScript]), made on the music host from the act's motion ([StudioSounds],
## hosts/music/contact.py). Generate makes the ones not made; a row's ⟳ makes ANOTHER TAKE of its act - the hands do it again,
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
const KNOBS := {"takes": {}, "makes": {}, "places": {}}
## What a make an agent designed is asked once it is looked at in the studio.
const CHECK_ASK := "You designed this for the studio. Look at it where the studio stands it: are its named points where they belong (the scene puts it by them), is its size right beside the others, does it rest on what it should and pass into nothing? Put right whatever is wrong - its points and parts as a new version, where it stands as a place - and change nothing that is right."
## How often it looks at the episode up now and its script (seconds).
const LOOK_EVERY := 0.5

var _knobs := KNOBS.duplicate(true)
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
var _keys := PackedStringArray()        # each act's sound's key
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
	card._maker.reads = false
	card._maker.auto = false
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
		_keys = _plan_box.get("keys", PackedStringArray())
		_maker.want(_plan_box.get("specs", {}))
	_maker.pump()
	_look_t -= delta
	if _look_t > 0.0:
		return
	_look_t = LOOK_EVERY
	_read_script()
	var of := _script + JSON.stringify(_knobs["takes"]) + _geo_for
	if not _geo.is_empty() and _plan_task < 0 and of != _planned_of:
		_planned_of = of
		_acts = StudioScript.with_takes(StudioScript.parse(_script)["acts"], _knobs["takes"])
		_plan_box = {}
		var box := _plan_box
		var acts := _acts.duplicate(true)
		var geo := _geo
		_plan_task = WorkerThreadPool.add_task(func() -> void: box.merge(StudioSounds.make_all(acts, geo), true))


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
	for k in ["takes", "makes", "places"]:
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
	_knobs["places"] = StudioSet.places_of(cfg)


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
	return _plan_task >= 0 or (not _script.is_empty() and not _geo.is_empty() and _planned_of != _script + JSON.stringify(_knobs["takes"]) + _geo_for)


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
func set_place(role: String, place: Dictionary) -> String:
	if not StudioSet.ROLES.has(role):
		return "nothing here takes that"
	var p := StudioSet.place_of(place)
	if p.is_empty():
		(_knobs["places"] as Dictionary).erase(role)
	else:
		_knobs["places"][role] = p
	if _panel != null:
		_panel.touch()
	_redress_live()
	return ""


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

	func sounds() -> Array:
		var out: Array = []
		for i in card._acts.size():
			var a: Dictionary = card._acts[i]
			var key := card._keys[i] if i < card._keys.size() else ""
			var state := card._maker.state_of(key) if not key.is_empty() else "queued"
			var line: String = {"made": "made, %d s" % roundi(float(a["secs"])), "running": "being made", "failed": card._maker.why(key)}.get(state, "not made yet")
			out.append({"key": "act:%d" % (i + 1), "name": "%d. %s %s, %s%s" % [i + 1, String(a["verb"]), String(a["thing"]), String(a["side"]),
					(" (take %d)" % (int(a.get("take", 0)) + 1)) if int(a.get("take", 0)) > 0 else ""],
				"line": line, "tip": String(a["words"]),
				"path": ProjectSettings.globalize_path(StudioSounds.wav_of(key)) if state == "made" else ""})
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
			r.label = "%d. %s %s, %s, %ds%s" % [i + 1, String(a["verb"]), String(a["thing"]), String(a["side"]), roundi(float(a["secs"])),
				(" (take %d)" % (int(a.get("take", 0)) + 1)) if int(a.get("take", 0)) > 0 else ""]
			var key := card._keys[i] if i < card._keys.size() else ""
			r.state = card._maker.state_of(key) if not key.is_empty() else "queued"
			r.said = card._maker.why(key) if r.state == "failed" else String(a["words"])
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
		for k in card._keys:
			if card._maker.state_of(k) == "made":
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

	func missing() -> bool:
		if not card.head_designed():
			return true
		for role in StudioSet.ROLES:
			if not card.designed(String(role)):
				return true
		for k in card._keys:
			if card._maker.state_of(k) != "made":
				return true
		return card._keys.is_empty() and not card._script.is_empty()

	func stop() -> void:
		card._maker.stop()
