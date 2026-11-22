extends RefCounted
class_name CartoonProducer

## CartoonProducer - what agents make for a cartoon (next/cartoon.md), one note's: each character RIGGED from its drawing by the rigger
## ([RiggerTools], rules/cartoon/rigger.yaml) onto the library's `puppets` shelf, each set PAINTED in the cast's own drawing style
## (rules/cartoon/set_painter.yaml, the cast's drawings its references; a set row's `from` names a set it is painted from, the same place
## changed) onto the `sets` shelf, a set's GROUND LINE (where its
## characters walk across it, from its `ground` words) traced by the surveyor ([SurveyorTools], rules/cartoon/surveyor.yaml), and the STORYBOARD written by the director
## (rules/cartoon/director.yaml) into the note's folder ([NoteStoryboard]), where the note's show plays it. Each is one agent job
## ([AgentJobs]); [method pump] lands what ended. A storyboard that will not play is sent back once with what was wrong with it.
##
## What it works from is the note's `cartoon:` block: `cast` [{name, picture | describe, about, height, drawings, asks, rigid, looks, align}]
## (`asks`: a drawing's own words in place of the sheet's; `rigid`: every drawing held whole, no rigger; `looks`: left or right, which
## way a character seen from its side looks as drawn; `thing`: furniture or a prop, a piece of the scene placed in depth among the
## characters, not one of them; `reaches`: left or right, a part that comes in from that edge of the frame - an arm - kept running off
## it ([method framed]); `align: width`: drawings set to
## one width rather than height - a bed someone sits up in), `sets` [{name, place, ground, from}], `seconds`, `silent` (no sound: talking is only seen) and `loops` (played round and round: it ends as it begins). Puppets and sets are named, so every note can use them (a Dex shelf each).

## How long an agent may take (s): a rigger looks at a dozen pictures; a surveyor at a few; a director writes one reply.
const RIG_MOST := 2400
const TRACE_MOST := 900
const WRITE_MOST := 900
## A shot FRAMED on someone (its camera's `frame`: an id, or several): `face` holds its head (the top of its drawing down to its
## neck, where its head bone joins - else a chin as far below its eyes as they are below its top, times `chin`) with room round it
## (`room`), `chest` its head and shoulders (at
## least `tall` of its height, its head near the frame's top), `full` its whole body; and the lens. One drawn with no eyes to aim
## at is held whole, as `full`.
const FRAMES := {"face": {"room": 1.35, "chin": 0.6, "fov": 40.0}, "chest": {"room": 2.2, "chin": 0.6, "tall": 0.9, "fov": 40.0},
	"full": {"room": 1.15, "fov": 48.0}}
## The frame's width over its height, for fitting several framed side by side; and the widest a note is shown at, which an arm that
## reaches in from an edge is kept past.
const FRAME_ASPECT := 4.0 / 3.0
const WIDEST := 16.0 / 9.0
## The slowest a character may go across on foot, in its own heights a second (a tiptoe, else a walk or a run): slower reads as a
## crawl, and a cartoon's timing is brisk.
const SLOWEST := {"tiptoe": 0.6, "": 0.9}
## How close two puppets may start, as a share of half their two widths, before they stand on each other.
const CROWD := 0.75
## A cartoon's length unless its block says, and how far a storyboard may stray from it.
const SECONDS := 30.0
const STRAY := [0.6, 1.6]
## The verbs a director is told of, each in a few words; their settings are [constant Actions.ARGS]' rows.
const VERBS := {
	"move": "a puppet goes to a place, on foot (its gait swings its legs and arms at the pace it goes)",
	"talk": "its jaw chatters and its head nods for the window - a line said, unheard",
	"pose": "it takes a pose and holds it (or, with ease spike, strikes it and comes back)",
	"face": "it turns: left or right (in profile), toward another actor, front (to us) or back (away); it holds that view until turned again",
	"feel": "it shows a mood from now on (scared, angry, laughing, dead - knocked out cold, X's for eyes), or none, where it was drawn in it",
	"strike": "it winds up and hits another, who reels; a mark where it lands",
	"hit": "it is hit (from another actor's side, or left or right): recoils, spins, eyes pop",
	"hop": "it crouches, springs up and lands, in place or to a place",
	"shake": "it shakes for the window: fear, rage",
	"fx": "a mark drawn on it a moment",
	"blink": "it blinks",
	"ramp": "eases a value across the window (`fade` 0 to 1 brings it in, 1 to 0 takes it away; `shade` 0 to 1 darkens it to a silhouette)",
	"set": "sets a value at once (`fade`, `shade`)",
	"emerge": "it comes out of another - a soul out of a body: small and faint at their middle, it grows, comes clear and rises out of them",
	"change": "a backdrop shows another painted set of the same place from now on (a door opened, a light switched on), at a moment",
}

var note_path := ""
var folder := ""
var block := {}
## Who writes and who paints: {agent, model, effort} each.
var writer := {"agent": "claude", "model": "", "effort": ""}
var painter := {"agent": "codex", "model": "", "effort": ""}

var _work := {}                      # key ("rig:NAME", "set:NAME", "board", "paint:NAME:KEY", ...) -> {job, kind, ...}
var _sheets := {}                    # a character's model sheet being made: name -> {picture, about, made: {key: step}, rigs: {view: ...}}
var _errors := {}                    # key -> the last failure, a sentence
var _widths := {}                    # a rig's width over its height, read once
var _faces := {}                     # a rig's face: where its eyes are, from its feet, in shares of its height (x across, y up), read once


func _init(path: String, note_folder: String, cartoon: Dictionary) -> void:
	note_path = path
	folder = note_folder
	block = cartoon


## The block's cast, each {name, picture, about, height}.
func cast() -> Array:
	return (block.get("cast", []) as Array).filter(func(c: Variant) -> bool: return c is Dictionary and not String((c as Dictionary).get("name", "")).is_empty())


## The block's sets, each {name, place}.
func sets() -> Array:
	return (block.get("sets", []) as Array).filter(func(c: Variant) -> bool: return c is Dictionary and not String((c as Dictionary).get("name", "")).is_empty())


## Whether [param key]'s work is going (a character's sheet counts while any of its drawings is being made).
func busy(key := "") -> bool:
	if key.is_empty():
		return not _work.is_empty() or not _sheets.is_empty()
	if key.begins_with("rig:") and _sheets.has(key.trim_prefix("rig:")):
		return true
	return _work.has(key)


## What [param key]'s last run said, "" for nothing wrong.
func error_of(key: String) -> String:
	return String(_errors.get(key, ""))


## What [param key]'s agent is doing now ("" for nothing).
func activity(key: String) -> String:
	if key.begins_with("rig:") and _sheets.has(key.trim_prefix("rig:")):
		return String((_sheets[key.trim_prefix("rig:")] as Dictionary).get("said", "making its model sheet"))
	return AgentJobs.activity(String((_work[key] as Dictionary)["job"])) if _work.has(key) and (_work[key] as Dictionary).has("job") else ""


# --- what is made ----------------------------------------------------------------------------------------------------------

## Whether the character [param name] is rigged (its puppet on the shelf: a model sheet, or one drawing).
static func rigged(name: String) -> bool:
	var f := PuppetRig.folder_of(name)
	return FileAccess.file_exists(f.path_join(PuppetSheet.FILE)) or FileAccess.file_exists(f.path_join(PuppetRig.FILE))


