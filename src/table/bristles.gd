extends RefCounted
class_name Bristles

## Bristles - a brush's hairs (next/painted_surface.md): a `tuft` shape of [Props], and how its hairs move.
##
## A tuft is hairs, not a cone: a few dozen thin tapered hairs from a root at y = 0 up to their tips, gathered as its kind gathers them (to
## a point, a chisel edge, a fan, a dome), round a softer core that keeps it reading as one body from the table's distance. Every vertex
## carries how far up its hair it is (UV2's x, 0 at the root and 1 at the tip), which is all the shader needs to bend it ([member Props]
## sets the root, the axis and the length on its material; prop_common.gdshaderinc).
##
## How it moves is a pure function of time: the hairs trail behind as the brush is dragged on the surface, splay as it is pressed straight
## down and bend over as it is pressed leaning ([method target]), and follow that as a stiff spring does, a moment behind it and hardly
## past it ([method response]: the target over the last moment, weighed by a damped spring's own response). No step is kept. Moved
## through the air they stay straight.

## The kinds of tuft, each how its hairs gather: `point` how far toward the middle the tips gather (1 all the way), `spread` how far out
## across they fan, `dome` how much shorter the outer hairs are, `bulge` how far out the middle of each hair bows, `flat` how thin it is
## across its width when no `thick` is written, and its hairs - and `bends`, the share of a brush's bend and splay its hairs take
## ([method target]): a brush's all of it; a cotton tip's, wound tight on its stick, a little.
## A cotton swab's tip is a tuft too: short, dense and rounded, barely bending - a tool that lays no paint of its own and lifts what is
## fresh ([method TableProducer._table_tool] gives it only the painter's swab).
const KINDS := {
	"round": {"label": "Round", "blurb": "gathered to a soft point - a round brush, for dots, details and filling small shapes",
		"point": 0.8, "spread": 1.0, "dome": 0.12, "bulge": 0.12, "flat": 1.0, "hairs": 46, "bends": 1.0},
	"liner": {"label": "Liner", "blurb": "long, thin and pointed - a liner or a script brush, for long fine lines in one stroke",
		"point": 0.9, "spread": 1.0, "dome": 0.08, "bulge": 0.05, "flat": 1.0, "hairs": 22, "bends": 1.0},
	"flat": {"label": "Flat", "blurb": "a flat chisel edge, wide one way and thin the other - a flat or a shader brush, for laying color in broad strokes",
		"point": 0.0, "spread": 1.0, "dome": 0.02, "bulge": 0.04, "flat": 0.3, "hairs": 64, "bends": 1.0},
	"fan": {"label": "Fan", "blurb": "thin hairs spread wide in a fan - for sweeping powder away and laying soft texture",
		"point": 0.0, "spread": 2.6, "dome": 0.18, "bulge": 0.0, "flat": 0.2, "hairs": 48, "bends": 1.0},
	"dome": {"label": "Dome", "blurb": "full and soft, its top rounded - a blending, powder or kabuki brush, for softening edges and dusting",
		"point": -0.25, "spread": 1.0, "dome": 0.38, "bulge": 0.28, "flat": 1.0, "hairs": 90, "bends": 1.0},
	"bud": {"label": "Bud", "blurb": "a cotton swab's tip - short, dense and rounded, barely bending - for lifting a small or faint spill of fresh paint",
		"point": 0.55, "spread": 1.0, "dome": 0.3, "bulge": 0.6, "flat": 1.0, "hairs": 140, "bends": 0.15},
}
## The most hairs a tuft has, and how many points round one hair's section and along it.
const MOST_HAIRS := 140
const HAIR_SIDES := 3
const HAIR_STEPS := 5
## How much of the hairs' room the core fills, and its sections up its length.
const CORE := 0.78
const CORE_STEPS := 8
const CORE_SIDES := 12
## The core stands for the hairs inside the bundle, and pressed they are pushed back into it as the outer ones splay: as far as they splay
## it draws in by [constant CORE_IN] of that and down by [constant CORE_DOWN], under the hairs (a core splayed like a hair would stand over
## their tips as a lump of paint); it takes this share of the paint they carry ([constant CORE_WET]); and it is told from a hair by its
## UV's x ([constant CORE_MARK], a hair's own number is 0-1). As prop_common.gdshaderinc draws it ([method core_at]).
const CORE_IN := 1.0
const CORE_DOWN := 1.0
const CORE_WET := 0.45
const CORE_MARK := 2.0

