extends SceneTree

## script_marks_check - that every mark the script editor offers DOES what it says.
##
## [ScriptMarks] is a list of promises: "click this and the reading will rest here", "this
## hands the text to Emily". It implements none of them - [Manuscript], [TextNorm] and
## [Phonemes] do - so the failure this exists for is DRIFT: a registry entry whose example no
## longer means anything to the parser that is supposed to read it, which looks exactly like
## a working palette button. So every entry's example is inserted and the REAL parser is asked
## what it makes of it, and an entry with no check here fails too - a new mark has to come
## with its proof.
##
## Also held: each entry's highlight pattern recognizes its own example (the color on screen
## is the same claim), the insertion rules (a selection becomes the fill, the fill is left
## selected, an own-line mark gets its own line, one undo step), and the highlighter coloring
## a multi-line picture description and leaving prose plain.
##
## A CARDS BRIEF HAS A PALETTE TOO (2026-10-12, the user: "why are all of the supported macros and
## features missing from 'cards' editor mode?"), and each mark offered there is held to what it
## says of a BRIEF, which is not what it says of a script: a speaker cue is a voice of the show, a
## note to self never reaches an agent and a macro reaches them as its default ([method
## CardPrompts.brief] - the control is the brief before it, which still carries both), a
## hesitation, a delivery and a stressed word survive from a line the brief dictates into the
## reader's passage and the reader is told to keep them (italic and bold as two levels of stress,
## never flattened into one), such a line is still known as the brief's own, and a card is colored
## as one only inside the deck. What is NOT offered is held too: a
## passage keeps no bracket, which is why the inline pronunciation is left out.
##
## Run: godot --headless --path . --script tests/notes/script_marks_check.gd

var fails := 0
var checks := 0


