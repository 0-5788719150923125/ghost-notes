extends SceneTree

## script_marks_check - that every mark the script editor offers DOES what it says.
##
## [ScriptMarks] is a list of promises that implements none of them ([Manuscript], [TextNorm] and [Phonemes] do), so
## the failure this guards is drift: an entry whose example no longer means anything to its parser looks like a
## working palette button. Every entry's example is inserted and the real parser is asked what it makes of it; an
## entry with no check here fails too.
##
## Also held: each entry's highlight pattern recognizes its own example, the insertion rules (a selection becomes the
## fill, the fill is left selected, an own-line mark gets its own line, one undo step), and the highlighter coloring a
## multi-line picture description and leaving prose plain.
##
## A table brief has a palette too, and each mark offered there is held to what it says of a brief: a speaker cue is a
## voice of the show, a note to self never reaches an agent and a macro reaches them as its default ([method
## TablePrompts.brief]; the control is the brief before it, which carries both), a hesitation, a delivery and a
## stressed word survive from a line the brief dictates into the reader's passage and the reader is told to keep them
## (italic and bold as two levels of stress), such a line is still known as the brief's own, and a card is colored as
## one only inside the deck. What is not offered is held too: a passage keeps no bracket, so the inline pronunciation
## is left out. A date mark is filled as the night it is made on (control: after noon, today's).
##
## Run: godot --headless --path . --script tests/notes/script_marks_check.gd

const Macros := preload("res://src/data/macros.gd")

var fails := 0
var checks := 0


func _init() -> void:
	_registry_shape()
	_patterns_match_examples()
	_parsers_agree()
	_cards_brief()
	_song_marks()
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
			_ok(m in ["generative", "table", "song"], "%s names an unknown mode %s" % [k, m])
		for m in e.get("blurbs", {}):
			_ok((e["modes"] as Array).has(m) and not String(e["blurbs"][m]).is_empty(),
				"%s words itself for %s, a panel it is not offered in" % [k, m])
		_ok(String(e.get("within", "")) in ["", "deck"], "%s names an unknown `within`" % k)
		var re := RegEx.new()
		_ok(re.compile(String(e.get("pattern", ""))) == OK, "%s's pattern does not compile" % k)
	# A reading has something to offer; a note's own panel (its mode "note") offers nothing.
	_ok(ScriptMarks.for_mode("generative").size() > 0 and ScriptMarks.for_mode(Components.script_mode("note")).is_empty(),
		"the per-mode palettes are not what they should be")
	# ...and so has a brief: its own marks, and none that need a page or a tablet
	var cards := ScriptMarks.for_mode("table")
	for k in ["speaker", "deck", "card", "suit", "note", "macro", "hesitation", "delivery"]:
		_ok(cards.has(k), "a Cards brief is not offered `%s`" % k)
	for k in cards:
		_ok(not String(ScriptMarks.REGISTRY[k]["group"]) in ["pictures", "tablet", "pronunciation"],
			"a Cards brief is offered `%s`, which nothing there reads" % k)
	_ok(ScriptMarks.blurb("speaker", "table") != ScriptMarks.blurb("speaker", "generative")
			and ScriptMarks.blurb("speaker", "generative") == String(ScriptMarks.REGISTRY["speaker"]["blurb"]),
		"a mark does not say what it does in a brief")


## The color is a claim too: the highlight pattern must find the whole example, on a line of its own inside prose.
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


## {word: its acts, comma-joined} for every token of [param chunks] ([DeliveryBank]): "" for a word with none.
func _acts_of(chunks: Array) -> Dictionary:
	var out := {}
	for c in chunks:
		for tok in (c as Dictionary)["tokens"]:
			var names := PackedStringArray()
			for a in (tok as Dictionary).get("acts", []):
				names.append(String(a[0]))
			out[String((tok as Dictionary)["text"])] = ",".join(names)
	return out


## {word: its axis values} for every token of [param chunks] that a delivery moves.
func _xs_of(chunks: Array) -> Dictionary:
	var out := {}
	for c in chunks:
		for tok in (c as Dictionary)["tokens"]:
			if (tok as Dictionary).has("x"):
				out[String((tok as Dictionary)["text"])] = (tok as Dictionary)["x"]
	return out


func _kinds(d: Dictionary) -> Array:
	var out := []
	for a in d["actions"]:
		out.append(String(a["kind"]))
	return out


## How a dispatch desk's tablet reaches each of its pages, in order.
func _hows(d: Dictionary) -> Array:
	var out := []
	for a in d["actions"]:
		if String(a["kind"]) == "page":
			out.append(String(a["how"]))
	return out


