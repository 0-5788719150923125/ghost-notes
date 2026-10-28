extends RefCounted
class_name ReadingPlan

## ReadingPlan - what a reading will say, worked out from its words before a sound is made: the
## script cut into chunks of a sentence each, every chunk carrying its speaker, its tokens for the
## voice host, its words for the subtitles, its hesitations, its delivery and its place in its
## paragraph; where the outro mark's fade starts and how long it is; the scrub bar's estimate of
## where each sentence starts; and, once a chunk is made, its words timed from the spans the host
## hands back.
##
## A FUNCTION OF WHAT IT IS HANDED (next/structure.md, step 17). These were the reading panel's
## own, and they kept what they found in members of it - the hesitations' lengths in a list a
## second method consumed with a cursor, the delivery marks of the passage last resolved, the
## fade's length - so an export planned while a reading played rewrote the fade the reading was
## fading by. Here the text, the title announced first and what is ASKED go in, and the plan
## comes out: the live window, the scrub, the audition and the export plan the same words the
## same way, and none of them can disturb another.
##
## WHAT IS ASKED (`ask` in [method make] and [method passages]):
## - `reader` - the voice a cue naming [constant Manuscript.NARRATOR] goes to (the cast's first);
## - `hesitate` - whether the script's hesitation marks rest at all (the Hesitate box);
## - `bare` - how long, in seconds, a hesitation that names no length rests;
## - `outro` - the Outro's length, in seconds: what an outro mark's fade can carry.
##
## A READING THAT GROWS plans each new piece of its text as a continuation: [method make]'s
## [param from_sentence] carries the sentence count on (the subtitles window by it, and two pieces
## sharing a sentence number would be drawn at once), and the plan says where the next piece
## starts (`sentences`).

# The punctuation marks the host is allowed to receive.
#
# A mark is phonemized as part of its word, so whatever is sent here has to have
# an entry in the selected voice's phoneme_id_map - piper.py raises loudly on a
# symbol that does not, and rightly so. This list is the contract: anything else
# a text might end a word with (a bare newline, an em dash, a stray glyph the
# normalizer let through) falls back to the coarse pause_after mapping instead of
# being forwarded verbatim.
const PUNCT_ALLOWED := [".", ",", "!", "?", ":", ";"]
# One sentence per chunk. Two made every tone or pace change wait for the larger
# buffer to drain; one halves that latency, and costs nothing now that the
# inter-sentence gap is inserted at chunk boundaries too (see ReadingJoin.add).
const CHUNK_SENTENCES := 1
## Give every chunk its place in the reading, so the delivery plan can be a plan.
##
## THE BUG THIS FIXES. `_discourse_plan` shapes a sentence by where it sits in the unit
## it was handed - and the unit it is handed is one REQUEST, which is one sentence
## (CHUNK_SENTENCES = 1). So every sentence was simultaneously the first and last of its
## own unit: position 0 of 1, every time. Final lengthening never once fired, and the
## "arc" resolved to the same constant offset on every sentence in the chapter - a
## transposition wearing an arc's name. It measured correctly when I tested it, because I
## tested it by handing the whole paragraph over in one call, which is a path the editor
## never takes. The audible difference between Arc 0 and Arc 1 was real; it just was not
## an arc.
##
## TWO NESTED LEVELS, because discourse structure is nested and so are its pitch resets -
## the size of a reset scales with the depth of the boundary it follows (Grosz & Sidner;
## Hirschberg & Nakatani). `u` is the sentence's place in its paragraph and `v` its
## paragraph's place in a run of them. That second level is what a chapter of one-sentence
## paragraphs needs: at `u` the paragraph collapses to a point and every one of them would
## otherwise be handed the identical contour, which is exactly the flatness reported.
## Sections are runs of SECTION_PARAS paragraphs, so the slow movement is phase-locked to
## the prose the same way the fast one is.
const SECTION_PARAS := 5
## ...and the longest run of sentences that may be called one paragraph. Nothing to
## do with style: a paragraph is where the pitch arc RESETS, so an unbroken block is
## an arc with no reset in it, and the register just falls for as long as the block
## does. Eight is a long paragraph; past that the text is not telling us where its
## paragraphs are, and reading it as consecutive ones of this length is the same
## guard SECTION_PARAS is a level up.
const PARA_CEILING := 8
## The estimate the scrub bar is laid out by: a reading pace, plus every rest at its own length.
const SCRUB_SECONDS_PER_WORD := 0.38
const OUTRO_MIN_FADE := 0.5
## Enough words to fill a fade - a brisk pace, so the fade never runs out of voice early.
const OUTRO_WORDS_PER_SECOND := 3.5


