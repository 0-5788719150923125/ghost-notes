extends RefCounted
class_name PuppeteerTools

## PuppeteerTools - what the puppeteer can do while it blocks an episode's work at the table
## (next/table_work.md): read what on the set table can be worked, write an act and be told in numbers what
## it does, watch it from the camera, and hand the acts in. Served as tools ([AgentTools]) like the set
## dresser's ([SetDresserTools]); it keeps a draft of acts here and works on it:
##
##   parts    the table as it is set, and what on it can be worked: each thing, whether it may be moved
##            whole, its named parts - joints, points (where each is on the table now), states, what each
##            runs and emits ([method TableWork.parts_report])
##   act      acts put into the draft - one of the same name is replaced - each answered with what it does:
##            how long, how far and how fast each moving thing goes, anything passing through anything
##            ([method TableWork.check]), and what of it could not be kept, and why. Every act of a call is
##            checked on one table ([method TablePreview.work_checks]): the table stands for the first call,
##            its acts are bound again for each after ([method TableMedium.rework]), and what is in things is
##            baked again only from where the draft changes ([method TablePhysics.replan])
##            (tests/table/act_calls_probe.gd)
##   remove   acts taken out, by name
##   watch    one act photographed from the camera's place, six times start to end
##            ([method TablePreview.work_watch])
##   model    what is built ([Assembly]) as an act leaves it, from four sides close to ([method TablePreview.model_views]): only
##            on a table with an assembly
##   submit   hand the acts in: written beside the job ([constant SUBMITTED]) for the producer to land as an
##            answer in words would land ([method TableProducer._land_acts]) - refused while an act passes
##            through something, until it is fixed or handed in so twice
##
## What it writes is data - the laws are [Motions]'s, a formula is [Formula]'s - and nothing it writes runs as code. Every
## picture counts against [constant LOOKS]; words cost nothing.

const SUBMITTED := "submitted.json"
## How many pictures one puppeteer may take.
const LOOKS := 30
## What to ask of a picture of an act.
const JUDGE := "Say what the six frames actually show, start to end: does each thing move as a held thing would - lifted before it travels, carried, set down - is it where the work is, can the viewer see what is done, and does anything pass through anything or leave the frame? Write the act again to fix what is wrong."

var episode: TableEpisode
var plan: Dictionary
var dir := ""
var submitted := false

var _table := {}
var _acts: Array = []           # the draft, in the order put
var _looks := 0
var _busy := false
var _released := false
var _warned_unseen := false
var _watched := {}              # act name -> true, once watched since it was last written
var _preview: TablePreview
## What the acts write that TeX lays out, laid out as they are put ([method _lay_ink]): item id -> TeX's record, and the fonts.
var _laid := {}
var _fonts := {}


## [param table]: the episode's set table, as `table.json` holds it.
func _init(ep: TableEpisode, episode_plan: Dictionary, job_dir: String, table: Dictionary) -> void:
	episode = ep
	plan = episode_plan
	dir = job_dir
	_table = table
	_preview = TablePreview.new(ep, plan, dir.path_join("preview"))
	# a run starts clean: a rerun works in the folder the last run left
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		var fs := String(f)
		if fs == SUBMITTED or fs == "tools.jsonl" or (fs.begins_with("look_") and fs.ends_with(".jpg")):
			DirAccess.remove_absolute(dir.path_join(fs))


## The tools closed: the preview given back now, or - while a call bakes - its bake given up, and given back after.
func release() -> void:
	_released = true
	if not _busy:
		_preview.release()
	else:
		_preview.halt()


func instructions() -> String:
	return "Tools for blocking the work done at the set table: read what on it can be worked, write acts and be told what they do, watch them from the camera, and submit them."