## The proof: each example, read by the parser of record. A key missing from this match fails, so a new entry cannot
## ship unverified.
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
			"over", "together":
				var seen := ReadingPlan.make("<!-- speaker: Narrator -->\nOne thing said.\n\n<!-- speaker: Bea -->\n%s\nAnother thing said." % ex, "", {"reader": "Dell", "hesitate": true, "bare": 1.0, "outro": 0.0})["chunks"] as Array
				_ok(seen.size() == 2 and ReadingJoin.overlaps(seen[1]), "%s does not bring its turn in over the last" % k)
				if k == "over" and seen.size() == 2:
					_ok(is_equal_approx(float((seen[1] as Dictionary)["over"]), float(fill)), "an over's seconds are not the ones it says")
			"heard":
				var heard := ReadingPlan.make("<!-- speaker: Narrator -->\nIn the room.\n\n<!-- speaker: Bea -->\n%s\nOver the air." % ex, "", {"reader": "Narrator", "hesitate": true, "bare": 1.0, "outro": 0.0})["chunks"] as Array
				_ok(heard.size() == 2 and String((heard[0] as Dictionary).get("heard", "")).is_empty()
						and String((heard[1] as Dictionary).get("heard", "")) == fill and VoiceFX.HEARD.has(fill),
					"a turn marked %s is not heard through it" % ex)
			"inflect":
				# the words it wraps carry its act to the voice - none on every word, rise on the last - the words round it
				# nothing (the control), spaced or not, and no sentinel is spoken or shown
				for form in [ex, ex.replace("-->A", "--> A").replace("?<!", "? <!"), ex.replace(": none", ": rise")]:
					var kind := "rise" if form.contains("rise") else "none"
					var made := ReadingPlan.make("They left. %s Then what?\n" % form, "", {"reader": "Narrator", "hesitate": true, "bare": 1.0, "outro": 0.0})["chunks"] as Array
					var got := _acts_of(made)
					var shown := ""
					for c in made:
						for w in (c as Dictionary)["words"]:
							shown += String((w as Dictionary)["text"]) + " "
					var want_am := kind if kind == "none" else ""
					_ok(got.get("am", "") == want_am and got.get("i", "") == want_am and got.get("fired", "") == kind,
						"the words %s wraps are not inflected %s (%s)" % [form, kind, str(got)])
					_ok(got.has("left") and got["left"] == "" and got.has("what") and got["what"] == "",
						"words outside %s are inflected too (%s)" % [form, str(got)])
					_ok(not got.has("inflect") and not got.has("none") and TextNorm.strip_emphasis(shown) == shown,
						"%s is spoken or shown (%s)" % [form, shown])
				# ...and on a line of its own, where a medium reads its lines first: the words between its two comments are
				# words, never a note dropped whole (a pattern for a comment that runs on past its own close), while a line of
				# comments alone is still a note (the control)
				var own := "<!-- speaker: Van -->\n\n%s\n\n<!-- speaker: Control -->\n\nGo home.\n" % ex
				var desk := DispatchScript.speakable("<!-- call: VAN -->\n\n" + own)
				var desk_made := ReadingPlan.make(desk, "", {"reader": "Control", "hesitate": true, "bare": 1.0, "outro": 0.0})["chunks"] as Array
				var desk_said := _acts_of(desk_made)
				_ok(desk_said.get("fired", "") == "none" and desk_said.get("go", "x") == "",
					"a dispatch desk drops the words an inflection mark wraps on a line of its own (%s)" % str(desk_said))
				var letter := ""
				for b in LetterScript.blocks(own):
					if String((b as Dictionary)["kind"]) == "para":
						letter += String((b as Dictionary)["text"])
				_ok(letter.contains("Am I fired?"), "a letter drops the words an inflection mark wraps on a line of its own")
				_ok(DispatchScript._classify("<!-- hesitation: 2 --> <!-- sound: a door -->").get("kind", "") == "note",
					"a line of comments alone is no longer a note")
			"delivered":
				# the bracketed words carry the act to the voice and the words round them nothing (the control); the brackets
				# and braces are never spoken, captioned or printed - on a page, in a letter, at the dispatch desk or in a table
				# reader's passage
				var made := ReadingPlan.make("A frog, %s five arrows.\n" % ex, "", {"reader": "Narrator", "hesitate": true, "bare": 1.0, "outro": 0.0})["chunks"] as Array
				var got := _acts_of(made)
				_ok(String(got.get("and", "")).contains("drawn") and String(got.get("and", "")).contains("held")
						and got.get("five", "x") == "" and got.get("frog", "x") == "",
					"%s does not reach its word alone (%s)" % [ex, str(got)])
				var shown := ""
				for c in made:
					for w in (c as Dictionary)["words"]:
						shown += String((w as Dictionary)["text"]) + " "
				_ok(not shown.contains("[") and not shown.contains("{") and shown.contains("and"),
					"%s is captioned as written (%s)" % [ex, shown])
				var page := ""
				for blk in Manuscript.blocks("A frog, %s five arrows.\n" % ex):
					page += String((blk as Dictionary).get("text", ""))
				_ok(page == "A frog, and five arrows.", "%s reached the page as written (%s)" % [ex, page])
				_ok(Manuscript.unspoken("A frog, %s five." % ex) == "A frog, and five.", "%s survives into a reading of no marks" % ex)
				var letter := ""
				for blk in LetterScript.blocks("A frog, %s five arrows.\n" % ex):
					if String((blk as Dictionary)["kind"]) == "para":
						letter += String((blk as Dictionary)["text"])
				_ok(not letter.contains("{") and Manuscript.unspoken(letter).contains("and five"), "a letter writes %s as written (%s)" % [ex, letter])
				var desk := DispatchScript.speakable("<!-- call: VAN -->\n\n<!-- speaker: Van -->\n\n" + Manuscript.delivered_as_marks("A frog, %s five arrows.\n" % ex))
				var desk_acts := _acts_of(ReadingPlan.make(desk, "", {"reader": "Control", "hesitate": true, "bare": 1.0, "outro": 0.0})["chunks"] as Array)
				_ok(String(desk_acts.get("and", "")).contains("drawn"), "a dispatch desk drops %s (%s)" % [ex, str(desk_acts)])
				var passage := TableProducer.clean_spoken("A frog, %s five arrows." % ex)
				_ok(passage.contains("delivery") and passage.contains("and") and not passage.contains("{"),
					"a table reader's passage loses %s or keeps its braces (%s)" % [ex, passage])
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
				var desk := DispatchScript.parse("<!-- speaker: Control -->\n\n<!-- tablet -->\n\n```page\nurl: a.test\n```\n\n%s\n\n```page\nurl: b.test\n```\n\n<!-- /tablet -->\n\nDone.\n" % ex)
				_ok(_hows(desk) == ["type", "tab", "type"] and (desk["warnings"] as PackedStringArray).is_empty(),
					"a new tab mark opens no tab on a dispatch desk's tablet (%s)" % str(_hows(desk)))
			"back":
				var d := TabletScript.parse("<!-- url: a.test -->\n\nOne.\n\n<!-- url: b.test -->\n\nTwo.\n\n%s\n" % ex)
				_ok(_kinds(d).has("back"), "a back mark goes nowhere")
				var desk := DispatchScript.parse("<!-- speaker: Control -->\n\n<!-- tablet -->\n\n```page\nurl: a.test\n\n[B](b.test)\n```\n\n```page\nurl: b.test\n```\n\n%s\n\n<!-- /tablet -->\n\nDone.\n" % ex)
				_ok(_hows(desk) == ["type", "tap", "back"] and (desk["warnings"] as PackedStringArray).is_empty(),
					"a back mark goes nowhere on a dispatch desk's tablet (%s)" % str(_hows(desk)))
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
			"post":
				var d := TabletScript.parse("<!-- url: a.test -->\n\n# Thread\n\n%s\n\nIts body.\n" % ex)
				var bl: Array = d["pages"][0]["blocks"]
				_ok(bl.size() == 3 and String(bl[1]["kind"]) == "post" and String(bl[1]["who"]) == "nightlog"
					and int(bl[2].get("post", 0)) == int(bl[1]["n"]), "a post mark makes no post, or its body is not its own")
				_ok(not String(d["speakable"]).contains("nightlog"), "a post's author is read aloud")
			"pager":
				var d := TabletScript.parse("<!-- url: a.test -->\n\n# Board\n\n%s\n" % ex)
				var tp := TabletPage.new()
				tp.build(d, 0, 1200.0, 3000.0)
				var pages := -1
				for it in tp.items:
					if String((it as Dictionary)["kind"]) == "pager":
						pages = int((it as Dictionary)["pages"])
				_ok(pages == int(fill), "a pager mark sets no pager of %s pages (%d)" % [fill, pages])
			"nav":
				var d := TabletScript.parse("<!-- url: a.test -->\n%s\n\n# Site\n" % ex)
				_ok((d["pages"][0].get("nav", PackedStringArray()) as PackedStringArray).size() == 4, "a nav mark names no menu")
				var desk := DispatchScript.parse("<!-- speaker: Control -->\n\n<!-- tablet -->\n\n```page\nurl: a.test\nnav: %s\n\n# Site\n```\n\n<!-- /tablet -->\n\nDone.\n" % fill)
				_ok((desk["tablet"]["pages"][0].get("nav", PackedStringArray()) as PackedStringArray).size() == 4,
					"a page fence's nav: line names no menu on a dispatch desk's tablet")
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
			"say":
				# the mark's words said as it spells them, and shown as written
				var told := ReadingPlan.said_in(ex)
				var ws: Array = Phonemes.parse("Three columns, Io-A here.", told)[0]
				var io: Dictionary = ws[2] if ws.size() > 2 else {}
				_ok(bool(io.get("literal", false)) and (io.get("phones", []) as Array) == ["AY", "OW", "EY"] and String(io.get("display", "")) == "Io-A",
					"a say mark does not have its word said as it spells it and shown as written (%s)" % str(io))
			"letter":
				var ws: Array = Phonemes.parse("Take %s to be two." % ex)[0]
				_ok(ws.size() == 5 and String(ws[1]["text"]) == TextNorm.LETTER_NAMES[fill]
						and String(ws[1]["display"]) == fill,
					"a named letter is not said by its name and shown as itself")
				var bare: Array = Phonemes.parse("Take %s fraction." % fill)[0]
				_ok(String(bare[1]["text"]) == fill, "a bare letter stopped being the word it spells")
			"macro":
				var dflt := fill.get_slice(":", 1)
				_ok(TextNorm.normalize("Chapter %s." % ex) == TextNorm.normalize("Chapter %s." % dflt),
					"a macro does not read as its default")
			"date":
				# filled as the reading reads it, on a pinned clock: half past one is still the night before
				var late := {"year": 2026, "month": 11, "day": 21, "hour": 1}
				_ok(Macros.dated("Tonight is %s." % ex, {}, late) == "Tonight is 11/20/2026.",
					"a date mark is not filled as the night it is made on")
				_ok(Macros.dated("Tonight is %s." % ex, {}, {"year": 2026, "month": 11, "day": 21, "hour": 13}) == "Tonight is 11/21/2026.",
					"control: after noon, the date mark is not today's")
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
			"section":
				var secs := Lyrics.parse("%s\nError me found\n\n<!-- verse -->\nWelcome random user\n\n%s\n" % [ex, ex])
				_ok(secs.size() == 3 and String(secs[0]["kind"]) == "chorus" and String(secs[1]["kind"]) == "verse"
						and String(secs[2]["kind"]) == "chorus" and (secs[2]["lines"] as Array).size() == (secs[0]["lines"] as Array).size(),
					"a song's section mark does not begin its section, or one with no lines under it is not the last of its kind again: %s" % str(secs))
				var named := Lyrics.parse("<!-- pre-chorus -->\nHere it comes\n<!-- hook -->\nError me found\n")
				_ok(named.size() == 2 and String(named[0]["kind"]) == "bridge" and String(named[0]["label"]) == "Pre-chorus"
						and String(named[1]["kind"]) == "chorus" and String(named[1]["label"]) == "Hook",
					"a pre-chorus does not play as a bridge, or a hook as a chorus, each named as written: %s" % str(named))
			"instrumental":
				var secs := Lyrics.parse("<!-- intro: 2 -->\n<!-- verse -->\nWelcome\n%s\n<!-- chorus -->\nError me found\n<!-- ending -->\n" % ex)
				var before: Array = secs[1].get("before", []) if secs.size() == 2 else []
				var after: Array = secs[1].get("after", []) if secs.size() == 2 else []
				_ok(secs.size() == 2 and (secs[0].get("before", []) as Array).size() == 1 and int(secs[0]["before"][0]["bars"]) == 2
						and before.size() == 1 and String(before[0]["kind"]) == "break" and int(before[0]["bars"]) == 8
						and after.size() == 1 and String(after[0]["kind"]) == "outro" and int(after[0]["bars"]) == Lyrics.INSTRUMENTAL_BARS,
					"an instrumental section's mark is not a section of its bars where it is written: %s" % str(secs))
			"repeat":
				var secs := Lyrics.parse("<!-- chorus -->\nError me found\n%s\n" % ex)
				_ok(secs.size() == 1 and (secs[0]["lines"] as Array).size() == 2,
					"a repeat does not sing the section so far again: %s" % str(secs))
				var bare := Lyrics.parse("<!-- chorus -->\nError me found\nTrying to shutdown now\n<!-- repeat -->\n")
				_ok(bare.size() == 1 and (bare[0]["lines"] as Array).size() == 4, "a bare repeat is not twice in all")
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
				# a delivery is the voice's business (DeliveryBank lays it out, delivery_check holds what it does); here: it
				# carries its words, it reaches the words of its paragraph and no further, and it is never read aloud or printed
				var lm := Manuscript._rx(Manuscript.DELIVERY).search(ex)
				_ok(lm != null and lm.get_string(1) == fill, "a delivery mark does not carry its words")
				_ok(not _words(Manuscript.unspoken("Before.\n%s\nAfter." % ex)).has("excited"),
					"a delivery mark is read aloud")
				var b := Manuscript.blocks("Before.\n%s\nAfter.\n" % ex)
				var shown := ""
				for blk in b:
					shown += String((blk as Dictionary).get("text", ""))
				_ok(not shown.contains("excited"), "a delivery mark reached the page")
				var told := _xs_of(ReadingPlan.make("Calm here.\n\n%s\nThis goes up and up and up.\n\nCalm again, and on and on, and later still at home." % ex, "", {"reader": "Narrator", "hesitate": true, "bare": 1.0, "outro": 0.0})["chunks"] as Array)
				_ok(not told.has("here") and told.has("up") and not told.has("home"),
					"a delivery mark does not reach its paragraph alone, letting go after it (%s)" % str(told.keys()))
			"thought", "strike", "struck", "color", "unspoken", "sketch_timed", "point", "tap", "image_end", "still", "new_page":
				_letter_mark(k, ex)
			"call", "hang_up", "ring", "text_msg", "ping", "desk_sound", "static", "print", "sleep", "screen_off", "look", "lift", \
					"switch", "live", "image_screen", "video_screen", "terminal", "moving", "plane", "reply", "redact", "gain", "bell", "lamp", "fade", "tablet", \
					"tablet_end", "page", "player", "replay", "power", "environment_switch", "play_screen":
				_dispatch_mark(k, ex)
			_:
				_ok(false, "%s has no check in script_marks_check - prove it before shipping it" % k)
	# The synthesis fix, two-sided: the raw text DOES read a cue aloud, the stripped text not.
	var raw := "Hello. <!-- speaker: Emily --> Then. <!-- hesitation --> End."
	_ok(_words(raw).has("emily") and not _words(Manuscript.unspoken(raw)).has("emily")
			and not _words(Manuscript.unspoken(raw)).has("hesitation"),
		"Manuscript.unspoken does not keep comments out of a synthesis reading")


