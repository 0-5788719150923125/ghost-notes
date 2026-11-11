extends SceneTree

## Gate for THE DISPATCH DESK'S SCRIPT ([DispatchScript], next/dispatch.md), on a note with every mark
## (tests/fixtures/dispatch_note.md):
##
## - THE PHONES are the `desk:` block's labels, the room's voice the first cued;
## - THE CALLS: one dialed, the one in hand laid down open when another is called, one lying open picked back up, a ringing
##   one answered, every one hung up - nothing left open;
## - THE VOICES THROUGH A PHONE: a turn of a voice whose phone is in hand is heard through it, one whose phone lies on the
##   desk from the desk, one with none of its own open (the cashier) through somebody else's;
## - WHAT IS SAID: typed words said, shown ones and texts never - a block in capitals in sentence case, straight through
##   (the control: one with small letters keeps its capitals); where each sentence ends (never at a comma, the control); no
##   fence and no desk mark reaches the voice, and what the voice is planned to say is the desk's spoken words, word for
##   word ([ReadingPlan], the words the medium matches);
## - THE RESTS: every action that takes time leaves the voice a rest, and two pings a hesitation apart keep it between them;
##   the voice opens on a breath of the desk at rest; a walk is a moving and a ping, a beat each, under the voice (a ping
##   that gives seconds is told they are not read; THE CONTROL: a comma inside a place is kept); a session's commands are
##   typed and answered in order, the voice waiting till its last answer is printed, nothing of it said; a reply is the room's
##   next words typed into the phone that texted, still said (THE CONTROL: with no text before it, a warning);
## - THE TERMINAL: a typed block's every spoken word has its characters, a strike strikes the block before it, a print
##   prints what was typed;
## - REDACTED WORDS: in a shown block and a session they are on the screen as themselves, moved into the private plane
##   (never as written, never the mark), each character one, and drawn back with their columns; a session types them a key
##   each; a redacted run wraps whole (THE CONTROL: the same words plain wrap between them); in a typed block they are
##   warned of and neither shown nor said;
## - THE GAIN, THE BELL, THE LAMP: the knob turned from three to its number and back, the voice waiting while it turns and a
##   beat; the bell rung before the block after it, a half beat; the lamp switched off - none of them said (THE CONTROLS: a
##   gain with no number and a lamp neither on nor off are each said, and do nothing);
## - THE CONTROLS: a call to a phone not on the desk, a phone voice with no phone open, and a call left open are each said.
##
## Run: godot --headless --path . --script tests/dispatch/dispatch_script_check.gd

const FIXTURE := "res://tests/fixtures/dispatch_note.md"

var _fails: Array = []


