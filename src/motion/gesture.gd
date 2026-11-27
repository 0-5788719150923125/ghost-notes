extends RefCounted
class_name Gesture

## Gesture - a hand's motion as a pure function of time (next/studio.md, "Human motion"): the strokes of a rub, a roll of
## taps, a reach from one place to another, and a held thing that is never still. Nothing here moves in a straight line or
## at a constant speed, and nothing repeats exactly.
##
## Each gesture is a PLAN: tables sampled [constant RATE] times a second from a seed and a few settings, read at any moment
## ([method at], [method at3]). The same tables are what a sound is made from, so what is seen and what is heard are one
## motion. A table is made once, off the app's thread where it is long; reading it is a lookup.
##
## What it keeps of how people move:
## - a reach is minimum-jerk (Flash and Hogan 1985: speed a bell, still at both ends) along a bowed path, and a quick one
##   ends a little off and is corrected by a small second move (Meyer et al. 1988);
## - a rub is rhythmic: its phase runs at a pace that drifts (about [constant PACE_DRIFT] either way, slow waves that never
##   line up), each cycle's length, arc and lean drawn on from the last (an AR(1), [constant CYCLE_AR]); the stroke out is
##   a little longer and pressed harder than the stroke back ([constant LEAN]), out and back on different arcs (a thin lens,
##   never a line), still at each turn; a circle is an ellipse traced at a varying rate, which keeps the two-thirds power
##   law (Lacquaniti, Terzuolo and Viviani 1983: speed falls where the path bends);
## - the hand presses hardest where it moves fastest on the stroke out, and lands and lifts rather than appearing;
## - assumptions break now and then, seeded: it hesitates mid-stroke, lifts and sets down a little elsewhere (a re-grip),
##   or hurries one cycle;
## - a rub may be OPEN (`open`): made as long as asked, the same wherever two lengths of it overlap, so a hand can go on for as
##   long as the words do - no break drawn against its end, no lift at it;
## - taps come in rolls (two to five, quick, the first hardest) with rests between, each lifted slowly and struck
##   accelerating, landing a millimeter or two from the last;
## - a held thing drifts on slow waves, rises and falls with a breath and trembles at 8-12 Hz (physiological tremor,
##   tens of micrometers), more while it moves (signal-dependent noise, Harris and Wolpert 1998).
##
## Lengths are meters, times seconds, forces newtons. Gate: tests/motion/gesture_check.gd.

## Samples a second of every table: what a sound's lanes are made from.
const RATE := 300.0
## How far a rub's pace drifts either way (a share), the AR(1) memory of each cycle's draws and their spread (a share), and
## the share of a cycle the stroke out takes.
const PACE_DRIFT := 0.05
const CYCLE_AR := 0.6
const CYCLE_SPREAD := 0.09
const LEAN := 0.54
## How far a rub's middle wanders (m), and the share of the stroke out's bow the stroke back keeps (bowing the other way).
const WANDER := 0.004
## An open rub's blocks of time, each drawing its own breaks (s).
const BLOCK := 8.0
const BACK_BOW := 0.6
## Hesitations, re-grips and hurried cycles: how many a second at most, and how long each lasts (s, least and most).
const BREAKS := 0.06
const HESITATE := Vector2(0.25, 0.6)
const REGRIP := Vector2(0.28, 0.45)
const REGRIP_SHIFT := 0.005
## Tremor: its band (Hz), its size at rest (m: about 30 micrometers rms, Stiles 1976), and how much more while moving (times).
const TREMOR_HZ := [8.3, 9.7, 11.2, 12.1]
const TREMOR := 0.00005
const TREMOR_MOVING := 3.0
## A quick reach ends this share of its way off and is corrected over this share of its time.
const MISS := 0.04
const CORRECT := 0.16


## Minimum-jerk position from 0 to 1 over [param s] in 0..1 (10s^3 - 15s^4 + 6s^5): still at both ends.
static func min_jerk(s: float) -> float:
	var x := clampf(s, 0.0, 1.0)
	return x * x * x * (10.0 + x * (-15.0 + 6.0 * x))


## A smooth window over [param s] in 0..1: 0 at both ends, 1 in the middle.
static func bump(s: float) -> float:
	if s <= 0.0 or s >= 1.0:
		return 0.0
	var k := sin(PI * s)
	return k * k


