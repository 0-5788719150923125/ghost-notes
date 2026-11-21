extends SceneTree

## Gate for the dispatch desk ([DispatchMedium], next/dispatch.md), mounted headless and played on a steady voice over
## tests/fixtures/dispatch_note.md ([method DispatchScript.rehearsal]). It holds:
##
## - the Environment ([Surroundings]): with none the hollow is its own; a light chosen, its colors and its share of the lamp; the
##   brightness its exposure; shafts in the crack's place; what drifts; each lit thing at its share; candles where it burns them
##   (the control: none again, as it was);
## - actions fit the voice's rests: each placed and done before the next word; two pings a hesitation apart stay apart;
## - phones: the one called is at the ear while its voice speaks, the previous one laid open, picked back up, all back at the end;
## - the desk is seen first: nothing happens and the camera stays home through the opening rest;
## - the terminal: dark until a block wakes it to its command line; a command typed there a key at a time and cleared as the
##   panel it opens comes up, the header at once and the body a line at a time; redacted words are one run on their row,
##   hidden over the frame by one box round them as the camera sees them, and covered whole from their first key; a typed
##   line is said behind its keys under the panel up; a strike removes it; after a block the camera stays on the glass while
##   the voice talks of it, however long, through to what comes next (control: a linger of 8 s goes home before it);
## - the camera cut across a seek and eased out of a stall of the app's thread as far as the clock ran (the control: the same move in no
##   time is a seek);
## - the black and the clock: fades down and up; in the black the camera is on the clock, its cards turned over to the time
##   given and running on a minute a minute, a later fade up turning from a minute before its own time (control: the clock as it
##   ran, before the black), and a reading started past the fade turns it where a whole reading does
##   (control: the fade counted from the far past a mid-way start places it in); what is marked in the black is unseen; no
##   track is drawn across it; a note opening in the black shows its title over the blurred desk first, going black as the
##   title goes, its blur never lifting on the desk (controls: no title, black from the start; the usual pull lifting by then);
## - two looks at the same thing are one, the camera held between them; in a live reading the camera holds on the glass for a
##   next look before its words are heard, a long talk away too (controls: a look at something else between; a look home);
## - the tablet: picked up and held low over the desk, the camera on it, and laid back in its place, the camera leaving it a
##   second into the laying down for the whole desk or what begins at once (the control: an ordinary look is held on to what
##   comes), its screen left lit as
##   it was, dimmed for the last seconds and locked dark half a minute on (the control: before it is woken it is dark); on
##   every desk it is carried clear of what stands under its way by each thing's outline, on most no higher than the hand
##   holds it (the control: straight and at its least height, something is in its way on some desk); an address typed into its bar, a
##   link on the page tapped; a page following the words said on it, else easing down, the words read off it lit as said
##   (control: a page nothing is read off); its player dark until the desk is played live into it;
## - the tablet browsed (tests/fixtures/dispatch_browsing.md): a link at a page's foot brought into view and tapped; back by
##   its arrow to the page before, scrolled where it was left (the control: a page come up is at its top), and a link tapped
##   on it; a new tab, blank beside the first, its bar taking the next address under the keyboard; a search typed into a search
##   engine's own box at the tablet medium's pace, its results under what was searched for (the control: from an article, into
##   the bar); a reply typed into the page's message box as it is said, clear of the keyboard, and sent (the control: a page
##   that takes none has no box); the page loaded again where it was left, its box kept;
## - a clip: the screen's static until it is imported, then its frames looping;
## - the grid down, the Environment switched and a film on the terminal ([method _grid_and_film]);
## - a picture told `unwatched` lands on its screen with the camera left on what it was on (the control: the same picture
##   untold turns the camera to its screen); a static told `unwatched` is heard with the camera left on the terminal (the
##   control: untold, it turns to the receiver);
## - a picture over the whole screen written after a block comes in once the block's typing is done, never over it (the
##   control: written before the block, it comes in just after the word before);
## - a said passage is typed at an even pace ahead of its voice: every word whole before it is said, never more than three
##   words ahead, its pace from word to word swinging less than half as much (the control: each word typed in the time of the
##   word two before it), on a voice whose words take as long as their letters and that rests at each sentence's end;
## - a block's last key: line that the paragraph after it says is typed ahead of those words: each word it says typed before
##   it is said, the first keys after the panel is up, the line's unsaid end typed on after (the control: the paragraph's
##   first word is said seconds before the whole line is typed);
## - a call's timer after a reading started mid-way: counted from where the call fell on the reading, as a whole reading
##   counts it (the control: from the far past the call is placed in, it is hours);
## - a call held across a black has been on the hours the clock jumped, past midnight too, shown with its hours, a reading started
##   past the black too (the controls: counted in the show's own time, it is a minute or two; the fades' own starts lie before
##   the call began);
## - the camera turns to what is active (terminal typing, receiver in a storm, ringing phone) and a look holds while nothing else
##   is; it goes to the radar only at its sounds; the radar target moves in small steps under the voice, never a jump, with its
##   old place written beside it until it arrives; the receiver is open only in its storm;
## - a voice with no phone comes in on the receiver, typed or said: open from the static before it straight on through its
##   words, the storm brought down under them and the needle swelling in a word, shut after its tail, one stretch of sound
##   (the control: the room's own typed line opens nothing);
## - a text is read on its phone (chime, phone up, message on screen, never captioned, reply typed as said and sent); a call
##   is speed-dialed (1 held, Send, ear);
## - captions: a typed word is read on the terminal, a spoken line is captioned;
## - a live reading, words arriving a sentence at a time: an action begun keeps its start when the plan is made again;
## - the roots: some on the desk, grown further at the end than at the start, none under an open phone or its lid, none
##   through the printer's paper or its heap (control: grown knowing nothing of them, they go through); none lying on the
##   desk nearer what stands there than it is thick (control: grown knowing nothing of what stands there, into it); each a
##   moderate reach across the top, some over the near edge and hanging down clear of the desk's front, some ending on it;
## - the desk is its number's: the same number is the same desk, across numbers it is mirrored and packed differently; on
##   forty desks no two things meet by their own meshes' outlines, nothing packed hides a label, dial, screen or the clock's
##   cards from the chair and nothing hides one in its own close-up (controls: a mug just before the clock hides it; a switch
##   at the radar's face meets it; the chart across the blotter's edge does not fit), the satellite's monitor is on its arm
##   turned to the chair, the handbook's spine faces the chair, the chart lies wholly off the blotter, the mug 25-40 cm in
##   from the edge beside the keyboard; the keyboard's keys all on its case; an open phone laid on the desk faces the chair;
## - the mug is drunk from: upright, brought to the mouth and out of the picture for the sip, back in its ring;
## - the gain knob turns from three to nine a click a step with the camera on the radar: at three only the target is on the
##   scope, at nine the clutter round it and the chair's own on the desk (not at eight), each blip painted once the sweep
##   has passed it; turned back, they fade;
## - the bell rings as the block after it goes up, an alert beeps; the lamp goes out at its click, the camera on the whole desk;
## - a seed changed while the note plays draws a new desk and keeps the reading's place (control: changed words load again);
## - built on a worker, as the app builds it: the show is held until it lands.
##
## Run: timeout 600 godot --headless --path . --script tests/dispatch/dispatch_check.gd (about 4 min: each of its 40-odd desks bakes its paper)

const FIXTURE := "res://tests/fixtures/dispatch_note.md"
const BROWSING := "res://tests/fixtures/dispatch_browsing.md"

