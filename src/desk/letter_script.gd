extends RefCounted
class_name LetterScript

## LetterScript - a letter as the voice reads it and the desk writes it (next/letter.md).
##
## THE PEN WRITES TWO WORDS AHEAD OF THE VOICE (2026-10-27; the user, of the pen behind the voice: "A person wants
## to read what is being said ... write ahead, and pause at the start of each sentence"; then, of the pen five or
## six words ahead at a hand's pace: "It makes the pauses between sentences far too long ... maybe 2 words ahead
## of the speaking?"): every paragraph is put on the page a line at a time, each word written while the voice says
## the word [constant AHEAD_WORDS] before it - the desk's elastic pen ([LetterMedium]) on the voice's own times,
## whatever its speed - and never quicker than [constant QUICKEST] the hand's pace. The voice waits at a
## sentence's start only where the pen cannot be that far ahead: after a thought, a still or the blank page (the
## pen begins as the voice gets there, and writes two words before it goes on), at a page turned between two
## paragraphs (once the voice has read the page; one turned inside a paragraph it reads on through, the pen
## catching up after), and where the words are more ink than the quickest pen can put down while they are said. Under a picture nobody reads along: the pen keeps with the
## voice there, unseen. (A pen at a hand's own steady pace ahead of a voice two or three times quicker makes
## the voice wait out the difference at every sentence - a letter as long as its writing, the chapter 43
## minutes - whatever lead is asked for.) The rest is marks:
##
##     *A paragraph in italics, whole.*        A THOUGHT: said, never written - the writer stops and
##                                             thinks it, the pen lifted.
##     <!-- strike -->, <!-- strike: 4 -->     the writer stops, decides (a few seconds; the mark's own
##                                             number of them), then crosses out the paragraph last
##                                             written, every line of it.
##     <!-- unspoken: Dear Ink, -->            written and not said: the voice waits while the pen
##                                             writes it.
##     <!-- sketch: what it shows -->          a drawing the pen makes on the page - an agent draws it
##                                             from the words as SVG ([LetterCard]), TeX's figure
##                                             reader lays it out - while the paragraph after it is
##                                             said: that paragraph is the drawing's, said, not written.
##     <!-- point: sketch -->, <!-- point: sketch, the dot on its own -->
##                                             INSIDE SPEECH: at the next word the pen points at the
##                                             last sketch, or at the part of it so described (the
##                                             agent names that part, [method part_id]).
##     <!-- point: camera -->                  the pen is lifted and pointed at whoever is watching.
##     <!-- tap -->, <!-- tap: desk -->        the pen turned over and its top tapped on the pad, or on
##                                             the desk beside it, while the writer thinks.
##     <!-- image (full): what it shows -->  ... <!-- /image -->
##                                             a picture over the whole screen, panned slowly, from the
##                                             word after it to the close: a flashback the voice reads
##                                             over, while the pen goes on writing unseen. Another image
##                                             mark before the close, or straight after it, DISSOLVES
##                                             INTO ITS PICTURE (`blend`): the page is not seen between.
##     <!-- still -->                          from here to the next written line the camera holds dead
##                                             still on what was last drawn, the pen off the page (a
##                                             test the viewer does on the screen).
##     <!-- new page -->                       the next writing starts a page of its own.
##
## The voice's own marks (a hesitation, a delivery, a speaker) pass to the voice; any other comment is a
## note and is neither read nor written.
##
## ONE WALK, TWO READERS ([DeskScript]'s rule): [method parse] gives the spoken words the desk follows
## the voice by, the pen's actions anchored to them, the spans the camera and the pictures follow, and
## the text the voice reads ([member speakable]) with its rests (`<!-- action-hold: S -->`) - from the
## same numbers, so they cannot disagree. THE WRITING NEEDS NO STEP: a line is the hand's own
## ([LetterHand]), so its strokes and how long they take are known here; only a sketch's drawing comes
## from the ink step, handed in as [param lengths] and [param sizes] the way [DeskScript.parse] takes them.
##
## THE PAGE IS FILLED: lines on the pad's rules, a rule left empty between two paragraphs and none
## indented (2026-10-27, the user: "the hanging indents look wrong, when the first several paragraphs are
## each just ~10 words long ... there should probably be a newline between each paragraph" - the book's
## rule, [constant BookLayout.INDENT_EM]), a sketch centered half a rule clear of what is above it, and the
## page turned where the next line or drawing would run off its foot - mid-sentence too, where the voice reads
## on and the pen catches up after the turn ([method _voice_text]).