## A slow wave, -1 to 1: three sines with periods between [param slowest] and [param quickest] seconds that never line up,
## their phases from [param seed].
static func wave(seed: int, t: float, slowest := 6.0, quickest := 1.5) -> float:
	var out := 0.0
	for i in 3:
		var h := hash([seed, i])
		var period := lerpf(quickest, slowest, float(h % 1000) / 999.0)
		var ph := float((h / 1000) % 1000) / 1000.0 * TAU
		out += sin(TAU * t / period * (1.0 + 0.137 * i) + ph)
	return out / 3.0


## A hand's tremor at [param t]: four sines in the 8-12 Hz band, their phases from [param seed], [param size] meters.
static func tremor(seed: int, t: float, size := TREMOR) -> Vector3:
	var v := Vector3.ZERO
	for i in TREMOR_HZ.size():
		var h := hash([seed, 77, i])
		var hz: float = TREMOR_HZ[i] * (1.0 + 0.04 * (float(h % 100) / 50.0 - 1.0))
		var ph := float(h % 997) / 997.0 * TAU
		v += Vector3(sin(TAU * hz * t + ph), sin(TAU * hz * 1.07 * t + ph * 1.3), sin(TAU * hz * 0.93 * t + ph * 0.7))
	return v * (size * 0.5)


## A held thing at rest at [param t]: drifting on slow waves (about [param size] meters), a breath's rise and fall, a tremor.
static func idle(seed: int, t: float, size := 0.003) -> Vector3:
	var drift := Vector3(wave(seed, t, 8.0, 2.5), wave(seed + 1, t, 9.0, 3.0) * 0.7, wave(seed + 2, t, 7.0, 2.2)) * size
	var breath := Vector3(0.0, sin(TAU * t * (0.22 + 0.04 * float(hash(seed) % 100) / 100.0)) * size * 0.35, 0.0)
	return drift + breath + tremor(seed, t)


# --- reading a plan ----------------------------------------------------------------------------------------------------

## Table [param tab] at [param t] seconds, between its samples (held at its ends).
static func at(tab: PackedFloat32Array, t: float) -> float:
	if tab.is_empty():
		return 0.0
	var x := clampf(t * RATE, 0.0, float(tab.size() - 1))
	var i := int(x)
	if i >= tab.size() - 1:
		return tab[tab.size() - 1]
	return lerpf(tab[i], tab[i + 1], x - float(i))


## A table of points at [param t] seconds.
static func at3(tab: PackedVector3Array, t: float) -> Vector3:
	if tab.is_empty():
		return Vector3.ZERO
	var x := clampf(t * RATE, 0.0, float(tab.size() - 1))
	var i := int(x)
	if i >= tab.size() - 1:
		return tab[tab.size() - 1]
	return tab[i].lerp(tab[i + 1], x - float(i))


## The speed along a path given as tables [param u] and [param w] (m/s a sample each): how fast a contact slides.
static func speeds(u: PackedFloat32Array, w: PackedFloat32Array) -> PackedFloat32Array:
	var n := u.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var a := maxi(i - 1, 0)
		var b := mini(i + 1, n - 1)
		var dt := float(b - a) / RATE
		out[i] = Vector2(u[b] - u[a], w[b] - w[a]).length() / dt if dt > 0.0 else 0.0
	return out


## The speed along a path of points (m/s a sample each).
static func speeds3(p: PackedVector3Array) -> PackedFloat32Array:
	var n := p.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var a := maxi(i - 1, 0)
		var b := mini(i + 1, n - 1)
		var dt := float(b - a) / RATE
		out[i] = (p[b] - p[a]).length() / dt if dt > 0.0 else 0.0
	return out


# --- a reach -----------------------------------------------------------------------------------------------------------

## A reach from [param from] to [param to] over [param secs]: minimum-jerk along a path bowed by [param bow] at its middle,
## a quick one ([param quick]) ending [constant MISS] of its way off and corrected over the last [constant CORRECT] of its
## time. A table of points.
static func reach(seed: int, from: Vector3, to: Vector3, secs: float, bow := Vector3.ZERO, quick := false) -> PackedVector3Array:
	var n := maxi(int(secs * RATE) + 1, 2)
	var out := PackedVector3Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "reach"])
	var miss := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() \
		* (to - from).length() * MISS if quick else Vector3.ZERO
	var main_end := 1.0 - CORRECT if quick else 1.0
	var land := to + miss
	for i in n:
		var s := float(i) / float(n - 1)
		var p: Vector3
		if s <= main_end:
			var k := min_jerk(s / main_end)
			p = from.lerp(land, k) + bow * sin(PI * k)
		else:
			p = land.lerp(to, min_jerk((s - main_end) / (1.0 - main_end)))
		var moving := sin(PI * clampf(s, 0.0, 1.0))
		out[i] = p + tremor(seed, float(i) / RATE, TREMOR * (1.0 + TREMOR_MOVING * moving))
	return out


