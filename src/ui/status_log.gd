extends RefCounted
class_name StatusLog

## StatusLog - what the panels, cards and the Pipeline card say on screen, written to the log as well (the log console
## and the log file), where it can be copied: a status line, a card's warnings, a step's state and its error.
##
## A place's words are logged each time they change and never again while they stand, so a line redrawn four times a
## second is logged once. Each line of them is its own log line, `ghost: <where>: <line>`.

static var _last := {}


## Log [param text] as [param where]'s, unless it is what [param where] said last ("" logs nothing and is remembered, so
## the same words said again are logged again).
static func say(where: String, text: String) -> void:
	var t := text.strip_edges()
	if String(_last.get(where, "")) == t:
		return
	_last[where] = t
	for line in t.split("\n", false):
		var s := String(line).strip_edges()
		if not s.is_empty():
			print("ghost: %s: %s" % [where, s])
