extends RefCounted
class_name ReadingPlan

## ReadingPlan - what a reading will say, worked out from its words before a sound is made: the script cut into
## chunks of a sentence each, every chunk carrying its speaker, its tokens for the voice host, its words for the
## subtitles, its hesitations, its delivery and its place in its paragraph; where the outro mark's fade starts and
## how long it is; the scrub bar's estimate of where each sentence starts; and, once a chunk is made, its words
## timed from the spans the host hands back.
##
## A function of what it is handed (next/structure.md, step 17): the text, the title announced first and what is
## asked go in, and the plan comes out, so the live window, the scrub, the audition and the export plan the same
## words the same way and none can disturb another.
##
## What is asked (`ask` in [method make] and [method passages]):
## - `reader` - the voice a cue naming [constant Manuscript.NARRATOR] goes to (the cast's first);
## - `hesitate` - whether the script's hesitation marks rest at all (the Hesitate box);
## - `bare` - how long, in seconds, a hesitation that names no length rests;
## - `outro` - the Outro's length, in seconds: what an outro mark's fade can carry.
##
## A reading that grows plans each new piece of its text as a continuation: [method make]'s [param from_sentence]
## carries the sentence count on (the subtitles window by it), and the plan says where the next piece starts
## (`sentences`).

# The punctuation marks the host is allowed to receive. A mark is phonemized as part of its word, so it needs an
# entry in the selected voice's phoneme_id_map (piper.py raises on one that has none); anything else a word might
# end with (a bare newline, an em dash, a stray glyph) falls back to the coarse pause_after mapping.
const PUNCT_ALLOWED := [".", ",", "!", "?", ":", ";"]
# One sentence per chunk: two made every tone or pace change wait for the larger buffer to drain, and the
# inter-sentence gap is inserted at chunk boundaries too (see ReadingJoin.add).
const CHUNK_SENTENCES := 1
## Give every chunk its place in the reading, so the delivery plan can be a plan. `_discourse_plan` shapes a
## sentence by where it sits in the unit it was handed, and that unit is one request, one sentence
## (CHUNK_SENTENCES = 1): without this every sentence is position 0 of 1, final lengthening never fires and the
## "arc" is a constant offset.
##
## Two nested levels, because discourse structure is nested and the size of a pitch reset scales with the depth of
## the boundary it follows (Grosz & Sidner; Hirschberg & Nakatani). `u` is the sentence's place in its paragraph
## and `v` its paragraph's place in a run of them; the second level is what a chapter of one-sentence paragraphs
## needs, since at `u` the paragraph collapses to a point. Sections are runs of SECTION_PARAS paragraphs, so the
## slow movement is phase-locked to the prose the way the fast one is.
const SECTION_PARAS := 5
## ...and the longest run of sentences that may be called one paragraph: a paragraph is where the pitch arc resets,
## so an unbroken block is an arc with no reset. Eight is a long paragraph; past that the text is not telling us
## where its paragraphs are (the same guard SECTION_PARAS is a level up).
const PARA_CEILING := 8
## The estimate the scrub bar is laid out by: a reading pace, plus every rest at its own length.
const SCRUB_SECONDS_PER_WORD := 0.38
const OUTRO_MIN_FADE := 0.5
## Enough words to fill a fade - a brisk pace, so the fade never runs out of voice early.
const OUTRO_WORDS_PER_SECOND := 3.5


