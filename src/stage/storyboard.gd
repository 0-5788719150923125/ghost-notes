extends RefCounted
class_name Storyboard

## Storyboard - a show's scenes written down: the data spec, and its one owner.
##
## A SHOW IS A LIST OF ENTRIES, each naming a scene, how long it stays and how it leaves. The
## Director walks whatever list it is handed, and where it is handed none it writes one as it goes,
## from the seed (`Director._next_entry`): the seeded show is a storyboard nobody wrote down, and a
## written one is the same show made explicit. So everything that makes a show by hand - this
## spec, the editor over it ([StoryboardEditor]) - is the general case, and "automatic" is its
## shortest form.
##
## WHERE ONE LIVES. In a note's own `scenes:` block ([method of_block] - the note is the project,
## and the block is edited in the app), or in a file a note names: YAML (it holds comments) or
## JSON, both parsing to the SAME tree, so everything downstream is format-blind. Bare names
## resolve inside `res://storyboards/` (`.yaml` first, then `.json`); explicit paths are taken
## as-is. A file is read here and never written: to change one in the app, a note takes it in.
##
## TWO SHAPES, AND WHICH IS WHICH. The RAW tree is what is written: `defs`, `use` and all - what a
## note keeps and an editor edits ([DataPath] makes each edit a new tree). The LOADED form is what
## the Director walks: `use` expanded, the tree validated, the top-level `elastic` stamped into its
## entries ([method from_data]). Loading never changes the raw tree it is given.
##
## Beyond parsing, the spec owns three data conveniences:
##   defs/use  - `defs:` is a top-level map of named fragments; `use: <name>` inside
##               any map deep-merges the fragment UNDER the map's own keys (explicit
##               keys win). A map that is ONLY `{use: name}` becomes the fragment
##               verbatim (so a whole cast / track block can be a reference). This is
##               how a storyboard composes reusable pieces - "a scene calling a scene".
##   sample    - "cattle, not pets": anywhere a number is expected, `[lo, hi]` is a
##               RANGE, sampled once per instance from the scene's seeded rng via
##               [method sample]. (A two-number array is therefore always a range -
##               positions are 3-component `[x, y, z]`.)
##   validate  - structural errors come back as one clear per-path message instead of
##               a silent misload.
##
## [method load_file] and [method from_data] return the loaded form, `{ok, error, path, name,
## loop, transition, sensitivity, sequence, tail}`; on failure only `ok` / `error` matter.

const DIR := "res://storyboards/"
const MAX_USE_DEPTH := 8
## The keys of a storyboard, in the order a note's block is written in.
const KEYS := ["name", "loop", "transition", "sensitivity", "elastic", "defs", "sequence", "tail"]
## Where a storyboard's errors say it is when a note keeps it.
const IN_NOTE := "in this note"
## No entry is scheduled shorter than this, in seconds.
const MIN_ENTRY := 0.5

