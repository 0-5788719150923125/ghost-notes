extends TextWalk
class_name LetterWalk

## LetterWalk - a letter reads its own words, as the desk writes them: the voice is handed the letter with the pen's rests in it
## ([method LetterScript.speakable]: a turn of the page, a strike, a tap, a drawing the pen owes after its paragraph, a line
## written and never said), sized from what the Letter card made exactly as [LetterMedium] writes and lays it out, so the voice and
## the pen keep time. A [TextWalk] the Letter's rows on the Medium card hand its reading ([LetterFormat]).
##
## No title is announced: a letter does not begin with its own name; it is on the title screen, over the desk, while the intro holds.

var card: LetterFormat


func _init(c: LetterFormat) -> void:
	card = c


func spoken(text: String, _title: String) -> Dictionary:
	var d := card.document()
	var records := LetterScript.records_of(d.get("ink", {}))
	var fonts: Dictionary = (d["ink"] as Dictionary).get("fonts", {}) if d.get("ink") is Dictionary else {}
	return {"body": LetterScript.speakable(text, int(d["seed"]), d["svgs"],
		LetterScript.lengths_of(records, int(d["seed"]), fonts), records, String(d["hand"])), "title": ""}