# --- strokes -----------------------------------------------------------------------------------------------------------

## A rub's strokes over [param secs]: tables `u` (along the stroke, m), `w` (across it, m), `press` (N) and `on` (0 off the
## surface to 1 on it), each [constant RATE] a second. Settings [param o]: `pace` (cycles a second as it begins) and `pace_to`
## (as it ends: quicker for faster, slower for slower), `reach` (half a stroke, m), `arc` (how far out and back part, m),
## `press` and `press_to` (N), `circles` (an ellipse instead of back and forth), `lead` and `tail` (seconds it takes to
## land and to lift), `breaks` (hesitations and re-grips a second, at most [constant BREAKS]).
static func strokes(seed: int, secs: float, o := {}) -> Dictionary:
	# open (`open`): a rub with no end, made [param secs] long - each block of time draws its own breaks, the pace and pressure
	# ease over `ramp` seconds and it never lifts at the end, so a longer one made later is the same where they overlap
	var open := bool(o.get("open", false))
	var ramp := maxf(float(o.get("ramp", secs)), 0.01)
	var pace := float(o.get("pace", 1.6))
	var pace_to := float(o.get("pace_to", pace))
	var reach_m := float(o.get("reach", 0.022))
	var arc := float(o.get("arc", 0.004))
	var press := float(o.get("press", 1.0))
	var press_to := float(o.get("press_to", press))
	var circles := bool(o.get("circles", false))
	var lead := float(o.get("lead", 0.35))
	var tail := float(o.get("tail", 0.35))
	var breaks := clampf(float(o.get("breaks", 0.035)), 0.0, BREAKS)
	var n := maxi(int(secs * RATE) + 1, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "strokes"])
	# the breaks: hesitations, re-grips and a hurried cycle, each at a seeded moment away from the ends
	var events: Array = []
	if open:
		for blk in int(ceil(secs / BLOCK)):
			var er := RandomNumberGenerator.new()
			er.seed = hash([seed, "strokes", "block", blk])
			if er.randf() >= breaks * BLOCK:
				continue
			var sort_o: String = ["hesitate", "regrip", "hurry"][er.randi() % 3]
			var dur_o := er.randf_range(HESITATE.x, HESITATE.y) if sort_o == "hesitate" else er.randf_range(REGRIP.x, REGRIP.y)
			var shift_o := Vector2(er.randf_range(-1.0, 1.0), er.randf_range(-1.0, 1.0)).normalized() * REGRIP_SHIFT
			events.append({"sort": sort_o, "t": maxf(float(blk) * BLOCK + er.randf_range(0.0, BLOCK - dur_o), lead + 1.0), "dur": dur_o, "shift": shift_o})
	var count := 0 if open else int(floor(breaks * secs + rng.randf()))
	for k in count:
		var sort: String = ["hesitate", "regrip", "hurry"][rng.randi() % 3]
		var dur := rng.randf_range(HESITATE.x, HESITATE.y) if sort == "hesitate" else rng.randf_range(REGRIP.x, REGRIP.y)
		var t_at := rng.randf_range(lead + 1.0, maxf(secs - tail - 1.0 - dur, lead + 1.0))
		var shift := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * REGRIP_SHIFT
		events.append({"sort": sort, "t": t_at, "dur": dur, "shift": shift})
	# each cycle's draws, each from the last: its length, its bow, its lean, an ellipse's shape
	var cycles := int(ceil(maxf(pace, pace_to) * 1.6 * secs)) + 4
	var amp := PackedFloat32Array()
	var bows := PackedFloat32Array()
	var leans := PackedFloat32Array()
	var shapes := PackedFloat32Array()
	var xa := 0.0
	var xb := 0.0
	var xl := 0.0
	for k in cycles:
		xa = CYCLE_AR * xa + CYCLE_SPREAD * rng.randfn()
		xb = CYCLE_AR * xb + 0.25 * rng.randfn()
		xl = CYCLE_AR * xl + 0.03 * rng.randfn()
		amp.append(reach_m * clampf(1.0 + xa, 0.6, 1.4))
		bows.append(arc * clampf(1.0 + xb, 0.3, 1.8))
		leans.append(clampf(LEAN + xl, 0.44, 0.64))
		shapes.append(clampf(0.78 + 0.08 * rng.randfn(), 0.55, 0.95))
	var u := PackedFloat32Array()
	var w := PackedFloat32Array()
	var pr := PackedFloat32Array()
	var on := PackedFloat32Array()
	u.resize(n)
	w.resize(n)
	pr.resize(n)
	on.resize(n)
	var ph := 0.0
	var shift := Vector2.ZERO
	for i in n:
		var t := float(i) / RATE
		var s := t / ramp
		# the pace: eased from where it begins to where it ends, drifting; getting going over its first cycle
		var f := lerpf(pace, pace_to, smoothstep(0.0, 1.0, s)) * (1.0 + PACE_DRIFT * 2.0 * wave(seed + 11, t, 4.7, 1.3))
		f *= lerpf(0.35, 1.0, clampf(t / (lead + 1.0 / maxf(pace, 0.1)), 0.0, 1.0))
		var lift := 1.0
		var off := Vector2.ZERO
		for e in events:
			var k := (t - float(e["t"])) / float(e["dur"])
			match String(e["sort"]):
				"hesitate":
					f *= 1.0 - 0.94 * bump(k)
				"hurry":
					f *= 1.0 + 0.45 * bump(k)
				"regrip":
					f *= 1.0 - 0.6 * bump(k)
					lift = minf(lift, 1.0 - bump(k))
					off += (e["shift"] as Vector2) * smoothstep(0.0, 1.0, k)
		ph += f / RATE
		var c := clampi(int(ph), 0, cycles - 2)
		var p := ph - float(c)
		var mix := smoothstep(0.0, 1.0, p)
		var a := lerpf(amp[c], amp[c + 1], mix)
		var b := lerpf(bows[c], bows[c + 1], mix)
		var su: float
		var sw: float
		var share: float           # how fast it goes, 0 still to 1 its quickest: what it presses hardest at
		if circles:
			var th := TAU * p
			var e := lerpf(shapes[c], shapes[c + 1], mix)
			var tilt := 0.4 * wave(seed + 17, t, 9.0, 4.0)
			var cu := cos(th) * a
			var cw := sin(th) * a * e
			su = cu * cos(tilt) - cw * sin(tilt)
			sw = cu * sin(tilt) + cw * cos(tilt)
			share = absf(sin(th))
		else:
			var r := lerpf(leans[c], leans[c + 1], mix)
			var th := PI * p / r if p < r else PI + PI * (p - r) / (1.0 - r)
			su = -cos(th) * a
			sw = sin(th) * b * (1.0 if th < PI else BACK_BOW)
			share = maxf(sin(th), 0.0) - 0.25 * maxf(-sin(th), 0.0)
		var land := min_jerk(t / maxf(lead, 0.01)) * (1.0 if open else min_jerk((secs - t) / maxf(tail, 0.01))) * lift
		var center := Vector2(wave(seed + 3, t, 7.0, 2.0), wave(seed + 4, t, 6.0, 2.4)) * WANDER + off
		var moving := absf(f * a) / 0.04
		var tr := tremor(seed, t, TREMOR * (1.0 + TREMOR_MOVING * clampf(moving, 0.0, 1.0)))
		u[i] = su + center.x + tr.x
		w[i] = sw + center.y + tr.y
		var base := lerpf(press, press_to, smoothstep(0.0, 1.0, s))
		pr[i] = base * (0.9 + 0.22 * share) * (1.0 + 0.03 * wave(seed + 5, t, 1.2, 0.3)) * land
		on[i] = land
	return {"u": u, "w": w, "press": pr, "on": on, "secs": secs}


