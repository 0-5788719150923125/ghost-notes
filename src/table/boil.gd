extends RefCounted
class_name Boil

## Boil - a liquid's bubbles, one stream seen and heard (next/table_physics.md, "Primitives"): how hard a liquid boils (its `boil`,
## [constant Motions.STATES], 0 still to 2 a rolling boil) is a seeded stream of bubbles breaking at its surface, each with its moment,
## its place and its size - a pure function of the liquid, the time and how hard it boils then, so the table draws each where it breaks
## ([method TablePhysics._draw_liquids]), the bake lets the big ones dent the surface ([SurfaceWaves]), and [WorkSounds] hears each one as
## it breaks: the same bubbles, never a sound with nothing seen.
##
## A bubble rings at about 3.26 / its radius (Hz, radius in meters; Minnaert, 1933; Leighton, "The Acoustic Bubble", 1994): a millimeter's
## at 3.3 kHz, a centimeter's at 330 Hz. A pot coming up to a simmer sends many small, faint, quick bubbles up from its floor, and a rolling
## boil many big ones. So the stream grows faster than the boil (its rate a power of it, [constant RATE] at a rolling boil over a pot
## [constant ACROSS] wide), its bubbles grow with it ([method radii]), and each is as loud as it is big: a simmer is a quiet fizz of ticks,
## a rolling boil a busy bubbling.

## Bubbles a second breaking over a surface across wide (meters) at a rolling boil (`boil` 2), and the power of the boil they
## come at (0.2, a simmer: about a tenth of a rolling boil's share, eighteen a second).
const RATE := 220.0
const ACROSS := 0.16
const POWER := 1.15
## A bubble's radius (meters): the least, at any boil; the most a simmer's; the most a rolling boil's.
const R_LEAST := 0.0005
const R_SIMMER := 0.0011
const R_ROLLING := 0.006
## How long a slot of the stream is (seconds): each one's bubbles drawn from its own seed, by how hard it boils as it begins.
const SLOT := 1.0 / 30.0
## How long a bubble is seen at the surface before it breaks, for its radius (seconds: this a meter of radius, and the least).
const SEEN := 40.0
const SEEN_LEAST := 0.06
## Minnaert's: a bubble's ring, Hz for a radius of a meter.
const MINNAERT := 3.26


## How hard a liquid boils, as a share of a rolling boil (0 to 1).
static func share(boil: float) -> float:
	return clampf(boil / 2.0, 0.0, 1.0)


## The radii a boil of [param boil] breaks (meters): `Vector2(least, most)`.
static func radii(boil: float) -> Vector2:
	var s := share(boil)
	return Vector2(R_LEAST, lerpf(R_SIMMER, R_ROLLING, pow(s, 1.5)))


## Bubbles a second over a surface [param across] meters wide boiling [param boil].
static func rate(boil: float, across: float) -> float:
	var s := share(boil)
	if s <= 0.0:
		return 0.0
	return RATE * pow(s, POWER) * pow(clampf(across / ACROSS, 0.25, 4.0), 2.0)


## How long a bubble of radius [param r] shows at the surface before it breaks (seconds).
static func seen(r: float) -> float:
	return maxf(SEEN * r, SEEN_LEAST)


## The pitch a bubble of radius [param r] rings at (Hz).
static func pitch(r: float) -> float:
	return MINNAERT / maxf(r, 1e-5)


## The bubbles of the liquid keyed [param key] that break from [param t0] to [param t1] (show seconds): `[{t, at (Vector2, on
## its surface from its middle, a share of its radius), r (meters)}]`, in time order - how hard it boils at a slot's start read
## from [param boil_at] (a Callable of show time), its surface [param across] meters wide. The same for every asker.
static func bubbles(key: int, t0: float, t1: float, boil_at: Callable, across: float) -> Array:
	var out: Array = []
	if t1 <= t0:
		return out
	var k0 := int(floor(t0 / SLOT))
	var k1 := int(floor(t1 / SLOT))
	for k in range(k0, k1 + 1):
		var start := float(k) * SLOT
		var b := float(boil_at.call(start))
		var lam := rate(b, across) * SLOT
		if lam <= 0.0:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([key, k, "boil"])
		# ...how many: Poisson's, by its inverse - few enough a slot to count up to
		var n := 0
		var p := exp(-lam)
		var c := p
		var u := rng.randf()
		while u > c and n < 64:
			n += 1
			p *= lam / float(n)
			c += p
		var rr := radii(b)
		for i in n:
			var t := start + rng.randf() * SLOT
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * 0.92
			var r := rr.x * pow(rr.y / rr.x, pow(rng.randf(), 1.6))
			if t >= t0 and t < t1:
				out.append({"t": t, "at": Vector2(cos(a), sin(a)) * d, "r": r})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t"]) < float(y["t"]))
	return out


## The bubbles of liquid [param key] showing at [param t]: those breaking within the time the biggest is seen, each with how far
## from rising to breaking it is (`phase`, 0 to 1) - at most [param most], the biggest first.
static func showing(key: int, t: float, boil_at: Callable, across: float, most: int) -> Array:
	var out: Array = []
	for bb in bubbles(key, t, t + seen(R_ROLLING), boil_at, across):
		var bd: Dictionary = bb
		var life := seen(float(bd["r"]))
		var phase := 1.0 - (float(bd["t"]) - t) / life
		if phase >= 0.0 and phase <= 1.0:
			bd["phase"] = phase
			out.append(bd)
	# ...and those just broken, their ring running out
	for bb in bubbles(key, t - 0.25, t, boil_at, across):
		var bd: Dictionary = bb
		bd["phase"] = 1.0 + (t - float(bd["t"])) / 0.25
		out.append(bd)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["r"]) > float(y["r"]))
	return out.slice(0, most)