func list_tools() -> Array:
	return [
		{"name": "parts", "description": "The table as it is set, and what on it can be worked: each thing, where it stands, whether it can be moved whole, and its named parts - their joints, their points (where each is on the table now, in centimeters), their states, and what they run and emit.",
			"inputSchema": {"type": "object", "properties": {}}},
		{"name": "act", "description": "Put acts into the episode's work - an act with the name of one already there replaces it. Each act is written exactly as in the format you were shown. Answered, act by act, with what it does: how long it runs, how far and how fast each moving thing goes, anything passing through anything (and the moment it does), and anything that could not be kept and why.",
			"inputSchema": {"type": "object", "properties": {
				"acts": {"type": "array", "items": {"type": "object"}, "description": "acts, each {name, beat, about, length, tracks, cues}"}},
				"required": ["acts"]}},
		{"name": "remove", "description": "Take acts out of the episode's work, by name.",
			"inputSchema": {"type": "object", "properties": {"names": {"type": "array", "items": {"type": "string"}}}, "required": ["names"]}},
		{"name": "watch", "description": "Watch one act on this episode's own table from the camera's place: one picture of six frames, start to end, left to right and down - one look.",
			"inputSchema": {"type": "object", "properties": {"name": {"type": "string"}}, "required": ["name"]}},
		{"name": "model", "description": "What is built on this table as one act leaves it, close to and from four sides, by the table's own light: its shape, seen as the chair never sees it. A table with no assembly has nothing to show.",
			"inputSchema": {"type": "object", "properties": {"name": {"type": "string"}}, "required": ["name"]}},
		{"name": "submit", "description": "Hand in the acts as they now stand. Answers with what keeps them from being handed in, if anything; otherwise the work is blocked, and so is your work.",
			"inputSchema": {"type": "object", "properties": {}}},
	]


## One call at a time, and none once the tools are closed (as [method SetDresserTools.call_tool]).
func call_tool(name: String, args: Dictionary) -> Dictionary:
	while _busy and not _released:
		await TablePreview._tree().process_frame
	if _released:
		return {"text": "The work has been handed in and its tools are closed.", "error": true}
	_busy = true
	var out: Dictionary = await _call(name, args)
	_busy = false
	if _released:
		_preview.release()
	return out


func _call(name: String, args: Dictionary) -> Dictionary:
	match name:
		"parts":
			return await _parts()
		"act":
			return await _act(args)
		"remove":
			return _remove(args)
		"watch":
			return await _watch(args)
		"model":
			return await _model(args)
		"submit":
			return _submit()
	return {"text": "There is no tool called \"%s\": parts, act, remove, watch, model and submit are the tools." % name, "error": true}


## The draft as written - the shape a one-reply answer has.
func draft() -> Dictionary:
	return {"acts": _acts.duplicate(true)}


func looks_used() -> int:
	return _looks


func _parts() -> Dictionary:
	if not TablePreview.can_set():
		return {"text": "The table cannot be stood in this run: work from the table as you were told it."}
	var got: Dictionary = await _preview.work(_table, draft())
	if got.has("error"):
		return {"text": "The table could not be stood: %s" % String(got["error"]), "error": true}
	return {"text": "THE TABLE AS IT IS SET:\n" + String(got["parts"])}


