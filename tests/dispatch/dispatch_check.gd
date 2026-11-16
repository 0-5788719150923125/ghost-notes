extends SceneTree

## Gate for the dispatch desk ([DispatchMedium], next/dispatch.md), mounted headless and played on a steady voice over
## tests/fixtures/dispatch_note.md ([method DispatchScript.rehearsal]). It holds:
##
## - actions fit the voice's rests: each placed and done before the next word; two pings a hesitation apart stay apart;
## - phones: the one called is at the ear while its voice speaks, the previous one laid open, picked back up, all back at the end;
## - the desk is seen first: nothing happens and the camera stays home through the opening rest;
## - the terminal: dark until a block wakes it to its command line; a command typed there a key at a time and cleared as the
##   panel it opens comes up, the header at once and the body a line at a time; redacted words are one run on their row,
##   hidden over the frame by one box round them as the camera sees them, and covered whole from their first key; a typed
##   line is said behind its keys under the panel up; a strike removes it; after a block the camera stays on the glass while
##   the voice talks of it and through to what comes soon, going home only when nothing comes for long;
## - the black and the clock: fades down and up; in the black the camera is on the clock, its cards turned over to the time
##   given and running on a minute a minute; what is marked in the black is unseen; no track is drawn across it; a note
##   opening in the black shows its title over the blurred desk first, going black as the title goes (control: no title,
##   black from the start);
## - the tablet: picked up before the eye and put down dark; an address typed into its bar, a link on the page tapped; a
##   page following the words said on it, else easing down; its player dark until the desk is played live into it;
## - a clip: the screen's static until it is imported, then its frames looping;
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
## - the roots: some on the desk, grown further at the end than at the start, none under an open phone or its lid;
## - the desk is its number's: the same number is the same desk, across numbers it is mirrored and packed differently, nothing
##   on anything standing, the mug 25-40 cm in from the edge beside the keyboard; the keyboard is a standard layout (every
##   row fifteen units) with every key on its case;
## - the mug is drunk from: upright, brought to the mouth and out of the picture for the sip, back in its ring;
## - the gain knob turns from three to nine a click a step with the camera on the radar: at three only the target is on the
##   scope, at nine the clutter round it and the chair's own on the desk (not at eight), each blip painted once the sweep
##   has passed it; turned back, they fade;
## - the bell rings as the block after it goes up, an alert beeps; the lamp goes out at its click, the camera on the whole desk;
## - a seed changed while the note plays draws a new desk and keeps the reading's place (control: changed words load again);
## - built on a worker, as the app builds it: the show is held until it lands.
##
## Run: godot --headless --path . --script tests/dispatch/dispatch_check.gd

