extends RefCounted
class_name Winds

## Winds - the air moving over a scene: a breeze from one side that rises and falls a little, and GUSTS
## now and then, each a swell that rises in a second or so and dies away over a few. One wind for the
## whole table: it stirs what the sun falls through, swings what hangs and ripples what flutters
## ([Lights]), and carries what drifts in the air - petals, leaves, seeds ([Effects], `drift`). The set
## dresser writes it as the light's `wind` (the user, 2026-10-08: "a table under a tree, where the
## shadows cast upon the table would look like those cast through foliage, gently moving in the wind
## ... petals ... settling on the table, or getting carried-off from the table again after another
## gust").
##
## EVERYTHING IS A FUNCTION OF SHOW TIME: the gusts are planned once over [constant Lights.HORIZON] from
## the seed ([method plan]), and the breeze is a few slow sines - so how far the air has carried a thing
## between two times ([method carried]) is a sum in closed form, never stepped, and a render, a scrub and
## a picture see the same petal in the same place.

## The breeze at strength 1 (m/s, at the table: a sheltered table's air is slower than the open wind's).
const BREEZE := 0.6
## A gust at its strongest, at `gusts` 1 on a strong wind (m/s).
const GUST := 1.6
## A gust's rise and its fall (seconds, the least and the most of each).
const RISE := Vector2(0.6, 1.5)
const FALL := Vector2(1.5, 4.0)
## The longest a gust lasts: a time this long after one starts, it is over.
const LONGEST := 5.5
## The breeze's slow swells: how fast (radians a second) and how much of it each is.
const SWELLS := [Vector2(0.11, 0.3), Vector2(0.27, 0.2)]
## How far a gust turns off the wind's own way (radians, either side).
const VEER := 0.35
## The speed that counts as the strongest air (m/s) when a wind is said as 0-1 ([method strength_at]).
const FULL := 1.5
## A wind no one wrote: a light breath, gusting now and then.
const STILL := {"from": 270.0, "strength": 0.15, "gusts": 0.35, "every": 40.0}


## THE VOCABULARY, as an agent reads it: one line of [method Lights.describe].
static func describe() -> String:
	return "- wind: {\"from\" (where it blows from, as a sun's `from`), \"strength\" 0-1 (0 still air, 0.2 a breath, 0.5 a breeze, 1 a strong wind), \"gusts\" 0-1 (steady to gusty: how hard a gust blows over the breeze), \"every\" (seconds between gusts, about)} - the air moving over the table. It stirs the leaves, fronds and branches the sun falls through and ripples an awning's edge, harder in a gust; swings what hangs and ripples what flutters among the shadows; and carries whatever drifts in the air (the air's `drift`: petals, leaves, seeds) - a gust lifts what lies on the cloth and carries it off. Leave it out for still air (anything drifting then falls through a faint breath)."


## WHATEVER AN AGENT WROTE as `wind`, made safe: `{}` when nothing was written. What had to change is said
## in [param notes].
static func sanitize(raw: Variant, notes: PackedStringArray = PackedStringArray()) -> Dictionary:
	if raw == null:
		return {}
	if not (raw is Dictionary):
		notes.append("the wind was not an object {from, strength, gusts, every} - still air")
		return {}
	var d: Dictionary = raw
	if d.is_empty():
		return {}
	return {"from": Lights._from(d.get("from"), float(STILL["from"]), "the wind", notes),
		"strength": Props._num(d.get("strength"), 0.3, 0.0, 1.0), "gusts": Props._num(d.get("gusts"), 0.5, 0.0, 1.0),
		"every": Props._num(d.get("every"), 30.0, 4.0, 600.0)}