func _act(args: Dictionary) -> Dictionary:
	var raw: Variant = args.get("acts", [])
	if raw is Dictionary:
		raw = [raw]
	if not (raw is Array) or (raw as Array).is_empty():
		return {"text": "Nothing was put: give `acts`, a list of acts.", "error": true}
	var put: Array = []
	for a in raw:
		if not (a is Dictionary):
			continue
		var act := (a as Dictionary).duplicate(true)
		var nm := Manuscript.slug(String(act.get("name", "act %d" % (_acts.size() + 1))))
		act["name"] = nm
		var at := _index_of(nm)
		if at >= 0:
			_acts[at] = act
		else:
			_acts.append(act)
		_watched.erase(nm)
		if not put.has(nm):
			put.append(nm)
	var lines := PackedStringArray()
	var made := Motions.sanitize_acts(draft(), episode.beat_count())
	var kept := {}
	for k in made["acts"]:
		kept[String((k as Dictionary)["name"])] = true
	if not TablePreview.can_set():
		lines.append("(The table cannot be stood in this run: only what the format allows was checked.)")
		for n in made["notes"]:
			lines.append("- " + String(n))
		return {"text": "\n".join(lines)}
	# one table for the call: every act put is checked on it and what could not be kept read off it, never a table stood per act
	var checking: Array = put.filter(func(nm: String) -> bool: return kept.has(nm))
	var refused := await _lay_ink()
	var got: Dictionary = await _preview.work_checks(_table, draft(), checking)
	for nm in put:
		if not kept.has(nm):
			lines.append("\"%s\" could not be kept." % nm)
		elif got.has("error"):
			lines.append("\"%s\" could not be played: %s" % [nm, String(got["error"])])
		else:
			lines.append(String((got["texts"] as Dictionary).get(nm, "")))
	var notes: Array = []
	for n in made["notes"]:
		notes.append(String(n))
	notes.append_array(refused)
	for n in got.get("notes", []):
		if not notes.has(String(n)):
			notes.append(String(n))
	if not notes.is_empty():
		lines.append("WHAT COULD NOT BE KEPT:")
		for n in notes:
			lines.append("- " + String(n))
	lines.append("Acts in the work now: %s." % _names())
	return {"text": "\n".join(lines)}


## What the acts write that TeX lays out, laid out now ([method TableInk.typeset]) - only what is new since the last call - and
## written beside the preview's acts, so the table tried shows the formulas and drawings as the episode will: each one TeX refuses
## is said in TeX's own words. Nothing where TeX is not installed yet (the ink step lays it out later).
func _lay_ink() -> Array:
	var out: Array = []
	var fresh: Array = TableInk.items_of(draft()).filter(func(it: Dictionary) -> bool: return not _laid.has(String(it["id"])))
	if fresh.is_empty():
		return out
	var data: Variant = episode.read_json("data")
	var got := await TableInk.typeset(fresh, data if data is Dictionary else {}, dir.path_join("ink"))
	if got.has("error"):
		if not String(got["error"]).is_empty():
			out.append("TeX could not lay out what is written: %s" % String(got["error"]))
		return out
	if got.get("fonts") is Dictionary:
		_fonts.merge(got["fonts"], true)
	for r in got.get("items", []):
		if not (r is Dictionary):
			continue
		_laid[String((r as Dictionary).get("id", ""))] = r
		if not bool((r as Dictionary).get("ok", false)):
			var tex := ""
			for it in fresh:
				if String((it as Dictionary)["id"]) == String((r as Dictionary).get("id", "")):
					tex = String((it as Dictionary)["tex"])
			out.append("TeX could not set \"%s\": %s - write it so that it sets" % [tex.left(160), String((r as Dictionary).get("error", ""))])
	TextGen.put(dir.path_join("preview").path_join(TableInk.FILE), JSON.stringify({"items": _laid.values(), "fonts": _fonts}))
	return out


func _remove(args: Dictionary) -> Dictionary:
	var gone := PackedStringArray()
	for n in (args.get("names", []) if args.get("names") is Array else [args.get("names", "")]):
		var i := _index_of(Manuscript.slug(String(n)))
		if i >= 0:
			gone.append(String((_acts[i] as Dictionary)["name"]))
			_acts.remove_at(i)
	return {"text": ("Taken out: %s. " % ", ".join(gone) if not gone.is_empty() else "Nothing by those names. ") + "Acts in the work now: %s." % _names()}


