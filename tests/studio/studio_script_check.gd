extends SceneTree

## studio_script_check - a note read at the studio ([StudioScript]) and its acts made into motion and sound lanes
## ([StudioActs]). It holds:
##
## - an act mark's words read in any order: its verb, thing, side, hand, seconds, paces, pressure, pattern, tool and `alone`; a word
##   it does not know named, never guessed (control: a mark of known words names nothing);
## - a thing an act cannot be done to is named and the verb's own taken;
## - the voice talks over every act, resting only for one said `alone` (its seconds), opening on a rest;
## - two hands: a hand named, else a free one, else the side's; cupping takes both; an act ends at its closing mark, where another
##   act takes its hand, or at the end; a closing mark that ends nothing named; an act on the fur with no side works its hand's;
## - an act that goes on is made as long as asked, the same where two lengths overlap, nothing carried back; its sound windows laid
##   over each other, those made already the same when it goes on longer; every tap in a window; where it ends it dies away;
## - the spoken words leave the marks and headings out, and each act knows how many came before it;
## - each act its own number: the same words twice are two numbers, the same note the same numbers;
## - a rub on the left of the windscreen is heard left (every lane x under 0; control: one on the right, over 0); one `around`
##   crosses from ear to ear; its contact never slides at one speed nor along a line; `faster` ends quicker than it began;
## - taps hit inside the act, each with a speed, a material and a place; a scrape brings both blocks from their rests and puts
##   them back, its contact a scrape of wood on wood; the brush is brought and taken back; only an act on the windscreen
##   presses it.
## - the reader is told its passage's planned work and about how long its sound runs (control: with none planned, none told);
## - the studio follows the voice with no act in its script: the title stands until the first word is heard (control: before it,
##   it stands) and the close fades after the last; no act the hands go on with holds it (they fade with it),
##   and the studio's sound goes down with the picture (control: with the end not known, it plays on);
## - every studio thing is a role an agent designs ([RoleDesign]): a make lacking what the studio works on it (a point, a named part,
##   fur on the windscreen) cannot play it and is named (control: one with all of it fits); the designer is told every need, its
##   prompt whole; its answer read, one lacking a need answered with what it lacks; a note's makes kept only where valid;
## - a passage's marks checked: a word in no list, a phrase the show's head has not, far less sound than asked, each said (control:
##   a passage of known words, phrases and enough sound passes); the reader is told the show's phrases by name and keeps its calls;
##   the head's designer told what a phrase is written as and, asked again, each phrase measured; its answer read as a bank;
## - over minutes of the head's performance nothing lying on the side table comes into its view;
## - a thing placed: its place made safe (its fields held to their ranges, defaults dropped); the camera moved moves alone with its
##   lens, the tripod's head staying under its foot as the studio stands it, so the two can be brought together; the microphone moved
##   carries where the sound is heard (control: unplaced, each where the studio stands it); the scene's report measures the camera on the tripod's head and names what the viewer sees; a refine's answer read as a
##   place, a prop or both, and its refiner told the scene and the place's fields, asked again only of the place;
## - a thing at rest lies on the side table out of shot: below the viewer's frame by a margin for the chair's sway, and out of the
##   flip screen's view (control: the windscreen's top is in shot).
##
##   godot --headless --path . --script tests/studio/studio_script_check.gd

var _fails := 0
var _checks := 0