## THE WHOLE PLAN of [param body] (the words as the voice reads them - see [method TextWalk.spoken])
## with [param title] announced first: `{chunks, note, fade, sentences}` - the chunks, what the plan
## noticed about the script for the line that reports it ("" for nothing), the outro mark's fade in
## seconds (0 with no mark) and the sentence the next piece of a growing reading starts at.
##
## The speaker cues are resolved HERE and nowhere else: past this point a chunk
## carries a speaker's name and every consumer - the request, the seam, the room - reads its
## settings from that. Nothing downstream has to know that a script can change voice.
static func make(body: String, title: String, ask: Dictionary, from_sentence := 0) -> Dictionary:
	var out: Array = []
	var sentence_no := from_sentence
	var bare: PackedStringArray = PackedStringArray()
	for seg in passages(body, title, ask):
		var text := String((seg as Dictionary)["text"])
		var who := String((seg as Dictionary)["speaker"])
		# Asked per PASSAGE rather than of the whole box, so a macro sitting in a
		# stripped authoring note is not reported as one that will be missing
		# from the reading - it was never going to be read either way.
		bare.append_array(TextNorm.unresolved_macros(text))
		var part := cut(text, sentence_no, (seg as Dictionary).get("holds", []))
		var chunks: Array = part["chunks"]
		sentence_no = int(part["sentence_no"])
		if chunks.is_empty():
			continue
		# PLACEMENT IS PER PASSAGE. A speaker's turn is its own piece of
		# discourse - it opens in its own register and settles across its own
		# paragraphs - so measuring it against the whole chapter would hand the
		# second voice the contour of a paragraph it is not in.
		place(chunks, text)
		var fade := bool((seg as Dictionary).get("fade", false))
		var leans: Array = (seg as Dictionary).get("leans", [])
		var cursor := 0
		for c in chunks:
			(c as Dictionary)["speaker"] = who
			if fade:
				(c as Dictionary)["fade"] = true
			# A CHUNK'S DELIVERY is the one marked where its first word is in the passage
			var aim := Vector4.ZERO
			if not leans.is_empty():
				var first := ""
				for w in (c as Dictionary)["words"]:
					first = String((w as Dictionary).get("text", "")).strip_edges()
					if not first.is_empty():
						break
				var found := text.find(first, cursor) if not first.is_empty() else -1
				if found >= 0:
					cursor = found + first.length()
				for sp in leans:
					if int((sp as Array)[0]) <= (found if found >= 0 else cursor):
						aim = (sp as Array)[1]
			(c as Dictionary)["lean_aim"] = aim
		out.append_array(chunks)
	Delivery.ease_leans(out)
	var trimmed := trim_to_outro(out, float(ask.get("outro", 0.0)))
	# what the script needs fixing, for the line someone is looking at with their hand on Play:
	# TextNorm has already warned into the log, but a macro with no default is words missing from
	# a reading about to be made
	var note := ""
	if not bare.is_empty():
		note = "%d macro(s) will not read as intended: %s - write ${NAME:value}" % [bare.size(), ", ".join(bare)]
	return {"chunks": trimmed["chunks"], "note": note, "fade": trimmed["fade"], "sentences": sentence_no}