## What a brief's marks do, each as its table blurb says it.
func _cards_brief() -> void:
	var body := "\n".join(PackedStringArray([
		"# The Penalty Box", "",
		"A league of ${TEAMS:twelve} teams. <!-- check the count -->", "",
		"<!-- speaker: Rink Announcer -->", "",
		"Sign off with: Keep your *stick* <!-- hesitation --> on the ice.", "",
		"<!-- delivery: hushed -->", "Open with: Welcome back to the box. <!-- hesitation: 2 -->", ""]))
	var brief := TablePrompts.brief(body)
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
	_ok(Rules.say("table/reader.spoken").contains("WORD FOR WORD") and Rules.say("table/reader.spoken").contains("its marks included"),
		"the reader is not told to keep a dictated line's marks")
	var said := TableProducer.clean_spoken("<!-- delivery: hushed -->\nWelcome back to the box. <!-- hesitation: 2 -->\n\n"
		+ "Keep your *stick* <!-- hesitation --> on the ice. <!-- table: draw 2 -->")
	_ok(said.contains("<!-- delivery: hushed -->") and said.contains("<!-- hesitation: 2 -->")
			and said.contains("*stick* <!-- hesitation --> on") and not said.contains("table:"),
		"a reader's passage does not keep the voice's marks (and only those): %s" % said)
	_ok(_stressed(said, "stick") and not _stressed(said, "ice"),
		"a stressed word of a dictated line is not stressed in the reading")
	# Italic hits, bold hits harder: a reader's passage keeps the two apart, each leaving it as its own level (1, 2) -
	# the level the voice leans by and the subtitle picks its face from
	var two := TableProducer.clean_spoken("It was *never* about the card. You **must** rest.")
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
	var left := TablePrompts.unfixed("Keep your stick on the ice. Something new happened today.", brief)
	_ok(left == "Something new happened today.", "a dictated line with a mark in it is not known as the brief's: '%s'" % left)
	# What is not offered: a passage keeps no bracket, so an inline pronunciation would be lost
	_ok(not TableProducer.clean_spoken("The [K AE T] sat down on the ice.").contains("["),
		"a reader's passage keeps brackets now - offer the pronunciation mark in a brief")
	# The deck is colored as one, and a list anywhere else is not
	var te := TextEdit.new()
	var hl := ScriptHighlighter.new("table")
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
## A song's editor offers its own marks and the script's it honors, each held to what it says of a song: a heading and a
## note to self (one running over lines too) are never sung, and a say mark has its word sung as it spells it - the
## control, the same words with no mark, sing the word as ghost reads it.
func _song_marks() -> void:
	var offered := ScriptMarks.for_mode("song")
	_ok(offered.has("section") and offered.has("repeat") and offered.has("instrumental") and offered.has("say") and offered.has("heading") and offered.has("note")
		and not offered.has("speaker"), "a song's editor does not offer a song's marks: %s" % str(offered))
	var secs := Lyrics.parse("# A title\n\n<!-- verse -->\n<!-- a note -->\nWelcome random user\n<!-- a note that\nruns over lines -->\nTo my soliloquy\n")
	var sung := PackedStringArray()
	for l in Lyrics.lines_of(secs):
		sung.append(String(l["text"]))
	_ok(sung == PackedStringArray(["Welcome random user", "To my soliloquy"]),
		"a heading or a note to self is sung in a song: %s" % str(sung))
	var said := Lyrics.parse("<!-- say: soliloquy = S AH0 L IH1 L AH0 K W IY0 -->\n<!-- verse -->\nTo my soliloquy\n")
	var word: Dictionary = said[0]["lines"][0]["words"][2] if not said.is_empty() else {}
	_ok((word.get("arpa", []) as Array) == ["S", "AH0", "L", "IH1", "L", "AH0", "K", "W", "IY0"] and int(word.get("syllables", 0)) == 4,
		"a say mark does not have its word sung as it spells it: %s" % str(word))
	var plain := Lyrics.parse("<!-- verse -->\nTo my soliloquy\n")
	_ok(not (plain[0]["lines"][0]["words"][2] as Dictionary).has("arpa"), "the control: a word no mark spells carries a spelling")


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
	# A selection becomes the fill, and an own-line mark in mid-line gets its own line.
	te.text = "Then Emily said hello."
	te.select(0, 5, 0, 10)
	ScriptMarks.insert(te, "speaker")
	_ok(te.text == "Then \n<!-- speaker: Emily -->\n said hello.",
		"a selected name did not become its own-line cue: %s" % te.text.c_escape())
	_ok(Manuscript.speakers(te.text).has("Emily"), "the inserted cue is not read as a cue")
	# The fill is selected so typing replaces the example.
	te.text = "Prose."
	te.deselect()
	te.set_caret_line(0)
	te.set_caret_column(6)
	ScriptMarks.insert(te, "image")
	_ok(te.get_selected_text() == "what the picture shows",
		"the example was not left selected: '%s'" % te.get_selected_text())
	_ok(te.text == "Prose.\n<!-- image: what the picture shows -->",
		"a picture after prose did not get its own line: %s" % te.text.c_escape())
	# One undo step takes the whole insertion back.
	te.undo()
	_ok(te.text == "Prose.", "one undo did not remove the whole mark: %s" % te.text.c_escape())
	# A mark with no fill goes AFTER a selection, never over it.
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
	# A note's own panel (its mode "note") offers no marks: the same cue there is words, never a voice's cue.
	var te2 := TextEdit.new()
	var hl2 := ScriptHighlighter.new(Components.script_mode("note"))
	te2.syntax_highlighter = hl2
	te2.text = "<!-- speaker: Emily -->"
	var s0 := hl2.get_line_syntax_highlighting(0)
	var c0: Color = (s0[0]["color"] as Color) if s0.has(0) else plain
	_ok(c0.is_equal_approx(plain), "a note's own highlighter colors a cue it does not honor: %s" % s0)
	te.free()
	te2.free()