func _init() -> void:
	var note := "\n".join(PackedStringArray([
		"---", "title: A test", "---", "", "# A test", "",
		"<!-- speaker: Whisper -->", "Hello there, my lovelies.", "",
		"<!-- rub: fur, left, 10, slower, firm -->", "",
		"Now the other side.", "",
		"<!-- rub: right, fur, 10 -->", "",
		"<!-- tap: camera, 5, alone -->", "Taps on their own.", "",
		"<!-- scrape: blocks, 9, slow, long -->", "",
		"<!-- brush: lens, 8 -->", "",
		"<!-- rub: fur, left, 10, slower, firm -->", "",
		"<!-- scratch: fur, wobbly, 6 -->", "",
		"<!-- knock: fur, 6 -->", "Done."]))
	var d := StudioScript.parse(note)
	var acts: Array = d["acts"]
	_ok(acts.size() == 8, "eight act marks read (%d)" % acts.size())
	var a0: Dictionary = acts[0]
	_ok(String(a0["verb"]) == "rub" and String(a0["thing"]) == "fur" and String(a0["side"]) == "left" and is_equal_approx(float(a0["secs"]), 10.0)
		and (a0["paces"] as Array) == ["slower"] and String(a0["press"]) == "firm", "a mark's words read: rub, fur, left, 10 s, slower, firm")
	_ok(String(acts[1]["side"]) == "right" and String(acts[1]["thing"]) == "fur", "...in any order")
	_ok(not bool(acts[2]["under"]) and bool(acts[2]["alone"]) and bool(a0["under"]), "every act goes on under the words, but one said alone")
	_ok(String(acts[3]["pattern"]) == "long" and (acts[3]["paces"] as Array) == ["slow"], "a pattern and a pace")
	var unknown: Array = d["unknown"]
	var named := unknown.map(func(u: Array) -> String: return String(u[1]))
	_ok(named.has("wobbly"), "a word a mark does not know is named (%s)" % str(named))
	_ok(unknown.filter(func(u: Array) -> bool: return int(u[0]) < 6).is_empty(), "control: marks of known words name nothing")
	_ok(String(acts[7]["thing"]) == "blocks" and named.any(func(w: String) -> bool: return w.begins_with("fur (")),
		"a thing an act cannot be done to is named, and the verb's own taken")

	# the voice's rests
	var speak := String(d["speakable"])
	var holds := RegEx.create_from_string("action-hold: ([0-9.]+)").search_all(speak).map(func(m: RegExMatch) -> float: return float(m.get_string(1)))
	_ok(holds.size() == 2 and is_equal_approx(float(holds[0]), StudioScript.OPENING), "it opens on a rest, and rests only for the act said alone (%d)" % holds.size())
	_ok(holds.size() == 2 and is_equal_approx(float(holds[1]), 5.0 + StudioScript.AFTER), "an act alone rests its seconds")
	_ok(not speak.contains("rub:") and speak.contains("<!-- speaker: Whisper -->"), "the marks go, a speaker's cue stays")
	var spoken: PackedStringArray = d["spoken"]
	_ok(spoken[0] == "hello" and not spoken.has("test") and not spoken.has("rub"), "the spoken words leave marks and headings out")
	_ok(int(a0["after"]) == 4 and int(acts[1]["after"]) == 8, "each act knows how many words came before it")
	_ok(int(a0["seed"]) != int(acts[5]["seed"]), "the same words twice are two numbers")
	_ok(StudioScript.parse(note)["acts"].map(func(a: Dictionary) -> int: return int(a["seed"])) == acts.map(func(a: Dictionary) -> int: return int(a["seed"])),
		"the same note the same numbers")

	# the acts made
	var geo := _geo()
	var left := StudioActs.make(a0, geo)
	var right := StudioActs.make(acts[1], geo)
	var lx: PackedFloat32Array = left["sound"]["contacts"][0]["lanes"]["x"]
	var rx: PackedFloat32Array = right["sound"]["contacts"][0]["lanes"]["x"]
	_ok(_max(lx) < 0.0, "a rub on the left of the windscreen is heard left")
	_ok(_min(rx) > 0.0, "control: one on the right is heard right")
	_ok(lx.size() >= int(10.0 * Gesture.RATE), "its lanes run the act's length (%d samples)" % lx.size())
	var around := StudioActs.make(StudioScript.act_of("rub", "fur, around, 12", []), geo)
	var ax: PackedFloat32Array = around["sound"]["contacts"][0]["lanes"]["x"]
	_ok(_min(ax) < -0.05 and _max(ax) > 0.05, "a rub around crosses from ear to ear")
	var sp: PackedFloat32Array = left["sound"]["contacts"][0]["lanes"]["speed"]
	_ok(_cv(sp, int(1.0 * Gesture.RATE), sp.size() - int(1.0 * Gesture.RATE)) > 0.3, "its contact never slides at one speed")
	_ok(_off_line(left["sound"]["contacts"][0]["lanes"]) > 0.002, "...nor along a line")
	var fast := StudioActs.make(StudioScript.act_of("rub", "fur, back, 12, faster", []), geo)
	var fsp: PackedFloat32Array = fast["sound"]["contacts"][0]["lanes"]["speed"]
	var q := fsp.size() / 4
	_ok(_mean(fsp, fsp.size() - q - 150, fsp.size() - 150) > _mean(fsp, 150, 150 + q) * 1.5, "faster ends quicker than it began")
	_ok((left["touches"] as Array).size() == 1, "a rub on the windscreen presses it")

	var tap := StudioActs.make(acts[2], geo)
	var hits: Array = tap["sound"]["hits"]
	var hits_ok := hits.size() > 4
	for h in hits:
		if float(h["t"]) < 0.0 or float(h["t"]) > 5.0 or float(h["speed"]) <= 0.0 or String(h["on"]) != "plastic" or (h["at"] as Array).size() != 3:
			hits_ok = false
	_ok(hits_ok, "taps hit inside the act, each with a speed, a material and a place")
	_ok((tap["shake"] as Dictionary).has("camera") and (tap["touches"] as Array).is_empty(), "a tap on the camera sways it and presses no fur")

	var scrape := StudioActs.make(acts[3], geo)
	var tracks: Dictionary = scrape["tracks"]
	var rests: Dictionary = geo["rests"]
	var a_track: Dictionary = tracks.get("block_a", {})
	_ok(tracks.has("block_a") and tracks.has("block_b"), "a scrape moves both blocks")
	if not a_track.is_empty():
		var first := StudioActs.pose_at(a_track, 0.0)
		var last := StudioActs.pose_at(a_track, 999.0)
		_ok(first.origin.distance_to((rests["block_a"] as Transform3D).origin) < 0.01 and last.origin.distance_to((rests["block_a"] as Transform3D).origin) < 0.01,
			"...brought from its rest and put back")
	var c: Dictionary = scrape["sound"]["contacts"][0]
	_ok(String(c["kind"]) == "scrape" and String(c["on"]) == "wood" and String(c["by"]) == "wood" and c.has("body"), "its contact is wood scraped on wood")
	var brush := StudioActs.make(acts[4], geo)
	_ok((brush["tracks"] as Dictionary).has("brush") and (brush["touches"] as Array).is_empty()
		and String(brush["sound"]["contacts"][0]["on"]) == "glass", "the brush is brought to the lens, brushes glass and presses no fur")
	var bt: Dictionary = brush["tracks"]["brush"]
	_ok(StudioActs.pose_at(bt, 0.0).origin.distance_to((rests["brush"] as Transform3D).origin) < 0.01
		and StudioActs.pose_at(bt, 999.0).origin.distance_to((rests["brush"] as Transform3D).origin) < 0.01, "...and taken back")
	var on_fur := StudioActs.make(StudioScript.act_of("brush", "fur, left, 10", []), geo)
	_ok((on_fur["tracks"] as Dictionary).has("brush") and (on_fur["touches"] as Array).size() == 1
		and String(on_fur["sound"]["contacts"][0]["by"]) == "bristle", "the brush on the windscreen is the brush brought to it, pressing the fur")
	var lens_z := _mean((brush["sound"]["contacts"][0]["lanes"]["z"] as PackedFloat32Array), int(4.0 * Gesture.RATE), int(5.0 * Gesture.RATE))
	_ok(lens_z < -0.3, "the lens is heard far in front of the microphone (%.2f m)" % lens_z)

	# for the agents who make an episode for it
	var voiced := StudioMedium.voiced("Before.\n\n<!-- rub: fur, left, 10, alone -->\n\nDuring.\n\n<!-- tap: camera, 4 -->\nOver it.\n")
	_ok(voiced.contains("<!-- rub: fur, left, 10, alone --> <!-- quiet: %s -->" % String.num(10.0 + StudioScript.AFTER, 2)) and voiced.count("quiet:") == 1,
		"an episode's voice talks over the hands, and rests only for an act said alone")
	var kept := TableProducer.voice_marks_only("Soft. <!-- rub: fur, left, 10 --> Now. <!-- wiggle: 3 -->", [], StudioMedium.reader_marks())
	_ok(kept.contains("<!-- rub: fur, left, 10 -->") and not kept.contains("wiggle"), "a reader's act marks are kept in its passage, nothing else")
	_ok(not TableProducer.voice_marks_only("Soft. <!-- rub: fur, left, 10 -->").contains("rub:"), "control: a format with no marks of its own keeps none")
	var told := StudioMedium.reader_rules()
	var tells_all := not told.is_empty()
	for v in StudioActs.VERBS:
		tells_all = tells_all and told.contains("- %s (" % v)
	for k in StudioActs.SIDES:
		tells_all = tells_all and told.contains("- %s:" % k)
	_ok(tells_all and not told.contains("{{"), "the reader is told every verb and side the studio reads, filled in")
	_check_roles()
	_ok(bool(Registry.field(Medium.REGISTRY, "studio", "own_set", false)) and Medium.mode_of("studio") == "table"
		and Medium.offered(["reading", "episode"]).has("studio") and not Medium.offered(["reading"]).has("studio"),
		"the studio is one of Table's formats, offered to a show's episodes and to nothing else")
	var taken := StudioScript.with_takes(acts, {str(int(a0["seed"])): 2})
	_ok(int(taken[0]["seed"]) != int(a0["seed"]) and int(taken[0]["take"]) == 2 and int(taken[1]["seed"]) == int(acts[1]["seed"])
		and int(taken[0]["own"]) == int(a0["seed"]), "a take is another performance of that act alone, its own number kept")

	var planned := StudioMedium.reader_rules({"work": "PLANNED the fur is rubbed slowly.", "beat": "3", "words": Vector2i(31, 46),
		"said_word": 0.52, "quiet": 0.65})
	_ok(planned.contains("PLANNED the fur is rubbed slowly.") and planned.contains("about 55 seconds") and not planned.contains("{{"),
		"the reader is told its passage's planned work and about how long its sound runs")
	_ok(not told.contains("THE HANDS IN THIS PASSAGE"), "control: with no work planned, none is told")
	_check_ends()
	_check_hands()
	_check_open(geo)
	_check_rests()
	_check_head()
	_check_places()

	# every act's sound names materials the host knows (an act whose mark names no tool takes its verb's)
	var known := true
	var whys: Array = []
	for a in acts:
		var m := StudioActs.make(a, geo)
		for one in (m["sound"]["contacts"] as Array) + (m["sound"]["hits"] as Array):
			for side in ["on", "by"]:
				if not StudioActs.SOUND_MATERIALS.has(String((one as Dictionary).get(side, ""))):
					known = false
					whys.append("%s %s: %s '%s'" % [String(a["verb"]), String(a["thing"]), side, String((one as Dictionary).get(side, ""))])
	_ok(known, "every act's sound names materials the host knows %s" % str(whys))

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The opening and the close found from the voice's words, with no act in the script or one past the last word; the sound faded
## with the picture.
func _check_ends() -> void:
	var m := StudioMedium.new()
	m.feed = ShowFeed.new()
	var bare := "<!-- act: pull-mic --> Okay, we are rolling.\n\n<!-- quiet: 12 -->\nHi there, night shift. Goodbye."
	m.load_script(bare)
	var before := m._opening()
	var words := StudioScript.rehearsal(StudioScript.parse(bare))
	m.take_words(words)
	var last_end := float((words[words.size() - 1] as Dictionary)["t1"])
	_ok(before == INF and m._opening() < INF and is_equal_approx(m._last_sound(), last_end),
		"with no act in its script the title waits for the first word and the close for the last (%s, %.2f, %.2f)" % [str(before), m._opening(), m._last_sound()])
	var past := "Goodbye now, sleep well.\n\n<!-- brush: fur, around, 20 -->\n"
	m.load_script(past)
	var said := StudioScript.rehearsal(StudioScript.parse(past))
	m.take_words(said)
	var said_end := float((said[said.size() - 1] as Dictionary)["t1"])
	_ok(is_equal_approx(m._last_sound(), said_end), "an act past the last word never holds the close: it begins where the words end (%.2f after them)" % (m._last_sound() - said_end))
	var going := "Hello there.\n<!-- rub: fur, left, 45 -->\nGoodbye now, sleep well."
	m.load_script(going)
	var heard := StudioScript.rehearsal(StudioScript.parse(going))
	m.take_words(heard)
	var going_end := float((heard[heard.size() - 1] as Dictionary)["t1"])
	_ok(is_equal_approx(m._last_sound(), going_end) and m._t1[0] <= going_end + maxf(m.feed.tail(), 0.5) + 0.01,
		"hands at work as the words end fade with the outro: the close is the last word's (%.2f), the act ends with the outro" % (m._last_sound() - going_end))
	m.feed.free()
	m.free()
	var snd := StudioSounds.new()
	var clip := PackedVector2Array()
	clip.resize(StudioSounds.RATE * 5)
	clip.fill(Vector2(0.1, 0.1))
	snd._clips = {"k": clip}
	snd.place([{"key": "k", "t0": 0.0}])
	var open := snd.render(2.5, 64)
	snd.fade_from = 1.0
	snd.outro = 1.0
	var early := snd.render(0.5, 64)
	var late := snd.render(2.5, 64)
	_ok(is_equal_approx(early[0].x, 0.1) and is_zero_approx(late[0].x) and is_zero_approx(late[63].y),
		"the studio's sound goes down with the picture after its last sound (%.3f, then %.3f)" % [early[0].x, late[0].x])
	_ok(is_equal_approx(open[0].x, 0.1), "control: with the end not known it plays on (%.3f)" % open[0].x)


