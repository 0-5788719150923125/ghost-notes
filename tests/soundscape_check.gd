extends SceneTree

## The gate of [Soundscape] - what a place sounds like behind the reader - with no audio device.
##
##   godot --headless --path . --script res://tests/soundscape_check.gd
##
## - MADE SAFE: nothing written is `{}`; a part that is not an object, an unknown part or kind is left
##   out or falls back, with a note; a sound made safe reads the same made safe again (an opening's
##   `from` and a wind of its own included).
## - THE AGENT DECIDES: a table whose light has a wind and whose sound says nothing of it is silent;
##   a sound's wind on such a table is planned exactly as [TableMedium] plans it - the same gusts.
## - NEVER TO NOTHING: a light breeze through eaves (the episode reported going silent between gusts)
##   ebbs and flows - its quietest half second within the floor of its loud ones - and still flows:
##   its loud half seconds stand well above its quiet ones.
## - NO CHURN: the breeze's loudness over 10 ms wobbles little round its own 0.6 s average - against the
##   same breeze with its rumble made of the old near-subsonic brown noise, which churned (reported as
##   "a dishwasher or a washing machine").
## - A GUST COMES IN AS A FADE DOES: the place's loudness (over a second) never climbs faster than
##   8 dB a second - against the plan's own gusts heard raw (their speed through the same loudness law),
##   which climb far faster.
## - A SPACE: a sound at one point (a fire's crackles) comes back from round about - its ears less
##   alike, and its tail lasting past each crackle - against the same fire with no space, dry.
## - IT FOLLOWS THE WIND: with every strong gust of the table's wind the trees' sound rises, from just
##   before it starts to just after its height - against the same place heard on another seed's wind.
## - WHERE IT IS HEARD: a wind from the right is louder in the right ear, from the left in the left;
##   heard through an opening on the right it is louder on the right whichever way it blows - and in
##   BOTH ears: no half second of a place set to one side is more than 8 dB from one ear to
##   the other (nor less than 2 dB: it is still to one side).
## - SLICED THE SAME: the samples are the same rendered at once, in odd slices, or ahead on a worker.
## - THE DIAL: 0 is silence; louder as it rises; never past the ceiling alone.
## - IT STEPS BACK FOR THE VOICE: under speech the place is quieter than in the gaps - against the
##   same place with no voice, which is not.
## - EVERY PART SOUNDS: each part and kind alone is heard at the dial's middle, in a sane range, and
##   none is NaN.