## A dispatch desk's mark ([DispatchScript]), read by the desk's own parser: what each makes the desk do, what the voice
## says and what it is heard through.
func _dispatch_mark(k: String, ex: String) -> void:
	var head := "<!-- speaker: Control -->\n\nThe night begins.\n\n"
	var tail := "\n\nThe night goes on.\n"
	match k:
		"call", "hang_up":
			var call := ex if k == "call" else "<!-- call: AISLE -->"
			var end := ex if k == "hang_up" else "<!-- /call -->"
			var d := DispatchScript.parse(head + call + "\n\n<!-- speaker: Aisle -->\n\nHello?\n\n<!-- speaker: Control -->\n\nGo.\n\n" + end + tail)
			var kinds: Array = []
			for a in d["actions"]:
				kinds.append(String(a["kind"]))
			var sp := String(d["speakable"])
			_ok(kinds == ["call", "hang_up"] and String(d["actions"][0]["how"]) == "dial" and (d["warnings"] as PackedStringArray).is_empty()
				and sp.contains("<!-- heard: phone -->\n\n<!-- action-hold") and not (d["spoken"] as PackedStringArray).has("aisle"),
				"%s: a call is not dialed, its voice not heard through it, or a phone is left open (%s, %s)" % [k, str(kinds), str(d["warnings"])])
		"ring":
			var d := DispatchScript.parse(head + ex + "\n\n<!-- call: LIGHTS -->\n\n<!-- speaker: Lights -->\n\nGot him.\n\n<!-- /call -->" + tail)
			_ok(String(d["actions"][0]["kind"]) == "ring" and String(d["actions"][1]["how"]) == "answer",
				"a call straight after a ring does not answer it")
		"text_msg":
			var d := DispatchScript.parse(head + ex + tail)
			var a: Dictionary = d["actions"][0]
			_ok(String(a["kind"]) == "text" and String(a["label"]) == "AISLE" and String(a["words"]) == "He looked at me"
				and not (d["spoken"] as PackedStringArray).has("looked") and float(a["rest"]) > 1.0, "a text is said, or not shown on its phone")
		"reply":
			var d := DispatchScript.parse(head + "<!-- text: AISLE | He looked at me -->\n\n" + ex + "\n\nGood. Let him wonder." + tail)
			var kinds: Array = (d["actions"] as Array).map(func(x: Dictionary) -> String: return String(x["kind"]))
			_ok(kinds == ["text", "reply"] and String(d["actions"][1]["label"]) == "AISLE" and String(d["actions"][1]["text"]) == "Good. Let him wonder."
				and (d["spoken"] as PackedStringArray).has("wonder"), "a reply is not typed into the phone that texted, or not said (%s)" % str(kinds))
			var on_page := DispatchScript.parse(head + "<!-- tablet -->\n\n```page\nurl: chat.test\n\n# Chat\n```\n\n<!-- reply: tablet -->\n\nHello there.\n\n<!-- /tablet -->" + tail)
			var page_kinds: Array = (on_page["actions"] as Array).map(func(x: Dictionary) -> String: return String(x["kind"]))
			_ok(page_kinds == ["tablet", "page", "post", "sent", "tablet"] and String(on_page["actions"][2]["text"]) == "Hello there."
				and (on_page["spoken"] as PackedStringArray).has("hello") and (on_page["warnings"] as PackedStringArray).is_empty()
				and bool((((on_page["tablet"] as Dictionary)["pages"] as Array)[0] as Dictionary).get("reply", false)),
				"reply: tablet is not typed into the page's message box, or not said (%s)" % str(page_kinds))
		"ping":
			var a: Dictionary = DispatchScript.parse(head + ex + tail)["actions"][0]
			_ok(String(a["kind"]) == "ping" and String(a["place"]) == "the stairwell" and is_equal_approx(float(a["rest"]), DispatchScript.PING)
				and is_equal_approx(float(a["bearing"]), 210.0) and is_equal_approx(float(a["range"]), 0.7),
				"a ping does not carry its place, bearing and range, or holds the voice past its beat")
		"moving":
			var d := DispatchScript.parse(head + ex + "\n\nHe is walking.\n\n<!-- ping: the stairwell | 210, 0.7 -->" + tail)
			var kinds: Array = (d["actions"] as Array).map(func(x: Dictionary) -> String: return String(x["kind"]))
			_ok(kinds == ["moving", "ping"] and is_equal_approx(float(d["actions"][0]["rest"]), DispatchScript.MOVING)
				and (d["spoken"] as PackedStringArray).has("walking"), "a moving mark does not set him off under the words before the ping (%s)" % str(kinds))
		"plane":
			var acts: Array = DispatchScript.parse(head + ex + tail)["actions"]
			_ok(acts.size() == 1 and String(acts[0]["kind"]) == "plane" and is_equal_approx(float(acts[0]["rest"]), 0.0),
				"a plane mark is not an aircraft the voice never waits for")
		"desk_sound":
			var a: Dictionary = DispatchScript.parse(head + ex + tail)["actions"][0]
			_ok(String(a["kind"]) == "sound" and String(a["sound"]) == "jet" and is_equal_approx(float(a["rest"]), float(DispatchSounds.SOUNDS["jet"]["secs"])),
				"a sound's words do not find its sound")
		"static":
			var a: Dictionary = DispatchScript.parse(head + ex + tail)["actions"][0]
			var sea: Dictionary = DispatchScript.parse(head + "<!-- static: 3, surf -->" + tail)["actions"][0]
			_ok(String(a["kind"]) == "static" and is_equal_approx(float(a["rest"]), 5.0) and String(a["storm"]) == "popcorn"
				and String(sea["storm"]) == "surf", "a static's seconds or its storm are not read")
		"print":
			var d := DispatchScript.parse(head + "```terminal\ntype: LOGGED.\n```\n\n" + ex + tail)
			var a: Dictionary = d["actions"].back()
			_ok(String(a["kind"]) == "print" and Array(a["lines"]).has("LOGGED."), "a print does not print what was typed")
		"sleep", "screen_off", "look", "lift", "switch", "live":
			var a: Dictionary = DispatchScript.parse(head + ex + tail)["actions"][0]
			var want := String({"sleep": "sleep", "screen_off": "off", "look": "look", "lift": "lift", "switch": "switch", "live": "live"}[k])
			var arg := String(a.get("screen", a.get("at", a.get("thing", a.get("side", "")))))
			_ok(String(a["kind"]) == want and (k == "sleep" or arg in ["tv", "radar", "mug", "BAD"]), "%s: the desk does not do it (%s)" % [k, str(a)])
		"image_screen":
			var d := DispatchScript.parse(head + ex + tail)
			var a: Dictionary = d["actions"][0]
			_ok(String(a["kind"]) == "picture" and String(a["screen"]) == "feed" and Manuscript.images(DispatchScript.pictures_only(ex)).size() == 1
				and not (d["spoken"] as PackedStringArray).has("picture"), "a picture on a screen is not pinned there, or not painted")
			# told `unwatched`, it is the same mark to the editor and the same picture to the painter
			var aside := ex.replace("(feed)", "(feed, unwatched)")
			var told: Dictionary = DispatchScript.parse(head + aside + tail)["actions"][0]
			var row := RegEx.new()
			row.compile(String(ScriptMarks.REGISTRY[k]["pattern"]))
			var found := row.search(aside)
			_ok(aside != ex and found != null and found.get_string() == aside.strip_edges() and bool(told.get("unwatched", false)) and String(told["screen"]) == "feed"
				and String(told["key"]) == String(a["key"]) and Manuscript.images(DispatchScript.pictures_only(aside)).size() == 1,
				"a picture told unwatched is not its row's mark, or not the same picture")
		"video_screen":
			var d := DispatchScript.parse(head + ex + tail)
			var a: Dictionary = d["actions"][0]
			var clips := 0
			for im in DispatchMedium.pictures_in(ex):
				if (im as Dictionary).has("clip"):
					clips += 1
			_ok(String(a["kind"]) == "picture" and String(a["screen"]) == "tv" and String(a.get("clip", "")) == "dog.webm" and clips == 1
				and not (d["spoken"] as PackedStringArray).has("dog"), "a clip on a screen is not pinned there as a clip, or is said")
		"terminal":
			var d := DispatchScript.parse(head + ex + tail)
			var a: Dictionary = d["actions"][0]
			var g := DispatchTerminal.at(a["glass"], a["ops"], INF)
			_ok(String(a["kind"]) == "session" and String(g["up"]) == "assets" and Array(DispatchTerminal.up(g)["body"]) == ["AISLE ...... AISLE SEVEN"]
				and String(d["actions"][1]["kind"]) == "type" and (d["spoken"] as PackedStringArray).has("watcher") and not (d["spoken"] as PackedStringArray).has("assets")
				and float(a["rest"]) > 1.0 and (d["warnings"] as PackedStringArray).is_empty(),
				"a terminal block does not open its panel silently with the voice waiting, then type and say its type: line (%s)" % str(d["warnings"]))
		"fade":
			var d := DispatchScript.parse(head + "<!-- fade: to-black -->\n\n" + ex + tail)
			var a: Dictionary = d["actions"][1]
			_ok(String(a["kind"]) == "fade" and not bool(a["to"]) and int(a["clock"]) == 74 and float(a["rest"]) > DispatchScript.FADE
				and (d["warnings"] as PackedStringArray).is_empty(), "a fade up does not come back on the clock's time (%s)" % str(a))
		"tablet", "tablet_end", "page":
			var page := ex if k == "page" else "```page\nurl: eyeball.vid/@pen-and-ink\n\n# Pen & Ink\n```"
			var body := (ex if k == "tablet" else "<!-- tablet -->") + "\n\n" + page + "\n\n" + (ex if k == "tablet_end" else "<!-- /tablet -->")
			var d := DispatchScript.parse(head + body + tail)
			var kinds: Array = []
			for x in d["actions"]:
				kinds.append(String((x as Dictionary)["kind"]))
			_ok(kinds == ["tablet", "page", "tablet"] and (d["warnings"] as PackedStringArray).is_empty() and (d["pages"] as Array).size() == 1
				and not (d["spoken"] as PackedStringArray).has("pen") and not (d["spoken"] as PackedStringArray).has("forum"),
				"%s: the tablet is not picked up, its page shown and never said, and put down (%s)" % [k, str(kinds)])
		"player":
			var d := DispatchScript.parse(head + "<!-- tablet -->\n\n```page\nurl: a.vid/watch\n\n" + ex + "\n```\n\n<!-- live: tablet -->\n\n<!-- /tablet -->" + tail)
			var blocks: Array = (((d["tablet"] as Dictionary)["pages"] as Array)[0] as Dictionary)["blocks"]
			var players := blocks.filter(func(b: Dictionary) -> bool:
				return String(b["kind"]) == "image" and String(b.get("key", "")) == Manuscript.image_key(DispatchScript.PLAYER))
			_ok(players.size() == 1 and (d["warnings"] as PackedStringArray).is_empty()
				and DispatchMedium.pictures_in(head + ex + tail).is_empty(), "a player is not on the page, or is painted")
		"replay":
			var d := DispatchScript.parse(head + "<!-- tablet -->\n\n" + ex + "\n\n<!-- /tablet -->" + tail)
			_ok(String(d["speakable"]).contains("<!-- heard: tablet -->") and (d["spoken"] as PackedStringArray).count("begins") == 2
				and (d["warnings"] as PackedStringArray).is_empty(), "a replay does not say the earlier words again through the tablet (%s)" % str(d["warnings"]))
		"gain":
			var d := DispatchScript.parse(head + ex + tail)
			var a: Dictionary = d["actions"][0]
			_ok(String(a["kind"]) == "gain" and int(a["from"]) == DispatchScript.GAIN_REST and int(a["to"]) == 9 and float(a["rest"]) > DispatchScript.GAIN_BEAT
				and not (d["spoken"] as PackedStringArray).has("gain"), "a gain does not turn the knob from three to its number (%s)" % str(a))
		"bell":
			var d := DispatchScript.parse(head + ex + "\n\n```terminal\nalert: INVALID OPTION\n```" + tail)
			var kinds: Array = (d["actions"] as Array).map(func(x: Dictionary) -> String: return String(x["kind"]))
			_ok(kinds == ["bell", "session"] and is_equal_approx(float(d["actions"][0]["rest"]), DispatchScript.BELL)
				and not String(d["speakable"]).contains("bell"), "a bell is not rung before the block after it, or is said (%s)" % str(kinds))
		"lamp":
			var a: Dictionary = DispatchScript.parse(head + ex + tail)["actions"][0]
			_ok(String(a["kind"]) == "lamp" and not bool(a["on"]), "a lamp mark does not switch the lamp off (%s)" % str(a))
		"power":
			var d := DispatchScript.parse(head + ex + tail)
			var a: Dictionary = d["actions"][0]
			_ok(String(a["kind"]) == "power" and not bool(a["on"]) and is_equal_approx(float(a["rest"]), DispatchScript.POWER)
				and not String(d["speakable"]).contains("power") and (d["warnings"] as PackedStringArray).is_empty(),
				"a power mark does not take the grid down with the voice waiting, or is said (%s)" % str(a))
		"environment_switch":
			var d := DispatchScript.parse(head + ex + tail)
			var a: Dictionary = d["actions"][0]
			_ok(String(a["kind"]) == "environment" and (a["set"] as Dictionary) == {"shafts": false, "beams": true}
				and is_equal_approx(float(a["secs"]), DispatchScript.ENVIRONMENT_FADE) and not String(d["speakable"]).contains("beams")
				and (d["warnings"] as PackedStringArray).is_empty(),
				"an environment mark does not switch each element it names, or is said (%s)" % str(a))
		"play_screen":
			# the film's seconds are what the parse is handed; the voice waits for the rest of it, and never says it
			var fill := String(ScriptMarks.REGISTRY[k]["fill"])
			var films := {fill: {"kind": "note", "ready": true, "secs": 30.0}}
			var d := DispatchScript.parse(head + ex + tail, films)
			var a: Dictionary = d["actions"][0]
			var left := 30.0 - (DispatchScript.PLAY_LEAD + DispatchScript.REST_PAD)
			var sp := String(d["speakable"])
			_ok(String(a["kind"]) == "play" and String(a["screen"]) == "terminal" and String(a["what"]) == fill
				and is_equal_approx(float(a["secs"]), 30.0) and sp.contains("action-hold: %s" % String.num(left, 2))
				and not (d["spoken"] as PackedStringArray).has("error") and (d["warnings"] as PackedStringArray).is_empty(),
				"a play mark does not put its film on the terminal with the voice waiting for it, or is said (%s; %s)" % [str(a), str(d["warnings"])])
		"redact":
			var d := DispatchScript.parse(head + "```terminal\nNAME ........ " + ex + "\n```" + tail)
			var line := String((DispatchTerminal.up(DispatchTerminal.at(d["actions"][0]["glass"], d["actions"][0]["ops"], INF))["body"] as PackedStringArray)[0])
			var drawn := DispatchScript.unredacted(line)
			_ok(String(drawn["text"]) == "NAME ........ DOE, JANE" and drawn["spans"] == [Vector2i(14, 23)] and not line.contains("DOE")
				and not (d["spoken"] as PackedStringArray).has("doe"), "redacted words are not on the screen as themselves, hidden (%s)" % str(drawn))


