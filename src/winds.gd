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
##
## IT REACHES EVERYTHING IN THE AIR (the user, 2026-10-08: "you might expect wind to effect the flame from
## candles, causing flickering (which would also chain into shadows moving) ... when there are little
## flying pixies/particles, you would expect wind to make those move"): a FLAME leans downwind and
## flickers in the eddies, guttering in a strong gust, and its light leans with it, so the shadows move
## ([method flame]: the candles on the table, the torches and fires round it); DUST, SNOW AND EMBERS are
## carried through; what FLIES - pixies, fireflies, wisps, flies - holds its place against the wind as
## hard as it can fly and gives way only to what is more, flying back once the gust has passed
## ([method pushed]); a burst's smoke and sparks drift off downwind, and fog rolls with it ([Effects]).
## The air is not smooth: near the ground it churns about its mean in EDDIES carried past on it
## ([method air_at]), so a flame flickers faster the harder it blows.
##
## ONLY A WIND THE LIGHT WROTE moves them ([method blows]): a room with its windows shut has still air, and
## its candles burn in the room's own faint drafts. Still air planned for what drifts ([constant STILL]:
## a petal must fall through something) moves no flame and no mote.

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
## THE EDDIES: how much the air near the ground churns about its mean (the share of its speed - 0.2 to 0.4
## over open ground and among things), and their sizes (meters: the big swirls a mote is tossed in, the
## small ones a flame flickers in). The noise they are drawn from spreads by [constant EDDY_SD] (measured),
## brought to one here.
const TURBULENCE := 0.3
const EDDIES := [0.5, 0.08]
const EDDY_SD := 0.231
## A FLAME IN A DRAFT ([method flame]): its hot gas rises at about the square root of g times its height
## (a candle's 3 cm flame draws at half a meter a second), and a draft as fast as that leans it 45
## degrees - tan(tilt) is the draft over the draw - never past [constant FLAME_TILT]. Between
## [constant GUTTER]'s two multiples of its draw it gutters: shorter, dimmer, as a candle does in a gust.
const FLAME_TILT := 1.2
const GUTTER := Vector2(1.8, 5.0)
## A FLIER PUSHED ([method pushed]): the wind it remembers - this many of its own returns back - and the
## steps that span is summed in.
const MEMORY := 4.0
const MEMORY_STEPS := 16


## THE VOCABULARY, as an agent reads it: one line of [method Lights.describe].
static func describe() -> String:
	return "- wind: {\"from\" (where it blows from, as a sun's `from`), \"strength\" 0-1 (0 still air, 0.2 a breath, 0.5 a breeze, 1 a strong wind), \"gusts\" 0-1 (steady to gusty: how hard a gust blows over the breeze), \"every\" (seconds between gusts, about)} - the air moving over the table. It stirs the leaves, fronds and branches the sun falls through and ripples an awning's edge, harder in a gust; swings what hangs and ripples what flutters among the shadows; carries whatever drifts in the air (the air's `drift`: petals, leaves, seeds) - a gust lifts what lies on the cloth and carries it off; leans and flickers every open flame - the candles on the table, torches and fires round it - so their light and shadows dance (a flame under glass hardly feels it); carries dust, snow and embers through the shot, while pixies, fireflies, wisps and flies hold their place against it and a strong gust pushes them off for a moment; and blows a burst's smoke and sparks downwind and fog along with it. Leave it out for still air - a room with its windows and doors shut has none, and a draft through an open window or door is a breath (0.1 to 0.25); anything drifting then falls through a faint breath that moves nothing else."


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
	# the eddies on dice of their own, so the gusts stay as they were planned
	var eddies := FastNoiseLite.new()
	eddies.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	eddies.frequency = 1.0
	eddies.seed = hash([seed, "eddies"]) & 0x7FFFFFFF
	return {"dir": dir, "breeze": strength * BREEZE, "phases": phases, "starts": starts, "rises": rises, "falls": falls,
		"peaks": peaks, "dirs": dirs, "sums": sums, "runs": runs, "written": not wind.is_empty(), "eddies": eddies}


## WHETHER [param p] MOVES WHAT IS IN THE AIR - flames, motes, smoke, fog: a wind the light wrote. Still
## air ([constant STILL], planned for what drifts) and `{}` move nothing.
static func blows(p: Dictionary) -> bool:
	return not p.is_empty() and bool(p.get("written", false))


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


## THE WIND'S VELOCITY at [param t] (m/s in the table's xz): the breeze along its way, each gust along its
## own - what [method carried] sums.
static func velocity_at(p: Dictionary, t: float) -> Vector2:
	var v: Vector2 = (p["dir"] as Vector2) * breeze_at(p, t)
	var span := _blowing(p, t)
	var peaks: PackedFloat32Array = p["peaks"]
	var dirs: PackedVector2Array = p["dirs"]
	for i in range(span.x, span.y):
		v += dirs[i] * peaks[i] * swell(p, i, t)
	return v