## Two hands and where acts end: a hand named, else the side's, else a free one; a closing mark ends the latest act of its verb (the
## one of its hand, where it names one); another act on a hand ends the one there; both-hand acts take both; a closing mark that ends
## nothing is named; an act on the fur that names no side works its hand's.
func _check_hands() -> void:
	var note := "\n".join(PackedStringArray([
		"One two three.", "<!-- rub: fur, left hand -->", "four five six.",
		"<!-- tap: camera -->", "seven eight.", "<!-- /rub -->", "nine ten.",
		"<!-- brush: fur, right hand -->", "eleven twelve.", "<!-- cup: fur -->", "thirteen.", "<!-- /scratch -->",
		"<!-- rub: fur, right -->", "fourteen fifteen.", "<!-- rub: fur, left -->", "sixteen.", "<!-- /rub: right hand -->", "seventeen."]))
	var d := StudioScript.parse(note)
	var acts: Array = d["acts"]
	var hands: Array = acts.map(func(a: Dictionary) -> String: return String(a["hand"]))
	var ends: Array = acts.map(func(a: Dictionary) -> String: return "%s@%d" % [String(a["ends"]), int(a["end"])])
	_ok(hands == ["left", "right", "right", "both", "right", "left"],
		"a hand named, else a free one, else the side's; cupping takes both (%s)" % str(hands))
	_ok(ends[0] == "mark@8" and ends[1] == "hand@10" and ends[2] == "hand@12" and ends[3] == "hand@13" and ends[4] == "mark@16" and ends[5] == "end@-1",
		"an act ends at its closing mark, where another takes its hand (both, for cupping), or at the end (%s)" % str(ends))
	_ok(Array(d["stray"]) == ["/scratch"] and StudioMedium.reader_check("Hi.\n<!-- /tap -->\nThere.").contains("<!-- /tap -->"),
		"a closing mark that ends nothing is named, and a passage with one handed back")
	_ok(String((acts[0] as Dictionary)["side"]) == "back-left" and String((acts[2] as Dictionary)["side"]) == "back-right"
		and String((acts[4] as Dictionary)["side"]) == "right", "an act on the fur that names no side works its hand's side (control: one named)")
	# an act's words as a Refine changed them: its sound made from those, its own number kept (control: the others as written)
	var own := str(int((acts[0] as Dictionary)["seed"]))
	var changed := StudioScript.parse(note, StudioMedium.marks_of({"marks": {own: "fur, right, right hand, slow", "bad": "x", "7": ""}}))
	var c0: Dictionary = (changed["acts"] as Array)[0]
	_ok(String(c0["side"]) == "right" and String(c0["hand"]) == "right" and int(c0["seed"]) == int((acts[0] as Dictionary)["seed"])
		and String((changed["acts"] as Array)[1]["words"]) == String(acts[1]["words"]),
		"an act's words as a Refine changed them make it, its own number kept (control: the others as written)")
	Rules.missing.clear()
	var sys := Rules.say("agents/refine.system", {"what": "the sound of act 1 (rub)", "title": "", "act": true, "verb": "rub",
		"vocabulary": StudioActs.vocabulary(), "parts": [], "marks": [], "has_parts": false, "has_marks": false, "tools": true})
	_ok(Rules.missing.is_empty() and sys.contains("Its verb (rub) stays") and sys.contains("both hands"), "its writer is told every word an act may use")
	var lengths := StudioScript.lengths(d)
	_ok(lengths.has(0) and float(lengths[0]) > 1.0 and not lengths.has(99), "an act that goes on is given a length a steady voice would take")


