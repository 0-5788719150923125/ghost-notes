extends SceneTree

## Gate for the desk's sound ([DispatchSounds], next/dispatch.md). It holds:
##
## - the jet's pitch falls as it passes (the Doppler factor c / (c - v cos), falling all the way through) and it is loudest
##   overhead; it fades slowly away under the words after it, quieter each second to all but nothing (the control: as the words
##   come back it is still well heard);
## - the storms differ: Io-B's pops are spiky (peak far over level), Io-A's surf is smooth swells; both are heard over the
##   receiver's hiss;
## - a voice over the receiver: the storm is brought down under it and is whole again past it (the control: the same stretch
##   with no voice is its storm, unchanged), heard there over the bare hiss; the needle swells within a word and is still
##   between two;
## - subdued: a phone flipped and snapped, keys, the ping, the toggle, the mug set down, the gain knob's click, the lamp's
##   switch, the earpiece ring and the terminal's bell are none louder than the desk's most;
## - the bell is one short beep, heard over the hiss while it sounds and gone when it ends;
## - a sound made from its words is heard where the plan puts it, its peak at what the voice waits for (the control: its frames
##   not read yet, only the hiss);
## - a pure function of the schedule: the same plan made twice is the same sound, sample for sample;
## - Io-B's clusters ease into each other, never switched (the control: switched a quarter second at a time, they jump), so the
##   hiss they open never pulses;
## - the receiver as loud as the Environment says: at 0 its hiss and storms are silent (the control: as made, heard);
## - control: with nothing planned there is only the hiss, and it is faint.
##
## Run: godot --headless --path . --script tests/dispatch/dispatch_sounds_check.gd

const RATE := DispatchSounds.RATE

var _fails: Array = []


## A desk with nothing but a sound plan.
class Plan extends RefCounted:
	var plan: Array = []

	func sound_plan() -> Array:
		return plan

	func sound_rev() -> int:
		return 1


