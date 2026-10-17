extends RefCounted
class_name DeskScript

## DeskScript - a lesson as the voice reads it and the desk performs it.
##
## The lesson is the teacher's words, and a few own-line marks for what the pen does:
##
##     <!-- pad: \sum_{k=1}^{n} (2k-1) = n^2 -->     write a formula on the pad (TeX math; several
##                                                   lines inside \begin{aligned} ... \end{aligned})
##     <!-- pad-text: Suppose $p$ is prime. -->     write a line of prose, math inside it in $...$
##     <!-- strike -->                              cross out the last thing written: a dead end
##     <!-- draw: <svg viewBox="0 0 360 120"> ... </svg> -->
##                                                   draw a figure: SVG, over as many lines as it
##                                                   takes (hosts/math/figure.py says what it may hold)
##     <!-- pad #name: ... -->, <!-- draw #name: ... -->
##                                                   the same, NAMED, so the pen can point back at it
##     ... the <!-- point: name --> hypotenuse ...    INSIDE SPEECH: at that word the pen points at the
##                                                   thing called name - a mark's #name, a drawing's
##                                                   part (its SVG `id`) or a formula's (\pin{name}{...})
##
## Everything else is speech. The voice's own marks (a delivery, a hesitation, a speaker) pass to
## the voice; any other comment is a note and is not read.
##
## THE WRITING IS SAID AS IT IS WRITTEN (the user, 2026-10-16: "It is very hard to watch text being
## written, while the voice is speaking about something else; a person cannot pay attention to both
## ... we need to narrate the text being written, as it is being written"). The paragraph on the line
## right after a pen's mark is its DICTATION - the formula read aloud, "the sum of two k minus one, for k
## from one to n, equals n squared" - and the pen writes during exactly those words, keeping pace with them
## word by word ([DeskMedium]). The voice rests before a dictation only for the pen to come down (and
## for the page to turn). Where the writing would trail the words ([method tail_for]) - a line of prose
## takes a hand three or four times as long to write as to say - the dictation goes PHRASE BY PHRASE
## ([method paced]): the voice says a phrase, rests while the pen writes it, and goes on, as a person
## reading out what they write on a board does - never all the words and then a long silence. A PHRASE
## ENDS AT PUNCTUATION, and only there (the user, 2026-10-16: "A point is named by two numbers" had
## "like 5 seconds of silence between 'two' and 'numbers' ... the flow completely broken by the
## interrupted sentence" - a rest once came after any six words): words with no mark between them are
## said together, and what the pen still owes waits for the next mark or the dictation's end.
##
## THE PAGES ARE FILLED (the user, the same day: "It would make more sense to use all of the available
## space on a page, and then to turn the page if we need more space"): there is no mark for a new
## page. [method lay_out] puts every formula on the next rules of the page and turns the page only when
## one would run off its foot - and that turn is a rest the voice takes, so the parse lays the pad out.
##
## ONE WALK, TWO READERS, as [CardReading] and [TabletScript] have it: [method parse] produces the
## spoken words the desk follows the voice by, the pen's actions anchored to them, and the text the
## voice reads ([member speakable]) with its rests (`<!-- action-hold: S -->`). They come from the same
## numbers, so they cannot disagree.
##
## THE VOICE IS NEVER HANDED NOTATION ([method audit]): the pen writes TeX in a mark, the voice says
## math in words. A lesson whose speech carries `$`, `\`, `^`, `_` or braces is refused at its step.
##
## A DRAWING IS WRITTEN LIKE A FORMULA (the user, 2026-10-16: "it might be useful if it could draw
## something, to support the idea ... today, the model just writes a title, then sits there
## explaining"): `draw` is a pen's mark like `pad`, its SVG laid out by the ink step - its lines and
## curves pen strokes, its labels TeX's - and the line after it is its dictation, said while it is
## drawn. It is centered on the page, half a rule clear of what is above it.
##
## THE PEN POINTS AT WHAT IS SPOKEN OF (the user, 2026-10-16: "the model has gone for minutes just staring
## at a static page, while describing what is on the page, but never POINTING to any of it ... I was not
## able to follow what the model was talking about"): a `point` mark sits in the speech at the word, and
## the pen goes to the named thing as that word is said and stays on it to the sentence's end
## (`span`). It names what the pen points at, never where: [method lay_out] finds the latest thing
## written under that name (`of`, and `part` when it is a piece of it), and the desk reads its place
## from the ink. A lesson that talks long over a still pen ([method still]) or points at a name nothing
## carries ([method unknown_points]) goes back once.
##
## A LETTER IS SAID AS A LETTER: `[a]` in speech is the letter's name, shown as the letter
## ([TextNorm]), and [method bare_letters] sends back a lesson that reads a formula's `a` as a bare
## word - the voice says the article there ("uh"), which is what the user heard (2026-10-16).