## Split a script into passages by speaker: `[{speaker, text, fade, leans, holds}]`. Text before
## the first cue - and a script with no cues at all - is the reader's ([param ask] `reader`).
##
## Also where the HESITATIONS are resolved, because it is the last place that still sees the
## markers in their text: each becomes a [constant TextNorm.HOLD_MARK] welded to the word it
## follows (or leads, when nothing comes before it in the passage), and its length goes on the
## passage's own `holds`, in the same order, for [method cut] to hand back out. With [param ask]
## `hesitate` off they are simply removed. Every other comment is an authoring note and goes too.
## A passage's rests are its own: a sentinel the phonemizer loses costs that passage its lengths,
## never every passage after it.
static func passages(body: String, title: String, ask: Dictionary) -> Array:
	var kept: Array = []
	var on := bool(ask.get("hesitate", true))
	var bare := float(ask.get("bare", 0.0))
	var reader := String(ask.get("reader", Manuscript.NARRATOR))
	# THE TITLE IS READ FIRST, as a heading of its own, by the voice that opens the chapter.
	# The frontmatter as metadata is still never spoken - only the title's value, the way a
	# reader announces a chapter before its first word. Not twice: a chapter that already
	# opens on its title as a heading keeps that one. A chapter read off a screen announces
	# nothing (its walk hands no title).
	var first := true
	var fading := false
	for p in Manuscript.passages(body):
		var raw := String((p as Dictionary)["text"])
		# the first passage with anything in it: a chapter opening on a cue has an empty one
		# before it, and a title put there would invent a narrator to read it
		if first and not title.is_empty() and not raw.strip_edges().is_empty():
			var lead := raw.strip_edges().get_slice("\n", 0).lstrip("#").strip_edges()
			if lead.to_lower() != title.to_lower():
				raw = "# %s\n\n%s" % [title, raw]
		if not raw.strip_edges().is_empty():
			first = false
		# a log entry's time gets its pause before the markers are read, so it IS a marker
		var t := Manuscript.mark_timestamp_pauses(raw)
		# THE OUTRO MARK splits its passage: what comes after it is read FADING (see
		# [method trim_to_outro]), and so is every passage after that. The first mark counts.
		var parts := [t]
		var om: RegExMatch = null
		if not fading:
			om = Manuscript._rx(Manuscript.OUTRO).search(t)
		if om != null:
			parts = [t.substr(0, om.get_start()), t.substr(om.get_end())]
		var name := String((p as Dictionary)["speaker"])
		for k in parts.size():
			if k == 1:
				fading = true
			var res := resolve_marks(String(parts[k]), on, bare)
			var out := String(res["text"])
			# A passage of nothing but hesitations: its rests would have no word to sit on.
			if not out.replace(TextNorm.HOLD_MARK, "").strip_edges().is_empty():
				kept.append({"speaker": reader if name == Manuscript.NARRATOR else name, "text": out,
					"fade": fading, "leans": res["leans"], "holds": res["holds"]})
	# A TABLET'S OPENING RUN (wake, open the browser, type) comes AFTER the intro, end to end:
	# the intro is the tablet lying dark on the desk, and its rest is the run's own, whole
	return kept


