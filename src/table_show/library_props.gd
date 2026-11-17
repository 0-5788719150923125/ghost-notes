extends PropSection
class_name LibraryProps

## LibraryProps - the library's props on the Dex's shelves ([DexWindow]): the props kept ("Kept props", [ThingLibrary]) and every
## thing any episode's set dresser made, read where it stands ("Seen props", read on a worker, never copied until it is kept). A
## kept prop is renamed in place, exported to a `.prop.json` to hand on, or removed to the trash; a seen one is kept; any is turned
## whole in 3D ([method model_of]). A prop's picture is taken once and kept by its hash ([PropStudio], [PropPictures]): those near
## the view first, then every other on the shelf shown. Opened on its own it adds nothing; a presentation's section adds what it
## offers ([EpisodeProps]).

const SHELVES := [
	{"key": "kept", "label": "Kept props", "tip": "The props in your library, kept from any show."},
	{"key": "seen", "label": "Seen props", "tip": "Every prop a set dresser has made for any episode, as it stands there. Keep one to have it in your library."},
]
## How long what was read is trusted before it is read again (seconds): the library, and every episode's table.
const LIBRARY_FRESH := 3.0
const SEEN_FRESH := 60.0

## Pictures of props, taken one at a time: shared with whatever section holds this one.
var pictures := PropPictures.new()
var _library: Array = []          # ThingLibrary.entries(), as last read
var _library_t := -INF
var _seen: Array = []             # every thing every episode stands: {key, name, line, tip, thing, materials, hash}
var _seen_t := -INF
var _seen_task := -1
var _seen_out: Array = []
var _seen_at := {}                # offer key -> its index in _seen


func shelves() -> Array:
	return SHELVES


func offers() -> Array:
	var out: Array = []
	for e in entries():
		var ed: Dictionary = e
		var h := String(ed["hash"])
		var line := pictures.size_of(h)
		if not String(ed["line"]).is_empty():
			line = String(ed["line"]) if line.is_empty() else line + " - " + String(ed["line"])
		out.append({"key": "kept:" + String(ed["name"]), "name": String(ed["name"]), "line": line, "shelf": "kept", "named": true,
			"tip": " ".join(PackedStringArray(ThingLibrary._traits(ed))), "picture": pictures.image(h),
			"verbs": [{"key": "forget", "label": "Remove", "tip": "Take it out of your library, to the trash."}]})
	var kept := kept_by_hash()
	for s in seen_list():
		var sd: Dictionary = s
		var as_kept := String(kept.get(String(sd["hash"]), ""))
		out.append({"key": String(sd["key"]), "name": String(sd["name"]), "line": String(sd["line"]), "shelf": "seen",
			"tip": String(sd["tip"]), "picture": pictures.image(String(sd["hash"])),
			"verbs": [{"key": "keep_seen", "label": "Kept" if not as_kept.is_empty() else "Keep", "off": not as_kept.is_empty(),
				"tip": ("In your library as %s." % as_kept) if not as_kept.is_empty() else "Keep it in your library."}]})
	return out


func act(key: String, verb: String) -> String:
	match verb:
		"forget":
			if not key.begins_with("kept:"):
				return "only a prop in your library can be removed"
			if not Library.writable():
				return "this session is read-only"
			var err := ThingLibrary.remove(key.substr(5))
			refresh()
			return err
		"keep_seen":
			var s := seen_of(key)
			if s.is_empty():
				return "that prop is gone"
			return keep(s["thing"], s["materials"], "")
	return "nothing here does that"


func versions_of() -> PropVersions:
	return LibraryVersions.new(self)


func want_pictures(keys: Array) -> void:
	pictures.want(_asked(keys))


func prepare_pictures(keys: Array) -> void:
	pictures.prepare(_asked(keys))


func picture(key: String) -> Variant:
	var p := prop_of(key)
	return pictures.image(String(p["hash"])) if not p.is_empty() else null