## THE EDDIES at [param at] (the table's space, meters) at [param t], spread to one: swirls of
## [constant EDDIES]' sizes, carried past on the wind (frozen in it as it goes, each turning over in the
## time its churn takes to cross it - [constant TURBULENCE] of the breeze, or of a breath at least), so
## what stands still sees them pass faster the harder it blows, and what rides the air keeps the swirl
## it is in. Up and down half as much as across: the ground flattens them. [param fine] false leaves the
## small ones out: what rides the air is tossed by the big swirls, and an eddy carries nothing much
## further than it is wide.
static func eddy(p: Dictionary, t: float, at: Vector3, fine := true) -> Vector3:
	var n: FastNoiseLite = p["eddies"]
	var c := carried(p, t)
	var x := at.x - c.x
	var z := at.z - c.y
	var e := Vector3.ZERO
	var ws := 0.0
	var churn := TURBULENCE * maxf(float(p["breeze"]), 0.1)
	for k in (EDDIES.size() if fine else 1):
		var l := float(EDDIES[k])
		var w := 0.8 if k == 0 else 0.6
		var tt := t * churn / l + 17.0 * float(k)
		e += Vector3(n.get_noise_3d(x / l, z / l, tt), 0.5 * n.get_noise_3d(x / l + 31.0, z / l, tt),
			n.get_noise_3d(x / l, z / l + 57.0, tt)) * w
		ws += w * w
	return e / (EDDY_SD * sqrt(ws))


## THE AIR AT A PLACE: the wind's velocity at [param t] and its eddies at [param at], churning about it by
## [constant TURBULENCE] of its speed (m/s; y up).
static func air_at(p: Dictionary, t: float, at: Vector3) -> Vector3:
	var v := velocity_at(p, t)
	return Vector3(v.x, 0.0, v.y) + eddy(p, t, at) * TURBULENCE * v.length()


## A FLAME [param size] meters tall at [param at] in the air at [param t], [param open] the share of a draft
## that reaches it (a chimney, a lantern's glass or a hurricane glass keeps most of it off). `axis`: which
## way it points, a unit vector - straight up in still air, leaning downwind as tan(tilt) = the draft over
## its draw ([constant FLAME_TILT]); `mid`: how far its middle has moved from where it burns upright
## (meters, for its light: the shadows lean with it); `tall`: its length against its still length - a
## little longer in a draft that stretches it, longer in an eddy rising through it, shorter as it gutters;
## `bright`: dimmer as it gutters ([constant GUTTER]); `draft`: m/s.
static func flame(p: Dictionary, t: float, at: Vector3, size: float, open := 1.0) -> Dictionary:
	var a := air_at(p, t, at) * open
	var h := Vector2(a.x, a.z)
	var u := h.length()
	var draw := sqrt(9.81 * maxf(size, 0.005))
	var tilt := minf(atan(u / draw), FLAME_TILT)
	var d := h / u if u > 1e-5 else Vector2.ZERO
	var axis := Vector3(d.x * sin(tilt), cos(tilt), d.y * sin(tilt))
	var gutter := smoothstep(GUTTER.x * draw, GUTTER.y * draw, u)
	var tall := (1.0 + 0.15 * minf(u / draw, 1.0)) * (1.0 - 0.45 * gutter) * clampf(1.0 + 0.5 * a.y / draw, 0.6, 1.4)
	return {"axis": axis, "mid": (axis * tall - Vector3.UP) * size * 0.5, "tall": tall, "bright": 1.0 - 0.6 * gutter,
		"draft": u}


## THE WIND A FLIER FEELS, sampled for [method pushed]: its velocity over the last [constant MEMORY] of the
## flier's returns ([param back], a second) before [param t], newest first.
static func memory(p: Dictionary, t: float, back: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var step := MEMORY / maxf(back, 0.05) / float(MEMORY_STEPS)
	for j in MEMORY_STEPS:
		out.append(velocity_at(p, maxf(t - (float(j) + 0.5) * step, 0.0)))
	return out


## HOW FAR A FLIER IS PUSHED from where it holds itself (meters, xz), from the wind it felt ([method
## memory], with the same [param back]): it flies against the wind as hard as it can - [param airspeed]
## m/s - and gives way only to what is more, and to a little of what it beats, up to [param give] of it as
## it nears its limit (none holds perfectly still against a wind it can barely beat); once a gust has
## passed it flies back, [param back] of the way a second. The wind
## beyond it, summed with each moment's weight fading as it recedes - so a breeze it can beat moves it
## barely, a gust past its strength carries it off, and it comes home after. Pure: the wind is planned.
static func pushed(felt: PackedVector2Array, back: float, airspeed: float, give: float) -> Vector2:
	var step := MEMORY / maxf(back, 0.05) / float(felt.size())
	var out := Vector2.ZERO
	for j in felt.size():
		var v := felt[j]
		var s := v.length()
		var beyond := v * (maxf(s - airspeed, 0.0) / s) if s > 1e-5 else Vector2.ZERO
		var slip := give * minf(s / maxf(airspeed, 1e-3), 1.0)
		out += (beyond + (v - beyond) * slip) * exp(-back * (float(j) + 0.5) * step) * step
	return out


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
