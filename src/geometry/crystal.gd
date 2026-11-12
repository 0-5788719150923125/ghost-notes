extends RefCounted
class_name Crystal

## Crystal - a bank of snow crystals, generated once from sampled morphology.
##
## The model: real snow crystal morphology is two-dimensional (Nakaya). Temperature selects the habit (plate near freezing,
## needle and column through the middle, plate then column when colder) and supersaturation selects the complexity (a bare prism
## at low humidity, a fernlike dendrite at high). Riming (supercooled droplets freezing onto the arms) is a third independent
## axis. The sampled space is `habit` x `branch_gens` x `rime`, and a weather can weight the habits it produces.
##
## The bank: crystals are generated once at build, as flat line lists in local unit space (radius 1, centered on the origin), and
## every falling flake references one by index. A few dozen different crystals shared across hundreds of flakes cost one array
## lookup and a transform per flake, and the geometry goes straight through [TriBatch] as segments.

## The habits. Weights are supplied per weather by the caller.
##   plate     - a bare hexagonal plate, no arms.
##   sectored  - a plate with ridges dividing it into six sectors.
##   stellar   - the classic six-armed star: arms with a couple of branch generations.
##   fern      - a stellar dendrite pushed to its limit; branches carry sub-branches.
##   needle    - a long thin spike, drawn with two folds.
##   column    - a stubby hexagonal prism seen with its axis across the frame.
##   capped    - a column with a plate at each end.
##   bullet    - a rosette of a few short columns sharing an origin at odd angles.
const HABITS := ["plate", "sectored", "stellar", "fern", "needle", "column", "capped", "bullet"]

## How many arms each habit is built on.
const FOLDS := {
	"plate": 6, "sectored": 6, "stellar": 6, "fern": 6,
	"needle": 2, "column": 2, "capped": 2, "bullet": 4,
}


## One crystal, ready to draw: `a`/`b` are matched endpoint arrays in local unit space (the crystal spans roughly radius 1), `w`
## is a per-segment width multiplier, and `fill` is an optional convex polygon for the solid-bodied habits.
class Shape:
	extends RefCounted
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	var w := PackedFloat32Array()
	var fill := PackedVector2Array()
	var habit := "stellar"
	var rime := 0.0

	func seg(p: Vector2, q: Vector2, width: float) -> void:
		a.append(p)
		b.append(q)
		w.append(width)

	func size() -> int:
		return a.size()


## Build [param count] crystals. [param weights] maps a habit name to a relative weight; anything absent is never generated.
## [param complexity] biases how many branch generations the branching habits get, and [param rime_max] how heavily they can be
## rimed - both are the weather's business, not the individual crystal's.
static func bank(rng: RandomNumberGenerator, count: int, weights: Dictionary,
		complexity := 0.5, rime_max := 0.0) -> Array:
	var names: Array = []
	var total := 0.0
	for k in HABITS:
		var wv := float(weights.get(k, 0.0))
		if wv > 0.0:
			names.append([k, wv])
			total += wv
	if names.is_empty():
		names = [["stellar", 1.0]]
		total = 1.0
	var out: Array = []
	for i in maxi(1, count):
		var pick := rng.randf() * total
		var habit := "stellar"
		for pair in names:
			pick -= float(pair[1])
			if pick <= 0.0:
				habit = String(pair[0])
				break
		out.append(make(rng, habit, complexity, rime_max))
	return out


## One crystal of a named habit.
static func make(rng: RandomNumberGenerator, habit: String, complexity := 0.5,
		rime_max := 0.0) -> Shape:
	var s := Shape.new()
	s.habit = habit
	s.rime = 0.0 if rime_max <= 0.0 else rng.randf_range(0.0, rime_max)
	var folds: int = int(FOLDS.get(habit, 6))
	match habit:
		"plate":
			_plate(s, rng, 1.0, true)
		"sectored":
			_plate(s, rng, 1.0, true)
			_sector_ridges(s, rng)
		"needle":
			_needle(s, rng)
		"column":
			_column(s, rng, false)
		"capped":
			_column(s, rng, true)
		"bullet":
			_bullet(s, rng)
		_:
			_dendrite(s, rng, folds, complexity, habit == "fern")
	if s.rime > 0.01:
		_rime(s, rng)
	return s


