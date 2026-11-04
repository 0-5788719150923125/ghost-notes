extends RefCounted
class_name Fingers

## Fingers - WHAT A HAND DOES WITH WHAT IT HOLDS, for as long as it holds it (the user, 2026-11-03, of a brick pulled from the tub and held up: "A real
## hand is not perfectly still: the brick would maybe float a little, the rotation would change, maybe the person would flip the brick in their
## fingers, fidgeting with it. But to have the brick just sit there, center-screen, at an angle, unmoving - it looks very strange").
##
## LAID OVER THE RECORD, NOT IN IT: a stop lasts as long as the reading wants ([method Assembly.lay]), so the record ([AssemblyTrack]) cannot hold
## motion for a time it does not know the length of, and whatever it held would run out into a brick standing still. So this is a pure function of how
## long the piece has been in hand: a scrub lands on the same pose, an export draws what the show drew, and it touches nothing in the world - it is
## given only as much ROOM as the hand has there ([method AssemblyBake._room]), so it never comes to touch anything either, and it has no sound.
##
## THREE THINGS, one over another, each as much as the room allows:
##   - THE ARM SWAYS ([method Hands.drift]), never stopping;
##   - THE HAND SHIFTS ([method _shift]) in short moves with rests between them, each to somewhere of its own: a hand corrects itself in submovements
##     (Milner, 1992), and the same amount of motion as smooth waves reads as something floating under water;
##   - THE FINGERS TURN IT OVER ([method turned]) in beats ([constant BEATS]), each from where the last left it, with no room to do so unless it is
##     clear of everything: their clock runs only then ([param free]), so a turned brick is righted, as room runs out, along one path and with no jump.

## WHAT FINGERS DO TO A THING THEY HOLD, how often (`share`), about which of its axes, how far either way and how long it takes: each from where the last left it.
const BEATS := {
	"tilt": {"label": "Tilt", "blurb": "tipped a little, to see it from another side", "share": 0.34, "about": "any", "degrees": Vector2(18.0, 42.0), "takes": Vector2(0.4, 0.8)},
	"roll": {"label": "Roll", "blurb": "rolled along its length between a thumb and a finger", "share": 0.26, "about": "long", "degrees": Vector2(70.0, 125.0), "takes": Vector2(0.38, 0.75)},
	"flip": {"label": "Flip", "blurb": "turned right over along its length, in two goes with a regrip between them: fingers do not roll anything half a turn at once", "share": 0.2, "about": "long", "degrees": Vector2(165.0, 195.0), "takes": Vector2(0.75, 1.25), "regrip": true},
	"end": {"label": "End over end", "blurb": "turned end over end", "share": 0.1, "about": "short", "degrees": Vector2(110.0, 185.0), "takes": Vector2(0.55, 0.95)},
	"spin": {"label": "Spin", "blurb": "spun flat under a finger, a quarter turn or so", "share": 0.1, "about": "up", "degrees": Vector2(55.0, 120.0), "takes": Vector2(0.35, 0.7)},
}
## How long before fingers begin on a thing, and between beats (seconds): most of the time a hand's worth of waiting, and one time in four straight on into another.
const FIRST_BEAT := Vector2(0.25, 0.9)
const BETWEEN_BEATS := Vector2(0.5, 3.2)
const FLURRY := 0.25
const FLURRY_GAP := Vector2(0.1, 0.35)
## How far through a flip the regrip begins and ends: half of it done by the first, the fingers still between.
const REGRIP := Vector2(0.42, 0.58)
## The most beats a look at a hold walks through: over ten minutes of fidgeting, and it costs a frame nothing to get there.
const BEATS_MOST := 240

## ROOM: how far from anything it could touch a thing in hand is, as a share of all it does: free in the air (1), carried over things, waiting a little over where it
## goes, sitting on the studs being tried. Pressed home (0) it does not move.
const ROOM_FREE := 1.0
const ROOM_CARRY := 0.35
const ROOM_DRAWN := 0.2
const ROOM_HOVER := 0.15
const ROOM_TRIED := 0.04
## Fingers begin to have room for a turn from here: under it, a turned thing has been righted.
const TURN_FROM := 0.2
## Under this much room what shifts goes up and never down, and what tilts is lifted by as much as its low end would dip: it has something under it.
const OVER_THINGS := Vector2(0.35, 0.9)

