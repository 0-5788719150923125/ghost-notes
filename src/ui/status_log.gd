extends RefCounted
class_name StatusLog

## StatusLog - what the panels, cards and the Pipeline card say on screen, written to the log as well (the log console
## and the log file), where it can be copied: a status line, a card's warnings, a step's state and its error.
##
## A place's words are logged each time they change and never again while they stand, so a line redrawn four times a
## second is logged once; words that change only in their numbers are progress ("Chunk 12 of 811"), logged once as it
## starts. Each line of them is its own log line, `ghost: <where>: <line>`.

static var _last := {}
static var _shape := {}


## Log [param text] as [param where]'s, unless it is what [param where] said last, or that with only its numbers changed
## ("" logs nothing and is remembered, so the same words said again are logged again).
static func say(where: String, text: String) -> void:
	var t := text.strip_edges()
	if String(_last.get(where, "")) == t:
		return
	_last[where] = t
	var shape := _numbers().sub(t, "#", true)
	if String(_shape.get(where, "")) == shape and not t.is_empty():
		return
	_shape[where] = shape
	for line in t.split("\n", false):
		var s := String(line).strip_edges()
		if not s.is_empty():
			print("ghost: %s: %s" % [where, s])


## Log [param lines] as [param where]'s warnings ([method say]), each marked ⚠ so it stands out among the log's lines; none
## logs nothing, and the same warnings come back as new once they have gone.
static func warn(where: String, lines: PackedStringArray) -> void:
	var marked := PackedStringArray()
	for l in lines:
		marked.append("⚠ " + String(l))
	say(where, "\n".join(marked))


static var _re: RegEx = null


static func _numbers() -> RegEx:
	if _re == null:
		_re = RegEx.create_from_string("[0-9]+(?:[.,][0-9]+)*")
	return _re