## THE FIELDS, AS DATA: what a storyboard, an entry, a stage's camera, an actor and a span can
## say - the editor builds its rows from these ([SchemaForm]), so a field added here is a field
## that can be set. A row: `label`, `type`, `default` (what an absent key means - an absent key
## is not written), `blurb`, and for a number `min` / `max` / `step`, for a choice `options`.
## Types: `bool`, `enum`, `float`, `int`, `text`, `num` (a number, or a sampled `[lo, hi]`
## range), `vec3` (three of those), `scene`, `targets` (actor ids, none meaning all).
##
## The choices are written out here, and not read off the registries that own them, because this
## file names no autoload and so loads under `--script`; `tests/storyboard_editor_check.gd` holds
## each list to its registry (GhostScene.BEHAVIORS, Shots.REGISTRY, Cast, Actions, Track).
const BOARD := {
	"loop": {"label": "Loop", "type": "bool", "default": true,
		"blurb": "At the end, start again from the first entry. Off, the show follows the song instead: it holds its last entry, or cycles the tail, and rolls back to the top when the song does."},
	"transition": {"label": "Transition", "type": "enum", "options": ["cut", "dip", "fade"], "default": "cut",
		"blurb": "How one entry gives way to the next unless the entry says otherwise: a hard cut, a dip through black, or a crossfade. Two entries that can morph always do."},
	"sensitivity": {"label": "Tempo", "type": "float", "min": 0.05, "max": 20.0, "step": 0.05, "default": 1.0,
		"blurb": "The story's pace. Higher is faster: every hold shrinks and every entry's timeline is compressed with it, so each event still lands. What an actor does on its own never speeds up."},
	"elastic": {"label": "Elastic", "type": "float", "min": 0.0, "max": 0.9, "step": 0.01, "default": 0.0,
		"blurb": "How far a stage's timeline breathes with the song: a loud passage runs it faster, a quiet one slower, the total unchanged. 0 keeps it even."},
}
const ENTRY := {
	"scene": {"label": "Scene", "type": "scene", "default": "",
		"blurb": "What is on screen. Stage is the one made of data: its actors and what they do are written in the entry itself."},
	"behavior": {"label": "Motion", "type": "enum", "options": ["static", "drift", "fluid"], "default": "drift",
		"blurb": "How the scene moves: held still, drifting as one, or every part moving on its own."},
	"shot": {"label": "Shot", "type": "enum", "options": ["", "centered", "offset", "push_in", "pull_back", "pan", "canted"], "default": "",
		"blurb": "How the camera frames it. Left unset, one that suits the scene is drawn from the entry's seed."},
	"seed": {"label": "Seed", "type": "int", "default": null,
		"blurb": "Pins everything the scene rolls - its colors, its shapes, each sampled range. Unset, it comes from the song and the entry's place in the list."},
	"transition": {"label": "Leaves by", "type": "enum", "options": ["", "cut", "dip", "fade"], "default": "",
		"blurb": "How this entry gives way to the next. Unset, the storyboard's own transition."},
	"sensitivity": {"label": "Tempo", "type": "float", "min": 0.05, "max": 20.0, "step": 0.05, "default": null,
		"blurb": "This entry's own pace. Unset, the storyboard's."},
}
## HOW LONG AN ENTRY STAYS, one of three ways ([method timing_of]): for a fixed time, until the
## music gives a cue, or for as long as the scene itself runs. Each lists the keys it writes.
const TIMINGS := {
	"hold": {"label": "A fixed time", "keys": ["hold"],
		"blurb": "Exactly this many seconds, whatever the music does."},
	"cue": {"label": "Until a cue", "keys": ["exit", "min_hold", "max_hold"],
		"blurb": "It leaves on the next beat, change of section or drop into quiet, no sooner and no later than the bounds."},
	"own": {"label": "The scene's own", "keys": ["min_hold", "max_hold"],
		"blurb": "A scene that plays once ends itself; one that loops leaves on a beat."},
}
const TIMING_FIELDS := {
	"hold": {"label": "Seconds", "type": "float", "min": 0.5, "max": 600.0, "step": 0.1, "default": 8.0,
		"blurb": "How long the entry stays."},
	"exit": {"label": "Cue", "type": "enum", "options": ["beat", "movement", "lull"], "default": "beat",
		"blurb": "What the entry leaves on: a beat, a change of section, or a drop into quiet."},
	"min_hold": {"label": "At least", "type": "float", "min": 0.5, "max": 600.0, "step": 0.1, "default": null,
		"blurb": "The entry never leaves sooner than this many seconds."},
	"max_hold": {"label": "At most", "type": "float", "min": 0.5, "max": 600.0, "step": 0.1, "default": null,
		"blurb": "The entry leaves by this many seconds even if no cue came."},
}
## A `stage` entry's own keys, beside the ones every entry has.
const STAGE := {
	"carry": {"label": "Carry", "type": "bool", "default": true,
		"blurb": "Actors with the same id as the entry before carry on across the cut - the same body, pose and gaze. Off, the entry opens on a clean cut."},
	"elastic": {"label": "Elastic", "type": "float", "min": 0.0, "max": 0.9, "step": 0.01, "default": null,
		"blurb": "This entry's own breathing with the song. Unset, the storyboard's."},
}
const CAMERA := {
	"eye": {"label": "Eye", "type": "vec3", "default": [0, 0, 4.0], "blurb": "Where the camera stands."},
	"look": {"label": "Looks at", "type": "vec3", "default": [0, 0, 0], "blurb": "The point it faces."},
	"fov": {"label": "Field of view", "type": "num", "min": 10.0, "max": 120.0, "step": 1.0, "default": 48.0,
		"blurb": "In degrees: wider takes in more and deepens the perspective."},
}
## What every actor says, whatever its kind; a kind's own fields are [constant Cast.PARAMS].
const ACTOR := {
	"id": {"label": "Name", "type": "text", "default": "",
		"blurb": "What the timeline calls this actor. One name, one body: the same name in the next stage entry is the same actor, carried across."},
	"kind": {"label": "Kind", "type": "enum", "options": ["eye", "prism", "swarm"], "default": "eye",
		"blurb": "What it is."},
	"at": {"label": "Place", "type": "vec3", "default": [0, 0, 0],
		"blurb": "Where it stands: right, up and toward the camera. With the camera at its default, 0.62 to either side are the two side-by-side places."},
	"hidden": {"label": "Starts hidden", "type": "bool", "default": false,
		"blurb": "It is there but unseen until something on the timeline reveals it."},
	"seed": {"label": "Seed", "type": "int", "default": null,
		"blurb": "Pins what this actor rolls for itself. Unset, it comes from the entry's seed."},
}
## What every span says; a verb's own settings are [constant Actions.ARGS].
const SPAN := {
	"action": {"label": "Does", "type": "enum", "default": "set",
		"options": ["look", "blink", "arrive", "sprout", "split", "crystallize", "tremble", "burst", "lock",
			"desync", "hold_still", "sway", "counterflow", "specialize", "gather", "fly", "helix_split",
			"lane_jump", "set", "ramp", "pulse", "flash"],
		"blurb": "What happens."},
	"target": {"label": "Who", "type": "targets", "default": null,
		"blurb": "The actors it happens to. None chosen means everyone on the stage."},
	"ease": {"label": "Ease", "type": "enum", "options": ["smooth", "linear", "in", "out", "spike"], "default": "smooth",
		"blurb": "The shape of its progress across the window. A verb with phases of its own wants linear."},
	"on": {"label": "Waits for", "type": "enum", "options": ["", "beat", "movement", "lull"], "default": "",
		"blurb": "A cue in the music the span waits for once its time has come, so a drop lands on the drop."},
	"by": {"label": "No later than", "type": "float", "min": 0.0, "max": 30.0, "step": 0.1, "default": 1.5,
		"blurb": "Seconds it waits for that cue before going anyway."},
	"sustain": {"label": "Keeps on", "type": "bool", "default": false,
		"blurb": "After its window closes it carries on at full strength for the rest of the entry, instead of finishing."},
}