## A passage's marks resolved: `{text, holds, leans}`. Every hesitation (and the tablet's action
## rests) becomes a [constant TextNorm.HOLD_MARK] welded to the word before it - or leading the
## next, when nothing precedes it - with its length in `holds`; a DELIVERY mark is noted where it
## falls in `leans` (see [method Delivery.leans_of]); every other comment goes.
static func resolve_marks(t: String, on: bool, bare: float) -> Dictionary:
	var out := ""
	var at := 0
	var holds: Array = []
	var leans: Array = []
	var re := Manuscript._rx(Manuscript.COMMENT)
	var hes := Manuscript._rx(Manuscript.HESITATION)
	var lean_re := Manuscript._rx(Manuscript.DELIVERY)
	for m in re.search_all(t):
		out += t.substr(at, m.get_start() - at)
		at = m.get_end()
		# THE TABLET'S HAND IS NOT A HESITATION: its rest is the time a tap or a typed
		# address takes, so it stays when the Hesitate box is off
		var secs := TabletScript.hold_of(m.get_string())
		if secs < 0.0:
			var lm := lean_re.search(m.get_string())
			if lm != null:
				leans.append([out.length(), Delivery.lean_of(lm.get_string(1))])
				continue
			if not on:
				continue
			var hm := hes.search(m.get_string())
			if hm == null:
				continue             # an authoring note
			var v := hm.get_string(1) if not hm.get_string(1).is_empty() else hm.get_string(2)
			secs = clampf(float(v), 0.0, 30.0) if not v.is_empty() else bare
		# WELDED, never left standing: a sentinel alone between two spaces is a token of
		# its own, and a token that is not a word confuses the sentence splitter around
		# it. Trailing whitespace is stepped over so it lands directly after the last
		# character of the previous word.
		var head := out.rstrip(" \t\n")
		out = head + TextNorm.HOLD_MARK + out.substr(head.length())
		holds.append(secs)
	out += t.substr(at)
	leans = Delivery.leans_of(out, leans)
	# Sentinels with nothing before them in the passage LEAD the next word instead:
	# close the gap after them so they weld on to it.
	var body_t := out.strip_edges()
	var n := 0
	while body_t.begins_with(TextNorm.HOLD_MARK):
		n += 1
		body_t = body_t.substr(1).strip_edges(true, false)
	# ...AFTER a heading's `#`s, never before them: `#` is only markup at the start of a
	# line, and a sentinel in front of it left "##" to be read as a word (a hesitation
	# standing alone above a dated entry did exactly that).
	var marks := ""
	if n > 0 and body_t.begins_with("#"):
		var k := 0
		while k < body_t.length() and body_t[k] == "#":
			k += 1
		marks = body_t.substr(0, k) + " "
		body_t = body_t.substr(k).strip_edges(true, false)
	var said := marks + TextNorm.HOLD_MARK.repeat(n) + body_t
	# A DELIVERY MARK IS WHERE IT FALLS IN WHAT IS RETURNED: it was noted in `out`, before the
	# passage's leading whitespace went, so a passage opening on a stripped comment and a blank
	# line had every mark two characters late - past the first word of the sentence under it,
	# which then read in the delivery before (tests/reading/multi_voice_check.gd).
	var gone := out.strip_edges(false, true).length() - said.length()
	if gone != 0:
		for lean in leans:
			(lean as Array)[0] = maxi(0, int((lean as Array)[0]) - gone)
	return {"text": said, "holds": holds, "leans": leans}


