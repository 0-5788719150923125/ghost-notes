extends RefCounted
class_name LikenessPlan

## LikenessPlan - how the actor moves at each moment, on their still (next/likeness.md, "The second
## build"): the head, the body, the eyes and the mouth, each A PURE FUNCTION OF SHOW TIME - asked for any
## moment, the answer depends on nothing asked before it, so a seek and an export draw what the live show
## drew.
##
## THE HEAD ([method motion]'s first three): their own motion (`motion.json`: its quick part, the slow drift
## out, where they face the camera - the head's turn against the shoulders), played in pieces drawn from the
## seed, each going into the next over [constant BLEND] seconds - the numbers mixed, so there is no cut -
## read smoothly between the survey's looks, scaled to a calm size ([constant CALM] of their own, at most
## [constant MOST]) and livelier while the voice speaks; and kept LEVEL, taking back most of the body's tilt.
##
## THE BODY HOLDS A POSTURE AND SHIFTS IT ([method posture], the fourth pass, 2026-10-22, the user: "it is
## just rocking around constantly ... I would have expected a more relaxed, neutral posture - and one that
## isn't frozen in-place, rocking weirdly back and forth"): the quick part of their shoulders' motion is
## their gestures pulling at them - 2 to 4 second swings - and a body at rest has none of it. So the torso
## holds a posture for a while (about [constant HOLD] of their own holding time, `motion.json`'s
## `posture`), then shifts to another over [constant SHIFT] seconds - each drawn from their own range of
## posture, which ways going together as theirs do, at [constant POSTURE_CALM] of it, keeping [constant
## HOLD_NEXT] of the last - with a slow sway under it ([constant SWAY]), so it is never frozen. THE CHEST
## ([method breath]) draws in at the voice's pauses and lets out while it speaks; THE SHOULDERS ([method
## lifts]) rise with it and wander a little apart; THE HANDS ([method hands]) rest, settling a little as the
## body shifts.
##
## THE EYES ([method eyes]): blinks at their own rate (`motion.json`'s), at times drawn from the seed, and
## one at most pauses in the voice, as people blink as a phrase ends; a blink closes in 70 ms, holds 40 and
## opens in 130. And GLANCES ([method glance]), drawn from the seed: down, aside, up, held a moment, back
## (the third pass: "The eyes never look around"). The open eye at the camera is the still's own; the
## rest are the library's.
##
## THE MOUTH ([method mouth]): with THEIR MOUTH LEARNED (`mouth_model.json`, the third pass: an ensemble of
## small networks trained on every video, from the sounds heard round a moment to their mouth then), the
## mouth the ensemble says for the voice's sounds, pushed past their own as the library was ([member
## LikenessFace.articulation]), drawn as the two library mouths nearest it - or the still's own - the
## farther less the third, so none pops. Without one, the voice's phones pulling ([Visemes.pulls]), the
## two strongest less the third ([Visemes.strongest]), each as one of its class's prototypes - which one
## drawn from the seed and the phone. Silence is the still's own mouth.

