extends SceneTree

## Gate for the dispatch desk's script ([DispatchScript], [DispatchTerminal], next/dispatch.md), on a note with every mark
## (tests/fixtures/dispatch_note.md). It holds:
##
## - phones are the `desk:` block's labels, the room's voice the first cued;
## - calls: one dialed, the one in hand laid down open when another is called, one lying open picked back up, a ringing one
##   answered, every one hung up;
## - voices: a voice whose phone is in hand is heard through it, one whose phone lies on the desk from the desk, one with
##   none open while a phone is at the ear through it (somebody in the caller's room); a voice with no phone on the desk,
##   with none at the ear, on the receiver; `heard:` after a cue says outright (controls: the cashier at Aisle's ear is not
##   on the receiver; a voice with a phone not open is warned of and heard in the room);
## - what is said: typed words are said, panels and pages and texts never; a line in capitals is said in sentence case, a
##   block with no capital its sentences raised (controls: a block of both keeps its capitals; as typed, a small block is one
##   sentence); sentences end at `.`, `!`, `?`, never at a comma; no fence or desk mark
##   reaches the voice, and the planned words are the desk's spoken words ([ReadingPlan]);
## - rests: every action that takes time leaves the voice a rest, the voice opens on a breath, two pings a hesitation apart
##   keep it between them; a walk is a moving and a ping, a beat each; a reply is the next words typed into the phone that
##   texted, still said (control: with no text before it, a warning);
## - the terminal, one block: the glass set as a fixed screen (title bar, header, body, keys spread, command line), panels
##   kept by id and opened again by a key as they last stood, typed lines kept with them, a digit's panel written after it,
##   a series key, `set:` straight after its panel is come back to there as the panel is drawn (the control: on a panel that
##   has been up, the row changed in place), `{N}` holding a line part-drawn, `wait:` in place of the read (the control:
##   with none, the panel is read), `clear`, the body scrolling past sixteen rows, a command that opens nothing an INVALID
##   OPTION and a warning, a strike taking the typed line off the glass, a print of what was typed (with none, the panel up); a
##   typed line naming an option chooses it - typed at the prompt, that row in inverse, read and thought over first, the camera
##   held on it after (the control: a line naming none is typed into the body); `select:` moves a bar in inverse over the
##   panel's cells with the arrow keys, down the first column then the second, Enter opening the panel written next, the bar
##   kept where it stopped on a kept panel (the control: a label naming no cell is warned of and does nothing);
## - redacted words on the glass are themselves in the private plane, each character one, drawn back with their columns; a
##   command types them a key each; a run wraps whole (control: plain words wrap between them); on a said line they are
##   warned of and neither shown nor said;
## - pings by bearing and range: where a radar reports a contact, a place named again bare the same spot (control: a place
##   never given numbers is warned of and laid out from the words);
## - fades: the voice waits for them, what is marked in the black happens at once, the first ping after one has no track, a
##   fade up on a time; a note opening on one opens in the black with no breath before it (control: the fixture's breath);
##   a said line's time far off the clock is warned of (control: one in step is not);
## - a picture on a screen told `unwatched` is the same picture, marked for the camera and painted as any other (controls: a
##   word a picture is not told, and a picture over the whole screen told one, are each warned of);
## - the tablet: pages typed into the bar or tapped from the page up (or come back to), never said; a replay says the room's
##   earlier words again through the tablet (control: words never said are warned of); a clip on a screen is a picture with
##   its file, handed to the Pictures card as a clip;
## - the tablet browsed as the tablet medium browses (tests/fixtures/dispatch_browsing.md): back to the page before in its
##   tab and a link tapped from it, a new tab with the next address typed into it, a search typed into a search engine's own
##   box at the tablet's pace and from an article into the bar (its results the engine's last used), a reply typed into the
##   page's message box and that page loaded again (controls: back and new tab with the tablet down, a reply with no page
##   up and a back with nothing behind it are each warned of and do nothing; a search with no page up goes in the bar);
## - gain, bell, lamp: the knob turns from three to its number and back with the voice waiting; the bell rings a half beat
##   before the block after it; the lamp is switched; none are said (controls: a gain with no number and a lamp neither on
##   nor off are said and do nothing);
## - the receiver: lines typed in a voice with no phone are said in it, on the storm the receiver last opened on (Io-B's
##   crackle before any), and the room's voice comes back after (the control: a bare `type:` is the room's);
## - a synced note's words, which come without their frontmatter, are read with the note's put back (control: alone, the
##   terminal's keys and the desk block are missing);
## - a command held with `{2}` is typed, held that long and then entered (the control: bare, at once);
## - controls: a call to a phone not on the desk, and a call left open, are each said;
## - a text answering the room's reply comes no sooner than the other end could type it (the control: a text answering nothing),
##   and the room's reply waits for its own typing on the keypad;
## - the grid down, the Environment switched and a film on the terminal ([method _grid_down]);
## - the flip clock's cards fall as a flap let go, slap down within a fifth of a second and bounce (the control: an even turn
##   is half way at half its time), the rightmost changed digit first; a digit that stays never flaps.
##
## Run: godot --headless --path . --script tests/dispatch/dispatch_script_check.gd

