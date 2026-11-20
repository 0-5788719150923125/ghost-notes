extends TextWalk
class_name DispatchWalk

## DispatchWalk - the reading of a note on the dispatch desk: the voice is handed the script with the desk's rests in it
## and every phone voice marked ([method DispatchScript.speakable]); typed blocks are said as typed, shown ones never.
## A [TextWalk] the Dispatch desk's card hands its reading. No title is announced: it is on the title screen.
##
## What the voice reads is a walk of the whole note (a tenth of a second for a long one) and a function of its text,
## so the last answer is kept: Play, a scrub and an export ask about the same text again and again.

var _of := ""               # the text last asked about...
var _said := ""             # ...and what the voice reads of it
var _asked := false


func spoken(text: String, _title: String) -> Dictionary:
	if not _asked or text != _of:
		_of = text
		_said = DispatchScript.speakable(text)
		_asked = true
	return {"body": _said, "title": ""}