## Whether the set [param name] is painted.
static func painted(name: String) -> bool:
	return not PuppetRig.set_file(name).is_empty()


## Whether the set [param name] keeps a ground line.
static func traced(name: String) -> bool:
	var file := PuppetRig.set_file(name)
	return not file.is_empty() and FileAccess.file_exists(PuppetRig.ground_file(file))


## Whether the set row [param s] asks for a ground line (its `ground` words).
static func grounded(s: Dictionary) -> bool:
	return not String(s.get("ground", "")).strip_edges().is_empty()


## Whether the note keeps a storyboard.
func boarded() -> bool:
	return bool(NoteStoryboard.read(folder).get("ok", false)) and not (NoteStoryboard.read(folder).get("data", {}).get("sequence", []) as Array).is_empty()


## When the note's storyboard was last written (0 for never).
func boarded_stamp() -> int:
	var p := NoteStoryboard.path_in(folder)
	return int(FileAccess.get_modified_time(p)) if FileAccess.file_exists(p) else 0


## The cartoon's clock: a silent track as long as its storyboard plays ([method Storyboard.silent_length]), in the note's folder;
## written where it is missing or of another length. "" while there is no storyboard.
func silence() -> String:
	var r := NoteStoryboard.read(folder)
	if not bool(r.get("ok", false)):
		return ""
	var sb := Storyboard.from_data(r.get("data", {}), Storyboard.IN_NOTE)
	if not bool(sb.get("ok", false)):
		return ""
	var secs := maxf(1.0, Storyboard.silent_length(sb))
	var path := folder.path_join("cartoon").path_join("silence.wav")
	var rate := 8000
	var frames := int(round(secs * rate))
	var had := FileAccess.open(path, FileAccess.READ) if FileAccess.file_exists(path) else null
	if had != null and absi(int(had.get_length()) - (44 + frames * 2)) <= 64:
		return path
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(frames * 2)
	wav.data = data
	wav.save_to_wav(path)
	return path


## Everything not made yet begun: each character rigged, each set painted, and - once all are - the storyboard written. "" or why not.
func make_missing() -> String:
	var why := ""
	for c in cast():
		if not rigged(String(c["name"])) and not busy("rig:" + String(c["name"])):
			why = make(c)
	for s in sets():
		var after := String(s.get("from", ""))
		if not painted(String(s["name"])) and not busy("set:" + String(s["name"])) and (after.is_empty() or painted(after)):
			why = paint(s)
		elif painted(String(s["name"])) and grounded(s) and not traced(String(s["name"])) and not busy("ground:" + String(s["name"])):
			why = trace(s)
	if _work.is_empty() and not boarded():
		why = direct()
	return why


# --- the rigger ------------------------------------------------------------------------------------------------------------

## The character [param c] rigged by the rigger: its drawing cut, a skeleton placed, built and handed in. "" or why not.
func rig(c: Dictionary) -> String:
	var name := String(c.get("name", ""))
	var picture := String(c.get("picture", ""))
	if picture.begins_with("~"):
		picture = OS.get_environment("HOME").path_join(picture.substr(1).trim_prefix("/"))
	if not FileAccess.file_exists(picture):
		return _fail("rig:" + name, "%s's drawing is not at %s" % [name, picture])
	if not Library.writable():
		return _fail("rig:" + name, "this session cannot write the library (read-only)")
	var where := PuppetRig.folder_of(name)
	var dir := where.path_join("job")
	var tools := RiggerTools.new(where, picture)
	var url := AgentTools.open(dir, tools)
	if url.is_empty():
		return _fail("rig:" + name, "the rigger's tools would not start")
	var about := String(c.get("about", ""))
	var prompt := Rules.say("cartoon/rigger.prompt", {"name": name, "source": picture.get_file(), "looks": tools.looks,
		"has_note": not about.is_empty(), "note": about})
	return _submit("rig:" + name, {"kind": "text", "backend": String(writer["agent"]), "tier": "best", "dir": dir, "prompt": prompt,
		"tools_url": url, "label": "cartoon rig " + name, "timeout": RIG_MOST, "model": String(writer["model"]),
		"effort": String(writer["effort"])}, {"tools": tools, "url": url, "name": name})


## The character [param c] made a puppet: a model sheet ([method sheet]) unless its row or the block says `sheet: false`, then its one
## drawing rigged as it is ([method rig]).
func make(c: Dictionary) -> String:
	return sheet(c) if bool(c.get("sheet", block.get("sheet", true))) else rig(c)


# --- the model sheet -------------------------------------------------------------------------------------------------------

## What a sheet's drawing is painted into, in its folder.
const PAINTED := "painted.png"


## The character [param c] made a model sheet ([PuppetSheet]): every drawing painted from the maker's (or from another of the sheet),
## cut off its paper and set onto the drawing it was painted from; the front and the profile rigged by the rigger, their other mouths
## built on their skeletons, the back and the moods held rigid. `sheet.json` lists what was made. "" or why not.
func sheet(c: Dictionary, again := false) -> String:
	var name := String(c.get("name", ""))
	var picture := _abs(String(c.get("picture", "")))
	var described := String(c.get("describe", "")).strip_edges()
	if not FileAccess.file_exists(picture) and described.is_empty():
		return _fail("rig:" + name, "%s has no drawing at %s, and nothing describes it" % [name, picture])
	if not Library.writable():
		return _fail("rig:" + name, "this session cannot write the library (read-only)")
	var where := PuppetRig.folder_of(name)
	# a character described rather than drawn takes its style from the cast's drawings
	var style := PackedStringArray()
	if FileAccess.file_exists(picture):
		style.append(_as_png(picture, where.path_join("refs")))
	else:
		for o in cast():
			var p := _abs(String((o as Dictionary).get("picture", "")))
			if FileAccess.file_exists(p) and style.size() < 3:
				style.append(_as_png(p, where.path_join("refs")))
	var original := style[0] if not style.is_empty() else ""
	var wanted: Array = c.get("drawings", []) if c.get("drawings") is Array and not (c.get("drawings") as Array).is_empty() else PuppetSheet.order()
	var made := {}
	var asks: Dictionary = c.get("asks", {}) if c.get("asks") is Dictionary else {}
	_sheets[name] = {"picture": picture, "original": original, "about": String(c.get("about", described)), "folder": where, "made": made,
		"said": "painting its drawings", "rigid": bool(c.get("rigid", false)), "align": String(c.get("align", "height")),
		"looks": String(c.get("looks", "front"))}
	_errors.erase("rig:" + name)
	for key in PuppetSheet.order():
		if not wanted.has(key):
			continue
		var row: Dictionary = PuppetSheet.REGISTRY[key]
		var from := String(row["from"])
		if not from.is_empty() and not wanted.has(from):
			continue
		# a drawing already made stays (a row added to the sheet paints only itself), unless the whole sheet is made again
		if not again and FileAccess.file_exists(where.path_join(key).path_join(PuppetRig.FILE)):
			made[key] = "done"
			continue
		# one painted whose cut or build stopped (its host not installed yet) is cut and built from its painting, not painted again
		if not again and FileAccess.file_exists(where.path_join(key).path_join(PAINTED)):
			made[key] = "painting"
			_cut_drawing.call_deferred(name, key)
			continue
		var refs := PackedStringArray()
		if from.is_empty():
			refs = style
		else:
			refs = PackedStringArray([where.path_join(from).path_join(PAINTED)])
			if not original.is_empty():
				refs.append(original)
		var prompt := Rules.say("cartoon/sheet.prompt", {"ask": String(asks.get(key, row["ask"])), "file": "image.png", "has_base": not from.is_empty(),
			"described": from.is_empty() and not described.is_empty(), "describe": described, "thing": bool(c.get("thing", false))})
		made[key] = "painting"
		var err := _submit("paint:%s:%s" % [name, key], {"kind": "image", "backend": String(painter["agent"]),
			"dir": where.path_join(key).path_join("paint"), "prompt": prompt, "refs": refs, "target": where.path_join(key).path_join(PAINTED),
			"lane": "sheet:" + name, "label": "cartoon %s %s" % [name, key], "model": String(painter["model"]),
			"effort": String(painter["effort"])}, {"name": name, "key": key})
		if not err.is_empty():
			_sheets.erase(name)
			return _fail("rig:" + name, err)
	if not made.values().has("painting"):
		_finish_sheet(name)
	return ""


