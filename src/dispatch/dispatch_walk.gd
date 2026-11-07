extends TextWalk
class_name DispatchWalk

## DispatchWalk - the dispatch desk reads its note as the desk plays it: the voice is handed the script with the desk's
## rests in it and every voice through a phone marked so ([method DispatchScript.speakable]) - a phone dialed and ringing,
## a ping, the printer, the static - the typed blocks said as they are typed and the shown ones never said. A [TextWalk]
## the Dispatch desk's card hands its reading.
##
## NO TITLE IS ANNOUNCED: it is on the title screen, over the desk, while the intro holds.


func spoken(text: String, _title: String) -> Dictionary:
	return {"body": DispatchScript.speakable(text), "title": ""}


## A minute at the desk: the room's voice, and one through a phone.
func test_passage(_fallback: String) -> String:
	return ("He's at the store. Eleven o'clock at night, he goes grocery shopping. There's his car, from space. I can see it "
		+ "needs a wash. An aisle needs a face at the end of it, and every trip to the store gets a cough.")