## An act that goes on: made as long as asked, the same wherever two lengths overlap, nothing carried back; its sound cut into
## windows laid over each other, the windows already made the same keys when it is made longer; a short timed act one sound.
func _check_open(geo: Dictionary) -> void:
	var act := StudioScript.act_of("rub", "fur, left hand, around", [])
	act["seed"] = 77
	act["timed"] = false
	var short := StudioActs.make(act, geo, 30.0)
	var long := StudioActs.make(act, geo, 70.0)
	var sx: PackedFloat32Array = short["sound"]["contacts"][0]["lanes"]["x"]
	var lx: PackedFloat32Array = long["sound"]["contacts"][0]["lanes"]["x"]
	var same := sx.size() >= int(29.0 * Gesture.RATE)
	for i in range(0, sx.size() - 3, 11):
		same = same and is_equal_approx(sx[i], lx[i])
	_ok(bool(short["open"]) and same and _min(lx) < -0.05 and _max(lx) > 0.05,
		"an act that goes on is made as long as asked, the same where two lengths overlap, circling on its own clock")
	var brushing := StudioScript.act_of("brush", "fur, right hand", [])
	brushing["timed"] = false
	var bt: Dictionary = StudioActs.make(brushing, geo, 30.0)["tracks"]["brush"]
	_ok(StudioActs.pose_at(bt, 999.0).origin.distance_to(((geo["rests"] as Dictionary)["brush"] as Transform3D).origin) > 0.05,
		"what an act that goes on brings is not carried back by it (whatever ends it does that)")
	var a := StudioSounds.make_all([act.merged({"i": 0})], geo, {0: 30.0})
	var b := StudioSounds.make_all([act.merged({"i": 0})], geo, {0: 50.0})
	var ka: PackedStringArray = a["keys"][0]
	var kb: PackedStringArray = b["keys"][0]
	var st: PackedFloat32Array = a["starts"][0]
	var spec0: Dictionary = (a["specs"] as Dictionary)[ka[0]]
	var spec1: Dictionary = (a["specs"] as Dictionary)[ka[1]] if ka.size() > 1 else {}
	_ok(ka.size() == 3 and kb.size() > ka.size() and kb.slice(0, ka.size()) == ka and is_equal_approx(st[1], StudioSounds.WINDOW)
		and is_equal_approx(float(spec0["secs"]), StudioSounds.WINDOW + StudioSounds.OVERLAP) and is_equal_approx(float(spec1.get("skip", 0.0)), StudioSounds.PRE)
		and is_zero_approx(float(spec0["skip"])), "its sound is windows laid over each other, those made already the same when it goes on longer (%d, then %d)" % [ka.size(), kb.size()])
	var brief := StudioSounds.make_all([act.merged({"i": 0})], geo, {0: 3.0})
	_ok((brief["keys"][0] as PackedStringArray).size() == 1 and (brief["keys"][0] as PackedStringArray)[0] == ka[0],
		"an act that goes on but briefly still has its first window to sound in, the same as a longer one's")
	var timed := StudioSounds.make_all([StudioScript.act_of("tap", "camera, 6", []).merged({"i": 0, "seed": 5})], geo)
	_ok((timed["keys"][0] as PackedStringArray).size() == 1, "a short act with its seconds is one sound")
	var taps := StudioScript.act_of("tap", "camera", [])
	taps.merge({"i": 0, "seed": 9, "timed": false}, true)
	var tw := StudioSounds.windows_of(StudioActs.make(taps, geo, 40.0)["sound"], true)
	var every := true
	for h in StudioActs.make(taps, geo, 40.0)["sound"]["hits"]:
		var t := float((h as Dictionary)["t"])
		if t > float(tw.size()) * StudioSounds.WINDOW:
			continue
		var held := false
		for w in tw:
			var w0 := float(w["at"]) - float(w["sound"]["skip"])
			for hh in w["sound"]["hits"]:
				held = held or is_equal_approx(float(hh["t"]) + w0, t)
		every = every and held
	_ok(every, "every tap is in a window that sounds it")
	# where it ends, it dies away
	var snd := StudioSounds.new()
	var clip := PackedVector2Array()
	clip.resize(StudioSounds.RATE * 4)
	clip.fill(Vector2(0.1, 0.1))
	snd._clips = {"k": clip}
	snd.place([{"key": "k", "t0": 0.0, "end": 1.0}])
	var before := snd.render(0.9, 8)
	var gone := snd.render(1.0 + StudioSounds.RELEASE + 0.01, 8)
	_ok(is_equal_approx(before[0].x, 0.1) and is_zero_approx(gone[0].x), "where an act ends its sound dies away (%.3f, then %.3f)" % [before[0].x, gone[0].x])