var _fails := 0
const SR := 22050


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	for check in [_sanitize, _table_wind, _floor, _churn, _entry, _space, _follows, _sides, _sliced, _dial, _duck, _every]:
		var done: Variant = await (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("soundscape_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


static func _rms(pcm: PackedVector2Array, a := 0, b := -1) -> Vector2:
	if b < 0:
		b = pcm.size()
	var l := 0.0
	var r := 0.0
	for i in range(a, b):
		l += pcm[i].x * pcm[i].x
		r += pcm[i].y * pcm[i].y
	var n := float(maxi(1, b - a))
	return Vector2(sqrt(l / n), sqrt(r / n))


static func _corr(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var n := mini(a.size(), b.size())
	var ma := 0.0
	var mb := 0.0
	for i in n:
		ma += a[i]
		mb += b[i]
	ma /= n
	mb /= n
	var sab := 0.0
	var saa := 0.0
	var sbb := 0.0
	for i in n:
		sab += (a[i] - ma) * (b[i] - mb)
		saa += (a[i] - ma) * (a[i] - ma)
		sbb += (b[i] - mb) * (b[i] - mb)
	return sab / sqrt(maxf(1e-12, saa * sbb))


func _make(sound: Dictionary, wind: Dictionary, seed := 3, dial := 0.5) -> Soundscape:
	var table := {"sound": sound}
	if not wind.is_empty():
		table["light"] = {"wind": wind}
	var made := Soundscape.of_table(table, seed)
	var sc := Soundscape.new(made["sound"], made["wind"], seed, SR, 0.0)
	sc.set_level(dial)
	return sc


func _sanitize() -> bool:
	_ok(Soundscape.sanitize(null).is_empty() and Soundscape.sanitize({}).is_empty(), "nothing written is not {}")
	var notes := PackedStringArray()
	var s := Soundscape.sanitize({"wind": "loud", "water": {"kind": "lake"}, "thunder": {}, "fire": {"size": 9}}, notes)
	_ok(not s.has("wind"), "a wind that is not an object was kept")
	_ok(String((s["water"] as Dictionary)["kind"]) == "shore", "an unknown water kind did not fall back to shore")
	_ok(float((s["fire"] as Dictionary)["size"]) == 1.0, "a fire's size was not clamped to 1")
	_ok(notes.size() >= 3, "what had to change was not said: %s" % str(notes))
	var raw := {"why": "a gale", "wind": {"through": "eaves", "from": "right", "strength": 0.8, "gusts": 0.9, "every": 9},
		"rain": {"on": "window", "strength": 0.6}, "insects": {"kind": "crickets"}}
	var once := Soundscape.sanitize(raw)
	var twice := Soundscape.sanitize(once)
	_ok(str(once) == str(twice), "made safe twice reads otherwise:\n    %s\n    %s" % [str(once), str(twice)])
	_ok(float((once["wind"] as Dictionary)["from"]) == 90.0 and (once["wind"] as Dictionary).has("strength"),
		"the opening or the wind of its own was lost: %s" % str(once["wind"]))
	_ok(not Soundscape.describe().is_empty() and Soundscape.summary(once).contains("rain"), "no vocabulary, or no summary")
	return true


func _table_wind() -> bool:
	var wind := {"from": "left", "strength": 0.5, "gusts": 0.7, "every": 12}
	_ok((Soundscape.of_table({"light": {"wind": wind}}, 9)["sound"] as Dictionary).is_empty(),
		"a table with a wind and no sound makes a sound the agent never wrote")
	var made := Soundscape.of_table({"light": {"wind": wind}, "sound": {"wind": {"through": "trees"}}}, 9)
	_ok((made["sound"] as Dictionary).get("wind") is Dictionary, "a sound's wind is not heard")
	var table_plan := Winds.plan(Lights.sanitize({"wind": wind})["wind"], hash([9, "wind"]))
	_ok(str(made["wind"]["starts"]) == str(table_plan["starts"]) and str(made["wind"]["peaks"]) == str(table_plan["peaks"]),
		"the wind heard is not the table's wind")
	var other: Dictionary = Soundscape.of_table({"light": {"wind": wind}, "sound": {"wind": {}}}, 10)["wind"]
	_ok(str(other["starts"]) != str(table_plan["starts"]), "the control: another seed planned the same gusts")
	_ok((Soundscape.of_table({}, 9)["sound"] as Dictionary).is_empty(), "a table with no wind and no sound makes a sound")
	return true


func _floor() -> bool:
	# the reported table: an autumn breeze outside a post office's glass door, through eaves
	var wind := {"every": 14.0, "from": "right", "gusts": 0.6, "strength": 0.3}
	for d in [0.5, 1.0]:
		var sc := _make({"wind": {"from": "right", "level": 0.3, "through": "eaves"}}, wind, 709583, d)
		var pcm := sc.render(SR * 120)
		var lv := PackedFloat32Array()
		var win := SR / 2
		# from after the fade in
		for k in range(4, pcm.size() / win):
			lv.append(linear_to_db(_rms(pcm, k * win, (k + 1) * win).length() + 1e-9))
		lv.sort()
		var quiet := lv[0]
		var loud := lv[int(lv.size() * 0.9)]
		_ok(loud - quiet < 18.0, "at %.1f the breeze falls %.1f dB below its loud moments between gusts" % [d, loud - quiet])
		_ok(loud - lv[int(lv.size() * 0.1)] > 4.0, "at %.1f the breeze does not ebb and flow (%.1f dB)" % [d, loud - lv[int(lv.size() * 0.1)]])
		_ok(quiet > -60.0, "at %.1f the breeze is near silence at its quietest (%.1f dBFS)" % [d, quiet])
	return true


static func _flutter(pcm: PackedVector2Array) -> float:
	var env := PackedFloat32Array()
	var w := SR / 100
	for k in pcm.size() / w:
		env.append(linear_to_db(_rms(pcm, k * w, (k + 1) * w).length() + 1e-9))
	var f := 0.0
	var n := 0
	for k in range(300, env.size() - 30):
		var m := 0.0
		for j in range(k - 30, k + 30):
			m += env[j]
		f += pow(env[k] - m / 60.0, 2.0)
		n += 1
	return sqrt(f / float(maxi(n, 1)))


func _churn() -> bool:
	var wind := {"every": 14.0, "from": "right", "gusts": 0.6, "strength": 0.3}
	var place := {"wind": {"from": "right", "level": 0.3, "through": "eaves"}}
	var calm := _flutter(_make(place, wind, 709583).render(SR * 60))
	var old := _make(place, wind, 709583)
	var low: Soundscape.Band = old._w["low"]
	low.leak = 0.997
	low.leak_in = 0.06
	# the old rumble, as loud beside the rush as it was
	var churned := _flutter(_louder_low(old).render(SR * 60))
	_ok(calm < 2.5, "the breeze wobbles %.2f dB round its own average" % calm)
	_ok(churned > calm + 1.0, "the control: the old rumble churns no more (%.2f dB against %.2f)" % [churned, calm])
	return true


## The old rumble's level: 3 times the new one (0.28 against 0.09), as it was when it churned.
static func _louder_low(sc: Soundscape) -> Soundscape:
	(sc._w["low"] as Soundscape.Band).steady = 3.1
	return sc


## EVERY STRONG GUST IS HEARD AS IT IS SEEN: from just before it starts to just after its height, the
## sound rises - the place holds a gust and lets it go slowly, so its loudness no longer tracks the
## plan's speed sample for sample, but it comes up with every gust the leaves and petals show.
## The steepest climb of [param db] (a loudness every 50 ms) once smoothed over a second, in dB/s.
static func _steepest(db: PackedFloat32Array) -> float:
	var most := 0.0
	var prev := INF
	for k in range(20, db.size()):
		var m := 0.0
		for j in range(k - 20, k):
			m += db[j]
		m /= 20.0
		if prev != INF:
			most = maxf(most, (m - prev) / 0.05)
		prev = m
	return most


func _entry() -> bool:
	var wind := {"from": "back", "strength": 0.45, "gusts": 0.9, "every": 10}
	for d in [0.5, 1.0]:
		var made := Soundscape.of_table({"light": {"wind": wind}, "sound": {"wind": {"through": "open"}}}, 21)
		var sc := Soundscape.new(made["sound"], made["wind"], 21, SR, 0.0)
		sc.set_level(d)
		var pcm := sc.render(SR * 180)
		var heard := PackedFloat32Array()
		var raw := PackedFloat32Array()
		var w := SR / 20
		for k in range(60, pcm.size() / w):
			heard.append(linear_to_db(_rms(pcm, k * w, (k + 1) * w).length() + 1e-9))
			raw.append(20.0 * 1.1 * lerpf(0.55, 1.5, d) * log(maxf(0.01, Winds.speed_at(made["wind"], k * 0.05))) / log(10.0))
		var a := _steepest(heard)
		var b := _steepest(raw)
		_ok(a < 8.0, "at %.1f a gust comes in at %.1f dB/s" % [d, a])
		_ok(b > a * 1.5, "the control: the plan's raw gusts climb only %.1f dB/s against %.1f" % [b, a])
	return true


static func _likeness(pcm: PackedVector2Array) -> float:
	var lr := 0.0
	var ll := 0.0
	var rr := 0.0
	for v in pcm:
		lr += v.x * v.y
		ll += v.x * v.x
		rr += v.y * v.y
	return lr / sqrt(maxf(1e-12, ll * rr))


func _space() -> bool:
	var place := {"fire": {"size": 0.7, "from": "front", "distance": 0.0}}
	var roomy := _make(place, {}).render(SR * 20)
	var dry_sc := _make(place, {})
	var dry := PackedVector2Array()
	while dry.size() < SR * 20:
		dry_sc._wet = 0.0
		dry.append_array(dry_sc.render(4096))
	var a := _likeness(roomy)
	var b := _likeness(dry)
	_ok(b - a > 0.05, "the space leaves a sound at one point as alike in both ears (%.2f) as dry (%.2f)" % [a, b])
	return true


func _follows() -> bool:
	var wind := {"from": "back", "strength": 0.45, "gusts": 0.8, "every": 10}
	var made := Soundscape.of_table({"light": {"wind": wind}, "sound": {"wind": {"through": "trees"}}}, 5)
	var other: Dictionary = Soundscape.of_table({"light": {"wind": wind}, "sound": {"wind": {"through": "trees"}}}, 6)["wind"]
	var heard := Soundscape.new(made["sound"], made["wind"], 5, SR, 0.0).render(SR * 180)
	var elsewhere := Soundscape.new(made["sound"], other, 5, SR, 0.0).render(SR * 180)
	var plan: Dictionary = made["wind"]
	var peaks: PackedFloat32Array = plan["peaks"]
	var sorted := peaks.duplicate()
	sorted.sort()
	var strong := sorted[sorted.size() / 2]
	var rose := 0
	var rose_else := 0
	var n := 0
	for g in peaks.size():
		var span := Winds.gust_span(plan, g)
		if peaks[g] < strong or span.x < 3.0 or span.z + 1.0 > 178.0:
			continue
		n += 1
		var a := int((span.x - 0.8) * SR)
		var b := int((span.z + 0.2) * SR)
		var w := SR / 2
		if linear_to_db(_rms(heard, b, b + w).length()) - linear_to_db(_rms(heard, a, a + w).length()) > 2.0:
			rose += 1
		if linear_to_db(_rms(elsewhere, b, b + w).length()) - linear_to_db(_rms(elsewhere, a, a + w).length()) > 2.0:
			rose_else += 1
	_ok(n >= 5, "too few strong gusts to judge (%d)" % n)
	_ok(float(rose) >= 0.8 * n, "the sound rose with %d of %d strong gusts" % [rose, n])
	_ok(float(rose_else) < 0.6 * n, "the control: another wind's sound rose with %d of %d of these gusts" % [rose_else, n])
	return true


func _sides() -> bool:
	for pair in [["right", 1.0], ["left", -1.0]]:
		var sc := _make({"wind": {"through": "open"}}, {"from": pair[0], "strength": 0.6, "gusts": 0.6, "every": 12})
		var e := _rms(sc.render(SR * 30))
		var db := linear_to_db(e.y) - linear_to_db(e.x)
		_ok(db * float(pair[1]) > 1.5, "a wind from the %s is %.1f dB right of left" % [pair[0], db])
	# through a window on the right, a wind from the left is heard on the right
	var win := _make({"wind": {"through": "open", "from": "right"}}, {"from": "left", "strength": 0.6, "gusts": 0.6, "every": 12})
	var w := _rms(win.render(SR * 30))
	_ok(linear_to_db(w.y) - linear_to_db(w.x) > 3.0, "heard through an opening on the right, it is %.1f dB right of left" %
		(linear_to_db(w.y) - linear_to_db(w.x)))
	# ...and in BOTH ears: no half second of a sound set wholly to one side, heard alone, leaves an ear far
	# behind - each alone, since sounds on both sides together would balance and prove nothing
	var wind := {"from": "right", "strength": 0.6, "gusts": 0.8, "every": 10}
	for aside in [{"wind": {"through": "eaves", "from": "right"}}, {"water": {"kind": "hull", "from": "right"}},
			{"fire": {"from": "left", "distance": 0.0}}, {"stream": {"from": "right"}}]:
		var pcm := _make(aside, wind).render(SR * 20)
		var worst := 0.0
		var half := SR / 2
		for k in pcm.size() / half:
			var e := _rms(pcm, k * half, (k + 1) * half)
			if e.length() > 1e-5:
				worst = maxf(worst, absf(linear_to_db(e.y + 1e-9) - linear_to_db(e.x + 1e-9)))
		_ok(worst > 2.0 and worst < 8.0, "%s: one ear is up to %.1f dB louder than the other" % [str(aside), worst])
	return true


func _sliced() -> bool:
	var place := {"wind": {"through": "rigging"}, "water": {"kind": "hull", "size": 0.7}, "rain": {"on": "canvas", "strength": 0.5},
		"fire": {"size": 0.6}, "insects": {"kind": "crickets"}}
	var wind := {"from": "right", "strength": 0.6, "gusts": 0.8, "every": 8}
	var n := SR * 12
	var whole := _make(place, wind).render(n)
	var sliced := PackedVector2Array()
	var sc := _make(place, wind)
	var sizes := [1, 37, 4096, 999, 64, 12345]
	var k := 0
	while sliced.size() < n:
		sliced.append_array(sc.render(mini(int(sizes[k % sizes.size()]), n - sliced.size())))
		k += 1
	_ok(whole == sliced, "rendered in slices, the samples differ")
	# ahead on a worker
	var ahead := PackedVector2Array()
	var sw := _make(place, wind)
	while ahead.size() < n:
		sw.prefetch(0.7)
		await process_frame
		ahead.append_array(sw.render(mini(3000, n - ahead.size())))
	sw.finish()
	_ok(whole == ahead, "rendered ahead on a worker, the samples differ")
	var other := _make(place, wind, 4).render(n)
	_ok(whole != other, "the control: another seed sounds the same")
	return true


func _dial() -> bool:
	var place := {"water": {"kind": "shore", "size": 0.8}, "rain": {"on": "roof", "strength": 0.8}}
	var off := _make(place, {}, 3, 0.0).render(SR * 5)
	_ok(_rms(off).length() == 0.0, "the dial at 0 is not silent")
	var last := 0.0
	for d in [0.1, 0.5, 1.0]:
		var pcm := _make(place, {}, 3, d).render(SR * 30)
		var level := _rms(pcm).length()
		_ok(level > last * 1.4, "the dial at %.1f is not louder than below it (%.4f after %.4f)" % [d, level, last])
		last = level
		var peak := 0.0
		for v in pcm:
			peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
		_ok(peak <= Soundscape.CEILING * 1.001, "at %.1f a place alone peaks at %.3f, past the ceiling" % [d, peak])
	return true


func _duck() -> bool:
	var place := {"rain": {"on": "leaves", "strength": 0.5}}
	var n := SR * 8
	# a voice: two seconds speaking, two quiet, twice
	var voice := PackedVector2Array()
	voice.resize(n)
	for i in n:
		var speaking := int(float(i) / SR / 2.0) % 2 == 0
		var x := 0.5 * sin(TAU * 180.0 * float(i) / SR) if speaking else 0.0
		voice[i] = Vector2(x, x)
	var under := _make(place, {}).mix(voice)
	var alone := _make(place, {}).mix(PackedVector2Array(voice).duplicate())
	var bare := _make(place, {}).render(n)
	for i in n:
		under[i] -= voice[i]
	# speech: 0.5-2 s; the gap: 3.0-4 s (after the duck has let go)
	var in_speech := _rms(under, int(0.5 * SR), 2 * SR).length()
	var in_gap := _rms(under, 3 * SR + SR / 2, 4 * SR).length()
	var bare_speech := _rms(bare, int(0.5 * SR), 2 * SR).length()
	var bare_gap := _rms(bare, 3 * SR + SR / 2, 4 * SR).length()
	_ok(linear_to_db(in_gap) - linear_to_db(in_speech) > 3.0, "under speech the place is only %.1f dB quieter than in the gaps" %
		(linear_to_db(in_gap) - linear_to_db(in_speech)))
	_ok(absf(linear_to_db(bare_gap) - linear_to_db(bare_speech)) < 1.5, "the control: with no voice the place dips there anyway")
	_ok(alone.size() == n, "mix changed the length")
	return true


func _every() -> bool:
	var wind := {"from": "left", "strength": 0.5, "gusts": 0.7, "every": 12}
	var places: Array = []
	for t in Soundscape.THROUGH:
		places.append([{"wind": {"through": t}}, wind])
	for k in Soundscape.WATERS:
		places.append([{"water": {"kind": k}}, {}])
	for k in Soundscape.RAINS:
		places.append([{"rain": {"on": k}}, {}])
	places.append([{"fire": {}}, {}])
	places.append([{"stream": {}}, {}])
	for k in Soundscape.INSECTS:
		places.append([{"insects": {"kind": k}}, {}])
	for p in places:
		var pcm := _make(p[0], p[1]).render(SR * 20)
		var level := linear_to_db(_rms(pcm).length() / sqrt(2.0))
		var nan := false
		for v in pcm:
			if is_nan(v.x) or is_nan(v.y):
				nan = true
				break
		_ok(not nan and level > -48.0 and level < -22.0, "%s is %.1f dBFS%s" % [str(p[0]), level, " and NaN" if nan else ""])
	return true
