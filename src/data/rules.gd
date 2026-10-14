extends RefCounted
class_name Rules

## Rules - what the agents are told, kept as text a person reads: `rules/<group>/<role>.yaml` (the user,
## 2026-10-08: "extract agent instructions into a more interpretable format, like yaml ... as a human - it
## would be easier for me to read and grok the meaning of all the various things we're asking those
## agents to do"). The code decides WHEN a rule applies and fills in what it knows; the words are here.
##
## A FILE is a map of PARTS. A part is the text itself, or a list of ITEMS read in order, each one or more
## lines of what the agent reads (the items are joined by line breaks):
##
##   - THIS EPISODE                       a line, as it is
##   - ""                                 an empty line
##   - >-                                 a paragraph, folded from as many lines of the file as it takes
##       You are the SET DRESSER ...
##   - {when: box, say: ...}              only when the code's flag is true; "!box" only when it is not;
##                                        a list, only when all are
##   - {insert: tables}                   a block the code makes - a registry's words, a list of earlier
##                                        episodes
##   - {include: moves}                   another part of this file - or of another, "cards/reader.moves"
##   - {each: zones, say: ...}            the line once for each entry of a list the code gives, the
##                                        entry's own fields filled in
##
## Inside the words, a little of Mustache's: `{{name}}` is a value the code gives; `{{#flag}}...{{/flag}}`
## is there only when the flag is true (or a text that is not empty), `{{^flag}}...{{/flag}}` only when it
## is not; a tag alone on its line takes its line with it. Every rule's reason - who asked for it, what
## went wrong without it - is a `#` comment above it.
##
## Nothing is filled in silently: a name the code did not give is left as `{{name}}` and said in
## [member missing], which the gate holds empty (tests/rules_check.gd), as it holds every file to parse.

const DIR := "res://rules"

## Every name a render could not fill, as "file.part: name", since the last [method clear].
static var missing := PackedStringArray()
static var _files := {}


## THE PART [param path] ("cards/set_dresser.prompt": the file, then the part) as the agent reads it,
## with [param vars] filled in.
static func say(path: String, vars: Dictionary = {}) -> String:
	var dot := path.rfind(".")
	var file := path.substr(0, dot)
	var part := path.substr(dot + 1)
	var data := load_file(file)
	if not data.has(part):
		missing.append("%s: no part called \"%s\"" % [file, part])
		return ""
	return _render(data[part], vars, path)


## A rules file, parsed once: `{part: text or items}`. `{}` (and an error) when it cannot be read.
static func load_file(file: String) -> Dictionary:
	if _files.has(file):
		return _files[file]
	var path := DIR.path_join(file + ".yaml")
	var text := FileAccess.get_file_as_string(path)
	var got := MiniYaml.parse(text)
	var data: Dictionary = got["data"] if bool(got["ok"]) and got["data"] is Dictionary else {}
	if not bool(got["ok"]):
		push_error("rules: %s - %s" % [path, String(got["error"])])
		missing.append("%s: does not parse - %s" % [file, String(got["error"])])
	elif text.is_empty():
		missing.append("%s: no such file" % file)
	_files[file] = data
	return data


## Forget what was read and what was missing: the next [method say] reads the files again.
static func clear() -> void:
	_files.clear()
	missing.clear()


static func _render(part: Variant, vars: Dictionary, where: String) -> String:
	if part is String:
		return fill(part, vars, where)
	if not (part is Array):
		return "" if part == null else fill(str(part), vars, where)
	var out := PackedStringArray()
	for item in part:
		if item == null:
			out.append("")
		elif item is Dictionary:
			var d: Dictionary = item
			if d.has("when") and not _all(d["when"], vars):
				continue
			if d.has("include"):
				var inc := String(d["include"])
				out.append(say(inc if inc.contains("/") else where.substr(0, where.rfind(".") + 1) + inc, vars))
			elif d.has("insert"):
				var name := String(d["insert"])
				if vars.has(name):
					var v: Variant = vars[name]
					out.append("\n".join(v) if v is PackedStringArray or v is Array else str(v))
				else:
					missing.append("%s: %s" % [where, name])
			elif d.has("each"):
				var list: Variant = vars.get(String(d["each"]))
				if not (list is Array):
					missing.append("%s: %s (a list)" % [where, String(d["each"])])
					continue
				for e in list:
					var mine := vars.duplicate()
					if e is Dictionary:
						mine.merge(e, true)
					else:
						mine["it"] = e
					out.append(fill(String(d.get("say", "")), mine, where))
			else:
				out.append(fill(String(d.get("say", "")), vars, where))
		else:
			out.append(fill(str(item), vars, where))
	return "\n".join(out)


## Whether every flag of [param when] (a name, "!name", or a list of them) holds in [param vars].
static func _all(when: Variant, vars: Dictionary) -> bool:
	for w in (when if when is Array else [when]):
		var name := String(w).strip_edges()
		var want := not name.begins_with("!")
		if _truthy(vars.get(name.trim_prefix("!"))) != want:
			return false
	return true


static func _truthy(v: Variant) -> bool:
	if v is bool:
		return v
	if v is String or v is StringName:
		return not String(v).is_empty()
	if v is int or v is float:
		return v != 0
	if v is Array or v is PackedStringArray or v is Dictionary:
		return not v.is_empty()
	return v != null


static var _rx_alone: RegEx
static var _rx_section: RegEx
static var _rx_name: RegEx

## [param text] with [param vars] filled in: sections first (innermost out), then names.
static func fill(text: String, vars: Dictionary, where := "") -> String:
	if not text.contains("{{"):
		return text
	if _rx_alone == null:
		_rx_alone = RegEx.create_from_string("(?m)^[ \\t]*(\\{\\{[#^/][\\w-]+\\}\\})[ \\t]*\\n")
		_rx_section = RegEx.create_from_string("(?s)\\{\\{([#^])([\\w-]+)\\}\\}((?:(?!\\{\\{[#^]).)*?)\\{\\{/\\2\\}\\}")
		_rx_name = RegEx.create_from_string("\\{\\{([\\w-]+)\\}\\}")
	var s := _rx_alone.sub(text, "$1", true)
	while true:
		var m := _rx_section.search(s)
		if m == null:
			break
		var on := _truthy(vars.get(m.get_string(2)))
		var keep := on if m.get_string(1) == "#" else not on
		s = s.substr(0, m.get_start()) + (m.get_string(3) if keep else "") + s.substr(m.get_end())
	var out := ""
	var at := 0
	for m in _rx_name.search_all(s):
		var name := m.get_string(1)
		out += s.substr(at, m.get_start() - at)
		if vars.has(name):
			out += str(vars[name])
		else:
			out += m.get_string()
			missing.append("%s: %s" % [where, name])
		at = m.get_end()
	return out + s.substr(at)