# --- habits ------------------------------------------------------------------------

## A regular hexagon. `solid` fills it; otherwise it is an outline.
static func _plate(s: Shape, rng: RandomNumberGenerator, r: float, solid: bool) -> void:
	var turn := rng.randf() * TAU
	# a few percent of radius variation per corner, so it reads as grown rather than drawn
	var pts := PackedVector2Array()
	for i in 6:
		var ang := turn + TAU * float(i) / 6.0
		var rr := r * rng.randf_range(0.94, 1.03)
		pts.append(Vector2(cos(ang), sin(ang)) * rr)
	for i in 6:
		s.seg(pts[i], pts[(i + 1) % 6], 1.0)
	if solid:
		s.fill = pts


## The ridges that divide a sectored plate: a spoke to each corner, sometimes stopping short of it, so the sectors read as facets.
static func _sector_ridges(s: Shape, rng: RandomNumberGenerator) -> void:
	var reach := rng.randf_range(0.55, 0.95)
	var n := s.fill.size()
	for i in n:
		s.seg(Vector2.ZERO, s.fill[i] * reach, 0.7)


## A long thin spike, drawn on two folds so it is a bar rather than a star.
static func _needle(s: Shape, rng: RandomNumberGenerator) -> void:
	var half_w := rng.randf_range(0.03, 0.10)
	var taper := rng.randf_range(0.2, 0.7)
	var ang := rng.randf() * TAU
	var d := Vector2(cos(ang), sin(ang))
	var p := Vector2(-d.y, d.x) * half_w
	# a closed sliver: two long sides drawn toward a narrowed tip at each end
	s.seg(-d + p * taper, d + p * taper, 1.0)
	s.seg(-d - p * taper, d - p * taper, 1.0)
	s.seg(-d + p * taper, -d - p * taper, 0.8)
	s.seg(d + p * taper, d - p * taper, 0.8)
	# a few internal striations
	var lines := rng.randi_range(1, 3)
	for i in lines:
		var f := float(i + 1) / float(lines + 1) * 2.0 - 1.0
		s.seg(d * f + p, d * f - p, 0.5)


## A hexagonal prism seen from the side: two end caps joined by its long faces. `capped` puts a full plate on each end.
static func _column(s: Shape, rng: RandomNumberGenerator, capped: bool) -> void:
	var ang := rng.randf() * TAU
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	var half_len := rng.randf_range(0.55, 1.0)
	var rad := rng.randf_range(0.16, 0.34)
	var c0 := -d * half_len
	var c1 := d * half_len
	for k in [-1.0, 1.0]:
		s.seg(c0 + n * rad * k, c1 + n * rad * k, 1.0)
	s.seg(c0 - n * rad, c0 + n * rad, 0.9)
	s.seg(c1 - n * rad, c1 + n * rad, 0.9)
	# the visible far edge of the prism
	s.seg(c0 + n * rad * 0.35, c1 + n * rad * 0.35, 0.45)
	if capped:
		var cap := rng.randf_range(0.5, 0.85)
		for c in [c0, c1]:
			var pts := PackedVector2Array()
			for i in 6:
				var a2 := TAU * float(i) / 6.0
				pts.append(c + (n * cos(a2) + d * sin(a2) * 0.25) * cap)
			for i in 6:
				s.seg(pts[i], pts[(i + 1) % 6], 0.8)


## A bullet rosette: a few short columns sharing an origin at independent angles.
static func _bullet(s: Shape, rng: RandomNumberGenerator) -> void:
	var arms := rng.randi_range(3, 6)
	for i in arms:
		var ang := rng.randf() * TAU
		var d := Vector2(cos(ang), sin(ang))
		var n := Vector2(-d.y, d.x)
		var ln := rng.randf_range(0.45, 1.0)
		var rad := ln * rng.randf_range(0.10, 0.22)
		for k in [-1.0, 1.0]:
			s.seg(n * rad * float(k), d * ln + n * rad * float(k) * 0.4, 0.9)
		s.seg(d * ln - n * rad * 0.4, d * ln + n * rad * 0.4, 0.7)