func _init() -> void:
	# jet
	var waits := float(DispatchSounds.SOUNDS["jet"]["secs"])
	var span := waits + float(DispatchSounds.SOUNDS["jet"]["tail"])
	var early := DispatchSounds.jet_pitch(0.5)
	var late := DispatchSounds.jet_pitch(waits - 0.5)
	var falls := true
	var last := INF
	for k in 40:
		var f := DispatchSounds.jet_pitch(span * float(k) / 39.0)
		if f > last + 1e-6:
			falls = false
		last = f
	_ok(early > 1.08 and late < 0.93 and falls, "the jet's pitch falls all through its pass (%.3f to %.3f)" % [early, late])
	var jet := _render([{"t": 0.0, "t1": span, "kind": "jet"}], span)
	var near := DispatchSounds.JET_CLOSEST
	var ends := maxf(_rms(jet, 0.2, 1.2), _rms(jet, waits - 1.2, waits - 0.2))
	var over := _rms(jet, near - 0.6, near + 0.6)
	_ok(over > ends * 2.0 and _peak(jet) < DispatchSounds.LOUD_MOST * 2.0, "the jet is loudest overhead, and never too loud (%.4f against %.4f, peak %.3f)" % [over, ends, _peak(jet)])
	# it goes away slowly: quieter second by second through its tail, its last second all but gone (the control: as the voice
	# comes back it is still well heard - the tail is not a cut)
	var going := true
	var louder := INF
	for k in range(int(waits), int(span)):
		var r := _rms(jet, float(k), float(k) + 1.0)
		going = going and r < louder
		louder = r
	var at_words := _rms(jet, waits - 1.0, waits)
	var gone := _rms(jet, span - 1.0, span)
	_ok(going and gone < over * 0.02 and at_words > over * 0.2,
		"the jet fades slowly away under the words after it (%.4f as they come, %.4f at its end, %.4f overhead)" % [at_words, gone, over])
	# a sound made from its words: its frames heard where the plan puts it, at what the voice waits for (the control: its frames not
	# read yet, nothing but the hiss)
	var frames := PackedVector2Array()
	frames.resize(RATE)
	for i in frames.size():
		var v := SoundEffects.CEILING * sin(TAU * 440.0 * float(i) / RATE)
		frames[i] = Vector2(v, -v)
	var clip_plan := [{"t": 0.5, "t1": 1.5, "kind": "clip", "key": "k"}]
	var clip_heard := _render(clip_plan, 2.0, 1.0, {"k": frames})
	var unread := _render(clip_plan, 2.0, 1.0, {})
	var halved := _render([{"t": 0.5, "t1": 1.5, "kind": "clip", "key": "k", "gain": 0.5}], 2.0, 1.0, {"k": frames})
	_ok(absf(_rms(halved, 0.6, 1.4) / maxf(_rms(clip_heard, 0.6, 1.4), 1e-9) - 0.5) < 0.05,
		"a made sound's level is heard: at half its gain, half as loud (the control: at its own, as made)")
	var level := _rms(clip_heard, 0.6, 1.4)
	_ok(level > 0.04 and _rms(clip_heard, 0.05, 0.45) < level * 0.1 and _rms(clip_heard, 1.6, 1.95) < level * 0.1
		and absf(_peak(clip_heard) - DispatchSounds.LOUD_MOST) < DispatchSounds.LOUD_MOST * 0.2 and _rms(unread, 0.6, 1.4) < level * 0.1,
		"a made sound is heard where the plan puts it, its peak at what the voice waits for, and nothing before its frames are read (%.4f, peak %.4f, unread %.4f)"
			% [level, _peak(clip_heard), _rms(unread, 0.6, 1.4)])
	# storms
	var pop := _render([{"t": 0.0, "t1": 5.0, "kind": "static", "storm": "popcorn", "seed": 11}], 5.0)
	var surf := _render([{"t": 0.0, "t1": 5.0, "kind": "static", "storm": "surf", "seed": 11}], 5.0)
	var quiet := _render([], 5.0)
	var crest_pop := _peak(pop) / maxf(_rms(pop, 0.5, 4.5), 1e-6)
	var crest_surf := _peak(surf) / maxf(_rms(surf, 0.5, 4.5), 1e-6)
	_ok(crest_pop > crest_surf * 1.3, "Io-B's pops are spikier than Io-A's surf (crest %.1f against %.1f)" % [crest_pop, crest_surf])
	_ok(_rms(pop, 0.5, 4.5) > _rms(quiet, 0.5, 4.5) * 3.0 and _rms(surf, 0.5, 4.5) > _rms(quiet, 0.5, 4.5) * 3.0,
		"both storms are heard over the hiss")
	_ok(_peak(pop) < DispatchSounds.LOUD_MOST * 2.0 and _peak(surf) < DispatchSounds.LOUD_MOST * 2.0, "the storms are never too loud")
	# a voice over the receiver
	var bare := {"t": 0.0, "t1": 10.0, "kind": "static", "storm": "surf", "seed": 11}
	var under := bare.duplicate()
	under["under"] = [[3.0, 6.0]]
	under["words"] = [[3.3, 3.8], [4.2, 4.6]]
	var plain := DispatchSounds.storm_level("surf", 4.5, 11, 10.0)
	var lowered := DispatchSounds.receiver_level(under, 4.5)
	_ok(is_equal_approx(DispatchSounds.receiver_level(bare, 4.5), plain) and is_equal_approx(lowered, plain * DispatchSounds.UNDER)
		and is_equal_approx(DispatchSounds.receiver_level(under, 8.0), DispatchSounds.storm_level("surf", 8.0, 11, 10.0)),
		"a voice brings the storm down under it, and it is whole past it (the control: with no voice it is its storm - %.3f, %.3f under, of %.3f)"
		% [DispatchSounds.receiver_level(bare, 4.5), lowered, plain])
	var over_voice := _render([under], 10.0)
	var no_voice := _render([bare], 10.0)
	_ok(_rms(over_voice, 3.5, 5.5) < _rms(no_voice, 3.5, 5.5) * 0.85 and _rms(over_voice, 3.5, 5.5) > _rms(quiet, 0.5, 4.5) * 2.0,
		"under a voice the storm is quieter, and still heard over the hiss (%.4f against %.4f)" % [_rms(over_voice, 3.5, 5.5), _rms(no_voice, 3.5, 5.5)])
	_ok(DispatchSounds.voice_level(under, 3.55) > 0.5 and DispatchSounds.voice_level(under, 4.0) == 0.0 and DispatchSounds.voice_level(bare, 3.55) == 0.0,
		"the needle swells within a word, is still between two, and never without a voice")
	# Io-B's clusters ease into each other: over a minute, never more than a small step in 10 ms, busy and quiet both - the control,
	# the same clusters switched a quarter second at a time (as a gate on the hiss), jumps
	var most_step := 0.0
	var switched := 0.0
	var busiest := 0.0
	var quietest := 1.0
	var was := DispatchSounds.storm_level("popcorn", 0.5, 11, 1e9)
	var was_switched := DispatchSounds._cluster(11, 2)
	for i in range(51, 6000):
		var u := float(i) * 0.01
		var lv := DispatchSounds.storm_level("popcorn", u, 11, 1e9)
		most_step = maxf(most_step, absf(lv - was))
		busiest = maxf(busiest, lv)
		quietest = minf(quietest, lv)
		was = lv
		var sw := DispatchSounds._cluster(11, int(floor(u / 0.25)))
		switched = maxf(switched, absf(sw - was_switched))
		was_switched = sw
	_ok(most_step < 0.03 and busiest > 0.75 and quietest < 0.3 and switched > 0.25,
		"Io-B's clusters ease into each other: at most %.3f in 10 ms, from %.2f to %.2f (the control: switched, they jump %.2f)"
		% [most_step, quietest, busiest, switched])
	# the receiver as loud as the Environment says: turned to 0, neither its hiss nor its storm is heard; the control, as made, both are
	var muted := _render([{"t": 0.0, "t1": 5.0, "kind": "static", "storm": "popcorn", "seed": 11}], 5.0, 0.0)
	_ok(_peak(muted) < 1e-6 and _rms(pop, 0.5, 4.5) > _rms(quiet, 0.5, 4.5) * 2.0,
		"the receiver turned to 0 is silent, its hiss and storm (peak %.6f); as made, its storm is heard (%.4f over %.4f)"
		% [_peak(muted), _rms(pop, 0.5, 4.5), _rms(quiet, 0.5, 4.5)])
	# one-shots and the phone
	var desk: Array = []
	var k := 0.2
	for what in ["flip", "snap", "lay", "key", "space", "ping", "echo", "toggle", "thud", "crt", "click", "detent", "lamp"]:
		desk.append({"t": k, "what": what, "at": Vector3(0.3, 0.76, 0.0)})
		k += 0.35
	desk.append({"t": k, "t1": k + 2.6, "kind": "ringback"})
	desk.append({"t": k + 3.0, "t1": k + 5.8, "kind": "buzz", "pattern": "ring", "ears": Vector2(0.8, 0.6)})
	desk.append({"t": k + 6.0, "t1": k + 8.5, "kind": "print", "lines": 4, "ears": Vector2(0.9, 0.4)})
	desk.append({"t": k + 8.6, "t1": k + 8.6 + DispatchSounds.BELL_LEN, "kind": "bell", "ears": Vector2(0.7071, 0.7071)})
	var heard := _render(desk, k + 9.0)
	# bell, alone
	var bell := _render([{"t": 0.5, "t1": 0.5 + DispatchSounds.BELL_LEN, "kind": "bell", "ears": Vector2(0.7071, 0.7071)}], 1.5)
	var ringing := _rms(bell, 0.52, 0.5 + DispatchSounds.BELL_LEN - 0.02)
	var after_bell := _rms(bell, 0.5 + DispatchSounds.BELL_LEN + 0.02, 1.4)
	_ok(ringing > _rms(quiet, 0.5, 4.5) * 5.0 and after_bell < ringing * 0.2 and _peak(bell) < DispatchSounds.PEAK_MOST,
		"the bell is one short beep, heard over the hiss and gone when it ends (%.4f, then %.4f)" % [ringing, after_bell])
	_ok(_peak(heard) < DispatchSounds.PEAK_MOST * 1.6 and _rms(heard, 0.1, k + 9.0) > _rms(quiet, 0.5, 4.5) * 1.5,
		"the desk's sounds are heard, and subdued (peak %.3f)" % _peak(heard))
	# a pure function of the schedule
	var again := _render(desk, k + 9.0)
	var same := again.size() == heard.size()
	for i in mini(again.size(), heard.size()):
		if again[i] != heard[i]:
			same = false
			break
	_ok(same, "the same plan is the same sound, sample for sample")
	# control
	_ok(_peak(quiet) < 0.012, "the control: with nothing planned only the faint hiss is heard (peak %.4f)" % _peak(quiet))
	if _fails.is_empty():
		print("dispatch_sounds_check: ALL OK")
		quit(0)
	else:
		for f in _fails:
			print("dispatch_sounds_check: FAIL  " + f)
		quit(1)


func _render(plan: Array, secs: float, receiver := 1.0, clips := {}) -> PackedVector2Array:
	var p := Plan.new()
	p.plan = plan
	var s := DispatchSounds.new(p)
	s.receiver_share = receiver
	s.clips = clips
	s._restart(0.0)
	var out := PackedVector2Array()
	var n := int(secs * RATE)
	while out.size() < n:
		out.append_array(s.render(mini(4096, n - out.size())))
	return out


static func _rms(buf: PackedVector2Array, a: float, b: float) -> float:
	var s := 0.0
	var n := 0
	for i in range(int(a * RATE), mini(int(b * RATE), buf.size())):
		s += buf[i].x * buf[i].x + buf[i].y * buf[i].y
		n += 2
	return sqrt(s / maxf(1.0, float(n)))


static func _peak(buf: PackedVector2Array) -> float:
	var m := 0.0
	for v in buf:
		m = maxf(m, maxf(absf(v.x), absf(v.y)))
	return m


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