## The marks: group 1 the verb, group 2 its name (after `#`), group 3 what follows the colon.
const MARK := "^\\s*<!--\\s*(pad-text|pad|strike|draw)(?:\\s+#([\\w-]+))?\\s*(?::\\s*(.*?))?\\s*-->\\s*$"
## A drawing's mark when it runs over several lines: its first line (group 1 its name, group 2 what
## follows the colon).
const DRAW_OPEN := "^\\s*<!--\\s*draw\\b(?:\\s+#([\\w-]+))?\\s*:?(.*)$"
## A point, inside speech: group 1 the name pointed at.
const POINT := "<!--\\s*point\\s*:\\s*([\\w-]+)\\s*-->"
## The parts a written thing names inside it: a formula's `\pin{name}{...}`, a drawing's `id="name"`.
const PARTS := "\\\\pin\\s*\\{([\\w-]+)\\}|\\bid\\s*=\\s*[\"']([\\w-]+)[\"']"
## The marks that put ink on the page.
const WRITES := ["pad", "pad-text", "draw"]

## The rest before a dictation, for the pen to come down at its line.
const LEAD_HOLD := 0.45
## A page turned before the next formula: the sheet lifts and flips over the pad's binding.
const TURN := 1.6
## How much faster or slower than its own pace the pen may write to keep with the words. Past
## MAX_PACE it lags, and the voice waits for it at punctuation and at the dictation's end
## ([method tail_for], [method paced]). THE PEN KEEPS UP WITH THE VOICE (the user, 2026-10-16: "rather
## than breaking the audio, should we increase the speed of writing ... to track with the audio
## better?"): at 1.8 a line of prose left the voice waiting six seconds at a colon; four times its
## own pace covers nearly every dictation, and the voice is held only for what is left.
const MAX_PACE := 4.0
const MIN_PACE := 0.55
## A spoken word's length, for the rests sized before the voice is heard.
const EST_WORD := 0.33
## A dictation's phrases: it rests only after a word that ends one (`, ; : . ? !`), never with a
## single word left, and never for less than [constant PHRASE_REST] - a shorter share waits for the
## next. A dictation the pen lags by under [constant PACED_FROM] is said straight, the pen catching up
## in the rest after it.
const PHRASE_REST := 0.25
const PACED_FROM := 1.0
## A cross-out: the pen draws a line through the last thing written, deliberately.
const STRIKE := 0.9
## THE PEN IS NEVER STILL FOR LONG: more spoken words than this with the pen neither writing, drawing
## nor pointing (about 45 seconds of the voice) send a lesson back once - the user lost the thread after
## two minutes over a still page.
const STILL_WORDS := 80
## A drawing's drawing time before it is laid out: a guess per element of its SVG.
const EST_PER_ELEMENT := 0.9
## A formula's writing time before it is typeset: a guess from its TeX's length, close to what the
## ink measures for short formulas (a^2 + b^2 = c^2: 4.3 s written, 4.2 guessed).
const EST_BASE := 1.2
const EST_PER_CHAR := 0.2