## THE LEARNED MOUTH IS DRAWN FROM only when, on the video it never saw, it explains at least this share of
## their mouth and this much more than each sound's mean mouth does (2026-10-22, his footage: 2.5% - his
## beard hides his mouth, and the words are timed only to the word - so his is placed by its sounds).
const LEARNED_LEAST := 0.15
const LEARNED_BEYOND := 0.05
## Seconds one piece of motion goes into the next over.
const BLEND := 0.8
## A piece of motion lasts this long, at least and at most (seconds).
const PIECE := [4.0, 9.0]
## THE MOTION'S SIZE: each axis at this share of their own, never past [constant MOST] of it (degrees of
## the head's yaw, pitch and roll; face widths across and down; the log of nearness; degrees of the
## shoulders' tilt) - eased, not cut, past it. Their own is how they move while they talk to a camera; a
## still bent by it should move less.
const CALM := 0.6
const MOST := [5.0, 4.0, 3.0, 0.05, 0.04, 0.03, 2.5]
## While they are silent the head moves at this share of what it does while they speak.
const QUIET := 0.55
## THE POSTURE: each axis (across, down, nearer, tilt) at this share of their own range - the tilt least, a
## seated body leans aside little; a posture held about this many of their own holding times (a gamma of
## shape 2), shifted from over this many seconds, keeping this much of the last; and the sway under it, a
## share of its range, its knots this many seconds apart.
const POSTURE_CALM := [0.5, 0.5, 0.5, 0.35]
const HOLD := 1.8
const SHIFT := [1.0, 2.2]
const HOLD_NEXT := 0.5
const SWAY := 0.3
const SWAY_KNOT := 3.0
## How much of the body's tilt the head takes back, keeping its eyes level as people do.
const LEVEL := 0.7
## THE SHOULDERS' LIFT (shares of their width): with the breath, from empty to full; and their own wander,
## each apart, its knots this many seconds apart.
const LIFT_BREATH := 0.006
const LIFT := 0.004
const LIFT_KNOT := 4.0
## THE HANDS (shares of the shoulders' width): how far each settles somewhere new as the body shifts, and
## its own small drift, its knots this many seconds apart.
const HAND_SHIFT := 0.006
const HAND_DRIFT := 0.002
const HAND_KNOT := 2.5
## Seconds round a moment the voice's speaking is judged over.
const SPEAKING := 0.6
## A BLINK: seconds closing, held, opening.
const BLINK := [0.07, 0.04, 0.13]
## The shortest gap between two blinks (seconds), and how often a pause in the voice is blinked at.
const BLINK_GAP := 0.6
const PAUSE_BLINK := 0.6
## A pause this long or longer is one a blink may fall in.
const PAUSE := 0.35
## THE BREATH: a pause this long or longer draws it in, full after [constant BREATH_IN] seconds of it;
## speaking lets it out at [constant BREATH_OUT] a second, never past [constant BREATH_LEAST]; with no
## voice yet, a breath every [constant BREATH_IDLE] seconds.
const BREATH_PAUSE := 0.2
const BREATH_IN := 0.5
const BREATH_OUT := 0.12
const BREATH_LEAST := 0.15
const BREATH_IDLE := 4.5
## GLANCES: about one every [constant GLANCE_EVERY] seconds (never sooner than [constant GLANCE_GAP]), each
## held [constant GLANCE_HOLD] seconds, turned to and back in [constant GLANCE_TURN]; which way, how often.
const GLANCE_EVERY := 4.5
const GLANCE_GAP := 1.5
const GLANCE_HOLD := [0.35, 1.2]
const GLANCE_TURN := 0.06
const GLANCES := {"look_down": 0.35, "look_left": 0.25, "look_right": 0.25, "look_up": 0.15}

var seed_value := 1
var rate := 5.0
var runs: Array = []          # [PackedFloat32Array of rows * axes] per run
var lengths := PackedInt32Array()
var axes := 6
var blinks_per_min := 16.0
var line: Array = []          # the voice's phones as classes ([Visemes.timeline])
var mouths_of := {}           # class -> [image]
var eyes_of := {}             # state -> [image]
## THEIR MOUTH, LEARNED: the ensemble's members (`{w1, b1, w2, b2, hidden}`, flat), the classes and offsets
## it reads, its mean and spread, how much each blendshape weighs, which are pushed - and the mouths it
## chooses among (image -> blendshapes, -1 the still's own), the mouth it says for silence.
var _members: Array = []
var _classes: Array = []
var _offsets := PackedFloat32Array()
var _window := 0.06
var _mean := PackedFloat32Array()
var _sd := PackedFloat32Array()
var _weights := PackedFloat32Array()
var _pushed := PackedInt32Array()
var _choices := {}
var _silence := PackedFloat32Array()
var _push := 1.0

## THEIR POSTURE: each axis's spread (their own times [constant POSTURE_CALM]), the lower triangle of how
## the axes go together (a draw's maker), and how long one holds.
var _posture_sd := PackedFloat32Array()
var _posture_mix := PackedFloat32Array()
var _posture_tau := 5.0

var _pieces: Array = []       # [{t0, run, at, rows}] ascending, grown as far as asked
var _holds: Array = []        # [{t0, shift, at}] ascending - a shift begun at t0 and done after shift - grown as far as asked
var _hold_rng := RandomNumberGenerator.new()
var _rng := RandomNumberGenerator.new()
var _total_rows := 0
var _blinks: Array = []       # the seeded blinks' times, ascending, grown as far as asked
var _blink_rng := RandomNumberGenerator.new()
var _pauses: Array = []       # the voice's pauses' blink times
var _glances: Array = []      # [{t0, look, hold, deep}] ascending, grown as far as asked
var _glance_rng := RandomNumberGenerator.new()
var _rests: Array = []        # the voice's pauses long enough to breathe in: [[t0, t1]]


