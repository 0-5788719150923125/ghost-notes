extends RefCounted
class_name Hands

## Hands - HOW A HAND MOVES A THING (next/table_physics.md, "The hand"). Nobody is in the chair, but what moves
## moves as if held: the user, 2026-10-28, of the first alchemy episode - "the motions are somewhat jerky, and they
## follow straight lines. A real human might move in curves, or in nonlinear patterns, or it might gently jitter ...
## akin to what we do with cards management already". So every move [TableWork] plays is shaped here, from what
## the study of reaching has measured, each with a share of its own drawn from its act's seed - no two alike, every
## one a function of its act's time:
##
##   - MINIMUM JERK in time (Flash and Hogan, 1985), skewed so a thing slows longer into a careful placing than it
##     took to leave (MacKenzie et al., 1987: the deceleration phase lengthens with the precision asked);
##   - A PATH THAT BOWS a little to one side (point-to-point hand paths are gently curved - Morasso, 1981), and a lift
##     that rises early and comes down late: lifted before it travels, lowered after it arrives;
##   - A HELD THING LAGS ITS HAND, tilted as a pendulum from the grip by the hand's acceleration - back as it sets
##     off, forward as it stops (a carried liquid sloshes from the same acceleration);
##   - A HELD THING IS NEVER STILL: a slow drift and a smaller quicker waver while it is off the table, none where it
##     rests - so a move still begins and ends exactly where it was sent;
##   - A ROUND IS NEVER THE SAME TWICE: a stir's or a grind's pace, radius and middle wander a little.
##
## Pure functions of their arguments: [TableWork] and its checker, the physics' bake and a picture all get the same
## move.

## The peak of a move's speed comes early by this much ([method timing]: a warp of time, 0 for the textbook's even
## minimum jerk) - a peak at 44% of the move, the slower half spent placing it.
const SKEW := 0.25
## A path's BOW to one side ([method carried]): a share of the distance, drawn between these, never more than BOW_MOST
## (meters) - and none on a move shorter than BOW_FROM.x, all of it from BOW_FROM.y.
const BOW := Vector2(0.015, 0.045)
const BOW_MOST := 0.012
const BOW_FROM := Vector2(0.02, 0.08)
## A LIFT's shape over the move's time ([method lift_at]): t^a (1 - t)^b, at its highest at a / (a + b) of the way.
const LIFT_SHAPE := Vector2(2.0, 3.0)
## A HELD THING'S LAG ([method lean]): this share of the angle a hanging thing would swing to under the hand's
## acceleration (the grip holds the rest), never more than LEAN_MOST (radians).
const LAG := 0.6
const LEAN_MOST := 0.14
## How far through a move its unsteadiness grows from nothing, and dies back to nothing ([method held]).
const HELD_IN := 0.18
## THE DRIFT of a held thing ([method drift]): each wave's frequency range (hertz), how far it moves the thing (meters)
## and how far it turns it (radians) - a slow drift, a waver over it, and a faint quick one.
const DRIFT := [
	{"hz": Vector2(0.3, 0.55), "move": 0.0008, "turn": 0.008},
	{"hz": Vector2(0.9, 1.5), "move": 0.00035, "turn": 0.004},
	{"hz": Vector2(2.3, 3.4), "move": 0.00012, "turn": 0.0015},
]
## A ROUND'S WANDER ([method round_of]): how far its phase leads and lags (radians), how much its radius breathes (a
## share), and how far its middle wanders (meters), each over a few rounds.
const ROUND_PHASE := 0.2
const ROUND_RADIUS := 0.08
const ROUND_WANDER := 0.0012
const GRAVITY := 9.81


## MINIMUM JERK over 0..1 (Flash and Hogan): 10x^3 - 15x^4 + 6x^5 - at rest at both ends, its acceleration rising and
## falling without a step.
static func smooth(x: float) -> float:
	var u := clampf(x, 0.0, 1.0)
	return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)


## A MOVE'S PROGRESS at [param lin] of its time: minimum jerk through time warped by [param skew] (its speed's peak
## early, the placing slow).
static func timing(lin: float, skew := SKEW) -> float:
	var x := clampf(lin, 0.0, 1.0)
	return smooth(x + skew * x * (1.0 - x))


## A LIFT's height at [param lin] of the move, as a share of the most it rises: zero at both ends and level there,
## highest early.
static func lift_at(lin: float) -> float:
	var x := clampf(lin, 0.0, 1.0)
	var a := LIFT_SHAPE.x
	var b := LIFT_SHAPE.y
	var top := a / (a + b)
	return pow(x, a) * pow(1.0 - x, b) / (pow(top, a) * pow(1.0 - top, b))


## [param seed]'s share in 0..1 for [param salt].
static func share(seed: int, salt: int) -> float:
	return float(hash([seed, salt, "hand"]) & 0xFFFFFF) / float(0x1000000)