## THE PAGE, in its canvas's pixels (an 8.5 x 11 sheet), and how the pen fills it: TeX points to
## pixels (12 pt type about one rule tall), the rules, the margin, and room at the foot.
const PW := 1100.0
const PH := 1424.0
const PX_PER_PT := 3.1
const RULE := 46.0
const FIRST_RULE := 196.0
const TEXT_X := 150.0
const MATH_X := 196.0
const RIGHT := 50.0
const FOOT := 90.0
## A drawing before the ink has laid it out: the column it spans (TeX points; figure.py's), and the
## tallest it is drawn.
const FIGURE_W := 270.0
const FIGURE_H := 200.0

## Characters that are notation, never words: the voice must not be handed them.
const NOTATION := ["$", "\\", "^", "_", "{", "}"]
## The environments TeX sets only outside math mode: a pad formula that is one is set as a display.
static var DISPLAY := RegEx.create_from_string("^\\s*\\\\begin\\{(align|gather|multline|flalign|alignat)\\*?\\}")


static func _rx(pattern: String) -> RegEx:
	var r := RegEx.new()
	r.compile(pattern)
	return r


## Is [param body] a lesson for the desk (does it carry a pen's mark)?
static func is_lesson(body: String) -> bool:
	return _rx("<!--\\s*(?:pad-text|pad|strike|draw)\\b").search(body) != null


## The item a pad mark writes, as the ink step typesets it and the desk draws it: `{id, tex, mode}`.
## The id is a hash of what is written, so the same formula is the same item wherever it appears.
static func item(kind: String, tex: String) -> Dictionary:
	var mode := "text"
	if kind == "draw":
		mode = "figure"
	elif kind == "pad":
		# MATH, unless it is a display environment of its own (align*, gather*), which TeX sets only
		# outside math: `aligned` - what the teacher is told to use - lives inside math, and set as a
		# display it was refused ("\\begin{aligned} allowed only in math mode", the first real episode)
		mode = "display" if DISPLAY.search(tex) != null else "math"
	return {"id": "p" + (kind + "|" + tex).sha256_text().substr(0, 12), "tex": tex, "mode": mode}


## Every item the pen writes in [param body], once each, in order: what the ink step typesets.
static func items(body: String) -> Array:
	var seen := {}
	var out: Array = []
	for b in _blocks(body):
		var blk: Dictionary = b
		if String(blk["kind"]) in WRITES and not String(blk["arg"]).is_empty():
			var it := item(String(blk["kind"]), String(blk["arg"]))
			if not seen.has(String(it["id"])):
				seen[String(it["id"])] = true
				out.append(it)
	return out


## How long a formula takes to write before the ink has measured it - or a drawing, by its elements.
static func estimate(tex: String) -> float:
	if tex.strip_edges().begins_with("<svg"):
		return EST_BASE + EST_PER_ELEMENT * float(maxi(1, tex.count("<") - tex.count("</") - 1))
	return EST_BASE + EST_PER_CHAR * float(tex.length())


## A drawing's size before the ink has laid it out (TeX points, as a typeset item has it): its
## viewBox's shape across the column, no taller than [constant FIGURE_H].
static func figure_size(svg: String) -> Dictionary:
	var m := _rx("viewBox\\s*=\\s*[\"']([^\"']*)[\"']").search(svg)
	var vw := 360.0
	var vh := 160.0
	if m != null:
		var bits := m.get_string(1).replace(",", " ").split(" ", false)
		if bits.size() == 4 and float(bits[2]) > 0.0 and float(bits[3]) > 0.0:
			vw = float(bits[2])
			vh = float(bits[3])
	var s := minf(minf(FIGURE_W / 360.0, FIGURE_W / vw), FIGURE_H / vh)
	return {"w": vw * s, "h": vh * s, "d": 0.0}


## THE REST AFTER A DICTATION of [param span] words for writing that takes [param write] seconds: what
## the pen, at its fastest, would still need after the words are said - none when it keeps up.
static func tail_for(write: float, span: int) -> float:
	var t := write / MAX_PACE - float(span) * EST_WORD
	return t if t > 0.05 else 0.0


