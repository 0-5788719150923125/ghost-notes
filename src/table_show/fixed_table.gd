extends RefCounted
class_name FixedTable

## FixedTable - a show's fixed things (next/painted_surface.md; next/table_work.md section 11): what a brief says stands on every
## episode's table exactly as written (a mask on its stand, an artist's station), which every set dresser would otherwise build
## anew each episode.
##
## A fenced JSON block under a heading of the brief's ([constant HEADING]): `{things, materials, light, sound}` written as a set
## dresser writes a table's. The set dresser starts with them standing ([SetDresserTools]), builds round them and can neither move
## nor take them away; the table it hands in is given them, whatever it wrote ([method merge]); no agent reads the JSON itself -
## the brief they are told says in a line what stands there ([method strip]).

## The heading the block is under (a Markdown heading of any level).
const HEADING := "^(#{1,6})\\s+(?i:the fixed table|fixed things)\\s*$"
## What of a table the block may fix.
const FIXES := ["things", "materials", "light", "sound"]


## The fixed things of brief [param body] (with or without its frontmatter): `{things, materials, light, sound}` as written, `{}`
## when it has none or its block is not JSON.
static func parse(body: String) -> Dictionary:
	var sec := Manuscript.section(body, HEADING)
	if sec.is_empty():
		return {}
	var block := _block("\n".join(PackedStringArray(sec["lines"])))
	if block.is_empty():
		return {}
	var j := JSON.new()
	if j.parse(block) != OK or not (j.data is Dictionary):
		push_warning("ghost: the brief's fixed table is not JSON: %s" % j.get_error_message())
		return {}
	var out := {}
	for k in FIXES:
		if (j.data as Dictionary).has(k):
			out[k] = (j.data as Dictionary)[k]
	if not (out.get("things") is Array):
		out["things"] = []
	if not (out.get("materials") is Dictionary):
		out["materials"] = {}
	return out


## The first fenced block in [param text] (```json ... ``` or ``` ... ```), its insides.
static func _block(text: String) -> String:
	var rx := RegEx.create_from_string("(?s)```(?:json)?\\s*\\n(.*?)\\n\\s*```")
	var m := rx.search(text)
	return m.get_string(1) if m != null else ""


## Brief [param body] as the agents read it: the fixed table's JSON taken out and said in a line - what stands there by name.
static func strip(body: String) -> String:
	var sec := Manuscript.section(body, HEADING)
	if sec.is_empty():
		return body
	var fixed := parse(body)
	var names := PackedStringArray()
	for t in fixed.get("things", []):
		if t is Dictionary and not String((t as Dictionary).get("name", "")).is_empty():
			names.append("\"%s\"" % String((t as Dictionary)["name"]))
	var text := "\n".join(PackedStringArray(sec["lines"]))
	var rx := RegEx.create_from_string("(?s)```(?:json)?\\s*\\n.*?\\n\\s*```")
	var said := "(These stand on every episode's table exactly as they are written, built by the show itself: %s%s.)" % [", ".join(names),
		", and the table's light and sound" if fixed.has("light") or fixed.has("sound") else ""]
	text = rx.sub(text, said)
	return String(sec["before"]) + String(sec["head"]) + "\n" + text + String(sec["after"])


## The names of the things [param fixed] stands, lower-cased.
static func names(fixed: Dictionary) -> Array:
	var out: Array = []
	for t in fixed.get("things", []):
		if t is Dictionary:
			out.append(String((t as Dictionary).get("name", "")).strip_edges().to_lower())
	return out


## [param table] (a set dresser's, as written) with the fixed things [param fixed] standing in it: each in place of one of its name,
## or added; their materials over any of the same name; the light and sound the brief fixes, if it does.
static func merge(table: Dictionary, fixed: Dictionary) -> Dictionary:
	if fixed.is_empty():
		return table
	var out := table.duplicate(true)
	var mine := names(fixed)
	var things: Array = []
	for t in fixed.get("things", []):
		if t is Dictionary:
			things.append((t as Dictionary).duplicate(true))
	for t in (out.get("things", []) if out.get("things") is Array else []):
		if t is Dictionary and not mine.has(String((t as Dictionary).get("name", "")).strip_edges().to_lower()):
			things.append(t)
	out["things"] = things
	var mats: Dictionary = out.get("materials", {}) if out.get("materials") is Dictionary else {}
	for k in (fixed.get("materials", {}) as Dictionary):
		mats[k] = (fixed["materials"] as Dictionary)[k]
	out["materials"] = mats
	for k in ["light", "sound"]:
		if fixed.has(k):
			out[k] = fixed[k]
	return out