## THE WIND PLANNED for [param wind] (made safe; `{}` is [constant STILL]) on [param seed]: the way it
## blows (`dir`, a unit vector in the table's xz, where the air goes), the breeze, and every gust over the
## [constant Lights.HORIZON] - starts, peaks, rises, falls, how hard (m/s) and which way - with the air
## each carried, summed (and how far, `runs`), so [method carried] and [method gust_run] are lookups.
## Pure: the same wind and seed, the same gusts.
static func plan(wind: Dictionary, seed: int) -> Dictionary:
	var w: Dictionary = wind if not wind.is_empty() else STILL
	var a := deg_to_rad(float(w["from"]))
	# FROM, as a sun's: 0 behind the reader, 90 their right - the air goes the other way
	var dir := -Vector2(sin(a), cos(a))
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed, "wind"])
	var strength := float(w["strength"])
	var every := float(w["every"])
	var peak := (0.25 + strength) * float(w["gusts"]) * GUST
	var starts := PackedFloat32Array()
	var rises := PackedFloat32Array()
	var falls := PackedFloat32Array()
	var peaks := PackedFloat32Array()
	var dirs := PackedVector2Array()
	var sums := PackedVector2Array([Vector2.ZERO])
	var runs := PackedFloat32Array([0.0])
	var t := r.randf_range(0.2, 1.0) * every
	while t < Lights.HORIZON and peak > 0.001:
		var rise := r.randf_range(RISE.x, RISE.y)
		var fall := r.randf_range(FALL.x, FALL.y)
		var p := peak * r.randf_range(0.45, 1.0)
		var g := dir.rotated(r.randf_range(-VEER, VEER))
		starts.append(t)
		rises.append(rise)
		falls.append(fall)
		peaks.append(p)
		dirs.append(g)
		sums.append(sums[sums.size() - 1] + g * p * (rise + fall) * 0.5)
		runs.append(runs[runs.size() - 1] + p * (rise + fall) * 0.5)
		t += every * r.randf_range(0.3, 1.7)
	var phases := PackedFloat32Array([r.randf() * TAU, r.randf() * TAU])
	return {"dir": dir, "breeze": strength * BREEZE, "phases": phases, "starts": starts, "rises": rises, "falls": falls,
		"peaks": peaks, "dirs": dirs, "sums": sums, "runs": runs, "written": not wind.is_empty()}


## THE BREEZE'S SPEED at [param t] (m/s), gusts aside.
static func breeze_at(p: Dictionary, t: float) -> float:
	var ph: PackedFloat32Array = p["phases"]
	var s := 1.0
	for i in SWELLS.size():
		s += (SWELLS[i] as Vector2).y * sin((SWELLS[i] as Vector2).x * t + ph[i])
	return float(p["breeze"]) * s


## Gust [param i]'s share of its peak at [param t]: 0 before and after it, rising and falling as a
## raised cosine.
static func swell(p: Dictionary, i: int, t: float) -> float:
	var t0 := float((p["starts"] as PackedFloat32Array)[i])
	var rise := float((p["rises"] as PackedFloat32Array)[i])
	var fall := float((p["falls"] as PackedFloat32Array)[i])
	if t <= t0 or t >= t0 + rise + fall:
		return 0.0
	if t < t0 + rise:
		return 0.5 * (1.0 - cos(PI * (t - t0) / rise))
	return 0.5 * (1.0 + cos(PI * (t - t0 - rise) / fall))


## How far gust [param i] has carried the air by [param t] (meters, at its peak's speed): a raised
## cosine's integral, so none before it and all of it after.
static func swell_carry(p: Dictionary, i: int, t: float) -> float:
	var t0 := float((p["starts"] as PackedFloat32Array)[i])
	var rise := float((p["rises"] as PackedFloat32Array)[i])
	var fall := float((p["falls"] as PackedFloat32Array)[i])
	if t <= t0:
		return 0.0
	if t >= t0 + rise + fall:
		return (rise + fall) * 0.5
	if t < t0 + rise:
		var s := (t - t0) / rise
		return rise * 0.5 * (s - sin(PI * s) / PI)
	var u := (t - t0 - rise) / fall
	return rise * 0.5 + fall * 0.5 * (u + sin(PI * u) / PI)