const FIXTURE := "res://tests/fixtures/dispatch_note.md"

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
	var curve := float(DispatchMedium.TERMINAL_GLASS["curve"])
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
				> maxf(DispatchMedium.PING_HOLD_MOST, DispatchMedium.LOOK_LEAST) + 0.5 or float(wd.get("linger", DispatchMedium.HOME_AFTER)) > 1.5)):
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
		"the answer is typed under it as it is said, and sent (%s / %s)" % [str(half_r), str(after_r)])
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
	var bell_block := _first(actions, "bell") + 1
	_gain_bell_lamp(md, actions, t0, plan_r, bell_block)
	_black_tablet_clip(md, actions, t0, plan_r, st)
	_receiver(st, md.feed)
	_glass_hold(st, md.feed)
	_opens_black(st)
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
	var frames := 0
	while away._set == null and frames < 900:
		away.advance(null, 0.016, 1.0)
		await process_frame
		frames += 1
	DispatchMedium.away_in_tests = false
	_ok(on_worker and away._set != null and not away._waiting and away._roots.on_desk.size() >= 2,
		"in the app the desk is built on a worker, the show held until it lands (%d frames)" % frames)
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
	var knob_at := md._set.gain_knob.rotation.z
	md._pose(t0[up] - 0.2)
	var knob_was := md._set.gain_knob.rotation.z
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
	_ok(is_equal_approx(lit_before, DispatchSet.LAMP_ENERGY) and md.lamp_at(click + DispatchMedium.LAMP_FADE * 0.3) < 1.0 and dark and clicked == 1
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


## The camera on the terminal: after a block it stays on the glass while the voice talks of what is up, and through to
## what comes next when that is soon, rather than pull back to the whole desk for nothing; with nothing coming for long,
## it goes home in the end (the controls: a block's look as it was, home within seconds; the same note talked on long).
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
	_ok(stays and look - done > DispatchMedium.GLASS_LEAST and old_home and far.looking_at(f_done + 4.0) == "terminal"
		and far.looking_at(f_look - 3.0) == "home",
		"after a block the camera stays on the glass while the voice talks of it, on to what comes next when that is soon, and goes home when nothing comes for long (the controls: as it was, home by %.0f s; talked on, home before the look) - %s %.1f %s %s %s" % [DispatchMedium.HOME_AFTER + 5.0,
			stays, look - done, old_home, far.looking_at(f_done + 4.0), far.looking_at(f_look - 3.0)])
	near.queue_free()
	far.queue_free()


## The black and the clock, the tablet and a clip, on the fixture's night.
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
	var flips := heard.filter(func(x: Dictionary) -> bool: return String(x.get("what", "")) == "detent" and float(x["t"]) > turn and float(x["t"]) < turn + 1.0).size()
	var held_t := t0[up] + float(actions[up]["rest"]) / md._sp[up]
	_ok(md.looking_at(black0 + 0.5) == "clock" and md.looking_at(turn + 0.3) == "clock" and md.looking_at(held_t + 1.5) != "clock" and flips == 2,
		"in the black the camera is on the clock, held while two cards turn and a beat, then eases away (%s, %s, %d flips)" % [md.looking_at(turn + 0.3), md.looking_at(held_t + 1.5), flips])
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
	var in_hand := md._set.tablet.global_transform.origin.distance_to(md._cam.global_position) < 0.4
	md._pose(md._end_of(tab_down) + 0.2)
	var home := md._set.tablet.global_transform.origin.distance_to(md._set.tablet_home.origin) < 0.001
	var off := float(md.tablet_at(md._end_of(tab_down) + 0.2)["face"]["power"]) == 0.0
	_ok(in_hand and home and off and float(md.tablet_at(t0[tab_up] - 0.1)["face"]["power"]) == 0.0 and md.looking_at(held + 2.0) == "tablet",
		"the tablet is picked up before the eye, its screen woken, and put back down dark")
	var pages: Array = []
	for i in actions.size():
		if String(actions[i]["kind"]) == "page":
			pages.append(i)
	var p1 := int(pages[0])
	var p2 := int(pages[1])
	var pt1 := md._page_times(p1)
	var typing: Dictionary = md.tablet_at((pt1["keys"] as PackedFloat32Array)[4] + 0.01)["face"]
	var first_up: Dictionary = md.tablet_at(float(pt1["shown"]) + 0.1)["face"]
	_ok(String(typing["url"]) == "forum" and bool(typing.get("typing", false)) and first_up.get("page") != null and String(first_up["url"]) == "forum.board",
		"a page's address is typed into the bar a key at a time, then the page comes up (%s)" % String(typing["url"]))
	var pt2 := md._page_times(p2)
	var tapping: Dictionary = md.tablet_at(float(pt2["tap"]) + 0.1)["face"]
	var second_up: Dictionary = md.tablet_at(float(pt2["shown"]) + 0.1)["face"]
	_ok(String(md._actions[p2]["how"]) == "tap" and tapping.has("tap") and float(tapping["tap_u"]) >= 0.0 and tapping.get("page") == first_up.get("page")
		and second_up.get("page") != first_up.get("page") and String(second_up["url"]) == "forum.board/t/headlights",
		"the next page is found on the one up and tapped, then it comes up")
	var follow := md._page_follow(p1, float(DispatchScreens.TABLET_SIZE.y) - DispatchScreens.BAR_H, 99999.0)
	var drift0 := md._page_scroll(p2, float(pt2["shown"]) + DispatchScript.TABLET_LOOK + 0.5)
	var drift1 := md._page_scroll(p2, md._page_end(p2) - 0.5)
	_ok(not follow.is_empty() and drift1 > drift0, "a page follows the words said that are on it, and with none, eases down (%d words followed, %.0f to %.0f px)" % [follow.size(), drift0, drift1])
	var live_i := -1
	for i in actions.size():
		if String(actions[i]["kind"]) == "live" and String(actions[i]["screen"]) == "tablet":
			live_i = i
	var player := Manuscript.image_key(DispatchMedium.PLAYER)
	md._now = t0[live_i] - 0.05
	var dark_player := md._page_tex(player)
	md._now = t0[live_i] + 0.5
	var live_player := md._page_tex(player)
	_ok(dark_player != null and dark_player != md._live_vp.get_texture() and live_player == md._live_vp.get_texture(),
		"the page's player is dark until the desk is played live into it")
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
	var plain: DispatchMedium = made.call("none")
	_ok(plain.fade_at(0.5) == 1.0 and plain.fade_at(plain._opening() - 2.0) == 1.0, "the control: with no title to open on, black from the start")
	titled.queue_free()
	plain.queue_free()


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
	var packed_clear := true
	var mug_reach := true
	var spots_follow := true
	var ring_ok := true
	var first: Dictionary = {}
	for seed in range(1, 9):
		var s := DispatchSet.new()
		var node := s.build(labels, seed, tex)
		flips[int(s.flip)] = true
		var m: Vector2 = s.at["mug"]
		mugs[snappedf(m.x, 0.01)] = true
		if seed == 1:
			first = s.at.duplicate()
		var n_big := s.footprints.size() - 6
		for i in range(n_big, s.footprints.size()):
			for j in s.footprints.size():
				if i != j and (s.footprints[i] as Rect2).intersects(s.footprints[j] as Rect2):
					packed_clear = false
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
	# the keyboard: a standard layout (every row fifteen units) with every key on its case, none past its edge
	var rows_ok := true
	for row in DispatchSet.KEY_ROWS:
		var units := 0.0
		for k in row:
			units += float((k as Array)[0])
		if not is_equal_approx(units, 15.0):
			rows_ok = false
	var probe_set := DispatchSet.new()
	var probe_node := probe_set.build(labels, 2, tex)
	var keys_mi := probe_node.get_node_or_null("Keyboard").find_child("Keys", true, false) as MeshInstance3D
	var case_w := DispatchSet.KEY_U * 15.0 + 0.026
	var case_d := DispatchSet.KEY_U * 5.0 + 0.042
	var keys_box := keys_mi.mesh.get_aabb() if keys_mi != null else AABB()
	keys_box.position += keys_mi.position if keys_mi != null else Vector3.ZERO
	var on_case := keys_mi != null and keys_box.position.x >= -case_w * 0.5 and keys_box.end.x <= case_w * 0.5 \
		and keys_box.position.z >= -case_d * 0.5 and keys_box.end.z <= case_d * 0.5 and keys_box.size.x > case_w * 0.85
	var old_floating := Rect2(Vector2(0.12, -0.074) - Vector2(0.008, 0.007), Vector2(0.081, 0.014))
	_ok(rows_ok and on_case and not Rect2(-case_w * 0.5, -case_d * 0.5, case_w, case_d).encloses(old_floating),
		"the keyboard is a standard layout, every row fifteen units, its keys all on its case (the control: the old floating keys stood off it) - %s" % keys_box)
	probe_node.free()
	var again := DispatchSet.new()
	var again_node := again.build(labels, 1, tex)
	_ok(again.at == first, "the control: the same number is the same desk")
	again_node.free()
	_ok(flips.size() == 2 and mugs.size() >= 4, "across numbers the desk is mirrored both ways and its small things packed elsewhere (%d mug places)" % mugs.size())
	_ok(packed_clear, "nothing packed stands on anything standing")
	_ok(mug_reach, "the mug is at arm's reach, 25 to 40 cm in from the edge, beside the keyboard")
	_ok(spots_follow, "the camera turns to where each thing is")
	_ok(ring_ok, "the old coffee ring is a thin opaque rim, never a clear disc")


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
		and on.call([glance.duplicate()], 2.5) == home,
		"a look is held %.0f s to be seen, then let go of (the control: as it was, gone at 2.5 s)" % DispatchMedium.LOOK_LEAST)
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
	_ok(float(to_home[0]["t1"]) < 5.01, "a look before the whole desk is not stretched into it (%.1f)" % float(to_home[0]["t1"]))
	md._attn = kept


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)