## [param body] as the voice reads it (see the class note); any other text untouched.
static func speakable(body: String, lengths: Dictionary = {}, sizes: Dictionary = {}) -> String:
	if not is_lesson(body):
		return body
	return String(parse(body, lengths, sizes)["speakable"])


## THE WALK. [param lengths]: item id -> seconds its writing takes (the ink's, else estimated);
## [param sizes]: item id -> the typeset item (`w`, `h`, `d` in TeX points), for the layout - without
## one an item is laid out as a line of type. Returns:
##   actions   - [{kind, id, tex, mode, after, span, write, dur, tail, page, turn, at, k, w, h, d, of, i}]:
##               `after` the spoken words before it (a pad item's dictation starts there), `span` its
##               dictation's words, `write` how long the pen takes, `dur` the rest before it, `tail`
##               the rest after its dictation, `page`/`turn` where it is written and whether the page
##               turns for it, `at` its baseline's start on the page, `of` what a strike crosses out
##               or a point points at (`target` the name it was given, `part` the piece of it, `span`
##               the words it holds for), `name` a written thing's own
##   spoken    - PackedStringArray: every spoken word, normalized ([method TabletScript.norm])
##   speakable - the text the voice reads
##   said      - the speech alone, marks and notes out: what [method audit] reads
static func parse(body: String, lengths: Dictionary = {}, sizes: Dictionary = {}) -> Dictionary:
	var blocks := _blocks(body)
	var point := _rx(POINT)
	# THE ACTIONS, and how many words each pad item's dictation has (the paragraph after its mark); a
	# point in speech is an action in its paragraph, anchored when the voice is walked below
	var actions: Array = []
	for bi in blocks.size():
		var blk: Dictionary = blocks[bi]
		var kind := String(blk["kind"])
		if kind == "para":
			if not bool(blk.get("joined", false)):
				for m in point.search_all(String(blk["text"])):
					actions.append({"kind": "point", "target": m.get_string(1), "id": "", "span": 0,
						"write": 0.0, "dur": 0.0, "tail": 0.0, "block": bi, "mark": m.get_start(),
						"mark_end": m.get_end()})
			continue
		var act := {"kind": kind, "id": "", "tex": "", "mode": "", "span": 0, "write": STRIKE,
			"dur": STRIKE, "tail": 0.0, "block": bi, "name": String(blk.get("name", ""))}
		if kind in WRITES:
			if String(blk["arg"]).is_empty():
				continue
			act.merge(item(kind, String(blk["arg"])), true)
			act["write"] = float(lengths.get(String(act["id"]), estimate(String(blk["arg"]))))
			if bi + 1 < blocks.size() and bool((blocks[bi + 1] as Dictionary).get("joined", false)):
				act["span"] = _words(String((blocks[bi + 1] as Dictionary)["text"])).size()
			# a formula with no dictation is written in silence: the voice waits it out
			act["dur"] = LEAD_HOLD if int(act["span"]) > 0 else LEAD_HOLD + float(act["write"])
			act["tail"] = tail_for(float(act["write"]), int(act["span"])) if int(act["span"]) > 0 else 0.0
		actions.append(act)
	actions = lay_out(actions, sizes)
	# THE VOICE: each paragraph in order, ONE rest between two - a dictation's tail, the actions'
	# leads and a page's turn summed
	var by_block := {}
	var points_in := {}
	for a in actions:
		if String((a as Dictionary)["kind"]) == "point":
			if not points_in.has(int(a["block"])):
				points_in[int(a["block"])] = []
			(points_in[int(a["block"])] as Array).append(a)
		else:
			by_block[int((a as Dictionary)["block"])] = a
	var spoken := PackedStringArray()
	var speak := PackedStringArray()
	var said := PackedStringArray()
	var hold := 0.0
	var dictating: Dictionary = {}
	for bi in blocks.size():
		var blk: Dictionary = blocks[bi]
		if String(blk["kind"]) != "para":
			if by_block.has(bi):
				var act: Dictionary = by_block[bi]
				act["after"] = spoken.size()
				hold += float(act["dur"]) + (TURN if bool(act.get("turn", false)) else 0.0)
				dictating = act if int(act["span"]) > 0 else {}
			continue
		if hold > 0.0:
			speak.append("<!-- action-hold: %s -->" % String.num(hold, 2))
			hold = 0.0
		# A POINT is at the word after its mark, and holds to its sentence's end
		for pa in points_in.get(bi, []):
			var text := String(blk["text"])
			var rest := text.substr(int(pa["mark_end"]))
			var stop := _rx("[.?!](?=\\s|$)").search(rest)
			pa["after"] = spoken.size() + _words(text.substr(0, int(pa["mark"]))).size()
			pa["span"] = maxi(1, _words(rest.substr(0, stop.get_end()) if stop != null else rest).size())
		if not dictating.is_empty():
			var p := paced(CardReading._voice_marks(String(blk["text"]).strip_edges()),
				float(dictating["write"]), int(dictating["span"]))
			_flush(String(blk["text"]), spoken, speak, said, String(p["text"]))
			hold += float(p["rest"])
			dictating = {}
		else:
			# a point's mark goes, with the space before it, so the voice's text reads as said
			_flush(_rx(" ?" + POINT).sub(String(blk["text"]), "", true), spoken, speak, said)
	if hold > 0.0:
		speak.append("<!-- action-hold: %s -->" % String.num(hold, 2))
	return {"actions": actions, "spoken": spoken, "speakable": "\n\n".join(speak),
		"said": "\n\n".join(said)}