## WHERE A CARRIED THING IS at [param lin] of its move from [param a] to [param b] (meters), rising [param lift]
## meters on the way: minimum jerk along the way, or - [param ma], [param mb] not both zero (a move going on through its
## places, [method TableWork._chains]) - the cubic through them with those slopes (meters, per the whole move); bowed
## to the side [param seed] draws; lifted early, lowered late.
static func carried(a: Vector3, b: Vector3, ma: Vector3, mb: Vector3, lift: float, lin: float, seed: int) -> Vector3:
	var x := clampf(lin, 0.0, 1.0)
	var p := a.lerp(b, timing(x)) if ma == Vector3.ZERO and mb == Vector3.ZERO else Motions.hermite(a, b, ma, mb, x)
	return p + bow(a, b, x, seed) + Vector3(0.0, lift * lift_at(x), 0.0)


## THE BOW of a move from [param a] to [param b] at [param lin]: across the way, level, to the side [param seed] draws -
## nothing at either end, its slope nothing there too (a run of moves through its places stays smooth where they meet).
static func bow(a: Vector3, b: Vector3, lin: float, seed: int) -> Vector3:
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var dist := flat.length()
	if dist < BOW_FROM.x:
		return Vector3.ZERO
	var side := Vector3(-flat.z, 0.0, flat.x) / dist
	var amount := minf(lerpf(BOW.x, BOW.y, share(seed, 1)) * dist, BOW_MOST) * smoothstep(BOW_FROM.x, BOW_FROM.y, dist)
	var way := 1.0 if share(seed, 2) < 0.5 else -1.0
	var s := sin(PI * clampf(lin, 0.0, 1.0))
	return side * (amount * way * s * s)


## THE LAG of a thing held while it moves along [param where] (a Callable of 0..1 through the move, giving its place in
## meters) at [param lin], the move taking [param seconds]: the turn its hand's acceleration swings it by - its top
## toward the way the hand speeds it, as a thing hanging from a grip swings back - none at rest.
static func lean(where: Callable, lin: float, seconds: float) -> Basis:
	var dl := 0.01
	var x := clampf(lin, dl, 1.0 - dl)
	var dt := dl * maxf(seconds, 0.05)
	var acc: Vector3 = ((where.call(x + dl) as Vector3) - 2.0 * (where.call(x) as Vector3) + (where.call(x - dl) as Vector3)) / (dt * dt)
	# at its very ends the move is at rest: no lag, so it stands where it was set
	acc *= smoothstep(0.0, 0.06, lin) * smoothstep(0.0, 0.06, 1.0 - lin)
	var flat := Vector3(acc.x, 0.0, acc.z)
	var amount := flat.length()
	if amount < 1e-4:
		return Basis.IDENTITY
	var angle := minf(atan2(amount, GRAVITY + acc.y) * LAG, LEAN_MOST)
	return Basis(Vector3.UP.cross(flat / amount).normalized(), angle)


## HOW HELD a thing is at [param lin] of a stretch it is held over: nothing at its ends, where it rests, wholly between.
static func held(lin: float) -> float:
	return smoothstep(0.0, HELD_IN, lin) * smoothstep(0.0, HELD_IN, 1.0 - lin)


## A HELD THING'S DRIFT at show time [param T] (its waves keep going through one move after another), as much of it as
## [param amount] (0..1, [method held]): `[place (meters), turn]`.
static func drift(T: float, seed: int, amount: float) -> Array:
	if amount <= 0.0:
		return [Vector3.ZERO, Basis.IDENTITY]
	var p := Vector3.ZERO
	var r := Vector3.ZERO
	for i in DRIFT.size():
		var w: Dictionary = DRIFT[i]
		var hz: Vector2 = w["hz"]
		for c in 3:
			var f := lerpf(hz.x, hz.y, share(seed, 10 + i * 6 + c))
			var ph := TAU * share(seed, 40 + i * 6 + c)
			var s := sin(TAU * f * T + ph)
			p[c] += s * float(w["move"]) * (0.5 if c == 1 else 1.0)
			r[c] += sin(TAU * f * 0.83 * T + ph * 1.7) * float(w["turn"])
	return [p * amount, Basis.from_euler(r * amount)]


## The fastest a held thing's drift ever moves it (meters a second): every wave at its quickest, all at once - what a
## thing held still is still to within.
static func drift_most() -> float:
	var most := 0.0
	for w in DRIFT:
		most += TAU * float(((w as Dictionary)["hz"] as Vector2).y) * float((w as Dictionary)["move"]) * sqrt(2.25)
	return most


## A ROUND'S WANDER at [param t] seconds into a law going round every [param period] seconds: `{phase (radians, added to
## where round it is), radius (a factor), middle (meters, added)}` - for a stir or a grind, its two ends taking the same.
static func round_of(t: float, period: float, seed: int) -> Dictionary:
	var p := maxf(period, 0.1)
	var phase := ROUND_PHASE * (0.65 * sin(TAU * t / (p * 2.7) + TAU * share(seed, 70)) + 0.35 * sin(TAU * t / (p * 1.3) + TAU * share(seed, 71)))
	var radius := 1.0 + ROUND_RADIUS * sin(TAU * t / (p * 3.3) + TAU * share(seed, 72))
	var middle := Vector3(sin(TAU * t / 7.1 + TAU * share(seed, 73)), 0.0, sin(TAU * t / 5.3 + TAU * share(seed, 74))) * ROUND_WANDER
	return {"phase": phase, "radius": radius, "middle": middle}