const FIXTURE := "res://tests/fixtures/dispatch_note.md"
const BROWSING := "res://tests/fixtures/dispatch_browsing.md"

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
	# calls
	var calls: Array = []
	for a in actions:
		if String((a as Dictionary)["kind"]) == "call":
			var moves: Array = []
			for p in a["parts"]:
				moves.append("%s:%s" % [String(p["label"]), String(p["move"])])
			calls.append(moves)
	_ok(calls == [["AISLE:dial"], ["AISLE:lay_down", "VAN:dial"], ["VAN:lay_down", "AISLE:pick_up"], ["COUGH:answer"], ["VAN:pick_up"]],
		"the calls dial, lay down, pick back up and answer (%s)" % str(calls))
	# voices through a phone, in the order the turns come
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
	_ok(phone_turns == ["Aisle:phone", "Van:phone", "Aisle:phone", "Cashier:far", "Van:desk", "Cough:phone", "Council:receiver", "Van:desk",
		"Van:tablet"], "every voice but the room's is heard through the right phone, the receiver or the tablet (%s)" % str(phone_turns))
	# what is said
	_ok(spoken.has("grocery") and spoken.has("watcher") and spoken.has("what"), "a typed line is said")
	_ok(sp.contains("What do we do with it") and not sp.contains("WHAT"),
		"a typed line in capitals is said in sentence case and straight through, its marks never reaching the voice")
	var cased := DispatchScript.said_of("[A] PREVENT THIS. [B] CONTAIN IT.\n[D]")
	var kept := DispatchScript.said_of("22:51. Target left, IT watching")
	_ok(cased == "[A] Prevent this. [B] Contain it. [D]" and kept == "22:51. Target left, IT watching",
		"a block in capitals said in sentence case, its named letters kept (the control: a block with small letters keeps its capitals: %s / %s)" % [cased, kept])
	# a block with no capital has its sentences raised, so the voice and the captions part it into its sentences (the control:
	# as typed, a small letter after a full stop runs on, the whole block one sentence)
	var typed_small := "they say he was ahead of his time. he wasn't ahead of anything.\nnobody is behind? i'm not. i know."
	var raised := DispatchScript.said_of(typed_small)
	var raised_parts := Phonemes.parse(raised).size()
	var run_on := Phonemes.parse(" ".join(typed_small.split("\n"))).size()
	_ok(raised == "They say he was ahead of his time. He wasn't ahead of anything. Nobody is behind? I'm not. I know." and raised_parts == 5 and run_on == 1,
		"a block with no capital is said with its sentences raised, five sentences (the control: as typed, %d) - %s" % [run_on, raised])
	# where a sentence ends, though the spoken words have lost their punctuation (a ping holds the radar to one): at `.`, `!` or `?`
	# (a quote after it kept) and at a paragraph's end, never at a comma (control)
	var ends := DispatchScript.sentence_ends({"spoken": PackedStringArray(["one", "two", "three", "four", "five", "six", "seven"]),
		"speakable": "One two. Three, four\n\nFive \"six?\" <!-- action-hold: 1.2 --> Seven"})
	_ok(Array(ends) == [0, 1, 0, 1, 0, 1, 1], "a sentence ends at its stop or its paragraph's end, never at a comma (%s)" % [Array(ends)])
	_ok(not spoken.has("contained") and not spoken.has("smiled") and not spoken.has("aisle"), "a panel, a text or a mark is said")
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
	# rests
	var holds := RegEx.create_from_string("<!--\\s*action-hold\\s*:").search_all(sp).size()
	var timed := actions.filter(func(a: Dictionary) -> bool: return float(a["rest"]) > 0.0).size()
	var at_once: Array = []
	for a in actions:
		if float((a as Dictionary)["rest"]) <= 0.0:
			at_once.append("passing" if bool(a.get("passing", false)) else ("dark" if bool(a.get("dark", false)) else String(a["kind"])))
	_ok(holds == timed + 1 and at_once == ["passing", "receiver", "dark", "replay"],
		"every action leaves the voice a rest but a passing through, a voice on the receiver, one in the black and a replay, and the desk is seen first (%d rests, %s)" % [holds, str(at_once)])
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
	# a reply: the room's next words typed into the phone that texted, and still said
	var reply: Dictionary = {}
	for a in actions:
		if String((a as Dictionary)["kind"]) == "reply":
			reply = a
	_ok(String(reply.get("label", "")) == "AISLE" and String(reply.get("text", "")) == "Good. Let him wonder." and spoken.has("wonder")
		and int(reply["to"]) - int(reply["from"]) == 4, "a reply is typed into the phone that texted as it is said (%s)" % str(reply.get("text")))
	var unanswered := DispatchScript.parse("<!-- speaker: Control -->\n\n<!-- reply -->\n\nHello.\n")
	_ok(str(unanswered["warnings"]).contains("reply") and (unanswered["actions"] as Array).is_empty(),
		"the control: a reply with no text before it is warned of, and types nothing")
	# a session at the terminal: the first block, set on the glass
	var cfg: Dictionary = d["terminal"]
	var session: Dictionary = actions[_first(actions, "session")]
	var ops: Array = session["ops"]
	var after := DispatchTerminal.at(session["glass"], ops, INF)
	var rows := DispatchTerminal.rows_of(after, cfg)
	var lines: PackedStringArray = rows["lines"]
	var pad := " ".repeat((DispatchTerminal.COLUMNS - 60) / 2)
	_ok(lines.size() == DispatchTerminal.ROWS and String(lines[0]).begins_with(pad + "COUNCIL") and String(lines[0]).ends_with("RECORD")
		and String(lines[0]).length() == pad.length() + 60 and (rows["bar"] as Vector2i) == Vector2i(pad.length(), pad.length() + 60)
		and String(lines[1]).begins_with(pad + "SUBJECT 1 OF 1") and String(lines[1]).ends_with("PAGE 1 OF 1") and String(lines[2]).is_empty()
		and String(lines[DispatchTerminal.BODY_TOP]) == pad + "NAME ........ SUBJECT"
		and String(lines[DispatchTerminal.KEYS_ROW]).begins_with(pad + "L LOG") and String(lines[DispatchTerminal.KEYS_ROW]).ends_with("X MENU")
		and String(lines[DispatchTerminal.COMMAND_ROW]) == pad + DispatchTerminal.PROMPT,
		"the glass is a fixed screen: title bar, header, body, keys spread across, the command line (%s)" % str(lines).replace("\\n", "/"))
	_ok((after["kept"] as Dictionary).has("menu") and (after["kept"] as Dictionary).has("matches") and (after["kept"] as Dictionary).has("record-1")
		and String(after["up"]) == "record-1", "panels with an id are kept, the last one up (%s)" % str((after["kept"] as Dictionary).keys()))
	var cmds: Array = ops.filter(func(o: Dictionary) -> bool: return String(o["op"]) == "command")
	var opens: Array = ops.filter(func(o: Dictionary) -> bool: return String(o["op"]) == "open")
	var in_order := true
	for k in range(1, ops.size()):
		if float(ops[k]["t"]) < float(ops[k - 1]["t"]):
			in_order = false
	var c3: Dictionary = cmds[2]
	var c3_keys: PackedFloat32Array = c3["keys"]
	_ok(String(ops[0]["op"]) == "wake" and cmds.size() == 3 and opens.size() == 3 and in_order and c3_keys.size() == "open 1".length()
		and float(c3["enter"]) > c3_keys[c3_keys.size() - 1] and float(opens[2]["t"]) > float(c3["enter"]),
		"asleep, it wakes; each command typed a key at a time and entered, then the panel it opens (%d commands, %d panels)" % [cmds.size(), opens.size()])
	var waited := float(cmds[1]["t"]) - float(ops.filter(func(o: Dictionary) -> bool: return String(o["op"]) == "wait")[0]["t"])
	var matches_line: Dictionary = ops.filter(func(o: Dictionary) -> bool: return String(o["op"]) == "line" and String(o["text"]).contains("SUBJECT"))[0]
	var read := float(c3["t"]) - float(matches_line["t"]) - DispatchTerminal.LINE_EACH
	_ok(is_equal_approx(waited, 1.5) and read > DispatchTerminal.READ_LEAST - 0.01 and read <= DispatchTerminal.READ_MOST + 0.01,
		"a wait holds what is up as long as it says, in place of the read (the control: with none the panel is read, %.2f s)" % read)
	_ok(float(session["rest"]) <= float(session["len"]) and not spoken.has("council") and not spoken.has("subjects") and not spoken.has("match"),
		"nothing of a block is said but its typed lines, the voice waiting for its steps")
	# a command held typed before it is entered (`{1.5}`), then the panel it opens (the control: the same command bare, entered at
	# once)
	var held_ops := func(cmd: String) -> Dictionary:
		var p := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n%s\npanel: done = DONE\n```\n\nSaid.\n" % cmd)
		var sess: Dictionary = (p["actions"] as Array).filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "session")[0]
		return (sess["ops"] as Array).filter(func(o: Dictionary) -> bool: return String(o["op"]) == "command")[0]
	var held_cmd: Dictionary = held_ops.call("> d {1.5}")
	var bare_cmd: Dictionary = held_ops.call("> d")
	var held_wait := float(held_cmd["enter"]) - (held_cmd["keys"] as PackedFloat32Array)[0]
	var bare_wait := float(bare_cmd["enter"]) - (bare_cmd["keys"] as PackedFloat32Array)[0]
	_ok(String(held_cmd["text"]) == "d" and is_equal_approx(held_wait - bare_wait, 1.5),
		"a command held `{1.5}` is typed, held that long, then entered - its mark never typed (%.2f s; the control, bare, %.2f s)" % [held_wait, bare_wait])
	# a typed line is added to the panel up and kept with it; a key opens that panel again as it last stood
	var log := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n> log\npanel: log = LOG\ntype: ONE.\n```\n\nSaid.\n\n"
		+ "```terminal\n> x\npanel: menu = MENU\nkeys: L LOG > log\n> l\n```\n")
	var back: Dictionary = (log["actions"] as Array).back()
	var shown_log := DispatchTerminal.at(back["glass"], back["ops"], INF)
	_ok(String(shown_log["up"]) == "log" and Array(DispatchTerminal.up(shown_log)["body"]) == ["ONE."] and (log["warnings"] as PackedStringArray).is_empty(),
		"a typed line is kept with its panel, and a key opens that panel again as it last stood (%s)" % str(DispatchTerminal.up(shown_log).get("body")))
	# a typed line naming an option chooses it: typed on the command line, no line added, that row in inverse; the panel read
	# and thought over before, the camera held on the choice after (the control: a line naming no option is typed into the body)
	var pick := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n> f\npanel: form = FORM 7\nCHOOSE ONE.\n"
		+ "    [A] DID NOT NOTICE\n    [D] ALL OF THE ABOVE\ntype: [D]\n```\n\nSaid.\n")
	var pacts: Array = pick["actions"]
	var pi := _nth(pacts, "type", 0)
	var pty: Dictionary = pacts[pi]
	var psess: Dictionary = pacts[pi - 1]
	var ptext := String(pty["text"])
	var half := DispatchTerminal.typed(pty["glass"], ptext, 1)
	var chose := DispatchTerminal.typed(pty["glass"], ptext, ptext.length())
	var prows := DispatchTerminal.rows_of(chose, pick["terminal"])
	var plain := DispatchTerminal.typed(pty["glass"], "ONE.", 4)
	var after_pick: Dictionary = pacts[pi + 1] if pi + 1 < pacts.size() else {}
	_ok(DispatchTerminal.up(chose)["body"] == DispatchTerminal.up(pty["glass"])["body"] and (prows["chosen"] as Vector3i).x == DispatchTerminal.BODY_TOP + 2
		and String(half.get("command", "")) == "[" and String(after_pick.get("kind", "")) == "look" and String(after_pick.get("at", "")) == "terminal"
		and float(after_pick.get("rest", 0.0)) >= DispatchTerminal.CHOICE_HOLD
		and float(psess["rest"]) >= float(psess["len"]) - 0.001 and float(psess["rest"]) >= DispatchTerminal.READ_LEAST + DispatchTerminal.CHOICE_THINK
		and (DispatchTerminal.up(plain)["body"] as PackedStringArray).size() == (DispatchTerminal.up(pty["glass"])["body"] as PackedStringArray).size() + 1
		and DispatchTerminal.choice_row(pty["glass"], "ONE.") < 0,
		"a typed [D] under its option chooses it - typed at the prompt, that row in inverse, read and thought over first (%.1f s), held after - the control: ONE. is typed into the body (%s)"
		% [float(psess["rest"]), str(prows["chosen"])])
	# said lines one straight after another in one voice are one passage: one action typed on over its line breaks, one
	# paragraph read through, one rest before its first words (the controls: a line after a mark, a line in another voice
	# and a line naming an option each stand alone; a strike takes the passage's last line off alone)
	var page := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n> m\npanel: MIRROR\n"
		+ "type: they say he was ahead of his time.\ntype: we line them up by year.\ntype: nobody is first.\n<!-- static: 1 -->\n"
		+ "type: nobody is behind.\ntype (Council): FIRST.\n```\n\nSaid.\n\n```terminal\n> f\npanel: form = FORM 7\n"
		+ "    [A] DID NOT NOTICE\n    [D] ALL OF THE ABOVE\ntype: ONE MORE.\ntype: [D]\n```\n\nThen.\n\n"
		+ "```terminal\ntype: kept line.\ntype: taken back.\nstrike\n```\n\nEnd.\n")
	var gacts: Array = page["actions"]
	var typed_texts: Array = gacts.filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "type").map(
		func(a: Dictionary) -> String: return String(a["text"]))
	var passage: Dictionary = gacts[_nth(gacts, "type", 0)]
	var speakable := String(page["speakable"])
	var g_strike: Array = gacts.filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "strike")
	_ok(String(passage["text"]) == "they say he was ahead of his time.\nwe line them up by year.\nnobody is first."
		and int(passage["to"]) - int(passage["from"]) == 17 and (passage["spans"] as Array).size() == 17
		and speakable.contains("They say he was ahead of his time. We line them up by year. Nobody is first.\n\n")
		and float(passage["rest"]) < DispatchScript.TYPE_LEAD + 2.0,
		"three said lines in a row are one passage, typed on and read through, one rest before it (%s; %.1f s)"
			% [str(typed_texts), float(passage["rest"])])
	_ok(typed_texts.size() == 7 and typed_texts[1] == "nobody is behind." and typed_texts[2] == "FIRST." and typed_texts[3] == "ONE MORE."
		and typed_texts[4] == "[D]" and typed_texts[5] == "kept line." and typed_texts[6] == "taken back."
		and g_strike.size() == 1 and String(gacts[int(g_strike[0]["block"])]["text"]) == "taken back.",
		"the controls: a line after a mark, one in another voice and one naming an option stand alone, a strike takes the last line alone (%s)"
			% str(typed_texts))
	# read: the other side's typing, read aloud behind the keys as one passage, never printed or struck (the control: a type:
	# line beside it is printed; read and type lines in a row stay two passages)
	var mirror := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n> m\npanel: MIRROR\n"
		+ "read: nobody is first.\nread: nobody is behind?\ntype: logged.\nprint\nread: one more.\nstrike\n```\n\nEnd.\n")
	var macts: Array = mirror["actions"]
	var mread: Dictionary = macts[_nth(macts, "type", 0)]
	var mprint: Dictionary = macts[_nth(macts, "print", 0)] if _nth(macts, "print", 0) >= 0 else {}
	var mstrike: Dictionary = macts[_nth(macts, "strike", 0)] if _nth(macts, "strike", 0) >= 0 else {}
	var mprinted := str(mprint.get("lines", ""))
	_ok(String(mread["text"]) == "nobody is first.\nnobody is behind?" and bool(mread.get("theirs", false))
		and String(mirror["speakable"]).contains("Nobody is first. Nobody is behind?") and int(mread["to"]) - int(mread["from"]) == 6
		and mprinted.contains("logged.") and not mprinted.contains("nobody") and String(macts[int(mstrike.get("block", 0))]["text"]) == "logged.",
		"read: lines are read aloud as one passage, never printed or struck; the control: the type: line beside them is (%s; %s)"
			% [mprinted, str(mirror["warnings"])])
	# a block's last key: lines that the paragraph straight after it says are typed ahead of its words: out of the silent
	# block, each word said anchored to its place in the paragraph, what is typed before or past them carried along (the
	# controls: a picture between, or a paragraph saying something else, leaves the line in the block, typed before the voice)
	var key_line := "key: HIM: there was a man in a bathrobe at the end of the aisle. I used to get angry. if you can see the rot, you can see it.\n"
	var said_para := "There was a man in a bathrobe at the end of the aisle. I used to get angry.\n"
	var keyed_doc := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n> m\npanel: MIRROR | HIS SCREEN\n" + key_line
		+ "```\n\n" + said_para)
	var kacts: Array = keyed_doc["actions"]
	var ksess: Dictionary = kacts[_nth(kacts, "session", 0)]
	var kty: Dictionary = kacts[_nth(kacts, "type", 0)] if _nth(kacts, "type", 0) >= 0 else {}
	var kspans: Array = kty.get("spans", [])
	var kspoken: PackedStringArray = keyed_doc["spoken"]
	var keyed_ops := (ksess["ops"] as Array).filter(func(o: Dictionary) -> bool: return String(o["op"]) == "key").size()
	_ok(keyed_ops == 0 and bool(kty.get("theirs", false)) and kspans.size() == 18 and kspoken[int(kspans[0]["word"])] == "there"
		and int(kspans[0]["c0"]) == 0 and kspoken[int(kspans.back()["word"])] == "angry" and int(kty["to"]) == kspoken.size()
		and int(kspans.back()["c1"]) < String(kty["text"]).length() and String(keyed_doc["speakable"]).count("bathrobe") == 1,
		"a key: line the paragraph after it says is typed ahead of those words, its prefix and its unsaid end carried along (%d key steps left, %d words anchored)"
			% [keyed_ops, kspans.size()])
	var pictured := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n> m\npanel: MIRROR | HIS SCREEN\n" + key_line
		+ "```\n\n<!-- image (full): an aisle -->\n\n" + said_para)
	var other := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n> m\npanel: MIRROR | HIS SCREEN\n" + key_line
		+ "```\n\nHe has never written that down before tonight.\n")
	var stays := func(d: Dictionary) -> bool:
		var acts: Array = d["actions"]
		return _nth(acts, "type", 0) < 0 and (acts[_nth(acts, "session", 0)]["ops"] as Array).filter(
			func(o: Dictionary) -> bool: return String(o["op"]) == "key").size() == 1
	_ok(stays.call(pictured) and stays.call(other),
		"the controls: a picture between the block and the paragraph, or a paragraph saying something else, leaves the key: line in the block")
	# lines drawn onto a panel already up are read before the next key, silently (the controls: a wait: says how long instead;
	# with nothing drawn the key follows at once)
	var answer := "show: MACHINE: That's a generous way to see them. Most of the people around you tonight were buying groceries. Get some sleep."
	var up_glass: Dictionary = DispatchTerminal.compile(PackedStringArray(["panel: MIRROR | HIS SCREEN"]), DispatchTerminal.blank(),
		DispatchTerminal.config_of(""), PackedStringArray())["glass"]
	var key_at := func(block: Array) -> float:
		var r := DispatchTerminal.compile(PackedStringArray(block), up_glass, DispatchTerminal.config_of(""), PackedStringArray())
		var shown_by := 0.0
		var key_t := -1.0
		for o in r["ops"]:
			if String(o["op"]) == "key":
				key_t = float(o["t"])
			elif key_t < 0.0:
				shown_by = float(o["t"])
		return key_t - shown_by
	var digest: float = key_at.call([answer, "HOW DID IT DO?    1 BAD    2 FINE    3 GOOD", "key: HIM: 3"])
	var held_1: float = key_at.call([answer, "wait: 1", "key: HIM: 3"])
	_ok(digest >= DispatchTerminal.READ_LEAST + DispatchTerminal.READ_DRAWN * 20.0 and digest <= DispatchTerminal.READ_DRAWN_MOST + 0.5
		and held_1 < DispatchTerminal.READ_LEAST + 0.5,
		"an answer drawn onto a panel already up is read before it is answered (%.1f s; the control, wait: 1, %.1f s)" % [digest, held_1])
	# crash: the program dies on its words - the glass nothing else, the screen's whole light; in a voice, said over it on
	# the receiver (the controls: a panel drawn after it brings the program back, and so does the screen waking)
	var crash_doc := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n> m\npanel: MIRROR | SIGN OFF\nOPERATORS ON DUTY ........ 0\n"
		+ "```\n\nThere.\n\n```terminal\ncrash (Council): ERROR: ME FOUND\n```\n\nAfter.\n\n```terminal\n> m\npanel: MIRROR | BACK\n```\n")
	var cacts: Array = crash_doc["actions"]
	var crashed: Dictionary = cacts[_nth(cacts, "session", 1)]
	var crash_g := DispatchTerminal.at(crashed["glass"], crashed["ops"], INF)
	var crash_rows := DispatchTerminal.rows_of(crash_g, crash_doc["terminal"])
	var back_s: Dictionary = cacts[_nth(cacts, "session", 2)]
	var back_g := DispatchTerminal.at(back_s["glass"], back_s["ops"], INF)
	var woke := DispatchTerminal.at(crash_g, [{"op": "wake", "t": 0.0}], INF)
	_ok(String(crash_rows["crash"]) == "ERROR: ME FOUND" and DispatchTerminal.lit_share({"asleep": false, "crash": crash_rows["crash"]}) == 1.0
		and String(crashed.get("heard", "")) == DispatchScript.RECEIVER and String(crash_doc["speakable"]).contains("Error: Me found")
		and float(crashed["rest"]) >= DispatchTerminal.CRASH_HOLD and (crash_g.get("alert", PackedStringArray()) as PackedStringArray).is_empty(),
		"a crash in a voice: the glass its words alone, the screen's whole light, said over it on the receiver (%s, %s)"
			% [str(crash_rows["crash"]), str(crashed.get("heard", ""))])
	_ok(String(back_g.get("crash", "")).is_empty() and String(DispatchTerminal.up(back_g)["left"]) == "BACK" and not woke.has("crash"),
		"the controls: a panel drawn after a crash brings the program back, and so does the screen waking")
	var st_told := DispatchScript.static_of("3, surf, unwatched")
	var st_bare := DispatchScript.static_of("3, surf")
	_ok(bool(st_told[DispatchScript.UNWATCHED]) and String(st_told["kind"]) == "surf" and float(st_told["secs"]) == 3.0
		and not bool(st_bare[DispatchScript.UNWATCHED]),
		"a static told unwatched says so, its storm and length kept (the control: untold, it is watched)")
	# a clause the voice puts in, or a word it leaves out, still says the line
	var clause := DispatchScript.said_after(PackedStringArray("we line them up by year and put ourselves at the end".split(" ")),
		PackedStringArray("we line them up by year the way his class did this afternoon and we put ourselves at the end with the machines".split(" ")))
	_ok(clause.size() == 12 and (clause[6] as Vector2i) == Vector2i(6, 13) and (clause.back() as Vector2i) == Vector2i(11, 19),
		"a clause the voice puts in still says the typed line, every typed word matched where it is said (%s)" % str(clause))
	# select: the arrow keys move a bar over the cells, down the first column and then the second, a press an item, the cell
	# in inverse; Enter opens the panel written next; on a kept panel the bar is left where it stopped and starts there again,
	# and with no panel after it there is no Enter (the control: a label naming no item is warned of and does nothing)
	var sel := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n> m\npanel: list = LIST\n"
		+ "agent 1 .. working     agent 4 .. done\nagent 2 .. done        agent 5 .. working\nagent 3 .. working\n```\n\nThere.\n\n"
		+ "```terminal\nselect: agent 4\npanel: AGENT 4\nDONE.\n```\n\nNow.\n\n```terminal\npanel: list\nselect: agent 2\n```\n\nThen.\n\n"
		+ "```terminal\nselect: agent 9\n```\n\nEnd.\n")
	var sacts: Array = sel["actions"]
	var s_open: Dictionary = sacts[_nth(sacts, "session", 1)]
	var s_back: Dictionary = sacts[_nth(sacts, "session", 2)]
	var s_op: Dictionary = (s_open["ops"] as Array).filter(func(o: Dictionary) -> bool: return String(o["op"]) == "select")[0]
	var s_opened: Dictionary = (s_open["ops"] as Array).filter(func(o: Dictionary) -> bool: return String(o["op"]) == "open")[0]
	var s_presses: PackedFloat32Array = s_op["presses"]
	var s_pad := (DispatchTerminal.COLUMNS - DispatchTerminal.WIDTH) / 2
	var s_first := DispatchTerminal.rows_of(DispatchTerminal.at(s_open["glass"], s_open["ops"], s_presses[0] + 0.01), sel["terminal"])
	var s_on := DispatchTerminal.rows_of(DispatchTerminal.at(s_open["glass"], s_open["ops"], float(s_op["enter"]) - 0.01), sel["terminal"])
	var s_up := DispatchTerminal.at(s_open["glass"], s_open["ops"], INF)
	var s_op2: Dictionary = (s_back["ops"] as Array).filter(func(o: Dictionary) -> bool: return String(o["op"]) == "select")[0]
	var s_left := DispatchTerminal.rows_of(DispatchTerminal.at(s_back["glass"], s_back["ops"], INF), sel["terminal"])
	_ok(s_presses.size() == 3 and Array(s_op["path"]) == [0, 1, 2, 3] and float(s_op["enter"]) > s_presses[2]
		and float(s_opened["t"]) > float(s_op["enter"]) and (s_first["chosen"] as Vector3i) == Vector3i(DispatchTerminal.BODY_TOP + 1, s_pad, s_pad + 15)
		and (s_on["chosen"] as Vector3i) == Vector3i(DispatchTerminal.BODY_TOP, s_pad + 23, s_pad + 38)
		and String(DispatchTerminal.up(s_up)["name"]) == "AGENT 4",
		"select: a press an item down the first column then the second, the cell in inverse, Enter opening the panel written next (%s, %s)"
			% [str(s_op["path"]), str(s_on["chosen"])])
	_ok(Array(s_op2["path"]) == [3, 2, 1] and float(s_op2["enter"]) < 0.0 and (s_left["chosen"] as Vector3i) == Vector3i(DispatchTerminal.BODY_TOP + 1, s_pad, s_pad + 15)
		and _nth(sacts, "session", 3) < 0 and str(sel["warnings"]).contains("select: no item begins agent 9"),
		"select: on a kept panel the bar starts where it was left, no Enter with no panel after it; the control: agent 9 is warned of and does nothing (%s, %s)"
			% [str(s_op2["path"]), str(sel["warnings"])])
	# a series key; set: straight after the panel is come back to, the row is there as the panel is drawn, never typed again
	# (the control: on a panel that has been up a while, it is changed in place); {N}: a line part-drawn
	var again: Dictionary = actions[_nth(actions, "session", 2)]
	var reopened := DispatchTerminal.at(again["glass"], again["ops"], INF)
	var rbody: PackedStringArray = DispatchTerminal.up(reopened)["body"]
	var came_back: Dictionary = (again["ops"] as Array).filter(func(o: Dictionary) -> bool: return String(o["op"]) == "open")[0]
	var drawing := DispatchTerminal.at(again["glass"], again["ops"], float(came_back["t"]) + DispatchTerminal.LINE_EACH * 1.5)
	_ok((again["ops"] as Array).filter(func(o: Dictionary) -> bool: return String(o["op"]) == "set").is_empty()
		and int(drawing["drawn"]) == 2 and String((DispatchTerminal.up(drawing)["body"] as PackedStringArray)[1]) == "STATUS ...... LOOSE",
		"a row set straight after its panel is come back to is there as the panel is drawn, never typed again (%s)"
			% String((DispatchTerminal.up(drawing)["body"] as PackedStringArray)[1]))
	var watched: Array = DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n> x\npanel: record-1 = RECORD | A\nNAME ........ SUBJECT\n"
		+ "STATUS ...... CONTAINED\n```\n\nThere.\n\n```terminal\nwait: 1\nset: STATUS ...... LOOSE\n```\n\nNow.\n")["actions"]
	var changed: Dictionary = watched[_nth(watched, "session", 1)]
	var set_op: Dictionary = (changed["ops"] as Array).filter(func(o: Dictionary) -> bool: return String(o["op"]) == "set")[0]
	var mid_set := DispatchTerminal.at(changed["glass"], changed["ops"], float((set_op["back"] as PackedFloat32Array)[2]) + 0.001)
	var line_op: Dictionary = (again["ops"] as Array).filter(func(o: Dictionary) -> bool: return String(o["op"]) == "line")[0]
	var part := DispatchTerminal.at(again["glass"], again["ops"], float(line_op["t"]) + 1.0)
	var whole := DispatchTerminal.at(again["glass"], again["ops"], float(line_op["t"]) + 2.1)
	_ok(String(reopened["up"]) == "record-1" and rbody.size() == 4 and String(rbody[1]) == "STATUS ...... LOOSE" and String(rbody[0]) == "NAME ........ SUBJECT",
		"`> r` opens the series' first, as it last stood, and set: replaces the row beginning its label (%s)" % str(rbody))
	_ok(String((DispatchTerminal.up(mid_set)["body"] as PackedStringArray)[1]).begins_with("STATUS ...... ") and String((DispatchTerminal.up(mid_set)["body"] as PackedStringArray)[1]) != "STATUS ...... CONTAINED"
		and String((DispatchTerminal.up(mid_set)["body"] as PackedStringArray)[1]) != "STATUS ...... LOOSE",
		"the control: on a panel that has been up, a row changing is seen to change: what differs backspaced, then typed (%s)" % String((DispatchTerminal.up(mid_set)["body"] as PackedStringArray)[1]))
	_ok(Array(DispatchTerminal.up(part)["body"]).back() == "SEARCHING ...." and Array(DispatchTerminal.up(whole)["body"]).back() == "SEARCHING .... DONE",
		"{2} holds a line part-drawn for two seconds, then the rest of it (%s / %s)" % [Array(DispatchTerminal.up(part)["body"]).back(), Array(DispatchTerminal.up(whole)["body"]).back()])
	# a command that opens nothing; clear; the body scrolling; a print with nothing typed
	var bad := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n> zz\n```\n")
	var bad_ops: Array = (bad["actions"] as Array)[0]["ops"]
	var invalid := 0
	for o in bad_ops:
		if String((o as Dictionary)["op"]) == "alert" and Array(o["lines"]) == [DispatchTerminal.INVALID]:
			invalid += 1
	_ok(str(bad["warnings"]).contains("opens nothing") and invalid == 1, "a command that opens nothing is an INVALID OPTION, and warned of (%s)" % str(bad["warnings"]))
	var tall := "```terminal\n> x\npanel: menu = MENU\n" + "\n".join(range(20).map(func(n: int) -> String: return "ROW %d" % n)) + "\n```\n\nThere.\n\n```terminal\nclear\nprint\n```\n"
	var tall_d := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n" + tall)
	var tall_a: Dictionary = (tall_d["actions"] as Array)[0]
	var tall_rows: PackedStringArray = DispatchTerminal.rows_of(DispatchTerminal.at(tall_a["glass"], tall_a["ops"], INF), DispatchTerminal.config_of(""))["lines"]
	var cleared: Dictionary = (tall_d["actions"] as Array)[1]
	_ok(String(tall_rows[DispatchTerminal.BODY_TOP]).strip_edges() == "ROW 4" and String(tall_rows[DispatchTerminal.BODY_TOP + 15]).strip_edges() == "ROW 19"
		and (DispatchTerminal.up(DispatchTerminal.at(cleared["glass"], cleared["ops"], INF))["body"] as PackedStringArray).is_empty(),
		"past sixteen rows the body alone scrolls, and clear empties it")
	var pr := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n> l\npanel: log = LOG\n22:40. Opened.\nprint\n```\n")
	var pr_a: Dictionary = (pr["actions"] as Array).back()
	_ok(String(pr_a["kind"]) == "print" and Array(pr_a["lines"]).has("22:40. Opened."), "a print with nothing typed prints the panel up (%s)" % str(pr_a.get("lines")))
	_ok(String(p1["kind"]) == "ping" and String(p2["kind"]) == "ping" and int(p1["after"]) == 0 and int(p2["after"]) == 0
		and is_equal_approx(float(p2["fwd"]) - float(p1["fwd"]), float(p1["rest"]) + DispatchScript.REST_PAD + 1.5)
		and float(p1["back"]) > float(p2["back"]), "two pings a hesitation apart keep it between them (%.2f, %.2f)" % [float(p1["fwd"]), float(p2["fwd"])])
	# typed lines, strike, print
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
		and int(spans.back()["c1"]) == String(typed["text"]).length(), "a typed line's every spoken word has its characters")
	var struck_on := DispatchTerminal.up(struck["glass"])
	var struck_off := DispatchTerminal.up(DispatchTerminal.struck(struck["glass"], 1.0))
	_ok(String(actions[int(struck["block"])]["text"]).begins_with("WHAT") and bool(actions[int(struck["block"])].get("struck", false))
		and String(Array(struck_on["body"]).back()).begins_with("WHAT") and not String(Array(struck_off["body"]).back()).begins_with("WHAT"),
		"a strike takes the line typed before it off the glass (%s)" % str(struck_off.get("body")))
	_ok(Array(printed["lines"]).has("23:21. Grocery store. Watcher in place."), "a print prints what was typed (%s)" % str(printed.get("lines")))
	var shown := DispatchScript.shown_of("WHAT <!-- hesitation --> DO WE <!-- hesitation --> DO")
	_ok(shown == "WHAT DO WE DO", "a typed line's marks leave no gap on the screen (%s)" % shown)
	# redacted words
	var plate := String(DispatchTerminal.up(after)["body"][2])
	var drawn := DispatchScript.unredacted(plate)
	_ok(not plate.contains("XKC") and not plate.contains("<!--") and plate.length() == "PLATE ....... XKC 4417".length()
		and String(drawn["text"]) == "PLATE ....... XKC 4417" and drawn["spans"] == [Vector2i(14, 22)],
		"a panel's redacted words are on the glass as themselves, hidden, by their columns (%s, %s)" % [plate, str(drawn)])
	_ok((DispatchScript.unredacted("STATUS ...... CONTAINED")["spans"] as Array).is_empty(), "the control: a plain line has no redacted run")
	var hid := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\n> search <!-- redact: jane doe -->\npanel: MATCHES | 1 MATCH\n```\n\nThere.\n")
	var hop: Dictionary = (hid["actions"][0]["ops"] as Array).filter(func(o: Dictionary) -> bool: return String(o["op"]) == "command")[0]
	var hkeys: PackedFloat32Array = hop["keys"]
	var htyped := DispatchScript.unredacted(String(hop["text"]))
	_ok(String(htyped["text"]) == "search jane doe" and htyped["spans"] == [Vector2i(7, 15)] and hkeys.size() == "search jane doe".length()
		and not String(hop["text"]).contains("jane"), "a command types its redacted words a key each, hidden (%s, %d keys)" % [str(htyped), hkeys.size()])
	var wide := "x".repeat(66) + " "
	var run_lines := DispatchTerminal.wrapped(wide + DispatchScript.redacted("<!-- redact: AB CD EF -->"), DispatchTerminal.COLUMNS)
	var plain_lines := DispatchTerminal.wrapped(wide + "AB CD EF", DispatchTerminal.COLUMNS)
	_ok(run_lines.size() == 2 and String(DispatchScript.unredacted(run_lines[1])["text"]) == "AB CD EF" and String(plain_lines[0]).ends_with("AB"),
		"a redacted run wraps whole (the control: plain, it wraps between its words - %s / %s)" % [str(run_lines), str(plain_lines)])
	var said_hid := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n```terminal\ntype: LOGGED <!-- redact: JANE DOE -->.\n```\n")
	_ok(String(said_hid["warnings"][0]).begins_with("redact:") and not (said_hid["spoken"] as PackedStringArray).has("jane")
		and not String(said_hid["actions"][0]["text"]).contains("JANE"), "a said line's redacted words are warned of, never shown or said")
	# pings by bearing and range
	var stops: Array = []
	for a in actions:
		if String((a as Dictionary)["kind"]) == "ping":
			stops.append({"place": a["place"], "bearing": a["bearing"], "range": a["range"]})
	var spots := DispatchMedium.track_of(stops, float(d["rings"]))
	var hall: Vector2 = spots[1]
	var stair: Vector2 = spots[2]
	_ok(hall.distance_to(Vector2(0.5, 0.0)) < 0.001 and stair.distance_to(Vector2(0.0, 0.75)) < 0.001 and (spots[3] as Vector2) == hall
		and bool(actions[_nth(actions, "ping", 3)].get("jump", false)) and not bool(actions[_nth(actions, "ping", 2)].get("jump", false)),
		"a ping is where its bearing and range put it (90 at two rings: right, half out; 180 at three: below), a place named bare again the same spot, the first after a fade with no track (%s, %s)" % [hall, stair])
	var bare := DispatchScript.parse("<!-- speaker: Control -->\n\n<!-- ping: the stairwell -->\n\nOh.\n")
	_ok(str(bare["warnings"]).contains("no bearing and range"), "the control: a place never given numbers is warned of (%s)" % str(bare["warnings"]))
	# fades
	var fades: Array = actions.filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "fade")
	var dark_lamp: Dictionary = actions.filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "switch")[1]
	_ok(fades.size() == 2 and bool(fades[0]["to"]) and is_equal_approx(float(fades[0]["rest"]), DispatchScript.FADE) and not bool(fades[1]["to"])
		and int(fades[1]["clock"]) == 23 * 60 + 40 and is_equal_approx(float(fades[1]["rest"]), DispatchScript.FADE + DispatchScript.CLOCK_TURN + DispatchScript.CLOCK_BEAT)
		and bool(dark_lamp.get("dark", false)) and float(dark_lamp["rest"]) == 0.0,
		"the voice waits for a fade, a fade up turns the clock, and what is marked in the black happens at once")
	var black := DispatchScript.parse("<!-- fade: from-black, 22:40 -->\n\n<!-- speaker: Control -->\n\nHello.\n\n```terminal\ntype: 23:30. Late.\n```\n\n"
		+ "```terminal\ntype: 22:41. Now.\n```\n")
	var first_hold := RegEx.create_from_string("<!--\\s*action-hold\\s*:\\s*([0-9.]+)").search(String(black["speakable"]))
	_ok(bool(black["dark"]) and not is_equal_approx(float(first_hold.get_string(1)), DispatchScript.OPENING) and not bool(d["dark"])
		and (black["warnings"] as PackedStringArray).size() == 1 and String(black["warnings"][0]).begins_with("clock: 23:30"),
		"a note opening on a fade up opens in the black, no breath first; a typed time far off the clock is warned of (the controls: the fixture breathes, 22:41 is in step - %s)" % str(black["warnings"]))
	# the tablet
	var pages: Array = actions.filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "page")
	var tablets: Array = actions.filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "tablet")
	_ok(tablets.size() == 2 and bool(tablets[0]["up"]) and not bool(tablets[1]["up"]) and pages.size() == 2
		and String(pages[0]["how"]) == "type" and String(pages[1]["how"]) == "tap" and (d["pages"] as Array).size() == 2
		and is_equal_approx(float(pages[0]["rest"]), DispatchScript.TABLET_GO + DispatchScript.TABLET_LOOK + DispatchScript.TABLET_KEY * "forum.board".length())
		and not spoken.has("forum") and not spoken.has("recent") and not spoken.has("coughing"),
		"the tablet picked up and put down; a page typed into the bar, the next tapped from it; never said (%s)" % str(pages.map(func(a: Dictionary) -> String: return String(a["how"]))))
	var twice := DispatchScript.parse("<!-- speaker: Control -->\n\n<!-- tablet -->\n\n```page\nurl: a.vid\n\n# A\n```\n\nOne.\n\n```page\nurl: a.vid\n\n# A again\n```\n\nTwo.\n\n<!-- /tablet -->\n\n```page\nurl: b.vid\n```\n")
	var twice_pages: Array = (twice["actions"] as Array).filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "page")
	_ok(twice_pages.size() == 3 and String(twice_pages[1]["how"]) == "again" and str(twice["warnings"]).contains("tablet down"),
		"a page come back to is reloaded, and a page with the tablet down is warned of (%s)" % str(twice["warnings"]))
	_browsing()
	_grid_down()
	var replayed := sp.find("<!-- speaker: Control -->\n<!-- heard: tablet -->")
	_ok(replayed > 0 and sp.find("He is in the hall.", replayed) - replayed < 120 and spoken.count("hall") == 3, "a replay says the room's own words again through the tablet's speaker")
	var unsaid := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n<!-- tablet -->\n\n<!-- replay: tablet | Never said. -->\n\n<!-- /tablet -->\n")
	_ok(str(unsaid["warnings"]).contains("was not said"), "the control: a replay of words never said is warned of (%s)" % str(unsaid["warnings"]))
	var page_src := "<!-- speaker: Control -->\n\nHi.\n\n<!-- tablet -->\n\n```page\nurl: a.example\n\n# A Site\n\nOne two three.\n\n%sFour five.\n```\n\nLook at this.\n\n<!-- /tablet -->\n"
	var placed_p := DispatchScript.parse(page_src % "<!-- said: Look at this -->\n\n")
	var unplaced := DispatchScript.parse(page_src % "")
	var pinned: Array = (placed_p["actions"] as Array).filter(func(x: Dictionary) -> bool: return String(x["kind"]) == "page")
	var free: Array = (unplaced["actions"] as Array).filter(func(x: Dictionary) -> bool: return String(x["kind"]) == "page")
	var places: Array = pinned[0]["said"] if pinned.size() == 1 else []
	_ok(places.size() == 1 and int(places[0]["before"]) == 5 and places[0]["words"] == DispatchScript.words_of("Look at this")
			and (placed_p["tablet"]["words"] as Array).size() == (unplaced["tablet"]["words"] as Array).size()
			and free.size() == 1 and (free[0]["said"] as Array).is_empty(),
		"a page's said mark is a place on it for those words, after the words written above it, and never a word of the page (the control: a page with none has no place) (%s)" % str(places))
	var clip: Dictionary = actions.filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "picture" and a.has("clip"))[0]
	var clip_rows: Array = DispatchMedium.pictures_in(body).filter(func(im: Dictionary) -> bool: return im.has("clip"))
	_ok(String(clip["screen"]) == "tv" and String(clip["clip"]) == "dog.webm" and clip_rows.size() == 1 and String(clip_rows[0]["key"]) == String(clip["key"])
		and String(clip_rows[0]["clip"]) == "dog.webm", "a clip on a screen is a picture with its file, handed to the Pictures card as a clip")
	# gain, bell, lamp
	var gains: Array = actions.filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "gain")
	var turn := DispatchScript.GAIN_REACH + DispatchScript.GAIN_STEP * 6.0 + DispatchScript.GAIN_BEAT
	_ok(gains.size() == 2 and int(gains[0]["from"]) == 3 and int(gains[0]["to"]) == 9 and int(gains[1]["from"]) == 9 and int(gains[1]["to"]) == 3
		and is_equal_approx(float(gains[0]["rest"]), turn) and is_equal_approx(float(gains[1]["rest"]), turn),
		"the gain knob is turned from three to nine and back, the voice waiting while it turns and a beat (%s)" % str(gains.map(func(a: Dictionary) -> String: return "%d-%d" % [a["from"], a["to"]])))
	var bell_i := -1
	for i in actions.size():
		if String((actions[i] as Dictionary)["kind"]) == "bell":
			bell_i = i
	_ok(bell_i >= 0 and bell_i + 1 < actions.size() and String(actions[bell_i + 1]["kind"]) == "session"
		and int(actions[bell_i + 1]["after"]) == int(actions[bell_i]["after"]) and is_equal_approx(float(actions[bell_i]["rest"]), DispatchScript.BELL),
		"the bell is rung in the silence before the block after it, the voice waiting half a beat")
	var lamps: Array = actions.filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "lamp")
	_ok(lamps.size() == 2 and not bool(lamps[0]["on"]) and bool(lamps[1]["on"]), "the lamp is switched off, and on")
	_ok(not sp.contains("gain") and not sp.contains("bell") and not sp.contains("lamp") and not spoken.has("nine"),
		"a gain, a bell or a lamp reaches the voice")
	var odd := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n<!-- gain: loud -->\n\n<!-- lamp: dim -->\n\nThere.\n")
	_ok((odd["actions"] as Array).is_empty() and str(odd["warnings"]).contains("gain: loud") and str(odd["warnings"]).contains("lamp: dim"),
		"the controls: a gain with no number and a lamp neither on nor off are each said, and do nothing (%s)" % str(odd["warnings"]))
	# pictures
	var full: Array = d["spans"]
	_ok(full.size() == 1 and int(full[0]["to"]) > int(full[0]["from"]), "a picture over the whole screen spans its passage")
	_ok(Manuscript.images(DispatchScript.pictures_only(body)).size() == 2, "every picture is handed to the painter")
	# a picture told `unwatched` is the same picture on the same screen, kept so for the camera, and painted as any other (the
	# controls: a word a picture is not told, and a picture over the whole screen told anything, are each warned of)
	var aside := "<!-- speaker: Control -->\n\nHi.\n\n<!-- image (feed, unwatched): an empty aisle -->\n\n<!-- image (tv): a dog -->\n\n<!-- video (tv, unwatched): dog.webm | a dog spinning -->\n\nThere.\n"
	var told := DispatchScript.parse(aside)
	var pics: Array = (told["actions"] as Array).filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "picture")
	_ok(pics.size() == 3 and bool(pics[0].get("unwatched", false)) and String(pics[0]["screen"]) == "feed"
		and String(pics[0]["key"]) == Manuscript.image_key("an empty aisle") and is_equal_approx(float(pics[0]["rest"]), DispatchScript.PICTURE)
		and not pics[1].has("unwatched") and bool(pics[2].get("unwatched", false)) and String(pics[2]["clip"]) == "dog.webm"
		and (told["warnings"] as PackedStringArray).is_empty() and DispatchMedium.pictures_in(aside).size() == 3
		and DispatchMedium.pictures_in(aside).any(func(im: Dictionary) -> bool: return String(im["key"]) == String(pics[0]["key"])),
		"a picture told unwatched is the same picture on its screen, marked for the camera, and handed to the painter (%s)" % str(told["warnings"]))
	var mistold := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n<!-- image (feed, sideways): an aisle -->\n\n<!-- image (full, unwatched): a hill -->\n\nThere.\n\n<!-- /image -->\n")
	var mis: Array = (mistold["actions"] as Array).filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "picture")
	_ok(mis.size() == 1 and not mis[0].has("unwatched") and (mistold["spans"] as Array).size() == 1
		and str(mistold["warnings"]).contains("image (feed, sideways)") and str(mistold["warnings"]).contains("image (full, unwatched)"),
		"the controls: a word a picture is not told, and a picture over the whole screen told one, are each warned of (%s)" % str(mistold["warnings"]))
	_ok(DispatchScript.rehearsal(d).size() == spoken.size(), "a rehearsal times every spoken word")
	# a synced note: its words come without their frontmatter, and the desk puts the note's back on them (the control: the
	# words alone have no desk block or terminal keys)
	var parts := FrontMatter.split(body)
	var words_alone := DispatchScript.parse(String(parts["body"]))
	var synced := DispatchScript.parse(DispatchMedium.whole(String(parts["body"]), String(parts["head"])))
	_ok(Array(synced["phones"]) == Array(d["phones"]) and synced["warnings"] == d["warnings"] and String(synced["speakable"]) == sp
		and DispatchMedium.whole(body, "x: 1") == body and str(words_alone["warnings"]).contains("opens nothing"),
		"a synced note's words are read with its frontmatter put back, as the note is written (the control, the words alone: %s)" % str(words_alone["warnings"]))
	# the receiver
	var desk := "---\ndesk:\n  phones: [VAN]\n---\n\n<!-- speaker: Control -->\n\nListen.\n\n"
	var council := DispatchScript.parse(desk + "```terminal\ntype (Council): WHAT DO WE DO\n```\n\n"
		+ "<!-- static: 4, surf -->\n\n```terminal\ntype (Council): WAIT\n```\n\nAlways.\n")
	var csp := String(council["speakable"])
	var typed_turns: Array = (council["actions"] as Array).filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "type")
	_ok(csp.contains("<!-- speaker: Council -->\n<!-- heard: receiver -->") and csp.find("What do we do") > csp.find("speaker: Council")
		and csp.find("speaker: Control", csp.find("Wait")) > 0 and VoiceFX.HEARD.has(DispatchScript.RECEIVER),
		"a line typed in a voice with no phone comes in on the receiver, in its own voice, and the room comes back after it (%s)" % csp.replace("\n", " / "))
	_ok(typed_turns.size() == 2 and String(typed_turns[0].get("heard", "")) == DispatchScript.RECEIVER
		and String(typed_turns[0]["storm"]) == "popcorn" and String(typed_turns[1]["storm"]) == "surf",
		"the receiver opens on the storm it last opened on, Io-B's before any (%s)" % str(typed_turns.map(func(a: Dictionary) -> String: return String(a.get("storm", "")))))
	var said_council: Array = actions.filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "receiver")
	_ok(said_council.size() == 1 and " ".join(spoken.slice(int(said_council[0]["from"]), int(said_council[0]["to"]))) == "bad",
		"a paragraph in a voice with no phone, none at the ear, is heard on the receiver")
	var van := DispatchScript.parse(desk + "<!-- speaker: Van -->\n\n```terminal\ntype: WHAT DO WE DO\n```\n")
	var vsp := String(van["speakable"])
	var van_typed: Array = (van["actions"] as Array).filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "type")
	_ok(not vsp.contains("speaker: Van") and not vsp.contains("heard") and van_typed.size() == 1 and not (van_typed[0] as Dictionary).has("heard"),
		"the control: a bare type: line is the room's, heard in the room (%s)" % vsp.replace("\n", " / "))
	# controls
	var stray := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n<!-- call: NOBODY -->\n\n<!-- speaker: Red -->\n\nHello.\n")
	_ok(not (stray["warnings"] as PackedStringArray).is_empty() and Array(stray["phones"]).has("NOBODY"),
		"the control: a call to a phone not on the desk, left open, is said")
	var mute := DispatchScript.parse(desk + "<!-- speaker: Van -->\n\nHello.\n")
	_ok(String(mute["warnings"][0]).contains("no phone open") and not String(mute["speakable"]).contains("heard"),
		"the control: a voice whose phone is not open is said, and heard in the room")
	# a text answering what the room sent comes back no sooner than the other end could type it on its keypad (the control: a text
	# answering nothing comes as the script has it); the room's reply waits for its own typing
	var texting := "---\ndesk:\n  phones: [AISLE]\n---\n\n<!-- speaker: Control -->\n\nListen.\n\n<!-- text: AISLE | Where are you -->\n\n"
	var convo := DispatchScript.parse(texting + "<!-- reply -->\n\nAt the store, by the window.\n\n<!-- text: AISLE | Which one -->\n\nShe will know.\n")
	var unasked := DispatchScript.parse(texting + "At the store, by the window.\n\n<!-- text: AISLE | Which one -->\n\nShe will know.\n")
	var second_text := func(p: Dictionary) -> Dictionary:
		var ts: Array = (p["actions"] as Array).filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "text")
		return ts[1] if ts.size() > 1 else {}
	var replied_a: Array = (convo["actions"] as Array).filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "reply")
	var answer_waited := float((second_text.call(convo) as Dictionary).get("fwd", 0.0))
	var unwaited := float((second_text.call(unasked) as Dictionary).get("fwd", 0.0))
	_ok(answer_waited >= DispatchScript.answer_wait("Which one") - 0.01 and unwaited < DispatchScript.THEIRS_THINK and replied_a.size() == 1
		and is_equal_approx(float(replied_a[0]["rest"]), DispatchScript.REPLY_LEAD + DispatchScript.reply_typing("At the store, by the window.")),
		"an answer to what was sent waits for the other end to type it (%.1f s; the control, a text answering nothing, %.1f s), and a reply for its own typing (%.1f s)"
		% [answer_waited, unwaited, float(replied_a[0]["rest"]) if not replied_a.is_empty() else -1.0])
	# the flip clock's cards: a flap falls faster all the way and slaps down within a fifth of a second, then bounces once off
	# its stop; the rightmost digit that changes flaps first, each changed one to its left after it
	var half_way := DispatchScript.flap_angle(DispatchScript.CLOCK_LAND * 0.5)
	var landed := DispatchScript.flap_angle(DispatchScript.CLOCK_LAND)
	var bounce := DispatchScript.flap_angle((DispatchScript.CLOCK_LAND + 1.0) * 0.5)
	_ok(DispatchScript.CLOCK_FLAP * DispatchScript.CLOCK_LAND <= 0.2 and absf(half_way - PI * 0.25) < 0.01 and is_equal_approx(landed, PI)
		and bounce < PI - 0.05 and is_equal_approx(DispatchScript.flap_angle(1.0), PI),
		"a clock's card falls as a flap let go, slapping down in %.2f s and bouncing off its stop (half its fall it has turned %.0f degrees; the control, an even turn, 90)"
		% [DispatchScript.CLOCK_FLAP * DispatchScript.CLOCK_LAND, rad_to_deg(half_way)])
	var all_four := DispatchScript.flap_starts("23:59", "00:00")
	var two := DispatchScript.flap_starts("23:39", "23:40")
	_ok(all_four[3] == 0.0 and all_four[0] > all_four[1] and all_four[1] > all_four[2] and all_four[2] > all_four[3]
		and all_four[0] + DispatchScript.CLOCK_FLAP <= DispatchScript.CLOCK_TURN + 1e-4 and two[0] < 0.0 and two[1] < 0.0 and two[3] == 0.0 and two[2] > 0.0,
		"the rightmost digit that changes flaps first and each to its left after it, all four within the turn (%s); a digit that stays never flaps (%s)"
		% [str(all_four), str(two)])
	if _fails.is_empty():
		print("dispatch_script_check: ALL OK (%d words, %d actions)" % [spoken.size(), actions.size()])
		quit(0)
	else:
		for f in _fails:
			print("dispatch_script_check: FAIL  " + f)
		quit(1)