## One passage, cut at sentence boundaries: `{chunks, sentence_no}`, each chunk
## `{tokens, words, holds}`. [param holds] are the lengths of its hesitations in text order
## ([method passages]), handed out as the phonemizer meets the sentinels that mark their places.
## `sentence_no` runs across the WHOLE script rather than restarting per passage: [Subtitles]
## windows the display by that index, and two speakers sharing sentence 0 would have the overlay
## draw both at once.
static func cut(body: String, sentence_no: int, holds: Array = []) -> Dictionary:
	var out: Array = []
	var toks: Array = []
	var words: Array = []
	var rests: Array = []          # [{tok, sec, before}] - see Splice.chunk
	var after := 0.0               # the rest spliced in after the token being built
	var hold_i := 0
	var sentences := 0
	var parsed := Phonemes.parse(body)
	var stressed_at := Delivery.stressed_words(parsed)
	var flat := -1
	for sentence in parsed:
		for w in sentence:
			flat += 1
			var ph: Array = w.phones
			var st: Array = w.get("stress", [])
			var start := toks.size()
			after = 0.0
			# HESITATIONS, in the order the phonemizer met their sentinels - which is the
			# order [method passages] listed their lengths in.
			for key in ["hold_before", "hold"]:
				var n := int(w.get(key, 0))
				if n <= 0:
					continue
				var sec := 0.0
				for _k in n:
					if hold_i < holds.size():
						sec += float(holds[hold_i])
					hold_i += 1
				if sec > 0.0:
					rests.append({"tok": start, "sec": sec, "before": key == "hold_before"})
					# ...AND THE VOICE IS TOLD, on the word the rest follows (`rest_after`), or it
					# reads straight on into the next word: "moved on to <!-- hesitation -->
					# Someone" came back "tə" - a "t" and a frame of schwa - with the rest cut in
					# after it (piper.py `REST_AFTER_FLOOR`, 2026-10-25)
					if key == "hold":
						after += sec
					elif not toks.is_empty():
						var prev: Dictionary = toks[toks.size() - 1]
						prev["rest_after"] = float(prev.get("rest_after", 0.0)) + sec
			# A HUM IS HELD, not spoken in passing - see Splice.HUM_SECONDS.
			var hum_key := String(w.text).to_lower()
			if Splice.HUM_SECONDS.has(hum_key):
				rests.append({"tok": start, "sec": 0.0, "before": false,
					"hum": float(Splice.HUM_SECONDS[hum_key])})
			# ghost's dictionary returns stress 0 for every phone of most
			# monosyllables, so no stress mark was ever emitted for them and the
			# model heard a flat reading. Promote the nucleus - but only for
			# CONTENT words, because eSpeak leaves function words unstressed and
			# promoting "the" to "ðˈʌ" is worse than leaving it alone. Phrasing
			# already made that distinction; w.stressed carries it.
			var lex: Array = []
			for i in ph.size():
				lex.append(int(st[i]) if i < st.size() else -1)
			if bool(w.get("stressed", false)) and not lex.has(1):
				var nucleus := Phonemes.stress_vowel(ph, st)
				if nucleus >= 0 and nucleus < lex.size():
					lex[nucleus] = 1
			# A token carries its SOURCE TEXT so the host can phonemize it with
			# eSpeak - whose transcriptions these voices were trained on - and
			# carries ghost's ARPAbet only as a fallback, or as an authored
			# [K AE T] override, which always wins.
			var arpa: Array = []
			for i in ph.size():
				# the stress digit lives in a parallel array; the ARPAbet path
				# needs it re-attached to the phone itself
				var d: int = lex[i]
				arpa.append(String(ph[i]) + (str(d) if d >= 0 else ""))
			# SEND THE REAL MARK. phonemes.gd already walks the terminal
			# punctuation off each word and records it verbatim (including the
			# case where a quote was hiding it - `early,"`); this used to
			# collapse it back to "." or "," via the coarse pause_after class,
			# which is where the reading lost its colons - heard as a comma -
			# and its question marks, heard as a full stop, so the interrogative
			# contour was never even asked for.
			#
			# pause_after stays as the fallback for a word whose mark has no
			# printable form (a line break), and the allow-list keeps anything
			# unexpected away from the voice's phoneme_id_map.
			var punct := String(w.get("punct", ""))
			if not PUNCT_ALLOWED.has(punct):
				punct = ""
				match String(w.pause_after):
					"stop": punct = "."
					"comma": punct = ","
			var tok := {"text": String(w.text), "cased": String(w.get("cased", w.text)), "punct": punct, "fallback": arpa}
			if after > 0.0:
				tok["rest_after"] = after
			if bool(w.get("literal", false)):
				tok["arpa"] = arpa
			# A WORD NO DICTIONARY HOLDS (the audit's UNKNOWN), spelled as written: eSpeak would be
			# guessing at it, so the host reads it as Wiktionary has it, its full vowels stressed
			# (lexicon.py - the user, 2026-10-16: cosine "co-seen", cotangent "co-angent")
			elif Phonemes.guessed(w):
				tok["rare"] = true
			# A WORD LEANED ON (`*so*`, `**so**`) is SPOKEN leaned on: the host holds its stressed
			# vowel longer and lifts the word a little (piper.py `EMPHASIS`). Sent only when set,
			# so an unmarked sentence is the request it always was.
			if stressed_at.has(flat):
				tok["emph"] = int(stressed_at[flat])
			toks.append(tok)
			# ONE SUBTITLE ENTRY PER SOURCE RUN. `2009` is three spoken words and
			# one thing on the page, so the words after the first in a rewritten
			# run do not get their own entry - they extend this one's END, and
			# the highlight sweeps the numeral across all three rather than
			# flashing it over the first syllable. See Phonemes.parse.
			var span := int(w.get("src_span", -1))
			if span >= 0 and not words.is_empty() \
					and int((words[words.size() - 1] as Dictionary).get("span", -1)) == span:
				(words[words.size() - 1] as Dictionary)["end"] = start
			else:
				# A run whose first word the phonemizer dropped would leave a
				# continuation with nothing to draw; show what is being said
				# rather than an empty card.
				var shown := String(w.get("display", w.text))
				words.append({"text": shown if not shown.is_empty() else String(w.text),
					"index": start, "end": start, "span": span, "sentence": sentence_no,
					"emph": int(w.get("emph", 0))})
		sentence_no += 1
		sentences += 1
		if sentences >= CHUNK_SENTENCES:
			out.append({"tokens": toks, "words": words, "holds": rests})
			toks = []
			words = []
			rests = []
			sentences = 0
	if not toks.is_empty():
		out.append({"tokens": toks, "words": words, "holds": rests})
	return {"chunks": out, "sentence_no": sentence_no}