static func load_file(name_or_path: String) -> Dictionary:
	var raw := read_raw(name_or_path)
	if not bool(raw.ok):
		return _fail(String(raw.error))
	return from_data(raw.data, String(raw.path), name_or_path, String(raw.path))


## A storyboard file as it is WRITTEN - parsed, its `defs` and `use` still in it: what a note takes
## in to make it its own. `{ok, error, path, data}`.
static func read_raw(name_or_path: String) -> Dictionary:
	var path := resolve_path(name_or_path)
	if path.is_empty():
		return {"ok": false, "error": "storyboard not found: %s" % name_or_path, "path": "", "data": {}}
	var text := FileAccess.get_file_as_string(path)
	var data: Variant
	if path.ends_with(".json"):
		data = JSON.parse_string(text)
		if data == null:
			return {"ok": false, "error": "storyboard %s: invalid JSON" % path, "path": path, "data": {}}
	else:
		var y := MiniYaml.parse(text)
		if not y.ok:
			return {"ok": false, "error": "storyboard %s: %s" % [path, y.error], "path": path, "data": {}}
		data = y.data
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "storyboard %s: top level must be a map" % path, "path": path, "data": {}}
	return {"ok": true, "error": "", "path": path, "data": data}


## THE LOADED FORM of a raw storyboard, whoever holds it: `use` expanded, the tree validated, the
## top-level `elastic` stamped into the entries. [param where] is how its errors name it - a file's
## path, or [constant IN_NOTE]. [param data] is left exactly as it was handed in.
static func from_data(data: Variant, where: String, fallback_name := "", path := "") -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return _fail("storyboard %s: top level must be a map" % where)
	# Expand defs/use into a plain tree, then validate the result.
	var defs: Variant = (data as Dictionary).get("defs", {})
	if typeof(defs) != TYPE_DICTIONARY:
		return _fail("storyboard %s: 'defs' must be a map" % where)
	var ctx := {"error": ""}
	var expanded: Dictionary = _expand(data, defs, 0, ctx)
	if ctx.error != "":
		return _fail("storyboard %s: %s" % [where, String(ctx.error)])
	var verr := _validate(expanded, where)
	if verr != "":
		return _fail(verr)

	# A top-level `elastic` (the music-breathing timeline clock, see scenes/stage.gd)
	# stamps into every entry that doesn't set its own, so one number tunes the show.
	if expanded.has("elastic"):
		for e in expanded["sequence"]:
			if not (e as Dictionary).has("elastic"):
				e["elastic"] = expanded["elastic"]
		for e in expanded.get("tail", []):
			if not (e as Dictionary).has("elastic"):
				e["elastic"] = expanded["elastic"]

	return {
		"ok": true, "error": "", "path": path,
		"name": String(expanded.get("name", fallback_name)),
		"loop": bool(expanded.get("loop", true)),
		"transition": String(expanded.get("transition", "")),
		"sensitivity": float(expanded.get("sensitivity", -1.0)),
		"sequence": expanded["sequence"],
		"tail": expanded.get("tail", []),
	}


