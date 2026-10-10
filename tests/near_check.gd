extends SceneTree

## Gate for NEAR - the reader coming in to the microphone and backing off ([method VoiceFX.near_to],
## [method VoiceFX.near_plan]).
##   godot --headless --path . --script res://tests/near_check.gd
##
## What it holds, each against a control that must fail:
##   - home is no effect at all: a chain told to stay where it is, is the chain it was.
##   - coming in plainly is louder and warmer, and the room behind it does not change.
##   - coming in HUSHED is closer without being louder: the voice holds its level while the
##     room falls away and the low end comes up (the control is the plain approach).
##   - backing off is quieter and thinner against an unchanged room.
##   - a move is eased: no step in level from one 10 ms to the next.
##   - the plan: 0 never moves; how often and how far rise with the dial; 1 never rests; plain and hushed
##     both occur, nothing is whispered, only an approach is hushed; each voice on its own dial;
##     same words, same moves.

const SR := 8000

var _fails: PackedStringArray = []


func _initialize() -> void:
	_check_home_is_off()
	_check_manners()
	_check_eased()
	_check_plan()
	if _fails.is_empty():
		print("near_check: ALL OK")
		quit(0)
		return
	for f in _fails:
		print("near_check: FAIL - ", f)
	print("near_check: %d FAILED" % _fails.size())
	quit(1)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)