## Each chunk of [param out] given its place in its paragraph (`plan_u`) and its paragraph's
## place in its section (`plan_v`), read off [param body], the passage the chunks were cut from.
static func place(out: Array, body: String) -> void:
	# Paragraph boundaries come from the SOURCE text (a blank line), which is the only place
	# they exist - Phonemes.parse hands back a flat run of sentences and knows nothing about
	# them. Counting sentence-final marks per paragraph maps one onto the other without
	# parsing the body twice.
	var per_para: Array = []
	# A BLANK LINE IS THE MARKER, BUT ONLY IF THE WRITER USED ANY. A script typed
	# with one newline between paragraphs - which is most of them, in a plain text
	# box with no formatting to lose - has no blank line anywhere in it, so this
	# found exactly one paragraph and handed the entire chapter a single arc that
	# descends from the first sentence to the last and never resets. That is half
	# of the "lower and lower and lower" report ([method Delivery.arc_semis] is the other
	# half); measured on one, the register fell monotonically across all sixteen
	# sentences instead of resetting six times.
	var para_mark := "\n\n"
	if body.find("\n\n") < 0:
		# ...but a line break is only a PARAGRAPH break if the lines are paragraphs.
		# Hard-wrapped prose breaks in the middle of sentences, and reading each of
		# those lines as a paragraph would reset the arc mid-sentence. The test is
		# whether the lines END the way sentences do - within a character or two of
		# the last one, so a closing quote or bracket still counts. Text that fails
		# it keeps the blank-line marker, finds no paragraphs, and is bounded by
		# PARA_CEILING instead, which is the right answer for prose that genuinely
		# carries no structure.
		var lines := 0
		var ended := 0
		for ln in body.split("\n", false):
			var t := String(ln).strip_edges()
			if t.is_empty():
				continue
			lines += 1
			var tail := t.substr(maxi(0, t.length() - 2))
			if tail.contains(".") or tail.contains("!") or tail.contains("?"):
				ended += 1
		if lines > 0 and float(ended) / float(lines) >= 0.6:
			para_mark = "\n"
	for para in body.split(para_mark, false):
		var t := String(para).strip_edges()
		if t.is_empty():
			continue
		var c := 0
		for ch in t:
			if ch == "." or ch == "!" or ch == "?":
				c += 1
		per_para.append(maxi(1, c))
	if per_para.is_empty():
		per_para = [maxi(1, out.size())]
	# ...and prose pasted as one unbroken block has no marker of either kind, so the
	# length of a paragraph is bounded whether the text says where they end or not.
	var capped: Array = []
	for n in per_para:
		var left := int(n)
		while left > PARA_CEILING:
			capped.append(PARA_CEILING)
			left -= PARA_CEILING
		capped.append(maxi(1, left))
	per_para = capped
	# sentence index -> (paragraph index, position within it)
	var pi := 0
	var within := 0
	for i in out.size():
		if within >= int(per_para[mini(pi, per_para.size() - 1)]) and pi < per_para.size() - 1:
			pi += 1
			within = 0
		var n := int(per_para[mini(pi, per_para.size() - 1)])
		# A ONE-SENTENCE PARAGRAPH SITS IN THE MIDDLE OF ITS OWN ARC, not at the start
		# of it. Placing it at 0 hands it the opening register of a paragraph it also
		# ends, so a run of them takes a constant lift - measured +2.3 semitones at Arc 1,
		# which is a transposition again, just a subtler one. The midpoint makes the
		# paragraph term neutral where the paragraph has no extent, and leaves the section
		# to supply all of the movement, which is the whole point of having one.
		out[i]["plan_u"] = 0.5 if n <= 1 else float(within) / float(n - 1)
		# ...and the paragraph's place in its section. A one-paragraph section would put
		# every paragraph at 0 again, which is the same trap one level up.
		var sp := pi % SECTION_PARAS
		out[i]["plan_v"] = float(sp) / float(maxi(1, SECTION_PARAS - 1))
		within += 1


