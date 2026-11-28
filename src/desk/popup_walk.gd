extends TextWalk
class_name PopupWalk

## PopupWalk - what the voice reads of a pop-up book ([PopupMedium]): the note's words up to its unread line, its citations
## out (as [TextWalk] reads any note), with the book's rests in them - one after the title while the cover opens and the first
## scene stands up ([constant OPEN_REST]), and one at each later scene while the leaf turns and the next scene stands
## ([constant TURN_REST]). A scene opens as the layout opens one ([method PopupLayout.scenes_of]): at a picture mark that
## follows words. A [TextWalk] the format's rows hand the reading ([PopupFormat]).

## Seconds the voice rests after the title, and at each later scene.
const OPEN_REST := 5.4
const TURN_REST := 3.4


func spoken(text: String, title: String) -> Dictionary:
	return {"body": rested(Manuscript.without_citations(Manuscript.read_part(text))), "title": title}


## [param text] with a rest before the first word of each scene: [constant OPEN_REST] at the first, [constant TURN_REST] at
## every later one. A rest sits on the word it comes before (a passage of nothing but a rest is no rest: [method
## ReadingPlan.passages]). A cover's mark opens nothing.
static func rested(text: String) -> String:
	var body := Manuscript.strip_frontmatter(text)
	var head := text.substr(0, text.length() - body.length())
	var cuts: Array = []
	var last := -1
	for m in Manuscript._rx(Manuscript.IMAGE).search_all(body):
		if m.get_string(2) == "cover":
			continue
		var at := m.get_start()
		if last >= 0 and Manuscript._rx(Manuscript.COMMENT).sub(body.substr(last, at - last), "", true).strip_edges().is_empty():
			continue                 # another picture of the same scene
		cuts.append([_first_word(body, at), OPEN_REST if last < 0 else TURN_REST])
		last = at
	if cuts.is_empty():
		cuts.append([_first_word(body, 0), OPEN_REST])
	for i in range(cuts.size() - 1, -1, -1):
		var at := int(cuts[i][0])
		if at < 0:
			continue
		body = body.substr(0, at) + "<!-- hesitation: %s --> " % str(cuts[i][1]) + body.substr(at)
	return head + body


## Where the first word at or after [param from] in [param body] begins, past blank space, every mark and a heading's
## hashes; -1 for none.
static func _first_word(body: String, from: int) -> int:
	var i := from
	var comment := Manuscript._rx(Manuscript.COMMENT)
	while i < body.length():
		var ch := body[i]
		if ch == " " or ch == "\t" or ch == "\n" or ch == "\r":
			i += 1
			continue
		if body.substr(i, 4) == "<!--":
			var m := comment.search(body, i)
			if m == null or m.get_start() != i:
				return i
			i = m.get_end()
			continue
		if ch == "#":
			while i < body.length() and (body[i] == "#" or body[i] == " "):
				i += 1
			return i
		return i
	return -1