var _fails: Array = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_layout()
	_roots_clear()
	var body := FileAccess.get_file_as_string(FIXTURE)
	var parsed := DispatchScript.parse(body)
	var words := DispatchScript.rehearsal(parsed, 0.32)
	var st := SubViewport.new()
	st.size = Vector2i(320, 180)
	st.own_world_3d = true
	root.add_child(st)
	var md := DispatchMedium.new()
	md.feed = ShowFeed.new()
	md.mount(st)
	md.load_note(body, {"seed": 3})
	md._now = 0.0
	md.take_words(words)
	var actions: Array = md._actions
	var t0 := md.starts()
	var at := func(si: int) -> float: return float((words[si] as Dictionary)["t0"])
	# actions fit the voice's rests
	var placed := true
	var before := true
	for i in actions.size():
		var a: Dictionary = actions[i]
		if t0[i] == INF:
			placed = false
			continue
		var n := int(a["after"])
		if n < words.size() and t0[i] + float(a["rest"]) > at.call(n) + 0.01:
			before = false
	_ok(placed, "every action is placed")
	_ok(before, "every action is done before the word after it")
	_ok(absf((t0[1] - t0[0]) - (float(actions[0]["rest"]) + DispatchScript.REST_PAD + 1.5)) < 0.05,
		"two pings a hesitation apart stay a hesitation apart (%.2f s)" % (t0[1] - t0[0]))
	# phones, at the words their voices say
	var si_of := func(word: String, from: int) -> int:
		var sp: PackedStringArray = parsed["spoken"]
		for k in range(from, sp.size()):
			if sp[k] == word:
				return k
		return -1
	var hello: int = si_of.call("hello", 0)
	var van: int = si_of.call("van", hello)
	var eight: int = si_of.call("eight", van)
	var door: int = si_of.call("door", eight)
	_ok(md.phone_at("AISLE", at.call(hello)) == "ear", "the phone called is at the ear while its voice speaks (%s)" % md.phone_at("AISLE", at.call(hello)))
	_ok(md.phone_at("AISLE", at.call(van)) == "desk" and md.phone_at("VAN", at.call(van)) == "ear",
		"calling another lays the first down open on the desk (%s, %s)" % [md.phone_at("AISLE", at.call(van)), md.phone_at("VAN", at.call(van))])
	_ok(md.phone_at("AISLE", at.call(eight)) == "ear" and md.phone_at("VAN", at.call(door)) == "desk",
		"a phone lying open is picked back up, the other laid down")
	# a call's timer runs from when it began, lying open on the desk and picked back up (the control: from when it was laid down,
	# it would start again)
	var aisle_began := md._call_began("AISLE", at.call(hello))
	var laid_at := INF
	for mv in md._phone_moves:
		if String((mv as Dictionary)["label"]) == "AISLE" and String(mv["to"]) == "desk":
			laid_at = minf(laid_at, float(mv["t0"]))
	_ok(md._call_began("AISLE", at.call(van)) == aisle_began and md._call_began("AISLE", at.call(eight)) == aisle_began and laid_at > aisle_began + 1.0,
		"a call's timer runs from when it began, lying open on the desk and picked back up (began %.1f s; the control, laid down at %.1f s)" % [aisle_began, laid_at])
	var end_t := float((words.back() as Dictionary)["t1"]) + 5.0
	_ok(md.phone_at("AISLE", end_t) == "row" and md.phone_at("VAN", end_t) == "row" and md.phone_at("COUGH", end_t) == "row",
		"every phone is back in its row at the end")
	# terminal
	_ok(bool(md.terminal_at(0.5)["asleep"]), "the terminal opens asleep, dark")
	_ok(t0[0] >= DispatchScript.OPENING and md.looking_at(t0[0] - 1.0) == "home",
		"THE DESK IS SEEN FIRST: nothing before the opening rest is over, the camera home (%.1f s)" % t0[0])
	var session_i := _first(actions, "session")
	var ops: Array = actions[session_i]["ops"]
	var s0 := t0[session_i]
	var pad := " ".repeat((DispatchTerminal.COLUMNS - 60) / 2)
	var cmds: Array = ops.filter(func(o: Dictionary) -> bool: return String(o["op"]) == "command")
	var opens: Array = ops.filter(func(o: Dictionary) -> bool: return String(o["op"]) == "open")
	var woke: PackedStringArray = md.terminal_at(s0 + 0.05)["lines"]
	var keys: PackedFloat32Array = cmds[0]["keys"]
	var typing: PackedStringArray = md.terminal_at(s0 + keys[3] + 0.01)["lines"]
	var menu_up: PackedStringArray = md.terminal_at(s0 + float(opens[0]["t"]) + 0.01)["lines"]
	var rec_t := s0 + float(opens[2]["t"])
	var rec_head: PackedStringArray = md.terminal_at(rec_t + 0.01)["lines"]
	var rec_some: PackedStringArray = md.terminal_at(rec_t + DispatchTerminal.LINE_EACH * 1.5)["lines"]
	_ok(bool(md.terminal_at(s0 - 0.1)["asleep"]) and String(woke[DispatchTerminal.COMMAND_ROW]) == pad + DispatchTerminal.PROMPT and String(woke[0]).is_empty(),
		"a block wakes the terminal to its bare command line (%s)" % str(woke))
	_ok(String(typing[DispatchTerminal.COMMAND_ROW]) == pad + "> coun" and String(typing[0]).is_empty(),
		"a command is typed on the command line a key at a time, nothing opened yet (%s)" % String(typing[DispatchTerminal.COMMAND_ROW]))
	_ok(String(menu_up[0]).ends_with("MENU") and String(menu_up[DispatchTerminal.COMMAND_ROW]) == pad + DispatchTerminal.PROMPT,
		"entered, the command line clears and the panel comes up (%s)" % String(menu_up[0]))
	_ok(String(rec_head[0]).ends_with("RECORD") and String(rec_head[DispatchTerminal.BODY_TOP]).is_empty()
		and String(rec_some[DispatchTerminal.BODY_TOP]).contains("NAME") and String(rec_some[DispatchTerminal.BODY_TOP + 2]).is_empty(),
		"a panel's header at once, its body drawn down the glass a line at a time")
	_ok(md.looking_at(s0 + keys[3]) == "terminal", "the camera is on the terminal through a block (%s)" % md.looking_at(s0 + keys[3]))
	var shown_t := s0 + float(actions[session_i]["rest"]) + 0.2
	var shown := md.terminal_at(shown_t)
	var shown_lines: PackedStringArray = shown["lines"]
	var covers: Array = md._screens.redactions(shown_lines)
	var plate_row := DispatchTerminal.BODY_TOP + 2
	_ok(covers.size() == 1 and not "\n".join(shown_lines).contains("XKC") and String(DispatchScript.unredacted(shown_lines[plate_row])["text"]).ends_with("XKC 4417")
		and absf((covers[0]["rect"] as Rect2).get_center().y - (DispatchScreens.TERM_MARGIN.y + DispatchScreens.TERM_LINE * float(plate_row) - float(DispatchScreens.TERM_FONT) * 0.32)) < 1.0,
		"a panel's redacted words are one run on their row, and nowhere as written (%d runs)" % covers.size())
	_ok(md._screens.redactions(PackedStringArray(["NAME ........ SUBJECT", "STATUS ...... CONTAINED"])).is_empty(),
		"the control: plain lines have no runs")
	# hidden over the frame: the camera on the terminal, one box round the plate as it sees it, a small part of the glass
	md._now = shown_t
	md._snap = true
	md._tick_camera(0.016)
	md._censor_at(shown_t)
	var curve := float(md._glass("terminal", "screen")["curve"])
	var plate_seen := DispatchCensor.seen(covers[0]["rect"], md._set.terminal_screen, curve, md._cam)
	var glass_seen := DispatchCensor.seen(Rect2(Vector2.ZERO, Vector2(DispatchScreens.TERM_SIZE)), md._set.terminal_screen, curve, md._cam)
	var boxes: Array = md._censor.boxes
	var box: Rect2 = boxes[0]["rect"] if boxes.size() == 1 else Rect2()
	_ok(md.looking_at(shown_t) == "terminal" and boxes.size() == 1 and md._censor.visible and plate_seen.size.x > 0.0 and box.encloses(plate_seen)
		and glass_seen.encloses(box) and box.get_area() < glass_seen.get_area() * 0.1,
		"the plate is hidden over the frame: one box round it as the camera sees it, a small part of the glass (%s round %s, glass %s)" % [box, plate_seen, glass_seen])
	md._censor_at(0.5)
	_ok(md._censor.boxes.is_empty() and not md._censor.visible, "the control: the terminal asleep, no box")
	# a redacted run being typed is covered whole from its first key (control: the key before it, as typed)
	var hid := DispatchScript.parse("```terminal\n> search <!-- redact: jane doe -->\npanel: MATCHES | 1 MATCH\n```\n\nThere.\n")
	var ha: Dictionary = hid["actions"][0]
	var hcmd: Dictionary = (ha["ops"] as Array).filter(func(o: Dictionary) -> bool: return String(o["op"]) == "command")[0]
	var hkeys: PackedFloat32Array = hcmd["keys"]
	var typed_j := String(DispatchScript.unredacted(String(DispatchTerminal.at(ha["glass"], ha["ops"], hkeys[7] + 0.001)["command"]))["text"])
	var whole_j := String(DispatchScript.unredacted(String(DispatchTerminal.at(ha["glass"], ha["ops"], hkeys[7] + 0.001, true)["command"]))["text"])
	var whole_before := String(DispatchScript.unredacted(String(DispatchTerminal.at(ha["glass"], ha["ops"], hkeys[6] + 0.001, true)["command"]))["text"])
	_ok(typed_j == "search j" and whole_j == "search jane doe" and whole_before == "search ",
		"a redacted run being typed is covered whole from its first key (%s / %s / %s)" % [typed_j, whole_j, whole_before])
	var type_i := _first(actions, "type")
	var ty: Dictionary = actions[type_i]
	var mid := int(ty["from"]) + 2
	var halfway := "\n".join(md.terminal_at(at.call(int(ty["from"])) + 0.05)["lines"])
	var done := "\n".join(md.terminal_at(at.call(int(ty["to"]) - 1) + 1.0)["lines"])
	_ok(halfway.contains("23:21. Grocery") and not halfway.contains("Watcher") and halfway.contains("22:40. Shift opened."),
		"the first words are typed under the panel up before the voice begins (the control: the rest is not typed all at once - %s)" % halfway.replace("\n", " / "))
	_ok(done.contains("Watcher in place."), "a typed line is typed out by its last word (%s)" % done.replace("\n", " / "))
	var keys_t: PackedFloat32Array = md._chars.get(type_i, PackedFloat32Array())
	var behind := not keys_t.is_empty()
	var tspans: Array = ty["spans"]
	for k in tspans.size():
		var last_key := keys_t[int(tspans[k]["c1"]) - 1] if not keys_t.is_empty() else INF
		behind = behind and last_key < at.call(int(ty["from"]) + k)
	_ok(behind, "the voice says a typed word only once its keys are done: it reads behind the typing, never waits on it")
	var strike_i := _first(actions, "strike")
	var gone := "\n".join(md.terminal_at(md._end_of(strike_i) + 0.2)["lines"])
	var before_strike := "\n".join(md.terminal_at(t0[strike_i] + 0.5)["lines"])
	_ok(before_strike.contains("WHAT DO WE DO") and not gone.contains("WHAT DO WE DO") and gone.contains("Watcher in place."),
		"a strike backspaces the line off the glass, what was there before it kept")
	# camera, radar, receiver
	var static_i := _first(actions, "static")
	var ring_i := _first(actions, "ring")
	var look_i := _first(actions, "look")
	_ok(md.looking_at(at.call(mid)) == "terminal", "the camera is on the terminal while it types (%s)" % md.looking_at(at.call(mid)))
	_ok(md.looking_at(t0[static_i] + 1.0) == "receiver", "the camera is on the receiver in a storm (%s)" % md.looking_at(t0[static_i] + 1.0))
	_ok(md.looking_at(t0[ring_i] + 0.5) == "phone", "the camera is on a ringing phone (%s)" % md.looking_at(t0[ring_i] + 0.5))
	var keep: int = si_of.call("keep", 0)
	_ok(md.looking_at(at.call(keep + 3)) == "radar" and md.looking_at(t0[look_i] - 0.5) != "radar",
		"a look turns the camera and holds it while nothing else is active (%s)" % md.looking_at(at.call(keep + 3)))
	var moving_i := _first(actions, "moving")
	var stair_i := moving_i + 1
	var hall: Vector2 = md._legs[1]["to"]
	var stair: Vector2 = md._legs[2]["to"]
	var half := (t0[moving_i] + t0[stair_i]) * 0.5
	var going := md.radar_at(half)
	var arrived := md.radar_at(t0[stair_i] + 1.0)
	var mid_at: Vector2 = going["blip"]["at"]
	var steps_ok := true
	var trail: Array = going["trail"]
	var last_at := mid_at
	for tr in trail:
		if ((tr as Dictionary)["at"] as Vector2).distance_to(last_at) > hall.distance_to(stair) * 0.6:
			steps_ok = false
		last_at = tr["at"]
	_ok(hall.distance_to(stair) > 0.04, "the control: the hall and the stairwell are well apart on the scope (%.3f)" % hall.distance_to(stair))
	_ok(String(going["blip"]["label"]) == "THE HALL" and mid_at.distance_to(hall) > 0.01 and mid_at.distance_to(stair) > 0.01 and steps_ok and trail.size() >= 1,
		"on his way, under the voice, the sweep paints him a step at a time, never a jump (%s, %d paints)" % [going["blip"]["label"], trail.size() + 1])
	_ok(String(arrived["blip"]["label"]) == "THE STAIRWELL" and (arrived["blip"]["at"] as Vector2).distance_to(stair) < 0.03,
		"arrived, the stairwell is written beside him (%s)" % arrived["blip"]["label"])
	_ok(md.looking_at(t0[moving_i] + 1.0) == "radar", "the radar's alarm as he sets off turns the camera to it (%s)" % md.looking_at(t0[moving_i] + 1.0))
	# the camera goes to the radar only at its sounds: every look at it begins as it pings or sounds its alarm (or a look mark
	# asks) and none stays to watch it do nothing - a ping is held to its sentence's end at most, a walk to the ping where he
	# arrives; either runs on only into the next look
	var radar_spot: Dictionary = md._spot("radar")
	var at_sounds := true
	for w in md._attn:
		var wd: Dictionary = w
		if wd["spot"] != radar_spot:
			continue
		var from := ""
		for i in actions.size():
			if absf(t0[i] - float(wd["t0"])) < 0.01 and String(actions[i]["kind"]) in ["ping", "moving", "sound", "look", "gain"]:
				from = String(actions[i]["kind"])
		var into_next := false
		for v in md._attn:
			if absf(float((v as Dictionary)["t0"]) - float(wd["t1"])) < 0.01 and v != wd:
				into_next = true
		# (a sound is watched as long as it is heard: the jet crosses the scope; a walk until he arrives)
		if from.is_empty() or (from == "ping" and not into_next and (float(wd["t1"]) - float(wd["t0"])
				> maxf(DispatchMedium.PING_HOLD_MOST, DispatchMedium.LOOK_LEAST) + 0.5 or float(wd.get("linger", DispatchMedium.HOME_AFTER)) > DispatchMedium.PING_LINGER + 0.01)):
			at_sounds = false
		if from == "moving":
			var ends_at_ping := into_next
			for i in actions.size():
				if String(actions[i]["kind"]) == "ping" and t0[i] > float(wd["t0"]) and absf(t0[i] - float(wd["t1"])) < 0.01:
					ends_at_ping = true
			if not ends_at_ping:
				at_sounds = false
	_ok(at_sounds, "the camera goes to the radar only at its sounds - a ping held to its sentence's end, its alarm and the walk after it - and never stays to watch it do nothing")
	# a ping is held from its ring PING_HOLD at least, to a sentence's end within PING_HOLD_MOST
	var pings_held := true
	for i in actions.size():
		if String(actions[i]["kind"]) == "ping" and t0[i] < INF:
			var hold := md._ping_hold(i) - t0[i]
			if hold < DispatchMedium.PING_HOLD - 0.01 or hold > DispatchMedium.PING_HOLD_MOST + 0.31:
				pings_held = false
	_ok(pings_held, "every ping holds the radar at least %.0f s, to the end of a sentence within %.0f s" % [DispatchMedium.PING_HOLD, DispatchMedium.PING_HOLD_MOST])
	_settling(md, radar_spot)
	# the mug is drunk from: upright all the way, brought to the mouth and out of the picture, then home in its ring
	var lift_i := _first(actions, "lift")
	var hold_t := t0[lift_i] + (DispatchScript.LIFT_UP + DispatchScript.LIFT_HOLD * 0.5) / md._sp[lift_i]
	var up_t := t0[lift_i] + DispatchScript.LIFT_UP * 0.5 / md._sp[lift_i]
	md._pose_mug(up_t)
	var upright_on_way := md._set.mug.global_transform.basis.y.normalized().dot(Vector3.UP) > 0.999
	md._pose_mug(hold_t)
	var held: Transform3D = md._set.mug.global_transform
	var at_mouth := held.origin.distance_to(md._cam.global_position) < 0.2 and held.basis.y.normalized().dot(Vector3.UP) > 0.999
	var unseen := true
	for q in [Vector3(0, 0.095, 0), Vector3(0, 0.095, -0.04), Vector3(0.04, 0.095, 0), Vector3(-0.04, 0.095, 0), Vector3(0, 0.05, -0.04)]:
		# looked at whichever way: down at the desk, and level
		for aim in [Vector3(0, -0.6, -1.0), Vector3(0, 0, -1.0)]:
			var cam_xf := Transform3D(Basis.looking_at(aim, Vector3.UP), md._cam.global_position)
			var mouth: Vector3 = cam_xf * DispatchMedium.MUG_MOUTH
			var local: Vector3 = cam_xf.affine_inverse() * (mouth + (q as Vector3))
			# inside the vertical half-angle of the widest lens the desk uses (27 degrees)?
			if local.z < 0.0 and absf(atan2(local.y, -local.z)) < deg_to_rad(27.0) and absf(atan2(local.x, -local.z)) < deg_to_rad(45.0):
				unseen = false
	md._pose_mug(t0[lift_i] - 0.5)
	_ok(upright_on_way and at_mouth and unseen and md._set.mug.global_transform.origin.distance_to(md._set.mug_home.origin) < 0.001,
		"the mug is drunk from: upright all the way, at the mouth and out of the picture for the sip, in its ring before (%s %s %s)" % [upright_on_way, at_mouth, unseen])
	# carried over what stands between it and the chair: a block 10 cm tall set just before the mug is never met, out or back
	# (the control: its arc at its least lift, as if nothing stood there, goes through it); and never higher than the mouth
	var mh := md._set.mug_home
	var toward := (md._cam.global_position - mh.origin) * Vector3(1, 0, 1)
	toward = toward.normalized()
	var block_at := mh.origin + toward * (md._set.mug_radius + 0.05)
	var block := AABB(Vector3(block_at.x - 0.04, DispatchSet.DESK_Y, block_at.z - 0.02), Vector3(0.08, 0.10, 0.04))
	md._set._parts["test block"] = [{"box": block}]
	var mug_box: AABB = md._set.bodies["mug"]
	var met := false
	var old_met := false
	var highest := -INF
	var mouth_y := INF
	for k in 41:
		var tt := t0[lift_i] + (DispatchScript.LIFT_UP + DispatchScript.LIFT_HOLD + DispatchScript.LIFT_DOWN) * float(k) / 40.0 / md._sp[lift_i]
		md._pose_mug(tt)
		var off: Vector3 = md._set.mug.global_transform.origin - mh.origin
		met = met or AABB(mug_box.position + off, mug_box.size).grow(-0.002).intersects(block)
		var held_now := Transform3D(mh.basis, md._cam.global_transform * DispatchMedium.MUG_MOUTH)
		highest = maxf(highest, md._set.mug.global_transform.origin.y)
		mouth_y = minf(mouth_y, held_now.origin.y)
		var u := (tt - t0[lift_i]) * md._sp[lift_i]
		var kk := DispatchMedium._jerkless(u / DispatchScript.LIFT_UP) if u < DispatchScript.LIFT_UP else (1.0 if u < DispatchScript.LIFT_UP + DispatchScript.LIFT_HOLD
			else 1.0 - DispatchMedium._jerkless((u - DispatchScript.LIFT_UP - DispatchScript.LIFT_HOLD) / DispatchScript.LIFT_DOWN))
		var old_off: Vector3 = DispatchMedium._mug_at(mh.origin, held_now.origin, DispatchMedium.MUG_LIFT.x, kk) - mh.origin
		old_met = old_met or AABB(mug_box.position + old_off, mug_box.size).grow(-0.002).intersects(block)
	md._set._parts.erase("test block")
	md._pose_mug(t0[lift_i] - 0.5)
	_ok(not met and old_met, "the mug is carried over what stands between it and the chair, out and back (the control: its arc lifted only %.0f cm, as if nothing stood there, goes through)"
		% (DispatchMedium.MUG_LIFT.x * 100.0))
	_ok(highest <= mouth_y + 0.01, "it is never lifted higher than the mouth on its way - never over the head (%.2f m, the mouth %.2f m)" % [highest, mouth_y])
	# a real sip: at the mouth from the end of its rise to the end of its hold (at least 2.5 s), after a rise of at least 1.5 s,
	# the voice silent until the sip is done (control: before its rise is over it is not there yet)
	var sip0 := t0[lift_i] + DispatchScript.LIFT_UP / md._sp[lift_i]
	var sip1 := t0[lift_i] + (DispatchScript.LIFT_UP + DispatchScript.LIFT_HOLD) / md._sp[lift_i]
	var mouth_at := func(t: float) -> bool:
		md._pose_mug(t)
		return md._set.mug.global_transform.origin.distance_to(md._cam.global_transform * DispatchMedium.MUG_MOUTH) < 0.005
	var rising: bool = not mouth_at.call(sip0 - 0.4)
	var sipping: bool = mouth_at.call(sip0 + 0.05) and mouth_at.call(sip1 - 0.05)
	var said_after: bool = float(at.call(int(actions[lift_i]["after"]))) >= sip1
	md._pose_mug(t0[lift_i] - 0.5)
	_ok(rising and sipping and sip1 - sip0 >= 2.5 and sip0 - t0[lift_i] >= 1.5 and said_after,
		"a real sip: brought up over %.1f s, held at the mouth %.1f s, the voice waiting for it (%s %s %s)" % [sip0 - t0[lift_i], sip1 - sip0, rising, sipping, said_after])
	var heard := md.sound_plan()
	var alarm := heard.filter(func(x: Dictionary) -> bool: return String(x.get("what", "")) == "alarm" and absf(float(x["t"]) - t0[moving_i]) < 0.01).size()
	var ticks := heard.filter(func(x: Dictionary) -> bool: return String(x.get("what", "")) == "tick" and float(x["t"]) > t0[moving_i] and float(x["t"]) < t0[stair_i]).size()
	_ok(alarm == 1 and ticks >= 1, "the radar sounds its alarm as he sets off, and ticks as the sweep passes him on his way (%d, %d)" % [alarm, ticks])
	# passing through: a moving straight after a ping sounds no alarm and turns no camera
	var pass_i := -1
	for i in actions.size():
		if String(actions[i]["kind"]) == "moving" and bool(actions[i].get("passing", false)):
			pass_i = i
	var pass_alarm := heard.filter(func(x: Dictionary) -> bool: return String(x.get("what", "")) == "alarm" and absf(float(x["t"]) - t0[pass_i]) < 0.01).size()
	var pass_look := md._attn.filter(func(w: Dictionary) -> bool: return absf(float(w["t0"]) - t0[pass_i]) < 0.01 and w["spot"] == radar_spot).size()
	_ok(pass_i >= 0 and pass_alarm == 0 and pass_look == 0, "passing through a place on the way, the radar sounds no alarm and the camera stays (%d, %d)" % [pass_alarm, pass_look])
	var stretch: Dictionary = {}
	for o in md._open:
		if float((o as Dictionary)["t"]) <= t0[static_i] + 1.0 and t0[static_i] + 1.0 < float(o["t1"]):
			stretch = o
	_ok(float(md.storm_at(t0[static_i] + 1.0).get("level", 0.0)) > 0.0 and not stretch.is_empty() and md.storm_at(float(stretch["t1"]) + 0.5).is_empty()
		and md.storm_at(t0[static_i] - 0.5).is_empty(), "the receiver is open only in its storm and under the voice it carries")
	# a text is read on its phone: a chime, the phone up before the eye and open, the message on its screen, no caption
	var text_i := _first(actions, "text")
	var reply_i := _first(actions, "reply")
	var read_t := t0[text_i] + (DispatchScript.TEXT_CHIME + DispatchScript.READ_LIFT) / md._sp[text_i] + 0.2
	var shown_thread: Array = md._reading("AISLE", read_t)["thread"]
	_ok(md.phone_at("AISLE", read_t) == "read" and not shown_thread.is_empty() and String(shown_thread[0][1]) == "He smiled at me"
		and md.get("_caption") == null and md.looking_at(read_t) == "home",
		"a text: the phone up before the eye, the message on its screen, never captioned (%s, %s)" % [md.phone_at("AISLE", read_t), str(shown_thread)])
	var keys_r: PackedFloat32Array = md._chars.get(reply_i, PackedFloat32Array())
	var half_r := md._reading("AISLE", keys_r[int(keys_r.size() * 0.5)] + 0.01)["thread"] as Array
	var sent_t := md._sent_at(reply_i)
	var after_r := md._reading("AISLE", sent_t + 0.05)["thread"] as Array
	_ok(half_r.size() == 2 and String(half_r[1][0]) == "out" and String(half_r[1][1]).length() < "Good. Let him wonder.".length() and not bool(half_r[1][2])
		and String(after_r[1][1]) == "Good. Let him wonder." and bool(after_r[1][2]),
		"the answer is typed, and sent once said (%s / %s)" % [str(half_r), str(after_r)])
	# typed on the phone's keypad at a thumb's pace, all of it before it is said (the control: under its words as they are said,
	# it would go at the voice's pace, far quicker)
	var reply_text := String(actions[reply_i]["text"])
	var keyed := keys_r[keys_r.size() - 1] - keys_r[0]
	var first_said := md._word_t0(int(actions[reply_i]["from"]))
	var said_for := md._word_t1(int(actions[reply_i]["to"]) - 1) - first_said
	var gaps := PackedFloat32Array()
	for c in range(1, keys_r.size()):
		gaps.append(keys_r[c] - keys_r[c - 1])
	var mean := 0.0
	for g in gaps:
		mean += g / float(gaps.size())
	var spread := 0.0
	for g in gaps:
		spread += (g - mean) * (g - mean) / float(gaps.size())
	spread = sqrt(spread) / maxf(mean, 1e-6)
	_ok(keyed >= float(keys_r.size() - 1) / DispatchScript.T9_RATE / md._sp[reply_i] * 0.85 and keys_r[keys_r.size() - 1] <= first_said
		and float(reply_text.length()) / said_for > DispatchScript.T9_RATE and spread > 0.2,
		"a reply is typed on the phone's keys at %.1f a second on the whole, unevenly (each key %.0f%% off the mean - the control, even keys, 0), %.1f s for its %d characters, before it is said (said, it goes by at %.1f a second)"
		% [DispatchScript.T9_RATE, spread * 100.0, keyed, reply_text.length(), float(reply_text.length()) / said_for])
	_ok(md.phone_at("AISLE", sent_t + DispatchScript.READ_DOWN + 0.3) == "row", "then the phone goes home (%s)" % md.phone_at("AISLE", sent_t + DispatchScript.READ_DOWN + 0.3))
	var plan_r := md.sound_plan()
	var chimed := plan_r.filter(func(x: Dictionary) -> bool: return String(x.get("what", "")) == "chime" and absf(float(x["t"]) - t0[text_i]) < 0.01).size()
	var pads := plan_r.filter(func(x: Dictionary) -> bool: return String(x.get("what", "")) == "pad" and float(x["t"]) > t0[reply_i] and float(x["t"]) < sent_t).size()
	var sends := plan_r.filter(func(x: Dictionary) -> bool: return String(x.get("what", "")) == "sent").size()
	_ok(chimed == 1 and pads >= 10 and sends == 1, "it chimes as it comes, its keys tap as the answer is typed, and it is sent (%d, %d, %d)" % [chimed, pads, sends])
	# speed dial: up before the eye, 1 held, Send, then to the ear
	var dial_mv: Dictionary = {}
	for m in md._phone_moves:
		if String((m as Dictionary).get("how", "")) == "dial" and String(m["to"]) == "read":
			dial_mv = m
			break
	var pressed_t := float(dial_mv.get("dialed", INF)) + DispatchScript.SPEED_PRESS + 0.1
	var dialed_one := 0
	for x in plan_r:
		var xd: Dictionary = x
		if String(xd.get("what", "")) == "dtmf" and int(xd.get("digit", -1)) == 1 \
				and absf(float(xd["t"]) - (float(dial_mv.get("dialed", INF)) + DispatchScript.SPEED_PRESS)) < 0.05:
			dialed_one += 1
	_ok(not dial_mv.is_empty() and md.phone_at(String(dial_mv["label"]), pressed_t) == "read" and dialed_one == 1
		and md.phone_at(String(dial_mv["label"]), float(dial_mv["dialed"]) + DispatchScript.DIAL + 0.2) == "ear",
		"a call is speed-dialed: up before the eye, 1 held, then to the ear for the rings (%s)" % str(dial_mv.get("label")))
	# the far end rings until it answers: never on under its first word (the control: answered a second into the rings, they stop
	# there)
	var answered := float(dial_mv.get("answered", INF))
	var ring_from := float(dial_mv["dialed"]) + DispatchScript.DIAL / md._sp_of(dial_mv)
	var rings_over := plan_r.filter(func(x: Dictionary) -> bool: return String(x.get("kind", "")) == "ringback" and absf(float(x["t"]) - ring_from) < 0.001 \
		and float(x["t1"]) > answered + 0.001).size()
	dial_mv["answered"] = ring_from + 1.0
	md._build_sound()
	var early := md.sound_plan().filter(func(x: Dictionary) -> bool: return String(x.get("kind", "")) == "ringback")
	dial_mv["answered"] = answered
	md._build_sound()
	_ok(answered < INF and rings_over == 0 and early.size() >= 1 and is_equal_approx(float((early[0] as Dictionary)["t1"]), ring_from + 1.0),
		"the far end rings until it answers, never on under its first word (the control: answered a second into its rings, they stop there)")
	var bell_block := _first(actions, "bell") + 1
	_gain_bell_lamp(md, actions, t0, plan_r, bell_block)
	_black_tablet_clip(md, actions, t0, plan_r, st)
	_clock_mid_way(md, body, parsed, words, st)
	# two small notes on one desk of their own (the same phones, so it is built once)
	var small := DispatchMedium.new()
	small.feed = md.feed
	small.mount(st)
	_unwatched(small)
	_picture_after_block(small)
	_typing_cadence(small)
	_said_keys_typing(small)
	_call_across_black(small)
	_timer_mid_way(small)
	small.queue_free()
	_clock_skip(st, md.feed)
	_receiver(st, md.feed)
	_grid_and_film(st, md.feed)
	_browsing(st, md.feed)
	_glass_hold(st, md.feed)
	_opens_black(st)
	_bridge_live(st, md.feed)
	_environment(md)
	# captions
	md._follower.extend(words)
	_ok(not md._captioned(mid, mid, 0.0) and md._captioned(hello, hello, 0.0), "a typed word is captioned, or a spoken one is not")
	# live reading
	var live := DispatchMedium.new()
	live.feed = md.feed
	live.mount(st)
	live.load_note(body, {"seed": 3})
	var kept := -1
	var was := INF
	var moved := false
	var fed := 0
	var t := 0.0
	while t < end_t:
		t += 0.25
		while fed < words.size() and float((words[fed] as Dictionary)["t0"]) < t + 3.0:
			fed += 1
		live._now = t
		live.take_words(words.slice(0, fed))
		if kept < 0:
			for i in actions.size():
				if live.starts()[i] < t - 0.5:
					kept = i
					was = live.starts()[i]
					break
		elif absf(live.starts()[kept] - was) > 0.001:
			moved = true
	_ok(kept >= 0 and not moved, "a live reading's begun action keeps its start as the plan is made again")
	_reseed_live(live, body, words, end_t * 0.5)
	# roots
	_ok(md._roots.on_desk.size() >= 2 and DispatchRoots.grown(end_t + 2000.0) > DispatchRoots.grown(0.0),
		"roots reach onto the desk, and grow through the night (%d on the desk)" % md._roots.on_desk.size())
	# built on a worker, as the app builds it: the show held, the desk put in as it lands
	DispatchMedium.away_in_tests = true
	var away := DispatchMedium.new()
	away.feed = md.feed
	away.mount(st)
	away.load_note(body, {"seed": 3})
	var on_worker := away._set == null and away._build_task >= 0 and away._waiting
	# waited for as long as the build takes (CI runs four gates on four cores): the clock only stops a hang
	var held_all := true
	var frames := 0
	var a0 := Time.get_ticks_msec()
	while away._set == null and Time.get_ticks_msec() - a0 < 120000:
		held_all = held_all and away._waiting
		away.advance(null, 0.016, 1.0)
		await process_frame
		frames += 1
	var away_ms := Time.get_ticks_msec() - a0
	DispatchMedium.away_in_tests = false
	print("  the desk built on a worker in %d ms (%d frames)" % [away_ms, frames])
	_ok(on_worker and held_all and away._set != null and not away._waiting and away._roots.on_desk.size() >= 2,
		"in the app the desk is built on a worker, the show held until it lands (%d frames, %d ms)" % [frames, away_ms])
	md.queue_free()
	live.queue_free()
	away.queue_free()
	if _fails.is_empty():
		print("dispatch_check: ALL OK (%d actions over %.0f s)" % [actions.size(), end_t])
		quit(0)
	else:
		for f in _fails:
			print("dispatch_check: FAIL  " + f)
		quit(1)