## The marks of their own line: group 1 the verb, group 2 what follows the colon.
const MARK := "^\\s*<!--\\s*(strike|tap|still|new\\s+page|/\\s*image|unspoken)\\s*(?::\\s*([\\s\\S]*?))?\\s*-->\\s*$"
## A point inside speech: group 1 what it points at.
const POINT := "<!--\\s*point\\s*:\\s*([^>]*?)\\s*-->"
## A passage the writer thinks and does not write: a paragraph in single asterisks, whole.
const THOUGHT := "^\\*(?!\\*)([^*]*[^*\\s])\\*$"
## The rest before a paragraph's pen comes down, and before a strike, a tap and an unspoken line.
const LEAD := 0.35
## A strike through one line.
const STRIKE := 0.55
## THE WRITER DECIDES BEFORE STRIKING (2026-10-27, the user: "The actor writes the line, then IMMEDIATELY
## scratches it out. In reality, an actor would likely write the line, then pause, then scratch it out
## after a few seconds of silent decision-making"): the pen done and the voice done, this long with the
## pen held still over the line (seconds) - or the mark's own number, `<!-- strike: 4 -->`, held to
## [constant DECIDE_MOST].
const DECIDE := 3.0
const DECIDE_MOST := 30.0
## THE PAGE LIES BLANK A MOMENT FIRST (2026-10-27, the user: "the writing begins IMMEDIATELY after the intro
## disappears. It's too quick. We should linger on the blank page for a bit before we do any writing"): the
## voice rests this long (seconds) before its first word, and nothing is written before it, while the camera
## comes in over the empty pad ([LetterMedium]).
const BLANK_PAGE := 4.0
## A PICTURE CLEARS BEFORE THE LETTER GOES ON: it fades out from just after the passage's last word, and the
## voice rests until it is gone, so what the pen does next is seen from its start ([LetterMedium]) - unless
## another picture comes up over it there. Every fade, in, out and from one picture into the next, is this long
## (seconds; 2026-10-27, the user, of 1.2: "seems to be too fast. A 2 or 3 second fade might look better").
const IMAGE_AFTER := 0.1
const IMAGE_FADE := 2.5
## A tap: how long the pen is turned over and tapping, and the rest the voice leaves for it before it
## goes on (the taps run on under the next words).
const TAP := 2.4
const TAP_HOLD := 1.0
## A page turned between two lines: the pen goes off the pad, the sheet goes over, the pen comes back
## ([DeskMedium]'s turn, [constant DeskMedium.PARK_CLEAR] and the turn itself).
const TURN_REST := DeskScript.TURN + 1.3
## THE PEN AHEAD OF THE VOICE: each word written while the voice says the one this many words before it - and
## where the voice must wait for the pen (a new paragraph, a turn, a dense sentence) until a sentence's first
## that many words are on the page, its last said no more than OVERTAKE before it is written (the user: "the
## voice can preempt the end of the written sentence a bit").
const AHEAD_WORDS := 2
const OVERTAKE := 0.6
## A DRAWING DASHED OFF (2026-10-27, the user, of the chapter's tree of dots: the text "sort of gets frozen for a few
## seconds ... with the pen not moving" - the voice waited 7.5 s after its words while the pen dotted its last two
## rows): a sketch with more ink than its words leave time for at the desk's quickest ([constant DeskScript.MAX_PACE])
## is drawn quicker, up to DRAW_QUICKEST the hand's pace, to be done DRAW_TAIL (seconds) after them ([method draw_pace]).
const DRAW_QUICKEST := 7.0
const DRAW_TAIL := 1.5
## The pen at its quickest, against the hand's own pace ([constant LetterHand.PACE]): past a quick voice's 180 words
## a minute, so the pen keeps with the voice it has (at 2.0 a voice of 0.36 s a word left it 18 words behind).
const QUICKEST := 2.5
## A voice this quick a word inside a sentence (the chapter's is about 0.45), for the rests the voice is written:
## the pen keeps to the voice's own times whatever they are.
const READ_WORD := 0.45
## A sentence's end: its stop, and any quote or bracket closing after it.
const SENTENCE_END := "[.?!…][\"'’”)\\]]*$"
## A line's return to the margin, at the least (seconds) - [LetterMedium]'s pen, and the walk's guess of it.
const RETURN := 0.28
## The page, as the pad's: the first line's baseline (a rule below the pad's first) and how far a line may
## run (px).
const FIRST_LINE := DeskScript.FIRST_RULE + DeskScript.RULE
const LINE_W := DeskScript.PW - DeskScript.RIGHT - DeskScript.TEXT_X
## A struck line is crossed through this high: the share of the hand's body above the baseline.
const STRIKE_H := 20.0
## Where a rest goes inside a paragraph while its voice text is made (a turn's, a sentence's beat): a
## character no script holds, put back as the rest once the voice's own marks are taken out round it.
const HOLD_AT := "\ue000"


static func _rx(pattern: String) -> RegEx:
	return Manuscript._rx(pattern)


## Is [param body] a letter? Every text can be one - a letter is prose - so this is only whether it has
## words to write.
static func is_letter(body: String) -> bool:
	return not Manuscript.unspoken(Manuscript.strip_frontmatter(body)).strip_edges().is_empty()


## The id a part of a sketch carries in its SVG, from the words a point says it with ("the figure on
## the bed" -> "the-figure-on-the-bed").
static func part_id(words: String) -> String:
	var s := _rx("[^a-z0-9]+").sub(words.to_lower().strip_edges(), "-", true)
	return s.trim_prefix("-").trim_suffix("-")


## How long the writer decides before a strike: the mark's own number of seconds ([param arg], from
## `<!-- strike: 4 -->`), else [constant DECIDE].
static func decide_of(arg: String) -> float:
	var a := arg.strip_edges().trim_suffix("s").strip_edges()
	return clampf(a.to_float(), 0.0, DECIDE_MOST) if a.is_valid_float() else DECIDE


## THE SKETCHES of [param body], in order: `[{key, prompt, said, parts}]` - the key its description's
## ([method Manuscript.image_key]), what is said while it is drawn (its paragraph, as [method parse]
## finds it), the parts each point at it names ([method part_id] of each): what an agent is handed to
## draw it.
static func sketches(body: String) -> Array:
	var out: Array = []
	var cur: Dictionary = {}
	var said_next := false
	for b in blocks(body):
		var blk: Dictionary = b
		var kind := String(blk["kind"])
		if kind == "sketch":
			cur = {"key": Manuscript.image_key(String(blk["arg"])), "prompt": String(blk["arg"]), "said": "",
				"parts": []}
			out.append(cur)
			said_next = true
		elif kind == "para" and not cur.is_empty():
			var text := String(blk["text"])
			if said_next and not _words(text).is_empty():
				cur["said"] = Manuscript.unspoken(text).strip_edges()
				said_next = false
			for m in _rx(POINT).search_all(text):
				var t := _target(m.get_string(1))
				if String(t["at"]) == "sketch" and not String(t["part"]).is_empty() \
						and not (cur["parts"] as Array).has(String(t["part"])):
					(cur["parts"] as Array).append(String(t["part"]))
		elif kind != "para":
			said_next = false
	return out


## THE PICTURES of [param body] as the painter is handed them ([IllustrationPanel]): its image marks,
## each pinned to the screen (`(screen)`: a letter shows every picture over the whole frame, so it is
## painted wide - a book's full page is painted tall), and no sketch (the pen's, never painted). A
## picture's key is its words', so the medium finds the painting whatever it was pinned to.
static func pictures_only(body: String) -> String:
	var out := _rx("<!--\\s*sketch\\s*:[\\s\\S]*?-->").sub(body, "", true)
	return _rx("<!--\\s*image\\s*(?:\\(\\s*\\w+\\s*\\))?\\s*:").sub(out, "<!-- image (screen):", true)


