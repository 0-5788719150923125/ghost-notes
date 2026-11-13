extends RefCounted
class_name DispatchScript

## DispatchScript - a note as the dispatch desk plays it (next/dispatch.md): what the voice reads, the words it says, and
## everything the desk does between and alongside them.
##
## The note is the script, word for word. An ordinary paragraph is said by whoever the last speaker cue names; the first
## name cued is the room's voice (the man at the desk, never seen), every other voice is heard through a phone. The
## desk's marks, each on a line of its own:
##
##     <!-- call: AISLE -->            the phone labeled AISLE lifts out of its row, flips open and is held to the ear:
##                                     dialed and ringing twice in the earpiece before anyone answers; answered at once if
##                                     it was ringing, picked back up if it lay open on the desk. Another in hand is laid
##                                     down open first (on hold).
##     <!-- /call -->, <!-- /call: VAN -->   the phone in hand (or the one named, lying open) snaps shut and goes home.
##     <!-- ring: LIGHTS -->           that phone buzzes and rattles against its neighbors; a call to it straight after
##                                     answers it, and with none it rings out.
##     <!-- text: AISLE | words -->    a chime and a buzz, and the phone comes up out of its row, flips open and is held up
##                                     to be read: the words on its screen, never said or captioned. It goes home after,
##                                     unless it texts again in a moment.
##     <!-- reply -->, <!-- reply: AISLE -->   the room's next words are typed into that phone (the last to text) as they are
##                                     said, a key at a time, under the message, and sent.
##     <!-- ping: a place -->          the target comes to that place on the radar: a ping, the place written beside the
##                                     blip (the first: the radar finds him there). He goes there along a track while the
##                                     voice goes on, the sweep painting him a step further each round, from where a
##                                     `moving` mark says he set off, else over the moments before. A place named again is
##                                     the same spot; what follows a comma in its name is a little off it.
##     <!-- moving -->                 the target sets off from where he is, toward the next ping's place: the radar sounds
##                                     its alarm and the camera turns to it. Straight after a ping he passes through it (a
##                                     place on the way: `driving south`) with no alarm.
##     <!-- sound: jet, ... -->        a sound of [constant DispatchSounds.SOUNDS], named by its key among the words.
##     <!-- static: 5 -->, <!-- static: 5, surf -->   the receiver opens up for that many seconds: Io-B's crackle, or surf.
##     <!-- print -->                  the printer prints what was typed since it last printed (struck blocks aside).
##     <!-- sleep -->                  the terminal's screen goes dark.
##     <!-- off: tv -->                a screen goes dark (tv, feed, satellite).
##     <!-- look: radar -->            the camera turns to that thing ([constant DispatchMedium.SPOTS]) until something
##                                     else is active.
##     <!-- lift: mug -->              a thing on the desk is lifted toward the chair, held for a sip and set back down.
##     <!-- switch: BAD -->            the switch box's toggle is thrown to that side.
##     <!-- live: tv -->               that screen shows this desk, live, seen from just behind the empty chair (words
##                                     after a comma say so for a reader: `live: tv, this desk from behind the chair`).
##     <!-- image (feed): words -->    a picture on that screen (feed, satellite, tv) until the next there or `off`.
##     <!-- image (full): words --> ... <!-- /image -->   a picture over the whole screen for the passage, one straight
##                                     after another dissolving into it.
##     <!-- strike -->                 after a typed block: the writer stops to decide, then backspaces it off the screen.
##     <!-- gain: 9 -->                the radar's gain knob is turned to that number (1 to 10; it starts at 3), a click a
##                                     step. Above 3 the scope paints clutter round the target, more the higher it is;
##                                     from 9, one more on the desk itself, the chair's.
##     <!-- bell -->                   the terminal's bell, one short beep as the block after it goes up.
##     <!-- lamp: off -->, <!-- lamp: on -->   the gooseneck lamp is switched off (or on), with a click.
##
## And the terminal's text, as fenced blocks:
##
##     ```type ... ```                 typed on the terminal while the voice says it, word for word, each word's keys as
##                                     it is said; a hesitation inside stops the keys with the voice.
##     ```screen ... ```               put up on the terminal, replacing what it showed, drawn down the glass a line at a
##                                     time; never said.
##     ```terminal ... ```             a silent session, the voice waiting: a line opening `>` is a command, typed at the
##                                     prompt a key at a time and entered; the lines after it are what the terminal
##                                     answers, printed a line at a time. Asleep, it wakes to a bare prompt first.
##
## A typed block and a session are added under what the terminal shows; a shown one replaces it.
##
## Redacted words, inside a shown block or a session: `NAME ........ <!-- redact: DOE, JANE -->`. The words are put up
## as any others and hidden over the camera's finished picture ([DispatchCensor]), never replaced by a word. A redacted
## character travels as itself moved into a private plane of Unicode ([constant REDACT_BASE]), so typing, wrapping,
## scrolling and a strike count it as the one character it is; the screens take it back out ([method unredacted]). A
## typed block is said, and the voice cannot say what is hidden: there the mark is warned of and its words left out.
##
## The voice opens on [constant OPENING] seconds of the desk at rest, the camera home, before any action or word. What
## moves on the radar moves under the voice: a walk is the words between a `moving` and a `ping`, and the camera turns
## to the radar at its sounds (the alarm as he sets off, the ping as he arrives). `<!-- act: ... -->` is plain words for
## a puppeteer that is not built here, and stays a note; every other comment is a note too.
##
## The desk acts in the rests the voice leaves for it: every action the voice waits for writes a rest into what it reads
## (`<!-- action-hold: S -->`), and the medium places each action in its rest ([method DispatchMedium._place]), from the
## next word back by what is written after it in the same silence.
##
## A voice through a phone is heard through one ([constant Manuscript.HEARD]): a turn of a voice whose phone is in hand
## is marked `phone`; one whose phone lies open on the desk, `desk`; a voice with no phone of its own open, `far`. Worked
## out here from the calls.