## The whole plan of [param body] (the words as the voice reads them - see [method TextWalk.spoken]) with
## [param title] announced first: `{chunks, note, fade, sentences}` - the chunks, what the plan noticed about the
## script for the line that reports it ("" for nothing), the outro mark's fade in seconds (0 with no mark) and the
## sentence the next piece of a growing reading starts at.
##
## The speaker cues are resolved here and nowhere else: past this point a chunk carries a speaker's name and every
## consumer (the request, the seam, the room) reads its settings from that.
static func make(body: String, title: String, ask: Dictionary, from_sentence := 0) -> Dictionary:
	var out: Array = []
	var sentence_no := from_sentence
	var bare: PackedStringArray = PackedStringArray()
	for seg in passages(body, title, ask):
		var text := String((seg as Dictionary)["text"])
		var who := String((seg as Dictionary)["speaker"])
				# Asked per passage rather than of the whole box, so a macro in a stripped authoring note is not reported as
				# missing from the reading.
		bare.append_array(TextNorm.unresolved_macros(text))
		var part := cut(text, sentence_no, (seg as Dictionary).get("holds", []))
		var chunks: Array = part["chunks"]
		sentence_no = int(part["sentence_no"])
		if chunks.is_empty():
			continue
				# Placement is per passage: a speaker's turn is its own piece of discourse, opening in its own register, so
				# measuring it against the whole chapter would hand the second voice the contour of a paragraph it is not in.
		place(chunks, text)
				# ...the turn comes in over the one before: its first sentence is that one's on the screen too, so they read as one line, each word lit in its own voice's color ([ReadingJoin])
		if not out.is_empty() and (float((seg as Dictionary).get("over", -1.0)) >= 0.0 or bool((seg as Dictionary).get("together", false))):
			var head: Dictionary = chunks[0]
			if bool((seg as Dictionary).get("together", false)):
				head["together"] = true
			else:
				head["over"] = float((seg as Dictionary)["over"])
			var with_prev: Array = ((out.back() as Dictionary).get("words", [])) as Array
			var prev_sentence := int((with_prev[0] as Dictionary).get("sentence", -1)) if not with_prev.is_empty() else -1
			if prev_sentence >= 0:
				for w in head.get("words", []):
					(w as Dictionary)["sentence"] = prev_sentence
		var fade := bool((seg as Dictionary).get("fade", false))
		var leans: Array = (seg as Dictionary).get("leans", [])
		var heard := String((seg as Dictionary).get("heard", ""))
		var cursor := 0
		for c in chunks:
			(c as Dictionary)["speaker"] = who
			if fade:
				(c as Dictionary)["fade"] = true
						# ...heard through what its turn says ([constant Manuscript.HEARD]): every chunk of it
			if not heard.is_empty():
				(c as Dictionary)["heard"] = heard
						# A chunk's delivery is the one marked where its first word is in the passage
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
		# what the script needs fixing, for the line someone is looking at with their hand on Play: TextNorm has already
		# warned into the log, but a macro with no default is words missing from a reading about to be made
	var note := ""
	if not bare.is_empty():
		note = "%d macro(s) will not read as intended: %s - write ${NAME:value}" % [bare.size(), ", ".join(bare)]
	return {"chunks": trimmed["chunks"], "note": note, "fade": trimmed["fade"], "sentences": sentence_no}