## What a point points at: `{at, part}` - "sketch" (the last one; `part` the id of the piece named),
## "camera", or whatever else was written, which the pen leaves be.
static func _target(arg: String) -> Dictionary:
	var a := arg.strip_edges()
	var head := a.get_slice(",", 0).strip_edges().to_lower()
	var rest := a.substr(a.find(",") + 1).strip_edges() if a.contains(",") else ""
	return {"at": head, "part": part_id(rest)}


## THE LETTER IN BLOCKS: each own-line mark `{kind, arg}` (kind one of strike, tap, still, page,
## image_end, unspoken, sketch, image) and each paragraph `{kind: "para", text}` - a comment over several
## lines read as one line, any other own-line comment a note that ends the paragraph and is dropped.
static func blocks(body: String) -> Array:
	var src := Manuscript.strip_frontmatter(body)
	var mark := _rx(MARK)
	var pic := _rx("^\\s*<!--\\s*(image|sketch)\\s*(?:\\(\\s*(\\w+)\\s*\\))?\\s*:\\s*([\\s\\S]*?)\\s*-->\\s*$")
	var voice := _rx("^\\s*(?:<!--\\s*(?:hesitation|delivery|speaker|point)\\b[\\s\\S]*?-->\\s*)+$")
	var note := _rx("^\\s*<!--[\\s\\S]*?-->\\s*$")
	var out: Array = []
	var para := PackedStringArray()
	for line in _logical_lines(src):
		var s := String(line)
		if s.strip_edges().is_empty():
			_end_para(out, para)
			continue
		var m := mark.search(s)
		if m != null:
			_end_para(out, para)
			var verb := m.get_string(1).replace(" ", "").to_lower()
			var kind: String = {"newpage": "page", "/image": "image_end"}.get(verb, verb)
			out.append({"kind": kind, "arg": m.get_string(2).strip_edges()})
			continue
		var p := pic.search(s)
		if p != null:
			_end_para(out, para)
			out.append({"kind": p.get_string(1), "arg": p.get_string(3).strip_edges(), "placement": p.get_string(2)})
			continue
		if note.search(s) != null and voice.search(s) == null:
			_end_para(out, para)
			continue
		para.append(s)
	_end_para(out, para)
	return out


static func _end_para(out: Array, para: PackedStringArray) -> void:
	if para.is_empty():
		return
	out.append({"kind": "para", "text": "\n".join(para)})
	para.clear()


## [param src]'s lines, a comment that runs over several lines joined into one.
static func _logical_lines(src: String) -> PackedStringArray:
	var out := PackedStringArray()
	var held := ""
	for line in src.split("\n"):
		var s := String(line)
		if not held.is_empty():
			held += " " + s.strip_edges()
			if s.contains("-->"):
				out.append(held)
				held = ""
			continue
		var open := s.rfind("<!--")
		if open >= 0 and s.find("-->", open) < 0:
			held = s
			continue
		out.append(s)
	if not held.is_empty():
		out.append(held)
	return out


## Is paragraph [param text] a thought - in italics, whole, the marks in it aside?
static func is_thought(text: String) -> bool:
	return _rx(THOUGHT).search(Manuscript.unspoken(text).strip_edges()) != null


## A paragraph's spoken words, normalized - what the voice says of it ([method DeskScript._words]).
static func _words(text: String) -> PackedStringArray:
	return DeskScript._words(text)


## THE WRITTEN WORDS of paragraph [param text]: `[{text, emph, spoken, at}]` - each word as the hand
## writes it (marks out, emphasis's asterisks off and the word underlined instead), the index among the
## paragraph's spoken words it is, -1 for one the voice does not say (a dash alone), and where it begins
## in [param text], for a rest to be put before it.
static func _written(text: String) -> Array:
	var out: Array = []
	var comment := _rx(Manuscript.COMMENT)
	var spans: Array = []
	for m in comment.search_all(text):
		spans.append(Vector2i(m.get_start(), m.get_end()))
	var spoken := 0
	var emph := false
	var tok := _rx("\\S+")
	for m in tok.search_all(text):
		var at := m.get_start()
		var inside := false
		for s in spans:
			if at >= (s as Vector2i).x and at < (s as Vector2i).y:
				inside = true
		if inside:
			continue
		var raw := comment.sub(m.get_string(), "", true)
		if raw.is_empty():
			continue
		var opens := raw.begins_with("*") or raw.begins_with("_")
		var bare := raw.replace("*", "").replace("_", "")
		bare = _rx("\\[([A-Za-z])\\]").sub(bare, "$1", true)
		bare = _rx("\\$\\{[A-Z_]+:([^}]*)\\}").sub(bare, "$1", true)
		if bare.is_empty():
			continue
		if opens:
			emph = true
		var on := emph
		if raw.ends_with("*") or raw.ends_with("_") or raw.rstrip(".,;:!?)'\"").ends_with("*"):
			emph = false
		var n := TabletScript.norm(bare)
		out.append({"text": bare, "emph": on, "spoken": spoken if not n.is_empty() else -1, "at": at})
		if not n.is_empty():
			spoken += 1
	return out