## Own-line desk marks: group 1 the verb, 2 its argument.
const MARK := "^\\s*<!--\\s*(call|/\\s*call|ring|text|reply|ping|moving|sound|static|print|sleep|off|look|lift|switch|live|strike|gain|bell|lamp|/\\s*image)\\s*(?::\\s*([\\s\\S]*?))?\\s*-->\\s*$"
## A picture: group 1 where (full, feed, satellite, tv; none is full), 2 its words.
const IMAGE := "^\\s*<!--\\s*image\\s*(?:\\(\\s*([a-z]+)\\s*\\))?\\s*:\\s*([\\s\\S]*?)\\s*-->\\s*$"
const FENCE_OPEN := "^\\s*```\\s*(type|screen|terminal)\\s*$"
const FENCE_CLOSE := "^\\s*```\\s*$"
## Words redacted inside a shown block or a session: group 1 the words.
const REDACT := "<!--\\s*redact\\s*:\\s*([\\s\\S]*?)\\s*-->"
## A redacted character is itself moved up by this much (Supplementary Private Use Area-A, U+F0000-U+FFFFD).
const REDACT_BASE := 0xF0000
## Own-line marks the voice reads: a hesitation, a delivery.
const VOICE_LINE := "^\\s*(?:<!--\\s*(?:hesitation|delivery)\\b[\\s\\S]*?-->\\s*)+$"
const HESITATION := Manuscript.HESITATION
const COMMENT := Manuscript.COMMENT
## What makes a note a dispatch script: nothing is rewritten for any other.
const IS_DISPATCH := "(?m)^\\s*(?:<!--\\s*(?:call|ring|ping)\\s*:|```\\s*(?:type|screen|terminal)\\s*$)"

## The screens a picture may be pinned to, each a thing on the desk ([DispatchSet]).
const SCREENS := ["feed", "satellite", "tv"]

## The timing of each action (seconds). `rest` is what the voice waits for it; an action may move on past its rest,
## under the next words (`len`). A phone: out of its row, opened and to the ear; dialed; the two rings in the earpiece,
## each a pair of short rings on a cycle, answered as the second's pair ends; answered at once when it was ringing;
## picked back up off the desk; the one in hand laid down open on the desk first; snapped shut and home.
const LIFT := 1.2
const DIAL := 1.3
## Speed dial, inside the dialing ([constant DIAL]): every phone's one contact is on 1 - held, then Send, and up to the ear.
const SPEED_PRESS := 0.15
const SPEED_HOLD := 0.45
const SEND_AT := 0.72
const TO_EAR := 0.5
const RING_CYCLE := 2.6
const RING_ON := 1.0
const RINGS := 2
const ANSWER := 0.35
const PICK_UP := 1.0
const LAY_DOWN := 1.0
const HANG_UP := 1.3
const HANG_UP_REST := 0.7
## An incoming ring: a buzz this long, then quiet this long, rung this many times before a call answers it, and this
## many when nobody does.
const BUZZ_ON := 0.8
const BUZZ_OFF := 0.6
const BUZZES := 2
const BUZZES_OUT := 4
## A text: its chime and buzz; the phone up out of its row and open, held to be read; long enough to read it (seconds a
## word, and a beat); and back down to its row, unless it texts again within [constant TEXT_AGAIN], when it stays up.
const TEXT_BUZZ := 0.5
const TEXT_CHIME := 0.6
const READ_LIFT := 0.9
const READ_WORD := 0.32
const READ_BEAT := 0.9
const READ_DOWN := 0.9
const TEXT_AGAIN := 9.0
## A reply, typed into the phone in hand as it is said: a beat before its first key, and its sending after its last.
const REPLY_LEAD := 0.4
const REPLY_SEND := 0.7
## The radar's ping: the voice's rest, and its ring's length. Its alarm as the target sets off: the voice's rest, and how
## long it sounds.
const PING := 1.2
const PING_LEN := 2.6
const MOVING := 0.7
const MOVING_LEN := 1.6
## The desk at rest, seen whole before anything moves (seconds): the breath the voice opens on, every opening's settle
## ([constant Openings.SETTLE]).
const OPENING := Openings.SETTLE
## Static: a bare mark's seconds.
const STATIC_BARE := 4.0
## The printer: before its first line, a line, the feed after it; and its least and most.
const PRINT_LEAD := 0.5
const PRINT_LINE := 0.42
const PRINT_FEED := 0.8
const PRINT_LEAST := 2.4
const PRINT_MOST := 9.0
## The printer's paper is this many characters across.
const PRINT_COLUMNS := 80
## The terminal's screen: columns and rows (inside what its curved glass and bezel leave seen - the widest shown block is
## 66 characters).
const COLUMNS := 70
const ROWS := 22
## The terminal: before typed words, the camera there and the cursor waiting; a shown screen looked at; the screen saver
## comes on.
const TYPE_LEAD := 1.0
const SCREEN_REST := 1.4
const SLEEP := 1.2
## A typed block is said behind its keys, as a letter is read behind its pen ([constant LetterScript.AHEAD_WORDS]): a
## word is typed while the voice says the one this many before it, so the voice reads what is already on the screen and
## goes on unbroken. The first words are typed at a typist's pace ([constant KEY_EACH]) in the rest before them, each
## after at most this quick a key, never still being typed when it is said. A reply on a phone is typed as it is said,
## its keys this long before each word.
const AHEAD_WORDS := 2
const KEY_QUICK := 0.035
const REPLY_AHEAD := 0.35
## A shown screen is drawn down the glass a line every this many seconds.
const SCREEN_LINE := 0.045
## A session at the terminal (seconds): the bare prompt waiting before the first key (and a sleeping screen waking before
## it); a key, give or take [constant KEY_JITTER] of it, a space a little longer; Enter after the last; the machine
## answering; each line it prints; then the operator reading it before the next command - at least, and a line more. The
## voice waits until the last answer is printed, and goes on as it is read.
const WAKE := 0.6
const PROMPT_WAIT := 0.6
const KEY_EACH := 0.1
const KEY_JITTER := 0.45
const ENTER_AFTER := 0.25
const ANSWER_AFTER := 0.45
const LINE_EACH := 0.06
const READ_LEAST := 0.7
const READ_LINE := 0.18
## What a command is typed after: its line opens with this.
const PROMPT := "> "
## A strike: the writer decides (the letter's), then backspaces at this many characters a second, held to at most.
const DECIDE := 3.0
const DECIDE_MOST := 30.0
const BACKSPACE := 28.0
const BACKSPACE_MOST := 4.0
## The others: a screen going dark, a look, the switch thrown, a picture landing on a screen.
const OFF := 0.5
const LOOK := 1.0
## A thing lifted (the mug drunk from): brought up unhurried, held at the mouth for a sip, and set back down; the voice
## goes on this far into its way down.
const LIFT_UP := 2.0
const LIFT_HOLD := 3.0
const LIFT_DOWN := 1.8
const LIFT_SAID := 0.5
const SWITCH := 1.3
const SWITCH_AT := 0.65
const PICTURE := 1.6
## The letter's pictures over the whole screen: the fade (seconds), every one; the voice rests for the last to clear.
const IMAGE_FADE := 2.5
## The radar's gain knob: its least and most, where it stands when the night begins; the hand reaching it, each step
## turned (a click), and the beat the voice waits after, as the sweep comes round.
const GAIN_LEAST := 1
const GAIN_MOST := 10
const GAIN_REST := 3
const GAIN_REACH := 0.25
const GAIN_STEP := 0.14
const GAIN_BEAT := 0.6
## The terminal's bell: the half beat the voice waits for it.
const BELL := 0.35
## The lamp: the hand reaching its switch (the click), and the voice's rest.
const LAMP_AT := 0.3
const LAMP := 0.8
## A sound with no row of its own: a rest this long, and nothing heard.
const SOUND_BARE := 3.0
## A hesitation that names no length, as the voice's Hesitate dial has it by default ([constant
## ReadingCast.HESITATE_DEFAULT]): what the desk counts it as between two of its own actions.
const HESITATE := 1.5
## A margin the voice's rest has past the action's own time: a breath before the next word.
const REST_PAD := 0.3

