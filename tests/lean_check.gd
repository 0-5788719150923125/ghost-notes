extends SceneTree

## Gate for the LEAN - the reader moving between the ears around a centered microphone
## ([member VoiceFX.lean]).
##   godot --headless --path . --script res://tests/lean_check.gd
##
## What it holds, each against a control that must fail:
##   - 0 is no effect at all: both ears are the mono chain, sample for sample.
##   - the far ear never drops under 30%: the measured balance stays inside 70/30 at every
##     window of a long full-dial run (control: a 90/10 frame set is flagged).
##   - the dial is HOW OFTEN: time spent leaning rises with it, the bottom rests at center
##     most of the time, and the top never rests there (a sway).
##   - every move is eased: no jump in the position (control: a stepped track is flagged).
##   - only the voice moves: where the dry input is silent, the room's and the bed's tails
##     are the same in both ears even mid-lean.
##   - same seed, same moves.

const SR := 1000          # the motion alone runs at a low rate: it is a function of time


var _fails: PackedStringArray = []


func _initialize() -> void:
	_check_zero_is_off()
	_check_balance_limit()
	_check_dial_is_how_often()
	_check_eased()
	_check_only_the_voice_moves()
	_check_seeded()
	if _fails.is_empty():
		print("lean_check: ALL OK")
		quit(0)
		return
	for f in _fails:
		print("lean_check: FAIL - ", f)
	print("lean_check: %d FAILED" % _fails.size())
	quit(1)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)


