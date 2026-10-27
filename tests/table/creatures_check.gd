extends SceneTree

## The gate of [Soundscape]'s CREATURES - animals heard and never seen, made of numbers rather than a kind
## (the table's `sound`, `creatures`) - with no audio device.
##
##   godot --headless --path . --script res://tests/table/creatures_check.gd
##
## - MADE SAFE: one creature written as an object is a list of one; an unknown call is left out with a note,
##   and a creature with no call it can make chirps; past MAX_CREATURES the rest are left out; numbers are held
##   to their ranges; made safe twice reads the same; the vocabulary names every call, the summary the creature.
## - SLICED THE SAME: a hatchlings' bed (two bodies purring, chirping and huffing) is the same rendered at once,
##   in odd slices, and ahead on a worker - against another seed, which is not.
## - EVERY CALL SOUNDS, AND NONE CLIPS: each call alone, while it sounds, stands between -32 and -14 dB over the
##   dial's level, peaks under the ceiling, and is never NaN.
## - A PURR BREATHES: over one long purr, its loudness by the quarter second rises and falls by 10 dB or more as
##   it breathes in and out - against a steady bed (rain on leaves) measured the same way, which swings under 6.
## - A BODY MAKES ONE CALL AT A TIME: over ten minutes of three bodies purring, snoring and huffing, no body's
##   calls overlap, across the plan's windows too - against the calls as drawn, before the rule, which do.
## - WHAT IS SEEN IS WHAT IS HEARD: at every huff [method Soundscape.seen_calls] gives, a huffing place is loud
##   within a third of a second, on a soundscape started at the top and on one started part way, as a scrub
##   starts one - against another seed's huffs, which fall where this place is quiet.
## - A CREATURE ADDED CHANGES NOTHING ELSE: a fire with a creature, less the creature alone, is the fire alone.
## - THE CONTROL: a sound with no creatures (an empty list) is made safe to nothing, is not active, and renders
##   silent - and the same place with a creature in it is active and is not.