static func _abs(p: String) -> String:
	return OS.get_environment("HOME").path_join(p.substr(1).trim_prefix("/")) if p.begins_with("~") else p


## A drawing of [param name]'s sheet painted: cut off its paper, then set onto the drawing it was painted from once that is cut.
func _cut_drawing(name: String, key: String) -> void:
	var s: Dictionary = _sheets.get(name, {})
	if s.is_empty():
		return
	var dir := String(s["folder"]).path_join(key)
	(s["made"] as Dictionary)[key] = "cutting"
	var got := await RiggerTools.host("cut", {"src": dir.path_join(PAINTED), "dir": dir}, dir.path_join("job"))
	var from := String((PuppetSheet.REGISTRY[key] as Dictionary)["from"])
	if bool(got.get("ok", false)) and not from.is_empty():
		var tree := Engine.get_main_loop() as SceneTree
		while String((s["made"] as Dictionary).get(from, "")) in ["painting", "cutting"]:
			await tree.process_frame
		if String((s["made"] as Dictionary).get(from, "")) == "failed":
			got = {"ok": false, "error": "the drawing it is painted from failed"}
		else:
			DirAccess.remove_absolute(dir.path_join("cut_raw.png"))
			got = await RiggerTools.host("align", {"dir": dir, "base": String(s["folder"]).path_join(from), "by": String(s.get("align", "height"))},
				dir.path_join("job"))
	_drawing_done(name, key, "cut" if bool(got.get("ok", false)) else "failed", String(got.get("error", "")))


## A drawing's step ended at [param state] (cut, done, failed), and what follows begun: once every drawing is painted and cut, the front
## and the profile go to the rigger and the back and the moods are built rigid; once a view is rigged its other mouths are built on its
## skeleton; once all are, the sheet is written.
func _drawing_done(name: String, key: String, state: String, why := "") -> void:
	var s: Dictionary = _sheets.get(name, {})
	if s.is_empty():
		return
	var made: Dictionary = s["made"]
	made[key] = state
	if state == "failed" and not why.is_empty():
		s["why_" + key] = why
	if made.values().any(func(v: String) -> bool: return v in ["painting", "cutting"]):
		s["said"] = "painting and cutting its drawings (%d of %d)" % [made.values().filter(func(v: String) -> bool: return v != "painting").size(), made.size()]
		return
	for k in made:
		if String(made[k]) != "cut":
			continue
		var row: Dictionary = PuppetSheet.REGISTRY[k]
		if bool(s.get("rigid", false)):
			made[k] = "building"
			_build_drawing(name, k, {"rigid": true, "faces": String(s.get("looks", "front"))})
		elif k in ["front", "side"]:
			made[k] = "rigging"
			_rig_drawing(name, k)
		elif String(row["view"]) == "back" or not String(row["mood"]).is_empty() or not String(row.get("action", "")).is_empty():
			made[k] = "building"
			_build_drawing(name, k, {"rigid": true})
		elif String(made.get(String(row["view"]), "")) == "done":
			made[k] = "building"
			_build_drawing(name, k, _spec_of(name, String(row["view"])))
		elif String(made.get(String(row["view"]), "")) == "failed":
			made[k] = "failed"
	s["said"] = "rigging its drawings"
	if made.values().all(func(v: String) -> bool: return v in ["done", "failed"]):
		_finish_sheet(name)


## The rigger at work on [param key], a drawing of [param name]'s sheet.
func _rig_drawing(name: String, key: String) -> void:
	var s: Dictionary = _sheets[name]
	var dir := String(s["folder"]).path_join(key)
	var tools := RiggerTools.new(dir, dir.path_join(PAINTED))
	var from := String((PuppetSheet.REGISTRY[key] as Dictionary)["from"])
	if not from.is_empty():
		tools.base = String(s["folder"]).path_join(from)
	var url := AgentTools.open(dir.path_join("job"), tools)
	if url.is_empty():
		_drawing_done(name, key, "failed", "the rigger's tools would not start")
		return
	var about := String(s.get("about", ""))
	var prompt := Rules.say("cartoon/rigger.prompt", {"name": name, "source": key + "/" + PAINTED, "looks": tools.looks,
		"has_note": not about.is_empty(), "note": about, "has_role": true,
		"role": "%s drawing (%s)" % [String((PuppetSheet.REGISTRY[key] as Dictionary)["label"]).to_lower(), String((PuppetSheet.REGISTRY[key] as Dictionary)["blurb"])],
		"talks": (s["made"] as Dictionary).has(key + "_open")})
	var err := _submit("rigdraw:%s:%s" % [name, key], {"kind": "text", "backend": String(writer["agent"]), "tier": "best",
		"dir": dir.path_join("job"), "prompt": prompt, "tools_url": url, "label": "cartoon rig %s %s" % [name, key], "timeout": RIG_MOST,
		"model": String(writer["model"]), "effort": String(writer["effort"])}, {"tools": tools, "url": url, "name": name, "key": key})
	if not err.is_empty():
		_drawing_done(name, key, "failed", err)


## The skeleton the rigger handed in for [param view] of [param name]'s sheet, to build its other mouths on (no jaw: they talk by
## drawing).
func _spec_of(name: String, view: String) -> Dictionary:
	var p := String(_sheets[name]["folder"]).path_join(view).path_join("job").path_join("build_spec.json")
	var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
	var spec: Dictionary = (got as Dictionary).duplicate(true) if got is Dictionary else {}
	spec.erase("jaw")
	return spec


## [param key] of [param name]'s sheet built from [param spec] (a skeleton of its view's, or `rigid`: one bone, held whole).
func _build_drawing(name: String, key: String, spec: Dictionary) -> void:
	var dir := String(_sheets[name]["folder"]).path_join(key)
	var s := spec.duplicate(true)
	s["dir"] = dir
	var got := await RiggerTools.host("build", s, dir.path_join("job"))
	_drawing_done(name, key, "done" if bool(got.get("ok", false)) else "failed", String(got.get("error", "")))