## The gusts that may be blowing at [param t]: from the first that can still be, to the last begun.
static func _blowing(p: Dictionary, t: float) -> Vector2i:
	var starts: PackedFloat32Array = p["starts"]
	return Vector2i(starts.bsearch(t - LONGEST), starts.bsearch(t))


## THE WIND'S SPEED at [param t] (m/s), breeze and gusts.
static func speed_at(p: Dictionary, t: float) -> float:
	var v := breeze_at(p, t)
	var span := _blowing(p, t)
	var peaks: PackedFloat32Array = p["peaks"]
	for i in range(span.x, span.y):
		v += peaks[i] * swell(p, i, t)
	return v


## HOW HARD IT BLOWS at [param t], 0 still to 1 the strongest ([constant FULL]).
static func strength_at(p: Dictionary, t: float) -> float:
	return clampf(speed_at(p, t) / FULL, 0.0, 1.0)


## How hard the gusts alone blow at [param t], 0-1.
static func gust_at(p: Dictionary, t: float) -> float:
	return clampf((speed_at(p, t) - breeze_at(p, t)) / FULL, 0.0, 1.0)


## HOW FAR THE AIR HAS CARRIED A THING from show time 0 to [param t] (meters in the table's xz): the
## breeze's run, every gust over, and the parts of those blowing. [method carried_between] is the
## difference of two.
static func carried(p: Dictionary, t: float) -> Vector2:
	var ph: PackedFloat32Array = p["phases"]
	var run := t
	for i in SWELLS.size():
		var sw: Vector2 = SWELLS[i]
		run -= sw.y / sw.x * (cos(sw.x * t + ph[i]) - cos(ph[i]))
	var out: Vector2 = (p["dir"] as Vector2) * float(p["breeze"]) * run
	var span := _blowing(p, t)
	out += (p["sums"] as PackedVector2Array)[span.x]
	var peaks: PackedFloat32Array = p["peaks"]
	var dirs: PackedVector2Array = p["dirs"]
	for i in range(span.x, span.y):
		out += dirs[i] * peaks[i] * swell_carry(p, i, t)
	return out


static func carried_between(p: Dictionary, t0: float, t1: float) -> Vector2:
	return carried(p, t1) - carried(p, t0)


## HOW MUCH GUST HAS BLOWN between [param t0] and [param t1]: the air every gust carried, as a length
## (meters, whichever way each went) - what sets a piece in the air turning, harder the harder it blows.
static func gust_run(p: Dictionary, t0: float, t1: float) -> float:
	return _run(p, t1) - _run(p, t0)


static func _run(p: Dictionary, t: float) -> float:
	var span := _blowing(p, t)
	var out := float((p["runs"] as PackedFloat32Array)[span.x])
	var peaks: PackedFloat32Array = p["peaks"]
	for i in range(span.x, span.y):
		out += peaks[i] * swell_carry(p, i, t)
	return out


## How far gust [param i] alone carried the air between [param t0] and [param t1] (meters, xz).
static func gust_carried(p: Dictionary, i: int, t0: float, t1: float) -> Vector2:
	var k := float((p["peaks"] as PackedFloat32Array)[i])
	return (p["dirs"] as PackedVector2Array)[i] * k * (swell_carry(p, i, t1) - swell_carry(p, i, t0))


## THE FIRST GUST at or after [param t] that blows at least [param least] m/s: its index, or -1.
static func next_gust(p: Dictionary, t: float, least: float) -> int:
	var starts: PackedFloat32Array = p["starts"]
	var peaks: PackedFloat32Array = p["peaks"]
	for i in range(starts.bsearch(t), starts.size()):
		if peaks[i] >= least:
			return i
	return -1


## The gust [param i]'s start, how long it blows and its peak's time.
static func gust_span(p: Dictionary, i: int) -> Vector3:
	var t0 := float((p["starts"] as PackedFloat32Array)[i])
	var rise := float((p["rises"] as PackedFloat32Array)[i])
	return Vector3(t0, rise + float((p["falls"] as PackedFloat32Array)[i]), t0 + rise)