## WHAT A NOTE'S `scenes:` BLOCK HOLDS, `{kind, name, data}`: its OWN storyboard (`kind` "own", the
## raw tree in `data` - a block with a `sequence`, even an empty one), the name or path of a FILE
## (`kind` "file", in `name`), or nothing written down ("none": the show is the seed's).
static func of_block(block: Variant) -> Dictionary:
	if not (block is Dictionary):
		return {"kind": "none", "name": "", "data": {}}
	var b: Dictionary = block
	if b.get("sequence") is Array:
		var data := {}
		for k in KEYS:
			if b.has(k):
				data[k] = b[k]
		return {"kind": "own", "name": String(b.get("name", "")), "data": data.duplicate(true)}
	var named := String(b.get("storyboard", "")).strip_edges()
	if not named.is_empty():
		return {"kind": "file", "name": named, "data": {}}
	return {"kind": "none", "name": "", "data": {}}


## The block a note keeps its OWN storyboard in: [param data]'s keys in [constant KEYS]' order,
## and a `sequence` always - an empty one is a storyboard with nothing written in it yet, which is
## still the note's own.
static func own_block(data: Dictionary) -> Dictionary:
	var out := {}
	for k in KEYS:
		if data.has(k):
			out[k] = data[k]
	if not (out.get("sequence") is Array):
		out["sequence"] = []
	return out.duplicate(true)


## The block of a note that plays a storyboard FILE: its name in `res://storyboards/`, or a path.
static func file_block(name_or_path: String) -> Dictionary:
	return {"storyboard": name_or_path}


## HOW AN ENTRY IS TIMED - a key of [constant TIMINGS]: "hold" (a fixed time), "cue" (until the
## music gives one) or "own" (the scene's own lifecycle).
static func timing_of(entry: Dictionary) -> String:
	if entry.has("hold"):
		return "hold"
	return "cue" if entry.has("exit") else "own"