## No root lies where a phone is laid open, on eight desks: the held phones' whole footprint, lids included (control: the strip
## round the bases leaves the lids out).
func _roots_clear() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var t := ImageTexture.create_from_image(img)
	var tex := {"tape": t, "chart": t, "spine": t, "dial": t, "GOOD": t, "BAD": t}
	var labels := PackedStringArray(["AISLE", "VAN", "COUGH", "LIGHTS"])
	var through := []
	var lid_out := 0
	for sd in range(1, 9):
		var ds := DispatchSet.new()
		var node := ds.build(labels, sd, tex)
		var held := ds.held_rect()
		var rr := DispatchRoots.new()
		var rn := rr.build(sd, ds.footprints, held)
		for path in rr.lying:
			var pts: PackedVector3Array = path["points"]
			var rad: PackedFloat32Array = path["radii"]
			for k in range(int(path["from"]), pts.size()):
				if held.grow(-rad[k] * 0.5).has_point(Vector2(pts[k].x, pts[k].z)):
					through.append(sd)
					break
		var lid := ds.held_xf(0) * Vector3(0, 0, -DispatchSet.PHONE.z * 1.4)
		var h := ds.at_of("held")
		var strip := Rect2(Vector2(minf(h.x, h.x + ds.flip * DispatchSet.HELD_STEP * 2.0) - 0.05, h.y - 0.07),
			Vector2(DispatchSet.HELD_STEP * 2.0 + 0.1, 0.16))
		if held.has_point(Vector2(lid.x, lid.z)) and not strip.has_point(Vector2(lid.x, lid.z)):
			lid_out += 1
		rn.free()
		node.free()
	_ok(through.is_empty() and lid_out == 8,
		"no root lies where a phone is laid open, its lid with it (the control: the strip round the bases leaves the lid out on %d of 8; through on %s)" % [lid_out, str(through)])
