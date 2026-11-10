extends SceneTree

## Gate for THE DISPATCH DESK ([DispatchMedium], next/dispatch.md), mounted headless and played through on a steady voice
## over tests/fixtures/dispatch_note.md ([method DispatchScript.rehearsal]):
##
## - THE ACTIONS FIT THE VOICE'S RESTS: every action placed, each done before the word after it, two pings a hesitation
##   apart kept a hesitation apart;
## - THE PHONES: the one called at the ear while its voice speaks, the one before it laid open on the desk, picked back up,
##   and every one back in its row at the end;
## - THE DESK IS SEEN FIRST: nothing happens and the camera stays home through the opening rest;
## - THE TERMINAL: asleep (dark) until a block wakes it; A SESSION wakes it to a bare prompt, each command typed a key at a
##   time and its answer printed after it, the prompt back at the end; a shown block drawn down a line at a time (the
##   control: just begun, its last line is not there yet), its redacted words under a mosaic's rect and nowhere as written
##   (the control: its plain lines have none); a typed block SAID BEHIND ITS KEYS - its first words typed before
##   the voice begins (the control: the rest not yet), every word's keys done before the voice says it; struck, it is gone;
## - THE CAMERA turns to what is active (the terminal while it types, the receiver in a storm, a ringing phone) and a look
##   holds it while nothing else is; THE RADAR: the target sets off at a moving mark and arrives at a ping, under the voice,
##   the sweep painting him a small step on each round - never a jump (THE CONTROL: the two places are well apart) - the
##   place he left written beside him until he arrives; the radar's alarm as he sets off turns the camera to it, and the
##   camera goes to the radar only at its sounds, never to watch it do nothing; THE RECEIVER is open only in its storm;
## - A TEXT IS READ ON ITS PHONE: a chime, the phone up before the eye, the message on its screen and never captioned; the
##   answer typed under it as it is said, and sent; the phone home after. A CALL IS SPEED-DIALED: 1 held, Send, the ear;
## - THE CAPTIONS: a typed word is read on the terminal, not captioned; a spoken line is;
## - A LIVE READING: words arriving a sentence at a time, an action begun keeps its start when the plan is made again;
## - THE ROOTS: some on the desk, and grown further at the end of the night than at its start; none where a phone is laid
##   open, its lid with it (the control: the strip round the bases it had been leaves the lid out);
## - THE DESK IS ITS NUMBER'S: the same number is the same desk (THE CONTROL), and across numbers it is mirrored both ways and
##   its small things packed elsewhere - never onto anything standing, the mug at arm's reach (25-40 cm in from the edge,
##   beside the keyboard), the camera turning to where each thing is; the old coffee ring a thin opaque rim, never a clear disc;
##   THE KEYBOARD a standard layout (every row fifteen units), every key on its case (THE CONTROL: the old ones stood off it);
## - THE MUG IS DRUNK FROM: upright all the way, brought to the mouth and out of the picture for the sip, in its ring before;
## - BUILT ON A WORKER, as the app builds it (half a second, on the main thread a hitch): the show held until it lands.
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
	# THE ACTIONS FIT THE VOICE'S RESTS
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
	# THE PHONES, at the words their voices say
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
	# THE TERMINAL
	_ok(bool(md.terminal_at(0.5)["asleep"]), "the terminal opens asleep, dark")
	_ok(t0[0] >= DispatchScript.OPENING and md.looking_at(t0[0] - 1.0) == "home",
		"THE DESK IS SEEN FIRST: nothing before the opening rest is over, the camera home (%.1f s)" % t0[0])
	var session_i := _first(actions, "session")
	var plan: Dictionary = actions[session_i]["plan"]
	var s1: Dictionary = plan["steps"][1]
	var s0 := t0[session_i]
	var woke := "\n".join(md.terminal_at(s0 + float(plan["steps"][0]["prompt"]) + 0.05)["lines"])
	var keys: PackedFloat32Array = s1["keys"]
	var typing := "\n".join(md.terminal_at(s0 + keys[5] + 0.01)["lines"])
	var answered := "\n".join(md.terminal_at(s0 + float(s1["lines"][0]) + 0.01)["lines"])
	var after := "\n".join(md.terminal_at(s0 + float(plan["prompt"]) + 0.05)["lines"])
	_ok(bool(md.terminal_at(s0 - 0.1)["asleep"]) and woke == DispatchScript.PROMPT, "a session wakes the terminal to a bare prompt (%s)" % woke)
	_ok(typing.ends_with("> search") and not typing.contains("1 MATCH"), "a command is typed a key at a time, unanswered yet (%s)" % typing.replace("\n", " / "))
	_ok(answered.ends_with("> search subject\n1 MATCH") and after.ends_with("> open 1\n" + DispatchScript.PROMPT),
		"its answer is printed after it, and the prompt comes back at the end (%s)" % after.replace("\n", " / "))
	_ok(md.looking_at(s0 + keys[5]) == "terminal", "the camera is on the terminal through a session (%s)" % md.looking_at(s0 + keys[5]))
	var screen_i := _first(actions, "screen")
	var begun := "\n".join(md.terminal_at(t0[screen_i] + 0.01)["lines"])
	var shown := md.terminal_at(t0[screen_i] + 1.0)
	_ok(not bool(shown["asleep"]) and "\n".join(shown["lines"]).contains("STATUS ...... CONTAINED") and begun.contains("NAME ...") and not begun.contains("STATUS"),
		"a shown block is drawn down the glass a line at a time (the control, just begun: %s)" % begun.replace("\n", " / "))
	var shown_lines: PackedStringArray = shown["lines"]
	var covers: Array = md._screens.redactions(shown_lines)
	var plates := shown_lines.slice(shown_lines.size() - 1)
	_ok(covers.size() == 1 and not "\n".join(shown_lines).contains("XKC") and String(DispatchScript.unredacted(plates[0])["text"]).ends_with("XKC 4417")
		and (covers[0] as Rect2).get_center().y > DispatchScreens.TERM_MARGIN.y + DispatchScreens.TERM_LINE * float(shown_lines.size() - 2),
		"a shown block's redacted words lie under a mosaic on their own line, and nowhere as written (%d rects)" % covers.size())
	_ok(md._screens.redactions(PackedStringArray(["NAME ........ SUBJECT", "STATUS ...... CONTAINED"])).is_empty(),
		"the control: plain lines have no mosaic")
	var type_i := _first(actions, "type")
	var ty: Dictionary = actions[type_i]
	var mid := int(ty["from"]) + 2
	var halfway := "\n".join(md.terminal_at(at.call(int(ty["from"])) + 0.05)["lines"])
	var done := "\n".join(md.terminal_at(at.call(int(ty["to"]) - 1) + 1.0)["lines"])
	_ok(halfway.contains("23:21. Grocery") and not halfway.contains("Watcher"),
		"the first words are typed before the voice begins (the control: the rest is not typed all at once - %s)" % halfway.replace("\n", " / "))
	_ok(done.contains("Watcher in place."), "a typed block is typed out by its last word (%s)" % done.replace("\n", " / "))
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
	_ok(before_strike.contains("WHAT DO WE DO") and not gone.contains("WHAT DO WE DO"), "a strike backspaces the block off the screen")
	# THE CAMERA, THE RADAR, THE RECEIVER
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
	# THE CAMERA GOES TO THE RADAR ONLY AT ITS SOUNDS: every look at it begins as it pings or sounds its alarm (or a look
	# mark asks), and none stays to watch it do nothing - a ping held to its sentence's end at most, a walk to the ping where
	# he arrives; either runs on only into the next look (the camera stays rather than easing home to turn straight back)
	var radar_spot: Dictionary = md._spot("radar")
	var at_sounds := true
	for w in md._attn:
		var wd: Dictionary = w
		if wd["spot"] != radar_spot:
			continue
		var from := ""
		for i in actions.size():
			if absf(t0[i] - float(wd["t0"])) < 0.01 and String(actions[i]["kind"]) in ["ping", "moving", "sound", "look"]:
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
	# A PING IS HELD: from its ring PING_HOLD at least, to a sentence's end within PING_HOLD_MOST
	var pings_held := true
	for i in actions.size():
		if String(actions[i]["kind"]) == "ping" and t0[i] < INF:
			var hold := md._ping_hold(i) - t0[i]
			if hold < DispatchMedium.PING_HOLD - 0.01 or hold > DispatchMedium.PING_HOLD_MOST + 0.31:
				pings_held = false
	_ok(pings_held, "every ping holds the radar at least %.0f s, to the end of a sentence within %.0f s" % [DispatchMedium.PING_HOLD, DispatchMedium.PING_HOLD_MOST])
	_settling(md, radar_spot)
	# THE MUG IS DRUNK FROM: upright all the way, brought to the mouth and out of the picture, then home in its ring
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
	# A REAL SIP, UNHURRIED: at the mouth from the end of its rise to the end of its hold - at least 2.5 s - after a rise of
	# 1.5 s at least, and the voice silent until the sip is done (THE CONTROL: before its rise is over it is not there yet)
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
	# PASSING THROUGH: a moving straight after a ping sounds no alarm and turns no camera
	var pass_i := -1
	for i in actions.size():
		if String(actions[i]["kind"]) == "moving" and bool(actions[i].get("passing", false)):
			pass_i = i
	var pass_alarm := heard.filter(func(x: Dictionary) -> bool: return String(x.get("what", "")) == "alarm" and absf(float(x["t"]) - t0[pass_i]) < 0.01).size()
	var pass_look := md._attn.filter(func(w: Dictionary) -> bool: return absf(float(w["t0"]) - t0[pass_i]) < 0.01 and w["spot"] == radar_spot).size()
	_ok(pass_i >= 0 and pass_alarm == 0 and pass_look == 0, "passing through a place on the way, the radar sounds no alarm and the camera stays (%d, %d)" % [pass_alarm, pass_look])
	_ok(float(md.storm_at(t0[static_i] + 1.0).get("level", 0.0)) > 0.0 and md.storm_at(md._end_of(static_i) + 0.5).is_empty(),
		"the receiver is open only in its storm")
	# A TEXT IS READ ON ITS PHONE: a chime, the phone up before the eye and open, the message on its screen - and no caption
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
	# SPEED DIAL: up before the eye, 1 held, Send, then to the ear
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
	# THE CAPTIONS
	md._follower.extend(words)
	_ok(not md._captioned(mid, mid, 0.0) and md._captioned(hello, hello, 0.0), "a typed word is captioned, or a spoken one is not")
	# A LIVE READING
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
	# THE ROOTS
	_ok(md._roots.on_desk.size() >= 2 and DispatchRoots.grown(end_t + 2000.0) > DispatchRoots.grown(0.0),
		"roots reach onto the desk, and grow through the night (%d on the desk)" % md._roots.on_desk.size())
	# BUILT ON A WORKER, as the app builds it: the show held, the desk put in as it lands
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


static func _first(actions: Array, kind: String) -> int:
	for i in actions.size():
		if String((actions[i] as Dictionary)["kind"]) == kind:
			return i
	return -1


## THE DESK IS ITS NUMBER'S.
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
	# THE KEYBOARD: a standard layout - every row fifteen units - and every key on its case, none off its edge (THE
	# CONTROL: the old four keys stood past the case's back)
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


## WHAT THE CAMERA TURNS TO IS SEEN ([method DispatchMedium._settled]), on looks made by hand - each against its control, the
## same looks as they were before (a glance let go of at once, a ping gone in a second, the camera eased home between two
## looks at the radar, a swerve toward a phone being hung up, a turn away to the receiver and straight back).
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
	# 0040: the camera stays on the radar from a ping to the walk that follows it, never easing home between
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

## NO ROOT LIES WHERE A PHONE IS LAID OPEN (feedback 0038: "This phone is clipping through the root here"), on eight desks:
## the held phones' whole footprint, lids and all - the control, the strip round the bases it had been, leaves the lids out.
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