## The studio's things as roles: what a make must have, what its designer is told, how its answer is read.
func _check_roles() -> void:
	var cam := {"parts": [{"shape": "box", "size": [12, 8, 6], "material": "body", "points": {"lens": [0, 4, 6], "body": [0, 8, 0]}},
		{"shape": "face", "name": "screen", "size": [6, 4], "at": [9, 4, 3], "material": "glass"}]}
	var blind: Dictionary = cam.duplicate(true)
	((blind["parts"] as Array)[0] as Dictionary)["points"] = {"body": [0, 8, 0]}
	_ok(PropMakes.fits("camera", cam) and not PropMakes.fits("camera", blind) and PropMakes.missing("camera", blind) == PackedStringArray(["point lens"]),
		"a camera lacking its lens point cannot play the part, and is told so (control: with it, it fits): %s" % str(PropMakes.missing("camera", blind)))
	var mic := {"parts": [{"shape": "ball", "size": [17, 18, 17], "material": "fur", "name": "windscreen", "points": {"capsule": [0, 18, 0], "body": [0, 9, 3]}}]}
	_ok(PropMakes.missing("microphone", mic) == PackedStringArray(["part windscreen"]), "a windscreen with no fur is no windscreen")
	((mic["parts"] as Array)[0] as Dictionary)["fur"] = {"length": 3}
	_ok(PropMakes.fits("microphone", mic), "...and with fur it fits")
	# a ring light that shines: one with no light and nothing lit is no design, though it still stands
	var dark := {"parts": [{"name": "ring", "shape": "ring", "radius": 14, "width": 3, "thickness": 2, "material": "m", "points": {"middle": [0, 0, 0]}}]}
	var lit := {"parts": [{"name": "ring", "shape": "ring", "radius": 14, "width": 3, "thickness": 2, "material": "m", "lit": 1.0, "points": {"middle": [0, 0, 0]},
		"light": {"kind": "spot", "aim": [0, 0, 1]}}]}
	var strict := PropMakes.missing("ring_light", dark, true)
	_ok(strict.has("part ring's light") and strict.has("part ring lit") and PropMakes.fits("ring_light", dark) and PropMakes.missing("ring_light", lit, true).is_empty(),
		"a ring light that does not shine is no design (it lacks %s), though it still stands to be refined (control: lit, with its light, it is whole)" % str(strict))
	var flat := Props.sanitize({"things": [{"name": "a washer", "parts": [{"shape": "ring", "radius": 14, "width": 3, "thickness": 2, "material": "m"}]}],
		"materials": {"m": {"kind": "plastic", "color": "#ffffff"}}}, [])
	var fb := Props.build((flat["things"] as Array)[0], flat["materials"], 1)
	var fsize: AABB = fb["size"]
	_ok(is_equal_approx(snappedf(fsize.size.x, 0.001), 0.31) and is_equal_approx(snappedf(fsize.size.y, 0.001), 0.02),
		"a ring with a width is flat: as wide as its band reaches and as deep as its thickness (%s)" % str(fsize.size))
	(fb["node"] as Node).free()
	Rules.missing.clear()
	var p := RoleDesign.prompt("camera", "A test show.", [{"name": "a tripod", "line": "A tripod."}], {"name": "an old camera", "line": "Old."})
	var told := String(p["prompt"])
	_ok(Rules.missing.is_empty() and told.contains("\"lens\"") and told.contains("\"screen\"") and told.contains("a tripod") and told.contains("an old camera"),
		"the designer is told every need, the scene's other things and the make it replaces, the prompt whole: %s" % ", ".join(Rules.missing))
	var lacking := RoleDesign.answer("camera", JSON.stringify({"name": "a camera", "line": "One.", "thing": blind, "materials": {"body": {"kind": "plastic"}}}))
	var whole := RoleDesign.answer("camera", "Here: " + JSON.stringify({"name": "a mirrorless camera", "line": "One.", "thing": cam,
		"materials": {"body": {"kind": "plastic"}, "glass": {"kind": "glass"}}}))
	_ok(lacking.get("lacks", PackedStringArray()) == PackedStringArray(["point lens"]) and String(whole.get("name", "")) == "a mirrorless camera",
		"a designer's answer is read, and one lacking a need is answered with what it lacks (%s, %s)" % [str(lacking), str(whole.keys())])
	var kept := StudioMedium.makes_of({"makes": {"camera": {"kept": "a mirrorless camera"}, "tripod": {"recipe": "x"}, "nothing": {"kept": "a"}, "brush": {}}})
	_ok(kept == {"camera": {"kept": "a mirrorless camera"}}, "a note's makes are kept only where a role can take them: %s" % str(kept))