## The branching habits: `gens` generations of side branches on each arm, at sampled positions and lengths, with sibling
## jitter: the schedule is drawn once for the crystal and each arm perturbs it slightly.
static func _dendrite(s: Shape, rng: RandomNumberGenerator, folds: int, complexity: float,
		fern: bool) -> void:
	var gens := 1
	if fern:
		gens = 2 if rng.randf() < 0.35 else 3
	else:
		gens = 1 if rng.randf() > complexity else 2
	var per_arm := rng.randi_range(2, 5) if fern else rng.randi_range(1, 3)
	var branch_ang := deg_to_rad(rng.randf_range(52.0, 68.0))
	var core := rng.randf_range(0.0, 0.30)
	var decay := rng.randf_range(0.62, 0.9) if fern else rng.randf_range(0.45, 0.72)
	# the shared schedule: where along the arm each branch pair sits, and how long it is
	var at: Array = []
	for k in per_arm:
		var f := core + (1.0 - core) * (float(k + 1) / float(per_arm + 1))
		at.append([f, rng.randf_range(0.22, 0.44) * (1.0 - f * 0.5)])
	if core > 0.02:
		_plate_at(s, rng, core, folds)
	for arm in folds:
		var base := TAU * float(arm) / float(folds)
		# per-arm jitter, a few percent
		var ang := base + deg_to_rad(rng.randf_range(-2.5, 2.5))
		var reach := rng.randf_range(0.95, 1.0)
		var d := Vector2(cos(ang), sin(ang))
		s.seg(d * core, d * reach, 1.0)
		for pair in at:
			var f: float = float(pair[0]) * rng.randf_range(0.96, 1.04)
			var ln: float = float(pair[1]) * rng.randf_range(0.9, 1.12)
			var root := d * (reach * f)
			for sgn in [-1.0, 1.0]:
				var ba: float = ang + float(sgn) * branch_ang
				var bd := Vector2(cos(ba), sin(ba))
				var tip := root + bd * ln
				s.seg(root, tip, 0.75)
				if gens >= 2:
					# sub-branches: the difference between a stellar dendrite and a fernlike one
					var subs := 2 if fern else 1
					for j in subs:
						var sf := float(j + 1) / float(subs + 1)
						var sroot := root + bd * (ln * sf)
						for sg2 in [-1.0, 1.0]:
							var sa: float = ba + float(sg2) * branch_ang
							s.seg(sroot, sroot + Vector2(cos(sa), sin(sa)) * (ln * decay * 0.5), 0.5)


## A small central hexagon some dendrites grow out of.
static func _plate_at(s: Shape, rng: RandomNumberGenerator, r: float, folds: int) -> void:
	var pts := PackedVector2Array()
	var turn := rng.randf() * TAU
	var n := maxi(3, folds)
	for i in n:
		var ang := turn + TAU * float(i) / float(n)
		pts.append(Vector2(cos(ang), sin(ang)) * r)
	for i in n:
		s.seg(pts[i], pts[(i + 1) % n], 0.8)


## Riming: frozen droplets stuck to the structure, modeled as short stubs normal to existing segments, so a rimed crystal reads
## as lumpy and blurred at its edges.
static func _rime(s: Shape, rng: RandomNumberGenerator) -> void:
	var n := s.size()
	if n == 0:
		return
	var drops := int(6.0 + 26.0 * s.rime)
	for i in drops:
		var k := rng.randi() % n
		var p := s.a[k]
		var q := s.b[k]
		var f := rng.randf()
		var at := p.lerp(q, f)
		var dir := (q - p).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var len2 := rng.randf_range(0.03, 0.09) * (0.5 + s.rime)
		var sgn := 1.0 if rng.randf() < 0.5 else -1.0
		s.seg(at, at + nrm * (len2 * sgn), 0.6)