## A SHIFT at full room: how far it may go each way (meters), and how far it may turn (radians).
const SHIFT_MOVE := Vector3(0.024, 0.016, 0.024)
const SHIFT_TURN := 0.3
## How often one begins (seconds, a hold's own), how long it may wait into that time as a share of it, and how long it takes.
const SHIFT_EVERY := Vector2(1.1, 1.9)
const SHIFT_WAITS := 0.45
const SHIFT_TAKES := Vector2(0.35, 0.8)
## Each one's size, as a share of the most: some barely anything, so it does not read as a beat.
const SHIFT_SIZE := Vector2(0.25, 1.0)
## How long after a grip what it does comes on, and how long before it lets go what it does has gone (seconds): the record's pose at both.
const GRIP_IN := 0.3
const GRIP_OUT := 0.22

## A HAND KEPT WAITING OVER THINGS DRAWS BACK: a stop over a place this long (seconds) and it rises by as much as this (meters), takes a look and comes down again. It is
## all the way back, with room for fingers, from [constant BACK_WHOLE]. What is on the studs, or under [constant BACK_FROM] of room, never does it.
const BACK_AFTER := 2.2
const BACK_WHOLE := 3.24
const BACK_RISE := 0.055
const BACK_LEAST := 0.35
const BACK_DELAY := 0.25
const BACK_UP := 0.6
const BACK_DOWN := 0.7
const BACK_EARLY := 0.15
const BACK_FROM := 0.1


## PIECE [param piece], whose record has it at [param x], as the hand has it: [param held] is what [method Assembly.held_at] says of this moment. It turns about its own
## middle, for a hand holds a thing by the sides and not by what it stands on.
static func on(x: Transform3D, held: Dictionary, piece: Dictionary) -> Transform3D:
	var w := int(piece["w"])
	var d := int(piece["d"])
	var up := Vector3(0.0, float((Assembly.KINDS[String(piece["kind"])] as Dictionary)["h"]) * Assembly.PLATE * 0.5, 0.0)
	var off := at(float(held["h"]), float(held["left"]), float(held["room"]), float(held["free"]), float(held["back"]), int(held["seed"]),
		Vector3.RIGHT if w >= d else Vector3.BACK, float(maxi(w, d)) * Assembly.STUD * 0.5)
	var b := x.basis * Basis(off[1] as Quaternion)
	return Transform3D(b, x * up + (off[0] as Vector3) - b * up)


## WHAT THE HAND HAS DONE TO IT: `[move (meters, the world's), turn (of its own axes)]`, [param h] seconds after the grip with [param left] to go, with [param room] now, the fingers
## having had [param free] seconds of room in all, drawn back by [param back] of [constant BACK_RISE], [param seed] the hold's. [param long] its long axis and [param half]
## how far it reaches along that, for how far a tilt dips.
static func at(h: float, left: float, room: float, free: float, back: float, seed: int, long: Vector3, half: float) -> Array:
	var fade := Hands.smooth(h / GRIP_IN) * Hands.smooth(left / GRIP_OUT)
	if fade <= 0.0 or room <= 0.0:
		return [Vector3.ZERO, Quaternion.IDENTITY]
	var s := _shift(h, seed)
	var mv: Vector3 = (s[0] as Vector3) * SHIFT_MOVE * room * fade
	var rv: Vector3 = (s[1] as Vector3) * SHIFT_TURN * room * fade
	var over := 1.0 - smoothstep(OVER_THINGS.x, OVER_THINGS.y, room)
	var angle := rv.length()
	mv.y = lerpf(mv.y, absf(mv.y), over) + over * half * sin(minf(angle, PI * 0.5))
	var sway: Array = Hands.drift(h, seed, Hands.HOLD_SWAY * sqrt(room) * fade)
	var q := Quaternion(rv.normalized(), angle) if angle > 1e-5 else Quaternion.IDENTITY
	q = q * (sway[1] as Basis).get_rotation_quaternion()
	var fingers := Quaternion.IDENTITY.slerp(turned(free, seed, long), smoothstep(TURN_FROM, 1.0, room))
	return [mv + (sway[0] as Vector3) + Vector3.UP * BACK_RISE * back, (q * fingers).normalized()]


## THE SHIFT AT [param h]: where the hand has gone from its way, `[move, turn]` each -1..1 of the most. Goes straight to the moment asked, whatever the hold's length.
static func _shift(h: float, seed: int) -> Array:
	var every := lerpf(SHIFT_EVERY.x, SHIFT_EVERY.y, Hands.share(seed, 300))
	var n := floori(h / every)
	var sn := hash([seed, n, "shift"])
	var waits := every * SHIFT_WAITS * Hands.share(sn, 1)
	var takes := minf(lerpf(SHIFT_TAKES.x, SHIFT_TAKES.y, Hands.share(sn, 2)), every - waits)
	var v := Hands.timing((h - float(n) * every - waits) / maxf(takes, 1e-4))
	var a := _shift_to(seed, n - 1)
	var b := _shift_to(seed, n)
	return [(a[0] as Vector3).lerp(b[0] as Vector3, v), (a[1] as Vector3).lerp(b[1] as Vector3, v)]