## Every thing at rest out of shot: each corner of a block, the brush's ends - below the viewer's frame and the flip screen's view.
func _check_rests() -> void:
	var pts := {}
	for k in StudioSet.RESTS:
		var r: Array = StudioSet.RESTS[k]
		var deg: Vector3 = r[1]
		var xf := Transform3D(Basis.from_euler(deg * PI / 180.0), r[0])
		var own: Array = [Vector3.ZERO, Vector3(0.0, 0.186, 0.0)] if String(k) == "brush" else []
		if own.is_empty():
			for c in 8:
				own.append(Vector3(0.075 * (1 - 2 * (c & 1)), 0.02 * ((c >> 1) & 1), 0.025 * (1 - 2 * ((c >> 2) & 1))))
		var on_desk := true
		for q in own:
			var w: Vector3 = xf * (q as Vector3)
			pts["%s %s" % [k, str(q)]] = w
			on_desk = on_desk and w.y >= StudioSet.SHELF - 0.005
		_ok(on_desk, "%s rests on the side table, not in it" % k)
	var worst := INF
	var worst_screen := INF
	for k in pts:
		worst = minf(worst, _below_view(pts[k], StudioSet.EYE, StudioSet.LOOK, StudioSet.VFOV))
		worst_screen = minf(worst_screen, _below_view(pts[k], StudioSet.LENS, StudioSet.LENS + Vector3(0.0, 0.0, 1.0), StudioScreen.FOV))
	_ok(worst > 3.0 and worst_screen > 3.0, "every thing at rest is out of shot: %.1f degrees below the frame, %.1f below the flip screen's" % [worst, worst_screen])
	_ok(_below_view(StudioSet.CAPSULE, StudioSet.EYE, StudioSet.LOOK, StudioSet.VFOV) < 0.0, "control: the windscreen's top is in shot")