## What a [DispatchMedium] reads of the reading's subtitles: its live document.
class LiveSubs extends RefCounted:
	var document := {}


## A seed changed in the live document while the note plays, [param at] seconds in: a new desk, the reading's place kept
## (every begun action where it began, the words heard still heard). Control: the note's words changed load it again.
func _reseed_live(md: DispatchMedium, body: String, words: Array, at: float) -> void:
	var subs := LiveSubs.new()
	subs.document = {"source": body, "dispatch": {"seed": 3}}
	md._subs = subs
	md._doc_key = ""
	md._ensure_doc()
	var fed := 0
	while fed < words.size() and float((words[fed] as Dictionary)["t0"]) < at + 3.0:
		fed += 1
	md._now = at
	md.take_words(words.slice(0, fed))
	var held := md._held.duplicate(true)
	var starts := md.starts()
	var set_was: DispatchSet = md._set
	var feet_was := str(set_was.footprints)
	(subs.document["dispatch"] as Dictionary)["seed"] = 11
	md._ensure_doc()
	var kept := not held.is_empty() and md._held == held and md._built_n == fed
	for i in held:
		kept = kept and absf(md.starts()[i] - starts[i]) < 0.001
	_ok(md._seed == 11 and md._set != set_was and str(md._set.footprints) != feet_was and md._clutter == DispatchMedium.clutter_of(11)
		and kept, "a new seed while the note plays draws a new desk and keeps the reading's place (%d begun actions)" % held.size())
	subs.document["source"] = body + "\n\nOne more line."
	md._ensure_doc()
	_ok(md._held.is_empty() and md._built_n == -1, "control: the note's words changed load it again")


## The gain, the bell and the lamp, on the fixture's night.
func _gain_bell_lamp(md: DispatchMedium, actions: Array, t0: PackedFloat32Array, heard: Array, block_i: int) -> void:
	var up := _first(actions, "gain")
	var down := -1
	for i in range(up + 1, actions.size()):
		if String(actions[i]["kind"]) == "gain":
			down = i
	var turned := md._step_at(up, 9)
	var mid_turn := (md._step_at(up, 4) + turned) * 0.5
	md._pose(turned + 0.2)
	var knob_at := deg_to_rad((md._set.rigs["radar"] as PropRig).value("gain", "angle"))
	md._pose(t0[up] - 0.2)
	var knob_was := deg_to_rad((md._set.rigs["radar"] as PropRig).value("gain", "angle"))
	_ok(is_equal_approx(md.gain_at(t0[up] - 0.1), 3.0) and is_equal_approx(md.gain_at(turned + 0.05), 9.0)
		and md.gain_at(mid_turn) > 4.0 and md.gain_at(mid_turn) < 9.0
		and is_equal_approx(knob_at, DispatchSet.gain_angle(9.0)) and is_equal_approx(knob_was, DispatchSet.gain_angle(3.0)) and knob_at < knob_was,
		"the gain knob stands at three, and is turned steadily to nine, clockwise (%.1f, %.1f)" % [md.gain_at(mid_turn), rad_to_deg(knob_at)])
	var clicks := heard.filter(func(x: Dictionary) -> bool: return String(x.get("what", "")) == "detent" and float(x["t"]) >= t0[up] and float(x["t"]) <= turned + 0.01).size()
	_ok(clicks == 6 and md.looking_at(turned + 0.5) == "radar", "a click a step as it turns, the camera on the radar (%d clicks, %s)" % [clicks, md.looking_at(turned + 0.5)])
	var before: Dictionary = md.radar_at(t0[up] - 0.1)
	var full := md.clutter_at(turned + DispatchMedium.SWEEP * 1.05)
	var early := md.clutter_at(turned + 0.01)
	var him := md.target_at(turned)
	var round_him := full.filter(func(c: Dictionary) -> bool: return not c.has("chair"))
	var chair := full.filter(func(c: Dictionary) -> bool: return c.has("chair"))
	var near := true
	for c in round_him:
		if ((c as Dictionary)["at"] as Vector2).distance_to(him) > DispatchMedium.CLUTTER_BUILDING.length() + DispatchMedium.CLUTTER_DRIFT + 0.01 \
				or (c as Dictionary).has("label"):
			near = false
	_ok(not before.has("clutter") and round_him.size() == DispatchMedium.clutter_n(9) and round_him.size() >= 20 and near,
		"at three nothing on the scope but him (the control); at nine the clutter round him, unnamed (%d blips)" % round_him.size())
	_ok(early.size() < full.size(), "each blip is painted only once the sweep has passed it since the knob reached it (the control: just turned, %d of %d)" % [early.size(), full.size()])
	# the chair's own blip at nine; the control: the same night with the knob stopped at eight
	var seated := chair.size() == 1 and ((chair[0] as Dictionary)["at"] as Vector2).distance_to(DispatchMedium.CHAIR_AT) <= DispatchMedium.CLUTTER_JITTER * 1.5 \
		and not (chair[0] as Dictionary).has("label") and Vector2(DispatchMedium.CHAIR_AT).length() < 0.1
	var gain_up: Dictionary = md._actions[up]
	gain_up["to"] = 8
	var at_eight := md.clutter_at(md._step_at(up, 8) + DispatchMedium.SWEEP * 1.05)
	gain_up["to"] = 9
	var unseated := at_eight.filter(func(c: Dictionary) -> bool: return c.has("chair")).is_empty() and at_eight.size() == DispatchMedium.clutter_n(8)
	_ok(seated and unseated, "at nine the scope paints one more, unnamed, on the desk at its middle; at eight it does not (the control: %d blips at eight)" % at_eight.size())
	var lowered := md._step_at(down, 3)
	var fading := md.clutter_at(lowered + 0.5)
	var faded := true
	for c in fading:
		if float((c as Dictionary)["fade"]) >= 1.0:
			faded = false
	_ok(not fading.is_empty() and faded and md.clutter_at(lowered + DispatchMedium.CLUTTER_FADE + 0.1).is_empty(),
		"turned back to three, the clutter fades, and is gone in a sweep or two (%d fading)" % fading.size())
	# the bell, as the block after it goes up
	var rung := heard.filter(func(x: Dictionary) -> bool: return String(x.get("kind", "")) == "bell")
	var alert_i := _first(actions.slice(block_i + 1), "session") + block_i + 1
	_ok(rung.size() == 2 and absf(float(rung[0]["t"]) - t0[block_i]) < 0.01 and float(rung[0]["t1"]) > float(rung[0]["t"])
		and absf(float(rung[1]["t"]) - t0[alert_i]) < 0.01,
		"the bell rings as the block after it goes up, and an alert beeps as it does (%s)" % str(rung))
	# the lamp
	var lamp_i := _first(actions, "lamp")
	var click := t0[lamp_i] + DispatchScript.LAMP_AT / md._sp[lamp_i]
	md._pose(click - 0.05)
	var lit_before := md._set.lamp.light_energy
	md._pose(click + DispatchMedium.LAMP_FADE + 0.05)
	var dark := md._set.lamp.light_energy == 0.0 and not md._set.lamp.visible
	var clicked := heard.filter(func(x: Dictionary) -> bool: return String(x.get("what", "")) == "lamp" and absf(float(x["t"]) - click) < 0.01).size()
	var strength := float(((md._set.rigs["lamp"] as PropRig).built["lights"] as Array)[0]["energy"])
	_ok(is_equal_approx(lit_before, strength) and md.lamp_at(click + DispatchMedium.LAMP_FADE * 0.3) < 1.0 and dark and clicked == 1
		and md.looking_at(click + 0.5) == "home",
		"the lamp goes out at its click, dark in a moment, the camera on the whole desk (the control: lit before - %.2f, %s, %d, %s)" % [lit_before, dark, clicked, md.looking_at(click + 0.5)])
	# the outro waits for the desk: what it does after the last word (lamp, hesitation, sleep) is seen before the fade
	# (control: timed from the last word alone, already fading)
	var last := md._word_t1(md._spoken_n - 1)
	var after := md._after_last()
	var outro := md.feed.tail()
	md._now = last + 2.0
	var seen := md._end_fade()
	md._now = last + after + outro + 0.1
	var black := md._end_fade()
	var by_word := ShowOpening.end_fade(last + 2.0, md._follower, md._spoken_n, outro)
	_ok(outro > 2.0 and after > 3.0 and is_equal_approx(seen, 1.0) and black < 0.001 and by_word < 1.0,
		"the outro waits for what the desk does after the last word, black as it runs out (the control: from the last word, %.2f at 2 s; %.1f s of desk)" % [by_word, after])


## A line typed in a voice with no phone, said as it comes in on the receiver after a static; then the room's own typed line
## (the control).
func _receiver(st: SubViewport, feed: ShowFeed) -> void:
	var body := ("---\ndesk:\n  phones: [VAN]\n---\n\n<!-- speaker: Control -->\n\nListen.\n\n<!-- static: 3 -->\n\n"
		+ "```terminal\ntype (Council): WHAT DO WE DO ABOUT HIM\n```\n\nAlways.\n\n"
		+ "```terminal\ntype: LOGGED\n```\n\nThere.\n")
	var md := DispatchMedium.new()
	md.feed = feed
	md.mount(st)
	md.load_note(body, {"seed": 3})
	md._now = 0.0
	md.take_words(DispatchScript.rehearsal(DispatchScript.parse(body), 0.32))
	var acts: Array = md._actions
	var typed: Array = []
	for i in acts.size():
		if String((acts[i] as Dictionary)["kind"]) == "type":
			typed.append(i)
	var s_i := _first(acts, "static")
	var c_i := int(typed[0])
	var r_i := int(typed[1])
	var first0 := md._word_t0(int(acts[c_i]["from"]))
	var first1 := md._word_t1(int(acts[c_i]["from"]))
	var last1 := md._word_t1(int(acts[c_i]["to"]) - 1)
	var shut := -1.0
	var t := md.starts()[s_i] + 0.05
	while t < last1 + DispatchMedium.RECEIVER_TAIL - 0.05:
		if md.storm_at(t).is_empty():
			shut = t
			break
		t += 0.05
	_ok(String(acts[c_i].get("heard", "")) == DispatchScript.RECEIVER and shut < 0.0
		and md.storm_at(last1 + DispatchMedium.RECEIVER_TAIL + 0.1).is_empty(),
		"the receiver is open from the static straight on through the voice that comes in on it, and shut after its tail (shut at %.2f)" % shut)
	var o: Dictionary = md._open[0]
	var mid := (first0 + first1) * 0.5
	var plain := DispatchSounds.storm_level(String(o["storm"]), mid - float(o["t"]), int(o["seed"]), float(o["t1"]) - float(o["t"]))
	var at_mid := md.storm_at(mid)
	_ok(is_equal_approx(float(at_mid["level"]), plain * DispatchSounds.UNDER) and float(at_mid["voice"]) > 0.4,
		"under the voice the storm is brought down and the needle swells in a word (%.3f of %.3f, voice %.2f)" % [float(at_mid["level"]), plain, float(at_mid["voice"])])
	var stretches := md.sound_plan().filter(func(x: Dictionary) -> bool: return String(x.get("kind", "")) == "static")
	_ok(stretches.size() == 1 and not (stretches[0]["under"] as Array).is_empty(),
		"the static and the voice on it are one stretch of the receiver's sound (%d)" % stretches.size())
	var room_mid := md._word_t0(int(acts[r_i]["from"])) + 0.05
	_ok(not (acts[r_i] as Dictionary).has("heard") and md.storm_at(room_mid).is_empty(),
		"the control: the room's own typed line opens nothing on the receiver")