## [param entry] timed another way: the keys of its old timing dropped, and the ones the new one
## needs filled with their defaults. A bound both ways share (`min_hold`, `max_hold`) is kept.
static func with_timing(entry: Dictionary, timing: String) -> Dictionary:
	var out := entry.duplicate(true)
	var keep: Array = (TIMINGS.get(timing, TIMINGS["own"]) as Dictionary)["keys"]
	for k in TIMING_FIELDS:
		if out.has(k) and not keep.has(k):
			out.erase(k)
	for k in keep:
		var d: Variant = (TIMING_FIELDS[k] as Dictionary)["default"]
		if not out.has(k) and d != null:
			out[k] = d
	return out


## How long [param entry] is SCHEDULED to stay, in seconds: its fixed hold, else the least it
## stays, else [param unauthored] (what an entry that says nothing gets) - over its tempo
## ([param sensitivity] where it names none). An entry that leaves on a cue has no fixed length;
## this is where the schedule counts it from.
static func entry_length(entry: Dictionary, sensitivity: float, unauthored: float) -> float:
	var sens := clampf(float(entry.get("sensitivity", sensitivity)), 0.05, 20.0)
	var dur := unauthored
	if entry.has("hold"):
		dur = float(entry["hold"])
	elif entry.has("min_hold"):
		dur = float(entry["min_hold"])
	return maxf(MIN_ENTRY, dur / sens)


## THE SCHEDULE of [param sequence]: `starts` (each entry's start, in seconds), `lengths`, and
## `end`, where the sequence hands over to the tail. One function for the Director's walk and the
## editor's ruler, so what is drawn is what plays.
static func schedule(sequence: Array, sensitivity: float, unauthored: float) -> Dictionary:
	var starts: Array = []
	var lengths: Array = []
	var acc := 0.0
	for item in sequence:
		starts.append(acc)
		var n := entry_length(item as Dictionary, sensitivity, unauthored) if item is Dictionary else MIN_ENTRY
		lengths.append(n)
		acc += n
	return {"starts": starts, "lengths": lengths, "end": acc}


## A new entry for [param scene], as the editor adds one: a stage with a camera, an empty cast and
## an empty timeline; any other scene with nothing but its name - every key unset is a default.
static func new_entry(scene: String) -> Dictionary:
	if scene != "stage":
		return {"scene": scene}
	return {"scene": "stage", "behavior": "static", "hold": 8.0,
		"camera": {"eye": [0, 0, 4.0], "look": [0, 0, 0], "fov": 48},
		"cast": [], "track": {"nominal": 8.0, "spans": []}}


## A LOADED storyboard as a raw tree again - every `use` already expanded - for handing a render
## what a session walks, where it is in no file of its own.
static func raw_of(loaded: Dictionary) -> Dictionary:
	var out := {"name": String(loaded.get("name", "")), "loop": bool(loaded.get("loop", true))}
	if not String(loaded.get("transition", "")).is_empty():
		out["transition"] = String(loaded["transition"])
	if float(loaded.get("sensitivity", -1.0)) > 0.0:
		out["sensitivity"] = float(loaded["sensitivity"])
	out["sequence"] = (loaded.get("sequence", []) as Array).duplicate(true)
	if not (loaded.get("tail", []) as Array).is_empty():
		out["tail"] = (loaded["tail"] as Array).duplicate(true)
	return out


## A storyboard as YAML text, in [constant KEYS]' order - what the editor's source view shows, and
## what a note's export hands its render.
static func to_yaml(data: Dictionary) -> String:
	return MiniYaml.emit(own_block(data))


## ...and back: `{ok, error, data}`, the raw tree, refused with the reason where the text does not
## parse or does not make a storyboard that loads.
static func from_yaml(text: String) -> Dictionary:
	var y := MiniYaml.parse(text)
	if not y.ok:
		return {"ok": false, "error": String(y.error), "data": {}}
	if not (y.data is Dictionary):
		return {"ok": false, "error": "a storyboard is a map: `sequence:` and the rest", "data": {}}
	var data := own_block(y.data as Dictionary)
	if not (data["sequence"] as Array).is_empty():
		var loaded := from_data(data, IN_NOTE)
		if not bool(loaded.ok):
			return {"ok": false, "error": String(loaded.error), "data": {}}
	return {"ok": true, "error": "", "data": data}