## [param name]'s sheet written: every drawing that built, listed in `sheet.json`; failed where its front did not.
func _finish_sheet(name: String) -> void:
	var s: Dictionary = _sheets[name]
	var made: Dictionary = s["made"]
	var drawn: Array = []
	for k in PuppetSheet.order():
		if String(made.get(k, "")) == "done" and FileAccess.file_exists(String(s["folder"]).path_join(k).path_join(PuppetRig.FILE)):
			drawn.append(k)
	_sheets.erase(name)
	if not drawn.has("front"):
		_fail("rig:" + name, "its front drawing could not be made: %s" % String(s.get("why_front", "the rigger handed nothing in")))
		return
	var f := FileAccess.open(String(s["folder"]).path_join(PuppetSheet.FILE), FileAccess.WRITE)
	f.store_string(JSON.stringify({"drawings": drawn, "from": String(s["picture"])}, "\t"))
	f.close()
	var lost := made.keys().filter(func(k: String) -> bool: return not drawn.has(k))
	if not lost.is_empty():
		_errors["rig:" + name] = "made without %s" % ", ".join(lost)


# --- the set painter -------------------------------------------------------------------------------------------------------

## The set [param s] painted in the cast's own drawing style. "" or why not.
func paint(s: Dictionary) -> String:
	var name := String(s.get("name", ""))
	if not Library.writable():
		return _fail("set:" + name, "this session cannot write the library (read-only)")
	var refs := PackedStringArray()
	for c in cast():
		var p := String((c as Dictionary).get("picture", ""))
		if p.begins_with("~"):
			p = OS.get_environment("HOME").path_join(p.substr(1).trim_prefix("/"))
		if FileAccess.file_exists(p):
			refs.append(_as_png(p, folder.path_join("cartoon").path_join("refs")))
	var dir := folder.path_join("cartoon").path_join("sets").path_join(name)
	var target := Library.shelf(PuppetRig.SETS).path_join(name + ".png")
	var ground := String(s.get("ground", "")).strip_edges()
	var from := PuppetRig.set_file(String(s.get("from", "")))
	if not String(s.get("from", "")).is_empty() and from.is_empty():
		return _fail("set:" + name, "the set it is painted from (%s) is not painted yet" % s["from"])
	if not from.is_empty():
		refs.insert(0, from)
	var prompt := Rules.say("cartoon/set_painter.prompt", {"place": String(s.get("place", name)), "file": "image.png",
		"has_ground": not ground.is_empty(), "ground": ground, "has_from": not from.is_empty()})
	return _submit("set:" + name, {"kind": "image", "backend": String(painter["agent"]), "dir": dir, "prompt": prompt, "refs": refs,
		"target": target, "label": "cartoon set " + name, "model": String(painter["model"]), "effort": String(painter["effort"])},
		{"name": name})


# --- the surveyor ----------------------------------------------------------------------------------------------------------

## The ground line of the set [param s] traced by the surveyor from its `ground` words: where its characters walk across it. "" or why not.
func trace(s: Dictionary) -> String:
	var name := String(s.get("name", ""))
	var file := PuppetRig.set_file(name)
	if file.is_empty():
		return _fail("ground:" + name, "the set %s is not painted yet" % name)
	if not grounded(s):
		return _fail("ground:" + name, "the set %s says nothing of where they walk (its `ground`)" % name)
	if not Library.writable():
		return _fail("ground:" + name, "this session cannot write the library (read-only)")
	var dir := folder.path_join("cartoon").path_join("ground").path_join(name)
	var tools := SurveyorTools.new(file, PuppetRig.ground_file(file))
	var url := AgentTools.open(dir, tools)
	if url.is_empty():
		return _fail("ground:" + name, "the surveyor's tools would not start")
	var prompt := Rules.say("cartoon/surveyor.prompt", {"place": String(s.get("place", name)), "ground": String(s["ground"]).strip_edges(),
		"looks": tools.looks})
	return _submit("ground:" + name, {"kind": "text", "backend": String(writer["agent"]), "tier": "best", "dir": dir, "prompt": prompt,
		"tools_url": url, "label": "cartoon ground " + name, "timeout": TRACE_MOST, "model": String(writer["model"]),
		"effort": String(writer["effort"])}, {"surveyor": tools, "url": url, "name": name})


## A drawing as a PNG a painter can take (a WebP read and written once into [param dir]); itself where it is one already.
static func _as_png(path: String, dir: String) -> String:
	if path.get_extension().to_lower() in ["png", "jpg", "jpeg"]:
		return path
	DirAccess.make_dir_recursive_absolute(dir)
	var out := dir.path_join(path.get_file().get_basename() + ".png")
	if not FileAccess.file_exists(out):
		var img := Image.load_from_file(path)
		if img != null:
			img.save_png(out)
	return out


# --- the director ----------------------------------------------------------------------------------------------------------

## The storyboard written by the director from the note's words, its direction, the cast and the sets. "" or why not.
func direct(error := "") -> String:
	var missing := PackedStringArray()
	for c in cast():
		if not rigged(String(c["name"])):
			missing.append(String(c["name"]))
	for s in sets():
		if not painted(String(s["name"])):
			missing.append(String(s["name"]))
	if not missing.is_empty():
		return _fail("board", "not made yet: %s" % ", ".join(missing))
	if cast().is_empty() or sets().is_empty():
		return _fail("board", "a cartoon needs a character and a set first")
	var raw := FileAccess.get_file_as_string(note_path)
	var dir := folder.path_join("cartoon").path_join("director")
	var prompt := Rules.say("cartoon/director.prompt", director_vars(raw, error))
	return _submit("board", {"kind": "text", "backend": String(writer["agent"]), "tier": "best", "dir": dir, "prompt": prompt,
		"label": "cartoon storyboard", "timeout": WRITE_MOST, "model": String(writer["model"]), "effort": String(writer["effort"])},
		{"tries": 0 if error.is_empty() else 1})


