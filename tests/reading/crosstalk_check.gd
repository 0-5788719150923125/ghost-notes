extends SceneTree

## crosstalk_check - voices over each other (next/tabletop.md). Holds the marks through the whole road: read
## out of a script, kept by a reading's own walk, carried by the plan, placed by the one join on a side track
## at the frame it says, its words on the same clock and in the sentence they overlap; and heard: both voices
## in the mix, each in its own ear, the room hearing both. A live window holds a chunk until what overlaps it
## is here. Controls: a script with no mark reads as it always did, frame for frame, and a line over the
## opening of a take has nothing to come in over.
##
##     godot --headless --path . --script tests/reading/crosstalk_check.gd

const SR := 22050
var fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _init() -> void:
	_marks()
	_plan()
	_join()
	_heard()
	_card_reading()
	_hold()
	print("crosstalk_check: ", "ok" if fails == 0 else "%d failed" % fails)
	quit(1 if fails > 0 else 0)


const ASK := {"reader": "Dell", "hesitate": true, "bare": 1.0, "outro": 0.0}
const SCRIPT := "<!-- speaker: Narrator -->\nThe door opens slowly.\n\n<!-- speaker: Bea -->\n<!-- over: 0.6 -->\nIs it a bear?\n\n<!-- speaker: Milo -->\n<!-- together -->\nOh no.\n\n<!-- speaker: Rosa -->\n<!-- over -->\nPlease not a bear. Anything else.\n\n<!-- speaker: Narrator -->\nIt is a bear."


func _marks() -> void:
	_check(Manuscript._rx(Manuscript.OVER).search("<!-- over -->") != null, "a bare over reads")
	_check(Manuscript._rx(Manuscript.OVER).search("<!-- over: 1.5 -->").get_string(1) == "1.5", "an over's seconds read")
	_check(Manuscript._rx(Manuscript.TOGETHER).search("<!-- together -->") != null, "together reads")
	_check(Manuscript._rx(Manuscript.OVER).search("<!-- overture -->") == null, "a comment that only begins so is no mark")


func _chunks(script := SCRIPT) -> Array:
	return ReadingPlan.make(script, "", ASK)["chunks"]


func _plan() -> void:
	var chunks := _chunks()
	_check(chunks.size() == 6, "six sentences: %d" % chunks.size())
	_check(not ReadingJoin.overlaps(chunks[0]), "the first line overlaps nothing")
	_check(is_equal_approx(float(chunks[1].get("over", -1.0)), 0.6), "Bea's turn comes in 0.6 s over")
	_check(String(chunks[1]["speaker"]) == "Bea", "...and is hers")
	_check(bool(chunks[2].get("together", false)), "Milo's comes in together")
	_check(is_equal_approx(float(chunks[3].get("over", -1.0)), Manuscript.OVER_BARE), "a bare over takes the usual overlap")
	_check(not ReadingJoin.overlaps(chunks[4]), "a turn's second sentence follows it, and overlaps nothing")
	_check(not ReadingJoin.overlaps(chunks[5]), "a turn with no mark is what it always was")
	var s0 := int(((chunks[0] as Dictionary)["words"] as Array)[0]["sentence"])
	_check(int(((chunks[1] as Dictionary)["words"] as Array)[0]["sentence"]) == s0, "what comes in over a sentence shows with it")
	_check(int(((chunks[5] as Dictionary)["words"] as Array)[0]["sentence"]) != s0, "and the next goes on as its own")
	var none := ReadingPlan.make("<!-- speaker: Narrator -->\nOne thing.\n\n<!-- speaker: Bea -->\nAnother thing.", "", ASK)["chunks"] as Array
	_check(not ReadingJoin.overlaps(none[0]) and not ReadingJoin.overlaps(none[1]), "the control: no mark, no overlap")


func _tone(seconds: float, hz: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * float(SR)))
	for i in out.size():
		out[i] = sin(TAU * hz * float(i) / float(SR)) * 0.25
	return out


func _spans(ch: Dictionary, seconds: float) -> Array:
	var words: Array = ch["words"]
	var out: Array = []
	for k in words.size():
		var d: Dictionary = words[k]
		out.append({"index": int(d["index"]), "t0": seconds * float(k) / float(words.size()), "t1": seconds * float(k + 1) / float(words.size())})
	return out


const SETTINGS := {"pause": 1.0, "pace": 1.0, "tone": 0}


