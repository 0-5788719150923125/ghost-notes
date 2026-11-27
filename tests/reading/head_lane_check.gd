extends SceneTree

## head_lane_check - the voice placed where the script puts the speaker's head ([HeadMarks], [HeadPlan], next/head.md). It holds:
##
## - a head mark is read with how many spoken words come before it, its own words never spoken, a heading never counted;
## - a mark is timed at the start of the word after it as a take says it, naming its phrase; one whose word is not heard yet is left
##   out; a name the bank has no phrase for is named;
## - a show with a bank is performed whether or not its script calls a phrase (control: with no bank nothing is placed);
## - the lane steps evenly from its first frame to its last, as the chain eases between its points;
## - the chain hands a placed voice to the ear the head leans to: leaning in at the left, the left ear louder (control: with no lane
##   both ears alike); a mouth turned away is duller (less above the muffle's corner, control: facing); a lane is used for one buffer
##   only, as `side` is;
## - the head at the capsule all the way round ([member VoiceFX.ears_at]): a mouth at the left ear is heard there first and louder, one
##   behind (the camera's side) darker than one in front (the chair's) at the same distance (control: at the right, the right ear louder).
##
##   godot --headless --path . --script tests/reading/head_lane_check.gd

var _fails := 0
var _checks := 0


func _init() -> void:
	var bank := HeadBank.phrases_of(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/studio/head_bank.json")))
	var body := "# A title\n\nHello there, my friend.\n<!-- head: Lean In Left -->\nNow I am close to you.\n"
	var d := HeadMarks.read(body)
	_ok((d["marks"] as Array).size() == 1 and int((d["marks"] as Array)[0]["after"]) == 4 and not (d["spoken"] as PackedStringArray).has("left")
		and not (d["spoken"] as PackedStringArray).has("title"), "a mark is read after its four words, its own words and the heading unspoken: %s" % str(d))
	var words: Array = []
	var t := 1.0
	for w in ["Hello", "there,", "my", "friend.", "Now", "I", "am", "close", "to", "you."]:
		words.append({"text": w, "t0": t, "t1": t + 0.3})
		t += 0.4
	var timed := HeadMarks.timed(body, words)
	_ok(timed.size() == 1 and is_equal_approx(float(timed[0]["at"]), 2.6) and timed[0]["name"] == "lean in left", "it is timed at the word after it, naming its phrase: %s" % str(timed))
	_ok(HeadMarks.timed(body, words.slice(0, 3)).is_empty(), "a mark whose word is not heard yet is left out")
	_ok(HeadMarks.unknown(body + "<!-- head: cartwheel -->", bank) == PackedStringArray(["cartwheel"]), "a name the bank has no phrase for is named")
	_ok(not HeadMarks.plan("Hello there, my friend. Now I am close to you.", words, bank).is_empty() and HeadMarks.plan(body, words, []).is_empty(),
		"a show with a bank is performed with no phrase called (control: with no bank, nothing)")

	# leaning in at the left, held: the lane of a plan that calls it at the start
	var plan := HeadPlan.make([{"at": 0.0, "name": "lean in left"}], [], [bank[1]], 1, {}, 0.01)
	var sr := 24000
	var lane := HeadMarks.lane(plan, 0, sr * 6, sr)
	_ok(lane.size() == ceili(float(sr * 6) / VoiceFX.PLACE_STEP) + 1 or lane.size() == ceili(float(sr * 6) / VoiceFX.PLACE_STEP),
		"the lane steps evenly over the frames (%d points)" % lane.size())

	# the chain, placed and not
	var tone := PackedFloat32Array()
	tone.resize(sr * 6)
	for i in tone.size():
		tone[i] = 0.2 * sin(TAU * 220.0 * float(i) / float(sr))
	var placed := _heard(tone, HeadMarks.lane(plan, 0, tone.size(), sr), sr)
	var plain := _heard(tone, PackedVector3Array(), sr)
	_ok(placed.x > placed.y * 1.4, "leaning in at the left, the left ear is louder (%.4f, %.4f)" % [placed.x, placed.y])
	_ok(absf(plain.x - plain.y) < plain.x * 0.02, "control: with no lane both ears alike (%.4f, %.4f)" % [plain.x, plain.y])
	# a bright tone heard with the mouth facing the microphone, then turned away
	var bright := PackedFloat32Array()
	bright.resize(sr * 3)
	for i in bright.size():
		bright[i] = 0.2 * sin(TAU * 5000.0 * float(i) / float(sr))
	var facing := PackedVector3Array()
	var away := PackedVector3Array()
	for i in ceili(float(bright.size()) / VoiceFX.PLACE_STEP) + 1:
		facing.append(Vector3(0.0, 0.0, 0.0))
		away.append(Vector3(0.0, 0.0, 1.0))
	var f_e := _heard(bright, facing, sr)
	var a_e := _heard(bright, away, sr)
	_ok(a_e.x < f_e.x * 0.4, "a mouth turned away is duller: %.5f against %.5f facing" % [a_e.x, f_e.x])
	var fx := VoiceFX.new()
	fx.setup(sr)
	fx.place = lane
	fx.process_stereo(tone.slice(0, 1024))
	_ok(fx.place.is_empty(), "a lane is used for one buffer only")

	# the head at the capsule, all the way round: a click heard from a mouth at the left reaches the left ear first and louder
	var click := PackedFloat32Array()
	click.resize(sr)
	click[sr / 2] = 0.8
	var left := _still(Vector3(-0.3, 0.0, 0.0), click.size())
	var out := _ears(click, left, sr)
	var peak := Vector2i(-1, -1)
	var most := Vector2.ZERO
	for i in out.size():
		if absf(out[i].x) > most.x:
			most.x = absf(out[i].x)
			peak.x = i
		if absf(out[i].y) > most.y:
			most.y = absf(out[i].y)
			peak.y = i
	_ok(peak.x < peak.y and peak.y - peak.x >= roundi(0.0004 * sr) and most.x > most.y * 1.5,
		"a mouth at the left ear is heard there first and louder (%d frames ahead; %.3f against %.3f)" % [peak.y - peak.x, most.x, most.y])
	var front := _ears_energy(bright, _still(Vector3(0.0, 0.0, 0.4), bright.size()), sr)
	var behind := _ears_energy(bright, _still(Vector3(0.0, 0.0, -0.4), bright.size()), sr)
	var mid := _ears_energy(bright, _still(Vector3(0.0, 0.0, 0.4), bright.size()), sr)
	_ok(behind.x < front.x * 0.6 and absf(behind.x - behind.y) < behind.x * 0.05 and is_equal_approx(snappedf(mid.x / front.x, 0.001), 1.0),
		"a mouth behind (the camera's side) is darker than one in front (the chair's) at the same distance, both ears alike (%.5f against %.5f)" % [behind.x, front.x])
	var right := _ears_energy(tone, _still(Vector3(0.3, 0.0, 0.0), tone.size()), sr)
	_ok(right.y > right.x * 2.0, "control: a mouth at the right is louder in the right ear (%.4f, %.4f)" % [right.x, right.y])

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## A mouth held at [param q] (listener frame, m) over [param n] frames, as [member VoiceFX.ears_at] takes it.
func _still(q: Vector3, n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in ceili(float(n) / VoiceFX.PLACE_STEP) + 1:
		out.append(q)
	return out


## [param pcm] through a fresh chain heard by the head at the capsule from [param mouths].
func _ears(pcm: PackedFloat32Array, mouths: PackedVector3Array, sr: int) -> PackedVector2Array:
	var fx := VoiceFX.new()
	fx.setup(sr)
	fx.place = PackedVector3Array()
	fx.place.resize(mouths.size())
	fx.ears_at = mouths
	return fx.process_stereo(pcm.duplicate())


## Each ear's energy over the last two seconds of [param pcm] heard from [param mouths].
func _ears_energy(pcm: PackedFloat32Array, mouths: PackedVector3Array, sr: int) -> Vector2:
	var out := _ears(pcm, mouths, sr)
	var e := Vector2.ZERO
	for i in range(maxi(out.size() - sr * 2, 0), out.size()):
		e += Vector2(out[i].x * out[i].x, out[i].y * out[i].y)
	return e


## The left and right ears' energy over the last two seconds of [param pcm] through a fresh chain, placed by [param lane].
func _heard(pcm: PackedFloat32Array, lane: PackedVector3Array, sr: int) -> Vector2:
	var fx := VoiceFX.new()
	fx.setup(sr)
	fx.place = lane
	var out := fx.process_stereo(pcm.duplicate())
	var e := Vector2.ZERO
	for i in range(out.size() - sr * 2, out.size()):
		e += Vector2(out[i].x * out[i].x, out[i].y * out[i].y)
	return e


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
	print(("ok    " if cond else "FAIL  ") + what)