## The head in the studio: a passage's marks checked against the show's phrases, and nothing resting seen over a long performance.
func _check_head() -> void:
	var bank := HeadBank.phrases_of(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/studio/head_bank.json")))
	Library.root = "user://studio_script_check"
	HeadBank.write("a test show", bank)
	var told := {"work": "the fur is rubbed", "beat": "2", "words": Vector2i(30, 40), "said_word": 0.52, "quiet": 0.65, "show": "a test show"}
	var good := "Hello.\n<!-- head: weave -->\n<!-- rub: fur, left, 30 -->\nThere."
	var bad := "Hello.\n<!-- head: cartwheel -->\n<!-- rub: fur, left, 4, sideways -->\nThere."
	var fault := StudioMedium.reader_check(bad, told)
	_ok(StudioMedium.reader_check(good, told).is_empty() and fault.contains("\"cartwheel\" (no phrase") and fault.contains("\"sideways\"")
		and fault.contains("4 seconds of sound"), "a passage's odd words, phrases the head has not and too little sound are named (control: a good one passes): %s" % fault)
	var rules := StudioMedium.reader_rules(told)
	_ok(rules.contains("- weave: ") and rules.contains("<!-- head: NAME -->") and not StudioMedium.reader_rules({}).contains("<!-- head: NAME -->"),
		"the reader is told the show's phrases by name (control: a show with none is told of none)")
	DirAccess.remove_absolute(HeadBank.path_of("a test show"))
	Library.root = Library.ROOT
	Rules.missing.clear()
	var first := HeadDesign.prompt("A test show: raw ASMR footage.")
	var again := HeadDesign.prompt("A test show.", HeadDesign.report(bank), JSON.stringify({"phrases": bank}))
	_ok(Rules.missing.is_empty() and String(first["prompt"]).contains("- side: ") and not String(first["prompt"]).contains("MEASURED")
		and String(again["prompt"]).contains("MEASURED") and String(again["prompt"]).contains("- weave (") and String(again["prompt"]).contains("crosses"),
		"the head's designer is told what a phrase is written as, and asked again shown each phrase measured: %s" % ", ".join(Rules.missing))
	_ok(HeadDesign.answer("Here: " + JSON.stringify({"phrases": bank})).size() == 5 and HeadDesign.answer("no").is_empty(), "its answer is read as a bank")
	_ok(TableProducer.voice_marks_only("Soft. <!-- head: weave --> Now.", [], StudioMedium.reader_marks()).contains("<!-- head: weave -->"),
		"the reader's head marks are kept in its passage")
	var geo := _geo()
	var lis: Transform3D = geo["listener"]
	var words: Array = []
	for i in 700:
		words.append({"text": "word.", "t0": 3.0 + float(i) * 0.42, "t1": 3.3 + float(i) * 0.42, "emph": 1 if i % 5 == 2 else 0, "sentence": i / 9})
	var targets := {"lens": lis.affine_inverse() * StudioSet.LENS, "screen": lis.affine_inverse() * (StudioSet.LENS + Vector3(0.15, 0.0, 0.0))}
	var plan := HeadPlan.make([], words, bank, 11, targets)
	var worst := INF
	var at := 0.0
	for i in 3000:
		var t := float(i) * 0.1
		var hp := HeadPlan.pose_at(plan, t)
		var eye: Vector3 = lis * (hp["eyes"] as Vector3)
		var look: Vector3 = lis.basis * (hp["look"] as Vector3)
		for k in StudioSet.RESTS:
			var off := rad_to_deg(look.angle_to(((StudioSet.RESTS[k] as Array)[0] as Vector3) - eye))
			# a view 28 degrees tall and 16:9 wide reaches about 27 degrees off its middle at its corners
			if off < worst:
				worst = off
				at = t
	_ok(worst > 30.0, "nothing resting comes into the head's view over five minutes of its performance (nearest %.0f degrees off its middle, at %.1f s)" % [worst, at])


## Things placed in the studio: from the fixture makes held in a library of the gate's own.
func _check_places() -> void:
	var p := StudioSet.place_of({"x": 500.0, "y": 3.0, "scale": 1.0, "turn": "no", "nothing": 2})
	_ok(p == {"x": 150.0, "y": 3.0}, "a place is made safe: each field in its range, defaults and strangers dropped: %s" % str(p))
	Library.root = "user://studio_script_check"
	var makes := {}
	for pair in [["camera", "vlog_camera"], ["tripod", "tripod"], ["microphone", "microphone"], ["ring_light", "ring_light"]]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/studio/%s.prop.json" % pair[1]))
		ThingLibrary.keep(d["thing"], d["materials"], String(d.get("line", "")), true)
		makes[pair[0]] = {"kept": String((d["thing"] as Dictionary)["name"])}
	var home := StudioSet.build(1, makes)
	var moved := StudioSet.build(1, makes, {"camera": {"y": 10.0}, "microphone": {"x": -5.0}})
	var hr: Dictionary = home["rigs"]
	var mr: Dictionary = moved["rigs"]
	var cam_up := StudioScene.box_of((mr["camera"] as PropRig).node).get_center().y - StudioScene.box_of((hr["camera"] as PropRig).node).get_center().y
	var tri_up := StudioScene.box_of((mr["tripod"] as PropRig).node).end.y - StudioScene.box_of((hr["tripod"] as PropRig).node).end.y
	var lens_up := ((moved["geo"] as Dictionary)["lens"] as Vector3).y - ((home["geo"] as Dictionary)["lens"] as Vector3).y
	var ear_left := ((moved["geo"] as Dictionary)["listener"] as Transform3D).origin.x - ((home["geo"] as Dictionary)["listener"] as Transform3D).origin.x
	_ok(is_equal_approx(snappedf(cam_up, 0.001), 0.1) and is_zero_approx(snappedf(tri_up, 0.001)) and is_equal_approx(snappedf(lens_up, 0.001), 0.1)
		and is_equal_approx(snappedf(ear_left, 0.001), -0.05), "the camera moved up moves alone with its lens, the tripod staying (%.3f, %.3f, %.3f m); the microphone moved carries the ear (%.3f m)" % [cam_up, tri_up, lens_up, ear_left])
	var lowered := StudioSet.build(1, makes, {"camera": {"y": -3.0}})
	var gap_down := StudioScene.gap(StudioScene.box_of(((lowered["rigs"] as Dictionary)["camera"] as PropRig).node), StudioScene.box_of(((lowered["rigs"] as Dictionary)["tripod"] as PropRig).node))
	_ok(gap_down < -1.0, "...so a camera can be brought down onto, and into, its tripod (%.1f cm)" % gap_down)
	((lowered["root"]) as Node).free()
	var said := StudioScene.describe(home, makes, {}, "camera")
	_ok(said.contains("the camera's foot is on the tripod's head") and said.contains("- tripod (") and said.contains("THE VIEWER'S EYE records the show")
		and said.contains("THE CAMERA'S LENS") and said.contains("the viewer's eye: seen across"),
		"the scene's report measures the camera on the tripod's head, says where the show is recorded from and where each thing falls through it")
	var ahead := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var mid := StudioScene.framed(AABB(Vector3(-0.1, -0.1, -2.1), Vector3(0.2, 0.2, 0.2)), ahead, 28.0, 16.0 / 9.0)
	var behind := StudioScene.framed(AABB(Vector3(-0.1, -0.1, 1.0), Vector3(0.2, 0.2, 0.2)), ahead, 28.0, 16.0 / 9.0)
	var left := StudioScene.framed(AABB(Vector3(-3.0, -0.1, -2.1), Vector3(0.2, 0.2, 0.2)), ahead, 28.0, 16.0 / 9.0)
	_ok(bool(mid["seen"]) and absf(float(mid["x"])) < 0.01 and absf(float(mid["y"])) < 0.01 and float(mid["tall"]) > 0.15
		and String(behind["off"]) == "behind it" and String(left["off"]) == "left of the frame",
		"a thing's framing: straight ahead, in the middle and filling its share (%s); behind, and off to the left, said so" % str(mid))
	var off := StudioScene.describe(moved, makes, {"camera": {"y": 10.0}}, "camera")
	_ok(off.contains("moved from where the studio stands it by"), "...and says where a thing was moved from")
	for r in [home, moved]:
		((r as Dictionary)["root"] as Node).free()
	for f in DirAccess.get_files_at(ThingLibrary.dir()):
		DirAccess.remove_absolute(ThingLibrary.dir().path_join(f))
	Library.root = Library.ROOT
	_ok(LibraryVersions.place_in("{\"place\": {\"y\": 2}}") == {"y": 2.0} and LibraryVersions.thing_in("{\"place\": {\"y\": 2}}").is_empty()
		and not LibraryVersions.thing_in("{\"thing\": {\"parts\": [{}]}, \"place\": {}}").is_empty(), "a refine's answer is read as a place, a prop or both")
	# one answer placing the camera and its tripod together, by name
	var put := {}
	var fake := {"role": "camera", "roles": [{"role": "camera", "label": "the camera", "now": {}}, {"role": "tripod", "label": "the tripod", "now": {}}],
		"place": func(pl: Dictionary) -> String:
			put["camera"] = pl
			return "",
		"place_role": func(r: String, pl: Dictionary) -> String:
			put[r] = pl
			return ""}
	var both := LibraryVersions.apply_places("{\"place\": {\"y\": -2}, \"places\": {\"tripod\": {\"y\": -2}}}", fake)
	_ok(put.has("camera") and put.has("tripod") and (both["moved"] as Dictionary).size() == 2,
		"one refine places the prop and another thing of its scene together, by name: %s" % str(put))
	put.clear()
	var alone := LibraryVersions.apply_places("{\"place\": {\"y\": 1}}", fake)
	var stranger := LibraryVersions.apply_places("{\"places\": {\"lamp\": {\"y\": 1}}}", fake)
	_ok(put.keys() == ["camera"] and (alone["moved"] as Dictionary).size() == 1 and stranger.has("error"),
		"control: its own place alone moves it alone; a thing the scene has not is refused (%s)" % str(stranger))
	Rules.missing.clear()
	var scene := {"now": {"y": 2.0}, "fields": StudioSet.PLACE_FIELDS, "role": "camera", "roles": fake["roles"], "needs": RoleDesign.needs_text("camera")}
	var first := LibraryVersions.prompt("a camera", "", {"parts": []}, {}, "set it on the tripod", false, scene, {"report": "THE STUDIO, measured.", "views": []})
	var again := LibraryVersions.prompt("a camera", "", {"parts": []}, {}, "set it on the tripod", false, scene, {"report": "NOW measured.", "views": []}, {"camera": {"y": 3.0}})
	_ok(Rules.missing.is_empty() and String(first["prompt"]).contains("PLACE it") and String(first["prompt"]).contains("THE STUDIO, measured.")
		and String(first["prompt"]).contains("\"scale\"") and String(first["prompt"]).contains("\"tripod\": the tripod") and String(first["prompt"]).contains("{\"places\":")
		and String(again["prompt"]).contains("You placed, by name") and not String(again["prompt"]).contains("<prop>")
		and String(first["prompt"]).contains("WHAT THE SCENE WORKS ON IT") and String(first["prompt"]).contains("\"lens\""),
		"the refiner is told the scene and the place's fields, and asked again only of the place: %s" % ", ".join(Rules.missing))
	var plain := LibraryVersions.prompt("a camera", "", {"parts": []}, {}, "make it red", false)
	_ok(not String(plain["prompt"]).contains("PLACE it"), "control: a prop in no scene is told of no place")


## How far below the bottom edge of a view from [param eye] toward [param look] (a lens [param vfov] degrees tall) point [param p] is,
## degrees: under 0 is in it.
func _below_view(p: Vector3, eye: Vector3, look: Vector3, vfov: float) -> float:
	var local := Basis.looking_at(look - eye, Vector3.UP).inverse() * (p - eye)
	return -rad_to_deg(atan2(local.y, -local.z)) - vfov * 0.5


## The set's geometry as [method StudioSet.geometry] gives it, without building a prop.
func _geo() -> Dictionary:
	var view := Basis.looking_at(StudioSet.LOOK - StudioSet.EYE, Vector3.UP)
	var rests := {}
	for k in StudioSet.RESTS:
		var deg: Vector3 = StudioSet.RESTS[k][1]
		rests[k] = Transform3D(Basis.from_euler(deg * PI / 180.0), StudioSet.RESTS[k][0])
	return {"listener": Transform3D(view, StudioSet.CAPSULE), "eye": Transform3D(view, StudioSet.EYE), "fur_r": 0.088, "fur_len": 0.024,
		"brush_tip": 0.186, "block_size": Vector3(0.15, 0.02, 0.05), "mic_body": StudioSet.CAPSULE + Vector3(0.0, -0.14, 0.034),
		"camera_body": StudioSet.LENS + Vector3(0.03, 0.04, -0.1), "lens": StudioSet.LENS, "lens_n": Vector3(0.0, 0.0, 1.0),
		"camera_at": StudioSet.LENS, "rests": rests}


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("ok    " + what)
	else:
		_fails += 1
		print("FAIL  " + what)


func _max(x: PackedFloat32Array) -> float:
	var m := -INF
	for v in x:
		m = maxf(m, v)
	return m


func _min(x: PackedFloat32Array) -> float:
	var m := INF
	for v in x:
		m = minf(m, v)
	return m


func _mean(x: PackedFloat32Array, a: int, b: int) -> float:
	var s := 0.0
	for i in range(maxi(a, 0), mini(b, x.size())):
		s += x[i]
	return s / maxf(float(mini(b, x.size()) - maxi(a, 0)), 1.0)


func _cv(x: PackedFloat32Array, a: int, b: int) -> float:
	var m := _mean(x, a, b)
	var s := 0.0
	for i in range(a, b):
		s += (x[i] - m) * (x[i] - m)
	return sqrt(s / maxf(float(b - a), 1.0)) / maxf(m, 1e-9)


## How far a contact's path strays from the line through its ends over each second, at most (m).
func _off_line(lanes: Dictionary) -> float:
	var x: PackedFloat32Array = lanes["x"]
	var y: PackedFloat32Array = lanes["y"]
	var z: PackedFloat32Array = lanes["z"]
	var best := 0.0
	var step := int(Gesture.RATE / 2.0)
	for s in range(int(Gesture.RATE), x.size() - step - int(Gesture.RATE), step):
		var a := Vector3(x[s], y[s], z[s])
		var b := Vector3(x[s + step], y[s + step], z[s + step])
		var ab := (b - a).normalized()
		for i in range(s, s + step):
			var p := Vector3(x[i], y[i], z[i]) - a
			best = maxf(best, (p - ab * p.dot(ab)).length())
	return best