## What the director is told, filled in from the note [param raw] (its file's text) and what was wrong last time ([param error]).
func director_vars(raw: String, error := "") -> Dictionary:
	var seconds := float(block.get("seconds", SECONDS))
	var cast_lines := PackedStringArray()
	for c in cast():
		var name := String(c["name"])
		var r := PuppetRig.read_now(name)
		var roles := {}
		for b in r.data.get("bones", []):
			var role := String((b as Dictionary).get("role", ""))
			if role in ["arm", "hand", "leg", "loose", "prop"]:
				roles[role] = int(roles.get(role, 0)) + 1
		var parts := PackedStringArray()
		for role in roles:
			parts.append("%d %s" % [roles[role], role])
		var own := (r.data.get("poses", {}) as Dictionary).keys()
		var drawn := PackedStringArray()
		var asks: Dictionary = c.get("asks", {}) if c.get("asks") is Dictionary else {}
		for k in r.drawings:
			# a drawing painted from its own words is named by what they show (a profile that is a charge, not a stroll)
			var label := String((PuppetSheet.REGISTRY.get(k, {"label": k}) as Dictionary)["label"]).to_lower()
			var said := String(asks.get(k, "")).get_slice(".", 0).strip_edges()
			drawn.append(label + (" (%s)" % said if not said.is_empty() else ""))
		var tall := float(c.get("height", 1.0))
		var wide := tall * float((r.data.get("size", [1, 1]) as Array)[0]) / r.height()
		var looks := String(c.get("looks", "")).strip_edges()
		cast_lines.append("- rig \"%s\": %s Usual height %.2f, and %.2f wide at that height. Bones: %s%s%s.%s" % [name,
			String(r.data.get("about", c.get("about", c.get("describe", "")))).strip_edges(), tall, wide, ", ".join(parts),
			("; drawn %s" % ", ".join(drawn)) if drawn.size() > 1 else ("; a jaw that talks" if r.data.get("mouth") is Dictionary else "; no mouth that moves"),
			("; its own poses: " + ", ".join(own)) if not own.is_empty() else "",
			(" Seen from its side, it looks to the %s as drawn; `facing: %s` turns it round to look the other way." % [looks,
				"left" if looks == "right" else "right"]) if looks in ["left", "right"] else ""])
		if bool(c.get("thing", false)):
			cast_lines[cast_lines.size() - 1] += " IT IS A THING, not a character: furniture or a prop, placed in depth among the characters (nearer z in front of them, farther behind) and left where it stands."
		var reach := String(c.get("reaches", ""))
		if reach in ["left", "right"]:
			cast_lines[cast_lines.size() - 1] += " It comes in from the %s edge of the frame, its %s end running off it - the code keeps it there, so place it by where its other end must reach (it reaches only as far as its width allows)." % [reach, reach]
	var set_lines := PackedStringArray()
	for s in sets():
		set_lines.append("- \"%s\": %s%s%s" % [String(s["name"]), String(s.get("place", "")),
			(" Where they stand in it: %s" % String(s["ground"])) if not String(s.get("ground", "")).is_empty() else "",
			" Its ground line is traced: a puppet given `on_ground: true` keeps its feet on it wherever it goes across." if traced(String(s["name"])) else ""])
	var verb_lines := PackedStringArray()
	for v in VERBS:
		var args: Dictionary = Actions.ARGS.get(v, {})
		var named := PackedStringArray()
		for a in args:
			named.append("%s (%s)" % [a, String((args[a] as Dictionary).get("blurb", ""))])
		verb_lines.append("- %s: %s.%s" % [v, VERBS[v], (" Args: " + "; ".join(named)) if not named.is_empty() else ""])
	var words := Manuscript.strip_frontmatter(raw).strip_edges()
	var dir_text := Direction.text_of(NoteStore.blocks_of(note_path).get(Direction.KEY))
	return {"title": FrontMatter.field_of(raw, "title").strip_edges(), "brief": words if not words.is_empty() else "(the note says nothing more)",
		"has_direction": not dir_text.is_empty(), "direction": dir_text, "seconds": int(round(seconds)),
		"shots": maxi(3, int(round(seconds / 4.0))), "cast": "\n".join(cast_lines), "sets": "\n".join(set_lines),
		"verbs": "\n".join(verb_lines), "poses": ", ".join(Actions.POSE_NAMES), "gaits": ", ".join(Actions.GAITS),
		"fx": ", ".join(Actions.FX_KINDS), "half_width": "1.2", "ground": "-0.72", "silent": bool(block.get("silent", true)),
		"loops": bool(block.get("loops", false)),
		"has_error": not error.is_empty(), "error": error}


## Whether the storyboard [param data] (as the director wrote it) plays with this note's cast and sets: "" if it does, else what is
## wrong, a sentence the director can act on.
func check(data: Variant) -> String:
	if not (data is Dictionary):
		return "the reply was not one JSON object."
	var sb := Storyboard.from_data(data, Storyboard.IN_NOTE)
	if not bool(sb.get("ok", false)):
		return String(sb.get("error", "it does not load")) + "."
	var rigs := cast().map(func(c: Dictionary) -> String: return String(c["name"]))
	var set_names := sets().map(func(s: Dictionary) -> String: return String(s["name"]))
	var total := 0.0
	var seq: Array = sb["sequence"]
	for i in seq.size():
		var e: Dictionary = seq[i]
		var where := "shot %d" % (i + 1)
		if String(e.get("scene", "")) != "stage":
			return "%s is not a stage." % where
		var hold := float(e.get("hold", 0.0))
		if hold < 1.0 or hold > 12.0:
			return "%s holds %.1f seconds; a shot is 1 to 12." % [where, hold]
		total += hold
		var ids := {}
		for a in e.get("cast", []):
			var ad: Dictionary = a if a is Dictionary else {}
			var id := String(ad.get("id", ""))
			if ids.has(id):
				return "%s names %s twice." % [where, id]
			ids[id] = true
			match String(ad.get("kind", "")):
				"puppet":
					if not rigs.has(String(ad.get("rig", ""))):
						return "%s: %s's rig \"%s\" is not one of the cast (%s)." % [where, id, ad.get("rig", ""), ", ".join(rigs)]
				"backdrop":
					if not set_names.has(String(ad.get("picture", ""))):
						return "%s: the backdrop \"%s\" is not one of the sets (%s)." % [where, ad.get("picture", ""), ", ".join(set_names)]
				_:
					return "%s: %s is a %s; a cartoon's cast is puppets and a backdrop." % [where, id, ad.get("kind", "")]
		var cam: Dictionary = e.get("camera", {}) if e.get("camera") is Dictionary else {}
		if cam.has("frame"):
			var fr: Variant = cam["frame"]
			for who in (fr as Array if fr is Array else [fr]):
				if not ids.has(String(who)):
					return "%s: its camera frames %s, who is not in that shot." % [where, who]
			if not FRAMES.has(String(cam.get("size", "chest"))):
				return "%s: a camera's size is one of %s." % [where, ", ".join(FRAMES.keys())]
		var crowd := _crowded(e)
		if not crowd.is_empty():
			return "%s: %s" % [where, crowd]
		var track: Dictionary = e.get("track", {}) if e.get("track") is Dictionary else {}
		var slow := _crawls(e)
		if not slow.is_empty():
			return "%s: %s" % [where, slow]
		for sp in track.get("spans", []):
			var sd: Dictionary = sp if sp is Dictionary else {}
			var verb := String(sd.get("action", ""))
			if not Actions.REGISTRY.has(verb):
				return "%s: there is no verb \"%s\"." % [where, verb]
			var t1 := float(sd.get("to", sd.get("at", sd.get("from", 0.0))))
			if t1 > float(track.get("nominal", hold)) + 0.01:
				return "%s: a %s span ends at %.1f, past the shot's %.1f seconds." % [where, verb, t1, hold]
			var tg: Variant = sd.get("target", "all")
			for t in (tg as Array if tg is Array else [tg]):
				if String(t) != "all" and not ids.has(String(t)):
					return "%s: a %s span is aimed at %s, who is not in that shot." % [where, verb, t]
			for k in ["at", "toward"]:
				var who := String((sd.get("args", {}) as Dictionary).get(k, "")) if sd.get("args") is Dictionary else ""
				if not who.is_empty() and verb in ["strike", "pose"] and not ids.has(who):
					return "%s: a %s span names %s, who is not in that shot." % [where, verb, who]
	var want := float(block.get("seconds", SECONDS))
	if total < want * float(STRAY[0]) or total > want * float(STRAY[1]):
		return "it runs %.0f seconds; it should run about %.0f." % [total, want]
	return ""


