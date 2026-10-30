extends RefCounted
class_name SurfaceWaves

## SurfaceWaves - A LIQUID'S SURFACE, MOVED (next/table_physics.md, "Liquids"): its heights over an even grid across its
## vessel's inside, stepped as a damped wave equation, by [TablePhysics] on the bake's thread. The user, 2026-10-29, of
## the-quiet-crucible 841899's ladle going round in its cauldron: "I am not seeing any water physics, surface tension, or
## any of that. I still think we need better liquid physics, which would react to ANYTHING we put into them." So:
##
##   - its ripples run at [constant SPEED], water's slowest (at a 1.7 cm wavelength, where its surface tension and its
##     weight pull alike: shorter ripples run faster for their tension, longer for their weight), die away over a
##     second or two, and come back off its vessel's walls, which nothing flows through;
##   - EVERYTHING THAT CROSSES IT MOVES IT: a solid coming into a cell of the surface pushes it up as it comes, and going,
##     lets it down - a ladle going round heaps a bow wave before it and leaves a wake, a vial dipped rings it; whatever
##     falls in dents it where it lands ([method dent]); what floats rides it ([method height_at]).
##
## Its own state is a Dictionary ([method fresh]) the bake keeps in its checkpoints; this holds only the grid. Pure data.

## How fast a ripple runs (meters a second), how fast one dies (a second), the most cells across, the least and most a
## cell may be (meters), and how many substeps a cell crossed at SPEED takes at least (two to a cell for a stable step).
const SPEED := 0.23
const DAMP := 1.4
const CELLS := 28
const CELL := Vector2(0.004, 0.02)
## How high a cell is pushed as a solid comes into all of it (meters) - for a ladle's bowl going round at a stir's pace, a
## bow wave a couple of millimeters high - and the highest the surface ever stands off its level.
const WAKE := 0.0035
const MOST := 0.006
## Kept a frame at a time as bytes: a step of this many meters each (127 of them up or down), and stiller than this all
## over it is still, and no longer stepped.
const QUANTUM := 0.00005
const STILL := 0.00003

var n := 0
var cell := 0.01
var o := Vector2.ZERO          # the grid's corner, its vessel's own space (x, z, meters)
var mask := PackedByteArray()  # the cells within the inside at the surface
var nb := PackedInt32Array()   # each cell's four neighbors - itself where its neighbor is beyond the wall
var _key := ""


## THE GRID OVER VESSEL [param vs]'s inside, its cells as many as fit [constant CELLS] across its widest.
static func of(vs: Vessel) -> SurfaceWaves:
	var w := SurfaceWaves.new()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in vs.points:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var span := maxf(hi.x - lo.x, hi.y - lo.y) * 1.06 + 0.002
	w.cell = clampf(span / float(CELLS), CELL.x, CELL.y)
	w.n = clampi(int(ceil(span / w.cell)), 4, CELLS)
	w.o = (lo + hi) * 0.5 - Vector2.ONE * (float(w.n) * w.cell * 0.5)
	w.mask.resize(w.n * w.n)
	w.nb.resize(w.n * w.n * 4)
	return w


## A surface at rest: its heights, those a step before, and what of each solid lay in each cell (`{solid: {cell: share}}`).
func fresh() -> Dictionary:
	var h := PackedFloat32Array()
	h.resize(n * n)
	return {"h": h, "hp": h.duplicate(), "occ": {}, "on": false}


## The middle of cell [param c] on the surface [param s] along [param up] (its vessel's own space).
func point(c: int, up: Vector3, s: float) -> Vector3:
	var x := o.x + (float(c % n) + 0.5) * cell
	var z := o.y + (float(c / n) + 0.5) * cell
	return Vector3(x, (s - up.x * x - up.z * z) / maxf(up.y, 0.05), z)


## The cell over [param q] (its vessel's own space), or -1 off the grid.
func cell_of(q: Vector3) -> int:
	var i := int(floor((q.x - o.x) / cell))
	var j := int(floor((q.z - o.y) / cell))
	return j * n + i if i >= 0 and j >= 0 and i < n and j < n else -1


## WHICH CELLS ARE LIQUID, the surface [param s] along [param up] in [param vs]: each whose middle there is inside - and each
## one's neighbors, a wall's own cell standing for what is beyond it. Found again only as the surface moves a quarter
## of a cell.
func remask(vs: Vessel, up: Vector3, s: float) -> void:
	var q := cell * 0.25
	var key := "%d %d %d %d" % [roundi(s / q), roundi(up.x * 40.0), roundi(up.z * 40.0), roundi(up.y * 40.0)]
	if key == _key:
		return
	_key = key
	for c in n * n:
		mask[c] = 1 if vs.contains(point(c, up, s)) else 0
	for c in n * n:
		var i := c % n
		var j := c / n
		var ns := [c - 1 if i > 0 else c, c + 1 if i < n - 1 else c, c - n if j > 0 else c, c + n if j < n - 1 else c]
		for k in 4:
			nb[c * 4 + k] = int(ns[k]) if mask[int(ns[k])] == 1 else c