# --- taps --------------------------------------------------------------------------------------------------------------

## Taps over [param secs], in rolls: tables `lift` (how far off the surface, m), `u` and `w` (where on it, m), and `hits` -
## each `{t, speed}`, the moment it lands and how fast. Settings [param o]: `rate` (taps a second in a roll), `group` (the
## most in a roll, at least 2), `gap` (seconds between rolls), `speed` (m/s at landing), `hover` (m off the surface between
## rolls), `lead` (seconds before the first).
static func taps(seed: int, secs: float, o := {}) -> Dictionary:
	var rate := float(o.get("rate", 6.5))
	var most := maxi(int(o.get("group", 4)), 2)
	var gap := float(o.get("gap", 0.5))
	var speed := float(o.get("speed", 0.35))
	var hover := float(o.get("hover", 0.018))
	var lead := float(o.get("lead", 0.35))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "taps"])
	var hits: Array = []
	var spots: Array = []
	var t := lead
	var spot := Vector2.ZERO
	while t < secs - 0.3:
		var g := rng.randi_range(2, most)
		for j in g:
			if t >= secs - 0.3:
				break
			var v := speed * (1.15 if j == 0 else rng.randf_range(0.78, 0.98)) * (1.0 + 0.08 * rng.randfn())
			hits.append({"t": t, "speed": clampf(v, 0.05, 2.0)})
			spot = spot * 0.5 + Vector2(rng.randfn(), rng.randfn()) * 0.0015
			spots.append(spot)
			t += (1.0 / rate) * (1.0 + 0.06 * rng.randfn())
		t += gap * (1.0 + 0.3 * rng.randfn()) - 1.0 / rate * 0.5
	# each hit's way down: how long it falls and from how high, so it lands at the speed drawn; between rolls it falls from
	# the hover, and lands as fast as that fall makes it - the hit's speed is the motion's
	var downs := PackedFloat32Array()
	var tops := PackedFloat32Array()
	for k in hits.size():
		var t0 := float((hits[k - 1] as Dictionary)["t"]) if k > 0 else 0.0
		var span := float((hits[k] as Dictionary)["t"]) - t0
		var down := minf(span * 0.45, 0.13)
		var top := clampf(float((hits[k] as Dictionary)["speed"]) * down / 2.0, 0.003, 0.025)
		if span > 0.4 or k == 0:
			top = maxf(top, hover)
		downs.append(down)
		tops.append(top)
		(hits[k] as Dictionary)["speed"] = 2.0 * top / down
	var n := maxi(int(secs * RATE) + 1, 2)
	var lift := PackedFloat32Array()
	var u := PackedFloat32Array()
	var w := PackedFloat32Array()
	lift.resize(n)
	u.resize(n)
	w.resize(n)
	var k := 0
	var contact := 0.012
	for i in n:
		var tt := float(i) / RATE
		while k < hits.size() and float((hits[k] as Dictionary)["t"]) <= tt:
			k += 1
		# between the hit before (k - 1) and the next (k): up after a contact, then struck down accelerating to its speed
		var t0 := float((hits[k - 1] as Dictionary)["t"]) if k > 0 else 0.0
		var h: float
		if k >= hits.size():
			# after the last: back up to the hover
			h = hover * min_jerk((tt - t0 - contact) / 0.25) if tt > t0 + contact else 0.0
		else:
			var t1 := float((hits[k] as Dictionary)["t"])
			var down := downs[k]
			var top := tops[k]
			if k == 0 and tt < t1 - down:
				h = top
			elif k > 0 and tt < t0 + contact:
				h = 0.0
			elif tt < t1 - down:
				h = top * min_jerk((tt - t0 - contact) / maxf(t1 - down - t0 - contact, 0.01))
			else:
				var s := (tt - (t1 - down)) / down
				h = top * (1.0 - s * s)
		lift[i] = maxf(h + tremor(seed, tt, TREMOR).y * 0.5, 0.0)
		var a: Vector2 = spots[k - 1] if k > 0 else Vector2.ZERO
		var b: Vector2 = spots[k] if k < spots.size() else a
		var t1v := float((hits[k] as Dictionary)["t"]) if k < hits.size() else secs
		var m := smoothstep(t0, t1v, tt) if k > 0 else 1.0
		var at_v := a.lerp(b, m) + Vector2(wave(seed + 8, tt, 5.0, 1.5), wave(seed + 9, tt, 5.5, 1.8)) * 0.002
		u[i] = at_v.x
		w[i] = at_v.y
	return {"lift": lift, "u": u, "w": w, "hits": hits, "secs": secs}