## The grid down, the Environment switched and a film on the terminal, on a note of the gate's own: the power whole until a beat into
## its rest, then gone, every rig's lights out with it but the tablet's (the control: before the mark, whole); a film's terminal lit
## all the same; the beams off until their mark and on after it, the shafts the other way (the control: an element no mark names is
## not listed); the film up on the glass from a moment after its mark, as far into it as the show is past that, until its last frame
## and a beat; its frames decoded from a video FFmpeg makes here, a later one not the first, a moment sought back to found again; its
## sound heard while it plays.
func _grid_and_film(st: SubViewport, feed: ShowFeed) -> void:
	var ffmpeg := Deps.resolve("ffmpeg")
	if ffmpeg.is_empty():
		_ok(false, "FFmpeg is needed to make the film fixture")
		return
	var dir := OS.get_temp_dir().path_join("ghost_dispatch_film_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(dir)
	var video := dir.path_join("fixture.mp4")
	var wav := dir.path_join("fixture.wav")
	OS.execute(ffmpeg, ["-y", "-nostdin", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=size=160x120:rate=10", "-t", "3",
		"-c:v", "libx264", "-pix_fmt", "yuv420p", "-g", "10", video])
	OS.execute(ffmpeg, ["-y", "-nostdin", "-loglevel", "error", "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=44100", "-t", "3",
		"-c:a", "pcm_s16le", wav])
	var films := {"fixture.mp4": {"kind": "file", "ready": true, "video": video, "sound": wav, "secs": 3.0, "size": Vector2i(160, 120), "fps": 10.0}}
	var body := ("---\ndesk:\n  phones: [VAN]\n---\n\n<!-- speaker: Control -->\n\nListen.\n\n<!-- power: off -->\n\n"
		+ "<!-- play (terminal): fixture.mp4 -->\n\n<!-- hesitation: 1 -->\n\n<!-- environment: shafts off, beams on, 0 -->\n")
	var md := DispatchMedium.new()
	md.feed = feed
	md.mount(st)
	md.load_note(body, {"seed": 3, "films": films})
	md._now = 0.0
	md.take_words(DispatchScript.rehearsal(DispatchScript.parse(body, films), 0.32))
	var acts: Array = md._actions
	var t0 := md.starts()
	var p_i := _first(acts, "power")
	var f_i := _first(acts, "play")
	var e_i := _first(acts, "environment")
	var gone := t0[p_i] + DispatchMedium.POWER_AT + DispatchMedium.POWER_FADE + 0.05
	md._pose(t0[p_i] - 0.05)
	var lit_before := (md._set.rigs["radar"] as PropRig).lights().all(func(l: Light3D) -> bool: return l.visible)
	md._pose(gone)
	var dark := (md._set.rigs["radar"] as PropRig).lights().all(func(l: Light3D) -> bool: return not l.visible)
	var lamp_dark := (md._set.rigs["lamp"] as PropRig).lights().all(func(l: Light3D) -> bool: return not l.visible) if md._set.rigs.has("lamp") else true
	_ok(is_equal_approx(md.power_at(t0[p_i] - 0.05), 1.0) and is_equal_approx(md.power_at(gone), 0.0) and lit_before and dark and lamp_dark,
		"the grid goes down a beat into its rest, the radar's and the lamp's lights with it (the control: before it, whole)")
	md._surround = Surroundings.sanitize({"elements": [{"kind": "shafts"}, {"kind": "beams"}, {"kind": "dust"}]})
	var before := md.env_levels(t0[e_i] - 0.05)
	var after := md.env_levels(t0[e_i] + 0.05)
	_ok(is_equal_approx(float(before.get(0, -1.0)), 1.0) and is_equal_approx(float(before.get(1, -1.0)), 0.0)
		and is_equal_approx(float(after.get(0, -1.0)), 0.0) and is_equal_approx(float(after.get(1, -1.0)), 1.0) and not after.has(2),
		"the beams are off until their mark and on after it, the shafts the other way (the control: the dust, never named, is not listed) (%s %s)" % [before, after])
	var mid := t0[f_i] + DispatchMedium.FILM_WAKE + 1.5
	var up := md.film_at("terminal", mid)
	_ok(md.film_at("terminal", t0[f_i] - 0.05).is_empty() and absf(float(up.get("at", -1.0)) - 1.5) < 0.01 and bool(up.get("playing", false))
		and md.film_at("terminal", t0[f_i] + DispatchMedium.FILM_WAKE * 2.0 + 3.0 + DispatchMedium.FILM_HOLD + 0.1).is_empty(),
		"the film is up on the glass after its mark, as far into it as the show is past that, and gone after its last frame and a beat (%s)" % up)
	md._pose(mid)
	var term_lit := (md._set.rigs["terminal"] as PropRig).lights().any(func(l: Light3D) -> bool: return l.visible)
	md._hear_films(mid)
	var player: ScreenFilm = md._players.get("fixture.mp4")
	_ok(term_lit and player != null and player._player != null and player._player.playing,
		"with the grid down the terminal a film plays on is lit, and the film is heard")
	var sf := ScreenFilm.new(films["fixture.mp4"])
	var a := sf.image_at(0.0, true)
	var b := sf.image_at(2.0, true)
	var c := sf.image_at(0.05, true)
	_ok(a != null and b != null and c != null and a.get_size() == Vector2i(160, 120) and a.get_data() != b.get_data() and c.get_data() == a.get_data(),
		"the film's frames are decoded by its time: a later one not the first, a moment sought back to found again")
	sf.stop()
	md._exit_tree()
	md.queue_free()
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


## The tablet browsed, on the browsing note: what its screen shows as each page is reached.
func _browsing(st: SubViewport, feed: ShowFeed) -> void:
	var body := FileAccess.get_file_as_string(BROWSING)
	var md := DispatchMedium.new()
	md.feed = feed
	md.mount(st)
	md.load_note(body, {"seed": 3})
	md._now = 0.0
	md.take_words(DispatchScript.rehearsal(DispatchScript.parse(body), 0.32))
	var acts: Array = md._actions
	var at: Array = []                    # the page actions, by index
	for i in acts.size():
		if String(acts[i]["kind"]) == "page":
			at.append(i)
	var face := func(t: float) -> Dictionary: return md.tablet_at(t)["face"]
	var times := func(n: int) -> Dictionary: return md._page_times(int(at[n]))
	var up := func(n: int) -> Dictionary: return md.tablet_at(float(md._page_times(int(at[n]))["shown"]) + 0.05)["face"]
	var view := float(DispatchScreens.TABLET_SIZE.y) - TabletChrome.TOP
	var down := func(f: Dictionary) -> Vector2: return Vector2(0.0, TabletChrome.TOP - float(f.get("scroll", 0.0)))
	# a link at the page's foot, then back
	var forum: TabletPage = up.call(0)["page"]
	var words_tap: Dictionary = face.call(float(times.call(1)["tap"]) + 0.05)
	var left := md._reach_scroll(int(at[0]), int(at[1]))
	_ok(words_tap.get("page") == forum and words_tap.has("tap") and left > view * 0.5 and is_equal_approx(float(words_tap["scroll"]), snappedf(left, 0.5)),
		"a link at the page's foot is brought into view and tapped there (scrolled %.0f px)" % left)
	var back_tap: Dictionary = face.call(float(times.call(2)["tap"]) + 0.05)
	var back_up: Dictionary = up.call(2)
	_ok(back_tap.get("tap") == TabletChrome.back_at() and back_tap.get("page") == up.call(1)["page"] and bool(back_tap["can_back"])
		and back_up.get("page") == forum and is_equal_approx(float(back_up["scroll"]), snappedf(left, 0.5)) and not bool(back_up["can_back"])
		and float(up.call(0)["scroll"]) == 0.0,
		"back is tapped on its arrow and the page before comes back scrolled where it was left (%.0f px; the control: a page come up is at its top)" % float(back_up["scroll"]))
	var tell_tap: Dictionary = face.call(float(times.call(3)["tap"]) + 0.05)
	_ok(String(acts[at[3]]["how"]) == "tap" and tell_tap.get("page") == forum and tell_tap.has("tap") and float(tell_tap["scroll"]) < left - view * 0.3
		and String(up.call(3)["url"]) == "forum.board" and up.call(3)["page"] != forum,
		"a link on the page come back to is brought into view and tapped, never its address typed (%.0f px from %.0f)" % [float(tell_tap["scroll"]), left])
	# a new tab, and an address typed into it
	var plus: Dictionary = face.call(float(times.call(4)["tap"]) + 0.05)
	var blank: Dictionary = face.call(float(times.call(4)["shown"]) + 0.4)
	_ok(plus.get("tap") == TabletChrome.plus_rect(Vector2(DispatchScreens.TABLET_SIZE)).get_center() and (plus["tabs"] as Array).size() == 1
		and blank.get("page") == null and blank["tabs"] == [up.call(3)["page"].title, "New Tab"] and int(blank["tab"]) == 1 and bool(blank["typing"])
		and String(blank["typed"]).is_empty() and float(blank["kb"]) > 0.5 and not bool(blank["can_back"]),
		"a new tab is opened by its plus: a blank tab beside the first, its bar ready and the keyboard up (%s)" % str(blank["tabs"]))
	var ducks_keys: PackedFloat32Array = times.call(5)["keys"]
	var ducks_typing: Dictionary = face.call(ducks_keys[4] + 0.01)
	var ducks: TabletPage = up.call(5)["page"]
	_ok(String(ducks_typing["typed"]) == "ducks" and bool(ducks_typing["typing"]) and float(ducks_typing["kb"]) == 1.0 and String(ducks_typing["key"]) == "s"
		and ducks_typing.get("page") == null and ducks != null and float(up.call(5).get("kb", 0.0)) < 1.0 and up.call(5)["tabs"] == [up.call(3)["page"].title, ducks.title],
		"an address is typed into the blank tab's bar a key at a time under the keyboard, and its page comes up in that tab (%s)" % String(ducks_typing["typed"]))
	# a search in the engine's own box
	var box_keys: PackedFloat32Array = times.call(6)["keys"]
	var box_tap: Dictionary = face.call(float(times.call(6)["tap"]) + 0.05)
	var box_typing: Dictionary = face.call(box_keys[7] + 0.01)
	var results: Dictionary = up.call(6)
	_ok(ducks.search_rect.size != Vector2.ZERO and box_tap.get("tap") == ducks.search_rect.get_center() + down.call(box_tap)
		and String(box_typing.get("box", "")) == "how many" and not bool(box_typing.get("typing", false)) and box_typing.get("page") == ducks
		and float(box_typing["kb"]) > 0.9 and ducks.search_rect.end.y + down.call(box_typing).y < float(DispatchScreens.TABLET_SIZE.y) * (1.0 - TabletChrome.KEYBOARD),
		"a search on a search engine's page is typed into the page's own box, tapped first, clear of the keyboard - never into the address bar (%s)" % String(box_typing.get("box", "")))
	var lazy := (box_keys[box_keys.size() - 1] - box_keys[0]) / float(box_keys.size() - 1)
	_ok(String(results["url"]) == "how many are there" and results["page"] != ducks and bool(results["can_back"]) and not results.has("box")
		and lazy > DispatchScript.TABLET_KEY * 1.5,
		"...at the tablet medium's pace, and its results come up under what was searched for (%.2f s a key, the bar's %.2f)" % [lazy, DispatchScript.TABLET_KEY])
	var bar_keys: PackedFloat32Array = times.call(8)["keys"]
	var bar_typing: Dictionary = face.call(bar_keys[2] + 0.01)
	_ok(String(bar_typing.get("typed", "")) == "who" and bool(bar_typing["typing"]) and not bar_typing.has("box") and float(times.call(8)["tap"]) == INF,
		"the control: a search from an article is typed into the address bar")
	_ok(up.call(11)["page"] == ducks and not bool(up.call(11)["can_back"]) and bool(up.call(10)["can_back"]),
		"back three times over is the tab's first page again, nothing behind it")
	# a reply typed into the page
	var post_i := _first(acts, "post")
	var keyed: PackedFloat32Array = md._chars[post_i]
	var chat: TabletPage = up.call(12)["page"]
	var posting: Dictionary = face.call(keyed[5] + 0.01)
	var sent := md._sent_at(post_i)
	var after: Dictionary = face.call(sent + 0.1)
	_ok(chat.reply_rect.size != Vector2.ZERO and forum.reply_rect.size == Vector2.ZERO and String(posting.get("post", "")) == "Be pat"
		and float(posting["kb"]) > 0.9 and chat.reply_rect.end.y + down.call(posting).y < float(DispatchScreens.TABLET_SIZE.y) * (1.0 - TabletChrome.KEYBOARD)
		and keyed[5] >= md._word_t0(int(acts[post_i]["from"])) and sent < INF and not after.has("post")
		and after.get("tap") == chat.send_rect().get_center() + down.call(after),
		"a reply is typed into the page's message box as it is said, clear of the keyboard, and sent (the control: a page that takes none has no box - %s)" % String(posting.get("post", "")))
	var again: Dictionary = up.call(13)
	_ok(again["page"] != chat and (again["page"] as TabletPage).reply_rect.size != Vector2.ZERO
		and is_equal_approx(float(again["scroll"]), snappedf(minf(md._page_left(int(at[12])), maxf((again["page"] as TabletPage).height - view, 0.0)), 0.5)),
		"the page loaded again comes up where it was left, its message box kept (%.0f px)" % float(again["scroll"]))
	md.queue_free()


## The camera on the terminal: after a block it stays on the glass while the voice talks of what is up, however long, through
## to what comes next, never pulled back to the whole desk for nothing (the controls: a block's look as it was, home within
## seconds; the same long talk with a linger of 8 s, home before the look).
func _glass_hold(st: SubViewport, feed: ShowFeed) -> void:
	var talk := "He keeps a log. Of course he keeps a log. He has a column for could be nothing, and he uses it for most of the night. "
	var made := func(paras: int) -> DispatchMedium:
		var body := ("<!-- speaker: Control -->\n\nHere.\n\n```terminal\n> x\npanel: menu = MENU | NIGHT 1\n  1  SUBJECTS\n  2  LOG\n```\n\n"
			+ "\n\n".join(range(paras).map(func(_n: int) -> String: return talk)) + "\n\n<!-- look: radar -->\n\nThere.\n")
		var md := DispatchMedium.new()
		md.feed = feed
		md.mount(st)
		md.load_note(body, {"seed": 3})
		md._now = 0.0
		md.take_words(DispatchScript.rehearsal(DispatchScript.parse(body), 0.32))
		return md
	var near: DispatchMedium = made.call(1)
	var s_i := _first(near._actions, "session")
	var done := near.starts()[s_i] + float(near._actions[s_i]["rest"])
	var look := near.starts()[_first(near._actions, "look")]
	var stays := true
	var t := done
	while t < look - 0.3:
		if near.looking_at(t) != "terminal":
			stays = false
		t += 0.5
	var bare := {"t0": near.starts()[s_i], "t1": near._end_of(s_i) + 1.5, "spot": near._spot("terminal")}
	var was: Array = near._attn
	near._attn = [bare]
	var old_home := near.looking_at(done + DispatchMedium.HOME_AFTER + 5.0) == "home"
	near._attn = was
	var far: DispatchMedium = made.call(12)
	var f_done := far.starts()[_first(far._actions, "session")] + float(far._actions[_first(far._actions, "session")]["rest"])
	var f_look := far.starts()[_first(far._actions, "look")]
	var held_on := true
	t = f_done
	while t < f_look - 0.3:
		held_on = held_on and far.looking_at(t) == "terminal"
		t += 1.0
	# the control: the same two looks settled with a linger of 8 s, as the glass once had
	var kept: Array = far._attn
	var fs := _first(far._actions, "session")
	far._attn = far._settled([{"t0": far.starts()[fs], "t1": far._end_of(fs) + 1.5, "hold": far._glass_hold(fs, f_done), "linger": 8.0,
		"spot": far._spot("terminal")}, {"t0": f_look, "t1": INF, "spot": far._spot("radar"), "sticky": true}])
	var lingered_home := far.looking_at(f_look - 3.0) == "home"
	far._attn = kept
	_ok(stays and look - done > DispatchMedium.GLASS_LEAST and old_home and held_on and f_look - f_done > 40.0 and lingered_home,
		"after a block the camera stays on the glass while the voice talks of it, %.0f s of talk too, through to what comes next (the controls: as it was, home by %.0f s; with a linger of 8 s, home before the look) - %s %.1f %s %s %s" % [f_look - f_done,
			DispatchMedium.HOME_AFTER + 5.0, stays, look - done, old_home, held_on, lingered_home])
	near.queue_free()
	far.queue_free()


## The black and the clock, the tablet and a clip, on the fixture's night.
## A reading started mid-way, a few words past the fade up, its words on its own clock (the first at 0) and how far in it
## starts handed: its clock turns to the next minute where the whole reading's does. Control: the fade counted from the far
## past the start places it in reads hours off.
func _clock_mid_way(md: DispatchMedium, body: String, parsed: Dictionary, words: Array, st: SubViewport) -> void:
	var up := -1
	for i in md._actions.size():
		if String(md._actions[i]["kind"]) == "fade" and not bool(md._actions[i]["to"]):
			up = i
	var k := int(md._actions[up]["after"]) + 6
	var since := float((words[k] as Dictionary)["t0"])
	var later: Array = []
	for w in words.slice(k):
		var d: Dictionary = (w as Dictionary).duplicate()
		d["t0"] = float(d["t0"]) - since
		d["t1"] = float(d["t1"]) - since
		later.append(d)
	var spoken: PackedStringArray = parsed["spoken"]
	var mid := DispatchMedium.new()
	mid.feed = md.feed
	mid.mount(st)
	mid.load_note(body, {"seed": 3}, spoken.slice(k, k + 8), k, since)
	mid._now = 0.0
	mid.take_words(later)
	var turn := md._t0[up] + DispatchScript.FADE / md._sp[up]
	var whole := [md.clock_at(turn + 59.0).get("to", ""), md.clock_at(turn + 61.0).get("to", "")]
	var part := [mid.clock_at(turn + 59.0 - since).get("to", ""), mid.clock_at(turn + 61.0 - since).get("to", "")]
	var far := mid._t0[up] + DispatchScript.FADE / mid._sp[up]
	var counted := DispatchScript.clock_text(int(md._actions[up]["clock"]) + int(floor((turn + 61.0 - since - far) / 60.0)))
	_ok(mid._follower.start_si == k and far < -1000.0 and whole == ["23:40", "23:41"] and part == whole and counted != "23:41",
		"a reading started past the fade turns its clock where a whole one does (%s, %s; counted from the far past %s)" % [part, whole, counted])
	mid.queue_free()


func _black_tablet_clip(md: DispatchMedium, actions: Array, t0: PackedFloat32Array, heard: Array, st: SubViewport) -> void:
	var down := -1
	var up := -1
	for i in actions.size():
		if String(actions[i]["kind"]) == "fade":
			if bool(actions[i]["to"]):
				down = i
			else:
				up = i
	var black0 := md._end_of(down)
	var turn := t0[up] + DispatchScript.FADE / md._sp[up]
	_ok(md.fade_at(t0[down] - 0.1) == 0.0 and md.fade_at(black0 + 0.01) == 1.0 and md.fade_at(t0[up] - 0.01) == 1.0
		and md.fade_at(turn + 0.05) == 0.0 and md.fade_at(t0[up] + DispatchScript.FADE * 0.5 / md._sp[up]) > 0.0,
		"the picture goes down to black and comes back up over its fades")
	var before: Dictionary = md.clock_at(turn - 0.2)
	var turning: Dictionary = md.clock_at(turn + DispatchScript.CLOCK_TURN * 0.5)
	var turned: Dictionary = md.clock_at(turn + DispatchScript.CLOCK_TURN + 0.1)
	var minute: Dictionary = md.clock_at(turn + 60.0 + DispatchScript.CLOCK_TURN + 0.1)
	_ok(String(before["to"]) == "23:39" and String(turning["from"]) == "23:39" and String(turning["to"]) == "23:40" and float(turning["u"]) > 0.0
		and float(turning["u"]) < 1.0 and String(turned["to"]) == "23:40" and float(turned["u"]) == 1.0 and String(minute["to"]) == "23:41",
		"coming up, the clock's cards turn over to the time given, and it runs on a minute a minute (%s, %s, %s)" % [before, turned, minute])
	var clock_at_desk := md._set.desk_at("clock")
	var clicks := func(plan: Array, a: float, b: float) -> int:
		return plan.filter(func(x: Dictionary) -> bool: return String(x.get("what", "")) == "detent" and x.get("at") == clock_at_desk \
			and float(x["t"]) > a and float(x["t"]) < b).size()
	var flips: int = clicks.call(heard, turn, turn + 1.0)
	# the clock runs on through a long outro: a click as each minute turns over, silence between - and none once the show is over
	# (the control: with the outro as it was, the show ends before the next minute)
	var past_end: int = clicks.call(heard, turn + 2.0, turn + 600.0)
	var outro_was := md.feed.outro_hold
	md.feed.outro_hold = 150.0
	md._build_sound()
	var long_plan := md.sound_plan()
	var minute_on: int = clicks.call(long_plan, turn + 60.0, turn + 61.0) + clicks.call(long_plan, turn + 120.0, turn + 121.0)
	var between: int = clicks.call(long_plan, turn + 20.0, turn + 40.0)
	md.feed.outro_hold = outro_was
	md._build_sound()
	_ok(minute_on >= 2 and between == 0 and past_end == 0,
		"the clock clicks as its cards turn over each minute it runs (%d over two minutes) and is silent between (%d) - and past the show's end none (the control, %d)"
		% [minute_on, between, past_end])
	var held_t := t0[up] + float(actions[up]["rest"]) / md._sp[up]
	_ok(md.looking_at(black0 + 0.5) == "clock" and md.looking_at(turn + 0.3) == "clock" and md.looking_at(held_t + 1.5) != "clock" and flips == 2,
		"in the black the camera is on the clock, held while two cards turn and a beat, then eases away (%s, %s, %d flips)" % [md.looking_at(turn + 0.3), md.looking_at(held_t + 1.5), flips])
	# the camera is put across a seek, and eased out of a stall of the app's thread (a note coming up on a screen)
	_ok(not DispatchMedium.jumped(1.6, 1.6) and DispatchMedium.jumped(30.0, 0.016) and DispatchMedium.jumped(-5.0, 0.016),
		"a stall that moved the clock as far as the time it took is eased out of; a seek forward or back is cut across")
	_ok(DispatchMedium.jumped(1.6, 0.0), "the control: the same move of the clock in no time is a seek")
	var thrown := actions.filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "switch" and bool(a.get("dark", false)))
	var switch_looks := md._attn.filter(func(w: Dictionary) -> bool: return w["spot"] == md._spot("switch") and float(w["t0"]) > black0 - 0.1 and float(w["t0"]) < turn)
	_ok(thrown.size() == 1 and switch_looks.is_empty(), "what is marked in the black happens unseen: no look for it")
	var ping_back := -1
	for i in actions.size():
		if String(actions[i]["kind"]) == "ping" and bool(actions[i].get("jump", false)):
			ping_back = i
	var leg: Dictionary = md._legs.filter(func(l: Dictionary) -> bool: return int(l["i"]) == ping_back)[0]
	_ok(is_equal_approx(float(leg["t0"]), float(leg["t1"])), "the first ping after the black has no track across it")
	# the tablet
	var tab_up := _first(actions, "tablet")
	var tab_down := -1
	for i in actions.size():
		if String(actions[i]["kind"]) == "tablet" and not bool(actions[i]["up"]):
			tab_down = i
	var held := t0[tab_up] + DispatchScript.TABLET_UP / md._sp[tab_up] + 0.1
	md._pose(held)
	var in_hand := md._set.tablet.global_transform.origin.distance_to(md._set.tablet_held_xf().origin) < 0.001
	var laid := md._end_of(tab_down)
	md._pose(laid + 0.2)
	var home := md._set.tablet.global_transform.origin.distance_to(md._set.tablet_home.origin) < 0.001
	_ok(in_hand and home and float(md.tablet_at(t0[tab_up] - 0.1)["face"]["power"]) == 0.0 and md.looking_at(held + 2.0) == "tablet",
		"the tablet is picked up and held low over the desk, the camera on it, its screen woken, and laid back in its place")
	# laid down, the camera leaves where it was held a second on: for the whole desk, or straight on to what begins within
	# another second (the control: an ordinary look is held on through to what comes within its linger)
	var tab_spot: Dictionary = md._spot("tablet")
	var term_spot: Dictionary = md._spot("terminal")
	var laid_look := {"t0": 0.0, "t1": 20.0, "spot": tab_spot, "kind": "tablet", "linger": 0.0, "leaves": true}
	var left: Array = md._settled([laid_look.duplicate(), {"t0": 25.0, "t1": 30.0, "spot": term_spot, "kind": "session"}])
	var at_once: Array = md._settled([laid_look.duplicate(), {"t0": 20.0 + DispatchMedium.TABLET_LEAVE * 0.5, "t1": 30.0, "spot": term_spot, "kind": "session"}])
	var held_on: Array = md._settled([{"t0": 0.0, "t1": 20.0, "spot": tab_spot, "kind": "tablet"}, {"t0": 25.0, "t1": 30.0, "spot": term_spot, "kind": "session"}])
	_ok(float(left[0]["t1"]) == 20.0 and is_equal_approx(float(at_once[0]["t1"]), float(at_once[1]["t0"])) and float(held_on[0]["t1"]) == 25.0
		and md.looking_at(t0[tab_down] + DispatchMedium.TABLET_LEAVE * 0.5) == "tablet" and md.looking_at(laid + 0.5) != "tablet",
		"laid down, the camera leaves the tablet %.1f s on, for the whole desk or straight on to what begins at once - the control: an ordinary look held on to what comes (%.1f, %.1f, %.1f)"
			% [DispatchMedium.TABLET_LEAVE, float(left[0]["t1"]), float(at_once[0]["t1"]), float(held_on[0]["t1"])])
	# laid down, its screen is left lit on the page it was left on and locks itself: dimmed for the last seconds, then dark
	var lock := DispatchMedium.TABLET_LOCK
	var lain: Dictionary = md.tablet_at(laid + 0.2)["face"]
	var lit_late := float(md.tablet_at(laid + lock - DispatchMedium.TABLET_DIM - 0.5)["face"]["power"])
	var dimmed := float(md.tablet_at(laid + lock - 1.0)["face"]["power"])
	var locked := float(md.tablet_at(laid + lock + DispatchMedium.TABLET_OFF + 0.1)["face"]["power"])
	_ok(float(lain["power"]) == 1.0 and lain.get("page") != null and lit_late == 1.0 and dimmed > 0.0 and dimmed < 0.5 and locked == 0.0
		and is_equal_approx(md._end_of(tab_down) - t0[tab_down], DispatchScript.TABLET_DOWN / md._sp[tab_down]) and DispatchScript.TABLET_DOWN >= 1.5,
		"laid down unhurried, the tablet's screen stays lit on its page %.0f s, dimmed for the last of them, then locks dark (%.2f, %.2f, %.2f, %.2f)"
			% [lock, float(lain["power"]), lit_late, dimmed, locked])
	var pages: Array = []
	for i in actions.size():
		if String(actions[i]["kind"]) == "page":
			pages.append(i)
	var p1 := int(pages[0])
	var p2 := int(pages[1])
	var pt1 := md._page_times(p1)
	var typing: Dictionary = md.tablet_at((pt1["keys"] as PackedFloat32Array)[4] + 0.01)["face"]
	var first_up: Dictionary = md.tablet_at(float(pt1["shown"]) + 0.1)["face"]
	_ok(String(typing["typed"]) == "forum" and bool(typing.get("typing", false)) and first_up.get("page") != null and String(first_up["url"]) == "forum.board",
		"a page's address is typed into the bar a key at a time, then the page comes up (%s)" % String(typing.get("typed", "")))
	var pt2 := md._page_times(p2)
	var tapping: Dictionary = md.tablet_at(float(pt2["tap"]) + 0.1)["face"]
	var second_up: Dictionary = md.tablet_at(float(pt2["shown"]) + 0.1)["face"]
	_ok(String(md._actions[p2]["how"]) == "tap" and tapping.has("tap") and float(tapping["tap_u"]) >= 0.0 and tapping.get("page") == first_up.get("page")
		and second_up.get("page") != first_up.get("page") and String(second_up["url"]) == "forum.board" and bool(second_up.get("can_back", false)),
		"the next page is found on the one up and tapped, then it comes up")
	var follow: Array = md._page_follow(p1, float(DispatchScreens.TABLET_SIZE.y) - TabletChrome.TOP, 99999.0)["marks"]
	var drift0 := md._page_scroll(p2, float(pt2["shown"]) + DispatchScript.TABLET_LOOK + 0.5)
	var drift1 := md._page_scroll(p2, md._page_end(p2) - 0.5)
	_ok(not follow.is_empty() and drift1 > drift0, "a page follows the words said that are on it, and with none, eases down (%d words followed, %.0f to %.0f px)" % [follow.size(), drift0, drift1])
	# words read off a page, a run of them read on, are lit as they are said (the control: the next page, nothing read off it)
	var read_si := -1
	var sp: PackedStringArray = md._parsed["spoken"]
	for k in range(int(md._actions[p1]["after"]), sp.size() - 1):
		if sp[k] == "three" and sp[k + 1] == "nights":
			read_si = k + 1
			break
	var reading := md._page_lit(p1, md._word_t0(read_si) + 0.05) if read_si >= 0 else {}
	var after_page := md._page_lit(p2, md._page_end(p2) - 0.5)
	_ok(not reading.is_empty() and (reading["times"] as Dictionary).size() >= 3 and int(reading["cur"]) >= 0 and after_page.is_empty(),
		"words read off a page are lit as they are said (the control: a page nothing is read off lights nothing - %s)" % str((reading.get("times", {}) as Dictionary).size()))
	var live_i := -1
	for i in actions.size():
		if String(actions[i]["kind"]) == "live" and String(actions[i]["screen"]) == "tablet":
			live_i = i
	var player := Manuscript.image_key(DispatchScript.PLAYER)
	md._now = t0[live_i] - 0.05
	var dark_player := md._page_tex(player)
	md._now = t0[live_i] + 0.5
	var live_player := md._page_tex(player)
	_ok(dark_player != null and dark_player != md._live_vp.get_texture() and live_player == md._live_vp.get_texture(),
		"the page's player is dark until the desk is played live into it")
	# laid down, the player plays on while the screen is lit, and stops as it locks
	md._now = laid + 5.0
	var plays_on := md._page_tex(player) == md._live_vp.get_texture()
	md._now = laid + lock + DispatchMedium.TABLET_OFF + 0.1
	var stopped := md._page_tex(player) != md._live_vp.get_texture()
	md._now = t0[live_i] + 0.5
	_ok(t0[live_i] < t0[tab_down] and plays_on and stopped, "laid down, the tablet's player plays on until its screen locks (%s, %s)" % [plays_on, stopped])
	# a clip: the screen's static until one is imported, then its frames, looping
	var clip_i := -1
	for i in actions.size():
		if String(actions[i]["kind"]) == "picture" and (actions[i] as Dictionary).has("clip"):
			clip_i = i
	var on_tv := t0[clip_i] + 1.0
	md._pose_screens(on_tv)
	var tv: ShaderMaterial = md._mats["tv"]
	var snowing := float(tv.get_shader_parameter("snow")) > 0.5 and not bool(tv.get_shader_parameter("has_face"))
	var dir := OS.get_temp_dir().path_join("ghost_dispatch_clip_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(dir)
	for k in 3:
		var img := Image.create(16, 9, false, Image.FORMAT_RGB8)
		img.fill(Color(float(k) / 2.0, 0.2, 0.4))
		img.save_jpg(dir.path_join("%04d.jpg" % k))
	var key := String(actions[clip_i]["key"])
	md._clips = {key: {"dir": dir, "fps": 12, "frames": 3, "size": Vector2i(16, 9)}}
	md._clip_tex = {}
	md._pose_screens(on_tv)
	var frames: Array = []
	for secs in [0.0, 1.0 / 12.0 + 0.001, 2.0 / 12.0 + 0.001, 3.0 / 12.0 + 0.001]:
		var tex := md._clip_frame(key, secs)
		frames.append(int(md._clip_tex[key]["i"]) if tex != null else -1)
	var showing := bool(tv.get_shader_parameter("has_face"))
	for k in 3:
		DirAccess.remove_absolute(dir.path_join("%04d.jpg" % k))
	DirAccess.remove_absolute(dir)
	md._clips = {}
	_ok(snowing and showing and frames == [0, 1, 2, 0],
		"a clip not imported is the screen's static; imported, its frames play at its pace and loop (%s %s %s)" % [snowing, showing, str(frames)])
	# a voice with no phone, said as a paragraph, comes in on the receiver
	var said_i := _first(actions, "receiver")
	var w0 := md._word_t0(int(actions[said_i]["from"]))
	var w1 := md._word_t1(int(actions[said_i]["from"]))
	_ok(float(md.storm_at((w0 + w1) * 0.5).get("voice", 0.0)) > 0.0, "a paragraph in a voice with no phone comes in on the receiver, the needle moving with it")



## A picture told `unwatched` lands on its screen with the camera left where it is (the control: untold, the camera turns to it).
func _unwatched(md: DispatchMedium) -> void:
	var looked := {}
	for told in [", unwatched", ""]:
		var body := ("<!-- speaker: Control -->\n\nOne two three four five six seven eight.\n\n<!-- image (feed%s): an aisle with nobody in it -->\n\n"
			+ "Nine ten eleven twelve thirteen fourteen fifteen sixteen.\n\n<!-- ring: AISLE -->\n\nSeventeen.\n") % told
		md.load_note(body, {"seed": 3})
		md._now = 0.0
		md.take_words(DispatchScript.rehearsal(DispatchScript.parse(body), 0.32))
		var pic := _first(md._actions, "picture")
		var at := md.starts()[pic]
		looked[told] = [at < INF, String(md._actions[pic]["screen"]), md.looking_at(at + 1.0), md._look_key(md._actions[pic])]
	_ok(looked[", unwatched"] == [true, "feed", "home", ""] and looked[""] == [true, "feed", "feed", "feed"],
		"an unwatched picture lands on its screen with the camera left where it is; untold, the camera turns to it (%s, %s)"
			% [looked[", unwatched"], looked[""]])
	# a static told unwatched is heard with the camera left on the terminal; untold, the camera turns to the receiver
	var heard := {}
	for told in [", unwatched", ""]:
		var body := ("<!-- speaker: Control -->\n\nOne two three four.\n\n```terminal\n> m\npanel: MIRROR\nONE ROW\n```\n\n"
			+ "<!-- static: 3, surf%s -->\n\nFive six seven eight.\n") % told
		md.load_note(body, {"seed": 3})
		md._now = 0.0
		md.take_words(DispatchScript.rehearsal(DispatchScript.parse(body), 0.32))
		var st_i := _first(md._actions, "static")
		heard[told] = [md.looking_at(md.starts()[st_i] + 1.5), md.storm_at(md.starts()[st_i] + 1.5).is_empty()]
	_ok(heard[", unwatched"] == ["terminal", false] and heard[""] == ["receiver", false],
		"an unwatched static is heard with the camera left on the terminal; untold, the camera turns to the receiver (%s, %s)"
			% [heard[", unwatched"], heard[""]])


## A picture over the whole screen written after a block comes in once the block's typing is done (the control: written
## before the block, it comes in just after the word before, over the typing).
func _picture_after_block(md: DispatchMedium) -> void:
	var block := "```terminal\nkey: from ten thousand feet, it's all the same problems.\nkey: a roof. food. a ride. a doctor.\n```\n\n"
	var picture := "<!-- image (full): a small town seen from the air before dawn -->\n\n"
	var got := {}
	for order in ["after", "before"]:
		var body := "<!-- speaker: Control -->\n\nOne two three four.\n\n" + (block + picture if order == "after" else picture + block) \
			+ "Five six seven eight.\n"
		md.load_note(body, {"seed": 3})
		md._now = 0.0
		md.take_words(DispatchScript.rehearsal(DispatchScript.parse(body), 0.32))
		var sess := _first(md._actions, "session")
		var keys: Array = (md._actions[sess]["ops"] as Array).filter(func(o: Dictionary) -> bool: return String(o["op"]) == "key")
		var last_key: Dictionary = keys.back()
		var typed_by := md._t0[sess] + float((last_key["times"] as PackedFloat32Array)[-1]) / md._sp[sess]
		var sp: Dictionary = md._spans[0]
		got[order] = [md._picture_in(sp), typed_by, md._word_t1(int(sp["from"]) - 1) + 0.1]
	var a: Array = got["after"]
	var b: Array = got["before"]
	_ok(float(a[0]) < INF and float(a[0]) > float(a[1]) and float(b[0]) < float(b[1]) and is_equal_approx(float(b[0]), float(b[2])),
		"a picture written after a block comes in once its typing is done (%.1f s, typed by %.1f s); the control: written before it, just after the word before (%.1f s, typed by %.1f s)"
			% [float(a[0]), float(a[1]), float(b[0]), float(b[1])])


## A said passage is typed at an even pace ahead of its voice (the control: each word typed in the time of the word two
## before it, as the keys once were), on a voice whose words take as long as their letters and that rests at sentence ends.
func _typing_cadence(md: DispatchMedium) -> void:
	var body := "<!-- speaker: Control -->\n\nOne two three four.\n\n```terminal\n> m\npanel: MIRROR\n" \
		+ "read: they say he was ahead of his time. he wasn't ahead of anything.\n" \
		+ "read: we line them up by year, and put ourselves at the end.\n" \
		+ "read: that's how we live it. it isn't how they did.\n```\n\nFive six seven eight.\n"
	var parsed := DispatchScript.parse(body)
	var ti := _first(parsed["actions"], "type")
	var ty: Dictionary = (parsed["actions"] as Array)[ti]
	var text := String(ty["text"])
	var spans: Array = ty["spans"]
	var from := int(ty["from"])
	var words := DispatchScript.rehearsal(parsed, 0.32)
	var shift := 0.0
	for k in words.size():
		var w: Dictionary = words[k]
		w["t0"] = float(w["t0"]) + shift
		var long := 0.32
		var piece := ""
		if k >= from and k < from + spans.size():
			var sp: Dictionary = spans[k - from]
			piece = text.substr(int(sp["c0"]), int(sp["c1"]) - int(sp["c0"])).strip_edges()
			long = 0.1 + 0.045 * float(piece.length())
		w["t1"] = float(w["t0"]) + long * 0.9
		shift += long - 0.32 + (0.6 if piece.ends_with(".") or piece.ends_with("?") else 0.0)
	md.load_note(body, {"seed": 3})
	md._now = 0.0
	md.take_words(words)
	var keys: PackedFloat32Array = md._chars.get(ti, PackedFloat32Array())
	var n := spans.size()
	var said := func(k: int) -> float: return md._word_t0(from + k)
	var c0 := func(k: int) -> int: return int((spans[k] as Dictionary)["c0"])
	var c1 := func(k: int) -> int: return int((spans[k] as Dictionary)["c1"])
	var behind := 0
	var too_far := 0
	for k in n:
		if keys.is_empty() or keys[c1.call(k) - 1] >= said.call(k):
			behind += 1
		if k + DispatchScript.AHEAD_MOST + 1 < n and not keys.is_empty() and keys[c0.call(k + DispatchScript.AHEAD_MOST + 1)] < said.call(k) - 0.001:
			too_far += 1
	var paces := PackedFloat32Array()
	var olds := PackedFloat32Array()
	for k in range(DispatchScript.AHEAD_WORDS, n - 1):
		var chars := float(c0.call(k + 1) - c0.call(k))
		if not keys.is_empty():
			paces.append((keys[c0.call(k + 1)] - keys[c0.call(k)]) / chars)
		olds.append((float(said.call(k - 1)) - float(said.call(k - 2))) / chars)
	var swing: float = (float(Array(paces).max()) / maxf(float(Array(paces).min()), 1e-6)) if not paces.is_empty() else INF
	var old_swing: float = float(Array(olds).max()) / maxf(float(Array(olds).min()), 1e-6)
	_ok(behind == 0 and too_far == 0 and swing < old_swing * 0.5,
		"a said passage typed evenly ahead of its voice: %d words behind, %d more than %d ahead, its pace swinging %.1fx (the control, a word in the time of the word two before: %.1fx)"
			% [behind, too_far, DispatchScript.AHEAD_MOST, swing, old_swing])


## A block's last key: line that the paragraph after it says is typed ahead of its words, its unsaid end typed on after.
func _said_keys_typing(md: DispatchMedium) -> void:
	var body := "<!-- speaker: Control -->\n\nOne two three four.\n\n```terminal\n> m\npanel: MIRROR | HIS SCREEN\n" \
		+ "key: HIM: there was a man in a bathrobe at the end of the aisle again tonight. I used to get so angry at them. I don't anymore. if you can understand the rot of the whole, you can understand the struggle.\n" \
		+ "```\n\nThere was a man in a bathrobe at the end of the aisle again tonight. I used to get so angry at them. I don't anymore.\n\nFive six seven eight nine ten.\n"
	md.load_note(body, {"seed": 3})
	md._now = 0.0
	md.take_words(DispatchScript.rehearsal(DispatchScript.parse(body), 0.32))
	var ti := _first(md._actions, "type")
	var si := _first(md._actions, "session")
	var a: Dictionary = md._actions[ti] if ti >= 0 else {}
	var keys: PackedFloat32Array = md._chars.get(ti, PackedFloat32Array())
	var spans: Array = a.get("spans", [])
	var late := 0
	for k in spans.size():
		if keys.is_empty() or keys[int((spans[k] as Dictionary)["c1"]) - 1] >= md._word_t0(int((spans[k] as Dictionary)["word"])):
			late += 1
	var last_said := md._word_t0(int((spans.back() as Dictionary)["word"])) if not spans.is_empty() else INF
	var text_n := String(a.get("text", "")).length()
	var tail_done := keys[text_n - 1] if not keys.is_empty() else INF
	var panel_up := md._t0[si] + float(md._actions[si]["rest"]) / md._sp[si]
	var first_said := md._word_t0(int(a.get("from", 0)))
	_ok(ti > si and late == 0 and not keys.is_empty() and keys[0] >= panel_up - 0.001 and tail_done < INF and tail_done > last_said
		and tail_done - first_said > 2.0,
		"a key: line the paragraph after says is typed ahead of its words (%d late of %d), after the panel is up, its unsaid end on after the last (%.1f s after it); the control: its first word said %.1f s before the line is typed whole"
			% [late, spans.size(), tail_done - last_said, tail_done - first_said])


## A call held across a black has been on the hours the clock jumped, past midnight, shown with its hours (the control: in
## the show's own time, a minute or two).
func _call_across_black(md: DispatchMedium) -> void:
	var body := "<!-- fade: from-black, 22:40 -->\n\n<!-- speaker: Control -->\n\nOne two three four five six.\n\n<!-- call: VAN -->\n\n" \
		+ "<!-- speaker: Van -->\n\nVan here, on the corner.\n\n<!-- speaker: Control -->\n\nStay on the line all night.\n\n" \
		+ "<!-- fade: to-black -->\n\n<!-- fade: from-black, 06:41 -->\n\nMorning now and he is still there with me.\n"
	md.load_note(body, {"seed": 3})
	md._now = 0.0
	md.take_words(DispatchScript.rehearsal(DispatchScript.parse(body), 0.32))
	var spoken: PackedStringArray = md._parsed["spoken"]
	var late := md._word_t0(spoken.find("morning")) + 1.0
	var secs := md._call_secs("VAN", late)
	var show_secs := late - md._call_began("VAN", late)
	var want := float((6 * 60 + 41 + 24 * 60) - (22 * 60 + 40)) * 60.0
	_ok(secs > want - 120.0 and secs < want + 120.0 and show_secs < 300.0 and DispatchScreens.call_time(int(secs)).count(":") == 2
		and DispatchScreens.call_time(2209) == "36:49",
		"a call held across a black has been on the hours the clock jumped (%s; the control, in the show's own time, %.0f s)"
			% [DispatchScreens.call_time(int(secs)), show_secs])
	# the same reading started past the black: the fades before the start lie in the far past, behind the call's beginning
	var words := DispatchScript.rehearsal(DispatchScript.parse(body), 0.32)
	var k := spoken.find("morning")
	var since := float((words[k] as Dictionary)["t0"])
	var later: Array = []
	for w in words.slice(k):
		var d: Dictionary = (w as Dictionary).duplicate()
		d["t0"] = float(d["t0"]) - since
		d["t1"] = float(d["t1"]) - since
		later.append(d)
	md.load_note(body, {"seed": 3}, spoken.slice(k, k + 8), k, since)
	md._now = 0.0
	md.take_words(later)
	var mid_secs := md._call_secs("VAN", late - since)
	var began := md._call_began("VAN", late - since)
	var raw_fade := md.starts()[_first(md._actions, "fade")]
	_ok(md._follower.start_si == k and absf(mid_secs - secs) < 120.0 and raw_fade < began,
		"a call held across a black, the reading started past it, has been on the hours the clock jumped (%s, whole %s; the control: the fades' own starts lie before the call began, %.0f s against %.0f s)"
			% [DispatchScreens.call_time(int(mid_secs)), DispatchScreens.call_time(int(secs)), raw_fade, began])


## A call's timer after a reading started mid-way, past where the call began: counted from where the call fell on the reading, as a
## whole reading counts it (the control: counted from the far past the call is placed in, it is hours).
func _timer_mid_way(md: DispatchMedium) -> void:
	var body := ("<!-- speaker: Control -->\n\nOne two three four five six seven eight nine ten eleven twelve.\n\n<!-- call: AISLE -->\n\n"
		+ "<!-- speaker: Aisle -->\n\nHello there this is aisle seven and I am standing by the coffee right now.\n\n"
		+ "<!-- speaker: Control -->\n\nGood stay there and keep your eyes on him until I say so.\n\n"
		+ "<!-- speaker: Aisle -->\n\nHe is reading the back of a bag and has not looked up once.\n\n<!-- /call -->\n")
	var parsed := DispatchScript.parse(body)
	var words := DispatchScript.rehearsal(parsed, 0.32)
	var spoken: PackedStringArray = parsed["spoken"]
	var k := spoken.find("good")
	var since := float((words[k] as Dictionary)["t0"])
	var at := float((words[spoken.find("bag")] as Dictionary)["t0"])
	md.load_note(body, {"seed": 3})
	md._now = 0.0
	md.take_words(words)
	var whole_secs := at - md._call_began("AISLE", at)
	var later: Array = []
	for w in words.slice(k):
		var d: Dictionary = (w as Dictionary).duplicate()
		d["t0"] = float(d["t0"]) - since
		d["t1"] = float(d["t1"]) - since
		later.append(d)
	md.load_note(body, {"seed": 3}, spoken.slice(k, k + 8), k, since)
	md._now = 0.0
	md.take_words(later)
	var mid_secs := (at - since) - md._call_began("AISLE", at - since)
	var far_secs := (at - since) - md.starts()[_first(md._actions, "call")]
	_ok(md._follower.start_si == k and whole_secs > 5.0 and absf(mid_secs - whole_secs) < 2.0 and far_secs > 3600.0,
		"a call begun before a mid-way start has run as long as in a whole reading (%.1f s, whole %.1f s; from the far past %.0f s)"
			% [mid_secs, whole_secs, far_secs])


## A note that opens in the black, on a title: the title stands over the blurred desk, the camera home; the picture goes
## down to black as the title goes, the camera on the clock in it; then up on the clock (the control: with no title to
## open on, black from the start).
func _opens_black(st: SubViewport) -> void:
	var body := "<!-- fade: from-black, 22:40 -->\n\n<!-- speaker: Control -->\n\nTwenty to eleven. The quiet hours. Every night at this hour.\n"
	var made := func(opening: String) -> DispatchMedium:
		var feed := ShowFeed.new()
		feed.opening = opening
		var md := DispatchMedium.new()
		md.feed = feed
		md.mount(st)
		md.load_note(body, {"seed": 3})
		md._now = 0.0
		md.take_words(DispatchScript.rehearsal(DispatchScript.parse(body), 0.32, 0.35, 9.0))
		return md
	var titled: DispatchMedium = made.call("title")
	var op := titled._opening()
	var up := titled.starts()[_first(titled._actions, "fade")]
	var shows := ShowOpening.title_alpha("title", op - 2.0, op, true)
	_ok(op < INF and titled.fade_at(op - 2.0) == 0.0 and shows > 0.9 and titled.looking_at(op - 2.0) == "home"
		and titled.fade_at(op + DispatchMedium.BLACK_TAIL + 0.05) == 1.0 and titled.looking_at(up - 0.5) == "clock"
		and titled.fade_at(up + DispatchScript.FADE + 0.05) == 0.0,
		"opening in the black on a title: the title over the blurred desk, then black as it goes, then up on the clock (%.2f under the title, %.2f after)" % [
			titled.fade_at(op - 2.0), titled.fade_at(op + DispatchMedium.BLACK_TAIL + 0.05)])
	var held := titled._pull(op - 0.3, op) == 0.0 and titled._pull(op + DispatchMedium.BLACK_TAIL + 0.05, op) == 1.0
	var usual := ShowOpening.pull("title", op - 0.3, op, true) > 0.0
	_ok(held and usual, "...its blur never lifts on the desk: held as it goes black, gone in the black (the control: a show's usual pull is lifting by then)")
	var plain: DispatchMedium = made.call("none")
	_ok(plain.fade_at(0.5) == 1.0 and plain.fade_at(plain._opening() - 2.0) == 1.0, "the control: with no title to open on, black from the start")
	titled.queue_free()
	plain.queue_free()


## A live reading knows only the words heard so far: after a block, with the next look's words not heard yet, the camera
## holds on for it when it comes soon - the glass again, or the radar - rather than pull back to the whole desk for nothing
## (the control: the next look a long talk away - not held).
func _bridge_live(st: SubViewport, feed: ShowFeed) -> void:
	var talk := "He keeps a log. Of course he keeps a log. He has a column for could be nothing, and he uses it for most of the night. "
	var made := func(next: String, long := false) -> Array:
		var body := ("<!-- speaker: Control -->\n\nHere.\n\n```terminal\n> x\npanel: menu = MENU | NIGHT 1\n  1  SUBJECTS\n```\n\n"
			+ "Forty-one thousand of them on the council's books, and I only have the one.\n\n"
			+ ("\n\n".join(range(12).map(func(_n: int) -> String: return talk)) + "\n\n" if long else "") + next + "\n\nThere.\n")
		var words := DispatchScript.rehearsal(DispatchScript.parse(body), 0.32)
		var md := DispatchMedium.new()
		md.feed = feed
		md.mount(st)
		md.load_note(body, {"seed": 3})
		md._now = 0.0
		md.take_words(words.slice(0, 6))
		var last: Dictionary = md._attn.back() if not md._attn.is_empty() else {}
		var held := float(last.get("t1", 0.0))
		md.queue_free()
		return [String(last.get("kind", "")), held]
	var again: Array = made.call("```terminal\n> 1\npanel: subjects = SUBJECTS\n```")
	var radar: Array = made.call("<!-- look: radar -->")
	var later: Array = made.call("<!-- look: radar -->", true)
	var home: Array = made.call("<!-- look: home -->", true)
	_ok(String(again[0]) == "session" and float(again[1]) == INF and float(radar[1]) == INF and float(later[1]) == INF and float(home[1]) < INF,
		"live, with the next look's words not heard yet, the camera holds on the glass for it, a long talk away too (the control: a look back to the whole desk is not held for - %s, %s, %s, %s)" % [str(again), str(radar), str(later), str(home)])


static func _first(actions: Array, kind: String) -> int:
	for i in actions.size():
		if String((actions[i] as Dictionary)["kind"]) == kind:
			return i
	return -1


## The desk is its number's.
func _layout() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var t := ImageTexture.create_from_image(img)
	var tex := {"tape": t, "chart": t, "spine": t, "dial": t, "GOOD": t, "BAD": t}
	var labels := PackedStringArray(["AISLE", "VAN", "COUGH", "LIGHTS"])
	var flips := {}
	var mugs := {}
	var clear := ""
	var seen := ""
	var arm := ""
	var spine := ""
	var blotter_cross := ""
	var mug_reach := true
	var spots_follow := true
	var ring_ok := true
	var first: Dictionary = {}
	var carried := 0
	var carried_clear := 0
	var carried_low := 0
	var straight_blocked := 0
	for seed in range(1, 41):
		var s := DispatchSet.new()
		var node := s.build(labels, seed, tex, {"clock": true, "tablet": true} if seed % 2 == 0 else {})
		if s.tablet != null:
			# the tablet's way between its place and the hand
			var lies := s.tablet_home
			var hand := s.tablet_held_xf()
			var route := DispatchMedium.tablet_route(s)
			var mid := lies.origin.lerp(hand.origin, 0.5)
			carried += 1
			if s.slab_clear(s.tablet_box, lies, DispatchMedium.tablet_way(lies, hand, route), DispatchMedium.CARRY_GAP, ["tablet"]):
				carried_clear += 1
			if route.y <= hand.origin.y + 0.001:
				carried_low += 1
			if not s.slab_clear(s.tablet_box, lies, DispatchMedium.tablet_way(lies, hand,
					Vector3(mid.x, lies.origin.y + DispatchMedium.TABLET_OVER.x, mid.z)), DispatchMedium.CARRY_GAP, ["tablet"]):
				straight_blocked += 1
		flips[int(s.flip)] = true
		var m: Vector2 = s.at["mug"]
		mugs[snappedf(m.x, 0.01)] = true
		if seed == 1:
			first = s.at.duplicate()
		var keys := s.bodies.keys()
		for i in keys.size():
			for j in range(i + 1, keys.size()):
				if clear.is_empty() and _meet(s, keys[i], keys[j]):
					clear = "%s and %s, desk %d" % [keys[i], keys[j], seed]
		if seen.is_empty():
			seen = _hidden_on(s, seed)
		var panel_rig: PropRig = s.rigs["satellite"]
		var panel := s.bounds_xf(panel_rig.node) * Transform3D(Basis.IDENTITY, (panel_rig.built["size"] as AABB).get_center())
		var to := (DispatchSet.EYE - panel.origin).normalized()
		if arm.is_empty() and (s._arm_fold(panel, s.at_of("satellite")).is_empty() or panel.basis.z.dot(to) < 0.95):
			arm = "desk %d" % seed
		var label: Node3D = (s._faces["handbook"] as Array)[0]
		var spine_xf := s.bounds_xf(label)
		if spine.is_empty() and spine_xf.basis.z.dot((DispatchSet.EYE - spine_xf.origin).normalized()) < 0.5:
			spine = "desk %d" % seed
		if s.bodies.has("chart") and blotter_cross.is_empty():
			var cb: AABB = s.bodies["chart"]
			if Rect2(cb.position.x, cb.position.z, cb.size.x, cb.size.z).intersects(DispatchSet.BLOTTER):
				blotter_cross = "desk %d" % seed
		var inward := DispatchSet.NEAR - m.y
		if inward < 0.24 or inward > 0.42 or absf(m.x) > 0.65:
			mug_reach = false
		if ((s.spots["mug"] as Dictionary)["aim"] as Vector3).distance_to(Vector3(m.x, ((s.spots["mug"] as Dictionary)["aim"] as Vector3).y, m.y)) > 0.001 \
				or signf(((s.spots["radar"] as Dictionary)["aim"] as Vector3).x) != signf((s.at["radar"] as Vector2).x):
			spots_follow = false
		var ring := node.get_node_or_null("CoffeeRing") as MeshInstance3D
		var mat := ring.material_override as StandardMaterial3D if ring != null else null
		if mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or ring.mesh == null or ring.mesh.get_aabb().size.x > 0.11:
			ring_ok = false
		node.free()
	# the keyboard: every key on its case, none past its edge, the rows across most of it
	var probe_set := DispatchSet.new()
	var probe_node := probe_set.build(labels, 2, tex)
	var kb: Node3D = (probe_set.rigs["keyboard"] as PropRig).node
	var case_box := _box_of(kb, ["beige"])
	var keys_box := _box_of(kb, ["key", "key gray"])
	var on_case := keys_box.has_volume() and keys_box.position.x >= case_box.position.x and keys_box.end.x <= case_box.end.x \
		and keys_box.position.z >= case_box.position.z and keys_box.end.z <= case_box.end.z and keys_box.size.x > case_box.size.x * 0.85
	var old_floating := Rect2(Vector2(0.12, -0.074) - Vector2(0.008, 0.007), Vector2(0.081, 0.014))
	_ok(on_case and not Rect2(case_box.position.x, case_box.position.z, case_box.size.x, case_box.size.z).encloses(old_floating),
		"the keyboard's keys are all on its case, across most of it (the control: the old floating keys stood off it) - %s in %s" % [keys_box, case_box])
	probe_node.free()
	var again := DispatchSet.new()
	var again_node := again.build(labels, 1, tex)
	_ok(again.at == first, "the control: the same number is the same desk")
	again_node.free()
	_ok(flips.size() == 2 and mugs.size() >= 4, "across numbers the desk is mirrored both ways and its small things packed elsewhere (%d mug places)" % mugs.size())
	_ok(clear.is_empty(), "no two things on the desk meet, by their own meshes' outlines - the satellite's arm and panel and the printer's paper too (%s)" % clear)
	_ok(seen.is_empty(), "nothing packed hides a label, dial, screen or the clock's cards from the chair, and nothing hides one in its own close-up (%s)" % seen)
	_ok(arm.is_empty(), "the satellite's monitor is held on its arm, turned to the chair (%s)" % arm)
	_ok(spine.is_empty(), "the handbook's spine faces the chair (%s)" % spine)
	_ok(blotter_cross.is_empty(), "the chart is taped down wholly on the desk's own top, never across the blotter (%s)" % blotter_cross)
	_layout_controls(labels, tex)
	_ok(mug_reach, "the mug is at arm's reach, 25 to 40 cm in from the edge, beside the keyboard")
	_ok(carried >= 15 and carried_clear == carried and carried_low * 4 >= carried * 3,
		"the tablet is carried clear of what stands under its way on every desk, on most no higher than the hand holds it (%d desks, %d clear, %d no higher)"
			% [carried, carried_clear, carried_low])
	_ok(straight_blocked > 0, "the control: carried straight and at its least height, something stands in the tablet's way on %d desks" % straight_blocked)
	_ok(spots_follow, "the camera turns to where each thing is")
	_ok(ring_ok, "the old coffee ring is a thin opaque rim, never a clear disc")


## The box the meshes under [param n] made of any of [param mats] fill, in [param n]'s space.
static func _box_of(n: Node3D, mats: Array) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if not String((mi as MeshInstance3D).get_meta("material", "")) in mats:
			continue
		var xf := Transform3D.IDENTITY
		var at: Node = mi
		while at != null and at != n:
			xf = (at as Node3D).transform * xf
			at = at.get_parent()
		var b: AABB = xf * (mi as MeshInstance3D).mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Whether things [param a] and [param b] of desk [param s] meet: any part of one ([method DispatchSet._parts_of]) inside any
## part of the other.
static func _meet(s: DispatchSet, a: String, b: String) -> bool:
	if not (s.bodies[a] as AABB).intersects(s.bodies[b] as AABB):
		return false
	for part in s._parts[a]:
		if DispatchSet._meets(part["outline"], part["lo"], part["hi"], s._parts[b]):
			return true
	return false


## The first face of desk [param s] hidden past what it allows ("" for none): from the chair by a thing packed, or of a thing
## packed by anything; from its own close-up by anything.
static func _hidden_on(s: DispatchSet, seed: int) -> String:
	for k in s._faces:
		if not s.bodies.has(k):
			continue
		var eyes := {"chair": DispatchSet.EYE, "close-up": s.spot_of(k).get("eye", DispatchSet.EYE)}
		for f in s._faces[k]:
			var pts := s._face_points(f, s.bodies[k] if f == s.things.get(k) else null)
			for e in eyes:
				var sg := DispatchSet._sight(pts, eyes[e], k)
				for o in s.bodies:
					if o == k or e == "chair" and not (DispatchSet.PACK.has(o) or DispatchSet.PACK.has(k)):
						continue
					var h := DispatchSet.hidden(s._blocks[o], sg)
					if h > float(sg["most"]) + 0.001:
						return "%s hides %.0f%% of %s from the %s, desk %d" % [o, h * 100.0, k, e, seed]
	return ""


## The layout's measures can fail: the mug set just before the clock hides its cards from the chair; a switch at the foot of
## the radar's face, clear of the footprint the radar was once typed with (32 x 34 cm about its middle), meets the radar.
func _layout_controls(labels: PackedStringArray, tex: Dictionary) -> void:
	var s := DispatchSet.new()
	var node := s.build(labels, 2, tex, {"clock": true})
	var face := s.bounds(s.clock_face)
	var c := face.get_center()
	var toward := Vector2(DispatchSet.EYE.x - c.x, DispatchSet.EYE.z - c.z).normalized()
	var at := Vector2(c.x, c.z) + toward * 0.10
	var blocks: Array = []
	DispatchSet._mesh_boxes(s.mug, Transform3D(s.mug.transform.basis, Vector3(at.x, DispatchSet.DESK_Y, at.y)), blocks)
	var share := DispatchSet.hidden(blocks, DispatchSet._sight(s._face_points(s.clock_face), DispatchSet.EYE, "clock"))
	var radar := s.at_of("radar")
	var facing := Vector2(sin(deg_to_rad(float(s.turn["radar"]))), cos(deg_to_rad(float(s.turn["radar"]))))
	var foot := radar + facing * 0.22
	var sw := Rect2(foot - Vector2(0.045, 0.035), Vector2(0.09, 0.07))
	var typed := Rect2(radar - Vector2(0.16, 0.17), Vector2(0.32, 0.34))
	var outline := PackedVector2Array([sw.position, Vector2(sw.end.x, sw.position.y), sw.end, Vector2(sw.position.x, sw.end.y)])
	var meets := DispatchSet._meets(outline, DispatchSet.DESK_Y, DispatchSet.DESK_Y + 0.055, s._parts["radar"])
	var chart: Node3D = s.things.get("chart")
	var on_blotter := 0.0
	if chart != null:
		var shape := DispatchSet._shape(chart)
		on_blotter = s._misfit("chart", chart, shape, Transform3D(Basis.IDENTITY, Vector3(0.2, DispatchSet.DESK_Y, 0.3)), s.held_rect(),
			Rect2(-0.26, 0.26, 0.52, 0.2), [])
	_ok(on_blotter >= 10000.0, "the control: the chart laid where it once was packed, across the blotter's edge, does not fit (%.0f)" % on_blotter)
	_ok(share > DispatchSet.HIDE_MOST and meets and not typed.intersects(sw),
		"the control: a mug just before the clock hides %.0f%% of its cards; a switch at the radar's face meets it, though the radar's old typed footprint called it clear" % [share * 100.0])
	node.free()


## What the camera turns to ([method DispatchMedium._settled]), on looks made by hand, each against its control: a glance is
## let go of at once, a ping is gone in a second, the camera eases home between two looks at the radar, a swerve toward a
## phone being hung up, a turn away to the receiver and straight back.
func _settling(md: DispatchMedium, radar: Dictionary) -> void:
	var home: Dictionary = md._spot("home")
	var phones: Dictionary = md._spot("phones")
	var term: Dictionary = md._spot("terminal")
	var recv: Dictionary = md._spot("receiver")
	var kept: Array = md._attn
	var on := func(looks: Array, t: float) -> Dictionary:
		md._attn = looks
		return md._attention(t)
	var always := func(looks: Array, spot: Dictionary, from: float, to: float) -> bool:
		md._attn = looks
		var t := from
		while t < to:
			if md._attention(t) != spot:
				return false
			t += 0.25
		return true
	# a glance is held long enough to be seen, then let go of at once
	var glance := {"t0": 0.0, "t1": 1.0, "spot": radar, "linger": DispatchMedium.PING_LINGER}
	var held: Array = md._settled([glance.duplicate()])
	_ok(on.call(held, DispatchMedium.LOOK_LEAST - 0.3) == radar and on.call(held, DispatchMedium.LOOK_LEAST + DispatchMedium.PING_LINGER + 0.5) == home
		and on.call([glance.duplicate()], 1.0 + DispatchMedium.PING_LINGER + 0.5) == home,
		"a look is held %.0f s to be seen, then let go of (the control: as it was, gone after its linger)" % DispatchMedium.LOOK_LEAST)
	# a ping to its hold - and a hold gives way to what begins next, never gone back to
	var ping := {"t0": 0.0, "t1": 3.1, "hold": 8.0, "spot": radar, "linger": DispatchMedium.PING_LINGER}
	var phone := {"t0": 4.0, "t1": 6.0, "spot": phones}
	var never_back := true
	var cut: Array = md._settled([ping.duplicate(), phone.duplicate()])
	for t in [6.5, 7.5, 8.5, 9.5]:
		if on.call(cut, t) == radar:
			never_back = false
	var unyielding: Array = [{"t0": 0.0, "t1": 8.0, "spot": radar}, phone.duplicate()]
	_ok(on.call(md._settled([ping.duplicate()]), 7.5) == radar and on.call([ping.duplicate()], 7.5) == home and never_back
		and on.call(unyielding, 6.5) == radar,
		"a ping holds the radar to its hold, and gives way to what begins next for good (the controls: gone at 7.5 s as it was; a hold that will not give way is gone back to)")
	# the camera stays on the radar from a ping to the walk that follows it, never easing home between
	var walk := [ping.duplicate(), {"t0": 9.0, "t1": 21.0, "spot": radar}]
	walk[0]["hold"] = 0.0
	_ok(always.call(md._settled(walk.duplicate(true)), radar, 0.0, 21.0) and not always.call(walk.duplicate(true), radar, 0.0, 21.0),
		"the camera stays on the radar from a ping to the walk after it, never easing home between (the control: as it was, home and back)")
	# no swerve toward a phone being hung up as the radar pings
	var swerve := [{"t0": 0.0, "t1": 1.3, "spot": phones}, {"t0": 1.0, "t1": 6.0, "spot": radar}]
	_ok(on.call(md._settled(swerve.duplicate(true)), 0.5) != phones and on.call(md._settled(swerve.duplicate(true)), 1.5) == radar
		and on.call(swerve.duplicate(true), 0.5) == phones,
		"a look cut before the camera could get there is not taken (the control: as it was, it swerves to the phones)")
	# no turn away to the receiver and straight back between two typed blocks - but never a typed block passed over
	var exchange := [{"t0": 0.0, "t1": 10.0, "spot": term, "kind": "type"}, {"t0": 10.5, "t1": 14.0, "spot": recv, "kind": "static"},
		{"t0": 14.5, "t1": 30.0, "spot": term, "kind": "type"}]
	var council := [{"t0": 0.0, "t1": 6.0, "spot": recv, "kind": "static"}, {"t0": 6.5, "t1": 10.0, "spot": term, "kind": "type"},
		{"t0": 10.5, "t1": 14.0, "spot": recv, "kind": "static"}]
	_ok(always.call(md._settled(exchange.duplicate(true)), term, 0.0, 30.0) and on.call(exchange.duplicate(true), 12.0) == recv
		and on.call(md._settled(council.duplicate(true)), 8.5) == term,
		"no turn away and straight back for a short look between two at the same thing, and never a typed block passed over (the control: as it was, to the receiver and back)")
	# the camera goes home as it would when home is next: nothing is stretched into it
	var to_home: Array = md._settled([{"t0": 0.0, "t1": 5.0, "spot": radar, "linger": 1.0}, {"t0": 9.0, "t1": 15.0, "spot": home}])
	_ok(float(to_home[0]["t1"]) < maxf(5.0, DispatchMedium.LOOK_LEAST) + 0.01, "a look before the whole desk is not stretched into it, past being seen (%.1f)" % float(to_home[0]["t1"]))
	# the same thing looked at again, even a while later, is one look: held between (the control: two things that far apart are not)
	var twice: Array = md._settled([{"t0": 0.0, "t1": 6.0, "spot": term, "kind": "session"}, {"t0": 40.0, "t1": 50.0, "spot": term, "kind": "session"}])
	var apart: Array = md._settled([{"t0": 0.0, "t1": 6.0, "spot": term, "kind": "session"}, {"t0": 40.0, "t1": 50.0, "spot": radar}])
	_ok(always.call(twice, term, 0.0, 50.0) and on.call(apart, 30.0) == home,
		"two looks at the same thing are bridged, held between them (the control: a look at something else that far off is not - home between)")
	md._attn = kept


## The Environment's ([Surroundings]): with none chosen the hollow is its own; moonlight lights it in the moon's colors with its lamp
## off, twice as bright doubles its exposure, shafts fall in the crack's place, pixies drift and the terminal shines at the share
## asked; candlelight burns candles out of the shot; and with none again the hollow is as it was (the control).
func _environment(md: DispatchMedium) -> void:
	var exposure := md._env.tonemap_exposure
	var own := md._env.ambient_light_color == DispatchMedium.AMBIENT and md._crack.visible and md._rays == null and is_equal_approx(md._lamp_share, 1.0)
	md._surround = Surroundings.sanitize({"elements": [{"kind": "light", "preset": "moonlight", "brightness": 2.0},
		{"kind": "shafts", "count": 4, "inner": 0}, {"kind": "pixies"}], "lights": {"terminal": 0.5}})
	md._dress_environment()
	var moon: Dictionary = Surroundings.LIGHTS["moonlight"]
	var term: PropRig = md._set.rigs.get("terminal")
	_ok(own and md._env.ambient_light_color.is_equal_approx(Color.html(String(moon["ambient"]))) and is_zero_approx(md._lamp_share)
		and is_equal_approx(md._env.tonemap_exposure, exposure * 2.0) and not md._crack.visible and md._rays != null
		and md._rays.get_child_count() == 4 and md._air != null and term != null and is_equal_approx(float(term.get("_light_scale")), 0.5)
		and not md._candles.visible,
		"the hollow is its own with no environment; moonlit, its ambient the moon's and its lamp off, twice as bright (%.2f of %.2f), four shafts for the crack, pixies, the terminal at half"
		% [md._env.tonemap_exposure, exposure])
	var homes: Array = []
	for pop in md._air.motes:
		for mo in (pop as Dictionary)["each"]:
			homes.append((mo as Dictionary)["home"])
	var apart := 0.0
	for a in homes:
		for b in homes:
			apart = maxf(apart, (a as Vector3).distance_to(b as Vector3))
	# the control: placed from a camera put nowhere yet, as it is before the first frame, every mote is in its region's middle
	var nowhere: Variant = Effects.build(Surroundings.effects_of(md._surround, DispatchMedium.FOG), {"regions": {"near": DispatchMedium.AIR_NEAR,
		"far": DispatchMedium.AIR_FAR, "room": DispatchMedium.AIR_ROOM}, "camera": Transform3D.IDENTITY, "fov": 54.0, "aspect": 16.0 / 9.0}, 1)
	var piled := 0.0
	for pop in nowhere.motes:
		for mo in (pop as Dictionary)["each"]:
			piled = maxf(piled, ((mo as Dictionary)["home"] as Vector3).distance_to(DispatchMedium.AIR_NEAR.get_center()))
	nowhere.release()
	_ok(apart > 0.3 and piled < 0.01, "the motes are spread over the desk as the chair sees it (%.2f m apart at most) - the control, placed from a camera put nowhere yet, all in their region's middle (%.3f off it)" % [apart, piled])
	md._surround = Surroundings.sanitize({"elements": [{"kind": "light", "preset": "candlelight"}]})
	md._dress_environment()
	_ok(md._candles.visible and md._candles.light_energy > 0.0 and is_zero_approx(md._lamp_share) and md._rays == null and md._air == null,
		"candlelit, candles burn out of the shot and the lamp is off")
	md._surround = Surroundings.sanitize({})
	md._dress_environment()
	_ok(md._env.ambient_light_color == DispatchMedium.AMBIENT and md._crack.visible and md._rays == null and md._air == null
		and not md._candles.visible and is_equal_approx(md._env.tonemap_exposure, exposure) and is_equal_approx(float(term.get("_light_scale")), 1.0),
		"the control: with none again, the hollow as it was")


## A fade to black is a jump in the story's time: a later fade up with a time turns the cards from a minute before it, never from
## wherever the clock had run to (the control: just before the black it still reads the earlier night's time).
func _clock_skip(st: SubViewport, feed: ShowFeed) -> void:
	var body := ("---\ndesk:\n  phones: [VAN]\n---\n\n<!-- speaker: Control -->\n\n<!-- fade: from-black, 22:40 -->\n\nFirst.\n\n"
		+ "The night goes on and on, and nothing moves out there. ".repeat(12) + "\n\nSit on his lot until I tell you.\n\n"
		+ "<!-- fade: to-black -->\n\n<!-- hesitation: 1.5 -->\n\n<!-- fade: from-black, 00:06 -->\n\nThen.\n")
	var md := DispatchMedium.new()
	md.feed = feed
	md.mount(st)
	md.load_note(body, {"seed": 3})
	md._now = 0.0
	md.take_words(DispatchScript.rehearsal(DispatchScript.parse(body), 0.32))
	var up := -1
	var down := -1
	for i in md._actions.size():
		var a: Dictionary = md._actions[i]
		if String(a["kind"]) == "fade" and not bool(a["to"]):
			up = i
		elif String(a["kind"]) == "fade" and bool(a["to"]):
			down = i
	var turn := md.starts()[up] + float(md._actions[up]["secs"]) / md._sp[up]
	var before := String(md.clock_at(turn - 0.2).get("to", ""))
	var turning: Dictionary = md.clock_at(turn + DispatchScript.CLOCK_TURN * 0.5)
	var earlier := String(md.clock_at(md.starts()[down] - 0.1).get("to", ""))
	_ok(before == "00:05" and String(turning.get("from", "")) == "00:05" and String(turning.get("to", "")) == "00:06" and earlier.begins_with("22:4"),
		"after the black the cards come up at 00:05 and turn to 00:06, never from where the clock had run to (%s, %s; the control, before the black, %s)"
		% [before, str(turning), earlier])
	# a live reading, its end not heard yet: the clock's turns are planned only a little past the last word heard, as the plan is
	# made again with every sentence (the control: the whole reading heard, with a long outro, plans its every minute)
	var all_words := DispatchScript.rehearsal(DispatchScript.parse(body), 0.32)
	md.feed.outro_hold = 1200.0
	md._build_sound()
	var whole := md._clock_turns().size()
	md.take_words(all_words.slice(0, all_words.size() - 2))
	var live := md._clock_turns().size()
	md.feed.outro_hold = ShowFeed.OUTRO_DEFAULT
	_ok(live <= 2 + int(DispatchMedium.CLOCK_AHEAD / 60.0) + 2 and whole > live + 5,
		"live, the clock's turns are planned only a little past the last word heard (%d; the control, the whole reading and a long outro, %d)" % [live, whole])
	md.queue_free()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)