static var _re := {}


static func _rx(pattern: String) -> RegEx:
	if not _re.has(pattern):
		var r := RegEx.new()
		r.compile(pattern)
		_re[pattern] = r
	return _re[pattern]


## Does [param body] use the desk's marks at all?
static func is_dispatch(body: String) -> bool:
	return _rx(IS_DISPATCH).search(Manuscript.strip_frontmatter(body)) != null


## [param body] as the voice should read it (see the class note).
static func speakable(body: String) -> String:
	return String(parse(body)["speakable"])


## The pictures of [param body] as the painter is handed them: every image mark pinned to the screen (painted wide;
## a desk's screen shows the middle of it), so the painting is found by its words whatever it was pinned to.
static func pictures_only(body: String) -> String:
	var src := Manuscript.strip_frontmatter(body)
	return _rx("<!--\\s*image\\s*(?:\\(\\s*\\w+\\s*\\))?\\s*:").sub(src, "<!-- image (screen):", true)


## The phones' labels, in order along the rows: the note's `desk:` block's `phones`, else every label its marks name, in
## the order they first do.
static func phones_of(body: String) -> PackedStringArray:
	var out := PackedStringArray()
	var block := FrontMatter.read_block(body, "desk")
	var listed: Variant = (block.get("data", {}) as Dictionary).get("phones", null)
	if listed is Array:
		for v in listed as Array:
			var s := String(v).strip_edges().to_upper()
			if not s.is_empty() and not out.has(s):
				out.append(s)
	if out.is_empty():
		for m in _rx("<!--\\s*(?:call|ring|text|/\\s*call)\\s*:\\s*([^|>]*?)\\s*(?:\\|[^>]*)?-->").search_all(body):
			var s := m.get_string(1).strip_edges().to_upper()
			if not s.is_empty() and not out.has(s):
				out.append(s)
	return out


## The note's `desk:` block, as written ({} for none).
static func desk_of(body: String) -> Dictionary:
	return FrontMatter.read_block(body, "desk").get("data", {})


## [param src]'s lines, a comment that runs over several lines joined into one - outside a fenced block, whose lines are
## kept as they are.
static func _logical_lines(src: String) -> PackedStringArray:
	var out := PackedStringArray()
	var held := ""
	var fenced := false
	for line in src.split("\n"):
		var s := String(line)
		if not held.is_empty():
			held += " " + s.strip_edges()
			if s.contains("-->"):
				out.append(held)
				held = ""
			continue
		if _rx(FENCE_OPEN).search(s) != null and not fenced:
			fenced = true
			out.append(s)
			continue
		if fenced:
			if _rx(FENCE_CLOSE).search(s) != null:
				fenced = false
			out.append(s)
			continue
		var open := s.rfind("<!--")
		if open >= 0 and s.find("-->", open) < 0:
			held = s
			continue
		out.append(s)
	if not held.is_empty():
		out.append(held)
	return out


## The note as blocks, in order: `{kind: "para", text}`, `{kind: "speaker", name}`, `{kind: "voice", text}` (an own-line
## hesitation or delivery), `{kind: "mark", verb, arg}`, `{kind: "image", where, prompt}`, `{kind: "type" | "screen",
## text}`. Notes are dropped.
static func blocks(body: String) -> Array:
	var src := Manuscript.strip_frontmatter(body)
	var out: Array = []
	var para := PackedStringArray()
	var fence := ""
	var fenced := PackedStringArray()
	for line in _logical_lines(src):
		var s := String(line)
		if not fence.is_empty():
			if _rx(FENCE_CLOSE).search(s) != null:
				out.append({"kind": fence, "text": "\n".join(fenced)})
				fence = ""
				fenced = PackedStringArray()
			else:
				fenced.append(s)
			continue
		var fo := _rx(FENCE_OPEN).search(s)
		if fo != null:
			_end_para(out, para)
			fence = fo.get_string(1)
			continue
		if s.strip_edges().is_empty():
			_end_para(out, para)
			continue
		var who := Manuscript.speaker_of_line(s)
		if not who.is_empty():
			_end_para(out, para)
			out.append({"kind": "speaker", "name": who})
			continue
		var m := _rx(MARK).search(s)
		if m != null:
			_end_para(out, para)
			out.append({"kind": "mark", "verb": m.get_string(1).replace(" ", "").to_lower(), "arg": m.get_string(2).strip_edges()})
			continue
		var im := _rx(IMAGE).search(s)
		if im != null:
			_end_para(out, para)
			var where := im.get_string(1).to_lower()
			out.append({"kind": "image", "where": where if (where in SCREENS) else "full", "prompt": im.get_string(2).strip_edges()})
			continue
		if _rx(VOICE_LINE).search(s) != null:
			_end_para(out, para)
			out.append({"kind": "voice", "text": s.strip_edges()})
			continue
		if _rx("^\\s*<!--[\\s\\S]*?-->\\s*$").search(s) != null:
			_end_para(out, para)
			continue
		para.append(s)
	_end_para(out, para)
	if not fence.is_empty():
		out.append({"kind": fence, "text": "\n".join(fenced)})
	return out