## A character of shot [param e] going across on foot slower than [constant SLOWEST] (a walk, a run or a tiptoe; one far off and small
## goes as it likes): what it is, a sentence; "" where none crawls.
func _crawls(e: Dictionary) -> String:
	var at := {}
	var tall := {}
	for a in e.get("cast", []):
		var ad: Dictionary = a if a is Dictionary else {}
		if String(ad.get("kind", "")) == "puppet" and ad.get("at") is Array and (ad["at"] as Array).size() == 3 and not ((ad["at"] as Array)[0] is Array):
			at[String(ad.get("id", ""))] = float(ad["at"][0])
			tall[String(ad.get("id", ""))] = float(Storyboard.sample(ad.get("height", 1.0), RandomNumberGenerator.new()))
	var track: Dictionary = e.get("track", {}) if e.get("track") is Dictionary else {}
	var spans: Array = (track.get("spans", []) as Array).duplicate()
	spans.sort_custom(func(x: Variant, y: Variant) -> bool: return float((x as Dictionary).get("from", (x as Dictionary).get("at", 0.0))) < float((y as Dictionary).get("from", (y as Dictionary).get("at", 0.0))))
	for sp in spans:
		var sd: Dictionary = sp if sp is Dictionary else {}
		var args: Dictionary = sd.get("args", {}) if sd.get("args") is Dictionary else {}
		var who := String(sd.get("target", ""))
		if not at.has(who) or not (args.get("to") is Array) or (args["to"] as Array).size() != 3 or (args["to"] as Array)[0] is Array:
			continue
		var x1 := float(args["to"][0])
		var dx := absf(x1 - float(at[who]))
		at[who] = x1
		var gait := String(args.get("gait", "walk"))
		if String(sd.get("action", "")) != "move" or not gait in ["walk", "run", "tiptoe"] or float(tall[who]) < 0.5:
			continue
		var secs := float(sd.get("to", 0.0)) - float(sd.get("from", 0.0))
		var pace := dx / maxf(0.01, secs) / maxf(0.05, float(tall[who]))
		var least := float(SLOWEST.get(gait if gait == "tiptoe" else "", 0.9))
		if dx > 0.3 and pace < least:
			return "%s %ss %.1f across in %.1f seconds, %.2f of its heights a second - a crawl; at least %.1f reads (take %.1f seconds or less)." % [
				who, gait, dx, secs, pace, least, dx / (least * float(tall[who]))]
	return ""


## Two puppets of shot [param e] that start standing on each other: places closer than half of their two widths at nearly the same
## depth (a puppet's width is its rig's at its height). "" where none do. How wide each is comes from its rig, read once. A thing (a
## cast row's `thing`) is placed among characters on purpose, and one that `emerge`s from another starts inside it: neither counts.
func _crowded(e: Dictionary) -> String:
	var them: Array = []
	var things := cast().filter(func(c: Dictionary) -> bool: return bool(c.get("thing", false))).map(func(c: Dictionary) -> String: return String(c["name"]))
	var emerging := {}
	var track: Dictionary = e.get("track", {}) if e.get("track") is Dictionary else {}
	for sp in track.get("spans", []):
		if sp is Dictionary and String((sp as Dictionary).get("action", "")) == "emerge":
			var tg: Variant = (sp as Dictionary).get("target", "")
			for t in (tg as Array if tg is Array else [tg]):
				emerging[String(t)] = true
	for a in e.get("cast", []):
		var ad: Dictionary = a if a is Dictionary else {}
		if String(ad.get("kind", "")) != "puppet" or bool(ad.get("hidden", false)) or things.has(String(ad.get("rig", ""))) \
				or emerging.has(String(ad.get("id", ""))):
			continue
		var at: Array = ad.get("at", [0, 0, 0]) if ad.get("at") is Array and (ad.get("at") as Array).size() == 3 else [0, 0, 0]
		if at[0] is Array or at[2] is Array:
			continue
		them.append({"id": String(ad.get("id", "")), "x": float(at[0]), "z": float(at[2]), "w": _width_of(String(ad.get("rig", "")), float(Storyboard.sample(ad.get("height", 1.0), RandomNumberGenerator.new())))})
	for i in them.size():
		for j in range(i + 1, them.size()):
			var a: Dictionary = them[i]
			var b: Dictionary = them[j]
			var need := (float(a["w"]) + float(b["w"])) * 0.5 * CROWD
			if absf(float(a["z"]) - float(b["z"])) < 0.35 and absf(float(a["x"]) - float(b["x"])) < need:
				return "%s and %s start standing on each other (%.2f apart; they need about %.2f)." % [a["id"], b["id"],
					absf(float(a["x"]) - float(b["x"])), need]
	return ""


## How wide the puppet [param rig] is at [param tall] (its front drawing's width over its height); a usual width where it is not read.
func _width_of(rig: String, tall: float) -> float:
	if not _widths.has(rig):
		var r := PuppetRig.read_now(rig) if rigged(rig) else null
		_widths[rig] = float((r.data.get("size", [1, 1]) as Array)[0]) / r.height() if r != null and r.ok() else 0.8
	return tall * float(_widths[rig])


