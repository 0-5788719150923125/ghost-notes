extends RefCounted
class_name ThingLibrary

## ThingLibrary - props kept to stand on any table (next/library.md): the library's `things` shelf ([Library]), one file per
## prop, `<slug>.json`: `{name, line, thing, materials, hash}`. A prop is kept by a person's choice, never automatically, and is
## the thing alone - its parts, its scale and the materials they use - never where it stood on the table it came from, its
## group or why it was there ([constant OWN]).
##
## Put on a table ([method put_on]) it is that thing again: named so no other thing there shares its name, each material it
## uses added under its own name, and renamed where the table has another of that name, so it looks the same on every table.
## A file from anywhere (one handed on, or edited by hand) comes in through [method sanitized], bounded as a made one is
## ([method Props.sanitize]).

const SHELF := "things"
## What a thing keeps when it is kept: what it is, never where it stood or why.
const OWN := ["name", "parts", "scale"]
## The most props a search answers with ([method search]).
const FOUND := 6
## The longest line saying what a prop is.
const LINE_MOST := 200
## The ending of a prop handed on as a file ([method export_to]).
const EXPORT := ".prop.json"


## The shelf's folder, absolute.
static func dir() -> String:
	return Library.shelf(SHELF)


## The entry [param thing] would be, kept with what [param materials] has of the ones its parts use and [param line] saying what it
## is: `{name, line, thing, materials, hash}`; {} for a thing with no name or no parts.
static func entry_of(thing: Dictionary, materials: Dictionary, line := "") -> Dictionary:
	var name := String(thing.get("name", "")).strip_edges()
	if name.is_empty() or not (thing.get("parts") is Array) or (thing["parts"] as Array).is_empty():
		return {}
	var own := {}
	for k in OWN:
		if thing.has(k):
			own[k] = (thing[k] as Variant) if not (thing[k] is Dictionary or thing[k] is Array) else thing[k].duplicate(true)
	own["name"] = name
	if own.has("scale") and is_equal_approx(float(own["scale"]), 1.0):
		own.erase("scale")
	var mats := {}
	for m in materials_used(own):
		if materials.has(m):
			mats[m] = (materials[m] as Variant) if not (materials[m] is Dictionary) else (materials[m] as Dictionary).duplicate(true)
	return {"name": name, "line": line.strip_edges().left(LINE_MOST), "thing": own, "materials": mats, "hash": hash_of(own, mats)}


## What [param thing] built of [param materials] is, as a short hash: the same prop on any table, by any name, hashes the same
## (only what it keeps counts, [constant OWN], its name left out); a part or a material changed does not.
static func hash_of(thing: Dictionary, materials: Dictionary) -> String:
	var t := {}
	for k in OWN:
		if k != "name" and thing.has(k):
			t[k] = thing[k]
	if t.has("scale") and (not (t["scale"] is float or t["scale"] is int) or is_equal_approx(float(t["scale"]), 1.0)):
		t.erase("scale")
	var used := {}
	for m in materials_used(t):
		if materials.has(m):
			used[m] = materials[m]
	return JSON.stringify([t, used], "", true).sha256_text().left(16)


## Thing [param thing] kept with what [param materials] has of the ones its parts use, and [param line] saying what it is; a prop of
## its name already kept is replaced. "" kept, else why not.
static func keep(thing: Dictionary, materials: Dictionary, line := "") -> String:
	var e := entry_of(thing, materials, line)
	if e.is_empty():
		return "a prop needs a name and a part to be kept"
	return _write(e)


static func _write(e: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(dir())
	var path := dir().path_join(Manuscript.slug(String(e["name"])) + ".json")
	var f := FileAccess.open(path + ".part", FileAccess.WRITE)
	if f == null:
		return "could not write " + path
	f.store_string(JSON.stringify(e, "\t"))
	f.close()
	return "" if DirAccess.rename_absolute(path + ".part", path) == OK else "could not move %s into place" % path


## Every prop kept, sorted by name: each its entry with `file`, the path it is kept at.
static func entries() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir()):
		return out
	for fn in DirAccess.get_files_at(dir()):
		if String(fn).ends_with(".json"):
			var e := read_file(dir().path_join(fn))
			if not e.is_empty():
				e["file"] = dir().path_join(fn)
				out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	return out