func _init() -> void:
	_registry_shape()
	_patterns_match_examples()
	_parsers_agree()
	_cards_brief()
	_insertion()
	_highlighter()
	if fails == 0:
		print("script_marks_check: ALL OK (%d checks)" % checks)
	else:
		print("script_marks_check: %d FAILURE(S) of %d checks" % [fails, checks])
	quit(1 if fails > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("script_marks_check: FAIL  " + msg)


func _registry_shape() -> void:
	for k in ScriptMarks.REGISTRY:
		var e: Dictionary = ScriptMarks.REGISTRY[k]
		for f in ["label", "group", "blurb", "before", "fill", "after", "line", "modes", "pattern"]:
			_ok(e.has(f), "%s has no `%s`" % [k, f])
		_ok(ScriptMarks.GROUPS.has(e.get("group", "")), "%s names an unknown group" % k)
		_ok(String(e.get("line", "")) in ["", "own", "start"], "%s has an unknown line rule" % k)
		for m in e.get("modes", []):
			_ok(m in ["generative", "synthesis", "cards"], "%s names an unknown mode %s" % [k, m])
		for m in e.get("blurbs", {}):
			_ok((e["modes"] as Array).has(m) and not String(e["blurbs"][m]).is_empty(),
				"%s words itself for %s, a panel it is not offered in" % [k, m])
		_ok(String(e.get("within", "")) in ["", "deck"], "%s names an unknown `within`" % k)
		var re := RegEx.new()
		_ok(re.compile(String(e.get("pattern", ""))) == OK, "%s's pattern does not compile" % k)
	# Both panels have something to offer.
	_ok(ScriptMarks.for_mode("generative").size() > ScriptMarks.for_mode("synthesis").size()
			and ScriptMarks.for_mode("synthesis").size() > 0,
		"the per-mode palettes are not what they should be")
	# ...and so has a brief: its own marks, and none that need a page or a tablet
	var cards := ScriptMarks.for_mode("cards")
	for k in ["speaker", "deck", "card", "suit", "note", "macro", "hesitation", "delivery"]:
		_ok(cards.has(k), "a Cards brief is not offered `%s`" % k)
	for k in cards:
		_ok(not String(ScriptMarks.REGISTRY[k]["group"]) in ["pictures", "tablet", "pronunciation"],
			"a Cards brief is offered `%s`, which nothing there reads" % k)
	_ok(ScriptMarks.blurb("speaker", "cards") != ScriptMarks.blurb("speaker", "generative")
			and ScriptMarks.blurb("speaker", "generative") == String(ScriptMarks.REGISTRY["speaker"]["blurb"]),
		"a mark does not say what it does in a brief")


## THE COLOR IS A CLAIM TOO: the highlight pattern must find the whole example, on a line
## of its own inside prose (the own-line marks are anchored to a line).
func _patterns_match_examples() -> void:
	for k in ScriptMarks.REGISTRY:
		var e: Dictionary = ScriptMarks.REGISTRY[k]
		var ex := ScriptMarks.example(k)
		var doc := "Some prose before.\n\n%s%s\n\nSome prose after." % [
			"" if String(e["line"]) != "start" else "", ex + ("The line goes on." if k == "timestamp" else "")]
		var re := RegEx.new()
		re.compile(String(e["pattern"]))
		var hit := false
		for m in re.search_all(doc):
			var s := m.get_string()
			if s.strip_edges() == ex.strip_edges() or (k == "heading" and s.begins_with(ex)) \
					or (k == "timestamp" and ex.begins_with(s.strip_edges())):
				hit = true
		_ok(hit, "%s's pattern does not find its own example %s" % [k, ex.c_escape()])


func _kinds(d: Dictionary) -> Array:
	var out := []
	for a in d["actions"]:
		out.append(String(a["kind"]))
	return out


## THE PROOF: each example, read by the parser of record. A key missing from this match is a
## failure, so a new entry cannot ship unverified.
func _parsers_agree() -> void:
	for k in ScriptMarks.REGISTRY:
		var e: Dictionary = ScriptMarks.REGISTRY[k]
		var ex := ScriptMarks.example(k)
		var fill := String(e["fill"])
		match k:
			"speaker":
				var body := "Before.\n%s\nAfter.\n" % ex
				_ok(Manuscript.speakers(body).has(fill), "a speaker cue is not a speaker")
				var ps := Manuscript.passages(body)
				_ok(ps.size() == 2 and String(ps[1]["speaker"]) == fill
						and String(ps[1]["text"]).strip_edges() == "After.",
					"a speaker cue did not hand the text after it over")
			"hesitation", "hesitation_timed":
				var h := Manuscript.hesitations("Wait %s for it." % ex)
				_ok(h.size() == 1, "%s is not a hesitation" % k)
				if h.size() == 1:
					var want := -1.0 if fill.is_empty() else float(fill)
					_ok(is_equal_approx(float(h[0]["seconds"]), want),
						"%s rests %s, not %s" % [k, h[0]["seconds"], want])
			"outro":
				# Read here by the parsers that see it; the fade itself is the Generative panel's,
				# gated in multi_voice_check (_check_outro_mark).
				_ok(RegEx.create_from_string(Manuscript.OUTRO).search("A %s B." % ex) != null,
					"the outro example is not the outro mark")
				_ok(not _words(Manuscript.unspoken("Before. %s After." % ex)).has("outro"),
					"the outro mark would be spoken")
				_ok(TabletScript.speakable("<!-- url: a.test -->\n\nOne. %s Two.\n" % ex).contains(ex),
					"a tablet chapter loses the outro mark before the voice sees it")
			"url":
				var d := TabletScript.parse("%s\n\nText.\n" % ex)
				_ok((d["pages"] as Array).size() == 1 and String(d["pages"][0]["url"]) == fill,
					"a url mark does not open a page at %s" % fill)
			"search":
				var d := TabletScript.parse("<!-- url: engine.test -->\n\n# Engine\n\n%s\n\nA result.\n" % ex)
				_ok(_kinds(d).has("search") and String((d["pages"] as Array).back()["query"]) == fill,
					"a search mark does not search for '%s'" % fill)
			"new_tab":
				_ok(_kinds(TabletScript.parse("<!-- url: a.test -->\n\nText.\n\n%s\n<!-- url: b.test -->\n\nMore.\n" % ex)).has("tab"),
					"a new tab mark opens no tab")
			"back":
				var d := TabletScript.parse("<!-- url: a.test -->\n\nOne.\n\n<!-- url: b.test -->\n\nTwo.\n\n%s\n" % ex)
				_ok(_kinds(d).has("back"), "a back mark goes nowhere")
			"redirect":
				var d := TabletScript.parse("<!-- url: a.test -->\n\n[Go](b.test)\n\n%s\n<!-- url: b.test -->\n\nThere.\n" % ex)
				var hops := []
				for a in d["actions"]:
					if a["kind"] == "link":
						hops = a.get("hops", [])
				_ok(hops.size() == TabletScript.REDIRECT_HOPS, "a redirect mark sends the tap through no hops")
			"notify":
				var d := TabletScript.parse("<!-- url: a.test -->\n\nOne. %s Two.\n" % ex)
				var notes: Array = d["notes"]
				_ok(notes.size() == 1 and String(notes[0]["sender"]) == "Sender" and String(notes[0]["title"]) == "Subject"
					and String(notes[0]["body"]) == "A line of the message", "a notify mark makes no banner")
				_ok(notes.size() == 1 and int(notes[0]["after"]) == 1, "a banner is not timed from the word after it")
				_ok(not String(d["speakable"]).contains("Subject"), "a notification is read aloud")
			"landscape", "portrait":
				var pre := "<!-- landscape -->\n" if k == "portrait" else ""
				var d := TabletScript.parse("<!-- url: a.test -->\n%s%s\n\nText.\n" % [pre, ex])
				var to := -1
				for a in d["actions"]:
					if a["kind"] == "rotate":
						to = int(a["to"])
				_ok(to == (1 if k == "landscape" else 0), "%s does not turn to %s" % [k, k])
			"skip":
				var sp := TabletScript.speakable("<!-- url: a.test -->\n\nRead this. %s Not this.\n" % ex)
				_ok(sp.contains("Read this") and not sp.contains("Not this"), "a skip mark does not stop the reading")
			"filler":
				var d := TabletScript.parse("<!-- url: a.test -->\n\nText.\n\n%s\n" % ex)
				var n := 0
				for b in (d["pages"][0]["blocks"] as Array):
					if b["kind"] == "filler":
						n += int(b["n"])
				_ok(n == int(fill), "a filler mark does not put %s stories in" % fill)
			"timestamp":
				var t := Manuscript.mark_timestamp_pauses(ex + "The subject was moved.")
				_ok(Manuscript.hesitations(t).size() == 1, "a log-entry time gets no rest")
			"hum":
				# Read off the source, where the held hums are (Splice.HUM_SECONDS)
				var word := fill.to_lower().rstrip(".!?…")
				var src := FileAccess.get_file_as_string("res://src/voice/splice.gd")
				var m := RegEx.create_from_string("const HUM_SECONDS := \\{([^}]*)\\}").search(src)
				_ok(m != null and m.get_string(1).contains("\"%s\":" % word),
					"the hum example is not a held hum")
			"image", "image_full", "image_left", "sketch":
				var imgs := Manuscript.images("Prose.\n\n%s\n\nMore prose.\n" % ex)
				_ok(imgs.size() == 1 and String(imgs[0]["prompt"]) == fill,
					"%s is not a picture of '%s': %s" % [k, fill, imgs])
				if imgs.size() == 1:
					var want: String = {"image": "inline", "image_full": "full", "image_left": "inline",
						"sketch": "sketch"}[k]
					_ok(String(imgs[0]["placement"]) == want,
						"%s is placed %s, not %s" % [k, imgs[0]["placement"], want])
					if k == "image_left":
						_ok(String(imgs[0].get("side", "")) == "left", "a left pin is not left")
			"phonetic":
				var ws: Array = Phonemes.parse("The %s sat." % ex)[0]
				_ok(ws.size() == 3 and bool(ws[1].get("literal", false))
						and (ws[1]["phones"] as Array) == ["K", "AE", "T"],
					"an inline pronunciation is not read as its phonemes")
			"macro":
				var dflt := fill.get_slice(":", 1)
				_ok(TextNorm.normalize("Chapter %s." % ex) == TextNorm.normalize("Chapter %s." % dflt),
					"a macro does not read as its default")
			"deck", "suit", "card":
				var body := "A show.\n\n%s\n\n%s\n%s\n\n## The host\n\n- quick with a joke\n" % [
					ScriptMarks.example("deck"), ScriptMarks.example("suit"), ScriptMarks.example("card")]
				var deck := CardDeck.parse(body)
				_ok(deck.size() == 1 and String(deck[0]["name"]) == "The Tower"
						and String(deck[0]["meaning"]).begins_with("sudden upheaval")
						and String(deck[0]["group"]) == "Major Arcana",
					"the deck's marks do not make a deck of one card in its suit: %s" % str(deck))
				# the control: the same item under any other heading is no card
				_ok(CardDeck.parse("## The host\n\n%s\n" % ScriptMarks.example("card")).is_empty(),
					"a list item outside the Cards section is a card")
			"heading":
				var b := Manuscript.blocks(ex + "\n\nText.\n")
				_ok(b.size() > 0 and String(b[0]["kind"]) == "heading"
						and String(b[0]["text"]) == fill, "a heading is not a heading")
			"scene_line":
				_ok(Manuscript.is_scene_line(ex), "a scene line is not a scene line")
			"italic", "bold":
				var want := TextNorm.EMPH_I if k == "italic" else TextNorm.EMPH_B
				var ws: Array = Phonemes.parse("A %s word." % ex)[0]
				var lit := false
				var spoken := PackedStringArray()
				for w in ws:
					spoken.append(String(w["text"]))
					if int(w.get("emph", 0)) & want:
						lit = true
				_ok(lit, "%s does not reach the subtitle as emphasis" % k)
				_ok(not "".join(spoken).contains("*"), "%s's marks are spoken" % k)
			"rule":
				var b := Manuscript.blocks("One.\n\n%s\n\nTwo.\n" % ex)
				_ok(b.size() == 3 and String(b[1]["kind"]) == "rule", "a scene break is not a rule")
			"note":
				var b := Manuscript.blocks("Before %s after.\n" % ex)
				_ok(b.size() == 1 and not String(b[0]["text"]).contains(fill),
					"a note reached the page")
				_ok(not Manuscript.unspoken("Before %s after." % ex).contains(fill),
					"a note survives into the synthesis reading")
			"delivery":
				# a delivery is the voice's business (ReadingPanel reads it, multi_voice_check holds
				# what it does); here: it carries its words, and it is never read aloud or printed
				var lm := Manuscript._rx(Manuscript.DELIVERY).search(ex)
				_ok(lm != null and lm.get_string(1) == fill, "a delivery mark does not carry its words")
				_ok(not _words(Manuscript.unspoken("Before.\n%s\nAfter." % ex)).has("quicker"),
					"a delivery mark is read aloud")
				var b := Manuscript.blocks("Before.\n%s\nAfter.\n" % ex)
				var shown := ""
				for blk in b:
					shown += String((blk as Dictionary).get("text", ""))
				_ok(not shown.contains("quicker"), "a delivery mark reached the page")
			_:
				_ok(false, "%s has no check in script_marks_check - prove it before shipping it" % k)
	# THE SYNTHESIS FIX, two-sided: the raw text DOES read a cue aloud, the stripped text not.
	var raw := "Hello. <!-- speaker: Emily --> Then. <!-- hesitation --> End."
	_ok(_words(raw).has("emily") and not _words(Manuscript.unspoken(raw)).has("emily")
			and not _words(Manuscript.unspoken(raw)).has("hesitation"),
		"Manuscript.unspoken does not keep comments out of a synthesis reading")


## WHAT A BRIEF'S MARKS DO, each as its Cards blurb says it.
func _cards_brief() -> void:
	var body := "\n".join(PackedStringArray([
		"# The Penalty Box", "",
		"A league of ${TEAMS:twelve} teams. <!-- check the count -->", "",
		"<!-- speaker: Rink Announcer -->", "",
		"Sign off with: Keep your *stick* <!-- hesitation --> on the ice.", "",
		"<!-- delivery: hushed -->", "Open with: Welcome back to the box. <!-- hesitation: 2 -->", ""]))
	var brief := CardPrompts.brief(body)
	# the control: the brief before it is prepared still carries the note and the macro
	_ok(CardDeck.strip(body).contains("check the count") and CardDeck.strip(body).contains("${TEAMS"),
		"the control is wrong - the unprepared brief carries no note or macro")
	_ok(not brief.contains("check the count"), "a note to self reaches the agents")
	_ok(brief.contains("twelve teams") and not brief.contains("${"), "a macro does not reach the agents as its default: %s" % brief)
	_ok(Manuscript.speakers(body).has("Rink Announcer") and brief.contains("<!-- speaker: Rink Announcer -->"),
		"a speaker cue in a brief is not a voice of the show")
	_ok(brief.contains("<!-- hesitation -->") and brief.contains("<!-- hesitation: 2 -->")
			and brief.contains("<!-- delivery: hushed -->") and brief.contains("*stick*"),
		"a dictated line's marks do not reach the agents: %s" % brief)
	# ...the reader is told to keep them, and its passage does
	_ok(Rules.say("cards/reader.spoken").contains("WORD FOR WORD") and Rules.say("cards/reader.spoken").contains("its marks included"),
		"the reader is not told to keep a dictated line's marks")
	var said := CardProducer.clean_spoken("<!-- delivery: hushed -->\nWelcome back to the box. <!-- hesitation: 2 -->\n\n"
		+ "Keep your *stick* <!-- hesitation --> on the ice. <!-- table: draw 2 -->")
	_ok(said.contains("<!-- delivery: hushed -->") and said.contains("<!-- hesitation: 2 -->")
			and said.contains("*stick* <!-- hesitation --> on") and not said.contains("table:"),
		"a reader's passage does not keep the voice's marks (and only those): %s" % said)
	_ok(_stressed(said, "stick") and not _stressed(said, "ice"),
		"a stressed word of a dictated line is not stressed in the reading")
	# ITALIC HITS, BOLD HITS HARDER (2026-10-12): a reader's passage keeps the two apart, each leaves it
	# as its own level (1, 2) - the level the voice leans by and the subtitle picks its face from
	var two := CardProducer.clean_spoken("It was *never* about the card. You **must** rest.")
	_ok(two.contains("*never*") and two.contains("**must**"), "a passage does not keep italic and bold apart: %s" % two)
	# (what the voice makes of a level is the reading panel's and the host's: multi_voice_check's
	# "a word leaned on is sent leaned on", hosts/voice/test_expression.py's "bold leans harder")
	var levels := {}
	for sentence in Phonemes.parse(two):
		for w in sentence:
			if int(w.get("emph", 0)) != 0:
				levels[String(w["text"]).to_lower()] = int(w["emph"])
	_ok(levels.size() == 2 and int(levels.get("never", 0)) == TextNorm.EMPH_I and int(levels.get("must", 0)) == TextNorm.EMPH_B,
		"italic and bold do not leave a passage as two levels: %s" % str(levels))
	# a dictated line is still known as the brief's own with a mark in it; a line of the reader's is not
	var left := CardPrompts.unfixed("Keep your stick on the ice. Something new happened today.", brief)
	_ok(left == "Something new happened today.", "a dictated line with a mark in it is not known as the brief's: '%s'" % left)
	# WHAT IS NOT OFFERED: a passage keeps no bracket, so an inline pronunciation would be lost
	_ok(not CardProducer.clean_spoken("The [K AE T] sat down on the ice.").contains("["),
		"a reader's passage keeps brackets now - offer the pronunciation mark in a brief")
	# THE DECK IS COLORED AS ONE, and a list anywhere else is not
	var te := TextEdit.new()
	var hl := ScriptHighlighter.new("cards")
	te.syntax_highlighter = hl
	te.text = "## The host\n- quick with a joke\n\n## Cards\n### Major Arcana\n- The Tower: upheaval\n<!-- image: a wolf -->"
	var plain: Color = te.get_theme_color("font_color")
	var deck := ScriptMarks.color_of("card")
	var l1 := hl.get_line_syntax_highlighting(1)
	_ok(l1.has(0) and (l1[0]["color"] as Color).is_equal_approx(plain), "a list outside the deck is colored as cards: %s" % l1)
	for i in [3, 4, 5]:
		var l := hl.get_line_syntax_highlighting(i)
		_ok(l.has(0) and (l[0]["color"] as Color).is_equal_approx(deck), "line %d of the deck is not colored as the deck: %s" % [i, l])
	var l6 := hl.get_line_syntax_highlighting(6)
	_ok(l6.has(0) and (l6[0]["color"] as Color).is_equal_approx(ScriptMarks.color_of("note")),
		"a picture mark in a brief is colored as a working one: %s" % l6)
	te.free()


## Does [param word] carry emphasis anywhere in [param text], as the voice parses it?
func _stressed(text: String, word: String) -> bool:
	for sentence in Phonemes.parse(Manuscript.unspoken(text)):
		for w in sentence:
			if String(w["text"]).to_lower().begins_with(word) and int(w.get("emph", 0)) != 0:
				return true
	return false


func _words(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for s in Phonemes.parse(text):
		for w in s:
			out.append(String(w["text"]))
	return out


func _insertion() -> void:
	var te := TextEdit.new()
	# A SELECTION BECOMES THE FILL, and an own-line mark in mid-line gets its own line.
	te.text = "Then Emily said hello."
	te.select(0, 5, 0, 10)
	ScriptMarks.insert(te, "speaker")
	_ok(te.text == "Then \n<!-- speaker: Emily -->\n said hello.",
		"a selected name did not become its own-line cue: %s" % te.text.c_escape())
	_ok(Manuscript.speakers(te.text).has("Emily"), "the inserted cue is not read as a cue")
	# THE FILL IS SELECTED so typing replaces the example.
	te.text = "Prose."
	te.deselect()
	te.set_caret_line(0)
	te.set_caret_column(6)
	ScriptMarks.insert(te, "image")
	_ok(te.get_selected_text() == "what the picture shows",
		"the example was not left selected: '%s'" % te.get_selected_text())
	_ok(te.text == "Prose.\n<!-- image: what the picture shows -->",
		"a picture after prose did not get its own line: %s" % te.text.c_escape())
	# ONE UNDO STEP takes the whole insertion back.
	te.undo()
	_ok(te.text == "Prose.", "one undo did not remove the whole mark: %s" % te.text.c_escape())
	# A MARK WITH NO FILL goes AFTER a selection, never over it.
	te.text = "Wait for it."
	te.select(0, 0, 0, 4)
	ScriptMarks.insert(te, "hesitation")
	_ok(te.text == "Wait<!-- hesitation --> for it.",
		"a hesitation replaced the selected word: %s" % te.text.c_escape())
	# A KNOWN NAME (the speaker chips) fills the mark and is not left selected.
	te.text = ""
	ScriptMarks.insert(te, "speaker", "Ryan")
	_ok(te.text == "<!-- speaker: Ryan -->" and not te.has_selection(),
		"a chip did not insert its speaker: %s" % te.text.c_escape())
	# A LINE-START MARK goes to the head of the line whatever the caret.
	te.text = "Chapter text"
	te.set_caret_column(8)
	ScriptMarks.insert(te, "heading")
	_ok(te.text.begins_with("# Heading") and te.text.ends_with("Chapter text"),
		"a heading was not put at the start of the line: %s" % te.text.c_escape())
	te.free()


func _highlighter() -> void:
	var te := TextEdit.new()
	var hl := ScriptHighlighter.new("generative")
	te.syntax_highlighter = hl
	te.text = "Plain prose.\n<!-- image: a wolf\nin a coat -->\n<!-- speaker: Emily -->\nMore."
	var plain: Color = te.get_theme_color("font_color")
	var pic := ScriptMarks.color_of("image")
	var voice := ScriptMarks.color_of("speaker")
	var l0 := hl.get_line_syntax_highlighting(0)
	_ok(l0.has(0) and (l0[0]["color"] as Color).is_equal_approx(plain), "prose is colored")
	var l2 := hl.get_line_syntax_highlighting(2)
	_ok(l2.has(0) and (l2[0]["color"] as Color).is_equal_approx(pic),
		"the second line of a picture description lost its color: %s" % l2)
	var l3 := hl.get_line_syntax_highlighting(3)
	_ok(l3.has(0) and (l3[0]["color"] as Color).is_equal_approx(voice),
		"a speaker cue is not colored as one: %s" % l3)
	# A CUE THAT DOES NOT OWN ITS LINE IS ONLY A NOTE, and is shown as one.
	te.text = "She said <!-- speaker: Emily --> hello."
	var l := hl.get_line_syntax_highlighting(0)
	var note := ScriptMarks.color_of("note")
	var at := te.text.find("<!--")
	_ok(l.has(at) and (l[at]["color"] as Color).is_equal_approx(note),
		"an inline speaker cue is colored as a working cue: %s" % l)
	# THE SYNTHESIS PANEL honors no cues: the same line there is a note.
	var te2 := TextEdit.new()
	var hl2 := ScriptHighlighter.new("synthesis")
	te2.syntax_highlighter = hl2
	te2.text = "<!-- speaker: Emily -->"
	var s0 := hl2.get_line_syntax_highlighting(0)
	_ok(s0.has(0) and (s0[0]["color"] as Color).is_equal_approx(note),
		"the synthesis highlighter colors a cue it does not honor")
	te.free()
	te2.free()