## THE LESSON IN BLOCKS: each own-line mark `{kind, name, arg}`, and each paragraph `{kind: "para",
## text, joined}` - lines up to a blank line or a mark, `joined` when it starts on the line right after a
## mark (a dictation; a blank line between makes it speech of its own).
static func _blocks(body: String) -> Array:
	var src := Manuscript.strip_frontmatter(body)
	var mark := _rx(MARK)
	var opens := _rx(DRAW_OPEN)
	var out: Array = []
	var lines: Array = []
	var joined := false
	var follows_mark := false
	var drawing := PackedStringArray()
	var drawing_name := ""
	var in_drawing := false
	for line in (src + "\n").split("\n"):
		# A DRAWING OVER SEVERAL LINES: its mark is everything up to the line that closes the comment
		if in_drawing:
			var close := String(line).find("-->")
			if close < 0:
				drawing.append(line)
				continue
			drawing.append(String(line).substr(0, close))
			in_drawing = false
			line = "<!-- draw%s: %s -->" % [(" #" + drawing_name) if not drawing_name.is_empty() else "",
				" ".join(drawing).strip_edges()]
		else:
			var o := opens.search(line)
			if o != null and not String(line).contains("-->"):
				in_drawing = true
				drawing_name = o.get_string(1)
				drawing = PackedStringArray([o.get_string(2)])
				continue
		var m := mark.search(line)
		if m == null and not String(line).strip_edges().is_empty():
			if lines.is_empty():
				joined = follows_mark
			lines.append(line)
			continue
		if not lines.is_empty():
			out.append({"kind": "para", "text": "\n".join(PackedStringArray(lines)), "joined": joined})
			lines = []
		follows_mark = m != null
		if m != null:
			out.append({"kind": m.get_string(1), "name": m.get_string(2), "arg": m.get_string(3).strip_edges()})
	return out