## The tablet browsed: how each page of the browsing note is reached, and the marks that do nothing said so.
## The grid down, the Environment switched, a film on the terminal: `power:` and `environment:` are actions the voice waits for and
## never says; `play` takes the film's seconds from what it is handed, and the voice waits for the rest of the film where its silence
## ends, so what is written after it happens while it plays (controls: a film handed no seconds is warned of and not waited for; one
## shorter than what follows it adds nothing; a mark it cannot read is warned of and does nothing).
func _grid_down() -> void:
	var note := "<!-- speaker: Control -->\n\nHi.\n\n<!-- power: off -->\n\n<!-- play (terminal): ERROR ME FOUND -->\n\n<!-- hesitation: 8 -->\n\n<!-- environment: Shafts off, beams ON, 2 -->\n"
	var films := {"ERROR ME FOUND": {"kind": "note", "ready": true, "secs": 30.0}}
	var d := DispatchScript.parse(note, films)
	var acts: Array = d["actions"]
	var kinds := acts.map(func(a: Dictionary) -> String: return String(a["kind"]))
	var sp := String(d["speakable"])
	_ok(kinds == ["power", "play", "environment"] and not bool(acts[0]["on"]) and is_equal_approx(float(acts[0]["rest"]), DispatchScript.POWER)
		and String(acts[1]["screen"]) == "terminal" and is_equal_approx(float(acts[1]["secs"]), 30.0)
		and (acts[2]["set"] as Dictionary) == {"shafts": false, "beams": true} and is_equal_approx(float(acts[2]["secs"]), 2.0)
		and (d["warnings"] as PackedStringArray).is_empty(),
		"the grid goes down, a film plays on the terminal, the Environment is switched (%s; %s)" % [str(kinds), str(d["warnings"])])
	var left := 30.0 - (DispatchScript.PLAY_LEAD + DispatchScript.REST_PAD) - 8.0 - (DispatchScript.ENVIRONMENT + DispatchScript.REST_PAD)
	_ok(sp.contains("action-hold: %s" % String.num(left, 2)) and not sp.contains("power") and not sp.contains("ERROR")
		and not sp.contains("environment"), "the voice waits for the rest of the film after what follows it, and says none of it (%s)" % sp)
	_ok(DispatchScript.films_in(note) == PackedStringArray(["ERROR ME FOUND"]), "what the script plays is listed once")
	var blind := DispatchScript.parse(note)
	_ok(str(blind["warnings"]).contains("play (terminal): ERROR ME FOUND - nothing found") and not String(blind["speakable"]).contains(String.num(left, 2))
		and is_equal_approx(float((blind["actions"] as Array)[1]["secs"]), 0.0),
		"the control: what is found by no name is warned of and not waited for (%s)" % str(blind["warnings"]))
	var short := DispatchScript.parse(note, {"ERROR ME FOUND": {"kind": "note", "ready": true, "secs": 5.0}})
	_ok(String(short["speakable"]).count("action-hold") == String(d["speakable"]).count("action-hold") - 1,
		"the control: a film shorter than what follows it adds no rest")
	var odd := DispatchScript.parse("<!-- speaker: Control -->\n\nHi.\n\n<!-- power: dim -->\n\n<!-- environment: beams sideways -->\n\n<!-- play (phone): x.mp4 -->\n\n<!-- play (tv, mono): x.mp4 -->\n\nThere.\n")
	var oa: Array = odd["actions"]
	var ow := str(odd["warnings"])
	_ok(oa.size() == 1 and String(oa[0]["kind"]) == "play" and bool(oa[0].get("mono", false)) and ow.contains("power: dim")
		and ow.contains("environment: beams sideways") and ow.contains("play (phone)"),
		"the controls: a power neither on nor off, an element neither on nor off and a film on no screen are warned of and do nothing (%s)" % ow)