## THE WALK. [param seed]: the hand's unsteadiness. [param hand]: which hand writes it ([LetterHand]).
## [param svgs]: a sketch's key -> its SVG (one not drawn yet is left
## off the page, and its paragraph is only said). [param lengths] and [param sizes]: a drawing's id ->
## its drawing time and typeset record, as [method DeskScript.parse] takes them. Returns:
##   actions   - the pen's, in [DeskMedium]'s shape (each with an `id`, "" for what puts no ink down)
##               and the words' order: a line `pad-text` (its
##               `strokes` the hand's schedule, `span` its spoken words, `k` 1), a sketch `draw`, a
##               `strike` per struck line, a `point` (in a paragraph the pen is not busy with), a `tap`
##               (`target` desk or pad)
##   spans     - what the camera and the screen follow, by spoken word (`from` to `to`, exclusive):
##               `image` (`key`, `prompt`, `blend` when it comes up over the picture before it), `still`,
##               `thought`, `camera` (a point at whoever watches)
##   spoken    - PackedStringArray: every spoken word, normalized
##   speakable - the text the voice reads
##   ignored   - the points the pen could not make (it was writing or drawing then), for the log
##   pauses    - the spoken words a hesitation follows (on a line of its own, or in a written paragraph):
##               the writer stops there too ([LetterMedium])
static func parse(body: String, seed := 1, svgs: Dictionary = {}, lengths: Dictionary = {},
		sizes: Dictionary = {}, hand := LetterHand.DEFAULT) -> Dictionary:
	var point := _rx(POINT)
	var actions: Array = []
	var spans: Array = []
	var voice: Array = []            # in order: {hold, act} (a rest, and the action it is for) or {para, base}
	var spoken := PackedStringArray()
	var ignored := PackedStringArray()
	var pending := -1                # a sketch waiting for its paragraph (its action), -1 for none
	var waiting := false             # ...or one with no drawing yet, whose paragraph is still its own
	var last_sketch := -1
	var last_para: Array = []        # the lines of the paragraph last written
	var image := {}
	var still := {}
	var new_page := false
	var line_n := 0
	var pauses: Array = []           # the spoken words a hesitation follows, where the writer stops too
	voice.append({"hold": BLANK_PAGE, "act": -1})
	for b in blocks(body):
		var blk: Dictionary = b
		var kind := String(blk["kind"])
		var text := String(blk.get("text", ""))
		var said := _words(text) if kind == "para" else PackedStringArray()
		if kind == "para" and said.is_empty():
			voice.append({"para": text, "base": spoken.size()})      # a hesitation on a line of its own
			if spoken.size() > 0 and _rx(Manuscript.HESITATION).search(text) != null:
				pauses.append(spoken.size() - 1)
			continue
		if (pending >= 0 or waiting) and kind != "para":
			# A SKETCH WITH NO PARAGRAPH OF ITS OWN is drawn in silence: the voice waits it out
			if pending >= 0:
				var w := float((actions[pending] as Dictionary)["write"])
				voice.append({"hold": w, "act": -1, "pen": w})
			pending = -1
			waiting = false
		match kind:
			"strike":
				var decide := decide_of(String(blk["arg"]))
				for li in last_para:
					var wait := decide if li == last_para[0] else 0.0
					voice.append({"hold": wait + STRIKE, "act": actions.size(), "pen": wait + STRIKE, "sync": true})
					actions.append({"kind": "strike", "id": "", "of": int(li), "write": STRIKE, "dur": STRIKE,
						"after": spoken.size(), "span": 0, "decide": wait})
				last_para = []
			"tap":
				var where := String(blk["arg"]).to_lower()
				voice.append({"hold": TAP_HOLD, "act": actions.size(), "pen": TAP, "sync": true})
				actions.append({"kind": "tap", "id": "", "target": "desk" if where == "desk" else "pad",
					"write": TAP, "dur": TAP_HOLD, "after": spoken.size(), "span": 0})
			"still":
				still = {"kind": "still", "from": spoken.size(), "to": -1}
				spans.append(still)
				# the pen off the page for it, and kept off it until the voice is past it
				voice.append({"hold": 0.0, "act": -1, "sync": true, "still": true})
			"page":
				new_page = true
			"image":
				# A PICTURE STRAIGHT AFTER ANOTHER'S PASSAGE comes up over it: nothing between to see the page for,
				# and no rest for the page to come back
				var blend := false
				if not image.is_empty() and int(image["to"]) < 0:
					image["to"] = spoken.size()
					blend = spoken.size() > int(image["from"])
				elif not image.is_empty() and int(image["to"]) == spoken.size() and spoken.size() > int(image["from"]) \
						and bool((voice.back() as Dictionary).get("image_end", false)):
					voice.pop_back()
					blend = true
				image = {"kind": "image", "key": Manuscript.image_key(String(blk["arg"])),
					"prompt": String(blk["arg"]), "from": spoken.size(), "to": -1, "blend": blend}
				spans.append(image)
			"image_end":
				if not image.is_empty() and int(image["to"]) < 0:
					image["to"] = spoken.size()
					voice.append({"hold": IMAGE_AFTER + IMAGE_FADE, "act": -1, "image_end": true})
			"sketch":
				var key := Manuscript.image_key(String(blk["arg"]))
				var svg := String(svgs.get(key, ""))
				waiting = svg.is_empty()
				if waiting:
					continue
				var act := {"kind": "draw", "key": key, "span": 0, "about": 0, "tail": 0.0,
					"after": spoken.size(), "page_break": new_page}
				act.merge(DeskScript.item("draw", svg), true)
				act["write"] = float(lengths.get(String(act["id"]), DeskScript.estimate(svg)))
				act["dur"] = LEAD + float(act["write"])
				new_page = false
				pending = actions.size()
				last_sketch = pending
				voice.append({"hold": LEAD, "act": pending, "sync": true})
				actions.append(act)
			"unspoken":
				var from := actions.size()
				for la in _lay_para(String(blk["arg"]), spoken.size(), seed, line_n, new_page, hand):
					var a: Dictionary = la
					a["span"] = 0
					a["dur"] = LEAD + float(a["write"])
					voice.append({"hold": LEAD + float(a["write"]), "act": actions.size(), "pen": LEAD + float(a["write"]),
						"sync": true})
					actions.append(a)
					line_n += 1
				new_page = false
				last_para = range(from, actions.size())
				if not still.is_empty() and int(still["to"]) < 0:
					still["to"] = spoken.size()
			"para":
				var base := spoken.size()
				var busy := true             # the pen writes or draws through it: no point in it
				if pending >= 0 or waiting:
					# THE SKETCH'S OWN PARAGRAPH: said while it is drawn, and never written
					var drawn := 0.0
					if pending >= 0:
						var s: Dictionary = actions[pending]
						s["dur"] = LEAD
						s["after"] = base
						s["span"] = said.size()
						drawn = float(s["write"])
					voice.append({"para": text, "base": base, "pen": drawn, "sync": true})
					pending = -1
					waiting = false
				elif is_thought(text):
					spans.append({"kind": "thought", "from": base, "to": base + said.size()})
					voice.append({"para": text, "base": base})
					busy = false
					# a point in it needs the pen there at its word: the voice waits for the pen first
					if point.search(text) != null and not String(_target(point.search(text).get_string(1))["at"]) == "camera":
						voice.back()["sync"] = true
				else:
					var lines := _lay_para(text, base, seed, line_n, new_page, hand)
					new_page = false
					last_para = []
					for la in lines:
						last_para.append(actions.size())
						actions.append(la)
						line_n += 1
					voice.append({"para": text, "base": base, "lines": last_para.duplicate()})
					# THE WRITER HESITATES TOO: a hesitation in what is written stops the pen where it is
					for m in _rx(Manuscript.HESITATION).search_all(text):
						var before := _words(text.substr(0, m.get_start())).size()
						if before > 0:
							pauses.append(base + before - 1)
					if not still.is_empty() and int(still["to"]) < 0:
						still["to"] = base
				# THE POINTS IN IT: at the word after the mark, held to its sentence's end
				for m in point.search_all(text):
					var t := _target(m.get_string(1))
					var rest := text.substr(m.get_end())
					var stop := _rx("[.?!](?=[*_\\s]|$)").search(rest)
					var after := base + _words(text.substr(0, m.get_start())).size()
					var span := maxi(1, _words(rest.substr(0, stop.get_end()) if stop != null else rest).size())
					if String(t["at"]) == "camera":
						spans.append({"kind": "camera", "after": after, "span": span, "from": after,
							"to": after + span})
					elif busy:
						ignored.append(m.get_string().strip_edges())
					else:
						actions.append({"kind": "point", "id": "", "target": String(t["at"]), "part": String(t["part"]),
							"of": last_sketch if String(t["at"]) == "sketch" else -1, "after": after,
							"span": span, "write": 0.0, "dur": 0.0, "tail": 0.0})
				spoken.append_array(said)
	if pending >= 0:
		var w := float((actions[pending] as Dictionary)["write"])
		voice.append({"hold": w, "act": -1, "pen": w})
	for s in spans:
		if int((s as Dictionary)["to"]) < 0:
			s["to"] = spoken.size()
	_keep_with(actions, spans)
	actions = lay_out(actions, sizes, hand)
	return {"actions": actions, "spans": spans, "spoken": spoken, "ignored": ignored, "pauses": pauses,
		"speakable": _voice_text(voice, actions, spans)}