func _settings() -> Dictionary:
	return {"voice": "x", "speaker": 0, "tone": 0, "pace": 1.0, "pause": 1.0, "dynamics": 0.5, "arc": 0.4, "effort": 0.35, "echo": 0.0, "room": 0.0, "resonance": 0.0, "presence": 1.0, "ambience": 0.0, "lean": 0.0, "near": 0.0, "seat": 0.0, "ink": ""}


func _join() -> void:
	var chunks := _chunks()
	var j := ReadingJoin.new(SR, [])
	var s := _settings()
	var lens := [2.0, 1.0, 0.5, 1.2, 1.0, 1.0]
	var line := PackedFloat32Array()
	for k in chunks.size():
		line.append_array(j.add(chunks, k, _tone(lens[k], 220.0 + 40.0 * float(k)), _spans(chunks[k], lens[k]), s, 0.2))
		_check(line.size() == j.frames, "the line holds as many frames as the join says, after %d: %d, %d" % [k, line.size(), j.frames])
	_check(j.side.size() == 3, "three turns on the side track: %d" % j.side.size())
	var first_end := int(j.chunk_at[0]) + int(2.0 * float(SR))
	var bea: Dictionary = j.side[0]
	_check(int(bea["at"]) == first_end - int(0.6 * float(SR)), "Bea comes in 0.6 s before the first line ends: %d" % int(bea["at"]))
	_check(String(bea["speaker"]) == "Bea", "the side track says who")
	var milo: Dictionary = j.side[1]
	var after := float(int(milo["at"]) - int(j.chunk_at[0])) / float(SR)
	_check(after >= ReadingJoin.TOGETHER_LEAST - 0.001 and after <= ReadingJoin.TOGETHER_MOST + 0.001, "Milo comes in with the line's start, a reaction apart: %.3f" % after)
	# the words: on the take's clock, overlapping
	var by_who := {}
	for w in j.words:
		var d: Dictionary = w
		var who := String(d["speaker"])
		if not by_who.has(who):
			by_who[who] = float(d["t0"])
	_check(is_equal_approx(float(by_who["Bea"]), float(bea["at"]) / float(SR)), "Bea's words start where her voice does")
	var dell_last := 0.0
	for w in j.words:
		if String((w as Dictionary)["speaker"]) == "Dell" and float((w as Dictionary)["sentence"]) == float((j.words[0] as Dictionary)["sentence"]):
			dell_last = maxf(dell_last, float((w as Dictionary)["t1"]))
	_check(float(by_who["Bea"]) < dell_last, "...before the first line's last word is done")
	# what follows waits for what overlaps: the line is as long as the longest voice
	var rosa: Dictionary = j.side[2]
	var rosa_end := int(rosa["at"]) + (rosa["pcm"] as PackedFloat32Array).size()
	_check(j.frames >= rosa_end, "the take runs as far as anyone said anything")
	_check(int(j.chunk_at[4]) >= rosa_end, "the next on the line waits for what overlaps: %d, %d" % [int(j.chunk_at[4]), rosa_end])
	# the control: nothing to come in over at a take's opening
	var alone := ReadingPlan.make("<!-- speaker: Bea -->\n<!-- over: 0.5 -->\nBea is first.", "", ASK)["chunks"] as Array
	var j2 := ReadingJoin.new(SR, [])
	var got := j2.add(alone, 0, _tone(1.0, 300.0), _spans(alone[0], 1.0), s, 0.2)
	_check(j2.side.is_empty() and got.size() == int(1.0 * float(SR)), "a line over nothing is simply the line")
	# the control: a script with no marks joins as ever
	var plain := ReadingPlan.make("<!-- speaker: Narrator -->\nOne.\n\n<!-- speaker: Bea -->\nTwo.", "", ASK)["chunks"] as Array
	var j3 := ReadingJoin.new(SR, [])
	var total := 0
	for k in plain.size():
		total += j3.add(plain, k, _tone(1.0, 300.0), _spans(plain[k], 1.0), s, 0.2).size()
	_check(j3.side.is_empty() and total == j3.frames, "the control: no marks, no side track")