## No root lies where a phone is laid open, on eight desks: the held phones' whole footprint, lids included (control: the strip
## round the bases leaves the lids out). No root goes through the printer's paper or its heap, anywhere along the line its tube is drawn on (control: the same roots grown
## knowing nothing of them go through). No root lying on the desk comes nearer what stands there - the chart taped to it too -
## than it is thick (control: grown knowing nothing of what stands there, into it); each reaches a moderate way across the top
## and goes over the near edge, down clear of the desk's front, or ends on the top.
## The chart lies a hair over the desk's top, never in its plane (control: its make seats its sheet on its own foot). The patch
## panel's cables end in a part of what they plug into or past the desk's edge, go over the roots on the desk (control: laid
## blind) and round what stands on it, through none of it (control: laid straight from socket to port); each plugs into a side
## neither its thing's front nor one the chair sees (control: the side facing the panel, as ports once were, is one of them);
## where two cross on the desk one lies over the other, never through it, but where they bunch leaving the panel (control: pressed
## flat onto the desk, they meet).
func _roots_clear() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var t := ImageTexture.create_from_image(img)
	var tex := {"tape": t, "chart": t, "spine": t, "dial": t, "GOOD": t, "BAD": t}
	var labels := PackedStringArray(["AISLE", "VAN", "COUGH", "LIGHTS"])
	var through := []
	var lid_out := 0
	var paper_through := []
	var paper_blind := 0
	var facing_least := 1.0
	var was_most := -1.0
	var chart_lift := INF
	var chart_seat := 0.0
	var loose_ends := []
	var cable_through := []
	var cable_blind := 0
	var cable_in_things := []
	var straight_in_things := 0
	var in_front := []
	var panel_front := 0
	var crossed := []
	var flat_crossed := 0
	var touching := []
	var touching_blind := 0
	var reach_most := 0.0
	var over_edge := 0
	var on_top := 0
	var hang_wrong := []
	for sd in range(1, 9):
		var ds := DispatchSet.new()
		var node := ds.build(labels, sd, tex)
		var held := ds.held_rect()
		var rr := DispatchRoots.new()
		var rn := rr.build(sd, ds.footprints, held, ds.clear)
		if _in_paper(rr, ds.clear):
			paper_through.append(sd)
		var blind := DispatchRoots.new()
		var bn := blind.build(sd, ds.footprints, held)
		if _in_paper(blind, ds.clear):
			paper_blind += 1
		bn.free()
		# the patch panel's cables: each ends in a thing it plugs into or out of sight past the desk's edge, never loose on the
		# desk; draped over the roots lying there, none goes through one (the control: laid knowing nothing of the roots, they do)
		ds.lay_cables(rr.lying, rr.hanging)
		for path in ds.cable_paths:
			var end: Vector3 = (path as PackedVector3Array)[(path as PackedVector3Array).size() - 1]
			var plugged := end.y < DispatchSet.DESK_Y - 0.1
			for k in DispatchSet.CABLED:
				for part in ds._parts.get(k, []):
					plugged = plugged or ((part as Dictionary)["box"] as AABB).grow(0.002).has_point(end)
			if not plugged:
				loose_ends.append(sd)
			var side := _plugged_side(ds, end)
			if not side.is_empty() and _faces_front(ds, side["k"], side["out"], side["mid"]):
				in_front.append("%s, desk %d" % [side["k"], sd])
		# one cable lies on another where they cross, never through it (the control: pressed flat onto the desk, they meet)
		if _cables_cross(ds, ds.cable_paths, false):
			crossed.append(sd)
		flat_crossed += int(_cables_cross(ds, ds.cable_paths, true))
		# (the control: of each thing's part on the desk, the side facing the panel most)
		var panel_at: Vector3 = ds._desk_pos(ds.at_of("patch"))
		for k in DispatchSet.CABLED:
			var faced := _panel_side(ds, String(k), Vector2(panel_at.x, panel_at.z))
			if not faced.is_empty() and _faces_front(ds, String(k), faced["out"], faced["mid"]):
				panel_front += 1
		# laid round what stands on the desk: no cable lying on it goes through a thing standing there, short of its own port
		# (the control: laid straight from socket to port, as they once were, they do)
		if _cables_in_things(ds, ds.cable_paths, 0.03):
			cable_in_things.append(sd)
		var straight: Array = []
		for path in ds.cable_paths:
			var pp := path as PackedVector3Array
			var line := DispatchSet.sag_path(pp[0], pp[pp.size() - 1], 0.0, DispatchSet.DESK_Y + DispatchSet.CABLE_R, 22)
			for i in line.size():
				if line[i].z >= DispatchSet.FAR:
					line[i].y = DispatchSet.DESK_Y + DispatchSet.CABLE_R
			straight.append(line)
		straight_in_things += int(_cables_in_things(ds, straight, 0.03))
		if _cables_through(ds.cable_paths, rr.lying):
			cable_through.append(sd)
		ds.lay_cables([])
		cable_blind += int(_cables_through(ds.cable_paths, rr.lying))
		# the chart taped flat on the desk lies a hair over its top
		var chart := _foot(ds, "chart")
		if chart.has_area():
			var cf: MeshInstance3D = (ds.rigs["chart"] as PropRig).face("chart")
			var face_y := (_xf_in(cf, node) * cf.get_aabb()).position.y
			chart_lift = minf(chart_lift, face_y - DispatchSet.DESK_Y)
			chart_seat = maxf(chart_seat, absf((_xf_in(cf, ds.rigs["chart"].node) * cf.get_aabb()).position.y))
		for path in rr.lying:
			var pts: PackedVector3Array = path["points"]
			var rad: PackedFloat32Array = path["radii"]
			for k in range(int(path["from"]), pts.size()):
				if held.grow(-rad[k] * 0.5).has_point(Vector2(pts[k].x, pts[k].z)):
					through.append(sd)
					break
			# past where it goes over the near edge it is off the top: out past the front, and down below it by its end
			var off := int(path.get("off", -1))
			if off >= 0:
				for k in range(off, pts.size()):
					if pts[k].z < DispatchSet.NEAR:
						hang_wrong.append(sd)
						break
				if pts[pts.size() - 1].y > DispatchSet.DESK_Y - DispatchRoots.HANG.x + 0.01:
					hang_wrong.append(sd)
		# no root lying on the desk comes nearer what stands there, or where a phone is laid open, than it is thick (the control:
		# grown knowing nothing of what stands there, they lie in it)
		var stood: Array = ds.footprints + [held]
		if _roots_touch(rr, stood):
			touching.append(sd)
		var unseeing := DispatchRoots.new()
		var un_node := unseeing.build(sd, [], Rect2(), ds.clear)
		touching_blind += int(_roots_touch(unseeing, stood))
		un_node.free()
		for o in rr.on_desk:
			reach_most = maxf(reach_most, float(o["reach"]))
			over_edge += int(bool(o["leaves"]))
			on_top += int(not bool(o["leaves"]))
		var lid := ds.held_xf(0) * Vector3(0, 0, -DispatchSet.PHONE.z * 1.4)
		var h := ds.at_of("held")
		var strip := Rect2(Vector2(minf(h.x, h.x + ds.flip * DispatchSet.HELD_STEP * 2.0) - 0.05, h.y - 0.07),
			Vector2(DispatchSet.HELD_STEP * 2.0 + 0.1, 0.16))
		if held.has_point(Vector2(lid.x, lid.z)) and not strip.has_point(Vector2(lid.x, lid.z)):
			lid_out += 1
		# an open phone laid down faces the chair; the control, the turn it once had, faces it far less on the phones' side
		for k in DispatchSet.HELD_SLOTS:
			var xf := ds.held_xf(k)
			var to := Vector2(DispatchSet.EYE.x - xf.origin.x, DispatchSet.EYE.z - xf.origin.z).normalized()
			var front := Vector2(xf.basis.z.x, xf.basis.z.z).normalized()
			var was := Basis(Vector3.UP, deg_to_rad((-22.0 + float(k) * 13.0) * ds.flip)) * Vector3.BACK
			facing_least = minf(facing_least, front.dot(to))
			was_most = maxf(was_most, Vector2(was.x, was.z).normalized().dot(to))
		rn.free()
		node.free()
	_ok(through.is_empty() and lid_out == 8,
		"no root lies where a phone is laid open, its lid with it (the control: the strip round the bases leaves the lid out on %d of 8; through on %s)" % [lid_out, str(through)])
	_ok(touching.is_empty() and touching_blind > 0,
		"no root lying on the desk comes nearer what stands there - the chart taped to it, where a phone is laid open - than it is thick (%s; the control: grown knowing nothing of what stands there, into it on %d of 8)"
		% [str(touching), touching_blind])
	_ok(reach_most <= DispatchRoots.DESK_REACH.y * DispatchRoots.REACH_OVER * 1.2 and over_edge > 0 and on_top > 0 and hang_wrong.is_empty(),
		"a root reaches a moderate way across the top (%.2f m at most), going over the near edge and down clear of the desk's front (%d) or ending on the top (%d) - wrong on %s"
		% [reach_most, over_edge, on_top, str(hang_wrong)])
	_ok(facing_least > 0.98 and was_most < 0.9,
		"an open phone laid on the desk faces the chair (the least %.3f; the control, the turn it once had, at most %.3f)" % [facing_least, was_most])
	_ok(paper_through.is_empty() and paper_blind > 0,
		"no root goes through the printer's paper or its heap (the control: grown knowing nothing of them, through on %d of 8; with them, on %s)" % [paper_blind, str(paper_through)])
	_ok(loose_ends.is_empty() and cable_through.is_empty() and cable_blind > 0,
		"the patch panel's cables end in a part of what they plug into or past the desk's edge, never loose (%s), and go over the roots on the desk, through none (the control: laid knowing nothing of them, through on %d of 8; laid over them, on %s)"
		% [str(loose_ends), cable_blind, str(cable_through)])
	_ok(crossed.is_empty() and flat_crossed > 0,
		"one cable lies over another where they cross, through none on the desk (%s) - the control: pressed flat onto the desk, they meet on %d of 8"
		% [str(crossed), flat_crossed])
	_ok(in_front.is_empty() and panel_front > 0,
		"each plugs in round the back of what it plugs into, never its front nor a side the chair sees (%s) - the control: the side facing the panel is one of them %d times"
		% [str(in_front), panel_front])
	_ok(cable_in_things.is_empty() and straight_in_things > 0,
		"they are laid round what stands on the desk, through none of it (%s) - the control: laid straight from socket to port, through it on %d of 8"
		% [str(cable_in_things), straight_in_things])
	_ok(chart_lift >= DispatchSet.FLAT_LIFT * 0.9 and chart_seat < 0.0002,
		"the chart lies %.2f mm over the desk's top, never in its plane (the control: its make seats its sheet on its own foot, %.2f mm up)"
		% [chart_lift * 1000.0, chart_seat * 1000.0])