## THE VOICE'S TEXT from [param voice] (what [method parse] gathered, in order): each paragraph's words
## with the voice's own marks, ONE rest between two - the rests the pen asked for summed, a page's turn
## among them where [param actions]' layout turned one for a silent thing - and inside a written paragraph
## a rest at a sentence's start where the voice waits for the pen to be ahead - but never at or after a page
## turned inside the paragraph.
##
## THE PEN AND THE VOICE ARE FOLLOWED THROUGH THE LETTER TOGETHER, as [LetterMedium]'s plan follows them:
## the voice a [constant READ_WORD] a word; the pen line after line, each word as the voice says the one
## [constant AHEAD_WORDS] before it and never quicker than [constant QUICKEST] its ink's own time, each line begun no sooner than the last's
## end and a return ([constant RETURN]) - nor, after a thought, a still or the blank page, than the voice gets
## there, nor, for a line a page turns for, than the voice has read the page and the page is turned. At each
## sentence's start the voice waits until the pen at its quickest can be ahead of it there ([method _ahead], the
## words' times on the page by their lines' `ends`) - but A PAGE TURNED INSIDE A PARAGRAPH IS NOT WAITED FOR
## (2026-10-27, the user, of "You do not" said and a rest for the turn before "remember agreeing to them": "It
## would probably feel most natural to just keep speaking there, and to force the pen to catch up after the page
## turn"): the voice reads the paragraph on through it, the pen comes back behind and catches up at its quickest,
## and the voice waits for it only at the next paragraph, if it is still behind. A turn between two paragraphs is
## still waited for: the writer turning the page is the pause there. A paragraph's first
## line the voice is waited for at is handed that rest (`gate` "voice", `gate_rest`), and a line a page turns
## for is marked ("turn"): [LetterMedium] begins them as the voice gets there. Before what needs
## the pen free (`sync`: a strike, a tap, a drawing, an unspoken line, a point in a thought, a still) the
## voice waits until it is. Under a picture ([param spans]' images) the voice reads on and the pen keeps up
## with it, as the desk's does, unseen.
static func _voice_text(voice: Array, actions: Array, spans: Array) -> String:
	var turns := {}                  # spoken index -> true: a drawing said from there turns a page
	for a in actions:
		var act: Dictionary = a
		if bool(act.get("turn", false)) and int(act.get("span", 0)) > 0 and String(act["kind"]) != "pad-text":
			turns[int(act["after"])] = true
	var speak := PackedStringArray()
	var hold := 0.0
	var tv := 0.0                    # where the voice is
	var tp := 0.0                    # when the pen is free
	var gated := true                # the next written paragraph waits for the voice to get to it (the blank page first)
	var said0 := {}                  # a spoken word -> when the voice begins it (the written paragraphs')
	for v in voice:
		var e: Dictionary = v
		if bool(e.get("sync", false)) and tp > tv + 0.05:
			hold += tp - tv
			tv = tp
		if bool(e.get("still", false)):
			gated = true
		if e.has("hold"):
			var h := float(e["hold"])
			var ai := int(e.get("act", -1))
			if ai >= 0 and bool((actions[ai] as Dictionary).get("turn", false)) \
					and int((actions[ai] as Dictionary).get("span", 0)) == 0:
				h += TURN_REST
			tp = maxf(tp, tv) + float(e.get("pen", 0.0)) + (h - float(e["hold"]))
			hold += h
			tv += h
			continue
		var text := String(e["para"])
		var base := int(e["base"])
		var n := _words(text).size()
		var inner := {}                  # a spoken word of the paragraph -> the rest before it
		var lines: Array = e.get("lines", [])
		var pictured := _pictured(base, spans)
		if not lines.is_empty() and not pictured:
			# WRITTEN AHEAD: the voice waits at each sentence's start and each turned line's
			var w_end := {}              # a spoken word of the paragraph -> when it is on the page
			var li := 0
			var t_word := tv
			var points := _beats(text).keys()
			points.append(0)
			for l in lines:
				var line: Dictionary = actions[int(l)]
				if bool(line.get("turn", false)):
					points.append(int(line["after"]) - base)
			points.sort()
			var at := 0
			var turned_in := false       # a page turned inside the paragraph: the voice reads it on through
			while at < points.size():
				var p := int(points[at])
				var q := n
				while at < points.size() and int(points[at]) == p:
					at += 1
				if at < points.size():
					q = int(points[at])
				# the pen's lines as far as this stretch's last word, as soon as they can be at its quickest -
				# how long the voice must wait for it
				var fresh: Array = []        # [line, the soonest it can begin]
				var soonest := tp
				while li < lines.size() and int((actions[int(lines[li])] as Dictionary)["after"]) - base < q:
					var line: Dictionary = actions[int(lines[li])]
					var k0 := int(line["after"]) - base
					var begin := soonest + RETURN
					line["gate"] = ""
					if bool(line.get("turn", false)):
						# the page is read before it turns: the voice has said all of it
						begin = maxf(begin, t_word + TURN_REST)
						line["gate"] = "turn"
						turned_in = turned_in or k0 > 0
					elif li == 0 and gated:
						begin = maxf(begin, tv)
						line["gate"] = "voice"
					var ends: PackedFloat32Array = line.get("ends", PackedFloat32Array())
					for j in int(line["span"]):
						w_end[k0 + j] = begin + (ends[j] if j < ends.size() else float(line["write"])) / QUICKEST
					soonest = begin + float(line["write"]) / QUICKEST
					fresh.append([line, begin])
					li += 1
				var head := mini(p + AHEAD_WORDS - 1, q - 1)
				var wait := _ahead(t_word, float(w_end.get(head, t_word)), float(w_end.get(q - 1, t_word)), q - 1 - p)
				if p == 0:
					hold += wait
					if not fresh.is_empty() and String((fresh[0][0] as Dictionary)["gate"]) == "voice":
						(fresh[0][0] as Dictionary)["gate_rest"] = wait
				elif turned_in:
					# A PAGE TURNED INSIDE A PARAGRAPH IS NOT WAITED FOR, nor is the pen after it: it comes back
					# behind the voice and catches up at its quickest, the voice waiting at the next paragraph if it must
					wait = 0.0
				elif wait > 0.0:
					inner[p] = float(inner.get(p, 0.0)) + wait
				for k in range(p, q):
					said0[base + k] = t_word + wait + float(k - p) * READ_WORD
				# ...and as the pen does write them: each word while the voice says the one AHEAD_WORDS before it,
				# never quicker than its quickest
				for f in fresh:
					var line: Dictionary = f[0]
					var first := int(line["after"]) - AHEAD_WORDS
					var last := int(line["after"]) + int(line["span"]) - 1 - AHEAD_WORDS
					var begin := maxf(maxf(float(f[1]), tp + RETURN), float(said0.get(first, -INF)))
					tp = maxf(begin + float(line["write"]) / QUICKEST, float(said0.get(last, -INF)) + READ_WORD)
				t_word += wait + float(q - p) * READ_WORD
			gated = false
			if hold > 0.005:
				speak.append("<!-- action-hold: %s -->" % String.num(hold, 2))
			hold = 0.0
			tv = t_word
		else:
			if turns.has(base):
				hold += TURN_REST
				tv += TURN_REST
				tp = maxf(tp, tv)
			if hold > 0.005:
				speak.append("<!-- action-hold: %s -->" % String.num(hold, 2))
			hold = 0.0
			var said_from := tv
			if not lines.is_empty():
				# under a picture: the desk's dictation, the pen kept with the voice
				var t_word := tv
				for l in lines:
					var line: Dictionary = actions[int(l)]
					var words_end := t_word + float(int(line["span"])) * READ_WORD
					var begin := maxf(tp + RETURN, t_word - 0.2)
					tp = maxf(begin + float(line["write"]) / DeskScript.MAX_PACE, words_end)
					t_word = words_end
				tv = t_word
			else:
				for k in range(1, n):
					if turns.has(base + k):
						inner[k] = TURN_REST
				tv += float(n) * READ_WORD + TURN_REST * float(inner.size())
				var work := float(e.get("pen", 0.0))
				if work > 0.0:
					tp = maxf(maxf(tp, said_from) + work / draw_pace(work, float(n) * READ_WORD), tv)
				elif n > 0 and is_thought(text):
					# a thought: the writer stops and thinks it, the pen waits
					gated = true
		var voiced := CardReading._voice_marks(_hold_before(text, inner) if not inner.is_empty() else text)
		# each mark, in the text's order, the rest of the word it stands before
		for k in _sorted_keys(inner):
			var cut := voiced.find(HOLD_AT)
			if cut < 0:
				break
			voiced = voiced.substr(0, cut) + "<!-- action-hold: %s -->" % String.num(float(inner[k]), 2) \
				+ voiced.substr(cut + HOLD_AT.length())
		if not voiced.is_empty():
			speak.append(voiced)
	if hold > 0.005:
		speak.append("<!-- action-hold: %s -->" % String.num(hold, 2))
	return "\n\n".join(speak)


