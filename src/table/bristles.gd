extends RefCounted
class_name Bristles

## Bristles - A BRUSH'S HAIRS (next/painted_surface.md): a `tuft` shape of [Props], and how its hairs move. The user,
## 2026-11-05: "we might need some new primitives for stuff like: brushes, with hair dynamics".
##
## A TUFT IS HAIRS, NOT A CONE: a few dozen thin tapered hairs from a root at y = 0 up to their tips, gathered as its kind
## gathers them (to a point, a chisel edge, a fan, a dome), round a softer core that keeps it reading as one body from the
## table's distance. Every vertex carries how far up its hair it is (UV2's x, 0 at the root and 1 at the tip), which is all the
## shader needs to bend it ([member Props] sets the root, the axis and the length on its material; prop_common.gdshaderinc).
##
## HOW IT MOVES IS A PURE FUNCTION OF TIME: the hairs lean back against the way the brush is dragged and splay as it is pressed
## ([method target]), and follow that as a stiff spring does, a little behind it and past it - a flick as the brush lifts
## ([method response]: the target over the last moment, weighed by a damped spring's own response). No step is ever kept.

## THE KINDS of tuft, each how its hairs gather: `point` how far toward the middle the tips gather (1 all the way), `spread`
## how far out across they fan, `dome` how much shorter the outer hairs are, `bulge` how far out the middle of each hair
## bows, `flat` how thin it is across its width when no `thick` is written, and its hairs.
const KINDS := {
	"round": {"label": "Round", "blurb": "gathered to a soft point - a round brush, for dots, details and filling small shapes",
		"point": 0.8, "spread": 1.0, "dome": 0.12, "bulge": 0.12, "flat": 1.0, "hairs": 46},
	"liner": {"label": "Liner", "blurb": "long, thin and pointed - a liner or a script brush, for long fine lines in one stroke",
		"point": 0.9, "spread": 1.0, "dome": 0.08, "bulge": 0.05, "flat": 1.0, "hairs": 22},
	"flat": {"label": "Flat", "blurb": "a flat chisel edge, wide one way and thin the other - a flat or a shader brush, for laying color in broad strokes",
		"point": 0.0, "spread": 1.0, "dome": 0.02, "bulge": 0.04, "flat": 0.3, "hairs": 64},
	"fan": {"label": "Fan", "blurb": "thin hairs spread wide in a fan - for sweeping powder away and laying soft texture",
		"point": 0.0, "spread": 2.6, "dome": 0.18, "bulge": 0.0, "flat": 0.2, "hairs": 48},
	"dome": {"label": "Dome", "blurb": "full and soft, its top rounded - a blending, powder or kabuki brush, for softening edges and dusting",
		"point": -0.25, "spread": 1.0, "dome": 0.38, "bulge": 0.28, "flat": 1.0, "hairs": 90},
}
## The most hairs a tuft has, and how many points round one hair's section and along it.
const MOST_HAIRS := 140
const HAIR_SIDES := 3
const HAIR_STEPS := 5
## How much of the hairs' room the core fills, and its sections up its length.
const CORE := 0.78
const CORE_STEPS := 8
const CORE_SIDES := 12

## THE SPRING the hairs follow ([method response]): how fast they swing back (Hz), how damped (1 never overshoots), and the
## moment it is judged over (seconds, in steps).
const SPRING_HZ := 3.6
const SPRING_DAMPING := 0.38
const SPRING_STEP := 0.025
const SPRING_STEPS := 18
## HOW FAR THEY BEND (shares of the hairs' length): back against a drag at full speed, and how fast that is (meters a
## second); how far they fold aside when pressed with no drag; how far they splay when pressed.
const DRAG_BEND := 0.42
const DRAG_FULL := 0.06
const PRESS_BEND := 0.22
const PRESS_SPLAY := 0.35


## Whatever an agent wrote for a tuft, made safe (sizes centimeters).
static func sanitize(p: Dictionary, out: Dictionary) -> void:
	var kind := String(p.get("kind", "round")).strip_edges().to_lower()
	if not KINDS.has(kind):
		kind = "round"
	var row: Dictionary = KINDS[kind]
	out["kind"] = kind
	out["length"] = Props._num(p.get("length"), 2.2 if kind != "liner" else 2.8, 0.3, 12.0)
	out["width"] = Props._num(p.get("width"), 0.7 if kind != "dome" else 2.2, 0.05, 10.0)
	out["thick"] = Props._num(p.get("thick"), float(out["width"]) * float(row["flat"]), 0.03, 10.0)
	out["hairs"] = int(Props._num(p.get("hairs"), float(row["hairs"]), 6.0, float(MOST_HAIRS)))