## THE OUTRO MARK, in chunks: `{chunks, fade}`. The reading goes on past the mark only as far as
## the fade can carry it - enough fading chunks to fill [param outro] seconds (at least
## [constant OUTRO_MIN_FADE]) at a brisk reading pace, and one more, since the fade is cut on the
## clock, not on a word - and the rest are dropped BEFORE synthesis: text that would be cut is
## never made. `fade` is the fade's length, 0 when there is no mark.
static func trim_to_outro(chunks: Array, outro: float) -> Dictionary:
	var first := -1
	for i in chunks.size():
		if bool((chunks[i] as Dictionary).get("fade", false)):
			first = i
			break
	if first < 0:
		return {"chunks": chunks, "fade": 0.0}
	var fade := maxf(OUTRO_MIN_FADE, outro)
	var budget := fade * OUTRO_WORDS_PER_SECOND
	var words := 0.0
	var keep := first
	while keep < chunks.size() and words < budget:
		words += float(((chunks[keep] as Dictionary).get("words", []) as Array).size())
		keep += 1
	return {"chunks": chunks.slice(0, mini(keep + 1, chunks.size())), "fade": fade}


## WHERE THE READER IS, sentence by sentence ([method VoiceFX.near_plan]), written into
## each chunk of [param chunks] from [param from] on as `near` - read by the request (the softer
## voice) and by the marks that ease the room there. [param near_of] is a voice's Near dial
## (`(name) -> float`); [param voice] reads every chunk as that voice (the audition's chunks carry
## none). Taken when a chunk is REQUESTED, from the dials as they are then, and never rewritten
## behind a request: a sentence already made has its softer voice in it, and its distance has to
## match.
static func near(chunks: Array, from: int, near_of: Callable, voice := "") -> void:
	var ks := PackedFloat32Array()
	var who := PackedStringArray()
	var text := ""
	for c in chunks:
		var name := voice if not voice.is_empty() else String((c as Dictionary).get("speaker", ""))
		ks.append(float(near_of.call(name)))
		who.append(name)
		for w in (c as Dictionary).get("words", []):
			text += String((w as Dictionary).get("text", "")) + " "
	# same words, same moves - in the reading, the audition of it and the export alike
	var plan := VoiceFX.near_plan(ks, who, hash("near " + text))
	for i in range(maxi(from, 0), chunks.size()):
		(chunks[i] as Dictionary)["near"] = plan[i]