## A voice-like signal: a low fundamental and an upper partial, so a low band can be measured.
func _voice(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(SR)
		out[i] = 0.12 * sin(TAU * 110.0 * t) + 0.08 * sin(TAU * 1300.0 * t)
	return out


func _chain(c: float, hush: float) -> VoiceFX:
	var fx := VoiceFX.new()
	fx.pad_seed = 4
	fx.setup(SR)
	fx.room.from_dial(0.6, 0.5)
	fx.echo_wet = 0.2
	if c != 0.0 or hush != 0.0:
		fx.near_to(c, hush)
	return fx


func _rms(buf: PackedFloat32Array, a: int, b: int) -> float:
	var acc := 0.0
	for i in range(a, b):
		acc += buf[i] * buf[i]
	return sqrt(acc / float(maxi(1, b - a)))


func _db(x: float, ref: float) -> float:
	return 20.0 * log(maxf(x, 1e-9) / maxf(ref, 1e-9)) / log(10.0)


## Level while speaking (settled), level of the tail after, and the low band's share.
func _measure(c: float, hush: float) -> Dictionary:
	var fx := _chain(c, hush)
	var src := _voice(SR * 6)
	var gap := PackedFloat32Array()
	gap.resize(SR * 2)
	src.append_array(gap)
	var out := fx.process(src)
	# the low end against the top, as the two partials' own amplitudes over the settled stretch
	# (a share of energy barely moves on a signal the low partial already dominates)
	return {"voice": _rms(out, SR * 4, SR * 6), "tail": _rms(out, SR * 6 + SR / 10, SR * 6 + SR / 2),
		"low": _amp(out, 110.0, SR * 4, SR * 6) / maxf(_amp(out, 1300.0, SR * 4, SR * 6), 1e-9)}


## One partial's amplitude over [a, b): a single-bin DFT.
func _amp(buf: PackedFloat32Array, hz: float, a: int, b: int) -> float:
	var re := 0.0
	var im := 0.0
	for i in range(a, b):
		var ph := TAU * hz * float(i) / float(SR)
		re += buf[i] * cos(ph)
		im += buf[i] * sin(ph)
	return 2.0 * sqrt(re * re + im * im) / float(b - a)


func _check_home_is_off() -> void:
	var a := _chain(0.0, 0.0)
	var b := _chain(0.0, 0.0)
	b.near_to(0.0, 0.0)
	var src := _voice(SR * 3)
	var x := a.process_stereo(src.duplicate())
	var y := b.process_stereo(src.duplicate())
	_ok(x == y, "a chain told to stay home is not the chain it was")
	var c := _chain(1.0, 0.0)
	var z := c.process_stereo(src.duplicate())
	_ok(x != z, "control: coming in changed nothing")


func _check_manners() -> void:
	var home := _measure(0.0, 0.0)
	var plain := _measure(1.0, 0.0)
	var hushed := _measure(1.0, 1.0)
	var back := _measure(-1.0, 0.0)
	var report := func(name: String, m: Dictionary) -> void:
		print("near_check: %-6s voice %+5.1f dB  tail %+5.1f dB  low end %+5.1f dB" % [name,
			_db(m.voice, home.voice), _db(m.tail, home.tail), _db(m.low, home.low)])
	for row in [["plain", plain], ["hushed", hushed], ["back", back]]:
		report.call(row[0], row[1])
	_ok(_db(plain.voice, home.voice) > 3.0, "coming in plainly is not louder")
	_ok(absf(_db(plain.tail, home.tail)) < 1.0, "coming in plainly changed the room")
	_ok(_db(plain.low, home.low) > 2.0, "coming in is not warmer (no proximity effect)")
	_ok(absf(_db(hushed.voice, home.voice)) < 2.0,
		"hushed is not about as loud as before (%+.1f dB)" % _db(hushed.voice, home.voice))
	_ok(_db(hushed.tail, home.tail) < -4.0, "hushed, the room did not fall away")
	_ok(_db(hushed.low, home.low) > 2.0, "hushed is not warmer")
	# control: the plain approach is what hushed must NOT sound like in level
	_ok(_db(plain.voice, hushed.voice) > 3.0, "control: plain and hushed are the same level")
	_ok(_db(back.voice, home.voice) < -2.0, "backing off is not quieter")
	_ok(absf(_db(back.tail, home.tail)) < 1.0, "backing off changed the room")
	_ok(_db(back.low, home.low) < -1.0, "backing off is not thinner")


## The largest change in level between consecutive 10 ms windows, in dB.
func _worst_step(buf: PackedFloat32Array) -> float:
	var win := SR / 100
	var prev := -1.0
	var worst := 0.0
	var i := 0
	while i + win <= buf.size():
		var r := _rms(buf, i, i + win)
		if prev > 0.0:
			worst = maxf(worst, absf(_db(r, prev)))
		prev = r
		i += win
	return worst


func _check_eased() -> void:
	var fx := VoiceFX.new()
	fx.setup(SR)
	var tone := PackedFloat32Array()
	tone.resize(SR * 6)
	for i in tone.size():
		tone[i] = 0.1 * sin(TAU * 400.0 * float(i) / float(SR))   # 4 cycles per window: steady RMS
	var first := fx.process(tone.slice(0, SR))
	fx.near_to(1.0, 0.0)
	var moved := fx.process(tone.slice(SR, SR * 4))
	fx.near_to(-1.0, 0.0)
	var back := fx.process(tone.slice(SR * 4))
	first.append_array(moved)
	first.append_array(back)
	var worst := _worst_step(first)
	print("near_check: largest 10 ms step %.2f dB" % worst)
	_ok(worst < 0.5, "a move is a step, not a lean in (%.2f dB in 10 ms)" % worst)
	# control: an instant change of the same size must be flagged
	var stepped := tone.slice(0, SR)
	var loud := tone.slice(0, SR)
	for i in loud.size():
		loud[i] *= db_to_linear(VoiceFX.NEAR_IN_DB)
	stepped.append_array(loud)
	_ok(_worst_step(stepped) > 3.0, "control: an instant step was not caught")


func _plan(k: float, n: int, seed: int = 7) -> Array:
	var ks := PackedFloat32Array()
	var who := PackedStringArray()
	for i in n:
		ks.append(k)
		who.append("A")
	return VoiceFX.near_plan(ks, who, seed)


func _away(plan: Array) -> float:
	var n := 0
	for p in plan:
		if float((p as Dictionary)["c"]) != 0.0:
			n += 1
	return float(n) / float(plan.size())


func _reach(plan: Array, key: String) -> float:
	var far := 0.0
	for p in plan:
		far = maxf(far, absf(float((p as Dictionary)[key])))
	return far


func _check_plan() -> void:
	var n := 2000
	var low_plan := _plan(0.1, n)
	var mid_plan := _plan(0.5, n)
	var top_plan := _plan(1.0, n)
	var off := _away(_plan(0.0, n))
	var low := _away(low_plan)
	var mid := _away(mid_plan)
	var top := _away(top_plan)
	print("near_check: sentences away from home: 0.1 %.0f%%, 0.5 %.0f%%, 1.0 %.0f%%"
		% [low * 100.0, mid * 100.0, top * 100.0])
	_ok(off == 0.0, "Near 0 moved the reader")
	_ok(low > 0.02 and low < 0.25, "0.1 is not sparse (%.2f)" % low)
	_ok(low < mid and mid < top, "how often does not rise with the dial")
	_ok(top > 0.95, "1.0 rests at home (%.2f)" % top)
	var low_reach := _reach(low_plan, "c")
	var mid_reach := _reach(mid_plan, "c")
	var top_reach := _reach(top_plan, "c")
	_ok(low_reach > 0.05 and low_reach <= 0.1 and low_reach < mid_reach and mid_reach <= 0.5
		and mid_reach < top_reach and top_reach > 0.9,
		"distance does not grow with Near (%.2f / %.2f / %.2f)" % [low_reach, mid_reach, top_reach])
	_ok(_reach(low_plan, "hush") <= 0.1 and _reach(mid_plan, "hush") <= 0.5
		and _reach(top_plan, "hush") > 0.9,
		"soft delivery stays at full strength when Near is low")
	# the manners, over the approaches at mid: plain and hushed, and never a whisper (piper's,
	# blended, was heard as "a garbled mess"); only an approach is hushed
	var plain := 0
	var hushed := 0
	var wrong := 0
	for p in _plan(0.6, n):
		var d: Dictionary = p
		if d.has("whisper"):
			wrong += 1
		if float(d["c"]) > 0.0:
			if float(d["hush"]) > 0.0:
				hushed += 1
			else:
				plain += 1
		elif float(d["hush"]) > 0.0:
			wrong += 1
	print("near_check: approaches plain %d, hushed %d" % [plain, hushed])
	var all := maxi(1, plain + hushed)
	_ok(float(plain) / all > 0.2 and float(hushed) / all > 0.2,
		"one manner is missing (plain %d, hushed %d)" % [plain, hushed])
	_ok(wrong == 0, "%d sentences whispered, or hushed without coming in" % wrong)
	# each voice on its own dial
	var ks := PackedFloat32Array()
	var who := PackedStringArray()
	for i in 400:
		ks.append(0.0 if i % 2 == 0 else 0.8)
		who.append("still" if i % 2 == 0 else "moving")
	var mixed := VoiceFX.near_plan(ks, who, 3)
	var still_moved := 0
	var moving_moved := 0
	for i in mixed.size():
		if float((mixed[i] as Dictionary)["c"]) != 0.0:
			if i % 2 == 0:
				still_moved += 1
			else:
				moving_moved += 1
	_ok(still_moved == 0, "a voice at Near 0 moved because another voice did")
	_ok(moving_moved > 50, "control: the moving voice hardly moved (%d)" % moving_moved)
	_ok(_plan(0.5, 300, 9) == _plan(0.5, 300, 9), "the same words made different moves")
	_ok(_plan(0.5, 300, 9) != _plan(0.5, 300, 10), "control: different words made the same moves")