## Read `motion.json`, and `mouth_model.json` beside it where it is; [param library] (a [LikenessFace])
## names the mouths and eyes. "" when sound.
func setup(motion_path: String, library: LikenessFace, seed_in: int) -> String:
	seed_value = seed_in
	mouths_of = library.mouths_of if library != null else {}
	eyes_of = library.eyes_of if library != null else {}
	_learn(motion_path.get_base_dir().path_join("mouth_model.json"), library)
	runs = []
	lengths = PackedInt32Array()
	_total_rows = 0
	var m: Variant = ActorFolder.read_json(motion_path)
	if not (m is Dictionary):
		return "their motion is not made"
	var d: Dictionary = m
	rate = maxf(1.0, float(d.get("rate", 5.0)))
	blinks_per_min = clampf(float(d.get("blinks_per_min", 16.0)), 4.0, 40.0)
	if not (d.get("posture") is Dictionary):
		return "their motion is from before their posture was learned"
	var po: Dictionary = d["posture"]
	_posture_tau = clampf(float(po.get("tau", 5.0)), 1.0, 30.0)
	_posture_sd = PackedFloat32Array()
	var sd: Array = po.get("sd", []) if po.get("sd") is Array else []
	for a in 4:
		_posture_sd.append((float(sd[a]) if a < sd.size() else 0.0) * float(POSTURE_CALM[a]))
	_posture_mix = cholesky(po.get("corr", []) if po.get("corr") is Array else [], 4)
	axes = clampi((d.get("axes", []) as Array).size(), 6, MOST.size()) if d.get("axes") is Array else 6
	for r in d.get("runs", []):
		var rows: Array = (r as Dictionary).get("rows", [])
		if rows.size() < int(ceil(PIECE[0] * rate + BLEND * rate)) + 4:
			continue
		var flat := PackedFloat32Array()
		for row in rows:
			for i in axes:
				flat.append(float(row[i]) if i < (row as Array).size() else 0.0)
		runs.append(flat)
		lengths.append(rows.size())
		_total_rows += rows.size()
	reset()
	return "" if not runs.is_empty() else "their motion has no run long enough"


## Start again from the seed: the same seed is the same performance.
func reset() -> void:
	_pieces = []
	_rng.seed = hash([seed_value, "likeness-head"])
	_blinks = []
	_blink_rng.seed = hash([seed_value, "likeness-blink"])
	_glances = []
	_glance_rng.seed = hash([seed_value, "likeness-glance"])
	_holds = []
	_hold_rng.seed = hash([seed_value, "likeness-posture"])


## THE VOICE'S PHONES ([param phones], `[{p, t0, t1}]`): the mouth's line, and the pauses a blink may fall in.
func set_voice(phones: Array) -> void:
	line = Visemes.timeline(phones)
	_pauses = []
	_rests = []
	for k in line.size():
		var ph: Dictionary = line[k]
		if String(ph["c"]) == "rest" and float(ph["t1"]) - float(ph["t0"]) >= BREATH_PAUSE:
			_rests.append([float(ph["t0"]), float(ph["t1"])])
		if String(ph["c"]) == "rest" and float(ph["t1"]) - float(ph["t0"]) >= PAUSE:
			var r := RandomNumberGenerator.new()
			r.seed = hash([seed_value, "likeness-pause", snappedf(float(ph["t0"]), 0.01)])
			if r.randf() < PAUSE_BLINK:
				_pauses.append(float(ph["t0"]) + 0.08 + r.randf() * 0.15)


# --- the head ----------------------------------------------------------------------------------------

func _grow(until: float) -> void:
	if runs.is_empty():
		return
	while _pieces.is_empty() or float(_pieces[-1]["t1"]) - BLEND <= until:
		var t0 := 0.0 if _pieces.is_empty() else float(_pieces[-1]["t1"]) - BLEND
		# a run drawn by its length, a place in it, and how long
		var pick := _rng.randi_range(0, _total_rows - 1)
		var r := 0
		while pick >= lengths[r]:
			pick -= lengths[r]
			r += 1
		var want := int(round(_rng.randf_range(PIECE[0], PIECE[1]) * rate))
		var rows := mini(want, lengths[r] - 3)
		var at := _rng.randi_range(1, maxi(1, lengths[r] - rows - 2))
		_pieces.append({"t0": t0, "t1": t0 + float(rows) / rate, "run": r, "at": at})


## A piece's motion at show time [param t]: its rows read between looks (Catmull-Rom). The rows are the
## quick part of their motion, round nothing, so a piece goes on from another through the blend alone.
func _sample(p: Dictionary, t: float) -> PackedFloat32Array:
	var flat: PackedFloat32Array = runs[int(p["run"])]
	var n := lengths[int(p["run"])]
	var u := float(p["at"]) + (t - float(p["t0"])) * rate
	var i := clampi(int(floor(u)), 1, n - 3)
	var f := clampf(u - float(i), 0.0, 1.0)
	var out := PackedFloat32Array()
	out.resize(axes)
	for a in axes:
		var p0 := flat[(i - 1) * axes + a]
		var p1 := flat[i * axes + a]
		var p2 := flat[(i + 1) * axes + a]
		var p3 := flat[(i + 2) * axes + a]
		out[a] = 0.5 * (2.0 * p1 + (p2 - p0) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
			+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * f * f * f)
	return out