## HOW LONG THE VOICE WAITS, come to a stretch at [param tv] that the pen has written its first [constant
## AHEAD_WORDS] words of by [param head] and its last of by [param last], [param words] words on: until those
## first words are on the page, and its last is said no more than [constant OVERTAKE] before it is written.
static func _ahead(tv: float, head: float, last: float, words: int) -> float:
	var w := maxf(head + 0.1 - tv, last - OVERTAKE - (tv + float(words) * READ_WORD))
	return w if w > 0.05 else 0.0


## HOW FAST A SKETCH IS DRAWN, against the hand's pace: [param work] seconds of ink at the hand's own, to be done
## [constant DRAW_TAIL] after the [param said] seconds of its words - never slower than the desk's quickest, which
## a drawing with room is drawn at, nor quicker than [constant DRAW_QUICKEST] ([LetterMedium] draws one as slowly
## as the next line leaves it time for).
static func draw_pace(work: float, said: float) -> float:
	return clampf(work / maxf(said + DRAW_TAIL, 0.1), DeskScript.MAX_PACE, DRAW_QUICKEST)


## Is the paragraph whose first spoken word is [param base] read under a picture ([param spans]' images)?
static func _pictured(base: int, spans: Array) -> bool:
	for s in spans:
		var sp: Dictionary = s
		if String(sp["kind"]) == "image" and base >= int(sp["from"]) and base < int(sp["to"]):
			return true
	return false