## THE TUFT's geometry from its made-safe part [param p]: hairs from y = 0 up, and a core.
static func build(p: Dictionary, rng: RandomNumberGenerator) -> Props.Tris:
	var row: Dictionary = KINDS.get(String(p.get("kind", "round")), KINDS["round"])
	var L := float(p.get("length", 2.2)) * 0.01
	var hw := float(p.get("width", 0.7)) * 0.005
	var hd := float(p.get("thick", 0.7)) * 0.005
	var n := int(p.get("hairs", row["hairs"]))
	var g := Props.Tris.new()
	var hair_r := maxf(minf(hw, hd) * 1.7 / sqrt(float(n)), 0.00006)
	for h in n:
		# a root in the section, spread evenly (a sunflower's spiral), each hair a little its own
		var k := (float(h) + 0.5) / float(n)
		var a := float(h) * 2.39996 + rng.randf() * 0.3
		var rr := sqrt(k)
		var root := Vector3(cos(a) * rr * hw, 0.0, sin(a) * rr * hd)
		var tip := _tip_of(root, rr, hw, hd, L, row, rng)
		var bow := Vector3(root.x, 0.0, root.z).normalized() * float(row["bulge"]) * hw if rr > 0.05 else Vector3.ZERO
		bow += Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * hair_r * 1.5
		_hair(g, root, tip, bow, hair_r, rng.randf())
	_core(g, hw, hd, L, row)
	g.measure()
	return g


## Where a hair rooted at [param root] (a share [param rr] of the way out) ends.
static func _tip_of(root: Vector3, rr: float, hw: float, hd: float, L: float, row: Dictionary, rng: RandomNumberGenerator) -> Vector3:
	var gather := 1.0 - float(row["point"])
	var spread := float(row["spread"])
	var tip := Vector3(root.x * gather * spread, 0.0, root.z * gather)
	var len := L * (1.0 - float(row["dome"]) * rr * rr) * (1.0 - rng.randf() * 0.04)
	tip.y = len
	return tip


## ONE HAIR from [param root] to [param tip], bowed out by [param bow] at its middle: a tapered tube of [constant HAIR_SIDES]
## sides. UV's x is the hair's own number, UV2's x how far up it is.
static func _hair(g: Props.Tris, root: Vector3, tip: Vector3, bow: Vector3, r0: float, own: float) -> void:
	var rings: Array = []
	for i in HAIR_STEPS + 1:
		var s := float(i) / float(HAIR_STEPS)
		var c := root.lerp(tip, s) + bow * 4.0 * s * (1.0 - s)
		var nxt := root.lerp(tip, minf(s + 0.05, 1.0)) + bow * 4.0 * minf(s + 0.05, 1.0) * (1.0 - minf(s + 0.05, 1.0))
		var up := (nxt - c).normalized() if (nxt - c).length() > 1e-7 else Vector3.UP
		var side := up.cross(Vector3.FORWARD).normalized() if absf(up.dot(Vector3.FORWARD)) < 0.95 else up.cross(Vector3.RIGHT).normalized()
		var side2 := up.cross(side).normalized()
		var r := r0 * lerpf(1.0, 0.22, s)
		var ring: Array = []
		for k in HAIR_SIDES:
			var a := TAU * float(k) / float(HAIR_SIDES)
			var d := side * cos(a) + side2 * sin(a)
			ring.append([c + d * r, d, s])
		rings.append(ring)
	for i in HAIR_STEPS:
		for k in HAIR_SIDES:
			var a: Array = rings[i][k]
			var b: Array = rings[i][(k + 1) % HAIR_SIDES]
			var c: Array = rings[i + 1][(k + 1) % HAIR_SIDES]
			var d: Array = rings[i + 1][k]
			g.tri(a[0], b[0], c[0], a[1], b[1], c[1], Vector2(own, a[2]), Vector2(own, b[2]), Vector2(own, c[2]),
				Vector2(a[2], 0.0), Vector2(b[2], 0.0), Vector2(c[2], 0.0))
			g.tri(a[0], c[0], d[0], a[1], c[1], d[1], Vector2(own, a[2]), Vector2(own, c[2]), Vector2(own, d[2]),
				Vector2(a[2], 0.0), Vector2(c[2], 0.0), Vector2(d[2], 0.0))


