extends TextWalk
class_name DispatchWalk

## DispatchWalk - the reading of a note on the dispatch desk: the voice is handed the script with the desk's rests in it
## and every phone voice marked ([method DispatchScript.speakable]); typed blocks are said as typed, shown ones never.
## A [TextWalk] the Dispatch desk's card hands its reading. No title is announced: it is on the title screen.
##
## What the voice reads is a walk of the whole note (a tenth of a second for a long one) and a function of its text and the
## lengths of the films it plays (the voice waits for each), so the last answer is kept: Play, a scrub and an export ask
## about the same text again and again.

var _of := ""               # the text last asked about, with the films' lengths...
var _said := ""             # ...and what the voice reads of it
var _asked := false
## () -> Dictionary: what each film the script plays is ([method DispatchFormat.films]), whose lengths the voice waits for.
var films := Callable()


func _init(of_films := Callable()) -> void:
	films = of_films


func spoken(text: String, _title: String) -> Dictionary:
	var f: Dictionary = films.call() if films.is_valid() else {}
	var key := text + "\n" + JSON.stringify(DispatchScript.lengths_of(f))
	if not _asked or key != _of:
		_of = key
		_said = DispatchScript.speakable(text, f)
		_asked = true
	return {"body": _said, "title": ""}