## Where shift [param n] goes: a hand begins from where its grip is.
static func _shift_to(seed: int, n: int) -> Array:
	if n < 0:
		return [Vector3.ZERO, Vector3.ZERO]
	var s := hash([seed, n, "shift"])
	var size := lerpf(SHIFT_SIZE.x, SHIFT_SIZE.y, Hands.share(s, 3))
	return [Vector3(Hands.share(s, 4) - 0.5, Hands.share(s, 5) - 0.5, Hands.share(s, 6) - 0.5) * 2.0 * size,
		Vector3(Hands.share(s, 7) - 0.5, Hands.share(s, 8) - 0.5, Hands.share(s, 9) - 0.5) * 2.0 * size]


## HOW THE FINGERS HAVE TURNED IT after [param free] seconds of room: each beat from where the last left it, of its own axes.
static func turned(free: float, seed: int, long: Vector3) -> Quaternion:
	var q := Quaternion.IDENTITY
	var clock := 0.0
	for n in BEATS_MOST:
		var b := _beat(seed, n, long)
		var begins := clock + float(b["gap"])
		if free <= begins:
			return q
		var takes := float(b["takes"])
		var axis: Vector3 = b["axis"]
		if free < begins + takes:
			var u := (free - begins) / takes
			return (q * Quaternion(axis, float(b["angle"]) * (_regripped(u) if bool(b["regrip"]) else Hands.timing(u)))).normalized()
		q = (q * Quaternion(axis, float(b["angle"]))).normalized()
		clock = begins + takes
	return q


## How much of a flip is done at [param u] of it: half, a moment with nothing moving, and the rest.
static func _regripped(u: float) -> float:
	if u < REGRIP.x:
		return 0.5 * Hands.timing(u / REGRIP.x)
	if u < REGRIP.y:
		return 0.5
	return 0.5 + 0.5 * Hands.timing((u - REGRIP.y) / (1.0 - REGRIP.y))


## Beat [param n] of a hold: `{axis, angle, takes, gap, regrip}`.
static func _beat(seed: int, n: int, long: Vector3) -> Dictionary:
	var s := hash([seed, n, "beat"])
	var pick := Hands.share(s, 1)
	var row: Dictionary = {}
	for key in BEATS:
		row = BEATS[key]
		pick -= float(row["share"])
		if pick <= 0.0:
			break
	var axis := Vector3(Hands.share(s, 2) - 0.5, Hands.share(s, 3) - 0.5, Hands.share(s, 4) - 0.5).normalized()
	match String(row["about"]):
		"long":
			axis = long
		"short":
			axis = Vector3.BACK if long == Vector3.RIGHT else Vector3.RIGHT
		"up":
			axis = Vector3.UP
	var degrees: Vector2 = row["degrees"]
	var takes: Vector2 = row["takes"]
	var gap := lerpf(FIRST_BEAT.x, FIRST_BEAT.y, Hands.share(s, 5))
	if n > 0:
		var into := Hands.share(s, 6)
		gap = lerpf(FLURRY_GAP.x, FLURRY_GAP.y, into / FLURRY) if into < FLURRY else lerpf(BETWEEN_BEATS.x, BETWEEN_BEATS.y, pow((into - FLURRY) / (1.0 - FLURRY), 1.5))
	return {"axis": axis, "angle": deg_to_rad(lerpf(degrees.x, degrees.y, Hands.share(s, 7))) * (-1.0 if Hands.share(s, 8) < 0.5 else 1.0),
		"takes": lerpf(takes.x, takes.y, Hands.share(s, 9)), "gap": gap, "regrip": bool(row.get("regrip", false))}


## HOW FAR A HAND KEPT WAITING HAS DRAWN BACK, [param s] seconds into a stop of [param d].
static func drawn_back(s: float, d: float) -> float:
	if d < BACK_AFTER:
		return 0.0
	var most := lerpf(BACK_LEAST, 1.0, clampf((d - BACK_AFTER) / (BACK_WHOLE - BACK_AFTER), 0.0, 1.0))
	return most * Hands.smooth((s - BACK_DELAY) / BACK_UP) * Hands.smooth((d - s - BACK_EARLY) / BACK_DOWN)


## HOW LONG OF THE FIRST [param s] SECONDS of a stop of [param d] a hand drawn back has been all the way back, with room for its fingers.
static func free_in(s: float, d: float) -> float:
	if d < BACK_WHOLE:
		return 0.0
	var from := BACK_DELAY + BACK_UP
	var to := d - BACK_EARLY - BACK_DOWN
	return clampf(s, from, maxf(to, from)) - from