func _browsing() -> void:
	var br := DispatchScript.parse(FileAccess.get_file_as_string(BROWSING))
	var acts: Array = br["actions"]
	var at: Array = []                    # the page actions, by index
	for i in acts.size():
		if String(acts[i]["kind"]) == "page":
			at.append(i)
	var hows: Array = at.map(func(i: int) -> String: return String(acts[i]["how"]))
	_ok(hows == ["type", "tap", "back", "tap", "tab", "type", "search", "tap", "search", "back", "back", "back", "type", "again"]
		and (br["warnings"] as PackedStringArray).is_empty() and (br["pages"] as Array).size() == 9 and not (br["spoken"] as PackedStringArray).has("forum"),
		"the tablet is browsed as the tablet medium browses, its pages never said (%s, %s)" % [str(hows), str(br["warnings"])])
	var back: Dictionary = acts[at[2]]
	_ok(int(back["page"]) == int(acts[at[0]]["page"]) and int(back["resume"]) == int(at[0]) and int(back["behind"]) == 0
		and is_equal_approx(float(back["rest"]), DispatchScript.TABLET_AGAIN) and int(acts[at[1]]["behind"]) == 1,
		"back is the page before in its tab, come back to as the action that had it up left it, nothing behind it again")
	var tab: Dictionary = acts[at[4]]
	_ok(int(tab["page"]) == -1 and int(tab["tab"]) == 1 and tab["tabs"] == [2, -1] and int(tab["behind"]) == 0
		and is_equal_approx(float(tab["rest"]), DispatchScript.TABLET_TAB) and bool(acts[at[5]]["bar"]) and acts[at[5]]["tabs"] == [2, 3],
		"a new tab is a blank tab of its own beside the first, the next address typed into its bar (%s)" % str(tab["tabs"]))
	var boxed: Dictionary = acts[at[6]]
	var barred: Dictionary = acts[at[8]]
	var lazy := float(TabletScript.char_times("how many are there")["how many are there".length()])
	_ok(not bool(boxed["bar"]) and String(boxed["text"]) == "how many are there" and String(boxed["url"]).begins_with("ducks.tom/")
		and is_equal_approx(float(boxed["rest"]), DispatchScript.TABLET_BOX + DispatchScript.TABLET_HAND + lazy + DispatchScript.TABLET_ENTER
			+ DispatchScript.TABLET_GO + DispatchScript.TABLET_LOOK),
		"a search on a search engine's page is typed into its own box, at the tablet medium's pace (%.2f s)" % float(boxed["rest"]))
	_ok(bool(barred["bar"]) and String(barred["text"]) == "who counts them" and String(barred["url"]).begins_with("ducks.tom/")
		and is_equal_approx(float(barred["rest"]), DispatchScript.TABLET_GO + DispatchScript.TABLET_LOOK + DispatchScript.TABLET_KEY * 15.0),
		"the control: a search from an article is typed into the address bar, its results the engine's last used (%s)" % String(barred["url"]))
	var posts: Array = acts.filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "post")
	var doc_pages: Array = (br["tablet"] as Dictionary)["pages"]
	_ok(posts.size() == 1 and String(posts[0]["text"]) == "Be patient tonight." and int(posts[0]["page"]) == 7 and (br["spoken"] as PackedStringArray).has("patient")
		and int(posts[0]["to"]) - int(posts[0]["from"]) == 3 and not acts.any(func(a: Dictionary) -> bool: return String(a["kind"]) == "reply")
		and String(acts[acts.find(posts[0]) + 1]["kind"]) == "sent" and int(acts[acts.find(posts[0]) + 1]["after"]) == int(posts[0]["to"])
		and is_equal_approx(float(acts[acts.find(posts[0]) + 1]["rest"]), DispatchScript.TABLET_SENT)
		and bool(doc_pages[7].get("reply", false)) and bool(doc_pages[8].get("reply", false)) and not bool(doc_pages[0].get("reply", false))
		and int(acts[at[13]]["behind"]) == int(acts[at[12]]["behind"]),
		"reply: tablet types the room's next words into the page's message box, still said, and the voice waits for it to be sent; the page loaded again keeps its box and adds nothing behind it")
	var lost := DispatchScript.parse("<!-- speaker: Control -->\n\n<!-- back -->\n\n<!-- new tab -->\n\n<!-- tablet -->\n\n<!-- new tab -->\n\n"
		+ "<!-- reply: tablet -->\n\nHi.\n\n```page\nsearch: who is it\n```\n\n<!-- back -->\n\n<!-- /tablet -->\n\nBye.\n")
	var lost_pages: Array = (lost["actions"] as Array).filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "page")
	var said := "\n".join(lost["warnings"])
	_ok(lost_pages.size() == 1 and String(lost_pages[0]["how"]) == "search" and bool(lost_pages[0]["bar"])
		and String(lost_pages[0]["url"]).begins_with(TabletScript.ENGINE + "/")
		and (lost["warnings"] as PackedStringArray).size() == 4 and said.contains("back: the tablet is down") and said.contains("new tab: the tablet is down")
		and said.contains("reply: tablet with no page up") and said.contains("back: nothing behind")
		and not (lost["actions"] as Array).any(func(a: Dictionary) -> bool: return String(a["kind"]) == "post"),
		"the controls: back and a new tab with the tablet down, a reply with no page up and a back with nothing behind it are warned of and do nothing; a new tab on the blank tab it wakes on is nothing; a search with no page up goes in the bar (%s)" % said)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)


static func _first(actions: Array, kind: String) -> int:
	for i in actions.size():
		if String((actions[i] as Dictionary)["kind"]) == kind:
			return i
	return -1


## The index of action [param n] of [param kind] (0 the first), -1 for none.
static func _nth(actions: Array, kind: String, n: int) -> int:
	var seen := 0
	for i in actions.size():
		if String((actions[i] as Dictionary)["kind"]) == kind:
			if seen == n:
				return i
			seen += 1
	return -1