## [param n]'s transform in [param top]'s space, walked up its parents: a set built out of any tree.
static func _xf_in(n: Node3D, top: Node3D) -> Transform3D:
	var xf := Transform3D()
	var at: Node = n
	while at != null and at != top:
		if at is Node3D:
			xf = (at as Node3D).transform * xf
		at = at.get_parent()
	return xf


## Whether any of [param paths] (cables) passes through a thing standing on the desk of [param ds] while it lies on the desk's top -
## inside a part's outline from above, between its foot and its top - short of the last [param spare] (m) of its way, where it
## plugs in.
static func _cables_in_things(ds: DispatchSet, paths: Array, spare: float) -> bool:
	for path in paths:
		var pp := path as PackedVector3Array
		var end := pp[pp.size() - 1]
		for i in range(2, pp.size()):
			var p := pp[i]
			if p.z < DispatchSet.FAR or p.y > DispatchSet.DESK_Y + 0.02 or p.y < DispatchSet.DESK_Y or p.distance_to(end) < spare:
				continue
			for k in ds._parts:
				if k == "patch":
					continue
				for part in ds._parts[k]:
					var pd: Dictionary = part
					# (under a part raised on its feet is no way through it)
					if float(pd["lo"]) > DispatchSet.DESK_Y + 0.05 or p.y > float(pd["hi"]) or p.y + DispatchSet.CABLE_R < float(pd["lo"]) \
							or (pd["outline"] as PackedVector2Array).size() < 3:
						continue
					if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), pd["outline"]):
						return true
	return false


