extends TextWalk
class_name DispatchWalk

## DispatchWalk - the reading of a note on the dispatch desk: the voice is handed the script with the desk's rests in it
## and every phone voice marked ([method DispatchScript.speakable]); typed blocks are said as typed, shown ones never.
## A [TextWalk] the Dispatch desk's card hands its reading. No title is announced: it is on the title screen.


func spoken(text: String, _title: String) -> Dictionary:
	return {"body": DispatchScript.speakable(text), "title": ""}


## A minute at the desk: the room's voice, and one through a phone.
func test_passage(_fallback: String) -> String:
	return ("He's at the store. Eleven o'clock at night, he goes grocery shopping. There's his car, from space. I can see it "
		+ "needs a wash. An aisle needs a face at the end of it, and every trip to the store gets a cough.")