static func _end_para(out: Array, para: PackedStringArray) -> void:
	if para.is_empty():
		return
	out.append({"kind": "para", "text": "\n".join(para)})
	para.clear()


## A paragraph's spoken words, normalized - what the voice says of it ([method DeskScript._words]).
static func words_of(text: String) -> PackedStringArray:
	return DeskScript._words(text)


## A typed block as shown: its marks out and the spaces they leave closed up, line by line.
static func shown_of(text: String) -> String:
	var lines := PackedStringArray()
	for line in text.split("\n"):
		var s := _rx(COMMENT).sub(String(line), " ", true)
		lines.append(_rx(" {2,}").sub(s, " ", true).strip_edges())
	return "\n".join(lines)


## [param text] with its redact marks as the terminal holds them: each mark's words in its place, every character of them
## moved up into the private plane ([constant REDACT_BASE]) - the same length, so it is typed, wrapped and scrolled as
## written (a redacted space is no place to wrap, so a short redacted span stays on one line).
static func redacted(text: String) -> String:
	var out := ""
	var at := 0
	for m in _rx(REDACT).search_all(text):
		out += text.substr(at, m.get_start() - at)
		var words := m.get_string(1)
		for i in words.length():
			var c := words.unicode_at(i)
			out += char(REDACT_BASE + c) if c < 0xFFFE else words[i]
		at = m.get_end()
	return out + text.substr(at)


## Is character [param c] a redacted one ([method redacted])?
static func is_redacted(c: int) -> bool:
	return c >= REDACT_BASE and c < REDACT_BASE + 0xFFFE


## A line as drawn: `{text, spans: [Vector2i(c0, c1)]}` - every redacted character back as itself, and the runs of them,
## by column ([method redacted]).
static func unredacted(line: String) -> Dictionary:
	var out := ""
	var spans: Array = []
	var open := -1
	for i in line.length():
		var c := line.unicode_at(i)
		var hidden := is_redacted(c)
		if hidden and open < 0:
			open = i
		elif not hidden and open >= 0:
			spans.append(Vector2i(open, i))
			open = -1
		out += char(c - REDACT_BASE) if hidden else line[i]
	if open >= 0:
		spans.append(Vector2i(open, line.length()))
	return {"text": out, "spans": spans}


## What the voice says of a typed block [param shown]: its lines run together, and a block set all in capitals said in
## sentence case (every word of two capitals or more lowered, a sentence's first raised again), because the voice reads
## a short word in capitals as an initialism ([constant TextNorm.INITIALISMS]). A block with any small letter is said as
## written, its capitals kept (an initialism in a log line is one); a named letter, `[D]`, stays the letter.
static func said_of(shown: String) -> String:
	var text := " ".join(shown.split("\n", false))
	if text != text.to_upper():
		return text
	var out := PackedStringArray()
	var opens := true
	for tok in text.split(" ", false):
		var t := String(tok)
		var letters := _rx("[A-Z]").search_all(t).size()
		if letters >= 2 and not t.begins_with("["):
			t = t.to_lower()
			if opens:
				var first := _rx("[a-z]").search(t)
				if first != null:
					t = t.substr(0, first.get_start()) + t[first.get_start()].to_upper() + t.substr(first.get_start() + 1)
		out.append(t)
		opens = t.ends_with(".") or t.ends_with("!") or t.ends_with("?") or t.ends_with("]") or t.ends_with(":")
	return " ".join(out)


## Where each spoken word of a typed block is on the screen: `[{c0, c1}]`, one a word the voice says, the characters of
## [param shown] it types - a word's spaces and line breaks after it with it, so the keys stop at a word's end.
static func typed_spans(shown: String) -> Array:
	var out: Array = []
	var toks := _rx("\\S+").search_all(shown)
	for i in toks.size():
		var m: RegExMatch = toks[i]
		if TabletScript.norm(m.get_string()).is_empty():
			if not out.is_empty():
				(out.back() as Dictionary)["c1"] = m.get_end()
			continue
		out.append({"c0": m.get_start(), "c1": m.get_end()})
	for i in out.size():
		var next := shown.length() if i == out.size() - 1 else int((out[i + 1] as Dictionary)["c0"])
		(out[i] as Dictionary)["c1"] = next
	if not out.is_empty():
		(out[0] as Dictionary)["c0"] = 0
	return out


## [param text]'s lines wrapped at words to [param width] columns (a word longer than a line is cut): what a terminal shows.
static func wrapped(text: String, width: int) -> PackedStringArray:
	var out := PackedStringArray()
	for line in text.split("\n"):
		var s := String(line)
		if s.length() <= width:
			out.append(s)
			continue
		var cur := ""
		for w in s.split(" ", true):
			var word := String(w)
			while word.length() > width:
				if not cur.is_empty():
					out.append(cur)
					cur = ""
				out.append(word.substr(0, width))
				word = word.substr(width)
			if cur.is_empty():
				cur = word
			elif cur.length() + 1 + word.length() <= width:
				cur += " " + word
			else:
				out.append(cur)
				cur = word
		out.append(cur)
	return out