## THE CORE: the hairs' room, a little smaller, as one smooth body - so the tuft reads whole from across the table.
static func _core(g: Props.Tris, hw: float, hd: float, L: float, row: Dictionary) -> void:
	var gather := 1.0 - float(row["point"])
	var spread := float(row["spread"])
	var rings: Array = []
	for i in CORE_STEPS + 1:
		var s := float(i) / float(CORE_STEPS) * 0.93
		var sx := lerpf(1.0, gather * spread, s) + float(row["bulge"]) * 4.0 * s * (1.0 - s)
		var sz := lerpf(1.0, gather, s) + float(row["bulge"]) * 4.0 * s * (1.0 - s)
		var ring: Array = []
		for k in CORE_SIDES:
			var a := TAU * float(k) / float(CORE_SIDES)
			var y := L * s * (1.0 - float(row["dome"]) * 0.5 * s * s)
			var q := Vector3(cos(a) * hw * maxf(sx, 0.05) * CORE, y, sin(a) * hd * maxf(sz, 0.05) * CORE)
			ring.append([q, Vector3(cos(a) / maxf(hw, 1e-5), 0.2, sin(a) / maxf(hd, 1e-5)).normalized(), s])
		rings.append(ring)
	for i in CORE_STEPS:
		for k in CORE_SIDES:
			var a: Array = rings[i][k]
			var b: Array = rings[i][(k + 1) % CORE_SIDES]
			var c: Array = rings[i + 1][(k + 1) % CORE_SIDES]
			var d: Array = rings[i + 1][k]
			g.tri(a[0], b[0], c[0], a[1], b[1], c[1], Vector2(0.5, a[2]), Vector2(0.5, b[2]), Vector2(0.5, c[2]),
				Vector2(a[2], 0.0), Vector2(b[2], 0.0), Vector2(c[2], 0.0))
			g.tri(a[0], c[0], d[0], a[1], c[1], d[1], Vector2(0.5, a[2]), Vector2(0.5, c[2]), Vector2(0.5, d[2]),
				Vector2(a[2], 0.0), Vector2(c[2], 0.0), Vector2(d[2], 0.0))
	# its top closed
	var top: Array = rings[CORE_STEPS]
	var mid := Vector3.ZERO
	for q in top:
		mid += (q as Array)[0]
	mid /= float(top.size())
	for k in CORE_SIDES:
		var a: Array = top[k]
		var b: Array = top[(k + 1) % CORE_SIDES]
		g.tri(a[0], b[0], mid, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(0.5, 0.93), Vector2(0.5, 0.93), Vector2(0.5, 1.0),
			Vector2(0.93, 0.0), Vector2(0.93, 0.0), Vector2(1.0, 0.0))


## WHERE THE HAIRS WANT THEIR TIPS at one moment (meters, the table's space): leaning back against [param velocity] (the
## brush's tip, meters a second, along the surface), and folded aside and splayed as hard as it is [param pressed] (0-1) - a
## brush [param length] meters long whose handle leans along [param lean] (unit, the table's space). Returns [bend, splay].
static func target(velocity: Vector3, pressed: float, length: float, lean: Vector3) -> Array:
	var speed := velocity.length()
	var drag := Vector3.ZERO
	if speed > 1e-5:
		drag = -velocity / speed * DRAG_BEND * length * clampf(speed / DRAG_FULL, 0.0, 1.0) * (0.35 + 0.65 * pressed)
	# pressed with no drag, the hairs fold the way the handle leans, away from the surface
	var fold := lean * PRESS_BEND * length * pressed
	return [drag + fold, PRESS_SPLAY * pressed]


## THE SPRING's weights over the last [constant SPRING_STEPS] steps (newest first), summing to 1: a damped spring's own
## response, so the hairs follow a little behind and swing past when the pull stops.
static func weights() -> PackedFloat32Array:
	var w := PackedFloat32Array()
	var wn := TAU * SPRING_HZ
	var wd := wn * sqrt(1.0 - SPRING_DAMPING * SPRING_DAMPING)
	var sum := 0.0
	for k in SPRING_STEPS:
		var tau := float(k) * SPRING_STEP
		var h := exp(-SPRING_DAMPING * wn * tau) * sin(wd * tau + 0.35)
		w.append(h)
		sum += h
	for k in w.size():
		w[k] /= sum
	return w


## THE HAIRS' BEND at show time [param t]: [param at] (a function of a time, giving [bend, splay] as [method target] does)
## followed as the spring follows it - a pure function of time.
static func response(at: Callable, t: float) -> Array:
	var w := weights()
	var bend := Vector3.ZERO
	var splay := 0.0
	for k in w.size():
		var got: Array = at.call(t - float(k) * SPRING_STEP)
		bend += (got[0] as Vector3) * w[k]
		splay += float(got[1]) * w[k]
	return [bend, maxf(splay, 0.0)]
