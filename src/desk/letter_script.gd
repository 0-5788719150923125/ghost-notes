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
##     like <!-- struck: morning --> mourning   INSIDE A WRITTEN LINE: the struck words written and said,
##                                             then the writer stops to decide ([constant DECIDE]), the
##                                             pen crosses out those words alone and writes the words
##                                             after the mark beside them, on the same rule.
##     <!-- color: red -->, <!-- color: default -->
##                                             THE PEN'S INK from here on - a name of [constant
##                                             NotebookLayout.INKS], a hex color, or the desk's own: the
##                                             writer puts the pen in hand down and picks up that ink's
##                                             ([constant SWAP]; a pen each ink the letter uses lies by the
##                                             pad from the start, [method pens_of]). Inside a written line
##                                             the line stops there and goes on beside it in the new ink.
##     <!-- unspoken: Dear Ink, -->            written and not said: the voice waits while the pen
##                                             writes it. Inside a written line, words written in it and
##                                             never said ([constant UNSAID]): `like <!-- struck: morning
##                                             --> <!-- unspoken: mourning. -->` says "like morning."
##     <!-- sketch: what it shows -->          a drawing the pen makes on the page - an agent draws it
##                                             from the words as SVG ([LetterCard]), TeX's figure
##                                             reader lays it out - while the paragraph after it is
##                                             said: that paragraph is the drawing's, said as it is drawn
##                                             and then written under it, the voice waiting for the pen
##                                             (Pen reads the letter later); a rule is left empty under
##                                             it ([constant UNDER_SKETCH]). Not drawn yet, the paragraph
##                                             is written as it is said, as any other.
##     <!-- point: sketch -->, <!-- point: sketch, the dot on its own -->
##                                             INSIDE SPEECH: at the next word the pen points at the
##                                             last sketch, or at the part of it so described (the
##                                             agent names that part, [method part_id]) - in a
##                                             thought held [constant POINT_LINGER] past its
##                                             sentence, the voice resting.
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
const MARK := "^\\s*<!--\\s*(strike|tap|still|new\\s+page|/\\s*image|unspoken|color)\\s*(?::\\s*([\\s\\S]*?))?\\s*-->\\s*$"
## A point inside speech: group 1 what it points at.
const POINT := "<!--\\s*point\\s*:\\s*([^>]*?)\\s*-->"
## Words written and struck inside a line, the words after the mark written beside them: group 1 the struck words.
const STRUCK := "<!--\\s*struck\\s*:\\s*([^>]*?)\\s*-->"
## The pen's ink from here on: group 1 its name ([method ink_of]).
const COLOR := "<!--\\s*color\\s*:\\s*([^>]*?)\\s*-->"
## WORDS WRITTEN AND NEVER SAID inside a line (2026-10-28, the user, of "morning" struck and "mourning" written beside
## it: "it feels like the second 'mourning' should not have been spoken"): the unspoken mark inside a written
## paragraph - group 1 its words - kept in the line between UNSAID_OPEN and UNSAID_CLOSE, characters no script holds,
## written ([method _written]: none of them said) and taken out of everything the voice is given.
const UNSAID := "<!--\\s*unspoken\\s*:\\s*([^>]*?)\\s*-->"
const UNSAID_OPEN := "\ue002"
const UNSAID_CLOSE := "\ue003"
## A PEN EACH INK (2026-10-28, the user: "a single pen would not be able to create 2 different font colors. So, could
## we render multiple pens at the start, and pick them up/put them down as we use them?"): the writer changes ink by
## putting down the pen in hand at its place by the pad (SWAP_DOWN, seconds) and picking up the other (SWAP_UP) - the
## voice resting through it ([LetterMedium]).
const SWAP_DOWN := 1.0
const SWAP_UP := 1.6
const SWAP := SWAP_DOWN + SWAP_UP
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
## A POINT LINGERS (2026-10-28, the user, of Secular Haze's "That one's me." at the dot: "the camera moves there
## quickly, and the pen retreats immediately, and the camera moves again, and it feels jarring. We need the linger
## when we point"): a point in a thought - at a sketch or at whoever watches - is held this long (seconds) after its
## sentence is said, the voice resting through it ([LetterMedium]: the pen on what it points at, the camera there).
const POINT_LINGER := 3.0
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
## ...and any mark the voice pauses at - a stop, a comma, a semicolon, a colon, a dash: a page that ends on one is
## turned with the voice waiting ([method _voice_text]).
const PAUSE_END := "[.?!…,;:—–][\"'’”)\\]]*$"
## A line's return to the margin, at the least (seconds) - [LetterMedium]'s pen, and the walk's guess of it.
const RETURN := 0.28
## The page, as the pad's: the first line's baseline (a rule below the pad's first) and how far a line may
## run (px).
const FIRST_LINE := DeskScript.FIRST_RULE + DeskScript.RULE
## RULES LEFT EMPTY UNDER A SKETCH before the writing goes on (2026-10-29, the user: "Both sketches are too squished
## today, with text that is too close to them") - it had gone on the first rule clear of the drawing.
const UNDER_SKETCH := 1.0
const LINE_W := DeskScript.PW - DeskScript.RIGHT - DeskScript.TEXT_X
## A struck line is crossed through this high: the share of the hand's body above the baseline.
const STRIKE_H := 20.0
## Where a rest goes inside a paragraph while its voice text is made (a turn's, a sentence's beat): a
## character no script holds, put back as the rest once the voice's own marks are taken out round it.
const HOLD_AT := "\ue000"
## Where an ink changes INSIDE A WORD (2026-10-28, Secular Haze's "Pen<!-- color: red -->.<!-- color: default -->": the
## closing stop alone in red): a character no script holds, splitting the word there into two pieces written with no
## space between ([method _written]'s `glued`), never said.
const GLUE := "\ue001"


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
	return DeskScript._words(_voiced(text))