## Split a script into passages by speaker: `[{speaker, text, fade, leans, holds}]`. Text before the first cue
## (and a script with no cues at all) is the reader's ([param ask] `reader`).
##
## Also where the hesitations are resolved, as the last place that still sees the markers in their text: each
## becomes a [constant TextNorm.HOLD_MARK] welded to the word it follows (or leads, when nothing comes before it in
## the passage), and its length goes on the passage's own `holds`, in the same order, for [method cut] to hand back
## out. With [param ask] `hesitate` off they are removed. Every other comment is an authoring note and goes too. A
## passage's rests are its own: a sentinel the phonemizer loses costs that passage its lengths, never every
## passage after it.
static func passages(body: String, title: String, ask: Dictionary) -> Array:
	var kept: Array = []
	var on := bool(ask.get("hesitate", true))
	var bare := float(ask.get("bare", 0.0))
	var reader := String(ask.get("reader", Manuscript.NARRATOR))
		# The title is read first, as a heading of its own, by the voice that opens the chapter. The frontmatter as
		# metadata is never spoken, only the title's value. Not twice: a chapter that already opens on its title keeps
		# that one. A chapter read off a screen announces nothing (its walk hands no title).
	var first := true
	var fading := false
	for p in Manuscript.passages(body):
		var raw := String((p as Dictionary)["text"])
				# the first passage with anything in it: a chapter opening on a cue has an empty one before it, and a title
				# put there would invent a narrator to read it
		if first and not title.is_empty() and not raw.strip_edges().is_empty():
			var lead := raw.strip_edges().get_slice("\n", 0).lstrip("#").strip_edges()
			if lead.to_lower() != title.to_lower():
				raw = "# %s\n\n%s" % [title, raw]
		if not raw.strip_edges().is_empty():
			first = false
				# a log entry's time gets its pause before the markers are read, so it is a marker
		var t := Manuscript.mark_timestamp_pauses(raw)
				# The outro mark splits its passage: what comes after it is read fading (see [method trim_to_outro]), and so
				# is every passage after that. The first mark counts.
		var parts := [t]
		var om: RegExMatch = null
		if not fading:
			om = Manuscript._rx(Manuscript.OUTRO).search(t)
		if om != null:
			parts = [t.substr(0, om.get_start()), t.substr(om.get_end())]
		var name := String((p as Dictionary)["speaker"])
				# Heard through something: the turn's own mark, which every piece of it keeps (an outro mark splits a turn,
				# never the line it comes down)
		var hm := Manuscript._rx(Manuscript.HEARD).search(t)
		var heard := hm.get_string(1).to_lower() if hm != null and VoiceFX.HEARD.has(hm.get_string(1).to_lower()) else ""
		for k in parts.size():
			if k == 1:
				fading = true
						# Voices over each other: a turn's own mark, which a later piece of it does not take up
			var over := -1.0
			var together := false
			if k == 0:
				var om2 := Manuscript._rx(Manuscript.OVER).search(String(parts[k]))
				if om2 != null:
					over = float(om2.get_string(1)) if not om2.get_string(1).is_empty() else Manuscript.OVER_BARE
				together = Manuscript._rx(Manuscript.TOGETHER).search(String(parts[k])) != null
			var res := resolve_marks(String(parts[k]), on, bare)
			var out := String(res["text"])
			# A passage of nothing but hesitations: its rests would have no word to sit on.
			if not out.replace(TextNorm.HOLD_MARK, "").strip_edges().is_empty():
				kept.append({"speaker": reader if name == Manuscript.NARRATOR else name, "text": out,
					"fade": fading, "leans": res["leans"], "holds": res["holds"], "over": over, "together": together,
					"heard": heard})
		# A tablet's opening run (wake, open the browser, type) comes after the intro, end to end: the intro is the
		# tablet lying dark on the desk, and its rest is the run's own
	return kept


## A passage's marks resolved: `{text, holds, leans}`. Every hesitation (and the tablet's action rests) becomes a
## [constant TextNorm.HOLD_MARK] welded to the word before it (or leading the next, when nothing precedes it), with
## its length in `holds`; a delivery mark is noted where it falls in `leans` (see [method Delivery.leans_of]);
## every other comment goes.
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
				# The tablet's hand is not a hesitation: its rest is the time a tap or typed address takes, so it stays when the
				# Hesitate box is off
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
				# Welded, never left standing: a sentinel alone between two spaces is a token of its own, and a non-word token
				# confuses the sentence splitter. Trailing whitespace is stepped over so it lands after the previous word.
		var head := out.rstrip(" \t\n")
		out = head + TextNorm.HOLD_MARK + out.substr(head.length())
		holds.append(secs)
	out += t.substr(at)
	leans = Delivery.leans_of(out, leans)
		# Sentinels with nothing before them in the passage lead the next word instead: close the gap so they weld on.
	var body_t := out.strip_edges()
	var n := 0
	while body_t.begins_with(TextNorm.HOLD_MARK):
		n += 1
		body_t = body_t.substr(1).strip_edges(true, false)
		# ...after a heading's `#`s, never before them: `#` is only markup at the start of a line, and a sentinel in
		# front of it would leave "##" to be read as a word
	var marks := ""
	if n > 0 and body_t.begins_with("#"):
		var k := 0
		while k < body_t.length() and body_t[k] == "#":
			k += 1
		marks = body_t.substr(0, k) + " "
		body_t = body_t.substr(k).strip_edges(true, false)
	var said := marks + TextNorm.HOLD_MARK.repeat(n) + body_t
		# A delivery mark is where it falls in what is returned: it was noted in `out` before the passage's leading
		# whitespace went, so it is shifted to match (tests/reading/multi_voice_check.gd).
	var gone := out.strip_edges(false, true).length() - said.length()
	if gone != 0:
		for lean in leans:
			(lean as Array)[0] = maxi(0, int((lean as Array)[0]) - gone)
	return {"text": said, "holds": holds, "leans": leans}