## A typed block as the printer prints it: its lines, each cut to the paper's width.
static func printed_lines(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line in text.split("\n"):
		var s := String(line)
		if s.is_empty():
			out.append("")
		while not s.is_empty():
			out.append(s.substr(0, PRINT_COLUMNS))
			s = s.substr(PRINT_COLUMNS)
	return out


## The length of a strike's or a `decide`'s pause: the mark's number (seconds), else [constant DECIDE].
static func decide_of(arg: String) -> float:
	var a := arg.strip_edges()
	return clampf(float(a), 0.0, DECIDE_MOST) if a.is_valid_float() else DECIDE


## How long the voice waits for a static of [param arg] (`5`, `5, surf`) and which storm it is.
static func static_of(arg: String) -> Dictionary:
	var parts := arg.split(",", false)
	var secs := STATIC_BARE
	var kind := "popcorn"
	for p in parts:
		var s := String(p).strip_edges().to_lower()
		if s.is_valid_float():
			secs = clampf(float(s), 0.5, 60.0)
		elif DispatchSounds.STORMS.has(s):
			kind = s
	return {"secs": secs, "kind": kind}


## Where a `gain:` mark turns the knob: its number, held to [constant GAIN_LEAST]-[constant GAIN_MOST]; -1 for no number.
static func gain_of(arg: String) -> int:
	var a := arg.strip_edges()
	return clampi(roundi(float(a)), GAIN_LEAST, GAIN_MOST) if a.is_valid_float() else -1


## How long the gain knob takes to turn from [param from] to [param to]: [constant GAIN_STEP] a step.
static func gain_turn(from: int, to: int) -> float:
	return GAIN_STEP * float(absi(to - from))


## Which sound a `sound:` mark's words name: its first part if that is a key of [constant DispatchSounds.SOUNDS], else
## the first key the words say; "" for none.
static func sound_of(arg: String) -> String:
	var head := arg.get_slice(",", 0).strip_edges().to_lower()
	if DispatchSounds.SOUNDS.has(head):
		return head
	var words := " " + _rx("[^a-z]+").sub(arg.to_lower(), " ", true) + " "
	for k in DispatchSounds.SOUNDS:
		if words.contains(" %s " % String(k)):
			return String(k)
	return ""


## A label as the phones are labeled: capitals, trimmed.
static func label_of(s: String) -> String:
	return s.strip_edges().to_upper()


## The whole note, walked: `{speakable, spoken, actions, spans, phones, room, warnings}`.
##
## `actions`, in order, are each `{kind, after, rest, len, fwd, back, ...}`: `after` the spoken word it comes before (its
## count of words before it), `rest` what the voice waits for it, `len` how long it moves, and where it falls in its
## silence - `fwd` the seconds written into the silence before it (hesitations and the rests of the actions before it),
## `back` after it. A typed block is an action too (its `rest` the lead before its words), with `from` and `to` its
## spoken words and `spans` where each is on the screen ([method typed_spans]). `spans` are the pictures over the whole
## screen: `{key, prompt, from, to, blend}` in spoken words.
static func parse(body: String) -> Dictionary:
	var phones := phones_of(body)
	var spoken := PackedStringArray()
	var speak := PackedStringArray()      # the voice's text, a block a line apart
	var actions: Array = []
	var spans: Array = []
	var warnings := PackedStringArray()
	var room := ""
	var speaker := ""                     # whose turn the next words are
	var said_as := ""                     # the speaker cue last written into the voice's text
	var heard_as := ""                    # ...and what it was heard through
	var said_any := false
	var in_hand := ""                     # the phone held to the ear
	var held: Array = []                  # the phones lying open on the desk, in the order they were laid down
	var ringing := ""                     # the phone that rang last, until a call answers it or words go by
	var gap: Array = []                   # this silence's rests in order: [seconds, action index or -1]
	var pending := PackedStringArray()    # voice marks and rests waiting for the next words
	var typed: Array = []                 # typed block action indices since the last print
	var last_typed := -1
	var open_image := -1                  # the picture over the whole screen still up (an index into spans)
	var last_text := ""                   # the phone that texted last
	var reply_to := ""                    # the phone the room's next words are typed into
	var gain := GAIN_REST                 # where the radar's gain knob stands
	gap.append([OPENING, -1])
	pending.append("<!-- action-hold: %s -->" % String.num(OPENING, 2))
	for b in blocks(body):
		var blk: Dictionary = b
		match String(blk["kind"]):
			"speaker":
				speaker = String(blk["name"])
				if room.is_empty():
					room = speaker
			"voice":
				var t := String(blk["text"])
				pending.append(t)
				for m in _rx(HESITATION).search_all(t):
					var v := m.get_string(1) if not m.get_string(1).is_empty() else m.get_string(2)
					gap.append([float(v) if not v.is_empty() else HESITATE, -1])
			"image":
				var where := String(blk["where"])
				var prompt := String(blk["prompt"])
				if where == "full":
					var blend := open_image >= 0
					if open_image >= 0:
						(spans[open_image] as Dictionary)["to"] = spoken.size()
					spans.append({"kind": "image", "key": Manuscript.image_key(prompt), "prompt": prompt,
						"from": spoken.size(), "to": -1, "blend": blend or _ends_at(spans, spoken.size())})
					open_image = spans.size() - 1
				else:
					_act(actions, gap, pending, spoken.size(), {"kind": "picture", "screen": where,
						"key": Manuscript.image_key(prompt), "prompt": prompt}, PICTURE, PICTURE)
			"terminal":
				var steps := session_of(redacted(String(blk["text"])))
				if steps.is_empty():
					continue
				var plan := session_plan(steps)
				_act(actions, gap, pending, spoken.size(), {"kind": "session", "steps": steps, "plan": plan},
					float(plan["rest"]), float(plan["len"]))
				ringing = ""
			"type", "screen":
				var kind := String(blk["kind"])
				var raw := String(blk["text"])
				var shown := shown_of(raw) if kind == "type" else redacted(raw)
				if kind == "type" and _rx(REDACT).search(raw) != null:
					warnings.append("redact: a typed block is said, so its redacted words are left out (redact in a screen or terminal block)")
				if kind == "screen":
					var drawn := SCREEN_LINE * float(raw.split("\n").size())
					_act(actions, gap, pending, spoken.size(), {"kind": "screen", "text": shown}, SCREEN_REST + drawn, SCREEN_REST + drawn)
					continue
				var who := room if not room.is_empty() else speaker
				_flush(speak, pending, who, "", said_as, heard_as)
				said_as = who
				heard_as = ""
				var voice_text := said_of(shown)
				var words := words_of(voice_text)
				var keyed := typed_spans(shown)
				var from := spoken.size()
				var ahead := TYPE_LEAD + KEY_EACH * float(int((keyed[mini(AHEAD_WORDS, keyed.size()) - 1] as Dictionary)["c1"])) \
					if not keyed.is_empty() else TYPE_LEAD
				var i := _act(actions, gap, pending, from, {"kind": "type", "text": shown, "from": from,
					"to": from + words.size(), "spans": keyed}, ahead, ahead)
				_flush(speak, pending, who, "", said_as, heard_as)
				speak.append(voice_text)
				spoken.append_array(words)
				said_any = said_any or not words.is_empty()
				gap = []
				typed.append(i)
				last_typed = i
				ringing = ""
			"para":
				var text := String(blk["text"])
				var who := speaker if not speaker.is_empty() else Manuscript.NARRATOR
				if room.is_empty():
					room = who
				var heard := _heard(who, room, in_hand, held)
				if who != room and heard.is_empty():
					warnings.append("%s speaks with no phone open: heard in the room" % who)
				if not reply_to.is_empty() and who == room:
					var shown := " ".join(text.split("\n", false))
					var wn := words_of(text).size()
					_act(actions, gap, pending, spoken.size(), {"kind": "reply", "label": reply_to, "text": shown, "from": spoken.size(),
						"to": spoken.size() + wn, "spans": typed_spans(shown)}, REPLY_LEAD, REPLY_LEAD)
					reply_to = ""
				_flush(speak, pending, who, heard, said_as, heard_as)
				said_as = who
				heard_as = heard
				speak.append(text)
				var words := words_of(text)
				spoken.append_array(words)
				said_any = said_any or not words.is_empty()
				if not words.is_empty():
					gap = []
					ringing = ""
			"mark":
				var verb := String(blk["verb"])
				var arg := String(blk["arg"])
				var at := spoken.size()
				match verb:
					"call":
						var label := label_of(arg)
						if not phones.has(label):
							warnings.append("call: %s is no phone on the desk" % label)
							phones.append(label)
						if label == in_hand:
							continue
						var rest := 0.0
						var parts: Array = []
						if not in_hand.is_empty():
							parts.append({"label": in_hand, "move": "lay_down", "at": 0.0})
							held.append(in_hand)
							rest += LAY_DOWN
						var how := "dial"
						if held.has(label):
							how = "pick_up"
							held.erase(label)
						elif ringing == label:
							how = "answer"
						var own := float({"pick_up": PICK_UP, "answer": LIFT + ANSWER}.get(how, LIFT + DIAL + _rung()))
						parts.append({"label": label, "move": how, "at": rest})
						rest += float(own)
						in_hand = label
						ringing = ""
						_act(actions, gap, pending, at, {"kind": "call", "label": label, "how": how, "parts": parts}, rest, rest)
					"/call":
						var label := label_of(arg) if not arg.is_empty() else in_hand
						if label.is_empty():
							warnings.append("/call with no phone in hand")
							continue
						if label == in_hand:
							in_hand = ""
						elif held.has(label):
							held.erase(label)
						else:
							warnings.append("/call: %s is not open" % label)
							continue
						_act(actions, gap, pending, at, {"kind": "hang_up", "label": label}, HANG_UP_REST, HANG_UP)
					"ring":
						var label := label_of(arg)
						if not phones.has(label):
							warnings.append("ring: %s is no phone on the desk" % label)
							phones.append(label)
						ringing = label
						var cycle := BUZZ_ON + BUZZ_OFF
						_act(actions, gap, pending, at, {"kind": "ring", "label": label}, cycle * BUZZES, cycle * BUZZES_OUT)
					"text":
						var label := label_of(arg.get_slice("|", 0))
						var words := arg.get_slice("|", 1).strip_edges() if arg.contains("|") else ""
						if not phones.has(label):
							warnings.append("text: %s is no phone on the desk" % label)
							phones.append(label)
						var rest := TEXT_CHIME + READ_LIFT + READ_WORD * float(words.split(" ", false).size()) + READ_BEAT
						_act(actions, gap, pending, at, {"kind": "text", "label": label, "words": words}, rest, rest + READ_DOWN)
						last_text = label
					"reply":
						var label := label_of(arg) if not arg.is_empty() else last_text
						if label.is_empty():
							warnings.append("reply with no text to answer")
							continue
						reply_to = label
					"ping":
						var stop := ping_of(arg)
						if float(stop["travel"]) > 0.0:
							warnings.append("ping: %s - seconds are not read; mark where he sets off with <!-- moving -->" % arg)
						_act(actions, gap, pending, at, {"kind": "ping", "place": String(stop["place"])}, PING, PING_LEN)
					"moving":
						# straight after a ping, in the same silence: he passes through it and goes on - no alarm, no wait
						var passing := not gap.is_empty() and int((gap.back() as Array)[1]) >= 0 \
							and String((actions[int((gap.back() as Array)[1])] as Dictionary)["kind"]) == "ping"
						_act(actions, gap, pending, at, {"kind": "moving", "passing": passing}, 0.0 if passing else MOVING, MOVING_LEN)
					"sound":
						var key := sound_of(arg)
						var secs := float(DispatchSounds.SOUNDS[key]["secs"]) if not key.is_empty() else SOUND_BARE
						_act(actions, gap, pending, at, {"kind": "sound", "sound": key, "words": arg}, secs, secs)
					"static":
						var st := static_of(arg)
						_act(actions, gap, pending, at, {"kind": "static", "storm": st["kind"]}, float(st["secs"]), float(st["secs"]))
					"print":
						var text := PackedStringArray()
						for k in typed:
							var a: Dictionary = actions[int(k)]
							if not bool(a.get("struck", false)):
								text.append(String(a["text"]))
						typed = []
						var lines := printed_lines("\n\n".join(text))
						var secs := clampf(PRINT_LEAD + PRINT_LINE * float(lines.size()) + PRINT_FEED, PRINT_LEAST, PRINT_MOST)
						_act(actions, gap, pending, at, {"kind": "print", "lines": lines}, secs, secs)
					"sleep":
						_act(actions, gap, pending, at, {"kind": "sleep"}, SLEEP, SLEEP)
					"off":
						var screen := arg.strip_edges().to_lower()
						if not screen in SCREENS:
							warnings.append("off: %s is no screen" % screen)
							continue
						_act(actions, gap, pending, at, {"kind": "off", "screen": screen}, OFF, OFF)
					"look":
						_act(actions, gap, pending, at, {"kind": "look", "at": arg.strip_edges().to_lower()}, LOOK, LOOK)
					"lift":
						_act(actions, gap, pending, at, {"kind": "lift", "thing": arg.strip_edges().to_lower()},
							LIFT_UP + LIFT_HOLD + LIFT_DOWN * LIFT_SAID, LIFT_UP + LIFT_HOLD + LIFT_DOWN)
					"switch":
						_act(actions, gap, pending, at, {"kind": "switch", "side": arg.strip_edges().to_upper()}, SWITCH, SWITCH)
					"live":
						var screen := arg.get_slice(",", 0).strip_edges().to_lower()
						if not screen in SCREENS:
							warnings.append("live: %s is no screen" % screen)
							continue
						_act(actions, gap, pending, at, {"kind": "live", "screen": screen}, PICTURE, PICTURE)
					"strike":
						if last_typed < 0:
							warnings.append("strike with nothing typed")
							continue
						var a: Dictionary = actions[last_typed]
						a["struck"] = true
						var wait := decide_of(arg)
						var back := minf(float(String(a["text"]).length()) / BACKSPACE, BACKSPACE_MOST)
						_act(actions, gap, pending, at, {"kind": "strike", "block": last_typed, "decide": wait}, wait + back, wait + back)
						last_typed = -1
					"gain":
						var to := gain_of(arg)
						if to < 0:
							warnings.append("gain: %s is no number from %d to %d" % [arg, GAIN_LEAST, GAIN_MOST])
							continue
						var turned := GAIN_REACH + gain_turn(gain, to)
						_act(actions, gap, pending, at, {"kind": "gain", "from": gain, "to": to}, turned + GAIN_BEAT, turned + GAIN_BEAT)
						gain = to
					"bell":
						_act(actions, gap, pending, at, {"kind": "bell"}, BELL, BELL)
					"lamp":
						var said := arg.strip_edges().to_lower()
						if not said in ["on", "off"]:
							warnings.append("lamp: %s - the lamp is on or off" % said)
							continue
						_act(actions, gap, pending, at, {"kind": "lamp", "on": said == "on"}, LAMP, LAMP)
					"/image":
						if open_image >= 0:
							(spans[open_image] as Dictionary)["to"] = at
							open_image = -1
							_act(actions, gap, pending, at, {"kind": "clear"}, IMAGE_FADE + 0.1, IMAGE_FADE + 0.1)
	if open_image >= 0:
		(spans[open_image] as Dictionary)["to"] = spoken.size()
	if in_hand != "" or not held.is_empty():
		warnings.append("left open at the end: %s" % ", ".join(PackedStringArray(([in_hand] if not in_hand.is_empty() else []) + held)))
	if not pending.is_empty():
		if speak.is_empty() or not said_any:
			speak.append(" ".join(pending))
		else:
			speak[speak.size() - 1] = String(speak[speak.size() - 1]) + " " + " ".join(pending)
	_silences(actions)
	return {"speakable": "\n\n".join(speak), "spoken": spoken, "actions": actions, "spans": spans,
		"phones": phones, "room": room, "warnings": warnings}


## How long a dialed phone rings in the earpiece before it is answered: [constant RINGS] rings' cycles, answered as the
## last one's pair of rings ends.
static func _rung() -> float:
	return RING_CYCLE * float(RINGS - 1) + RING_ON + ANSWER


## A ping's words: `{place, travel}` - a comma inside the place kept (`the grocery store, aisle seven`); a number after
## its last comma is taken off it (`travel`) and not read - where he sets off is a `moving` mark - so the parse can say so.
static func ping_of(arg: String) -> Dictionary:
	var place := arg.strip_edges()
	var travel := 0.0
	var cut := place.rfind(",")
	if cut >= 0:
		var m := _rx("^\\s*([0-9]+(?:\\.[0-9]+)?)\\s*(?:s|secs?|seconds)?\\s*$").search(place.substr(cut + 1))
		if m != null:
			travel = float(m.get_string(1))
			place = place.substr(0, cut).strip_edges()
	return {"place": place, "travel": travel}


## A session's steps from a ```terminal block: `[{typed, out: PackedStringArray}]` - each line opening `>` a command (what
## follows the `>`, typed), the lines after it its answer. Lines before the first command are what the terminal shows as
## it wakes (a step with nothing typed). Blank lines at a step's end are dropped; inside, kept.
static func session_of(text: String) -> Array:
	var out: Array = []
	var typed := ""
	var command := false
	var lines := PackedStringArray()
	var open := false
	for raw in text.split("\n"):
		var line := String(raw).rstrip(" \t")
		if line.strip_edges().begins_with(">"):
			if open:
				out.append(_session_step(typed, command, lines))
			typed = line.strip_edges().substr(1).strip_edges()
			command = true
			lines = PackedStringArray()
			open = true
			continue
		if not open:
			if line.strip_edges().is_empty():
				continue
			typed = ""
			command = false
			lines = PackedStringArray()
			open = true
		lines.append(line)
	if open:
		out.append(_session_step(typed, command, lines))
	return out


## One step of a session, its answer's blank lines at the end dropped. (A packed array is built whole before it goes into
## the step: one read back out of a Dictionary is a copy, and appending to it changes nothing.)
static func _session_step(typed: String, command: bool, lines: PackedStringArray) -> Dictionary:
	var kept := lines.duplicate()
	while not kept.is_empty() and kept[kept.size() - 1].strip_edges().is_empty():
		kept.remove_at(kept.size() - 1)
	return {"typed": typed, "out": kept, "command": command}


## When each thing in a session happens, in seconds from its start (the screen waking first, [constant WAKE]): per step
## `{prompt (its prompt up), keys: PackedFloat32Array (each typed character's), enter, lines: PackedFloat32Array (each
## answering line's)}` - a step with nothing typed has its lines printed as the screen wakes - then `prompt`, when the bare
## prompt comes back after the last; `rest`, what the voice waits (the last answer printed), and `len`: the operator reads
## each answer before the next command, and the last one before the session ends. A key's give-or-take is drawn from the
## session's own words, so it is typed the same way every time.
static func session_plan(steps: Array) -> Dictionary:
	var t := WAKE
	var wait := PROMPT_WAIT
	var out: Array = []
	var last_n := 0
	for k in steps.size():
		var st: Dictionary = steps[k]
		var typed := String(st["typed"])
		var prompt := -1.0
		var keys := PackedFloat32Array()
		var enter := -1.0
		if bool(st.get("command", true)):
			prompt = t
			t += wait
			for c in typed.length():
				var j := DispatchSounds.hash01(hash([typed, k]), c) * 2.0 - 1.0
				var space := typed[c] == " " or typed.unicode_at(c) == REDACT_BASE + 32
				t += KEY_EACH * (1.0 + KEY_JITTER * j) * (1.35 if space else 1.0)
				keys.append(t)
			t += ENTER_AFTER
			enter = t
			t += ANSWER_AFTER
		var lines := PackedFloat32Array()
		var n := (st["out"] as PackedStringArray).size()
		for i in n:
			lines.append(t + LINE_EACH * float(i))
		t += LINE_EACH * float(n)
		wait = READ_LEAST + READ_LINE * float(n)
		last_n = n
		out.append({"prompt": prompt, "keys": keys, "enter": enter, "lines": lines})
	return {"steps": out, "prompt": t, "rest": t + 0.2, "len": t + (wait if last_n > 0 else 0.3)}


## What a turn of [param who] is heard through: the room's own voice in the room; a voice whose phone is in hand
## through it, one whose phone lies open on the desk from the desk, and any other through the phone in hand (a voice in
## the caller's room) - or the one on the desk.
static func _heard(who: String, room: String, in_hand: String, held: Array) -> String:
	if who == room:
		return ""
	var label := label_of(who)
	if label == in_hand:
		return "phone"
	if held.has(label):
		return "desk"
	if not in_hand.is_empty() or not held.is_empty():
		return "far"
	return ""


## An action before spoken word [param at]: added, its rest written into the voice's text, its place in its silence
## noted. Returns its index.
static func _act(actions: Array, gap: Array, pending: PackedStringArray, at: int, a: Dictionary, rest: float, length: float) -> int:
	a["after"] = at
	a["rest"] = rest
	a["len"] = maxf(length, rest)
	actions.append(a)
	var i := actions.size() - 1
	a["gap"] = gap
	gap.append([rest, i])
	if rest > 0.0:
		pending.append("<!-- action-hold: %s -->" % String.num(rest + REST_PAD, 2))
	return i


## Each action's `fwd` and `back`: the seconds of its silence written before and after it - its hesitations and the rests
## of the actions in it, in order (each action holds its silence's list, `gap`, until now).
static func _silences(actions: Array) -> void:
	for i in actions.size():
		var act: Dictionary = actions[i]
		var g: Array = act.get("gap", [])
		var before := 0.0
		var mine := -1
		for k in g.size():
			if int((g[k] as Array)[1]) == i:
				mine = k
				break
			before += float((g[k] as Array)[0]) + (REST_PAD if int((g[k] as Array)[1]) >= 0 else 0.0)
		var after := 0.0
		for k in range(mine + 1, g.size()):
			after += float((g[k] as Array)[0]) + (REST_PAD if int((g[k] as Array)[1]) >= 0 else 0.0)
		act["fwd"] = before
		act["back"] = after + REST_PAD
		act.erase("gap")


## The voice's text for the next words: a speaker cue where the voice or what it is heard through changes, then what
## waited for them (voice marks, rests) - so a rest before a turn is that turn's, leading its first word.
static func _flush(speak: PackedStringArray, pending: PackedStringArray, who: String, heard: String, said_as: String,
		heard_as: String) -> void:
	if who != said_as or heard != heard_as:
		var cue := "<!-- speaker: %s -->" % who
		if not heard.is_empty():
			cue += "\n<!-- heard: %s -->" % heard
		speak.append(cue)
	if not pending.is_empty():
		speak.append(" ".join(pending))
		pending.clear()


## Does a picture over the whole screen end at spoken word [param at] (its `/image` just before), so the next begins on
## it - a dissolve, the desk never seen between?
static func _ends_at(spans: Array, at: int) -> bool:
	return not spans.is_empty() and int((spans.back() as Dictionary)["to"]) == at


## Which spoken words end a sentence in [param parsed]: 1 for each that ends in `.`, `!` or `?` (a quote or bracket after it
## kept) or ends its paragraph - the voice's text walked as [method rehearsal] walks it (the spoken words themselves are
## normalized, their punctuation gone).
static func sentence_ends(parsed: Dictionary) -> PackedByteArray:
	var spoken: PackedStringArray = parsed["spoken"]
	var out := PackedByteArray()
	out.resize(spoken.size())
	var token := _rx("<!--.*?-->|\\S+")
	var stop := _rx("[.!?][\"')\\]]*$")
	var n := 0
	for chunk in String(parsed["speakable"]).split("\n\n"):
		var last := -1
		for m in token.search_all(String(chunk)):
			var tok := m.get_string()
			if tok.begins_with("<!--") or TabletScript.norm(tok).is_empty() or n >= spoken.size():
				continue
			out[n] = 1 if stop.search(tok) != null else 0
			last = n
			n += 1
		if last >= 0:
			out[last] = 1
	return out


## A steady voice's word times for [param parsed] (for a probe and a gate): every spoken word [param word] seconds, a
## sentence's rest after each paragraph, and the rests the script writes and its hesitations at their lengths - as
## [method DeskScript.rehearsal] does for the desk, and as a live reading's words arrive: `{text, t0, t1}`.
static func rehearsal(parsed: Dictionary, word := 0.32, pause := 0.35, lead := 1.0) -> Array:
	var spoken: PackedStringArray = parsed["spoken"]
	var token := _rx("<!--\\s*action-hold\\s*:\\s*([0-9.]+)\\s*-->|<!--\\s*hesitation\\s*(?::\\s*([0-9.]+))?\\s*-->|<!--.*?-->|\\S+")
	var out: Array = []
	var t := lead
	for chunk in String(parsed["speakable"]).split("\n\n"):
		var any := false
		for m in token.search_all(String(chunk)):
			if not m.get_string(1).is_empty():
				t += float(m.get_string(1))
			elif m.get_string().contains("hesitation"):
				t += float(m.get_string(2)) if not m.get_string(2).is_empty() else HESITATE
			elif not m.get_string().begins_with("<!--") and not TabletScript.norm(m.get_string()).is_empty():
				if out.size() < spoken.size():
					out.append({"text": spoken[out.size()], "t0": t, "t1": t + word * 0.9, "sentence": 0})
				t += word
				any = true
		if any:
			t += pause
	return out