## Heard: run through the chain, a voice sits in its own ear, the room hears it, and it is really in the take.
func _heard() -> void:
	var seat_of := func(who: String) -> float: return -1.0 if who == "Bea" else 1.0
	var j := ReadingJoin.new(SR, [])
	var chunks := _chunks("<!-- speaker: Narrator -->\nThe door opens.\n\n<!-- speaker: Bea -->\n<!-- over: 0.5 -->\nA bear.")
	var s := _settings()
	var line := j.add(chunks, 0, PackedFloat32Array(_silence(1.0)), _spans(chunks[0], 1.0), s, 0.2)
	line.append_array(j.add(chunks, 1, _tone(1.0, 300.0), _spans(chunks[1], 1.0), s, 0.2))
	var sides := j.side_between(0, line.size(), seat_of)
	_check(sides.size() == line.size(), "the side voices cover what they are asked of")
	var l := 0.0
	var r := 0.0
	for v in sides:
		l += absf(v.x)
		r += absf(v.y)
	_check(l > r * 1.5, "Bea, at the left, is louder in the left: %.0f, %.0f" % [l, r])
	var fx := VoiceFX.new()
	fx.setup(SR)
	fx.side = sides
	var out := fx.process_stereo(line.duplicate())
	var ol := 0.0
	var or_ := 0.0
	for v in out:
		ol += absf(v.x)
		or_ += absf(v.y)
	_check(ol > 10.0, "the voice over the line is in the take: %.1f" % ol)
	_check(ol > or_ * 1.3, "...and in her own ear after the chain: %.0f, %.0f" % [ol, or_])
	_check(fx.side.is_empty(), "a buffer's side voices are taken once")
	# a voice's own seat: the direct voice moves, the same way
	var seat := VoiceFX.new()
	seat.setup(SR)
	seat.seat = 1.0
	var placed := seat.process_stereo(_tone(0.5, 300.0))
	var pl := 0.0
	var pr := 0.0
	for v in placed:
		pl += absf(v.x)
		pr += absf(v.y)
	_check(pr > pl * 1.5, "a voice at the right is heard at the right: %.0f, %.0f" % [pl, pr])
	var mid := VoiceFX.new()
	mid.setup(SR)
	var centered := mid.process_stereo(_tone(0.2, 300.0))
	var diff := 0.0
	for v in centered:
		diff += absf(v.x - v.y)
	_check(diff < 0.001, "the control: at the middle, with nobody over it, both ears hear the same")
	_check(is_equal_approx(Delivery.pan_of_seat(90.0), 1.0) and is_equal_approx(Delivery.pan_of_seat(-90.0), -1.0) and absf(Delivery.pan_of_seat(0.0)) < 0.001, "a seat is an ear")


func _silence(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * float(SR)))
	return out


## A table's reading keeps them, and a game's mark does not hand the voice back.
func _card_reading() -> void:
	var body := "<!-- table: begin -->\n\n<!-- speaker: Milo -->\nI kick it.\n\n<!-- table: roll 3 -->\n\nNineteen!\n\n<!-- speaker: Bea -->\n<!-- over: 0.4 -->\nOh no."
	var p := CardReading.parse(body)
	_check(String(p["speakable"]).contains("<!-- over: 0.4 -->"), "a table's reading keeps an over for the voice")
	var kinds: Array = (p["actions"] as Array).map(func(a: Dictionary) -> String: return String(a["kind"]))
	_check(kinds.has("roll"), "a roll is one of its moves")
	_check(int(p["cards"]) == 0, "a roll's number is no card")
	var speak := String(p["speakable"])
	var at := speak.find("Nineteen")
	var head := speak.substr(0, at)
	_check(head.rfind("<!-- speaker: Milo -->") > head.rfind("<!-- speaker: Narrator -->"), "after the dice, whoever was speaking still is")
	var chunks := ReadingPlan.make(speak, "", ASK)["chunks"] as Array
	var found := false
	for c in chunks:
		found = found or is_equal_approx(float((c as Dictionary).get("over", -1.0)), 0.4)
	_check(found, "and the plan sees it, through the table's own reading")


## A live window holds: a chunk does not go out while what overlaps it is not here.
func _hold() -> void:
	var chunks := _chunks()
	_check(not ReadingJoin.overlaps_ready(chunks, 0, [{"index": 0}]), "the first line waits for what comes in over it")
	_check(not ReadingJoin.overlaps_ready(chunks, 0, [{"index": 0}, {"index": 1}, {"index": 2}]), "...for all of it")
	_check(ReadingJoin.overlaps_ready(chunks, 0, [{"index": 0}, {"index": 1}, {"index": 2}, {"index": 3}]), "...and goes once it is here")
	_check(ReadingJoin.overlaps_ready(chunks, 4, [{"index": 4}]), "the control: what nothing overlaps does not wait")