## Cell [param c] pushed up by [param dh] meters (down, less than 0).
func push(st: Dictionary, c: int, dh: float) -> void:
	if c < 0 or mask[c] == 0:
		return
	var h: PackedFloat32Array = st["h"]
	h[c] = clampf(h[c] + dh, -MOST, MOST)
	st["h"] = h
	st["on"] = true


## A DENT where something lands: [param depth] meters down at [param q] (its vessel's own space), less out to
## [param radius] - the ring it makes running out from it.
func dent(st: Dictionary, q: Vector3, depth: float, radius: float) -> void:
	var r := maxf(radius, cell * 0.75)
	var reach := int(ceil(r * 2.0 / cell))
	var c0 := cell_of(q)
	if c0 < 0:
		return
	var h: PackedFloat32Array = st["h"]
	for dj in range(-reach, reach + 1):
		for di in range(-reach, reach + 1):
			var i := c0 % n + di
			var j := c0 / n + dj
			if i < 0 or j < 0 or i >= n or j >= n or mask[j * n + i] == 0:
				continue
			var x := o.x + (float(i) + 0.5) * cell - q.x
			var z := o.y + (float(j) + 0.5) * cell - q.z
			var c := j * n + i
			h[c] = clampf(h[c] - depth * exp(-(x * x + z * z) / (r * r)), -MOST, MOST)
	st["h"] = h
	st["on"] = true


## [param dt] seconds of the surface: the wave equation in as many substeps as keep it stable, held to its level (its
## mean the volume's, never the ripples'), and still once it is - whether it still moves.
func step(st: Dictionary, dt: float) -> bool:
	if not bool(st["on"]):
		return false
	var h: PackedFloat32Array = st["h"]
	var hp: PackedFloat32Array = st["hp"]
	var steps := maxi(1, int(ceil(SPEED * dt / (0.5 * cell))))
	var hh := dt / float(steps)
	var k2 := (SPEED * hh / cell) * (SPEED * hh / cell)
	var keep := 1.0 - DAMP * hh
	var cells := n * n
	var hn := PackedFloat32Array()
	hn.resize(cells)
	var most := 0.0
	for s in steps:
		var sum := 0.0
		var count := 0
		for c in cells:
			if mask[c] == 0:
				continue
			var hc := h[c]
			var lap := h[nb[c * 4]] + h[nb[c * 4 + 1]] + h[nb[c * 4 + 2]] + h[nb[c * 4 + 3]] - 4.0 * hc
			var v := clampf(hc + (hc - hp[c]) * keep + k2 * lap, -MOST, MOST)
			hn[c] = v
			sum += v
			count += 1
		var mean := sum / float(maxi(count, 1))
		hp = h
		h = hn.duplicate()
		most = 0.0
		for c in cells:
			if mask[c] == 1:
				h[c] -= mean
				most = maxf(most, maxf(absf(h[c]), absf(h[c] - hp[c])))
			else:
				h[c] = 0.0
	if most < STILL:
		h.fill(0.0)
		hp.fill(0.0)
		st["on"] = false
	st["h"] = h
	st["hp"] = hp
	return bool(st["on"])


## The surface's heights as kept a frame at a time: a byte a cell, [constant QUANTUM] a step, 128 its level.
func bytes(st: Dictionary) -> PackedByteArray:
	var h: PackedFloat32Array = st["h"]
	var out := PackedByteArray()
	out.resize(n * n)
	for c in n * n:
		out[c] = clampi(roundi(h[c] / QUANTUM) + 128, 1, 255)
	return out


## How far above its level the surface stands over [param q] (its vessel's own space, meters), read from [param st]
## between the cells' middles.
func height_at(st: Dictionary, q: Vector3) -> float:
	var h: PackedFloat32Array = st["h"]
	var fx := (q.x - o.x) / cell - 0.5
	var fz := (q.z - o.y) / cell - 0.5
	var i := clampi(int(floor(fx)), 0, n - 2)
	var j := clampi(int(floor(fz)), 0, n - 2)
	var tx := clampf(fx - float(i), 0.0, 1.0)
	var tz := clampf(fz - float(j), 0.0, 1.0)
	var a := lerpf(h[j * n + i], h[j * n + i + 1], tx)
	var b := lerpf(h[(j + 1) * n + i], h[(j + 1) * n + i + 1], tx)
	return lerpf(a, b, tz)