## Resolve a bare name or explicit path to an existing storyboard file, or "".
static func resolve_path(name_or_path: String) -> String:
	var cands: Array = [name_or_path] \
		if name_or_path.ends_with(".json") or name_or_path.ends_with(".yaml") or name_or_path.ends_with(".yml") \
		else [DIR + name_or_path + ".yaml", DIR + name_or_path + ".yml", DIR + name_or_path + ".json"]
	for p in cands:
		if FileAccess.file_exists(p):
			return p
	return ""


## [param node] with every `use` in it expanded against [param defs]: what one map of a raw
## storyboard is worth once loaded, for an editor showing a value its own keys do not write.
## Returned as it was where a def is missing.
static func expanded(node: Variant, defs: Variant) -> Variant:
	var ctx := {"error": ""}
	var out: Variant = _expand(node, defs if defs is Dictionary else {}, 0, ctx)
	return out if String(ctx.error).is_empty() else node


## Sample a spec value with a seeded rng: a two-number array is a `[lo, hi]` range
## (one draw per call site = once per instance); everything else recurses. Call this
## on any user-authored numeric config before baking it into an instance.
static func sample(v: Variant, rng: RandomNumberGenerator) -> Variant:
	match typeof(v):
		TYPE_ARRAY:
			var a: Array = v
			if a.size() == 2 and _is_num(a[0]) and _is_num(a[1]):
				return rng.randf_range(float(a[0]), float(a[1]))
			var out := []
			for it in a:
				out.append(sample(it, rng))
			return out
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = sample(v[k], rng)
			return d
		_:
			return v


## A spec vector: `[x, y, z]` where each component may itself be a `[lo, hi]` range.
static func sample_vec3(v: Variant, rng: RandomNumberGenerator, fallback := Vector3.ZERO) -> Vector3:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() != 3:
		return fallback
	var a: Array = v
	return Vector3(float(sample(a[0], rng)) if typeof(a[0]) == TYPE_ARRAY else float(a[0]),
		float(sample(a[1], rng)) if typeof(a[1]) == TYPE_ARRAY else float(a[1]),
		float(sample(a[2], rng)) if typeof(a[2]) == TYPE_ARRAY else float(a[2]))


static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "path": "", "name": "", "loop": true,
		"transition": "", "sensitivity": -1.0, "sequence": [], "tail": []}


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


# Recursive defs/use expansion. `depth` counts USE hops only (cycle guard), not tree
# depth. Node keys always win over fragment keys; dict-vs-dict conflicts merge deep.
static func _expand(node: Variant, defs: Dictionary, depth: int, ctx: Dictionary) -> Variant:
	if ctx.error != "":
		return node
	match typeof(node):
		TYPE_DICTIONARY:
			var d: Dictionary = node
			if d.has("use"):
				if depth >= MAX_USE_DEPTH:
					ctx.error = "'use' nesting deeper than %d (a def cycle?)" % MAX_USE_DEPTH
					return node
				var key := String(d["use"])
				if not defs.has(key):
					ctx.error = "unknown def '%s' (available: %s)" % [key, ", ".join(defs.keys())]
					return node
				var frag: Variant = _expand(defs[key], defs, depth + 1, ctx)
				if ctx.error != "":
					return node
				if d.size() == 1:
					return frag                       # a pure reference becomes the fragment itself
				if typeof(frag) != TYPE_DICTIONARY:
					ctx.error = "def '%s' must be a map to merge extra keys over it" % key
					return node
				var out: Dictionary = (frag as Dictionary).duplicate(true)
				for k in d:
					if k == "use":
						continue
					var val: Variant = _expand(d[k], defs, depth, ctx)
					if out.has(k) and typeof(out[k]) == TYPE_DICTIONARY and typeof(val) == TYPE_DICTIONARY:
						out[k] = _merge(out[k], val)
					else:
						out[k] = val
				return out
			var plain := {}
			for k in d:
				plain[k] = _expand(d[k], defs, depth, ctx)
			return plain
		TYPE_ARRAY:
			var arr := []
			for it in node:
				arr.append(_expand(it, defs, depth, ctx))
			return arr
		_:
			return node