## [param data] with every camera that FRAMES someone (`camera: {frame: id or [ids], size: face | chest | full, fov}`) placed by
## their places and heights in that shot and where each one's face is drawn ([constant FRAMES]): the eye straight in front of them,
## as far off as the size asks. The framing is the director's; the numbers are the puppets'.
func framed(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	for key in ["sequence", "tail"]:
		for e in out.get(key, []):
			if not (e is Dictionary) or not ((e as Dictionary).get("camera") is Dictionary):
				continue
			var cam: Dictionary = e["camera"]
			if cam.has("frame"):
				var placed := frame_camera(e, cam)
				if not placed.is_empty():
					e["camera"] = placed
			_keep_reaching(e)
	return carried(out)


## Each arm of shot [param e] that reaches in from an edge (its cast row's `reaches`) kept running off that edge of the frame, at its
## place and wherever it moves to: as near the middle as its width lets it come while that end stays out of the widest frame - and
## drawn bigger where it is too short for its far end to reach where the farthest move sends it. It never turns round (its moves keep
## `turn: false`, and a `face` aimed at it is dropped): an arm that pulls back still runs off its edge.
func _keep_reaching(e: Dictionary) -> void:
	var cam: Dictionary = e.get("camera", {}) if e.get("camera") is Dictionary else {}
	var eye: Array = cam.get("eye", [0, 0, 4]) if cam.get("eye") is Array else [0, 0, 4]
	var look: Array = cam.get("look", [0, 0, 0]) if cam.get("look") is Array else [0, 0, 0]
	var fov := float(cam.get("fov", 48.0))
	var reach := {}
	for c in cast():
		var r := String((c as Dictionary).get("reaches", ""))
		if r in ["left", "right"]:
			reach[String(c["name"])] = r
	var limit := {}
	for a in e.get("cast", []):
		var ad: Dictionary = a if a is Dictionary else {}
		var side := String(reach.get(String(ad.get("rig", "")), ""))
		if side.is_empty() or not (ad.get("at") is Array) or (ad["at"] as Array).size() != 3 or (ad["at"] as Array)[0] is Array:
			continue
		var z := float(ad["at"][2])
		var dist := maxf(0.05, float(eye[2]) - z)
		var along := dist / maxf(0.05, float(eye[2]) - float(look[2]))
		var mid := float(eye[0]) + (float(look[0]) - float(eye[0])) * along
		var half_w := dist * tan(deg_to_rad(fov) * 0.5) * 0.5 * WIDEST
		var h := float(Storyboard.sample(ad.get("height", 1.0), RandomNumberGenerator.new()))
		var w := _width_of(String(ad.get("rig", "")), h)
		# where its far end is sent at most (its place's and each move's), and the size that lets it get there from off the edge
		var sign := 1.0 if side == "left" else -1.0
		var far := float(ad["at"][0]) * sign + w * 0.5
		var track0: Dictionary = e.get("track", {}) if e.get("track") is Dictionary else {}
		for sp in track0.get("spans", []):
			var sd0: Dictionary = sp if sp is Dictionary else {}
			var a0: Dictionary = sd0.get("args", {}) if sd0.get("args") is Dictionary else {}
			if String(sd0.get("target", "")) == String(ad.get("id", "")) and a0.get("to") is Array and (a0["to"] as Array).size() == 3 \
					and not ((a0["to"] as Array)[0] is Array):
				far = maxf(far, float(a0["to"][0]) * sign + w * 0.5)
		var need := far - (mid * sign - half_w)
		if need > w:
			h *= need / w
			w = need
			ad["height"] = snappedf(h, 0.001)
		# its centre may come no nearer the middle than half its width inside the frame's edge
		var bound := mid - half_w + w * 0.5 if side == "left" else mid + half_w - w * 0.5
		limit[String(ad.get("id", ""))] = [side, bound]
		ad["at"][0] = minf(float(ad["at"][0]), bound) if side == "left" else maxf(float(ad["at"][0]), bound)
	var track: Dictionary = e.get("track", {}) if e.get("track") is Dictionary else {}
	if track.get("spans") is Array:
		track["spans"] = (track["spans"] as Array).filter(func(sp: Variant) -> bool:
			return not (sp is Dictionary and limit.has(String((sp as Dictionary).get("target", ""))) and String((sp as Dictionary).get("action", "")) == "face"))
	for sp in track.get("spans", []):
		var sd: Dictionary = sp if sp is Dictionary else {}
		var args: Dictionary = sd.get("args", {}) if sd.get("args") is Dictionary else {}
		var who := String(sd.get("target", ""))
		if limit.has(who) and String(sd.get("action", "")) == "move":
			args["turn"] = false
			sd["args"] = args
		if limit.has(who) and args.get("to") is Array and (args["to"] as Array).size() == 3 and not ((args["to"] as Array)[0] is Array):
			var lim: Array = limit[who]
			args["to"][0] = minf(float(args["to"][0]), float(lim[1])) if String(lim[0]) == "left" else maxf(float(args["to"][0]), float(lim[1]))


## [param data] with each character's mood carried into its next shot, wherever it was last seen: one that left a shot terrified is
## terrified when it is cut back to, though shots without it came between (a body carried straight on keeps its mood already). A
## `feel` at the shot's start where the shot does not set one itself then.
static func carried(data: Dictionary) -> Dictionary:
	var mood := {}
	for key in ["sequence", "tail"]:
		for e in data.get(key, []):
			if not (e is Dictionary):
				continue
			var track: Dictionary = e.get("track", {}) if e.get("track") is Dictionary else {}
			var spans: Array = track.get("spans", []) if track.get("spans") is Array else []
			var feels := spans.filter(func(sp: Variant) -> bool: return sp is Dictionary and String((sp as Dictionary).get("action", "")) == "feel")
			feels.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.get("at", x.get("from", 0.0))) < float(y.get("at", y.get("from", 0.0))))
			for a in e.get("cast", []):
				var id := String((a as Dictionary).get("id", "")) if a is Dictionary else ""
				if String((a as Dictionary).get("kind", "")) != "puppet" or String(mood.get(id, "")) in ["", "none"]:
					continue
				var sets_own := feels.any(func(f: Dictionary) -> bool: return String(f.get("target", "")) == id and float(f.get("at", f.get("from", 0.0))) < 0.05)
				if not sets_own:
					spans.append({"action": "feel", "target": id, "at": 0.0, "args": {"mood": mood[id]}})
			for f in feels:
				var tg: Variant = f.get("target", "")
				for t in (tg as Array if tg is Array else [tg]):
					mood[String(t)] = String((f.get("args", {}) as Dictionary).get("mood", "")) if f.get("args") is Dictionary else ""
			if not track.is_empty():
				track["spans"] = spans
	return data


## The camera of shot [param e] that frames [param cam]'s `frame` at its `size`: {eye, look, fov}; {} where nobody framed is in it.
func frame_camera(e: Dictionary, cam: Dictionary) -> Dictionary:
	var fr: Variant = cam["frame"]
	var who: Array = (fr as Array).map(func(x: Variant) -> String: return String(x)) if fr is Array else [String(fr)]
	var size := String(cam.get("size", "chest"))
	var row: Dictionary = FRAMES.get(size, FRAMES["chest"])
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var head_lo := INF
	var head_hi := -INF
	var face_x := 0.0
	var faced := true
	var tall := 0.0
	var z := 0.0
	var n := 0
	for a in e.get("cast", []):
		var ad: Dictionary = a if a is Dictionary else {}
		if not who.has(String(ad.get("id", ""))) or String(ad.get("kind", "")) != "puppet":
			continue
		var at: Array = ad.get("at", [0, -0.72, 0]) if ad.get("at") is Array and (ad.get("at") as Array).size() == 3 else [0, -0.72, 0]
		if at[0] is Array or at[1] is Array or at[2] is Array:
			continue
		var h := float(Storyboard.sample(ad.get("height", 1.0), RandomNumberGenerator.new()))
		var rig := String(ad.get("rig", ""))
		var f := _face_of(rig)
		var mirror := -1.0 if String(ad.get("facing", "")) == "left" else 1.0
		var w := _width_of(rig, h)
		faced = faced and bool(f["ok"])
		face_x += float(at[0]) + float(f["x"]) * h * mirror
		head_hi = maxf(head_hi, float(at[1]) + h)
		var neck := float(f["neck"]) if f["neck"] != null else float(f["y"]) - float(row.get("chin", 0.6)) * (1.0 - float(f["y"]))
		head_lo = minf(head_lo, float(at[1]) + neck * h)
		lo = Vector2(minf(lo.x, float(at[0]) - w * 0.5), minf(lo.y, float(at[1])))
		hi = Vector2(maxf(hi.x, float(at[0]) + w * 0.5), maxf(hi.y, float(at[1]) + h))
		tall = maxf(tall, h)
		z += float(at[2])
		n += 1
	if n == 0:
		return {}
	face_x /= float(n)
	z /= float(n)
	if not faced:
		size = "full"
		row = FRAMES["full"]
	var head := head_hi - head_lo
	var frame_h := 0.0
	var look := Vector2.ZERO
	match size:
		"face":
			frame_h = head * float(row["room"])
			look = Vector2(face_x, (head_hi + head_lo) * 0.5)
		"chest":
			frame_h = maxf(head * float(row["room"]), tall * float(row["tall"]))
			look = Vector2(face_x, head_hi + head * 0.15 - frame_h * 0.5)
		_:
			frame_h = (hi.y - lo.y) * float(row["room"])
			look = Vector2((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5)
	if n > 1:
		frame_h = maxf(frame_h, (hi.x - lo.x) * 1.15 / FRAME_ASPECT)
		look.x = (lo.x + hi.x) * 0.5
	var fov := float(cam.get("fov", row["fov"]))
	var d := frame_h / tan(deg_to_rad(fov) * 0.5)          # the stage's frame is d * tan(fov / 2) tall (its lens scales by the short side)
	return {"eye": [snappedf(look.x, 0.001), snappedf(look.y, 0.001), snappedf(z + d, 0.001)],
		"look": [snappedf(look.x, 0.001), snappedf(look.y, 0.001), snappedf(z, 0.001)], "fov": fov}


## Where the rig [param rig]'s face is drawn, from its feet in shares of its height (x across as drawn, y up): {x, y} the middle of
## its eyes (else three quarters up its head bone), `neck` where its head bone joins (null for none), `ok` false where it has neither
## eyes nor a head bone to say. Read once from its front drawing's file.
func _face_of(rig: String) -> Dictionary:
	if _faces.has(rig):
		return _faces[rig]
	var out := {"x": 0.0, "y": 0.8, "neck": null, "ok": false}
	var f := PuppetRig.folder_of(rig)
	var file := f.path_join("front").path_join(PuppetRig.FILE)
	if not FileAccess.file_exists(file):
		file = f.path_join(PuppetRig.FILE)
	var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(file)) if FileAccess.file_exists(file) else null
	if got is Dictionary:
		var d: Dictionary = got
		var bones: Array = d.get("bones", [])
		var ground := float(d.get("ground", 1.0))
		var tall := maxf(1.0, ground - float(d.get("top", 0.0)))
		var ax := float((bones[0] as Dictionary)["head"][0]) if not bones.is_empty() else float((d.get("size", [0, 0]) as Array)[0]) * 0.5
		var p := Vector2.INF
		for b in bones:
			if String((b as Dictionary).get("role", "")) == "head":
				var hd: Array = (b as Dictionary)["head"]
				var tl: Array = (b as Dictionary)["tail"]
				out["neck"] = (ground - float(hd[1])) / tall
				p = Vector2(lerpf(float(hd[0]), float(tl[0]), 0.75), lerpf(float(hd[1]), float(tl[1]), 0.75))
				break
		var eyes: Array = d.get("eyes", [])
		if not eyes.is_empty():
			p = Vector2.ZERO
			for ey in eyes:
				p += Vector2(float((ey as Dictionary)["center"][0]), float((ey as Dictionary)["center"][1]))
			p /= float(eyes.size())
		if p != Vector2.INF:
			out["x"] = (p.x - ax) / tall
			out["y"] = (ground - p.y) / tall
			out["ok"] = true
	_faces[rig] = out
	return out