var _fails := 0
const SR := 22050


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	for check in [_sanitize, _sliced, _every, _breathes, _one_at_a_time, _seen, _apart, _control]:
		var done: Variant = await (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("creatures_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


static func _rms(pcm: PackedVector2Array, a := 0, b := -1) -> float:
	a = clampi(a, 0, pcm.size())
	b = pcm.size() if b < 0 else clampi(b, a, pcm.size())
	var e := 0.0
	for i in range(a, b):
		e += pcm[i].x * pcm[i].x + pcm[i].y * pcm[i].y
	return sqrt(e / float(maxi(1, 2 * (b - a))))


func _make(sound: Dictionary, seed := 3, dial := 0.5, t0 := 0.0) -> Soundscape:
	var made := Soundscape.of_table({"sound": sound}, seed)
	var sc := Soundscape.new(made["sound"], made["wind"], seed, SR, t0)
	sc.set_level(dial)
	return sc


const HATCHLINGS := {"creatures": [{"name": "two hatchlings by the hearth", "size": 0.15, "breath": 0.7,
	"calls": ["purr", "chirp", "huff"], "count": 2, "rate": 30, "side": -0.4, "near": 0.6, "awake": [0.3, 0.7], "over": 60}]}


func _sanitize() -> bool:
	var notes := PackedStringArray()
	var one := Soundscape.sanitize({"creatures": {"name": "a cat", "calls": ["purr", "meow"], "size": 3, "count": 9}}, notes)
	var cs: Array = one.get("creatures", [])
	_ok(cs.size() == 1, "one creature written as an object is not a list of one: %s" % str(one))
	if cs.size() == 1:
		var c: Dictionary = cs[0]
		_ok(c["calls"] == ["purr"], "an unknown call was kept, or a known one lost: %s" % str(c["calls"]))
		_ok(float(c["size"]) == 1.0 and int(c["count"]) == Soundscape.MAX_BODIES, "the numbers were not held to their ranges: %s" % str(c))
	_ok(", ".join(notes).contains("meow"), "the unknown call was not said: %s" % str(notes))
	var none := Soundscape.sanitize({"creatures": [{"calls": ["roar"]}]})
	_ok((((none.get("creatures", [{}]) as Array)[0] as Dictionary).get("calls", []) as Array) == ["chirp"],
		"a creature with no call it can make does not chirp: %s" % str(none))
	var many: Array = []
	for i in 6:
		many.append({"name": "frog %d" % i, "calls": ["croak"]})
	var more := PackedStringArray()
	var six := Soundscape.sanitize({"creatures": many}, more)
	_ok((six["creatures"] as Array).size() == Soundscape.MAX_CREATURES and not more.is_empty(),
		"past %d creatures the rest were kept, or nothing was said" % Soundscape.MAX_CREATURES)
	var once := Soundscape.sanitize(HATCHLINGS)
	var twice := Soundscape.sanitize(once)
	_ok(str(once) == str(twice), "made safe twice reads otherwise:\n    %s\n    %s" % [str(once), str(twice)])
	var words := Soundscape.describe()
	for k in Soundscape.CALLS:
		_ok(words.contains("- %s:" % k), "the vocabulary does not name the call %s" % k)
	_ok(words.contains("creatures") and Soundscape.summary(once).contains("hatchlings"), "no creatures in the vocabulary, or none in the summary")
	return true


func _sliced() -> bool:
	var n := SR * 20
	var whole := _make(HATCHLINGS).render(n)
	_ok(_rms(whole) > 0.0, "the hatchlings' bed is silent - nothing to compare")
	var sliced := PackedVector2Array()
	var sc := _make(HATCHLINGS)
	var sizes := [1, 37, 4096, 999, 64, 12345]
	var k := 0
	while sliced.size() < n:
		sliced.append_array(sc.render(mini(int(sizes[k % sizes.size()]), n - sliced.size())))
		k += 1
	_ok(whole == sliced, "rendered in slices, the samples differ")
	var ahead := PackedVector2Array()
	var sw := _make(HATCHLINGS)
	while ahead.size() < n:
		sw.prefetch(0.7)
		await process_frame
		ahead.append_array(sw.render(mini(3000, n - ahead.size())))
	sw.finish()
	_ok(whole == ahead, "rendered ahead on a worker, the samples differ")
	_ok(whole != _make(HATCHLINGS, 4).render(n), "the control: another seed sounds the same")
	return true


func _every() -> bool:
	for kind in Soundscape.CALLS:
		var e := 0.0
		var count := 0
		var peak := 0.0
		var nan := false
		for seed in [7, 8]:
			var sound := Soundscape.sanitize({"creatures": [{"calls": [kind], "rate": 40, "near": 0.7, "size": 0.3, "breath": 0.4, "awake": [0.5, 0.5]}]})
			var pcm := _make(sound, seed).render(SR * 30)
			var c: Dictionary = (sound["creatures"] as Array)[0]
			for w in 4:
				for call in Soundscape._calls_in(c, 0, w, seed):
					var a := int(float(call["t"]) * SR)
					var b := mini(pcm.size(), int((float(call["t"]) + float(call["dur"])) * SR))
					if b > a:
						var r := _rms(pcm, a, b)
						e += r * r * float(b - a)
						count += b - a
			for v in pcm:
				peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
				if is_nan(v.x) or is_nan(v.y):
					nan = true
		var level := linear_to_db(sqrt(e / float(maxi(1, count)))) - Soundscape.level_db(0.5)
		_ok(count > 0 and level > -32.0 and level < -14.0, "%s is %.1f dB over the dial's level while it sounds" % [kind, level])
		_ok(peak <= Soundscape.CEILING and not nan, "%s peaks at %.3f%s" % [kind, peak, " and is NaN" if nan else ""])
	return true


## The loudness of [param pcm] from [param a] to [param b] seconds, by the quarter second (dB).
static func _quarters(pcm: PackedVector2Array, a: float, b: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var q := SR / 4
	var i := int(a * SR)
	while i + q <= mini(pcm.size(), int(b * SR)):
		out.append(linear_to_db(maxf(_rms(pcm, i, i + q), 1e-9)))
		i += q
	return out


static func _swing(db: PackedFloat32Array) -> float:
	if db.is_empty():
		return 0.0
	var lo := INF
	var hi := -INF
	for x in db:
		lo = minf(lo, x)
		hi = maxf(hi, x)
	return hi - lo


func _breathes() -> bool:
	var sound := Soundscape.sanitize({"creatures": [{"calls": ["purr"], "rate": 20, "near": 0.8, "size": 0.4, "breath": 0.5, "awake": [0.2, 0.2]}]})
	var c: Dictionary = (sound["creatures"] as Array)[0]
	var purr := {}
	for w in 12:
		for call in Soundscape._calls_in(c, 0, w, 11):
			if purr.is_empty() and (call["parts"] as PackedFloat32Array).size() >= 3:
				purr = call
	_ok(not purr.is_empty(), "no purr of three breaths in two minutes of a purring creature")
	if purr.is_empty():
		return true
	var t := float(purr["t"])
	var end := t + float(purr["dur"])
	var pcm := _make(sound, 11).render(int((end + 1.0) * SR))
	var swing := _swing(_quarters(pcm, t + 0.6, end - 0.6))
	_ok(swing >= 10.0, "a purr of %d breaths rises and falls by only %.1f dB - a steady drone" % [(purr["parts"] as PackedFloat32Array).size(), swing])
	var bed := _make({"rain": {"on": "leaves", "strength": 0.5}}, 11).render(int((end + 1.0) * SR))
	var flat := _swing(_quarters(bed, t + 0.6, end - 0.6))
	_ok(flat < 6.0, "the control: a steady bed of rain swings by %.1f dB as well" % flat)
	return true


## THE OVERLAPS in [param calls] (`[{t, dur, body}]`): how many pairs of one body's calls sound at once.
static func _overlaps(calls: Array) -> int:
	var n := 0
	for i in calls.size():
		for j in range(i + 1, calls.size()):
			var a: Dictionary = calls[i]
			var b: Dictionary = calls[j]
			if int(a["body"]) == int(b["body"]) and float(a["t"]) < float(b["t"]) + float(b["dur"]) and float(b["t"]) < float(a["t"]) + float(a["dur"]):
				n += 1
	return n


func _one_at_a_time() -> bool:
	var c: Dictionary = (Soundscape.sanitize({"creatures": [{"calls": ["purr", "snore", "huff"], "count": 3, "rate": 30,
		"awake": [0.2, 0.6], "over": 600}]})["creatures"] as Array)[0]
	var kept: Array = []
	var drawn: Array = []
	for k in 75:
		kept.append_array(Soundscape._calls_in(c, 0, k, 21))
		drawn.append_array(Soundscape._drawn_in(c, 0, k, 21))
	_ok(kept.size() > 20 and _overlaps(kept) == 0, "of %d calls kept, %d pairs of one body's sound at once" % [kept.size(), _overlaps(kept)])
	_ok(_overlaps(drawn) > 0, "the control: the calls as drawn never overlap either - the rule holds nothing")
	return true


## THE HUFFS heard in [param pcm] (a soundscape whose first sample is at show time [param t0]) at the times
## [param seen]: how many of them are loud, within 14 dB of the loudest, in the third of a second from it.
static func _heard_at(pcm: PackedVector2Array, t0: float, seen: Array) -> int:
	var loudest := 0.0
	var levels := PackedFloat32Array()
	for s in seen:
		var a := int((float((s as Dictionary)["t"]) - t0) * SR)
		var r := _rms(pcm, a, a + SR / 3)
		levels.append(r)
		loudest = maxf(loudest, r)
	var heard := 0
	for r in levels:
		if loudest > 0.0 and linear_to_db(maxf(r, 1e-9)) > linear_to_db(loudest) - 14.0:
			heard += 1
	return heard


func _seen() -> bool:
	var sound := Soundscape.sanitize({"creatures": [{"name": "the hatchlings", "calls": ["huff"], "rate": 12, "count": 2,
		"near": 1.0, "size": 0.2, "awake": [0.5, 0.5]}]})
	# past the soundscape's own fade in (Soundscape.FADE)
	var seen := Soundscape.seen_calls(sound, 5, 2.0, 60.0)
	_ok(seen.size() >= 3, "only %d huffs seen in a minute of a huffing place" % seen.size())
	for s in seen:
		var d: Dictionary = s
		_ok(d.has("side") and d.has("near") and d.has("size") and String(d["call"]) == "huff", "a seen call is not {t, call, side, near, size}: %s" % str(d))
	var pcm := _make(sound, 5).render(SR * 60)
	_ok(_heard_at(pcm, 0.0, seen) == seen.size(), "of %d huffs seen, only %d were heard where they were seen" % [seen.size(), _heard_at(pcm, 0.0, seen)])
	# PART WAY, as a scrub starts one: the huffs past its start, heard where they are seen
	var later := Soundscape.seen_calls(sound, 5, 27.0, 60.0)
	var part := _make(sound, 5, 0.5, 25.0).render(SR * 35)
	_ok(not later.is_empty() and _heard_at(part, 25.0, later) == later.size(), "started part way, the huffs seen are not heard where they are")
	# THE CONTROL: another seed's huffs, where none of this seed's is near, fall where this place is quiet
	var quiet := 0
	var elsewhere := 0
	for s in Soundscape.seen_calls(sound, 6, 0.0, 58.0):
		var t := float((s as Dictionary)["t"])
		var near := false
		for m in seen:
			near = near or absf(float((m as Dictionary)["t"]) - t) < 2.5
		if near:
			continue
		elsewhere += 1
		var a := int(t * SR)
		if linear_to_db(maxf(_rms(pcm, a, a + SR / 3), 1e-9)) < linear_to_db(maxf(_rms(pcm), 1e-9)) - 20.0:
			quiet += 1
	_ok(elsewhere > 0 and quiet == elsewhere, "the control: of %d huffs of another seed away from this one's, only %d fell where it is quiet" % [elsewhere, quiet])
	return true


func _apart() -> bool:
	var fire := {"fire": {"size": 0.5}}
	var both := fire.duplicate(true)
	both["creatures"] = HATCHLINGS["creatures"]
	var n := SR * 12
	var a := _make(both).render(n)
	var b := _make(HATCHLINGS).render(n)
	var c := _make(fire).render(n)
	var most := 0.0
	for i in n:
		most = maxf(most, (a[i] - b[i] - c[i]).abs().length())
	_ok(_rms(b) > 0.0 and most < 1e-5, "a fire with a creature, less the creature, is not the fire alone (off by %.7f)" % most)
	return true


func _control() -> bool:
	var empty := Soundscape.sanitize({"creatures": []})
	_ok(empty.is_empty(), "a sound with an empty list of creatures was not made safe to nothing: %s" % str(empty))
	var off := _make({"creatures": []})
	_ok(not off.active() and _rms(off.render(SR * 10)) == 0.0, "a sound with no creatures is active, or not silent")
	var on := _make(HATCHLINGS)
	_ok(on.active() and _rms(on.render(SR * 20)) > 0.0, "the same place with a creature in it is not active, or silent")
	return true
