extends RefCounted
class_name TableRows

## TableRows - what a person may set of a table show's data, as rows (next/editing.md step 5): each
## field's type, label, sentence, default and bounds, in the shape [SchemaForm] draws, so the inspector
## a picked act or thing opens in ([TimelineDock]) is these tables. What a row does not name is still
## shown, as what its value is ([method SchemaForm.infer]); the agents' own words for the same fields
## stay theirs ([constant Props.SHAPES], the set dresser's and the puppeteer's rules).
##
## The bounds are what the table itself takes: an act's length as [method Motions.sanitize_acts] keeps
## it, a thing's place in centimeters from the middle of the reading ([method TableThings.stand_at]).

## An act (`acts.json`), as its sanitizer keeps it.
const ACT := {
	"name": {"type": "text", "label": "Name", "blurb": "What the act is called: what a cue in the words names to start it."},
	"about": {"type": "text", "label": "About", "blurb": "What the act does, in a few words, for whoever reads the acts."},
	"beat": {"type": "text", "label": "Beat", "blurb": "The beat it plays in: intro, close, or a beat's number."},
	"length": {"type": "float", "label": "Seconds", "blurb": "How long the act takes, unless it plays under the words.",
		"default": 6.0, "min": 0.3, "max": 120.0},
	"under": {"type": "bool", "label": "Under the words", "blurb": "It lasts as long as the words of its beat, rather than its own seconds.",
		"default": false},
	"tracks": {"type": "data", "label": "Tracks", "blurb": "What it does: each track a law on a thing (and a part of it), as the puppeteer wrote it."},
}

## A thing on the table (one of `table.json`'s `things`).
const THING := {
	"name": {"type": "text", "label": "Name", "blurb": "What the thing is called: how an act and the words find it."},
	"at": {"type": "pair", "label": "Place (cm)", "blurb": "Where it stands: centimeters right and toward the reader from the middle of the reading."},
	"turn": {"type": "float", "label": "Turn (°)", "blurb": "Which way its front faces, degrees about the upright.", "default": 0.0,
		"min": -180.0, "max": 180.0},
	"scale": {"type": "float", "label": "Size", "blurb": "How large it is against how it was made.", "default": 1.0, "min": 0.25, "max": 3.0},
	"group": {"type": "text", "label": "Group", "blurb": "The things it belongs with: what stands together, kept apart from other groups."},
	"why": {"type": "text", "label": "Why", "blurb": "Why it is on the table, as the set dresser said it."},
	"parts": {"type": "data", "label": "Parts", "blurb": "What it is made of: each part a shape, its size, its material and its place in the thing."},
}

## One part of a thing (a shape in its `parts`); a shape's own fields are shown as what their values are.
const PART := {
	"name": {"type": "text", "label": "Name", "blurb": "What the part is called: how a track works it (a jaw, a lid, a wick)."},
	"shape": {"type": "enum", "label": "Shape", "blurb": "What kind of form it is.", "options": []},
	"material": {"type": "ref", "of": "materials", "label": "Material", "blurb": "What it is made of: one of the table's materials."},
	"size": {"type": "vec3", "label": "Size (cm)", "blurb": "Width, height and depth, centimeters."},
	"at": {"type": "vec3", "label": "Place (cm)", "blurb": "Where it sits in the thing, centimeters from the thing's middle."},
	"turn": {"type": "vec3", "label": "Turn (°)", "blurb": "How it is turned in the thing, degrees about each axis."},
}


## A law's fields as rows (next/editing.md step 5): what every track names - its law, its thing, its
## part - then each of the law's own `fields` in [constant Motions.LAWS], its name and the sentence the
## puppeteer reads, typed and defaulted by what the law's sanitizer makes of a track that tells it
## nothing ([method Motions.sanitize_law]): the rows and the agents' words are one list.
static func law_fields(law: String) -> Dictionary:
	var out := {
		"law": {"type": "enum", "label": "Law", "blurb": "What the track does to its thing.", "options": Motions.LAWS.keys()},
		"thing": {"type": "text", "label": "Thing", "blurb": "What it works: a thing on the table, by its name."},
		"part": {"type": "text", "label": "Part", "blurb": "Which part of the thing, where it has parts (a lid, a hand, a jaw)."},
	}
	if not Motions.LAWS.has(law):
		return out
	var made := Motions.sanitize_law({"law": law, "thing": "thing"}, PackedStringArray())
	for f in (Motions.LAWS[law] as Dictionary).get("fields", []):
		var key := String((f as Array)[0])
		var told: Variant = made.get(key)
		if told is Vector2:
			told = [(told as Vector2).x, (told as Vector2).y]
		elif told is Vector3:
			told = [(told as Vector3).x, (told as Vector3).y, (told as Vector3).z]
		var row := SchemaForm.infer(key, told)
		if told is Array and (told as Array).size() == 2:
			row["type"] = "pair"
		row["label"] = key
		row["blurb"] = String((f as Array)[1])
		if told != null:
			row["default"] = told
		out[key] = row
	return out


## [constant PART] with its shapes listed: [constant Props.SHAPES]' names.
static func part_fields() -> Dictionary:
	var out := PART.duplicate(true)
	out["shape"]["options"] = Props.SHAPES.keys()
	return out


## Where thing [param name] is in [param table]'s `things`, -1 for nowhere.
static func thing_index(table: Dictionary, name: String) -> int:
	var things: Array = table.get("things", []) if table.get("things") is Array else []
	for i in things.size():
		if things[i] is Dictionary and String((things[i] as Dictionary).get("name", "")) == name:
			return i
	return -1


## The path to part [param name] inside [param thing] (`["parts", i, "parts", j, ...]`, as [DataPath] reads one), the first found
## depth first; [] for none.
static func part_path(thing: Dictionary, name: String) -> Array:
	if name.is_empty():
		return []
	var parts: Array = thing.get("parts", []) if thing.get("parts") is Array else []
	for i in parts.size():
		if not (parts[i] is Dictionary):
			continue
		var p: Dictionary = parts[i]
		if String(p.get("name", "")) == name:
			return ["parts", i]
		var deeper := part_path(p, name)
		if not deeper.is_empty():
			return ["parts", i] + deeper
	return []


## The materials [param table] names (its `materials` map), for a part's choice.
static func materials_of(table: Dictionary) -> Array:
	var m: Variant = table.get("materials", {})
	var out: Array = (m as Dictionary).keys() if m is Dictionary else []
	out.sort()
	return out
