extends TextWalk
class_name DispatchWalk

## DispatchWalk - the reading of a note on the dispatch desk: the voice is handed the script with the desk's rests in it
## and every phone voice marked ([method DispatchScript.speakable]); typed blocks are said as typed, shown ones never.
## A [TextWalk] the Dispatch desk's card hands its reading. No title is announced: it is on the title screen.


func spoken(text: String, _title: String) -> Dictionary:
	return {"body": DispatchScript.speakable(text), "title": ""}