## A steady voice-like signal: a 180 Hz tone with a slow swell, never silent.
func _tone(n: int, sr: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(sr)
		out[i] = 0.2 * sin(TAU * 180.0 * t) * (0.7 + 0.3 * sin(TAU * 0.3 * t))
	return out


## The lean's position over [param seconds], at [constant SR].
func _track(k: float, seconds: float, seed: int = 1) -> PackedFloat32Array:
	var fx := VoiceFX.new()
	fx.pad_seed = seed
	fx.setup(SR)
	fx.lean = k
	fx._resolve_lean()
	var out := PackedFloat32Array()
	out.resize(int(seconds * SR))
	for i in out.size():
		out[i] = fx._tick_lean()
	return out


func _check_zero_is_off() -> void:
	var a := VoiceFX.new()
	var b := VoiceFX.new()
	for fx in [a, b]:
		fx.pad_seed = 5
		fx.setup(22050)
		fx.echo_wet = 0.3
		fx.room.from_dial(0.4, 0.5)
		fx.pad = 0.5
	var src := _tone(22050 * 4, 22050)
	var mono := a.process(src.duplicate())
	var st := b.process_stereo(src.duplicate())
	var off := 0
	for i in mono.size():
		if st[i].x != mono[i] or st[i].y != mono[i]:
			off += 1
	_ok(off == 0, "lean 0 is not the mono chain in both ears (%d samples differ)" % off)
	# control: the same at full lean must differ, or this proves nothing
	var c := VoiceFX.new()
	c.pad_seed = 5
	c.setup(22050)
	c.lean = 1.0
	var st2 := c.process_stereo(src.duplicate())
	var differ := 0
	for i in st2.size():
		if absf(st2[i].x - st2[i].y) > 1e-4:
			differ += 1
	_ok(differ > st2.size() / 4, "control: lean 1 left the ears identical (%d)" % differ)


## The balance per 50 ms window: the near ear's share of the summed RMS.
func _worst_share(st: PackedVector2Array, sr: int) -> float:
	var win := sr / 20
	var worst := 0.5
	var i := 0
	while i + win <= st.size():
		var l := 0.0
		var r := 0.0
		for j in range(i, i + win):
			l += st[j].x * st[j].x
			r += st[j].y * st[j].y
		l = sqrt(l)
		r = sqrt(r)
		if l + r > 1e-6:
			worst = maxf(worst, maxf(l, r) / (l + r))
		i += win
	return worst


func _check_balance_limit() -> void:
	var sr := 8000
	var fx := VoiceFX.new()
	fx.pad_seed = 3
	fx.setup(sr)
	fx.lean = 1.0
	var st := fx.process_stereo(_tone(sr * 60, sr))
	var worst := _worst_share(st, sr)
	print("lean_check: deepest measured balance %.1f/%.1f" % [worst * 100.0, (1.0 - worst) * 100.0])
	_ok(worst <= VoiceFX.LEAN_SHARE + 0.005, "the balance went past 70/30 (%.3f)" % worst)
	_ok(worst >= 0.66, "a minute at full lean never got near the limit (%.3f)" % worst)
	# the law itself, past the ends of its travel
	var g := VoiceFX.lean_gains(5.0)
	_ok(absf(g.y / (g.x + g.y) - VoiceFX.LEAN_SHARE) < 1e-4, "lean_gains does not clamp")
	_ok(absf(g.x * g.x + g.y * g.y - 2.0) < 1e-4, "lean_gains is not constant power")
	# control: a 90/10 frame set must be flagged by the same measurement
	var bad := PackedVector2Array()
	bad.resize(sr)
	for i in sr:
		var v := sin(TAU * 180.0 * float(i) / float(sr))
		bad[i] = Vector2(0.9 * v, 0.1 * v)
	_ok(_worst_share(bad, sr) > VoiceFX.LEAN_SHARE + 0.1, "control: 90/10 was not caught")


## Fraction of the time spent off center, and the longest rest at center, in seconds.
func _stats(track: PackedFloat32Array) -> Dictionary:
	var off := 0
	var rest := 0
	var longest := 0
	for v in track:
		if absf(v) > 0.05:
			off += 1
			rest = 0
		else:
			rest += 1
			longest = maxi(longest, rest)
	return {"off": float(off) / float(track.size()), "rest": float(longest) / float(SR)}


func _check_dial_is_how_often() -> void:
	var secs := 600.0
	var low := _stats(_track(0.1, secs))
	var mid := _stats(_track(0.5, secs))
	var top := _stats(_track(1.0, secs))
	print("lean_check: off center 0.1 %.0f%%, 0.5 %.0f%%, 1.0 %.0f%%; longest rest %.1f / %.1f / %.1f s"
		% [low.off * 100.0, mid.off * 100.0, top.off * 100.0, low.rest, mid.rest, top.rest])
	_ok(low.off < 0.45, "0.1 does not rest at center most of the time (%.2f)" % low.off)
	_ok(low.off > 0.05, "0.1 hardly ever leans (%.2f) - dead travel" % low.off)
	_ok(low.off < mid.off and mid.off < top.off, "time leaning does not rise with the dial")
	_ok(top.off > 0.85, "1.0 is not a constant sway (%.2f off center)" % top.off)
	_ok(top.rest < 1.0, "1.0 rests at center (%.1f s)" % top.rest)
	# turned to 0 mid-lean, the reader goes home and stays
	var fx := VoiceFX.new()
	fx.pad_seed = 1
	fx.setup(SR)
	fx.lean = 1.0
	fx._resolve_lean()
	for i in SR * 5:
		fx._tick_lean()
	fx.lean = 0.0
	fx._resolve_lean()
	var last := 1.0
	for i in SR * 8:
		last = fx._tick_lean()
	_ok(last == 0.0, "turned to 0, the reader did not come home (%.3f)" % last)


## The largest step between samples, per second.
func _max_speed(track: PackedFloat32Array) -> float:
	var top := 0.0
	for i in range(1, track.size()):
		top = maxf(top, absf(track[i] - track[i - 1]))
	return top * SR


func _check_eased() -> void:
	var speed := _max_speed(_track(1.0, 300.0))
	print("lean_check: fastest move %.2f per second" % speed)
	_ok(speed < 2.5, "a move is a jump, not a lean (%.2f/s)" % speed)
	# control: a track that steps must be flagged
	var stepped := PackedFloat32Array()
	stepped.resize(SR)
	for i in SR:
		stepped[i] = 0.0 if i < SR / 2 else 0.8
	_ok(_max_speed(stepped) > 2.5, "control: a stepped track was not caught")


## The room and the bed stay put: wherever the dry input is silent, the ears agree.
func _check_only_the_voice_moves() -> void:
	var sr := 8000
	var fx := VoiceFX.new()
	fx.pad_seed = 9
	fx.setup(sr)
	fx.lean = 1.0
	fx.echo_wet = 0.5
	fx.room.from_dial(0.7, 0.6)
	fx.presence = 0.7
	# voice, then a long gap with only the tails and the presence filter's own decay
	var src := _tone(sr * 20, sr)
	var gap := PackedFloat32Array()
	gap.resize(sr * 4)
	src.append_array(gap)
	var st := fx.process_stereo(src)
	# the presence lowpass on the direct voice decays a few ms into the gap; skip 50 ms
	var spread := 0.0
	var tail := 0.0
	for i in range(sr * 20 + sr / 20, st.size()):
		spread = maxf(spread, absf(st[i].x - st[i].y))
		tail = maxf(tail, absf(st[i].x))
	_ok(tail > 1e-3, "control: there is no tail to test (%.5f)" % tail)
	_ok(spread < 1e-4, "the room moved with the reader (ears differ by %.5f in the gap)" % spread)
	var during := 0.0
	for i in range(sr * 2, sr * 20):
		during = maxf(during, absf(st[i].x - st[i].y))
	_ok(during > 0.02, "control: the voice did not move either (%.4f)" % during)


func _check_seeded() -> void:
	var a := _track(0.5, 120.0, 11)
	var b := _track(0.5, 120.0, 11)
	var c := _track(0.5, 120.0, 12)
	_ok(a == b, "the same seed made different moves")
	_ok(a != c, "control: a different seed made the same moves")