## One passage, cut at sentence boundaries: `{chunks, sentence_no}`, each chunk `{tokens, words, holds}`.
## [param holds] are the lengths of its hesitations in text order ([method passages]), handed out as the phonemizer
## meets the sentinels that mark their places. `sentence_no` runs across the whole script, not per passage:
## [Subtitles] windows the display by that index, and two speakers sharing a number would be drawn at once.
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
						# Hesitations, in the order the phonemizer met their sentinels (the order [method passages] listed their
						# lengths in).
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
										# ...and the voice is told, on the word the rest follows (`rest_after`), or it reads straight on
										# into the next word (piper.py `REST_AFTER_FLOOR`)
					if key == "hold":
						after += sec
					elif not toks.is_empty():
						var prev: Dictionary = toks[toks.size() - 1]
						prev["rest_after"] = float(prev.get("rest_after", 0.0)) + sec
						# A hum is held, not spoken in passing - see Splice.HUM_SECONDS.
			var hum_key := String(w.text).to_lower()
			if Splice.HUM_SECONDS.has(hum_key):
				rests.append({"tok": start, "sec": 0.0, "before": false,
					"hum": float(Splice.HUM_SECONDS[hum_key])})
						# ghost's dictionary returns stress 0 for every phone of most monosyllables, so no stress mark was
						# emitted and the model heard a flat reading. Promote the nucleus, but only for content words: eSpeak
						# leaves function words unstressed. Phrasing already made that distinction; w.stressed carries it.
			var lex: Array = []
			for i in ph.size():
				lex.append(int(st[i]) if i < st.size() else -1)
			if bool(w.get("stressed", false)) and not lex.has(1):
				var nucleus := Phonemes.stress_vowel(ph, st)
				if nucleus >= 0 and nucleus < lex.size():
					lex[nucleus] = 1
						# A token carries its source text so the host can phonemize it with eSpeak (whose transcriptions
						# these voices were trained on) and carries ghost's ARPAbet only as a fallback, or as an authored
						# [K AE T] override, which always wins.
			var arpa: Array = []
			for i in ph.size():
								# the stress digit lives in a parallel array; the ARPAbet path needs it re-attached to the phone
				var d: int = lex[i]
				arpa.append(String(ph[i]) + (str(d) if d >= 0 else ""))
						# Send the real mark: phonemes.gd walks the terminal punctuation off each word and records it verbatim
						# (including where a quote hid it), so colons and question marks reach the voice as themselves.
						# pause_after stays as the fallback for a word whose mark has no printable form (a line break), and the
						# allow-list keeps anything unexpected away from the voice's phoneme_id_map.
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
						# A word no dictionary holds (the audit's UNKNOWN), spelled as written: eSpeak would be guessing, so the
						# host reads it as Wiktionary has it, its full vowels stressed (lexicon.py)
			elif Phonemes.guessed(w):
				tok["rare"] = true
						# A word leaned on (`*so*`, `**so**`) is spoken leaned on: the host holds its stressed vowel longer and
						# lifts the word a little (piper.py `EMPHASIS`). Sent only when set.
			if stressed_at.has(flat):
				tok["emph"] = int(stressed_at[flat])
			toks.append(tok)
						# One subtitle entry per source run: `2009` is three spoken words and one thing on the page, so the
						# words after the first in a rewritten run extend this one's end and the highlight sweeps across all
						# three. See Phonemes.parse.
			var span := int(w.get("src_span", -1))
			if span >= 0 and not words.is_empty() \
					and int((words[words.size() - 1] as Dictionary).get("span", -1)) == span:
				(words[words.size() - 1] as Dictionary)["end"] = start
			else:
								# A run whose first word the phonemizer dropped would leave a continuation with nothing to draw;
								# show what is being said rather than an empty card.
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