## [param data] (a storyboard that plays) as a cartoon plays it: every stage shot framed still (`shot: centered`, `behavior: static`)
## where it names nothing else, so the camera moves only where the director moved it on purpose, never drifting or pushing in; no
## fade up from black or down to it at its ends (`bookend: false`): a screen may come on in the middle of it, and a loop's end meets
## its start; and, where it [param loops], its last shot followed by its first (`loop`), else its last held.
static func settled(data: Dictionary, loops: bool) -> Dictionary:
	var out := data.duplicate(true)
	out["bookend"] = false
	out["loop"] = loops
	for key in ["sequence", "tail"]:
		for e in out.get(key, []):
			if e is Dictionary and String((e as Dictionary).get("scene", "")) == "stage":
				if not (e as Dictionary).has("shot"):
					e["shot"] = "centered"
				if not (e as Dictionary).has("behavior"):
					e["behavior"] = "static"
	return out


## The director's reply [param text] as the JSON object in it (fences and words round it left out); null where there is none.
static func parse_board(text: String) -> Variant:
	var a := text.find("{")
	var b := text.rfind("}")
	if a < 0 or b <= a:
		return null
	var got: Variant = JSON.parse_string(text.substr(a, b - a + 1))
	return Storyboard.whole(got) if got != null else null


## The director's reply [param text] landed: checked, its cameras framed ([method framed]) and written as the note's storyboard. "" when
## it is; what keeps it from playing; or "!" and why it would not write.
func land(text: String) -> String:
	var data: Variant = parse_board(text)
	var why := check(data)
	if not why.is_empty():
		return why
	var err := NoteStoryboard.write(folder, CartoonProducer.settled(framed(data), bool(block.get("loops", false))))
	return "" if err.is_empty() else "!" + err


# --- the queue -------------------------------------------------------------------------------------------------------------

func _submit(key: String, spec: Dictionary, extra: Dictionary) -> String:
	var id := AgentJobs.submit(spec)
	if id.is_empty():
		if extra.has("url"):
			AgentTools.close(String(extra["url"]))
		return _fail(key, "this session cannot start agents (read-only)")
	var w := extra.duplicate()
	w["job"] = id
	_work[key] = w
	_errors.erase(key)
	return ""


func _fail(key: String, why: String) -> String:
	_errors[key] = why
	return why


## What ended, landed: a rig handed in (or not), a set painted, a storyboard checked and written - or sent back once. Call each frame.
func pump() -> void:
	AgentJobs.pump()
	for key in _work.keys():
		var w: Dictionary = _work[key]
		var st := AgentJobs.state(String(w["job"]))
		if st in ["queued", "running"]:
			continue
		_work.erase(key)
		var res := AgentJobs.result(String(w["job"]))
		AgentJobs.forget(String(w["job"]))
		if w.has("url"):
			AgentTools.close(String(w["url"]))
		if w.has("tools"):
			(w["tools"] as RiggerTools).release()
		if w.has("surveyor"):
			(w["surveyor"] as SurveyorTools).release()
		if String(key).begins_with("paint:"):
			if bool(res.get("ok", false)):
				_cut_drawing(String(w["name"]), String(w["key"]))
			else:
				_drawing_done(String(w["name"]), String(w["key"]), "failed", "the painter made nothing: %s" % String(res.get("error", "")).left(160))
		elif String(key).begins_with("rigdraw:"):
			var ok := (w["tools"] as RiggerTools).submitted
			_drawing_done(String(w["name"]), String(w["key"]), "done" if ok else "failed",
				"" if ok else "the rigger handed nothing in: %s" % String(res.get("error", res.get("text", ""))).left(160))
		elif String(key).begins_with("rig:"):
			if not (w["tools"] as RiggerTools).submitted:
				_fail(key, "the rigger stopped without handing a puppet in: %s" % String(res.get("error", res.get("text", ""))).left(200))
		elif String(key).begins_with("ground:"):
			if not (w["surveyor"] as SurveyorTools).submitted:
				_fail(key, "the surveyor stopped without handing a line in: %s" % String(res.get("error", res.get("text", ""))).left(200))
		elif String(key).begins_with("set:"):
			if not bool(res.get("ok", false)):
				_fail(key, "the painter made nothing: %s" % String(res.get("error", "")).left(200))
			else:
				var file := PuppetRig.set_file(String(w["name"]))
				if not file.is_empty() and FileAccess.file_exists(PuppetRig.ground_file(file)):
					DirAccess.remove_absolute(PuppetRig.ground_file(file))    # traced on the picture painted over
		elif key == "board":
			if not bool(res.get("ok", false)):
				_fail(key, "the director stopped: %s" % String(res.get("error", "")).left(200))
				continue
			var why := land(String(res.get("text", "")))
			if why.is_empty() or why.begins_with("!"):
				if not why.is_empty():
					_fail(key, why.substr(1))
			elif int(w.get("tries", 0)) < 1:
				direct(why)
			else:
				_fail(key, "the storyboard written would not play: %s" % why)