## [param text] as the voice is given it: words written and never said ([constant UNSAID]) out, and the splits of words
## an ink changes in ([constant GLUE]).
static func _voiced(text: String) -> String:
	if not text.contains(UNSAID_OPEN) and not text.contains(GLUE):
		return text
	# with the space before them, so a stop after them is the last word's ("morning." - never "morning .") - and the
	# sentence's own marks they end on kept: `<!-- unspoken: mourning. -->` still ends the sentence it is in
	return _rx("\\s*" + UNSAID_OPEN + "[^" + UNSAID_CLOSE + "]*?([.,;:!?…]*)" + UNSAID_CLOSE).sub(text, "$1", true) \
		.replace(GLUE, "")


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
	var unsaid := false              # inside words written and never said ([constant UNSAID])
	var tok := _rx("[^\\s\\x{E001}]+")
	for m in tok.search_all(text):
		var at := m.get_start()
		var glued := at > 0 and text[at - 1] == GLUE
		var piece := m.get_string()
		var quiet := unsaid or piece.contains(UNSAID_OPEN)
		if piece.contains(UNSAID_OPEN):
			unsaid = true
		if piece.contains(UNSAID_CLOSE):
			unsaid = false
		var inside := false
		for s in spans:
			if at >= (s as Vector2i).x and at < (s as Vector2i).y:
				inside = true
		if inside:
			continue
		var raw := comment.sub(piece, "", true).replace(UNSAID_OPEN, "").replace(UNSAID_CLOSE, "")
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
		var said := not n.is_empty() and not quiet
		out.append({"text": bare, "emph": on, "spoken": spoken if said else -1, "at": at, "glued": glued})
		if said:
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
##               `image` (`key`, `prompt`, `blend` when it comes up over the picture before it,
##               `after_hesitation` when a hesitation stands between the word before it and its mark), `still`,
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
	var pens := pens_of(body)
	var ink := ""                    # the ink the letter asks for now ([constant COLOR])
	var held := -1                   # the pen in hand (pens' index), -1 before the first is picked up
	voice.append({"hold": BLANK_PAGE, "act": -1})
	for b in blocks(body):
		var blk: Dictionary = b
		var kind := String(blk["kind"])
		var text := String(blk.get("text", ""))
		# WORDS STRUCK INSIDE A WRITTEN LINE are its words, written and said, and a color mark in one changes the pen
		# there: where each run of them ends, and each change, is a cut
		var cuts: Array = []
		var ink_to := ink
		if kind == "para" and not is_thought(text) and (_rx(STRUCK).search(text) != null or _rx(COLOR).search(text) != null
				or _rx(UNSAID).search(text) != null):
			var un := _marked(text, ink)
			text = String(un["text"])
			cuts = un["cuts"]
			ink = String(un["first"])
			ink_to = String(un["last"])
		elif kind == "para":
			ink_to = _ink_after(text, ink)
		var said := _words(text) if kind == "para" else PackedStringArray()
		var thought: Dictionary = {}     # the voice's entry for a thought paragraph, where a point's linger rests
		var narrated := ""               # a sketch's paragraph, said as it is drawn: written under it once it is
		if kind == "para" and said.is_empty():
			ink = ink_to
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
				if not last_para.is_empty():
					held = _hold_pen(actions, voice, held, pens.find(ink), spoken.size())
				for li in last_para:
					var wait := decide if li == last_para[0] else 0.0
					voice.append({"hold": wait + STRIKE, "act": actions.size(), "pen": wait + STRIKE, "sync": true})
					actions.append({"kind": "strike", "id": "", "of": int(li), "write": STRIKE, "dur": STRIKE,
						"after": spoken.size(), "span": 0, "decide": wait, "ink": pens[held]})
				last_para = []
			"color":
				ink = ink_of(String(blk["arg"]))
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
					"prompt": String(blk["arg"]), "from": spoken.size(), "to": -1, "blend": blend,
					"after_hesitation": pauses.has(spoken.size() - 1)}
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
				held = _hold_pen(actions, voice, held, pens.find(ink), spoken.size())
				act["ink"] = pens[held]
				pending = actions.size()
				last_sketch = pending
				voice.append({"hold": LEAD, "act": pending, "sync": true})
				actions.append(act)
			"unspoken":
				held = _hold_pen(actions, voice, held, pens.find(ink), spoken.size())
				var from := actions.size()
				for la in _lay_para(String(blk["arg"]), spoken.size(), seed, line_n, new_page, hand):
					var a: Dictionary = la
					a["span"] = 0
					a["ink"] = pens[held]
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
				# A SKETCH NOT DRAWN YET has nothing to say its paragraph over: it is written as it is said
				waiting = false
				if pending >= 0:
					# THE SKETCH'S OWN PARAGRAPH: said while it is drawn - and then written under it (below)
					var s: Dictionary = actions[pending]
					s["dur"] = LEAD
					s["after"] = base
					s["span"] = said.size()
					voice.append({"para": text, "base": base, "pen": float(s["write"]), "sync": true})
					pending = -1
					narrated = text
				elif is_thought(text):
					spans.append({"kind": "thought", "from": base, "to": base + said.size()})
					voice.append({"para": text, "base": base})
					thought = voice.back()
					busy = false
					# a point in it needs the pen there at its word: the voice waits for the pen first
					if point.search(text) != null and not String(_target(point.search(text).get_string(1))["at"]) == "camera":
						voice.back()["sync"] = true
				else:
					var struck: Array = []
					var lines := _lay_para(text, base, seed, line_n, new_page, hand, cuts, struck)
					new_page = false
					last_para = []
					held = _hold_pen(actions, voice, held, pens.find(ink), spoken.size())
					# A STRUCK RUN ENDS ITS PART OF THE PARAGRAPH: said and written up to it, the writer decides, the pen
					# crosses those words out, and the rest is the paragraph's next part, written on beside them - and
					# so does a change of ink, the writer putting one pen down and picking up the other there
					var ws := _written(text)
					var part_lines: Array = []
					var part_at := 0             # where the part begins in the text
					var part_base := base
					for li in lines.size():
						last_para.append(actions.size())
						part_lines.append(actions.size())
						var line_i := actions.size()
						(lines[li] as Dictionary)["ink"] = pens[held]
						actions.append(lines[li])
						line_n += 1
						var c := int((lines[li] as Dictionary).get("cut", -1))
						if c < 0:
							continue
						var at_word := int((cuts[c] as Dictionary)["at"])
						# the voice's part runs on to the next word said: a stop in another ink is said with its sentence
						var next_said := at_word
						while next_said < ws.size() and int((ws[next_said] as Dictionary)["spoken"]) < 0:
							next_said += 1
						var end := int((ws[next_said] as Dictionary)["at"]) if next_said < ws.size() else text.length()
						_voice_part(voice, actions, text.substr(part_at, end - part_at), part_base, part_lines)
						var said_to := base
						for wi in at_word:
							if int((ws[wi] as Dictionary)["spoken"]) >= 0:
								said_to += 1
						var first := true
						for st in struck:
							if int((st as Dictionary)["cut"]) != c:
								continue
							var wait := DECIDE if first else 0.0
							first = false
							voice.append({"hold": wait + STRIKE, "act": actions.size(), "pen": wait + STRIKE, "sync": true})
							actions.append({"kind": "strike", "id": "", "of": line_i - li + int(st["line"]),
								"x0": float(st["x0"]), "x1": float(st["x1"]), "write": STRIKE, "dur": STRIKE,
								"after": said_to, "span": 0, "decide": wait, "ink": pens[held]})
						held = _hold_pen(actions, voice, held, pens.find(String(cuts[c]["ink"])), said_to)
						part_lines = []
						part_at = end
						part_base = said_to
					_voice_part(voice, actions, text.substr(part_at), part_base, part_lines)
					# THE WRITER HESITATES TOO: a hesitation in what is written stops the pen where it is
					for m in _rx(Manuscript.HESITATION).search_all(text):
						var before := _words(text.substr(0, m.get_start())).size()
						if before > 0:
							pauses.append(base + before - 1)
					if not still.is_empty() and int(still["to"]) < 0:
						still["to"] = base
				# THE POINTS IN IT: at the word after the mark, held to its sentence's end - and in a thought, lingered
				# on past it ([constant POINT_LINGER]): the voice rests at the next sentence, or after the paragraph
				var linger_after := false
				for m in point.search_all(text):
					var t := _target(m.get_string(1))
					var rest := text.substr(m.get_end())
					var stop := _rx("[.?!](?=[*_\\s]|$)").search(rest)
					var after := base + _words(text.substr(0, m.get_start())).size()
					var span := maxi(1, _words(rest.substr(0, stop.get_end()) if stop != null else rest).size())
					var linger := POINT_LINGER if not thought.is_empty() else 0.0
					if String(t["at"]) == "camera":
						spans.append({"kind": "camera", "after": after, "span": span, "from": after,
							"to": after + span, "linger": linger})
					elif busy:
						ignored.append(m.get_string().strip_edges())
						linger = 0.0
					else:
						actions.append({"kind": "point", "id": "", "target": String(t["at"]), "part": String(t["part"]),
							"of": last_sketch if String(t["at"]) == "sketch" else -1, "after": after,
							"span": span, "write": 0.0, "dur": 0.0, "tail": 0.0, "linger": linger})
					if linger > 0.0:
						var k := after + span - base
						if k < said.size():
							var rests: Dictionary = thought.get_or_add("rests", {})
							rests[k] = maxf(float(rests.get(k, 0.0)), linger)
						else:
							linger_after = true
				if linger_after:
					voice.append({"hold": POINT_LINGER, "act": -1})
				spoken.append_array(said)
				ink = ink_to
				# ...AND THEN WRITTEN UNDER IT, as words written and not said are: the voice waits while the pen puts
				# them on the page (2026-10-29, the user of the paragraph under a tree of dots: "it fails to write down
				# the context Pen would need to have here") - said with the drawing, they are Pen's to read after it
				if not narrated.is_empty():
					held = _hold_pen(actions, voice, held, pens.find(ink), spoken.size())
					var from := actions.size()
					for la in _lay_para(narrated, spoken.size(), seed, line_n, new_page, hand):
						var a: Dictionary = la
						a["span"] = 0
						a["ink"] = pens[held]
						a["dur"] = LEAD + float(a["write"])
						voice.append({"hold": LEAD + float(a["write"]), "act": actions.size(), "pen": LEAD + float(a["write"]),
							"sync": true})
						actions.append(a)
						line_n += 1
					new_page = false
					last_para = range(from, actions.size())
					if not still.is_empty() and int(still["to"]) < 0:
						still["to"] = spoken.size()
	if pending >= 0:
		var w := float((actions[pending] as Dictionary)["write"])
		voice.append({"hold": w, "act": -1, "pen": w})
	for s in spans:
		if int((s as Dictionary)["to"]) < 0:
			s["to"] = spoken.size()
	_keep_with(actions, spans)
	actions = lay_out(actions, sizes, hand)
	# the pen picked up at the start: the first one anything is written with
	var first_pen := 0
	for a in actions:
		if (a as Dictionary).has("ink"):
			first_pen = pens.find(String(a["ink"]))
			break
	return {"actions": actions, "spans": spans, "spoken": spoken, "ignored": ignored, "pauses": pauses,
		"pens": pens, "first_pen": first_pen,
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
## words' times on the page by their lines' `ends`). A PAGE TURNED INSIDE A PARAGRAPH IS WAITED FOR WHERE THE PAGE
## ENDS ON A MARK ([constant PAUSE_END]: a stop, a comma, a dash) - the writer turning the page is the pause there,
## as it is between two paragraphs - BUT A SENTENCE IT BREAKS IS READ ON TO ITS END (2026-10-27, the user, of "You do
## not" said and a rest for the turn before "remember agreeing to them": "It would probably feel most natural to just
## keep speaking there, and to force the pen to catch up after the page turn"), and the voice then waits for the pen
## before the next sentence (2026-10-28: "if a page ended with punctuation, we can hold the voice until after the
## page turn. However if a sentence was broken by a page turn, we should just finish the thought/voice - and then we
## should wait for the pen to catch up, before proceeding with the next sentence"; it had waited only at the next
## paragraph, the pen at its quickest all the way there - "like 5x speed"). A paragraph's first
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
			var paused := _paused(text)
			var read_on := {}            # a turned line's first word the voice reads on through: the page broke its sentence
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
						if k0 > 0 and not paused.has(k0):
							read_on[k0] = true
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
				elif read_on.has(p):
					# A SENTENCE A PAGE BREAKS IS READ ON TO ITS END: the pen comes back behind the voice, and the voice
					# waits for it at the next sentence (or paragraph) if it must
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
				# ...and a point's linger at its next sentence ([constant POINT_LINGER])
				var rests: Dictionary = e.get("rests", {})
				for k in rests:
					inner[int(k)] = float(inner.get(int(k), 0.0)) + float(rests[k])
				var resting := 0.0
				for k in inner:
					resting += float(inner[k])
				tv += float(n) * READ_WORD + resting
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


## THE WORDS OF PARAGRAPH [param text] AFTER A MARK THE VOICE MAY PAUSE AT ([constant PAUSE_END]): their spoken
## indices - where a page turned is waited for ([method _voice_text]).
static func _paused(text: String) -> Dictionary:
	var out := {}
	var after := false
	for w in _written(text):
		var k := int((w as Dictionary)["spoken"])
		if k < 0:
			after = after or _rx(PAUSE_END).search(String(w["text"])) != null
			continue
		if after:
			out[k] = true
		after = _rx(PAUSE_END).search(String(w["text"])) != null
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


## A color mark's ink as the letter keeps it: "" the desk's own ("default", or nothing), else its name lower-cased
## ([NotebookLayout.ink_color] reads it).
static func ink_of(arg: String) -> String:
	var k := arg.strip_edges().to_lower()
	return "" if k in ["", "default"] else k


## THE PENS [param body] WRITES WITH, scanned before anything is written: the desk's own first, then each ink its
## color marks name, in the order they first do - every one lying by the pad from the start ([LetterMedium]).
static func pens_of(body: String) -> PackedStringArray:
	var out := PackedStringArray([""])
	for m in _rx(COLOR).search_all(Manuscript.strip_frontmatter(body)):
		var k := ink_of(m.get_string(1))
		if not out.has(k):
			out.append(k)
	return out


## The ink in force after [param text], begun in [param ink]: its last color mark's, else [param ink].
static func _ink_after(text: String, ink: String) -> String:
	for m in _rx(COLOR).search_all(text):
		ink = ink_of(m.get_string(1))
	return ink


## [param text] (a written paragraph) begun in [param ink], with each `<!-- struck: words -->` made its words and
## each color mark read: `{text, cuts, first, last}` - a cut `{at, struck, ink}` where the writer stops (the written
## word after it, [method _written]'s count; how many words before it were struck; the ink after it), `first` the ink
## of its first word, `last` the ink it ends in. A color mark straight after a struck run is that run's cut: the
## writer strikes with the pen in hand, then changes it. One before any word is the paragraph's own; one after the
## last is left for whatever is written next.
static func _marked(text: String, ink: String) -> Dictionary:
	var out := ""
	var at := 0
	var cuts: Array = []
	var first := ink
	var cur := ink
	for m in _rx(STRUCK + "|" + COLOR + "|" + UNSAID).search_all(text):
		out += text.substr(at, m.get_start() - at)
		at = m.get_end()
		var before := _written(out).size()
		if m.get_start(3) >= 0:
			var unsaid := m.get_string(3).strip_edges()
			if not unsaid.is_empty():
				out += UNSAID_OPEN + unsaid + UNSAID_CLOSE
			continue
		if m.get_start(1) >= 0:
			var words := m.get_string(1).strip_edges()
			if words.is_empty():
				continue
			out += words
			var after := _written(out).size()
			if after > before:
				cuts.append({"at": after, "struck": after - before, "ink": cur})
			continue
		cur = ink_of(m.get_string(2))
		# inside a word: the word split there, its pieces written with no space between
		if not out.is_empty() and not out[out.length() - 1] in [" ", "\t", "\n"] and at < text.length() \
				and not text[at] in [" ", "\t", "\n"]:
			out += GLUE
		if before == 0:
			first = cur
		elif not cuts.is_empty() and int((cuts.back() as Dictionary)["at"]) == before:
			cuts.back()["ink"] = cur
		else:
			cuts.append({"at": before, "struck": 0, "ink": cur})
	out += text.substr(at)
	var n := _written(out).size()
	while not cuts.is_empty() and int((cuts.back() as Dictionary)["at"]) >= n and int(cuts.back()["struck"]) == 0:
		cuts.pop_back()
	return {"text": out, "cuts": cuts, "first": first, "last": cur}


## A PART OF A WRITTEN PARAGRAPH, to the voice ([method parse]: the parts between where the writer stops): [param part]
## of its text, its first word said [param base], its lines [param lines] - said as a paragraph is, or with nothing in
## it to say (a stop in another ink, words written and never said) the pen's alone, the voice resting while its lines
## are written as for an unspoken line, the rests either side of it one.
static func _voice_part(voice: Array, actions: Array, part: String, base: int, lines: Array) -> void:
	var said := _voiced(part)
	if not _words(said).is_empty() or said.contains("<!--"):
		voice.append({"para": said, "base": base, "lines": lines})
		return
	var w := 0.0
	for li in lines:
		w += float((actions[int(li)] as Dictionary).get("write", 0.0))
	if w > 0.0:
		voice.append({"hold": LEAD + w, "act": int(lines[0]), "pen": LEAD + w, "sync": true})


## THE PEN IN HAND for ink [param want] ([param pens]' index): [param held] as it is, or the pen there is to change
## to - a `swap` action ([constant SWAP]) and the voice's rest for it put in, after spoken word [param after]. The
## first pen asked for is the one picked up at the start, with no swap. Returns the pen held after.
static func _hold_pen(actions: Array, voice: Array, held: int, want: int, after: int) -> int:
	if held < 0 or held == want:
		return want
	voice.append({"hold": SWAP, "act": actions.size(), "pen": SWAP, "sync": true})
	actions.append({"kind": "swap", "id": "", "pen": want, "from": held, "write": SWAP, "dur": SWAP, "after": after,
		"span": 0})
	return want


## THE LINES OF A PARAGRAPH: [param text] cut into lines as the page's width allows ([constant LINE_W]),
## each a `pad-text` action with the [param hand]'s strokes - laid on the page by [method lay_out], the
## first marked `para` (a rule is left empty above it). [param base] is the paragraph's first spoken word,
## [param n] the letter's line count so far (each line's hand is salted by its place), [param page_break]
## whether its first line starts a page.
##
## AT A CUT ([param cuts], [method _marked]) the line ends - with the struck words, if it struck any - marked `cut`, the cut's
## index - and the next goes on beside them on the same rule (`cont`, `cont_x` px along it), unless its first
## word will not fit there; [param struck] is handed, for each line a struck run crosses, `{cut, line, x0, x1}`
## (px along that line, its local index).
static func _lay_para(text: String, base: int, seed: int, n: int, page_break: bool, hand: String,
		cuts: Array = [], struck: Array = []) -> Array:
	var out: Array = []
	var cur: Array = []
	var x := 0.0
	var from_x := 0.0                # where the line being built begins, along its rule
	var sp := LetterHand.space(hand) * DeskScript.PX_PER_PT
	var ends := {}                   # a written word's index after a struck run -> the cut's index
	for c in cuts.size():
		ends[int((cuts[c] as Dictionary)["at"])] = c
	var placed: Array = []           # every word laid: [local line, x0, x1]
	var said := 0                    # the spoken words laid before the line being built
	var ws := _written(text)
	for wi in ws.size():
		var w: Dictionary = ws[wi]
		var adv := LetterHand.advance(String(w["text"]), hand) * DeskScript.PX_PER_PT
		# a piece of a word split by a change of ink sits against the piece before it
		if bool(w.get("glued", false)) and x > 0.0:
			x -= sp
			if cur.is_empty():
				from_x = x
		if x + adv > LINE_W and (not cur.is_empty() or from_x > 0.0):
			if not cur.is_empty():
				out.append(_line_of(cur, base, seed, n + out.size(), hand, from_x, -1, said))
				said += _said_in(cur)
			cur = []
			x = 0.0
			from_x = 0.0
		cur.append(w)
		placed.append([out.size(), x - from_x, x - from_x + adv])
		x += adv + sp
		if ends.has(wi + 1):
			var c := int(ends[wi + 1])
			# the struck run, crossed out on each line it lies on
			var runs := {}
			for k in range(wi + 1 - int((cuts[c] as Dictionary)["struck"]), wi + 1):
				var pl: Array = placed[k]
				var r: Array = runs.get(int(pl[0]), [float(pl[1]), float(pl[2])])
				runs[int(pl[0])] = [minf(float(r[0]), float(pl[1])), maxf(float(r[1]), float(pl[2]))]
			for li in runs:
				struck.append({"cut": c, "line": int(li), "x0": float(runs[li][0]), "x1": float(runs[li][1])})
			out.append(_line_of(cur, base, seed, n + out.size(), hand, from_x, c, said))
			said += _said_in(cur)
			cur = []
			from_x = x
	if not cur.is_empty():
		out.append(_line_of(cur, base, seed, n + out.size(), hand, from_x, -1, said))
	if not out.is_empty():
		(out[0] as Dictionary)["page_break"] = page_break
		(out[0] as Dictionary)["para"] = true
	return out


## A line of [method _lay_para]'s: [method _line_action], going on along its rule from [param from_x] px (`cont`),
## and ending a struck run [param cut] (`cut`; -1 none) - one with no word in it said (a stop written in another
## ink) after the [param said] words said before it in its paragraph.
static func _line_of(words: Array, base: int, seed: int, n: int, hand: String, from_x: float, cut: int,
		said := 0) -> Dictionary:
	var act := _line_action(words, base, seed, n, hand)
	if int(act["span"]) == 0:
		act["after"] = base + said
	if from_x > 0.0:
		act["cont"] = true
		act["cont_x"] = from_x
	if cut >= 0:
		act["cut"] = cut
	return act


## How many of [param words] ([method _written]'s) are said.
static func _said_in(words: Array) -> int:
	var k := 0
	for w in words:
		if int((w as Dictionary)["spoken"]) >= 0:
			k += 1
	return k


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
				var x := DeskScript.TEXT_X
				if bool(act.get("cont", false)) and started and under_text:
					# BESIDE THE WORDS STRUCK: on the same rule, from where they end ([method _lay_para])
					base = y
					x += float(act.get("cont_x", 0.0))
				elif started and (bool(act.get("page_break", false)) or base + LetterHand.descent_px(hand) > foot):
					page += 1
					act["turn"] = true
					base = FIRST_LINE
				act["page"] = page
				act["at"] = Vector2(x, base)
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
				# the lines kept with it: the first lands up to a rule and a half under it past the rule left empty, each next a rule on
				var keep := int(act.get("keep", 0))
				var kept := (float(keep) + 1.0 + UNDER_SKETCH) * DeskScript.RULE + LetterHand.descent_px(hand) if keep > 0 else 0.0
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
				bottom = top + (h + d) * k + DeskScript.RULE * (0.25 + UNDER_SKETCH)
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