func _watch(args: Dictionary) -> Dictionary:
	var nm := Manuscript.slug(String(args.get("name", "")))
	if _index_of(nm) < 0:
		return {"text": "There is no act called \"%s\" (the acts: %s)." % [nm, _names()], "error": true}
	if _looks >= LOOKS:
		return {"text": "No looks left: submit the work.", "error": true}
	if not TablePreview.can_set() or not TablePreview.can_see():
		return {"text": "No pictures can be taken in this run: judge the act by what `act` told you."}
	var got: Dictionary = await _preview.work_watch(_table, draft(), nm)
	if got.has("error"):
		return {"text": "\"%s\" could not be watched: %s" % [nm, String(got["error"])], "error": true}
	_looks += 1
	_watched[nm] = true
	var frames := PackedStringArray()
	for f in got["frames"]:
		frames.append("%.1f s" % float(f))
	# a watch is one look of six frames: it spends one of the looks, not six
	return {"text": "\"%s\", one picture of six frames, left to right and down: %s into it.\n%s\nLooks left: %d (a watch is one)." % [nm, ", ".join(frames), JUDGE, LOOKS - _looks],
		"images": [got["image"]]}


func _model(args: Dictionary) -> Dictionary:
	var nm := Manuscript.slug(String(args.get("name", "")))
	if _index_of(nm) < 0:
		return {"text": "There is no act called \"%s\" (the acts: %s)." % [nm, _names()], "error": true}
	if _looks >= LOOKS:
		return {"text": "No looks left: submit the work.", "error": true}
	if not TablePreview.can_set() or not TablePreview.can_see():
		return {"text": "No pictures can be taken in this run: judge it by the levels `act` told you."}
	var got: Dictionary = await _preview.model_views(_table, draft(), nm)
	if got.has("error"):
		return {"text": "What \"%s\" leaves could not be shown: %s" % [nm, String(got["error"])], "error": true}
	_looks += 1
	return {"text": "As \"%s\" leaves it, from four sides. Does it look like what it is meant to be, from every side? Looks left: %d." % [nm, LOOKS - _looks],
		"images": [got["image"]]}


func _submit() -> Dictionary:
	var made := Motions.sanitize_acts(draft(), episode.beat_count())
	if (made["acts"] as Array).is_empty():
		return {"text": "No act can be kept yet - put acts first.%s" % (("\n" + "\n".join(made["notes"])) if not (made["notes"] as PackedStringArray).is_empty() else ""), "error": true}
	var unseen: Array = []
	for a in made["acts"]:
		# (what builds is known exactly from what `act` says of it: a look at it is the agent's to spend, never owed)
		if not _watched.has(String((a as Dictionary)["name"])) and not (a as Dictionary).has("_natural"):
			unseen.append(String((a as Dictionary)["name"]))
	if not unseen.is_empty() and not _warned_unseen and TablePreview.can_see() and _looks < LOOKS:
		_warned_unseen = true
		return {"text": "Not watched since it was written: %s. Watch each, fix what it shows, then submit. (Submit again to hand the work in as it is.)" % ", ".join(unseen), "error": true}
	var raw := draft()
	var err := TextGen.put(dir.path_join(SUBMITTED) + ".part", JSON.stringify(raw, "\t"))
	if err.is_empty() and DirAccess.rename_absolute(dir.path_join(SUBMITTED) + ".part", dir.path_join(SUBMITTED)) != OK:
		err = "could not move the acts into place"
	if not err.is_empty():
		return {"text": "The work could not be handed in: %s" % err, "error": true}
	submitted = true
	return {"text": "Handed in: %d act%s. The work is blocked - your work is done; end with one short line." % [
		(made["acts"] as Array).size(), "" if (made["acts"] as Array).size() == 1 else "s"]}


func _index_of(name: String) -> int:
	for i in _acts.size():
		if String((_acts[i] as Dictionary).get("name", "")) == name:
			return i
	return -1


func _names() -> String:
	var out := PackedStringArray()
	for a in _acts:
		out.append(String((a as Dictionary).get("name", "")))
	return ", ".join(out) if not out.is_empty() else "none yet"
