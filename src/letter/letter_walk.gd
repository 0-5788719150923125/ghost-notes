extends TextWalk
class_name LetterWalk

## LetterWalk - a letter reads its own words, as the desk writes them: the voice is handed the letter with
## the pen's rests in it ([method LetterScript.speakable]) - a turn of the page, a strike, a tap, a
## drawing the pen owes after its paragraph, a line written and never said - sized from what the Letter
## card made exactly as [LetterMedium] writes and lays it out, so the voice and the pen keep time. A
## [TextWalk] the Letter card hands its reading.
##
## NO TITLE IS ANNOUNCED: a letter does not begin with its own name - it is on the title screen, over the
## desk, while the intro holds.

var card: LetterCard


func _init(c: LetterCard) -> void:
	card = c


func spoken(text: String, _title: String) -> Dictionary:
	var d := card.document()
	var records := LetterScript.records_of(d.get("ink", {}))
	var fonts: Dictionary = (d["ink"] as Dictionary).get("fonts", {}) if d.get("ink") is Dictionary else {}
	return {"body": LetterScript.speakable(text, int(d["seed"]), d["svgs"],
		LetterScript.lengths_of(records, int(d["seed"]), fonts), records), "title": ""}


## A letter's minute: what is written as it is said.
func test_passage(_fallback: String) -> String:
	return ("I don't know where to start, so I'll start with the weather. It rained all week, the kind "
		+ "of rain that never quite commits, and the street outside my window has been grey since Monday. "
		+ "I keep meaning to write to you properly, with news, and then the evening goes. So here is what "
		+ "there is. The tree by the gate came down in the wind. Nobody was hurt. The lamp still works, "
		+ "and the desk still wobbles if you lean on its left side. I think of you most when it is quiet. "
		+ "Write back when you can. Tell me something small, and true.")