## The spring the hairs follow ([method response]): how fast they swing back (Hz), how damped (1 never overshoots), and the moment it is
## judged over (seconds, in steps). Hairs are stiff: a spring that overshoots (3.6 Hz damped 0.38 swung past straight by a quarter of
## the bend) makes a brush floppy at the end of every stroke.
const SPRING_HZ := 9.0
const SPRING_DAMPING := 0.75
const SPRING_STEP := 0.025
const SPRING_STEPS := 18
## How far they bend (shares of the hairs' length): trailing a drag on the surface at full speed, and how fast that is (meters a second) -
## the surface's pull on them, as hard as they are pressed: in the air nothing pulls them; how far they fold aside when pressed with no
## drag; how far they splay when pressed.
const DRAG_BEND := 0.2
const DRAG_FULL := 0.06
const PRESS_BEND := 0.22
const PRESS_SPLAY := 0.35
## ...a handle leaning this far off the surface's normal (the sine) folds them as far as they fold ([method target]).
const LEAN_FULL := 0.3
## A brush pressed straight down splays; leaned, its hairs bend over instead: leaning this far off the normal (the sine, about 30 degrees)
## it splays only this share of what it splays upright - the bend that keeps its tip on the face takes up the rest
## ([method TablePaint._bend_to_surface]).
const SPLAY_LEAN := 0.5
const SPLAY_LEANED := 0.25
## A hair bent aside keeps its length: it is bent as an arc of a circle ([method bent_at]), its tip at most this share of its length
## aside - about as far as an arc can take it (the most is 0.72, half way round and more).
const ASIDE_MOST := 0.7
## A brush pressed down onto a level surface lays its hairs on it, on their side: each hair bows down from its root as an arc of a circle
## until it runs along the surface, and the rest of it lies there straight ([method laid], [method laid_at]) - as prop_common.gdshaderinc
## draws it (`bristle_lay`). Bent only until its tip touches, a brush pushed onto its paint would have only a millimeter of its point on
## it. At most this share of a hair lies on the surface.
const LAID_MOST := 0.6


## How far a tuft of kind [param kind] bends, of a brush's ([constant KINDS]' `bends`).
static func bends_of(kind: String) -> float:
	return float((KINDS.get(kind, KINDS["round"]) as Dictionary)["bends"])


## Whatever an agent wrote for a tuft, made safe (sizes centimeters).
static func sanitize(p: Dictionary, out: Dictionary) -> void:
	var kind := String(p.get("kind", "round")).strip_edges().to_lower()
	if not KINDS.has(kind):
		kind = "round"
	var row: Dictionary = KINDS[kind]
	out["kind"] = kind
	out["length"] = Props._num(p.get("length"), {"liner": 2.8, "bud": 0.9}.get(kind, 2.2), 0.3, 12.0)
	out["width"] = Props._num(p.get("width"), {"dome": 2.2, "bud": 0.35}.get(kind, 0.7), 0.05, 10.0)
	out["thick"] = Props._num(p.get("thick"), float(out["width"]) * float(row["flat"]), 0.03, 10.0)
	out["hairs"] = int(Props._num(p.get("hairs"), float(row["hairs"]), 6.0, float(MOST_HAIRS)))


## The tuft's geometry from its made-safe part [param p]: hairs from y = 0 up, and a core.
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


## One hair from [param root] to [param tip], bowed out by [param bow] at its middle: a tapered tube of [constant HAIR_SIDES]
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


