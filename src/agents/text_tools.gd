extends RefCounted
class_name TextTools

## TextTools - what a writer can do to one text while it talks it over with its author ([WriterChat]): read it, change a part
## of it, write it whole, and, for a text that stands beside the note's words (the Direction), read the note. Served as tools
## ([AgentTools]) like every toolset. Each call reads the text as it stands then (the author may be typing in it), and a
## change lands through [member apply] at once, where the author sees it and can take it back.
##
## A change names a part copied exactly from the text and what replaces it. A part that is not there, or is there more than
## once when one place is meant, is refused with why, so a change never lands where it was not meant.

## The text as it stands now: `func() -> String`, or null once nobody holds it (the note was left): every call is then refused.
var read_text: Callable
## A change to land: `func(at: int, gone: int, put: String)`, [param gone] characters from [param at] replaced by [param put].
var apply: Callable
## The note's own words, for a text beside them: `func() -> String`. Unset, there is no `read_note`.
var read_note: Callable
## A call is about to be answered: `func()`, so whoever shows the conversation can show what was said before it first.
var calling: Callable
## A change landed: `func(entry: Dictionary)` - `{tool, old, new, count}` for an edit, `{tool, words}` for a text written whole.
var changed: Callable


func instructions() -> String:
	return ("The text you and the author are working on. read shows it as it stands now; edit changes a part of it, copied "
		+ "exactly; write replaces it whole. Every change shows to the author at once." + ("" if not read_note.is_valid()
		else " read_note shows the note it stands beside, which is not yours to change."))


func list_tools() -> Array:
	var out: Array = [
		{"name": "read", "description": "The text as it stands now, whole. The author may have changed it since you last saw it.",
			"inputSchema": {"type": "object", "properties": {}}},
		{"name": "edit", "description": "Change one part of the text: `old` copied exactly from the text as it stands, and `new` to put in its place (empty to take it out). `old` must be in the text once - copy more around it if it is there more than once - unless `every` is true, which changes every place it is.",
			"inputSchema": {"type": "object", "properties": {
				"old": {"type": "string"}, "new": {"type": "string"}, "every": {"type": "boolean"}},
				"required": ["old", "new"]}},
		{"name": "write", "description": "Replace the whole text with `text`. Only for a change to most of it: a change to a part is an edit.",
			"inputSchema": {"type": "object", "properties": {"text": {"type": "string"}}, "required": ["text"]}},
	]
	if read_note.is_valid():
		out.append({"name": "read_note", "description": "The note's own words as they stand now. Not yours to change.",
			"inputSchema": {"type": "object", "properties": {}}})
	return out


func call_tool(name: String, args: Dictionary) -> Dictionary:
	if calling.is_valid():
		calling.call()
	if not read_text.is_valid() or read_text.call() == null:
		return {"error": "The text is closed: the author has left it. Stop here."}
	match name:
		"read":
			var t := _text()
			return {"text": t if not t.is_empty() else "(The text is empty.)"}
		"edit":
			return edit(String(args.get("old", "")), String(args.get("new", "")), bool(args.get("every", false)))
		"write":
			return write(String(args.get("text", "")))
		"read_note":
			if read_note.is_valid():
				var n := String(read_note.call())
				return {"text": n if not n.strip_edges().is_empty() else "(The note has no words.)"}
	return {"text": "", "error": "no tool '%s'" % name}


## [param old] replaced by [param new] in the text: once, or every place it is when [param every]. `{text}` saying what was
## done, or `{error}` saying why nothing was.
func edit(old: String, new: String, every := false) -> Dictionary:
	if old.is_empty():
		return {"error": "old is empty: copy the part to change from the text, or write the whole text."}
	if old == new:
		return {"error": "old and new are the same: nothing to change."}
	var t := _text()
	var n := t.count(old)
	if n == 0:
		return {"error": "That part is not in the text as it stands. read it again and copy the part exactly, spaces and line breaks included."}
	if n > 1 and not every:
		return {"error": "That part is in the text %d times. Copy more around it so it is there once, or set every to change all %d." % [n, n]}
	# from the last place to the first, so each place found stands where it was found
	var at := t.rfind(old)
	while at >= 0:
		_put(at, old.length(), new)
		at = t.rfind(old, at - old.length()) if every and at - old.length() >= 0 else -1
	if changed.is_valid():
		changed.call({"tool": "edit", "old": old, "new": new, "count": n})
	return {"text": "Changed %s." % ("1 place" if n == 1 else "%d places" % n)}


## The whole text replaced by [param text].
func write(text: String) -> Dictionary:
	var t := _text()
	if text == t:
		return {"text": "The text already reads so: nothing changed."}
	_put(0, t.length(), text)
	if changed.is_valid():
		changed.call({"tool": "write", "words": text.split(" ", false).size()})
	return {"text": "Written whole."}


func _text() -> String:
	var t: Variant = read_text.call() if read_text.is_valid() else null
	return String(t) if t != null else ""


func _put(at: int, gone: int, put: String) -> void:
	if apply.is_valid():
		apply.call(at, gone, put)