## A LETTER'S MARK ([LetterScript]), read by the letter's own parser: what each does to what the pen
## writes, what the voice says and what the screen follows.
func _letter_mark(k: String, ex: String) -> void:
	var dot := "<svg viewBox=\"0 0 360 40\"><circle id=\"the-dot\" cx=\"300\" cy=\"20\" r=\"4\" fill=\"black\"/></svg>"
	var svgs := {Manuscript.image_key("a dot"): dot}
	match k:
		"thought":
			var d := LetterScript.parse("Written first.\n\n%s\n\nWritten after.\n" % ex)
			var written := ""
			for a in d["actions"]:
				written += String(a.get("text", "")) + " "
			_ok(not written.contains("fine") and written.contains("first") and (d["spoken"] as PackedStringArray).has("fine")
				and (d["spans"] as Array).size() == 1 and String(d["spans"][0]["kind"]) == "thought",
				"a thought is written, or not said")
		"strike":
			var d := LetterScript.parse("Kept.\n\nCrossed out.\n\n%s\n" % ex)
			var of := -1
			for a in d["actions"]:
				if String(a["kind"]) == "strike":
					of = int(a["of"])
			_ok(of >= 0 and String(d["actions"][of]["text"]) == "Crossed out.", "a strike crosses out the wrong line")
		"struck":
			var d := LetterScript.parse("It looks like %s mourning.\n" % ex)
			var st: Dictionary = {}
			for a in d["actions"]:
				if String(a["kind"]) == "strike":
					st = a
			_ok(not st.is_empty() and st.has("x1") and String(d["actions"][int(st["of"])]["text"]).ends_with("morning")
				and bool(d["actions"].back().get("cont", false)) and (d["spoken"] as PackedStringArray).has("morning")
				and not String(d["speakable"]).contains("struck"),
				"struck words are not written, said and crossed out alone, the words after them beside them")
		"color":
			var d := LetterScript.parse("Before %s after.\n" % ex)
			var swap: Dictionary = {}
			for a in d["actions"]:
				if String(a["kind"]) == "swap":
					swap = a
			_ok(Array(d["pens"]) == ["", "red"] and not swap.is_empty() and String(d["actions"].back()["ink"]) == "red"
				and not String(d["speakable"]).contains("color"),
				"an ink mark does not change the pen there, or is read aloud")
		"unspoken":
			var d := LetterScript.parse("Said.\n\n%s\n" % ex)
			var line: Dictionary = d["actions"].back()
			_ok(String(line["text"]) == "Dear Ink," and int(line["span"]) == 0
				and not String(d["speakable"]).contains("Dear"), "an unspoken line is said, or not written")
			var inline := LetterScript.parse("I said %s goodbye.\n" % ex)
			_ok(String(inline["actions"][0]["text"]) == "I said Dear Ink, goodbye." and not String(inline["speakable"]).contains("Dear")
				and String(inline["speakable"]).contains("goodbye"), "unspoken words inside a line are said, or not written")
		"sketch_timed":
			# its time told, its key its words' (the drawing made untimed is kept), seen by a page and painted by nobody
			var prompt := "a tree of small dots"
			var tree := {Manuscript.image_key(prompt): dot}
			var timed := LetterScript.parse("%s\n\nAfter it.\n" % ex, 1, tree)
			var plain := LetterScript.parse("<!-- sketch: %s -->\n\nAfter it.\n" % prompt, 1, tree)
			var t_draw: Dictionary = timed["actions"][0]
			var p_draw: Dictionary = plain["actions"][0]
			_ok(String(t_draw["kind"]) == "draw" and is_equal_approx(float(t_draw.get("drawn_in", 0.0)), 10.0)
				and String(p_draw["kind"]) == "draw" and not p_draw.has("drawn_in")
				and String(t_draw["key"]) == String(p_draw["key"]) and not String(timed["speakable"]).contains("10"),
				"a timed sketch is not drawn, not told its time, or is read aloud")
			var imgs := Manuscript.images("Prose.\n\n%s\n\nMore prose.\n" % ex)
			_ok(imgs.size() == 1 and String(imgs[0]["placement"]) == "sketch" and String(imgs[0]["prompt"]) == prompt
				and not LetterScript.pictures_only(ex).contains("sketch"),
				"a timed sketch is not a page's sketch, or is handed to the painter")
		"point":
			var d := LetterScript.parse("<!-- sketch: a dot -->\n\nA dot.\n\n%s *That one.*\n" % ex, 1, svgs)
			var pt: Dictionary = d["actions"].back()
			_ok(String(pt["kind"]) == "point" and String(pt["part"]) == "the-dot"
				and String(d["actions"][int(pt["of"])]["kind"]) == "draw" and int(pt["after"]) == 2,
				"a point does not go to the part of the sketch it names")
			_ok(not String(d["speakable"]).contains("point"), "a point is read aloud")
		"tap":
			var d := LetterScript.parse("One.\n\n%s\n\n*Two.*\n" % ex)
			_ok(String(d["actions"].back()["kind"]) == "tap" and String(d["speakable"]).contains("action-hold"),
				"a tap is not the pen's, or the voice does not wait for it")
		"image_end":
			var d := LetterScript.parse("<!-- image (full): a street -->\n\nUnder it.\n\n%s\n\nAfter it.\n" % ex)
			var sp: Dictionary = d["spans"][0]
			_ok(String(sp["kind"]) == "image" and int(sp["from"]) == 0 and int(sp["to"]) == 2,
				"a picture is not shown over exactly its passage")
		"still":
			var d := LetterScript.parse("<!-- sketch: a dot -->\n\nA dot.\n\n%s\n\n*Look.*\n\nWritten.\n" % ex, 1, svgs)
			var sp: Dictionary = d["spans"][0]
			_ok(String(sp["kind"]) == "still" and int(sp["from"]) == 2 and int(sp["to"]) == 3,
				"a still does not hold from its mark to the next written line")
		"new_page":
			var d := LetterScript.parse("One.\n\n%s\n\nTwo.\n" % ex)
			_ok(bool(d["actions"].back()["turn"]) and int(d["actions"].back()["page"]) == 1,
				"a new page mark does not turn the page")
