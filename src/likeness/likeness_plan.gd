extends RefCounted
class_name LikenessPlan

## LikenessPlan - how the actor moves at each moment, on their still (next/likeness.md, "The second
## build"): the head, the eyes and the mouth, each A PURE FUNCTION OF SHOW TIME - asked for any moment, the
## answer depends on nothing asked before it, so a seek and an export draw what the live show drew.
##
## THE HEAD ([method head]): their own motion (`motion.json`: its quick part, the slow drift out, where they
## face the camera), played in pieces drawn from the seed, each going into the next over [constant BLEND]
## seconds - the numbers mixed, so there is no cut - read smoothly between the survey's looks, scaled to a
## calm size ([constant CALM] of their own, at most [constant MOST]) and livelier while the voice speaks.
##
## THE EYES ([method eyes]): blinks at their own rate (`motion.json`'s), at times drawn from the seed, and
## one at most pauses in the voice, as people blink as a phrase ends; a blink closes in 70 ms, holds 40 and
## opens in 130. The open eye is the still's own; half and fully closed are the library's.
##
## THE MOUTH ([method mouth]): the voice's phones pulling ([Visemes.pulls]), the two strongest less the
## third ([Visemes.strongest]), each as one of its class's prototypes - which one drawn from the seed and
## the phone, so a sound said twice may be said with two of their mouths. Silence is the still's own mouth.

## Seconds one piece of motion goes into the next over.
const BLEND := 0.8
## A piece of motion lasts this long, at least and at most (seconds).
const PIECE := [4.0, 9.0]
## THE MOTION'S SIZE: each axis at this share of their own spread, never past [constant MOST] of it
## (degrees of yaw, pitch and roll; face widths across and down; the log of nearness) - eased, not cut,
## past it. Their own is how they move while they talk to a camera; a still bent by it should move less.
const CALM := 0.6
const MOST := [5.0, 4.0, 3.0, 0.05, 0.04, 0.03]
## While they are silent the head moves at this share of what it does while they speak.
const QUIET := 0.55
## Seconds round a moment the voice's speaking is judged over.
const SPEAKING := 0.6
## A BLINK: seconds closing, held, opening.
const BLINK := [0.07, 0.04, 0.13]
## The shortest gap between two blinks (seconds), and how often a pause in the voice is blinked at.
const BLINK_GAP := 0.6
const PAUSE_BLINK := 0.6
## A pause this long or longer is one a blink may fall in.
const PAUSE := 0.35

var seed_value := 1
var rate := 5.0
var runs: Array = []          # [PackedFloat32Array of rows * 6] per run
var lengths := PackedInt32Array()
var blinks_per_min := 16.0
var line: Array = []          # the voice's phones as classes ([Visemes.timeline])
var mouths_of := {}           # class -> [image]
var eyes_of := {}             # state -> [image]

var _pieces: Array = []       # [{t0, run, at, rows}] ascending, grown as far as asked
var _rng := RandomNumberGenerator.new()
var _total_rows := 0
var _blinks: Array = []       # the seeded blinks' times, ascending, grown as far as asked
var _blink_rng := RandomNumberGenerator.new()
var _pauses: Array = []       # the voice's pauses' blink times


## Read `motion.json`; [param library] (a [LikenessFace]) names the mouths and eyes. "" when sound.
func setup(motion_path: String, library: LikenessFace, seed_in: int) -> String:
	seed_value = seed_in
	mouths_of = library.mouths_of if library != null else {}
	eyes_of = library.eyes_of if library != null else {}
	runs = []
	lengths = PackedInt32Array()
	_total_rows = 0
	var m: Variant = ActorFolder.read_json(motion_path)
	if not (m is Dictionary):
		return "their motion is not made"
	var d: Dictionary = m
	rate = maxf(1.0, float(d.get("rate", 5.0)))
	blinks_per_min = clampf(float(d.get("blinks_per_min", 16.0)), 4.0, 40.0)
	for r in d.get("runs", []):
		var rows: Array = (r as Dictionary).get("rows", [])
		if rows.size() < int(ceil(PIECE[0] * rate + BLEND * rate)) + 4:
			continue
		var flat := PackedFloat32Array()
		for row in rows:
			for i in 6:
				flat.append(float(row[i]))
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


