extends RefCounted
class_name CartoonProducer

## CartoonProducer - what agents make for a cartoon (next/cartoon.md), one note's: each character RIGGED from its drawing by the rigger
## ([RiggerTools], rules/cartoon/rigger.yaml) onto the library's `puppets` shelf, each set PAINTED in the cast's own drawing style
## (rules/cartoon/set_painter.yaml, the cast's drawings its references) onto the `sets` shelf, and the STORYBOARD written by the director
## (rules/cartoon/director.yaml) into the note's folder ([NoteStoryboard]), where the note's show plays it. Each is one agent job
## ([AgentJobs]); [method pump] lands what ended. A storyboard that will not play is sent back once with what was wrong with it.
##
## What it works from is the note's `cartoon:` block: `cast` [{name, picture, about, height}], `sets` [{name, place}], `seconds`, and
## `silent` (no sound: talking is only seen). Puppets and sets are named, so every note can use them (a Dex shelf each).

## How long an agent may take (s): a rigger looks at a dozen pictures; a director writes one reply.
const RIG_MOST := 2400
const WRITE_MOST := 900
## A cartoon's length unless its block says, and how far a storyboard may stray from it.
const SECONDS := 30.0
const STRAY := [0.6, 1.6]
## The verbs a director is told of, each in a few words; their settings are [constant Actions.ARGS]' rows.
const VERBS := {
	"move": "a puppet goes to a place, on foot (its gait swings its legs and arms at the pace it goes)",
	"talk": "its jaw chatters and its head nods for the window - a line said, unheard",
	"pose": "it takes a pose and holds it (or, with ease spike, strikes it and comes back)",
	"face": "it turns: left or right (in profile), toward another actor, front (to us) or back (away); it holds that view until turned again",
	"feel": "it shows a mood from now on (scared, angry, laughing), or none",
	"strike": "it winds up and hits another, who reels; a mark where it lands",
	"hit": "it is hit (from another actor's side, or left or right): recoils, spins, eyes pop",
	"hop": "it crouches, springs up and lands, in place or to a place",
	"shake": "it shakes for the window: fear, rage",
	"fx": "a mark drawn on it a moment",
	"blink": "it blinks",
	"ramp": "eases a value across the window (`fade` 0 to 1 brings it in; 1 to 0 takes it away)",
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
		if not painted(String(s["name"])) and not busy("set:" + String(s["name"])):
			why = paint(s)
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
func sheet(c: Dictionary) -> String:
	var name := String(c.get("name", ""))
	var picture := _abs(String(c.get("picture", "")))
	if not FileAccess.file_exists(picture):
		return _fail("rig:" + name, "%s's drawing is not at %s" % [name, picture])
	if not Library.writable():
		return _fail("rig:" + name, "this session cannot write the library (read-only)")
	var where := PuppetRig.folder_of(name)
	var original := _as_png(picture, where.path_join("refs"))
	var made := {}
	_sheets[name] = {"picture": picture, "original": original, "about": String(c.get("about", "")), "folder": where, "made": made,
		"said": "painting its drawings"}
	_errors.erase("rig:" + name)
	for key in PuppetSheet.order():
		var row: Dictionary = PuppetSheet.REGISTRY[key]
		var from := String(row["from"])
		var refs := PackedStringArray([original]) if from.is_empty() else PackedStringArray([where.path_join(from).path_join(PAINTED), original])
		var prompt := Rules.say("cartoon/sheet.prompt", {"ask": String(row["ask"]), "file": "image.png", "has_base": not from.is_empty()})
		made[key] = "painting"
		var err := _submit("paint:%s:%s" % [name, key], {"kind": "image", "backend": String(painter["agent"]),
			"dir": where.path_join(key).path_join("paint"), "prompt": prompt, "refs": refs, "target": where.path_join(key).path_join(PAINTED),
			"lane": "sheet:" + name, "label": "cartoon %s %s" % [name, key], "model": String(painter["model"]),
			"effort": String(painter["effort"])}, {"name": name, "key": key})
		if not err.is_empty():
			_sheets.erase(name)
			return _fail("rig:" + name, err)
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
			got = await RiggerTools.host("align", {"dir": dir, "base": String(s["folder"]).path_join(from)}, dir.path_join("job"))
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
		if k in ["front", "side"]:
			made[k] = "rigging"
			_rig_drawing(name, k)
		elif String(row["view"]) == "back" or not String(row["mood"]).is_empty():
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
	var prompt := Rules.say("cartoon/set_painter.prompt", {"place": String(s.get("place", name)), "file": "image.png"})
	return _submit("set:" + name, {"kind": "image", "backend": String(painter["agent"]), "dir": dir, "prompt": prompt, "refs": refs,
		"target": target, "label": "cartoon set " + name, "model": String(painter["model"]), "effort": String(painter["effort"])},
		{"name": name})


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
		for k in r.drawings:
			drawn.append(String((PuppetSheet.REGISTRY.get(k, {"label": k}) as Dictionary)["label"]).to_lower())
		var tall := float(c.get("height", 1.0))
		var wide := tall * float((r.data.get("size", [1, 1]) as Array)[0]) / r.height()
		cast_lines.append("- rig \"%s\": %s Usual height %.2f, and %.2f wide at that height. Bones: %s%s%s." % [name,
			String(r.data.get("about", c.get("about", ""))).strip_edges(), tall, wide, ", ".join(parts),
			("; drawn %s" % ", ".join(drawn)) if drawn.size() > 1 else ("; a jaw that talks" if r.data.get("mouth") is Dictionary else "; no mouth that moves"),
			("; its own poses: " + ", ".join(own)) if not own.is_empty() else ""])
	var set_lines := PackedStringArray()
	for s in sets():
		set_lines.append("- \"%s\": %s" % [String(s["name"]), String(s.get("place", ""))])
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
		"shots": maxi(3, int(round(seconds / 4.5))), "cast": "\n".join(cast_lines), "sets": "\n".join(set_lines),
		"verbs": "\n".join(verb_lines), "poses": ", ".join(Actions.POSE_NAMES), "gaits": ", ".join(Actions.GAITS),
		"fx": ", ".join(Actions.FX_KINDS), "half_width": "1.2", "ground": "-0.72", "silent": bool(block.get("silent", true)),
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
		if hold < 1.5 or hold > 12.0:
			return "%s holds %.1f seconds; a shot is 1.5 to 12." % [where, hold]
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
		var track: Dictionary = e.get("track", {}) if e.get("track") is Dictionary else {}
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


## The director's reply [param text] as the JSON object in it (fences and words round it left out); null where there is none.
static func parse_board(text: String) -> Variant:
	var a := text.find("{")
	var b := text.rfind("}")
	if a < 0 or b <= a:
		return null
	var got: Variant = JSON.parse_string(text.substr(a, b - a + 1))
	return Storyboard.whole(got) if got != null else null


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
		elif String(key).begins_with("set:"):
			if not bool(res.get("ok", false)):
				_fail(key, "the painter made nothing: %s" % String(res.get("error", "")).left(200))
		elif key == "board":
			if not bool(res.get("ok", false)):
				_fail(key, "the director stopped: %s" % String(res.get("error", "")).left(200))
				continue
			var data: Variant = parse_board(String(res.get("text", "")))
			var why := check(data)
			if why.is_empty():
				var err := NoteStoryboard.write(folder, data)
				if not err.is_empty():
					_fail(key, err)
			elif int(w.get("tries", 0)) < 1:
				direct(why)
			else:
				_fail(key, "the storyboard written would not play: %s" % why)
