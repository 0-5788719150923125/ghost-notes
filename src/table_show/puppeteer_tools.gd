extends RefCounted
class_name PuppeteerTools

## PuppeteerTools - what the puppeteer can do while it blocks an episode's WORK AT THE TABLE
## (next/table_work.md): read what on the set table can be worked, WRITE an act and be told in numbers what
## it does, WATCH it from the camera, and hand the acts in. Served as tools ([AgentTools]), as the set
## dresser's are ([SetDresserTools]); it keeps a DRAFT of acts here and works on it:
##
##   parts    the table as it is set, and what on it can be worked: each thing, whether it may be moved
##            whole, its named parts - joints, points (where each is on the table now), states, what each
##            runs and emits ([method TableWork.parts_report])
##   act      acts put into the draft - one of the same name is replaced - each answered with what it does:
##            how long, how far and how fast each moving thing goes, and ANYTHING PASSING THROUGH ANYTHING
##            ([method TableWork.check]), and what of it could not be kept, and why
##   remove   acts taken out, by name
##   watch    one act photographed from the camera's place, six times start to end
##            ([method TablePreview.work_watch])
##   submit   hand the acts in: written beside the job ([constant SUBMITTED]) for the producer to land as an
##            answer in words would land ([method TableProducer._land_acts]) - refused while an act passes
##            through something, until it is fixed or handed in so twice
##
## The user, 2026-10-25: "I want to build a system that is flexible enough to allow agents to do this for
## themselves." What it writes is data - the laws are [Motions]'s, a formula is [Formula]'s - and nothing
## it writes runs as code. EVERY PICTURE COUNTS against [constant LOOKS]; words cost nothing.

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


## [param table]: the episode's set table, as `table.json` holds it.
func _init(ep: TableEpisode, episode_plan: Dictionary, job_dir: String, table: Dictionary) -> void:
	episode = ep
	plan = episode_plan
	dir = job_dir
	_table = table
	_preview = TablePreview.new(ep, plan, dir.path_join("preview"))
	# A RUN STARTS CLEAN: a rerun works in the folder the last run left
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		var fs := String(f)
		if fs == SUBMITTED or fs == "tools.jsonl" or (fs.begins_with("look_") and fs.ends_with(".jpg")):
			DirAccess.remove_absolute(dir.path_join(fs))


func release() -> void:
	_released = true
	if not _busy:
		_preview.release()


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
		{"name": "watch", "description": "Watch one act on this episode's own table from the camera's place: six pictures, start to end, left to right and down.",
			"inputSchema": {"type": "object", "properties": {"name": {"type": "string"}}, "required": ["name"]}},
		{"name": "submit", "description": "Hand in the acts as they now stand. Answers with what keeps them from being handed in, if anything; otherwise the work is blocked, and so is your work.",
			"inputSchema": {"type": "object", "properties": {}}},
	]


## ONE CALL AT A TIME, and none once the tools are closed (as [method SetDresserTools.call_tool]).
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
		"submit":
			return _submit()
	return {"text": "There is no tool called \"%s\": parts, act, remove, watch and submit are the tools." % name, "error": true}


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
	for nm in put:
		if not kept.has(nm):
			lines.append("\"%s\" could not be kept." % nm)
			continue
		var got: Dictionary = await _preview.work_check(_table, draft(), nm)
		if got.has("error"):
			lines.append("\"%s\" could not be played: %s" % [nm, String(got["error"])])
			continue
		lines.append(String(got["text"]))
	var notes: Array = []
	for n in made["notes"]:
		notes.append(String(n))
	var stood: Dictionary = await _preview.work(_table, draft())
	for n in stood.get("notes", []):
		if not notes.has(String(n)):
			notes.append(String(n))
	if not notes.is_empty():
		lines.append("WHAT COULD NOT BE KEPT:")
		for n in notes:
			lines.append("- " + String(n))
	lines.append("Acts in the work now: %s." % _names())
	return {"text": "\n".join(lines)}


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
	return {"text": "\"%s\", six pictures, left to right and down: %s into it.\n%s\nLooks left: %d." % [nm, ", ".join(frames), JUDGE, LOOKS - _looks],
		"images": [got["image"]]}


func _submit() -> Dictionary:
	var made := Motions.sanitize_acts(draft(), episode.beat_count())
	if (made["acts"] as Array).is_empty():
		return {"text": "No act can be kept yet - put acts first.%s" % (("\n" + "\n".join(made["notes"])) if not (made["notes"] as PackedStringArray).is_empty() else ""), "error": true}
	var unseen: Array = []
	for a in made["acts"]:
		if not _watched.has(String((a as Dictionary)["name"])):
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