## THE VOICE'S PHONES ([param phones], `[{p, t0, t1}]`): the mouth's line, and the pauses a blink may fall in.
func set_voice(phones: Array) -> void:
	line = Visemes.timeline(phones)
	_pauses = []
	for k in line.size():
		var ph: Dictionary = line[k]
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


## A piece's motion at show time [param t]: its rows read between looks (Catmull-Rom), relative to the
## piece's first, so a piece starts where the head is.
func _sample(p: Dictionary, t: float) -> PackedFloat32Array:
	var flat: PackedFloat32Array = runs[int(p["run"])]
	var n := lengths[int(p["run"])]
	var u := float(p["at"]) + (t - float(p["t0"])) * rate
	var i := clampi(int(floor(u)), 1, n - 3)
	var f := clampf(u - float(i), 0.0, 1.0)
	var out := PackedFloat32Array()
	out.resize(6)
	for a in 6:
		var p0 := flat[(i - 1) * 6 + a]
		var p1 := flat[i * 6 + a]
		var p2 := flat[(i + 1) * 6 + a]
		var p3 := flat[(i + 2) * 6 + a]
		out[a] = 0.5 * (2.0 * p1 + (p2 - p0) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
			+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * f * f * f)
	return out


## THE HEAD AT SHOW TIME [param t]: yaw, pitch, roll (degrees), across, down (face widths), nearer (the
## log of its scale) - their own motion, calm, livelier while the voice speaks.
func head(t: float) -> PackedFloat32Array:
	var out := PackedFloat32Array([0, 0, 0, 0, 0, 0])
	if runs.is_empty():
		return out
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
		for a in 6:
			here[a] = lerpf(here[a], nxt[a], k)
	var lively := lerpf(QUIET, 1.0, speaking(t))
	for a in 6:
		var most := float(MOST[a])
		out[a] = most * tanh(here[a] * CALM * lively / most)
	return out


## HOW MUCH THE VOICE IS SPEAKING round show time [param t], 0..1: the share of the [constant SPEAKING]
## seconds either side that its sounds cover.
func speaking(t: float) -> float:
	if line.is_empty():
		return 0.0
	var covered := 0.0
	var a := t - SPEAKING
	var b := t + SPEAKING
	for ph in line:
		var d: Dictionary = ph
		if float(d["t1"]) < a:
			continue
		if float(d["t0"]) > b:
			break
		if String(d["c"]) == "rest":
			continue
		covered += minf(b, float(d["t1"])) - maxf(a, float(d["t0"]))
	return clampf(covered / (b - a), 0.0, 1.0)


# --- the eyes ----------------------------------------------------------------------------------------

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


## THE EYES AT SHOW TIME [param t]: `[[image, weight]]` - the still's own (-1) going through half closed
## to shut, one of the library's for each, drawn from the seed and the blink.
func eyes(t: float) -> Array:
	var b := blink(t)
	if b.x <= 0.0 or not eyes_of.has("half"):
		return [[-1, 1.0]]
	var half := _one_of(eyes_of["half"], ["half", b.y])
	var shut := _one_of(eyes_of.get("closed", eyes_of["half"]), ["closed", b.y])
	if b.x <= 0.5:
		return [[-1, 1.0 - 2.0 * b.x], [half, 2.0 * b.x]]
	return [[half, 2.0 - 2.0 * b.x], [shut, 2.0 * b.x - 1.0]]


# --- the mouth ---------------------------------------------------------------------------------------

## THE MOUTH AT SHOW TIME [param t]: `[[image, weight]]` - the two strongest pulls, each one of its class's
## prototypes (the still's own, -1, for the rest), at most two images mixed.
func mouth(t: float) -> Array:
	var out: Array = []
	for p in Visemes.strongest(t, line, _line_from(t)):
		var c := String(p[1])
		var img := -1
		if c != "rest" and mouths_of.has(c):
			img = _one_of(mouths_of[c], [c, int(p[0])])
		out.append([img, float(p[2])])
	return out


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