## THE PREDICTED TIMELINE: where each chunk is estimated to start along the reading, in seconds,
## and where the reading ends (one more than there are chunks). A scrub bar scaled by what has been
## DECODED grows as the reading is made, so its own length changed under the pointer; a timeline
## has to know how long the thing is before it plays it.
static func timeline(chunks: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var at := 0.0
	for c in chunks:
		out.append(at)
		var rest := 0.0
		for h in (c as Dictionary).get("holds", []):
			if h is Dictionary:
				rest += float((h as Dictionary).get("sec", 0.0))
		at += maxf(0.2, float(((c as Dictionary).get("words", []) as Array).size())
			* SCRUB_SECONDS_PER_WORD + rest)
	out.append(at)
	return out


## About where a reading started at chunk [param k] is: how many words with letters come before
## it (-1 for a reading from the top). A medium breaks ties between equally good matches of
## [method start_words] with it - see [method TabletScript.find_run].
static func start_index(chunks: Array, k: int) -> int:
	if k <= 0 or k >= chunks.size():
		return -1
	var n := 0
	for ci in k:
		for w in (chunks[ci] as Dictionary).get("words", []):
			if not TabletScript.norm(String((w as Dictionary).get("text", ""))).is_empty():
				n += 1
	return n


## The first words of chunk [param k], normalized - how a medium finds its place in a reading
## started there. Empty for a reading from the top.
static func start_words(chunks: Array, k: int) -> PackedStringArray:
	var out := PackedStringArray()
	if k <= 0 or k >= chunks.size():
		return out
	for ci in range(k, mini(k + 2, chunks.size())):
		for w in (chunks[ci] as Dictionary).get("words", []):
			var n := TabletScript.norm(String((w as Dictionary).get("text", "")))
			if not n.is_empty():
				out.append(n)
			if out.size() >= 6:
				return out
	return out


## [param chunk]'s words timed from the per-phone spans the host returned for it, in the take's own
## seconds - every word kept ([method bridge_words]). The backend hands back one entry per phone sent,
## in order, so the word spans recorded at plan time index straight into it. [param label] names the
## take in the log.
static func words_for(chunk: Dictionary, spans: Array, label: String) -> Array:
	if spans.is_empty():
		return []
	var by_index := {}
	for s in spans:
		by_index[int((s as Dictionary).get("index", -1))] = s
	var rows: Array = []
	# WHO SAYS IT rides with each word: the subtitles color each voice its own way
	var who := String(chunk.get("speaker", ""))
	for w in chunk["words"]:
		var span: Variant = by_index.get(int(w["index"]))
		# A run's card is up from its first word to its LAST - `end` is that word
		# when the entry covers a rewritten run, and the entry's own word when it
		# does not.
		var tail: Variant = by_index.get(int(w.get("end", w["index"])))
		if tail == null:
			tail = span
		rows.append({"text": String(w["text"]), "sentence": int(w["sentence"]),
			"emph": int(w.get("emph", 0)), "speaker": who,
			"t0": 0.0 if span == null else float((span as Dictionary).get("t0", 0.0)),
			"t1": 0.0 if tail == null else float((tail as Dictionary).get("t1", 0.0)),
			"ok": span != null})
	return bridge_words(rows, label)


## KEEP EVERY WORD, even one the aligner had no span for.
##
## Both paths used to `continue` past a word whose token the host did not return a span
## for, which deletes it from the karaoke line without a word anywhere about it. That is how a
## chapter render came back reading "an opponent who left the building in" with the year simply
## absent (the root cause was upstream - see TextNorm._expand_numbers - but this is what made it
## SILENT, and it would hide the next one just as well).
##
## A word with no span keeps its text and takes a timing interpolated across the gap between its
## nearest aligned neighbors, so the line reads correctly and the highlight sweeps through it at
## a plausible rate. The count is reported once per take, because an aligner that misses words is
## a real fault worth seeing in the log even when the subtitle no longer loses them.
static func bridge_words(rows: Array, label: String) -> Array:
	var missing := 0
	var n := rows.size()
	for i in n:
		if bool((rows[i] as Dictionary)["ok"]):
			continue
		missing += 1
		# The aligned neighbors either side, and how many unaligned words share the gap.
		var lo := i - 1
		while lo >= 0 and not bool((rows[lo] as Dictionary)["ok"]):
			lo -= 1
		var hi := i + 1
		while hi < n and not bool((rows[hi] as Dictionary)["ok"]):
			hi += 1
		var t0: float = float((rows[lo] as Dictionary)["t1"]) if lo >= 0 else 0.0
		var t1: float = float((rows[hi] as Dictionary)["t0"]) if hi < n else t0 + 0.25
		if t1 <= t0:
			t1 = t0 + 0.25
		var run := float(maxi(1, (hi if hi < n else n) - (lo + 1)))
		var k := float(i - (lo + 1))
		var step := (t1 - t0) / run
		var row: Dictionary = rows[i]
		row["t0"] = t0 + step * k
		row["t1"] = t0 + step * (k + 1.0)
	if missing > 0:
		push_warning("ghost/voice: %s - the aligner returned no span for %d of %d words; "
			% [label, missing, n] + "their subtitle timing is interpolated (text is intact)")
	var out: Array = []
	for r in rows:
		var d: Dictionary = r
		out.append({"text": d["text"], "sentence": d["sentence"], "t0": d["t0"], "t1": d["t1"],
			"emph": int(d.get("emph", 0)), "speaker": String(d.get("speaker", ""))})
	return out