## THE SENTENCES of paragraph [param text] after its first: their first spoken words (the indices among the
## paragraph's spoken words) - where the voice may wait for the pen ([method _voice_text]).
static func _beats(text: String) -> Dictionary:
	var out := {}
	var ended := false
	for w in _written(text):
		var k := int((w as Dictionary)["spoken"])
		if k < 0:
			continue
		if ended:
			out[k] = true
		ended = _rx(SENTENCE_END).search(String(w["text"])) != null
	return out


## [param d]'s keys, smallest first.
static func _sorted_keys(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys


## [param text] (a paragraph) with a rest's mark before each of its spoken words [param rests] (their
## indices among its words, the keys), where a sentence begins or a turned line does.
static func _hold_before(text: String, rests: Dictionary) -> String:
	var cuts: Array = []
	for w in _written(text):
		if rests.has(int((w as Dictionary)["spoken"])):
			cuts.append(int(w["at"]))
	cuts.reverse()
	var out := text
	for c in cuts:
		out = out.substr(0, int(c)) + HOLD_AT + " " + out.substr(int(c))
	return out


## THE LINES OF A PARAGRAPH: [param text] cut into lines as the page's width allows ([constant LINE_W]),
## each a `pad-text` action with the [param hand]'s strokes - laid on the page by [method lay_out], the
## first marked `para` (a rule is left empty above it). [param base] is the paragraph's first spoken word,
## [param n] the letter's line count so far (each line's hand is salted by its place), [param page_break]
## whether its first line starts a page.
static func _lay_para(text: String, base: int, seed: int, n: int, page_break: bool, hand: String) -> Array:
	var out: Array = []
	var cur: Array = []
	var x := 0.0
	var sp := LetterHand.space(hand) * DeskScript.PX_PER_PT
	for w in _written(text):
		var adv := LetterHand.advance(String((w as Dictionary)["text"]), hand) * DeskScript.PX_PER_PT
		if not cur.is_empty() and x + adv > LINE_W:
			out.append(_line_action(cur, base, seed, n + out.size(), hand))
			cur = []
			x = 0.0
		cur.append(w)
		x += adv + sp
	if not cur.is_empty():
		out.append(_line_action(cur, base, seed, n + out.size(), hand))
	if not out.is_empty():
		(out[0] as Dictionary)["page_break"] = page_break
		(out[0] as Dictionary)["para"] = true
	return out


## One line's action: its words written by the [param hand] ([LetterHand]), timed by [method Ink.schedule].
static func _line_action(words: Array, base: int, seed: int, n: int, hand: String) -> Dictionary:
	var texts := PackedStringArray()
	var emph: Array = []
	var first := -1
	var said := 0
	for w in words:
		texts.append(String((w as Dictionary)["text"]))
		emph.append(bool(w["emph"]))
		if int(w["spoken"]) >= 0:
			said += 1
			if first < 0:
				first = int(w["spoken"])
	var salt := "line-%d" % n
	var written := LetterHand.line(texts, emph, seed, salt, hand)
	var sched := Ink.schedule(written["strokes"], seed, LetterHand.PACE)
	# WHEN EACH SPOKEN WORD IS ON THE PAGE, seconds into the line: its last stroke's end (a word drawn with
	# none, the one before's) - what the voice is held behind ([method _voice_text])
	var done := {}
	for st in sched["strokes"]:
		done[int((st as Dictionary).get("k", 0))] = maxf(float(done.get(int(st.get("k", 0)), 0.0)), float(st["t1"]))
	var ends := PackedFloat32Array()
	var last := 0.0
	for wi in words.size():
		last = maxf(last, float(done.get(wi, last)))
		if int((words[wi] as Dictionary)["spoken"]) >= 0:
			ends.append(last)
	return {"kind": "pad-text", "id": "l%d-%s" % [n, (" ".join(texts) + salt + hand).sha256_text().substr(0, 8)],
		"text": " ".join(texts), "strokes": sched, "write": float(sched["length"]), "ends": ends,
		"after": base + maxi(first, 0), "span": said, "about": 0, "tail": 0.0, "dur": 0.0,
		"w_pt": float(written["width"])}


## A SKETCH STAYS ON THE PAGE WITH WHAT IS SAID ABOUT IT (the first look, 2026-10-26: the cross and the dot
## at a page's foot, the page turned under the test the letter asks the viewer to do with them, and the
## pen pointing at a dot on a page already turned): each `draw` in [param actions] is told how many lines
## are written after it before the last point at it, or before the end of a still after it (`keep`: rows,
## a paragraph's empty rule above it among them), and [method lay_out] starts it on a page of its own when
## they would not fit under it.
static func _keep_with(actions: Array, spans: Array) -> void:
	for di in actions.size():
		var d: Dictionary = actions[di]
		if String(d["kind"]) != "draw":
			continue
		var upto := -1                   # the last spoken word it must be seen through
		for pi in actions.size():
			var p: Dictionary = actions[pi]
			if String(p["kind"]) == "point" and int(p.get("of", -1)) == di:
				upto = maxi(upto, int(p["after"]))
		var next_draw := INF
		for j in range(di + 1, actions.size()):
			if String((actions[j] as Dictionary)["kind"]) == "draw":
				next_draw = float(int((actions[j] as Dictionary)["after"]))
				break
		for s in spans:
			var sp: Dictionary = s
			if String(sp["kind"]) == "still" and int(sp["from"]) >= int(d["after"]) and float(sp["from"]) < next_draw:
				upto = maxi(upto, int(sp["to"]))
		var n := 0
		for j in range(di + 1, actions.size()):
			var a: Dictionary = actions[j]
			if String(a["kind"]) == "pad-text" and int(a["after"]) < upto:
				n += 2 if n > 0 and bool(a.get("para", false)) else 1
		d["keep"] = n


## WHERE EACH ACTION GOES ON THE PAGE ([method DeskScript.lay_out]'s, for a letter's lines, in [param hand]):
## a line on the next rule - a paragraph's first a rule further, under a line of the paragraph before it -
## a sketch centered half a rule below what is above it, a page turned where the next line
## or drawing would run off the foot - or where the letter asks for a new page - `turn` on what starts it.
## A strike stands on the page of what it crosses out; a point on the page it is made over, which may no
## longer hold what it names ([method DeskMedium.target_box]). Pure: a function of the actions and
## the typeset drawings.
static func lay_out(actions: Array, sizes: Dictionary, hand := LetterHand.DEFAULT) -> Array:
	var out: Array = []
	var page := 0
	var y := FIRST_LINE - DeskScript.RULE       # the last baseline used
	var bottom := y                             # how far down the page is written
	var started := false                        # anything on this page yet
	var under_text := false                     # ...and the last of it a line of writing
	var foot := DeskScript.PH - DeskScript.FOOT
	for a in actions:
		var act: Dictionary = (a as Dictionary).duplicate()
		act["i"] = out.size()
		act["page"] = page
		act["turn"] = false
		match String(act["kind"]):
			"pad-text":
				var gap := DeskScript.RULE if under_text and bool(act.get("para", false)) else 0.0
				var base := _snap_rule(maxf(y + DeskScript.RULE, bottom + LetterHand.ascent_px(hand) * 0.8) + gap)
				if started and (bool(act.get("page_break", false)) or base + LetterHand.descent_px(hand) > foot):
					page += 1
					act["turn"] = true
					base = FIRST_LINE
				act["page"] = page
				act["at"] = Vector2(DeskScript.TEXT_X, base)
				act["k"] = 1.0
				act["w"] = float(act.get("w_pt", 0.0)) * DeskScript.PX_PER_PT
				act["h"] = STRIKE_H
				act["d"] = LetterHand.descent_px(hand) * 0.5
				y = base
				bottom = base + LetterHand.descent_px(hand) * 0.6
				started = true
				under_text = true
			"draw":
				var r: Dictionary = sizes.get(String(act["id"]), {})
				if r.is_empty():
					r = DeskScript.figure_size(String(act.get("tex", "")))
				var w := float(r.get("w", 200.0)) * DeskScript.PX_PER_PT
				var h := float(r.get("h", 100.0)) * DeskScript.PX_PER_PT
				var d := float(r.get("d", 0.0)) * DeskScript.PX_PER_PT
				var room := DeskScript.PW - DeskScript.RIGHT - DeskScript.TEXT_X
				var k := minf(1.0, room / w) if w > 0.0 else 1.0
				var top := bottom + DeskScript.RULE * 0.5
				# the lines kept with it: the first lands up to a rule and a half under it, each next a rule on
				var keep := int(act.get("keep", 0))
				var kept := (float(keep) + 1.0) * DeskScript.RULE + LetterHand.descent_px(hand) if keep > 0 else 0.0
				var fresh := FIRST_LINE - DeskScript.RULE * 0.5 + (h + d) * k + kept <= foot
				if started and (bool(act.get("page_break", false)) or top + (h + d) * k > foot
						or (fresh and top + (h + d) * k + kept > foot)):
					page += 1
					act["turn"] = true
					top = FIRST_LINE - DeskScript.RULE * 0.5
				act["page"] = page
				act["at"] = Vector2(DeskScript.TEXT_X + maxf(0.0, (room - w * k) * 0.5), top + h * k)
				act["k"] = k
				act["w"] = w * k
				act["h"] = h * k
				act["d"] = d * k
				bottom = top + (h + d) * k + DeskScript.RULE * 0.25
				y = _snap_rule(bottom) - DeskScript.RULE
				started = true
				under_text = false
			"strike":
				var of := int(act.get("of", -1))
				act["page"] = int((out[of] as Dictionary)["page"]) if of >= 0 and of < out.size() else page
		out.append(act)
	return out


## The first rule at or below [param y].
static func _snap_rule(y: float) -> float:
	return DeskScript._snap_rule(y)


## [param body] as the voice reads it.
static func speakable(body: String, seed := 1, svgs: Dictionary = {}, lengths: Dictionary = {},
		sizes: Dictionary = {}, hand := LetterHand.DEFAULT) -> String:
	return String(parse(body, seed, svgs, lengths, sizes, hand)["speakable"])


## HOW LONG [param body] RUNS when it is read (seconds, the bookends aside): every spoken word at
## [constant DeskScript.SAID_WORD] and every rest the letter asks the voice for.
static func runtime(body: String, seed := 1, svgs: Dictionary = {}, lengths: Dictionary = {},
		sizes: Dictionary = {}, hand := LetterHand.DEFAULT) -> float:
	var parsed := parse(body, seed, svgs, lengths, sizes, hand)
	var t := float((parsed["spoken"] as PackedStringArray).size()) * DeskScript.SAID_WORD
	for m in _rx("<!--\\s*action-hold\\s*:\\s*([0-9.]+)\\s*-->").search_all(String(parsed["speakable"])):
		t += float(m.get_string(1))
	return t


## THE SKETCHES' DRAWING TIMES from the ink step's records ([param records], id -> record) in the hand of
## [param seed], glyphs no hand has traced from [param fonts] (the answer's `fonts`): what [method parse]
## takes as `lengths` (the records themselves are its `sizes`).
static func lengths_of(records: Dictionary, seed: int, fonts: Dictionary = {}) -> Dictionary:
	var out := {}
	for id in records:
		var got := Ink.strokes_of(records[id], seed, fonts)
		out[id] = float(Ink.schedule(got["strokes"], seed)["length"])
	return out


## The ink step's answer ([param ink], `{items}`) as records by id: the ones TeX set.
static func records_of(ink: Variant) -> Dictionary:
	var out := {}
	if ink is Dictionary:
		for r in (ink as Dictionary).get("items", []):
			if r is Dictionary and bool((r as Dictionary).get("ok", false)):
				out[String((r as Dictionary)["id"])] = r
	return out


## THE ITEMS THE INK STEP LAYS OUT: each sketch's drawing, from [param svgs] (key -> SVG), as
## [method DeskScript.item] makes a `draw` mark's.
static func items(body: String, svgs: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	for s in sketches(body):
		var svg := String(svgs.get(String((s as Dictionary)["key"]), ""))
		if svg.is_empty():
			continue
		var it := DeskScript.item("draw", svg)
		if not seen.has(String(it["id"])):
			seen[String(it["id"])] = true
			out.append(it)
	return out