func _init() -> void:
	var body := FileAccess.get_file_as_string(FIXTURE)
	var d := DispatchScript.parse(body)
	var actions: Array = d["actions"]
	var spoken: PackedStringArray = d["spoken"]
	var sp := String(d["speakable"])
	_ok(Array(d["phones"]) == ["AISLE", "VAN", "COUGH"], "the phones are the desk block's (%s)" % str(d["phones"]))
	_ok(String(d["room"]) == "Control", "the room's voice is the first cued (%s)" % String(d["room"]))
	_ok((d["warnings"] as PackedStringArray).is_empty(), "a sound note has nothing to say about it (%s)" % str(d["warnings"]))
	# THE CALLS
	var calls: Array = []
	for a in actions:
		if String((a as Dictionary)["kind"]) == "call":
			var moves: Array = []
			for p in a["parts"]:
				moves.append("%s:%s" % [String(p["label"]), String(p["move"])])
			calls.append(moves)
	_ok(calls == [["AISLE:dial"], ["AISLE:lay_down", "VAN:dial"], ["VAN:lay_down", "AISLE:pick_up"], ["COUGH:answer"], ["VAN:pick_up"]],
		"the calls dial, lay down, pick back up and answer (%s)" % str(calls))
	# THE VOICES THROUGH A PHONE, in the order the turns come
	var heard: Array = []
	var who := ""
	for line in sp.split("\n"):
		var s := String(line)
		var m := RegEx.create_from_string("<!--\\s*speaker\\s*:\\s*(.+?)\\s*-->").search(s)
		if m != null:
			who = m.get_string(1)
			heard.append(who + ":")
			continue
		var h := RegEx.create_from_string(Manuscript.HEARD).search(s)
		if h != null and not heard.is_empty():
			heard[heard.size() - 1] = who + ":" + h.get_string(1)
	var phone_turns: Array = heard.filter(func(x: String) -> bool: return not x.begins_with("Control"))
	_ok(phone_turns == ["Aisle:phone", "Van:phone", "Aisle:phone", "Cashier:far", "Van:desk", "Cough:phone", "Van:desk"],
		"every voice but the room's is heard through the right phone (%s)" % str(phone_turns))
	# WHAT IS SAID
	_ok(spoken.has("grocery") and spoken.has("watcher") and spoken.has("what"), "a typed block is said")
	_ok(sp.contains("What do we do with it") and not sp.contains("WHAT"),
		"a typed block in capitals is said in sentence case and straight through, its marks never reaching the voice")
	var cased := DispatchScript.said_of("[A] PREVENT THIS. [B] CONTAIN IT.\n[D]")
	var kept := DispatchScript.said_of("22:51. Target left, IT watching")
	_ok(cased == "[A] Prevent this. [B] Contain it. [D]" and kept == "22:51. Target left, IT watching",
		"a block in capitals said in sentence case, its named letters kept (the control: a block with small letters keeps its capitals: %s / %s)" % [cased, kept])
	# WHERE A SENTENCE ENDS, though the spoken words have lost their punctuation (a ping holds the radar to one): at `.`, `!`
	# or `?` (a quote after it kept) and at a paragraph's end - never at a comma (THE CONTROL)
	var ends := DispatchScript.sentence_ends({"spoken": PackedStringArray(["one", "two", "three", "four", "five", "six", "seven"]),
		"speakable": "One two. Three, four\n\nFive \"six?\" <!-- action-hold: 1.2 --> Seven"})
	_ok(Array(ends) == [0, 1, 0, 1, 0, 1, 1], "a sentence ends at its stop or its paragraph's end, never at a comma (%s)" % [Array(ends)])
	_ok(not spoken.has("contained") and not spoken.has("smiled") and not spoken.has("aisle"), "a shown block, a text or a mark is said")
	_ok(not sp.contains("```") and not sp.contains("<!-- call") and not sp.contains("<!-- ping") and sp.contains("<!-- action-hold:"),
		"a fence or a desk mark reaches the voice, or no rest does")
	var plan := ReadingPlan.make(sp, "", {"reader": "Control", "hesitate": true, "bare": 1.5, "outro": 0.0})
	var said := PackedStringArray()
	for c in plan["chunks"]:
		for w in (c as Dictionary).get("words", []):
			var n := TabletScript.norm(String((w as Dictionary).get("text", "")))
			if not n.is_empty():
				said.append(n)
	var same := said.size() == spoken.size()
	var first_off := -1
	for i in mini(said.size(), spoken.size()):
		if said[i] != spoken[i]:
			same = false
			first_off = i
			break
	_ok(same, "the voice is planned to say the desk's spoken words, word for word (%d against %d, first apart at %d: %s / %s)"
		% [said.size(), spoken.size(), first_off, said[first_off] if first_off >= 0 else "", spoken[first_off] if first_off >= 0 else ""])
	# THE RESTS
	var holds := RegEx.create_from_string("<!--\\s*action-hold\\s*:").search_all(sp).size()
	var timed := actions.filter(func(a: Dictionary) -> bool: return float(a["rest"]) > 0.0).size()
	var passes := actions.filter(func(a: Dictionary) -> bool: return bool(a.get("passing", false))).size()
	_ok(holds == timed + 1 and timed == actions.size() - passes and passes == 1,
		"every action leaves the voice a rest but a passing through, and the desk is seen first (%d rests, %d actions)" % [holds, actions.size()])
	var opening := RegEx.create_from_string("<!--\\s*action-hold\\s*:\\s*([0-9.]+)").search(sp)
	_ok(opening != null and is_equal_approx(float(opening.get_string(1)), DispatchScript.OPENING) and sp.find(opening.get_string()) < sp.find("Oh"),
		"THE DESK IS SEEN FIRST: the voice opens on the desk at rest, before any word or action")
	var p1: Dictionary = actions[0]
	var p2: Dictionary = actions[1]
	var moving: Dictionary = actions[2]
	_ok(String(moving["kind"]) == "moving" and is_equal_approx(float(moving["rest"]), DispatchScript.MOVING)
		and String(actions[3]["place"]) == "the stairwell" and is_equal_approx(float(actions[3]["rest"]), DispatchScript.PING),
		"he sets off at a moving mark and arrives at a ping, the voice waiting only a beat for each - the walk is under its words")
	var passing: Dictionary = actions[4]
	_ok(String(passing["kind"]) == "moving" and bool(passing.get("passing", false)) and is_equal_approx(float(passing["rest"]), 0.0)
		and not bool(moving.get("passing", false)) and float(moving["rest"]) > 0.0,
		"a moving straight after a ping passes through it, the voice waiting nothing (the control: one after words gives its beat)")
	var aisle := DispatchScript.ping_of("the grocery store, aisle seven")
	_ok(String(aisle["place"]) == "the grocery store, aisle seven" and float(aisle["travel"]) == 0.0,
		"the control: a comma inside a place's name is kept")
	var seconds := DispatchScript.parse("<!-- speaker: Control -->\n\n<!-- ping: the stairwell, 18 -->\n\nOh.\n")
	_ok(String((seconds["actions"] as Array)[0]["place"]) == "the stairwell" and str(seconds["warnings"]).contains("moving"),
		"a ping that gives seconds says they are not read, and where to mark the setting off instead (%s)" % str(seconds["warnings"]))
	# A REPLY: the room's next words typed into the phone that texted, and still said
	var reply: Dictionary = {}
	for a in actions:
		if String((a as Dictionary)["kind"]) == "reply":
			reply = a
	_ok(String(reply.get("label", "")) == "AISLE" and String(reply.get("text", "")) == "Good. Let him wonder." and spoken.has("wonder")
		and int(reply["to"]) - int(reply["from"]) == 4, "a reply is typed into the phone that texted as it is said (%s)" % str(reply.get("text")))
	var unanswered := DispatchScript.parse("<!-- speaker: Control -->\n\n<!-- reply -->\n\nHello.\n")
	_ok(str(unanswered["warnings"]).contains("reply") and (unanswered["actions"] as Array).is_empty(),
		"the control: a reply with no text before it is warned of, and types nothing")
	# A SESSION AT THE TERMINAL
	var session: Dictionary = {}
	for a in actions:
		if String((a as Dictionary)["kind"]) == "session":
			session = a
	var steps: Array = session.get("steps", [])
	_ok(steps.size() == 3 and String(steps[1]["typed"]) == "search subject" and (steps[1]["out"] as PackedStringArray) == PackedStringArray(["1 MATCH"])
		and (steps[2]["out"] as PackedStringArray).is_empty() and is_equal_approx(float(session["rest"]), float(session["plan"]["rest"]))
		and float(session["plan"]["rest"]) <= float(session["plan"]["len"]),
		"a session's commands are typed and answered in order, the voice waiting for all of it (%s)" % str(steps.map(func(x: Dictionary) -> String: return String(x["typed"]))))
	_ok(not sp.contains("subjects") and not sp.contains("MATCH"), "nothing of a session is said")
	var splan: Dictionary = session["plan"]
	var keys: PackedFloat32Array = splan["steps"][1]["keys"]
	_ok(keys.size() == "search subject".length() and float(splan["steps"][1]["prompt"]) > float(splan["steps"][0]["lines"][0])
		and float(splan["steps"][1]["enter"]) > keys[keys.size() - 1] and float(splan["steps"][1]["lines"][0]) > float(splan["steps"][1]["enter"]),
		"each command's prompt comes up after the answer before it, its keys one at a time, Enter, then its answer")
	_ok(String(p1["kind"]) == "ping" and String(p2["kind"]) == "ping" and int(p1["after"]) == 0 and int(p2["after"]) == 0
		and is_equal_approx(float(p2["fwd"]) - float(p1["fwd"]), float(p1["rest"]) + DispatchScript.REST_PAD + 1.5)
		and float(p1["back"]) > float(p2["back"]), "two pings a hesitation apart keep it between them (%.2f, %.2f)" % [float(p1["fwd"]), float(p2["fwd"])])
	# THE TERMINAL
	var typed: Dictionary = {}
	var printed: Dictionary = {}
	var struck: Dictionary = {}
	for a in actions:
		match String((a as Dictionary)["kind"]):
			"type":
				if typed.is_empty():
					typed = a
			"print":
				printed = a
			"strike":
				struck = a
	var spans: Array = typed.get("spans", [])
	_ok(spans.size() == int(typed["to"]) - int(typed["from"]) and int(spans[0]["c0"]) == 0
		and int(spans.back()["c1"]) == String(typed["text"]).length(), "a typed block's every spoken word has its characters")
	_ok(String(actions[int(struck["block"])]["text"]).begins_with("WHAT") and bool(actions[int(struck["block"])].get("struck", false)),
		"a strike strikes the block typed before it")
	_ok(Array(printed["lines"]).has("23:21. Grocery store. Watcher in place."), "a print prints what was typed (%s)" % str(printed.get("lines")))
	var shown := DispatchScript.shown_of("WHAT <!-- hesitation --> DO WE <!-- hesitation --> DO")
	_ok(shown == "WHAT DO WE DO", "a typed block's marks leave no gap on the screen (%s)" % shown)
	# REDACTED WORDS
	var screen_a: Dictionary = {}
	for a in actions:
		if String((a as Dictionary)["kind"]) == "screen":
			screen_a = a
	var plate := String(String(screen_a["text"]).split("\n")[2])
	var drawn := DispatchScript.unredacted(plate)
	_ok(not plate.contains("XKC") and not plate.contains("<!--") and plate.length() == "PLATE ....... XKC 4417".length()
		and String(drawn["text"]) == "PLATE ....... XKC 4417" and drawn["spans"] == [Vector2i(14, 22)],
		"a shown block's redacted words are on the screen as themselves, hidden, by their columns (%s, %s)" % [plate, str(drawn)])
	_ok((DispatchScript.unredacted("STATUS ...... CONTAINED")["spans"] as Array).is_empty(), "the control: a plain line has no redacted run")
	var hid := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n> search <!-- redact: jane doe -->\n1 MATCH\n```\n\nThere.\n")
	var hstep: Dictionary = hid["actions"][0]["steps"][0]
	var hkeys: PackedFloat32Array = hid["actions"][0]["plan"]["steps"][0]["keys"]
	var htyped := DispatchScript.unredacted(String(hstep["typed"]))
	_ok(String(htyped["text"]) == "search jane doe" and htyped["spans"] == [Vector2i(7, 15)] and hkeys.size() == "search jane doe".length()
		and not String(hstep["typed"]).contains("jane"), "a session types its redacted words a key each, hidden (%s, %d keys)" % [str(htyped), hkeys.size()])
	var wide := "x".repeat(66) + " "
	var run_lines := DispatchScript.wrapped(wide + DispatchScript.redacted("<!-- redact: AB CD EF -->"), DispatchScript.COLUMNS)
	var plain_lines := DispatchScript.wrapped(wide + "AB CD EF", DispatchScript.COLUMNS)
	_ok(run_lines.size() == 2 and String(DispatchScript.unredacted(run_lines[1])["text"]) == "AB CD EF" and String(plain_lines[0]).ends_with("AB"),
		"a redacted run wraps whole (the control: plain, it wraps between its words - %s / %s)" % [str(run_lines), str(plain_lines)])
	var said_hid := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```type\nLOGGED <!-- redact: JANE DOE -->.\n```\n")
	_ok(String(said_hid["warnings"][0]).begins_with("redact:") and not (said_hid["spoken"] as PackedStringArray).has("jane")
		and not String(said_hid["actions"][0]["text"]).contains("JANE"), "a typed block's redacted words are warned of, never shown or said")
	# THE GAIN, THE BELL, THE LAMP
	var gains: Array = actions.filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "gain")
	var turn := DispatchScript.GAIN_REACH + DispatchScript.GAIN_STEP * 6.0 + DispatchScript.GAIN_BEAT
	_ok(gains.size() == 2 and int(gains[0]["from"]) == 3 and int(gains[0]["to"]) == 9 and int(gains[1]["from"]) == 9 and int(gains[1]["to"]) == 3
		and is_equal_approx(float(gains[0]["rest"]), turn) and is_equal_approx(float(gains[1]["rest"]), turn),
		"the gain knob is turned from three to nine and back, the voice waiting while it turns and a beat (%s)" % str(gains.map(func(a: Dictionary) -> String: return "%d-%d" % [a["from"], a["to"]])))
	var bell_i := -1
	for i in actions.size():
		if String((actions[i] as Dictionary)["kind"]) == "bell":
			bell_i = i
	_ok(bell_i >= 0 and bell_i + 1 < actions.size() and String(actions[bell_i + 1]["kind"]) == "screen"
		and int(actions[bell_i + 1]["after"]) == int(actions[bell_i]["after"]) and is_equal_approx(float(actions[bell_i]["rest"]), DispatchScript.BELL),
		"the bell is rung in the silence before the block after it, the voice waiting half a beat")
	var lamps: Array = actions.filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "lamp")
	_ok(lamps.size() == 1 and not bool(lamps[0]["on"]), "the lamp is switched off")
	_ok(not sp.contains("gain") and not sp.contains("bell") and not sp.contains("lamp") and not spoken.has("nine"),
		"a gain, a bell or a lamp reaches the voice")
	var odd := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n<!-- gain: loud -->\n\n<!-- lamp: dim -->\n\nThere.\n")
	_ok((odd["actions"] as Array).is_empty() and str(odd["warnings"]).contains("gain: loud") and str(odd["warnings"]).contains("lamp: dim"),
		"the controls: a gain with no number and a lamp neither on nor off are each said, and do nothing (%s)" % str(odd["warnings"]))
	# PICTURES
	var full: Array = d["spans"]
	_ok(full.size() == 1 and int(full[0]["to"]) > int(full[0]["from"]), "a picture over the whole screen spans its passage")
	_ok(Manuscript.images(DispatchScript.pictures_only(body)).size() == 2, "every picture is handed to the painter")
	_ok(DispatchScript.rehearsal(d).size() == spoken.size(), "a rehearsal times every spoken word")
	# THE CONTROLS
	var stray := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n<!-- call: NOBODY -->\n\n<!-- speaker: Red -->\n\nHello.\n")
	_ok(not (stray["warnings"] as PackedStringArray).is_empty() and Array(stray["phones"]).has("NOBODY"),
		"the control: a call to a phone not on the desk, left open, is said")
	var mute := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n<!-- speaker: Red -->\n\nHello.\n")
	_ok(String(mute["warnings"][0]).contains("no phone open") and not String(mute["speakable"]).contains("heard"),
		"the control: a phone voice with no phone open is said, and heard in the room")
	if _fails.is_empty():
		print("dispatch_script_check: ALL OK (%d words, %d actions)" % [spoken.size(), actions.size()])
		quit(0)
	else:
		for f in _fails:
			print("dispatch_script_check: FAIL  " + f)
		quit(1)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