## Whether any two of [param paths] (cables) on desk [param ds] come closer on the desk than they are thick - one through the other;
## with [param flat], each pressed flat onto the desk first. Where they leave the patch panel together (within 6 cm of it) and past
## the desk's back edge they bunch, as a bundle does, out of sight.
static func _cables_cross(ds: DispatchSet, paths: Array, flat: bool) -> bool:
	var bundle: AABB = (ds._parts["patch"][0] as Dictionary)["box"]
	bundle = bundle.grow(0.06)
	var chunks: Array = []                # per cable: [[box, from, to]] of ten links each
	var ways: Array = []
	for path in paths:
		var pp := (path as PackedVector3Array).duplicate()
		if flat:
			for i in pp.size():
				pp[i].y = DispatchSet.DESK_Y + DispatchSet.CABLE_R
		ways.append(pp)
		var mine: Array = []
		var i := 0
		while i < pp.size() - 1:
			var j := mini(i + 10, pp.size() - 1)
			var box := AABB(pp[i], Vector3.ZERO)
			for k in range(i, j + 1):
				box = box.expand(pp[k])
			if box.end.y >= DispatchSet.DESK_Y - 0.01:
				mine.append([box.grow(DispatchSet.CABLE_R), i, j])
			i = j
		chunks.append(mine)
	var least := 2.0 * DispatchSet.CABLE_R - 0.0008
	for a in ways.size():
		for b in range(a + 1, ways.size()):
			for ca in chunks[a]:
				for cb in chunks[b]:
					if not (ca[0] as AABB).intersects(cb[0]):
						continue
					var pa: PackedVector3Array = ways[a]
					var pb: PackedVector3Array = ways[b]
					for u in range(int(ca[1]), int(ca[2])):
						for v in range(int(cb[1]), int(cb[2])):
							var st := Rope._closest(pa[u], pa[u + 1], pb[v], pb[v + 1])
							var p := pa[u].lerp(pa[u + 1], st.x)
							if p.y < DispatchSet.DESK_Y - 0.005 or p.z < DispatchSet.FAR or bundle.has_point(p):
								continue
							if p.distance_to(pb[v].lerp(pb[v + 1], st.y)) < least:
								return true
	return false