## The core: the hairs' room, a little smaller, as one smooth body - so the tuft reads whole from across the table - and no taller than its
## outer hairs (a dome's are 38% shorter than its middle's); taller, it would stand as a solid band of paint over the ends of the hairs
## round it ([constant CORE_IN]).
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
			var y := L * s * (1.0 - float(row["dome"]) * 0.5 * s * s) * (1.0 - float(row["dome"]))
			var q := Vector3(cos(a) * hw * maxf(sx, 0.05) * CORE, y, sin(a) * hd * maxf(sz, 0.05) * CORE)
			ring.append([q, Vector3(cos(a) / maxf(hw, 1e-5), 0.2, sin(a) / maxf(hd, 1e-5)).normalized(), s])
		rings.append(ring)
	for i in CORE_STEPS:
		for k in CORE_SIDES:
			var a: Array = rings[i][k]
			var b: Array = rings[i][(k + 1) % CORE_SIDES]
			var c: Array = rings[i + 1][(k + 1) % CORE_SIDES]
			var d: Array = rings[i + 1][k]
			g.tri(a[0], b[0], c[0], a[1], b[1], c[1], Vector2(CORE_MARK, a[2]), Vector2(CORE_MARK, b[2]), Vector2(CORE_MARK, c[2]),
				Vector2(a[2], 0.0), Vector2(b[2], 0.0), Vector2(c[2], 0.0))
			g.tri(a[0], c[0], d[0], a[1], c[1], d[1], Vector2(CORE_MARK, a[2]), Vector2(CORE_MARK, c[2]), Vector2(CORE_MARK, d[2]),
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
		g.tri(a[0], b[0], mid, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(CORE_MARK, 0.93), Vector2(CORE_MARK, 0.93), Vector2(CORE_MARK, 1.0),
			Vector2(0.93, 0.0), Vector2(0.93, 0.0), Vector2(1.0, 0.0))


## Where the hairs want their tips at one moment (meters, the table's space): leaning back against [param velocity] (the brush's tip,
## meters a second), and folded aside and splayed as hard as it is [param pressed] (0-1) - a brush [param length] meters long whose
## hairs run back to the handle along [param axis] (unit, the table's space), its tip going [param ahead] along the surface as it is
## pressed (the way from where the handle leans over it to the tip; none for a brush held upright, or off a surface), its hairs taking
## [param bends] of a brush's bend and splay ([constant KINDS]' `bends`). Returns [bend, splay].
##
## Splayed as far as it is upright ([constant SPLAY_LEAN]): pressed straight down it mushrooms, leaned it bends.
##
## A bend is always aside, across the hairs, never along them: hairs keep one length. A fold along the handle's own way out of the surface
## would draw the hairs up into it and off the face. Only what goes across the hairs drags them; pressed, they fold the way the tip goes
## along the surface, and bent either way they keep their length ([method bent_at]).
static func target(velocity: Vector3, pressed: float, length: float, axis: Vector3, ahead := Vector3.ZERO, bends := 1.0) -> Array:
	# (...as far as its kind's hairs bend at all - [constant KINDS]' `bends`: a cotton tip a little)
	pressed *= bends
	var a := axis.normalized()
	var across := velocity - a * velocity.dot(a)
	var speed := across.length()
	var bend := Vector3.ZERO
	if speed > 1e-5:
		bend = -across / speed * DRAG_BEND * length * clampf(speed / DRAG_FULL, 0.0, 1.0) * pressed
	var fold := ahead - a * ahead.dot(a)
	if fold.length() > 1e-5:
		bend += fold / maxf(fold.length(), LEAN_FULL) * PRESS_BEND * length * pressed
	# (how far it leans: [param ahead] is the handle's own lean along the surface, the sine of its angle off the normal)
	return [bend, PRESS_SPLAY * pressed * lerpf(1.0, SPLAY_LEANED, clampf(ahead.length() / SPLAY_LEAN, 0.0, 1.0))]


## A point of the core pressed so its hairs splay [param splay]: `[how far up its hairs it stands now (of [param s]), how far down its
## height along them is drawn (a share of it), how far out from the middle it goes (a share of how far out it is)]` - a hair's own
## point is `[s, 0, splay * s * 1.2]`, out as they splay ([method target]).
static func core_at(s: float, splay: float) -> Vector3:
	var down := CORE_DOWN * splay
	var s2 := s * (1.0 - down)
	return Vector3(s2, down, -CORE_IN * splay * s2)


## A point [param s] (0-1) up a hair [param length] long bent [param bend] aside (meters, across it): (how far aside, how far along it
## from its root) - as prop_common.gdshaderinc draws it (`bristle_bend`, the same arithmetic): an arc of a circle through the root, as
## long as the hair, its tip [param bend] aside.
static func bent_at(s: float, bend: float, length: float) -> Vector2:
	var th := arc_angle(minf(bend / maxf(length, 1e-6), ASIDE_MOST))
	if th < 1e-4:
		return Vector2(0.0, length * s)
	var r := length / th
	return Vector2(r * (1.0 - cos(th * s)), r * sin(th * s))


## How a hair [param length] meters long lies on a level surface its root is [param over] meters over, pointing [param down] into it (the
## cosine of its angle off straight down at it): `Vector2(the share of it lying along the surface, the angle (radians) its arc turns
## through)`. Out of its reach, none. Reaching it, bent only as far as brings its tip onto it - the arc turning further the lower its
## root, until its tip runs along the surface; pushed down further than that, more of it lies there ([constant LAID_MOST] at most).
static func laid(over: float, down: float, length: float) -> Vector2:
	return laid_leaning(over, acos(clampf(down, 0.0, 1.0)), length)


## ...its root leaning [param lean] radians off straight down toward the way it is bent - against it, less than none: a hair trailed behind
## a brush swirled round a pot leans against the way it is laid half the time, and its arc turns through that much more.
static func laid_leaning(over: float, lean: float, length: float) -> Vector2:
	var a := clampf(lean, -PI * 0.5 + 1e-3, PI * 0.5)
	var c := cos(a)
	if length <= 0.0 or over >= length * c:
		return Vector2.ZERO
	var top := PI * 0.5 - a
	if top < 1e-3:
		return Vector2.ZERO
	var sa := sin(a)
	var o := maxf(over, 0.0)
	# (an arc of angle th drops its tip length * (sin(a + th) - sin(a)) / th under its root, less the further it turns)
	if o >= length * (1.0 - sa) / top:
		var lo := 0.0
		var hi := top
		for _i in 24:
			var mid := (lo + hi) * 0.5
			if length * (sin(a + mid) - sa) / mid > o:
				lo = mid
			else:
				hi = mid
		return Vector2(0.0, (lo + hi) * 0.5)
	return Vector2(minf(1.0 - o * top / (length * (1.0 - sa)), LAID_MOST), top)


## How far over a level surface the root of a hair [param length] long, pointing [param down] into it ([method laid]), stands when
## [param share] of it lies along the surface (meters).
static func lay_over(down: float, length: float, share: float) -> float:
	var a := acos(clampf(down, 0.0, 1.0))
	return length * (1.0 - clampf(share, 0.0, LAID_MOST)) * (1.0 - sin(a)) / maxf(PI * 0.5 - a, 1e-3)


## A point [param s] (0-1) up a hair [param length] long laid as [param lay] says ([method laid]): (how far aside, how far along it from
## its root) - as prop_common.gdshaderinc draws it (`bristle_lay`, the same arithmetic): an arc of a circle from the root over the share
## that does not lie on the surface, turning through `lay.y`, and the rest straight on from its end.
static func laid_at(s: float, lay: Vector2, length: float) -> Vector2:
	var th := lay.y
	if th < 1e-4:
		return Vector2(0.0, length * s)
	var arc := 1.0 - clampf(lay.x, 0.0, LAID_MOST)
	var r := length * arc / th
	var u := minf(s, arc) / arc
	var past := maxf(s - arc, 0.0) * length
	return Vector2(r * (1.0 - cos(th * u)) + past * sin(th), r * sin(th * u) + past * cos(th))


## The angle an arc turns through (radians) whose end is [param q] of its length aside of where it began: (1 - cos th) / th = q, by
## Newton's way from twice it (the small arc's own).
static func arc_angle(q: float) -> float:
	var th := 2.0 * q
	for _i in 4:
		var f := (1.0 - cos(th)) / maxf(th, 1e-4) - q
		var df := (th * sin(th) - (1.0 - cos(th))) / maxf(th * th, 1e-8)
		th -= f / maxf(df, 1e-4)
	return maxf(th, 0.0)


## The spring's weights over the last [constant SPRING_STEPS] steps (newest first), summing to 1: a damped spring's own response -
## [param hz] and [param damping] its own, by default [constant SPRING_HZ], [constant SPRING_DAMPING] - so the hairs follow a moment
## behind and come back when the pull stops.
static func weights(hz := SPRING_HZ, damping := SPRING_DAMPING) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	var wn := TAU * hz
	var wd := wn * sqrt(1.0 - damping * damping)
	var sum := 0.0
	for k in SPRING_STEPS:
		var tau := float(k) * SPRING_STEP
		var h := exp(-damping * wn * tau) * sin(wd * tau + 0.35)
		w.append(h)
		sum += h
	for k in w.size():
		w[k] /= sum
	return w


## The hairs' bend at show time [param t]: [param at] (a function of a time, giving [bend, splay] as [method target] does)
## followed as the spring follows it ([method weights], [param hz] and [param damping] its own) - a pure function of time.
static func response(at: Callable, t: float, hz := SPRING_HZ, damping := SPRING_DAMPING) -> Array:
	var w := weights(hz, damping)
	var bend := Vector3.ZERO
	var splay := 0.0
	for k in w.size():
		var got: Array = at.call(t - float(k) * SPRING_STEP)
		bend += (got[0] as Vector3) * w[k]
		splay += float(got[1]) * w[k]
	return [bend, maxf(splay, 0.0)]