## Every prop kept, by name, sorted.
static func names() -> Array:
	return entries().map(func(e: Dictionary) -> String: return String(e["name"]))


## The prop kept as [param name]: its entry, {} for none.
static func read(name: String) -> Dictionary:
	return read_file(dir().path_join(Manuscript.slug(name) + ".json"))


## The entry in the file at [param path], its fields filled; {} where it is no prop.
static func read_file(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not (d is Dictionary) or not ((d as Dictionary).get("thing") is Dictionary):
		return {}
	var e: Dictionary = d
	var thing: Dictionary = e["thing"]
	if String(e.get("name", "")).strip_edges().is_empty():
		e["name"] = String(thing.get("name", "")).strip_edges()
	if String(e["name"]).is_empty():
		return {}
	thing["name"] = String(e["name"])
	if not (e.get("materials") is Dictionary):
		e["materials"] = {}
	e["line"] = String(e.get("line", "")) if e.get("line") is String else ""
	if not (e.get("hash") is String) or String(e["hash"]).is_empty():
		e["hash"] = hash_of(thing, e["materials"])
	return e


## The name of the prop kept whose hash is [param h] ([method hash_of]), "" for none.
static func kept_as(h: String) -> String:
	for e in entries():
		if String((e as Dictionary)["hash"]) == h:
			return String((e as Dictionary)["name"])
	return ""


## The prop kept as [param name] taken off the shelf, to the trash ([method Library.trash]). "" done, else why not.
static func remove(name: String) -> String:
	var path := dir().path_join(Manuscript.slug(name) + ".json")
	if not FileAccess.file_exists(path):
		return "%s is not in the library" % name
	return "" if Library.trash(path) == OK else "could not take %s off the shelf" % name


## The prop kept as [param name] called [param new_name], said by [param line]. "" done, else why not.
static func rename(name: String, new_name: String, line: String) -> String:
	var e := read(name)
	if e.is_empty():
		return "%s is not in the library" % name
	var to := new_name.strip_edges()
	if to.is_empty():
		return "a prop needs a name"
	if Manuscript.slug(to) != Manuscript.slug(name) and not read(to).is_empty():
		return "another prop is called %s" % to
	e.erase("file")
	e["name"] = to
	(e["thing"] as Dictionary)["name"] = to
	e["line"] = line.strip_edges().left(LINE_MOST)
	var err := _write(e)
	if err.is_empty() and Manuscript.slug(to) != Manuscript.slug(name):
		DirAccess.remove_absolute(dir().path_join(Manuscript.slug(name) + ".json"))
	return err


## [param table] with [param entry] ([method read]) put on it: the thing appended, named so no other thing there has its name, and
## standing at [param at] (centimeters from the middle of the reading; null leaves it for whoever sets the table to place); the
## materials it uses added, each renamed where the table has a different one of its name. A new table; the one handed is not
## changed.
static func put_on(table: Dictionary, entry: Dictionary, at: Variant = Vector2.ZERO) -> Dictionary:
	var out := table.duplicate(true)
	var thing: Dictionary = (entry.get("thing", {}) as Dictionary).duplicate(true)
	var things: Array = out.get("things", []) if out.get("things") is Array else []
	var taken := {}
	for t in things:
		if t is Dictionary:
			taken[String((t as Dictionary).get("name", "")).to_lower()] = true
	var base := String(entry.get("name", thing.get("name", "thing")))
	var name := base
	var n := 2
	while taken.has(name.to_lower()):
		name = "%s %d" % [base, n]
		n += 1
	thing["name"] = name
	if at is Vector2:
		thing["at"] = [(at as Vector2).x, (at as Vector2).y]
	var mats: Dictionary = out.get("materials", {}) if out.get("materials") is Dictionary else {}
	var own: Dictionary = entry.get("materials", {}) if entry.get("materials") is Dictionary else {}
	var renamed := {}
	for m in own:
		var to := String(m)
		var k := 2
		while mats.has(to) and JSON.stringify(mats[to], "", true) != JSON.stringify(own[m], "", true):
			to = "%s (%s)" % [String(m), base] if k == 2 else "%s (%s %d)" % [String(m), base, k]
			k += 1
		mats[to] = (own[m] as Variant) if not (own[m] is Dictionary) else (own[m] as Dictionary).duplicate(true)
		if to != String(m):
			renamed[String(m)] = to
	if not renamed.is_empty():
		_rename_materials(thing, renamed)
	things.append(thing)
	out["things"] = things
	out["materials"] = mats
	return out


## The props kept as [param names] as a table's fixed things are written ([FixedTable]): `{things, materials}`, each named its own
## and placed by whoever sets the table (no `at`). A name not kept is left out.
static func given(names: Array) -> Dictionary:
	var out := {"things": [], "materials": {}}
	for n in names:
		var e := read(String(n))
		if not e.is_empty():
			out = put_on(out, e, null)
	return out


## The props kept that best fit [param words] (what is needed, in words), best first, [param most] at most: each `{name, line,
## parts}` with its entry. A prop is matched by its name, its line, its shapes and its materials' kinds; one sharing no word is
## never offered.
static func search(words: String, most := FOUND) -> Array:
	var want := _words(words)
	var scored: Array = []
	for e in entries():
		var said := "%s %s %s" % [String(e["name"]), String(e["line"]), " ".join(PackedStringArray(_traits(e)))]
		var have := _words(said)
		var score := 0.0
		for w in want:
			if have.has(w):
				score += 2.0 if String(e["name"]).to_lower().contains(w) else 1.0
		if score > 0.0:
			scored.append([score, e])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	return scored.slice(0, most).map(func(s: Array) -> Dictionary: return s[1])


## The shapes [param e]'s parts are and the kinds of the materials they use, as words.
static func _traits(e: Dictionary) -> Array:
	var out: Array = []
	var walk: Array = [e["thing"]]
	while not walk.is_empty():
		var p: Dictionary = walk.pop_back()
		if p.get("shape") is String and not out.has(String(p["shape"])):
			out.append(String(p["shape"]))
		for q in (p.get("parts", []) if p.get("parts") is Array else []):
			if q is Dictionary:
				walk.append(q)
	for m in (e["materials"] as Dictionary):
		var d: Variant = (e["materials"] as Dictionary)[m]
		out.append(String(m))
		if d is Dictionary and (d as Dictionary).get("kind") is String:
			out.append(String((d as Dictionary)["kind"]))
	return out


## [param text] as the words in it, lower-cased, each also without a closing "s" (cups finds a cup).
static func _words(text: String) -> Dictionary:
	var out := {}
	var rx := RegEx.create_from_string("[\\p{L}\\p{N}]+")
	for m in rx.search_all(text.to_lower()):
		var w := m.get_string()
		if w.length() < 3:
			continue
		out[w] = true
		if w.length() > 3 and w.ends_with("s"):
			out[w.left(-1)] = true
	return out


## The materials [param part] (a thing, or one of its parts) and every part inside it name: its `material` (one, or a list its
## copies take in turn), a cluster's or a geode's rock (`base`) and a vine's `leaves`.
static func materials_used(part: Dictionary) -> Array:
	var out: Array = []
	var named: Array = []
	if part.get("material") is String:
		named.append(part["material"])
	elif part.get("material") is Array:
		named.append_array(part["material"])
	for k in ["base", "leaves"]:
		if part.get(k) is String:
			named.append(part[k])
	for m in named:
		if m is String and not String(m).strip_edges().is_empty() and not out.has(String(m).strip_edges()):
			out.append(String(m).strip_edges())
	for p in (part.get("parts", []) if part.get("parts") is Array else []):
		if p is Dictionary:
			for m in materials_used(p):
				if not out.has(m):
					out.append(m)
	return out


## Every material [param part] and the parts inside it name, renamed as [param to] says (old -> new).
static func _rename_materials(part: Dictionary, to: Dictionary) -> void:
	if part.get("material") is String and to.has(String(part["material"]).strip_edges()):
		part["material"] = to[String(part["material"]).strip_edges()]
	elif part.get("material") is Array:
		part["material"] = (part["material"] as Array).map(func(m: Variant) -> Variant:
			return to.get(String(m).strip_edges(), m) if m is String else m)
	for k in ["base", "leaves"]:
		if part.get(k) is String and to.has(String(part[k]).strip_edges()):
			part[k] = to[String(part[k]).strip_edges()]
	for p in (part.get("parts", []) if part.get("parts") is Array else []):
		if p is Dictionary:
			_rename_materials(p, to)


## [param d] (an entry, or a bare `{thing, materials}`, from anywhere) made safe to keep: refused ({}) where [method Props.sanitize]
## can build nothing of it, else kept as written but bounded - at most [constant Props.MAX_PARTS] shaped parts [constant
## Props.MAX_DEPTH] groups deep, every list, map and text cut short, every number finite, only what a prop keeps. Every table
## sanitizes what it stands again, so what is kept here needs only to be small and plain.
static func sanitized(d: Dictionary) -> Dictionary:
	if not (d.get("thing") is Dictionary):
		return {}
	var thing: Dictionary = _bounded(d["thing"], 0)
	var name := String(d.get("name", thing.get("name", ""))).strip_edges().left(100)
	thing["name"] = name if not name.is_empty() else "a prop"
	thing["parts"] = _capped(thing.get("parts", []), 0, [Props.MAX_PARTS])
	var mats: Dictionary = _bounded(d["materials"], 0) if d.get("materials") is Dictionary else {}
	if (Props.sanitize({"things": [thing], "materials": mats}, [])["things"] as Array).is_empty():
		return {}
	return entry_of(thing, mats, String(d.get("line", "")).left(LINE_MOST) if d.get("line") is String else "")


## [param v] as plain data, bounded: maps and lists cut short, texts cut, numbers finite, anything else dropped (null).
static func _bounded(v: Variant, depth: int) -> Variant:
	if depth > 10:
		return null
	match typeof(v):
		TYPE_DICTIONARY:
			var out := {}
			for k in (v as Dictionary):
				if out.size() >= 48:
					break
				var b: Variant = _bounded((v as Dictionary)[k], depth + 1)
				if b != null:
					out[String(k).left(40)] = b
			return out
		TYPE_ARRAY:
			var out: Array = []
			for x in (v as Array):
				if out.size() >= Props.MAX_POINTS * 2:
					break
				var b: Variant = _bounded(x, depth + 1)
				if b != null:
					out.append(b)
			return out
		TYPE_FLOAT:
			return v if is_finite(float(v)) else 0.0
		TYPE_INT, TYPE_BOOL:
			return v
		TYPE_STRING, TYPE_STRING_NAME:
			return String(v).left(400)
	return null


## A list of parts kept within [param budget] shaped parts ([constant Props.MAX_PARTS] in all) and [constant Props.MAX_DEPTH] groups
## deep, as [method Props.sanitize] keeps them.
static func _capped(raw: Variant, depth: int, budget: Array) -> Array:
	var out: Array = []
	for p in (raw if raw is Array else []):
		if int(budget[0]) <= 0:
			break
		if not (p is Dictionary):
			continue
		var d: Dictionary = p
		if d.get("parts") is Array:
			if depth >= Props.MAX_DEPTH:
				continue
			var group := d.duplicate()
			group["parts"] = _capped(d["parts"], depth + 1, budget)
			if not (group["parts"] as Array).is_empty():
				out.append(group)
			continue
		out.append(d)
		budget[0] = int(budget[0]) - 1
	return out


## The prop kept as [param name] written to [param path] as a file anyone can be handed. "" done, else why not.
static func export_to(name: String, path: String) -> String:
	var e := read(name)
	if e.is_empty():
		return "%s is not in the library" % name
	e.erase("file")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "could not write " + path
	f.store_string(JSON.stringify(e, "\t"))
	f.close()
	return ""


## The prop in the file at [param path] kept, read through [method sanitized]: its name, or "" with [param why] told why not.
static func import_from(path: String, why: Array = []) -> String:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var e := sanitized(d) if d is Dictionary else {}
	if e.is_empty():
		why.append("%s holds no prop that can be built" % path.get_file())
		return ""
	var err := _write(e)
	if not err.is_empty():
		why.append(err)
		return ""
	return String(e["name"])