## The props of offers [param keys], as [PropPictures] is asked for them: each `[hash, thing, materials]`.
func _asked(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		var p := prop_of(String(k))
		if not p.is_empty():
			out.append([String(p["hash"]), p["thing"], p["materials"]])
	return out


func rename(key: String, name: String) -> String:
	if not key.begins_with("kept:"):
		return "only a prop in your library can be renamed"
	if not Library.writable():
		return "this session is read-only"
	var was := key.substr(5)
	var err := ThingLibrary.rename(was, name, String(entry(was).get("line", "")))
	refresh()
	return err


func prop_of(key: String) -> Dictionary:
	if key.begins_with("kept:"):
		var e := entry(key.substr(5))
		return {} if e.is_empty() else {"name": String(e["name"]), "thing": e["thing"], "materials": e["materials"], "hash": String(e["hash"])}
	if key.begins_with("seen:"):
		var sd := seen_of(key)
		return {} if sd.is_empty() else {"name": String(sd["name"]), "thing": sd["thing"], "materials": sd["materials"], "hash": String(sd["hash"])}
	return {}


func model_of(key: String) -> Dictionary:
	var p := prop_of(key)
	if p.is_empty():
		return {}
	return await PropStudio.model(p["thing"], p["materials"], String(p["hash"]))


func exportable(key: String) -> bool:
	return key.begins_with("kept:")


func export_to(key: String, path: String) -> String:
	if not key.begins_with("kept:"):
		return "only a prop in your library can be exported"
	return ThingLibrary.export_to(key.substr(5), path)


func import_from(path: String) -> String:
	if not Library.writable():
		return "this session is read-only"
	var why: Array = []
	var name := ThingLibrary.import_from(path, why)
	refresh()
	return "" if not name.is_empty() else "; ".join(PackedStringArray(why))


# --- the library -------------------------------------------------------------------------------------

## Thing [param thing] built of [param mats] kept in the library under its own name (or the next free one, "cup 2"), its picture
## asked for. "" done, else why not.
func keep(thing: Dictionary, mats: Dictionary, line: String) -> String:
	if not Library.writable():
		return "this session is read-only"
	var t := thing.duplicate(true)
	var base := String(t.get("name", "a prop")).strip_edges()
	var name := base
	var n := 2
	# never over another prop of its name
	while not ThingLibrary.read(name).is_empty():
		name = "%s %d" % [base, n]
		n += 1
	t["name"] = name
	var err := ThingLibrary.keep(t, mats, line)
	refresh()
	if err.is_empty():
		var e := ThingLibrary.read(name)
		if not e.is_empty():
			pictures.of(String(e["hash"]), e["thing"], e["materials"])
	return err


## What was read of the library forgotten: the next look reads it again.
func refresh() -> void:
	_library_t = -INF


## The props kept, as last read (again once [constant LIBRARY_FRESH] has passed).
func entries() -> Array:
	if Time.get_ticks_msec() * 0.001 - _library_t > LIBRARY_FRESH:
		_library = ThingLibrary.entries()
		_library_t = Time.get_ticks_msec() * 0.001
	return _library


## The prop kept as [param name], {} for none.
func entry(name: String) -> Dictionary:
	for e in entries():
		if String((e as Dictionary)["name"]) == name:
			return e
	return {}


## Each prop kept, by the hash of every one of its versions ([method ThingLibrary.hashes_of]): hash -> its name. A prop refined
## is found by the hash it was kept with, so the one it was kept from says Kept.
func kept_by_hash() -> Dictionary:
	var out := {}
	for e in entries():
		for h in ThingLibrary.hashes_of(e):
			out[String(h)] = String((e as Dictionary)["name"])
	return out


## Every thing any episode stands, once each by what it is: read on a worker, and what was read so far meanwhile.
func seen_list() -> Array:
	if _seen_task >= 0 and WorkerThreadPool.is_task_completed(_seen_task):
		WorkerThreadPool.wait_for_task_completion(_seen_task)
		_seen_task = -1
		_took_seen()
		_seen_t = Time.get_ticks_msec() * 0.001
	if _seen_task < 0 and Time.get_ticks_msec() * 0.001 - _seen_t > SEEN_FRESH:
		var root := ProjectSettings.globalize_path(TableEpisode.root)
		_seen_t = Time.get_ticks_msec() * 0.001
		_seen_task = WorkerThreadPool.add_task(func() -> void: _seen_out = seen_in(root))
	return _seen


## The read of every episode's things on a worker waited for, if one is under way: before what holds this section goes.
func settle() -> void:
	if _seen_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_seen_task)
		_seen_task = -1
		_took_seen()
	pictures.settle()


## What the worker read of the episodes taken as the seen props.
func _took_seen() -> void:
	_seen = _seen_out
	_seen_at = {}
	for i in _seen.size():
		_seen_at[String((_seen[i] as Dictionary)["key"])] = i


## The seen thing of offer [param key], {} for none.
func seen_of(key: String) -> Dictionary:
	return _seen[int(_seen_at[key])] if _seen_at.has(key) else {}


## Every thing the episodes under [param root] (absolute: `<show>/<seed>/table.json`) stand, once each by what it is ([method
## ThingLibrary.hash_of]): `{key, name, line, tip, thing, materials, hash}`, newest episode first. Touches no tree: read on a worker.
static func seen_in(root: String) -> Array:
	var tables: Array = []
	if not DirAccess.dir_exists_absolute(root):
		return []
	for show in DirAccess.get_directories_at(root):
		var sdir := root.path_join(show)
		for seed in DirAccess.get_directories_at(sdir):
			var path := sdir.path_join(seed).path_join("table.json")
			if FileAccess.file_exists(path):
				tables.append([FileAccess.get_modified_time(path), path, String(show), String(seed)])
	tables.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var out: Array = []
	var had := {}
	for tb in tables:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(tb[1])))
		if not (raw is Dictionary):
			continue
		var mats: Dictionary = (raw as Dictionary).get("materials", {}) if (raw as Dictionary).get("materials") is Dictionary else {}
		var things: Array = (raw as Dictionary).get("things", []) if (raw as Dictionary).get("things") is Array else []
		for i in things.size():
			if not (things[i] is Dictionary) or not ((things[i] as Dictionary).get("parts") is Array):
				continue
			var th: Dictionary = things[i]
			var e := ThingLibrary.entry_of(th, mats)
			if e.is_empty() or had.has(String(e["hash"])):
				continue
			had[String(e["hash"])] = true
			out.append({"key": "seen:%s/%s/%d" % [String(tb[2]), String(tb[3]), i], "name": String(e["name"]),
				"line": "%s, episode %s" % [String(tb[2]).replace("-", " "), String(tb[3])], "tip": String(th.get("why", "")),
				"thing": e["thing"], "materials": e["materials"], "hash": String(e["hash"])})
	return out