# Deep merge: `over`'s keys win; nested maps merge recursively; arrays replace whole.
static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over:
		if out.has(k) and typeof(out[k]) == TYPE_DICTIONARY and typeof(over[k]) == TYPE_DICTIONARY:
			out[k] = _merge(out[k], over[k])
		else:
			out[k] = over[k]
	return out


# Structural validation with per-path messages. Kept to what would otherwise fail
# silently or crash deep inside a scene; scenes still own their semantic defaults.
static func _validate(data: Dictionary, path: String) -> String:
	if not data.has("sequence"):
		return "storyboard %s has no 'sequence' array" % path
	if typeof(data["sequence"]) != TYPE_ARRAY or (data["sequence"] as Array).is_empty():
		return "storyboard %s sequence is empty" % path
	var seq: Array = data["sequence"]
	for idx in seq.size():
		var err := _validate_entry(seq[idx], "%s: sequence[%d]" % [path, idx])
		if err != "":
			return err
	if data.has("tail"):
		if typeof(data["tail"]) != TYPE_ARRAY:
			return "storyboard %s 'tail' must be a list of entries" % path
		var tail: Array = data["tail"]
		for idx in tail.size():
			var err := _validate_entry(tail[idx], "%s: tail[%d]" % [path, idx])
			if err != "":
				return err
	return ""


static func _validate_entry(entry: Variant, where: String) -> String:
	if typeof(entry) != TYPE_DICTIONARY:
		return where + " must be a map"
	var e: Dictionary = entry
	if String(e.get("scene", "")).is_empty():
		return where + " is missing 'scene'"
	for k in ["hold", "min_hold", "max_hold", "sensitivity", "elastic"]:
		if e.has(k) and not _is_num(e[k]):
			return "%s.%s must be a number" % [where, k]
	if String(e["scene"]) == "stage":
		return _validate_stage(e, where)
	return ""


# Shape checks for a data-driven `stage` entry: a cast of uniquely-id'd actors and a
# track of timed spans (see scenes/stage.gd for the semantics).
static func _validate_stage(e: Dictionary, where: String) -> String:
	if e.has("cast"):
		if typeof(e["cast"]) != TYPE_ARRAY:
			return where + ".cast must be a list of actors"
		var ids := {}
		for j in (e["cast"] as Array).size():
			var a: Variant = e["cast"][j]
			var aw := "%s.cast[%d]" % [where, j]
			if typeof(a) != TYPE_DICTIONARY:
				return aw + " must be a map"
			var id := String((a as Dictionary).get("id", ""))
			if id.is_empty():
				return aw + " is missing 'id'"
			if String((a as Dictionary).get("kind", "")).is_empty():
				return aw + " is missing 'kind'"
			if ids.has(id):
				return "%s duplicates actor id '%s'" % [aw, id]
			ids[id] = true
	if e.has("track"):
		if typeof(e["track"]) != TYPE_DICTIONARY:
			return where + ".track must be a map with 'spans'"
		var tr: Dictionary = e["track"]
		if typeof(tr.get("spans", [])) != TYPE_ARRAY:
			return where + ".track.spans must be a list"
		for j in (tr.get("spans", []) as Array).size():
			var s: Variant = tr["spans"][j]
			var sw := "%s.track.spans[%d]" % [where, j]
			if typeof(s) != TYPE_DICTIONARY:
				return sw + " must be a map"
			var sd: Dictionary = s
			if String(sd.get("action", "")).is_empty():
				return sw + " is missing 'action'"
			if not (sd.has("at") or sd.has("from")):
				return sw + " needs 'at' or 'from'"
			for k in ["at", "from", "to", "by"]:
				if sd.has(k) and not _is_num(sd[k]):
					return "%s.%s must be a number (seconds of the track's nominal)" % [sw, k]
	return ""