## THEIR MOTION AT SHOW TIME [param t]: the head's yaw, pitch and roll against the shoulders (degrees) -
## their own motion, calm, livelier while the voice speaks, its roll taking back [constant LEVEL] of the
## body's tilt - then the body's [method posture]: across and down (face widths), nearer (the log of its
## scale) and its tilt (degrees).
func motion(t: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(MOST.size())
	if runs.is_empty():
		return out
	var body := posture(t)
	for a in 4:
		out[3 + a] = body[a]
	_grow(t + 1.0)
	var lo := 0
	var hi := _pieces.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if float(_pieces[mid]["t0"]) <= t:
			lo = mid
		else:
			hi = mid - 1
	var here := _sample(_pieces[lo], t)
	# going into the next piece: the two mixed, eased
	if lo + 1 < _pieces.size() and t > float(_pieces[lo + 1]["t0"]):
		var k := smoothstep(0.0, 1.0, (t - float(_pieces[lo + 1]["t0"])) / BLEND)
		var nxt := _sample(_pieces[lo + 1], t)
		for a in axes:
			here[a] = lerpf(here[a], nxt[a], k)
	var lively := lerpf(QUIET, 1.0, speaking(t))
	for a in 3:
		var most := float(MOST[a])
		out[a] = most * tanh(here[a] * CALM * lively / most)
	out[2] -= LEVEL * out[6]
	return out


# --- the body ----------------------------------------------------------------------------------------

## THE LOWER TRIANGLE of [param corr] (an [param n] by [param n] list of lists) such that it times draws
## of spread 1 gives draws that go together as [param corr] says; a sound one where it is not one.
static func cholesky(corr: Array, n: int) -> PackedFloat32Array:
	var c := PackedFloat32Array()
	c.resize(n * n)
	for i in n:
		for j in n:
			var row: Array = corr[i] if i < corr.size() and corr[i] is Array else []
			c[i * n + j] = float(row[j]) if j < row.size() else (1.0 if i == j else 0.0)
	var l := PackedFloat32Array()
	l.resize(n * n)
	for i in n:
		for j in i + 1:
			var sum := c[i * n + j]
			for k in j:
				sum -= l[i * n + k] * l[j * n + k]
			if i == j:
				if sum <= 1e-6:
					return cholesky([], n)
				l[i * n + i] = sqrt(sum)
			else:
				l[i * n + j] = sum / l[j * n + j]
	return l


func _grow_holds(until: float) -> void:
	while _holds.is_empty() or float(_holds[-1]["t0"]) <= until:
		if _holds.is_empty():
			# THE FIRST POSTURE IS THE STILL'S OWN
			var still := PackedFloat32Array()
			still.resize(8)
			_holds.append({"t0": -1.0e9, "shift": 1.0, "at": still})
			continue
		var last: Dictionary = _holds[-1]
		var mean := HOLD * _posture_tau
		var held := -0.5 * mean * (log(maxf(1e-6, _hold_rng.randf())) + log(maxf(1e-6, _hold_rng.randf())))
		var z := PackedFloat32Array()
		for a in 4:
			z.append(_hold_rng.randfn(0.0, 1.0))
		var prev: PackedFloat32Array = last["at"]
		var at := PackedFloat32Array()
		at.resize(8)
		var fresh := sqrt(1.0 - HOLD_NEXT * HOLD_NEXT)
		for a in 4:
			var v := 0.0
			for k in a + 1:
				v += _posture_mix[a * 4 + k] * z[k]
			at[a] = HOLD_NEXT * prev[a] + fresh * v * _posture_sd[a]
		# THE HANDS SETTLE SOMEWHERE NEW as the body shifts
		for a in range(4, 8):
			at[a] = HOLD_NEXT * prev[a] + fresh * _hold_rng.randfn(0.0, HAND_SHIFT)
		var t0 := maxf(0.0, float(last["t0"]) + float(last["shift"])) + maxf(1.0, held)
		_holds.append({"t0": t0, "shift": _hold_rng.randf_range(SHIFT[0], SHIFT[1]), "at": at})


## The posture held and shifted to at show time [param t]: its eight numbers (the body's four, then each
## hand's place).
func _held(t: float) -> PackedFloat32Array:
	_grow_holds(t + 1.0)
	var lo := 0
	var hi := _holds.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if float(_holds[mid]["t0"]) <= t:
			lo = mid
		else:
			hi = mid - 1
	var here: Dictionary = _holds[lo]
	var at: PackedFloat32Array = here["at"]
	if lo == 0:
		return at
	var from: PackedFloat32Array = (_holds[lo - 1] as Dictionary)["at"]
	var k := clampf((t - float(here["t0"])) / float(here["shift"]), 0.0, 1.0)
	k = k * k * k * (k * (k * 6.0 - 15.0) + 10.0)
	var out := PackedFloat32Array()
	out.resize(at.size())
	for a in at.size():
		out[a] = lerpf(from[a], at[a], k)
	return out


## THE BODY'S POSTURE AT SHOW TIME [param t]: across and down (face widths), nearer (the log of its scale)
## and its tilt (degrees) - held and shifted, a slow sway under it, eased (never cut) past [constant MOST].
func posture(t: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(4)
	if _posture_sd.size() < 4:
		return out
	var held := _held(t)
	for a in 4:
		var v := held[a] + SWAY * _posture_sd[a] * wander(t, SWAY_KNOT, "sway%d" % a)
		var most := float(MOST[3 + a])
		out[a] = most * tanh(v / most)
	return out


## HOW FAR EACH SHOULDER IS LIFTED AT SHOW TIME [param t] (x theirs left, y right; shares of their width):
## with the breath, and each wandering a little on its own.
func lifts(t: float) -> Vector2:
	var b := LIFT_BREATH * (breath(t) - 0.5)
	return Vector2(b + LIFT * wander(t, LIFT_KNOT, "lift_l"), b + LIFT * wander(t, LIFT_KNOT, "lift_r"))


## WHERE EACH RESTING HAND HAS MOVED AT SHOW TIME [param t] (theirs left, then right; shares of the
## shoulders' width): settled somewhere new at each shift of the body, drifting a little.
func hands(t: float) -> PackedVector2Array:
	var held := _held(t) if _posture_sd.size() >= 4 else PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
	var out := PackedVector2Array()
	for side in 2:
		out.append(Vector2(held[4 + side * 2] + HAND_DRIFT * wander(t, HAND_KNOT, "hand%dx" % side),
			held[5 + side * 2] + HAND_DRIFT * wander(t, HAND_KNOT, "hand%dy" % side)))
	return out


## A SMOOTH SEEDED WANDER at show time [param t], of spread about 1: a value every [param knot] seconds
## drawn from the seed and [param key], a cubic B-spline through them - so asked at any moment it is the
## same, and smooth in its slope.
func wander(t: float, knot: float, key: String) -> float:
	var u := t / knot
	var i := int(floor(u))
	var f := u - float(i)
	var p0 := _knot(i - 1, key)
	var p1 := _knot(i, key)
	var p2 := _knot(i + 1, key)
	var p3 := _knot(i + 2, key)
	var f2 := f * f
	var f3 := f2 * f
	var v := ((1.0 - f) * (1.0 - f) * (1.0 - f) * p0 + (3.0 * f3 - 6.0 * f2 + 4.0) * p1
		+ (-3.0 * f3 + 3.0 * f2 + 3.0 * f + 1.0) * p2 + f3 * p3) / 6.0
	# a B-spline through knots of spread 1 has a spread of about 0.69
	return v * 1.45


## Knot [param i] of the wander [param key]: normal, spread 1, from the seed.
func _knot(i: int, key: String) -> float:
	var h := hash([seed_value, key, i])
	var u1 := (float(h & 0xFFFF) + 0.5) / 65536.0
	var u2 := (float((h >> 16) & 0xFFFF) + 0.5) / 65536.0
	return sqrt(-2.0 * log(u1)) * cos(TAU * u2)


## HOW MUCH THE VOICE IS SPEAKING round show time [param t], 0..1: the share of the [constant SPEAKING]
## seconds either side that its sounds cover.
func speaking(t: float) -> float:
	if line.is_empty():
		return 0.0
	var covered := 0.0
	var a := t - SPEAKING
	var b := t + SPEAKING
	for i in range(maxi(0, _line_from(a) - 2), line.size()):
		var d: Dictionary = line[i]
		if float(d["t1"]) < a:
			continue
		if float(d["t0"]) > b:
			break
		if String(d["c"]) == "rest":
			continue
		covered += minf(b, float(d["t1"])) - maxf(a, float(d["t0"]))
	return clampf(covered / (b - a), 0.0, 1.0)


## HOW FULL THEIR CHEST IS AT SHOW TIME [param t], 0..1: let out while the voice speaks, drawn in over
## each pause, drawn in before the first word - each going on from where the last left it (the last few
## pauses are enough: one of half a second fills the chest, whatever came before).
func breath(t: float) -> float:
	var idle := 0.5 + 0.5 * sin(TAU * t / BREATH_IDLE)
	if line.is_empty():
		return idle
	var first := float((line[0] as Dictionary)["t0"])
	if t < first:
		return lerpf(idle, 1.0, smoothstep(first - BREATH_IN, first, t))
	# the last pause begun by now
	var lo := -1
	var hi := _rests.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if float(_rests[mid][0]) <= t:
			lo = mid
		else:
			hi = mid - 1
	var level := 1.0
	var since := first
	if lo >= 3:
		level = 0.5
		since = float(_rests[lo - 3][0])
	for i in range(maxi(0, lo - 3), lo + 1):
		var r: Array = _rests[i]
		level = clampf(level - BREATH_OUT * maxf(0.0, float(r[0]) - since), BREATH_LEAST, 1.0)
		level = lerpf(level, 1.0, smoothstep(0.0, 1.0, (minf(t, float(r[1])) - float(r[0])) / BREATH_IN))
		since = float(r[1])
		if t <= float(r[1]):
			return level
	return clampf(level - BREATH_OUT * (t - since), BREATH_LEAST, 1.0)


# --- the eyes ----------------------------------------------------------------------------------------

func _grow_glances(until: float) -> void:
	while _glances.is_empty() or float(_glances[-1]["t0"]) <= until:
		var last := 0.5 if _glances.is_empty() else float(_glances[-1]["t0"]) + float(_glances[-1]["hold"])
		var gap := -0.5 * GLANCE_EVERY * (log(maxf(1e-6, _glance_rng.randf())) + log(maxf(1e-6, _glance_rng.randf())))
		var pick := _glance_rng.randf()
		var look := "look_down"
		for g in GLANCES:
			pick -= float(GLANCES[g])
			if pick < 0.0:
				look = String(g)
				break
		_glances.append({"t0": last + maxf(GLANCE_GAP, gap), "look": look,
			"hold": _glance_rng.randf_range(GLANCE_HOLD[0], GLANCE_HOLD[1]), "deep": _glance_rng.randf_range(0.6, 1.0)})


## WHERE THEY ARE GLANCING AT SHOW TIME [param t]: `[look, how far 0..1, which glance]`, or how far 0 at the
## camera.
func glance(t: float) -> Array:
	_grow_glances(t + 2.0)
	for i in range(_glances.size() - 1, -1, -1):
		var g: Dictionary = _glances[i]
		var t0 := float(g["t0"])
		if t0 > t:
			continue
		var t1 := t0 + float(g["hold"])
		if t > t1 + GLANCE_TURN:
			break
		var k := smoothstep(0.0, 1.0, (t - t0) / GLANCE_TURN) * (1.0 - smoothstep(0.0, 1.0, (t - t1) / GLANCE_TURN))
		return [String(g["look"]), k * float(g["deep"]), i]
	return ["", 0.0, -1]

func _grow_blinks(until: float) -> void:
	var mean := 60.0 / blinks_per_min
	while _blinks.is_empty() or float(_blinks[-1]) <= until:
		var last := -1.0 if _blinks.is_empty() else float(_blinks[-1])
		# a gamma of shape 2: rarely too soon, sometimes long
		var gap := -0.5 * mean * (log(maxf(1e-6, _blink_rng.randf())) + log(maxf(1e-6, _blink_rng.randf())))
		_blinks.append(maxf(last, 0.0) + maxf(BLINK_GAP, gap))


## How closed a blink at [param at] is at [param t]: 0 open, 1 shut.
static func _closed(t: float, at: float) -> float:
	var d := t - at
	if d < 0.0 or d > BLINK[0] + BLINK[1] + BLINK[2]:
		return 0.0
	if d < BLINK[0]:
		return smoothstep(0.0, 1.0, d / BLINK[0])
	if d < BLINK[0] + BLINK[1]:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (d - BLINK[0] - BLINK[1]) / BLINK[2])


## HOW CLOSED THE EYES ARE AT SHOW TIME [param t] (0 open, 1 shut), and which blink it is.
func blink(t: float) -> Vector2:
	_grow_blinks(t + 1.0)
	var best := 0.0
	var which := -1.0
	var span := BLINK[0] + BLINK[1] + BLINK[2]
	for i in _blinks.size():
		var at := float(_blinks[i])
		if at > t:
			break
		if t - at <= span:
			var c := _closed(t, at)
			if c > best:
				best = c
				which = float(i)
	for at in _pauses:
		if float(at) <= t and t - float(at) <= span:
			var c := _closed(t, float(at))
			if c > best:
				best = c
				which = 100000.0 + float(at) * 100.0
	return Vector2(best, which)


## THE EYES AT SHOW TIME [param t]: `[[image, weight]]` - a blink, the still's own (-1) going through half
## closed to shut; else a glance, the still's own going to one of the library's looking that way; else the
## still's own. Each one of the library's drawn from the seed and the blink or glance.
func eyes(t: float) -> Array:
	var b := blink(t)
	if b.x <= 0.0 or not eyes_of.has("half"):
		var g := glance(t)
		if float(g[1]) > 0.0 and eyes_of.has(String(g[0])):
			var img := _one_of(eyes_of[String(g[0])], [String(g[0]), int(g[2])])
			return [[img, float(g[1])], [-1, 1.0 - float(g[1])]]
		return [[-1, 1.0]]
	var half := _one_of(eyes_of["half"], ["half", b.y])
	var shut := _one_of(eyes_of.get("closed", eyes_of["half"]), ["closed", b.y])
	if b.x <= 0.5:
		return [[-1, 1.0 - 2.0 * b.x], [half, 2.0 * b.x]]
	return [[half, 2.0 - 2.0 * b.x], [shut, 2.0 * b.x - 1.0]]


# --- the mouth ---------------------------------------------------------------------------------------

## THE LEARNED MOUTH, read from [param path] where it is, to choose among [param library]'s mouths.
func _learn(path: String, library: LikenessFace) -> void:
	_members = []
	_choices = {}
	var d: Variant = ActorFolder.read_json(path)
	if not (d is Dictionary) or library == null or library.mouth_blends.is_empty():
		return
	var m: Dictionary = d
	var sc: Dictionary = m.get("scores", {}) if m.get("scores") is Dictionary else {}
	if float(sc.get("ensemble", 0.0)) < LEARNED_LEAST or float(sc.get("ensemble", 0.0)) < float(sc.get("each_sound_mean", 0.0)) + LEARNED_BEYOND:
		return
	_classes = m.get("classes", [])
	_offsets = PackedFloat32Array(m.get("offsets", []))
	_window = float(m.get("window", 0.06))
	_mean = PackedFloat32Array(m.get("mean", []))
	_sd = PackedFloat32Array(m.get("sd", []))
	_weights = PackedFloat32Array(m.get("weights", []))
	var names: Array = m.get("names", [])
	_pushed = PackedInt32Array()
	for n in m.get("pushed", []):
		_pushed.append(names.find(n))
	for mem in m.get("members", []):
		var w1 := PackedFloat32Array()
		for row in (mem as Dictionary)["w1"]:
			w1.append_array(PackedFloat32Array(row))
		var w2 := PackedFloat32Array()
		for row in (mem as Dictionary)["w2"]:
			w2.append_array(PackedFloat32Array(row))
		var b1 := PackedFloat32Array((mem as Dictionary)["b1"])
		_members.append({"w1": w1, "b1": b1, "w2": w2, "b2": PackedFloat32Array((mem as Dictionary)["b2"]), "hidden": b1.size()})
	for img in library.mouth_blends:
		if (library.mouth_blends[img] as PackedFloat32Array).size() == _mean.size():
			_choices[img] = library.mouth_blends[img]
	_push = library.articulation
	_silence = _predict(_inputs_of_silence())
	# THE STILL'S OWN MOUTH IS SILENCE: what the ensemble says for none, so silence draws it, never a mouth
	# of the library's that happened to be nearer what was measured of the still
	_choices[-1] = _silence
	if _choices.is_empty() or _mean.is_empty():
		_members = []


## THE INPUTS AT [param t], as the ensemble was trained on them (actor.py's `contexts`): for each offset,
## how much of each class is heard in the window round it - the rest wherever none is. Sparse:
## `{input: share}`.
func _inputs(t: float) -> Dictionary:
	var out := {}
	var k := _classes.size()
	var rest := _classes.find("rest")
	var from := _line_from(t - 0.5)
	for j in _offsets.size():
		var a := t + _offsets[j] - _window * 0.5
		var b := a + _window
		var heard := 0.0
		for i in range(maxi(0, from - 2), line.size()):
			var ph: Dictionary = line[i]
			if float(ph["t0"]) >= b:
				break
			if String(ph["c"]) == "rest":
				continue
			var over := minf(b, float(ph["t1"])) - maxf(a, float(ph["t0"]))
			if over > 0.0:
				var c := _classes.find(String(ph["c"]))
				var at := j * k + (c if c >= 0 else rest)
				out[at] = float(out.get(at, 0.0)) + over / _window
				heard += over / _window
		if heard < 1.0:
			out[j * k + rest] = float(out.get(j * k + rest, 0.0)) + 1.0 - heard
	return out


func _inputs_of_silence() -> Dictionary:
	var out := {}
	for j in _offsets.size():
		out[j * _classes.size() + _classes.find("rest")] = 1.0
	return out


## WHAT THE ENSEMBLE SAYS for [param x] (sparse inputs): their mouth's blendshapes, the members' mean.
func _predict(x: Dictionary) -> PackedFloat32Array:
	var m := _mean.size()
	var out := PackedFloat32Array()
	out.resize(m)
	for mem in _members:
		var hn := int(mem["hidden"])
		var w1: PackedFloat32Array = mem["w1"]
		var w2: PackedFloat32Array = mem["w2"]
		var h: PackedFloat32Array = (mem["b1"] as PackedFloat32Array).duplicate()
		for i in x:
			var v := float(x[i])
			var row := int(i) * hn
			for u in hn:
				h[u] += v * w1[row + u]
		var b2: PackedFloat32Array = mem["b2"]
		for o in m:
			out[o] += b2[o]
		for u in hn:
			var hu := tanh(h[u])
			var row := u * m
			for o in m:
				out[o] += hu * w2[row + o]
	for o in m:
		out[o] = (out[o] / float(_members.size())) * _sd[o] + _mean[o]
	return out


## THE MOUTH THE ENSEMBLE SAYS AT [param t], pushed past their own as the library was: the blendshapes.
func learned(t: float) -> PackedFloat32Array:
	var y := _predict(_inputs(t))
	for i in _pushed:
		if i >= 0:
			y[i] = clampf(_silence[i] + (y[i] - _silence[i]) * _push, 0.0, 1.0)
	return y


## THE MOUTH AT SHOW TIME [param t]: `[[image, weight]]`, at most two images mixed - the two library mouths
## (or the still's own, -1) nearest the learned mouth where there is one, the farther less the third; else
## the two strongest pulls, each one of its class's prototypes (the still's own for the rest).
func mouth(t: float) -> Array:
	if not _members.is_empty():
		var y := learned(t)
		var near: Array = []
		for img in _choices:
			var b: PackedFloat32Array = _choices[img]
			var d := 0.0
			for o in y.size():
				var z := (y[o] - b[o]) / _sd[o]
				d += z * z * _weights[o]
			near.append([int(img), sqrt(d)])
		near.sort_custom(func(p: Array, q: Array) -> bool: return float(p[1]) < float(q[1]))
		if near.size() < 3:
			return [[int(near[0][0]), 1.0]]
		# THE NEAREST WHOLE, THE NEXT BY HOW FAR IT IS FROM THE THIRD over how far the nearest is: as the
		# order changes nothing jumps - the next falls to nothing as the third overtakes it, and two
		# equally near weigh alike
		var d1 := float(near[0][1])
		var second := clampf((float(near[2][1]) - float(near[1][1])) / maxf(float(near[2][1]) - d1, 1e-3), 0.0, 1.0)
		if second <= 1e-6:
			return [[int(near[0][0]), 1.0]]
		return [[int(near[0][0]), 1.0 / (1.0 + second)], [int(near[1][0]), second / (1.0 + second)]]
	var out: Array = []
	for p in Visemes.strongest(t, line, _line_from(t)):
		var c := String(p[1])
		var img := -1
		if c != "rest" and mouths_of.has(c):
			img = _one_of(mouths_of[c], [c, int(p[0])])
		out.append([img, float(p[2])])
	return out


## THE SOUNDS PULLING AT THE MOUTH AT [param t]: `[[_, class, weight]]`, the two strongest less the third
## ([method Visemes.strongest]) - what the 2D mouth draws from the library, and a head of splats from each
## sound's scores.
func pulls(t: float) -> Array:
	return Visemes.strongest(t, line, _line_from(t))


## One of [param images], drawn from the seed and [param key].
func _one_of(images: Array, key: Array) -> int:
	if images.is_empty():
		return -1
	return int(images[absi(hash([seed_value] + key)) % images.size()])


## Where in the phone line to start looking for [param t] (a binary search on the middles).
func _line_from(t: float) -> int:
	var lo := 0
	var hi := line.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if float((line[mid] as Dictionary)["mid"]) < t:
			lo = mid + 1
		else:
			hi = mid
	return lo