## Each chunk of [param out] given its place in its paragraph (`plan_u`) and its paragraph's place in its section
## (`plan_v`), read off [param body], the passage the chunks were cut from.
static func place(out: Array, body: String) -> void:
		# Paragraph boundaries come from the source text (a blank line), the only place they exist: Phonemes.parse
		# hands back a flat run of sentences. Counting sentence-final marks per paragraph maps one onto the other.
	var per_para: Array = []
		# A blank line is the marker, but only if the writer used any. A script typed with one newline between
		# paragraphs has no blank line and would be one paragraph with a single arc that never resets
		# ([method Delivery.arc_semis] is the other half of that).
	var para_mark := "\n\n"
	if body.find("\n\n") < 0:
				# ...but a line break is only a paragraph break if the lines are paragraphs: hard-wrapped prose breaks
				# mid-sentence. The test is whether the lines end the way sentences do (within a character or two of the
				# last one, so a closing quote or bracket counts). Text that fails keeps the blank-line marker and is
				# bounded by PARA_CEILING instead.
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
		# ...and prose pasted as one unbroken block has no marker of either kind, so a paragraph's length is bounded
		# whether the text says where they end or not.
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
				# A one-sentence paragraph sits in the middle of its own arc, not at the start: placing it at 0 would give a
				# run of them a constant lift (+2.3 semitones at Arc 1). The midpoint makes the paragraph term neutral where
				# the paragraph has no extent and leaves the section to supply the movement.
		out[i]["plan_u"] = 0.5 if n <= 1 else float(within) / float(n - 1)
				# ...and the paragraph's place in its section: a one-paragraph section would put every paragraph at 0 again.
		var sp := pi % SECTION_PARAS
		out[i]["plan_v"] = float(sp) / float(maxi(1, SECTION_PARAS - 1))
		within += 1


## The outro mark, in chunks: `{chunks, fade}`. The reading goes on past the mark only as far as the fade can carry
## it: enough fading chunks to fill [param outro] seconds (at least [constant OUTRO_MIN_FADE]) at a brisk reading
## pace, and one more since the fade is cut on the clock, not on a word. The rest are dropped before synthesis.
## `fade` is the fade's length, 0 when there is no mark.
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


## Where the reader is, sentence by sentence ([method VoiceFX.near_plan]), written into each chunk of
## [param chunks] from [param from] on as `near`: read by the request (the softer voice) and by the marks that ease
## the room there. [param near_of] is a voice's Near dial (`(name) -> float`); [param voice] reads every chunk as
## that voice (the audition's chunks carry none). Taken when a chunk is requested, from the dials as they are
## then, and never rewritten behind a request: a sentence already made has its softer voice in it.
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


## The predicted timeline: where each chunk is estimated to start along the reading, in seconds, and where the
## reading ends (one more than there are chunks). A scrub bar scaled by what has been decoded would change length
## under the pointer as the reading is made.
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


## About where a reading started at chunk [param k] is: how many words with letters come before it (-1 for a
## reading from the top). A medium breaks ties between equally good matches of [method start_words] with it - see
## [method TabletScript.find_run].
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


## [param chunk]'s words timed from the per-phone spans the host returned for it, in the take's own seconds, every
## word kept ([method bridge_words]). The backend hands back one entry per phone sent, in order, so the word spans
## recorded at plan time index straight into it. [param label] names the take in the log.
static func words_for(chunk: Dictionary, spans: Array, label: String) -> Array:
	if spans.is_empty():
		return []
	var by_index := {}
	for s in spans:
		by_index[int((s as Dictionary).get("index", -1))] = s
	var rows: Array = []
		# who says it rides with each word: the subtitles color each voice its own way
	var who := String(chunk.get("speaker", ""))
	for w in chunk["words"]:
		var span: Variant = by_index.get(int(w["index"]))
				# A run's card is up from its first word to its last: `end` is that word when the entry covers a rewritten
				# run, and the entry's own word when it does not.
		var tail: Variant = by_index.get(int(w.get("end", w["index"])))
		if tail == null:
			tail = span
		rows.append({"text": String(w["text"]), "sentence": int(w["sentence"]),
			"emph": int(w.get("emph", 0)), "speaker": who,
			"t0": 0.0 if span == null else float((span as Dictionary).get("t0", 0.0)),
			"t1": 0.0 if tail == null else float((tail as Dictionary).get("t1", 0.0)),
			"ok": span != null})
	return bridge_words(rows, label)


## Keep every word, even one the aligner had no span for: dropping it would delete it from the karaoke line
## silently. A word with no span keeps its text and takes a timing interpolated across the gap between its nearest
## aligned neighbors. The count is reported once per take, since an aligner that misses words is a fault worth
## seeing in the log.
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