## A paragraph's spoken words, normalized - what the voice says of it.
static func _words(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var plain := Manuscript._rx(Manuscript.COMMENT).sub(text, "", true)
	for w in plain.split(" ", false):
		for piece in String(w).split("\n", false):
			var n := TabletScript.norm(piece)
			if not n.is_empty():
				out.append(n)
	return out


## A DICTATION PACED TO THE PEN: [param voiced] (its words as the voice reads them) for writing that
## takes [param write] seconds over [param span] words, with the wait the pen needs ([method tail_for])
## shared out over its words and rested at the end of each phrase. Returns `{text, rest}`: the text
## with its rests in it, and the last phrase's share - the rest after the dictation, which the parse
## sums with the next one. A dictation the pen keeps up with comes back as it was.
static func paced(voiced: String, write: float, span: int) -> Dictionary:
	var tail := tail_for(write, span)
	if tail < PACED_FROM or span <= 0:
		return {"text": voiced, "rest": tail}
	var per := tail / float(span)
	var notes := _rx(Manuscript.COMMENT).search_all(voiced)
	var out := ""
	var at := 0
	var n := 0
	var owed := 0.0
	for m in _rx("\\S+").search_all(voiced):
		var inside := false
		for c in notes:
			if m.get_start() < (c as RegExMatch).get_end() and m.get_end() > (c as RegExMatch).get_start():
				inside = true
		var piece := m.get_string()
		if inside or TabletScript.norm(piece).is_empty():
			continue
		n += 1
		owed += per
		if n >= span:
			break
		var ends := piece.rstrip("\"')*_").right(1) in [",", ";", ":", ".", "?", "!"]
		if ends and owed >= PHRASE_REST and span - n >= 2:
			out += voiced.substr(at, m.get_end() - at) + " <!-- action-hold: %s -->" % String.num(owed, 2)
			at = m.get_end()
			owed = 0.0
	out += voiced.substr(at)
	return {"text": out, "rest": tail - (per * float(n) - owed) if n < span else owed}


## A paragraph into the spoken list, the voice's text and the speech ([param voiced]: its words as the
## voice reads them, when the caller has them already).
static func _flush(text: String, spoken: PackedStringArray, speak: PackedStringArray,
		said: PackedStringArray, voiced := "") -> void:
	var t := text.strip_edges()
	if voiced.is_empty():
		voiced = CardReading._voice_marks(t)
	var plain := Manuscript._rx(Manuscript.COMMENT).sub(t, "", true).strip_edges()
	spoken.append_array(_words(t))
	if not voiced.is_empty():
		speak.append(voiced)
	if not plain.is_empty():
		said.append(plain)


## WHERE EACH ACTION WRITES: its page and its place on it ([constant PX_PER_PT] scaled, baselines on
## the rules), the page turned only where the next formula would run off its foot - `turn` on the one
## that starts a new page. A strike crosses out the last thing written (`of`); a point, the latest
## thing written under its name (`of`, -1 for none; `part` when the name is a piece of it). Pure: a
## function of the actions and the typeset items.
static func lay_out(actions: Array, sizes: Dictionary) -> Array:
	var out: Array = []
	var page := 0
	var cursor := FIRST_RULE - RULE
	var last_written := -1
	var named := {}         # a name -> {of, part}: the latest thing written under it
	for a in actions:
		var act: Dictionary = (a as Dictionary).duplicate()
		act["i"] = out.size()
		act["page"] = page
		act["turn"] = false
		match String(act["kind"]):
			"strike":
				act["of"] = last_written
			"point":
				var got: Dictionary = named.get(String(act.get("target", "")), {"of": -1, "part": ""})
				act["of"] = int(got["of"])
				act["part"] = String(got["part"])
			"pad", "pad-text", "draw":
				var drawn := String(act["kind"]) == "draw"
				var r: Dictionary = sizes.get(String(act["id"]), {})
				if r.is_empty() and drawn:
					r = figure_size(String(act.get("tex", "")))
				var w := float(r.get("w", 6.0 * String(act.get("tex", "")).length())) * PX_PER_PT
				var h := float(r.get("h", 8.0)) * PX_PER_PT
				var d := float(r.get("d", 2.0)) * PX_PER_PT
				var x := MATH_X if String(act["kind"]) == "pad" else TEXT_X
				var room := PW - RIGHT - x
				var k := minf(1.0, room / w) if w > 0.0 else 1.0
				# a drawing: centered in the column, half a rule clear of what is above it
				var clear := RULE * 0.5 if drawn else 0.0
				if drawn:
					x = TEXT_X + maxf(0.0, (room - w * k) * 0.5)
				var base := _snap_rule(cursor + 10.0 + clear + h * k)
				if base + d * k > PH - FOOT and cursor > FIRST_RULE:
					page += 1
					act["turn"] = true
					base = _snap_rule(FIRST_RULE - RULE + 10.0 + h * k)
				act["page"] = page
				act["at"] = Vector2(x, base)
				act["k"] = k
				act["w"] = w * k
				act["h"] = h * k
				act["d"] = d * k
				cursor = base + d * k + clear
				last_written = out.size()
				if not String(act.get("name", "")).is_empty():
					named[String(act["name"])] = {"of": out.size(), "part": ""}
				for part in parts_of(String(act.get("tex", ""))):
					named[part] = {"of": out.size(), "part": part}
		out.append(act)
	return out


## The first rule at or below [param y].
static func _snap_rule(y: float) -> float:
	var n := ceilf((y - FIRST_RULE) / RULE)
	return FIRST_RULE + maxf(n, 0.0) * RULE


## A STEADY VOICE READING [param parsed] (what [method parse] returned): every spoken word
## [param word] seconds long, a breath of [param pause] after each paragraph, and every rest the
## lesson asks for - the words as a take's timing hands them to the desk (`text`, `t0`, `t1`), from
## [param lead] on. For a gate or a probe, which has no voice to time.
static func rehearsal(parsed: Dictionary, word := 0.32, pause := 0.35, lead := 1.0) -> Array:
	var spoken: PackedStringArray = parsed["spoken"]
	var token := _rx("<!--\\s*action-hold\\s*:\\s*([0-9.]+)\\s*-->|<!--.*?-->|\\S+")
	var out: Array = []
	var t := lead
	for chunk in String(parsed["speakable"]).split("\n\n"):
		var words := false
		for m in token.search_all(String(chunk)):
			if not m.get_string(1).is_empty():
				t += float(m.get_string(1))
			elif not m.get_string().begins_with("<!--") and not TabletScript.norm(m.get_string()).is_empty():
				if out.size() < spoken.size():
					out.append({"text": spoken[out.size()], "t0": t, "t1": t + word * 0.9, "sentence": 0})
				t += word
				words = true
		if words:
			t += pause
	return out


## WHAT THE PEN WOULD WRITE IN SILENCE: each pad line in [param body] with no dictation on the line
## after it - the voice waits while it is written, so a lesson with any goes back once.
static func undictated(body: String) -> PackedStringArray:
	var out := PackedStringArray()
	var blocks := _blocks(body)
	for bi in blocks.size():
		var blk: Dictionary = blocks[bi]
		if not (String(blk["kind"]) in WRITES) or String(blk["arg"]).is_empty():
			continue
		if bi + 1 >= blocks.size() or not bool((blocks[bi + 1] as Dictionary).get("joined", false)):
			out.append(String(blk["arg"]).substr(0, 120))
	return out


## WHERE THE VOICE WOULD SAY THE LETTER a AS THE WORD "a": each paragraph that reads aloud a formula
## (or a drawing's label) with the letter a in its math and says a bare "a" with no `[a]` in it; and
## each line of speech with a bare "a" right before a stop or a comma, which an article never is
## ("with a, b irrational"). The voice reads the article "uh" there; `[a]` is the letter's name.
static func bare_letters(body: String) -> PackedStringArray:
	var out := PackedStringArray()
	var blocks := _blocks(body)
	var math_a := _rx("(?<![A-Za-z\\\\])a(?![A-Za-z])")
	var bare := _rx("(?<![\\[\\w])a(?![\\]\\w'])")
	var before_stop := _rx("(?<![\\[\\w])a\\s*[,.;:?!)]")
	for bi in blocks.size():
		var blk: Dictionary = blocks[bi]
		if String(blk["kind"]) != "para":
			continue
		var text := Manuscript._rx(Manuscript.COMMENT).sub(String(blk["text"]), "", true)
		var flagged := before_stop.search(text) != null
		if not flagged and bool(blk.get("joined", false)) and bi > 0:
			var mk: Dictionary = blocks[bi - 1]
			var m := _math_of(String(mk.get("kind", "")), String(mk.get("arg", "")))
			flagged = math_a.search(m) != null and bare.search(text) != null and not text.contains("[a]")
		if flagged:
			out.append(text.strip_edges().substr(0, 160))
	return out


## The math a pen's mark writes, words and commands out: a formula whole, a line of prose's `$...$`
## and a drawing's labels' - with `\text{...}` and every `\command` taken out, so what is left of
## its letters are the ones a voice reads as letters.
static func _math_of(kind: String, arg: String) -> String:
	var m := ""
	match kind:
		"pad":
			m = arg
		"pad-text", "draw":
			for d in _rx("\\$([^$]*)\\$").search_all(arg):
				m += " " + d.get_string(1)
	m = _rx("\\\\(?:text|mathrm|operatorname|textbf|textit|mbox|pin)\\s*\\{[^}]*\\}").sub(m, " ", true)
	return _rx("\\\\[A-Za-z]+").sub(m, " ", true)


## The names of the parts [param tex] holds: a formula's `\pin{name}{...}`, a drawing's `id="name"`.
static func parts_of(tex: String) -> PackedStringArray:
	var out := PackedStringArray()
	for m in _rx(PARTS).search_all(tex):
		var name := m.get_string(1) if not m.get_string(1).is_empty() else m.get_string(2)
		if not out.has(name):
			out.append(name)
	return out


## WHAT THE PEN WOULD POINT AT THAT IS NOT THERE: each point in [param body] at a name nothing written
## before it carries - a mark's `#name`, a drawing's part, a formula's `\pin`.
static func unknown_points(body: String) -> PackedStringArray:
	var out := PackedStringArray()
	for a in parse(body)["actions"]:
		if String((a as Dictionary)["kind"]) == "point" and int((a as Dictionary)["of"]) < 0 \
				and not out.has(String(a["target"])):
			out.append(String(a["target"]))
	return out


## WHERE THE PEN STANDS STILL TOO LONG: each run of more than [param most] spoken words in [param body]
## while the pen neither writes (a dictation's words), draws nor points (a point's sentence) - the
## run's first words and its length, for the teacher to find it.
static func still(body: String, most := STILL_WORDS) -> PackedStringArray:
	var parsed := parse(body)
	var spoken: PackedStringArray = parsed["spoken"]
	var busy: Array = []
	for a in parsed["actions"]:
		busy.append(Vector2i(int((a as Dictionary).get("after", 0)), int(a["after"]) + int(a.get("span", 0))))
	busy.sort_custom(func(x: Vector2i, y: Vector2i) -> bool: return x.x < y.x)
	busy.append(Vector2i(spoken.size(), spoken.size()))
	var out := PackedStringArray()
	var free := 0
	for b in busy:
		if (b as Vector2i).x - free > most:
			out.append("%d words from \"%s ...\"" % [(b as Vector2i).x - free,
				" ".join(spoken.slice(free, mini(free + 8, spoken.size())))])
		free = maxi(free, (b as Vector2i).y)
	return out


## WHAT THE VOICE WOULD BE HANDED THAT IS NOTATION: each line of speech carrying a character of
## [constant NOTATION], "" when there is none. Math the voice says is words ("n squared"), never TeX.
static func audit(body: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line in String(parse(body)["said"]).split("\n"):
		for c in NOTATION:
			if String(line).contains(c):
				out.append(String(line).strip_edges().substr(0, 120))
				break
	return out