## The side of a part a cable ending at [param end] is plugged into on desk [param ds]: `{k, out, mid}` - the thing, the way the
## side of its part nearest the end faces (x, z), and the middle of that part's outline; {} where it ends in none.
static func _plugged_side(ds: DispatchSet, end: Vector3) -> Dictionary:
	for k in DispatchSet.CABLED:
		for part in ds._parts.get(k, []):
			var pd: Dictionary = part
			if not (pd["box"] as AABB).grow(0.002).has_point(end) or (pd["outline"] as PackedVector2Array).size() < 3:
				continue
			var hull: PackedVector2Array = pd["outline"]
			var at := Vector2(end.x, end.z)
			var mid := Vector2.ZERO
			for q in hull:
				mid += q
			mid /= float(hull.size())
			var best := INF
			var out := Vector2.ZERO
			for i in hull.size():
				var a: Vector2 = hull[i]
				var b: Vector2 = hull[(i + 1) % hull.size()]
				if a.distance_to(b) < 0.001:
					continue
				var d := at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b))
				if d < best:
					best = d
					out = Vector2(b.y - a.y, a.x - b.x).normalized()
					if out.dot((a + b) * 0.5 - mid) < 0.0:
						out = -out
			return {"k": String(k), "out": out, "mid": mid}
	return {}


## Of thing [param k]'s lowest part on desk [param ds], the side facing [param panel] most: `{out, mid}` ({} for none).
static func _panel_side(ds: DispatchSet, k: String, panel: Vector2) -> Dictionary:
	var parts: Array = (ds._parts.get(k, []) as Array).filter(func(p: Dictionary) -> bool:
		return float(p["lo"]) >= DispatchSet.DESK_Y - 0.02 and (p["outline"] as PackedVector2Array).size() >= 3)
	if parts.is_empty():
		return {}
	parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["box"] as AABB).get_volume() > (b["box"] as AABB).get_volume())
	var hull: PackedVector2Array = parts[0]["outline"]
	var mid := Vector2.ZERO
	for q in hull:
		mid += q
	mid /= float(hull.size())
	var toward := (panel - mid).normalized()
	var best := -INF
	var out := Vector2.ZERO
	for i in hull.size():
		var a: Vector2 = hull[i]
		var b: Vector2 = hull[(i + 1) % hull.size()]
		if a.distance_to(b) < 0.001:
			continue
		var n := Vector2(b.y - a.y, a.x - b.x).normalized()
		if n.dot((a + b) * 0.5 - mid) < 0.0:
			n = -n
		if n.dot(toward) > best:
			best = n.dot(toward)
			out = n
	return {"out": out, "mid": mid}


## Whether a side facing [param out] (x, z) of thing [param k] on desk [param ds], whose part's middle is [param mid], is its front
## or faces the chair ([constant DispatchSet.PORT_FRONT]).
static func _faces_front(ds: DispatchSet, k: String, out: Vector2, mid: Vector2) -> bool:
	var rig: PropRig = ds.rigs.get(k)
	if rig == null:
		return false
	var z := rig.node.transform.basis.z
	var seen := (Vector2(DispatchSet.EYE.x, DispatchSet.EYE.z) - mid).normalized()
	return out.dot(Vector2(z.x, z.z).normalized()) > DispatchSet.PORT_FRONT + 0.01 or out.dot(seen) > DispatchSet.PORT_FRONT + 0.01


## Whether any of [param paths] (cables) passes inside a root of [param lying] on the desk's top - within its radius of its middle.
static func _cables_through(paths: Array, lying: Array) -> bool:
	for path in paths:
		for p in (path as PackedVector3Array):
			if (p as Vector3).z < DispatchSet.FAR:
				continue
			for root_path in lying:
				var pts: PackedVector3Array = (root_path as Dictionary)["points"]
				var rad: PackedFloat32Array = (root_path as Dictionary)["radii"]
				for j in range(int((root_path as Dictionary).get("from", 0)), pts.size()):
					if (p as Vector3).distance_to(pts[j]) < rad[j]:
						return true
	return false


## Thing [param k]'s footprint on the desk of [param ds] (x, z): its parts' boxes, merged; empty where the desk has none.
static func _foot(ds: DispatchSet, k: String) -> Rect2:
	var foot := Rect2()
	if not ds.at.has(k):
		return foot
	for part in ds._parts.get(k, []):
		var b: AABB = (part as Dictionary)["box"]
		var r := Rect2(b.position.x, b.position.z, b.size.x, b.size.z)
		foot = r if not foot.has_area() else foot.merge(r)
	return foot


## Whether a root of [param rr] lying on the desk's top comes nearer one of [param stood] (Rect2s in x, z) than it is thick there.
static func _roots_touch(rr: DispatchRoots, stood: Array) -> bool:
	for path in rr.lying:
		var pts: PackedVector3Array = path["points"]
		var rad: PackedFloat32Array = path["radii"]
		var end := int(path.get("off", -1))
		for k in range(int(path["from"]), pts.size() if end < 0 else end):
			var p := Vector2(pts[k].x, pts[k].z)
			for f in stood:
				var rect: Rect2 = f
				var away := Vector2(maxf(maxf(rect.position.x - p.x, p.x - rect.end.x), 0.0), maxf(maxf(rect.position.y - p.y, p.y - rect.end.y), 0.0))
				if away.length() < rad[k] - 0.001:
					return true
	return false


## Whether any root of [param rr] (off the desk's top or on it) has a point inside one of [param boxes].
static func _in_paper(rr: DispatchRoots, boxes: Array) -> bool:
	for path in rr.hanging + rr.lying:
		# along the line its tube is drawn on (smoothed once, as the mesh is), every centimeter - not only at its points
		var pts: PackedVector3Array = (path as Dictionary)["points"]
		var n := pts.size()
		var drawn := PackedVector3Array()
		for i in n:
			drawn.append(pts[i] if i == 0 or i == n - 1 else (pts[i - 1] + pts[i] * 2.0 + pts[i + 1]) * 0.25)
		for i in n - 1:
			var steps := maxi(1, ceili(drawn[i].distance_to(drawn[i + 1]) / 0.01))
			for k in steps + 1:
				var q := drawn[i].lerp(drawn[i + 1], float(k) / float(steps))
				for b in boxes:
					if (b as AABB).grow(-0.002).has_point(q):
						return true
	return false
