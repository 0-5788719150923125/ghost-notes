extends RefCounted
class_name AssemblyHeap

## AssemblyHeap - WHERE AN ASSEMBLY'S PARTS WAIT, as the plan knows it: a tub, a tray or a pile on the table, as a height field. Pure data, no node ([Assembly] asks it for places; a
## gate stands one with no table). It says what a stock's inside is ([method TableAssembly._heap_of]: which [AssemblyBake] pours real pieces into), and where things seem to lie in a
## preview, where a puppeteer or a set dresser asks for no record: each lands on what is already there, in a few tries at the lowest place it can find, tilted by the ground it lands on.
## What the pieces really do is the record's ([AssemblyWorld]). A cell keeps its pieces in the order they landed, so whatever came after one in a cell it shares lies on it.

## A cell of the height field (meters): under the narrowest piece, a stud across.
const CELL := 0.006
## Tries at a place a piece has ([method deposit]), the lowest kept.
const TRIES := 9
## How a piece lands, by share: studs up, studs down, or on its long side.
const FACE_UP := 0.62
const FACE_DOWN := 0.22
## The most a piece lies tilted by what is under it (radians), and how much of the height of the highest thing under it it
## rests at against the mean of what is under it (a piece bridges the low places and nests a little).
const TILT_MOST := 0.5
const NESTLE := 0.72
## A pile keeps toward its middle: a place's height counts this much more per its distance from there (meters, at its reach).
const GATHER := 0.007

var name := ""
var origin := Vector2.ZERO        # the middle of cell (0, 0), on the table
var nx := 0
var nz := 0
var ground := PackedFloat32Array()    # the height of each cell with nothing in it; NAN outside the heap
var rim := INF                    # a container's rim: heaped past it, a piece slides elsewhere first
var middle := Vector2.ZERO
var reach := 0.1                  # how far from the middle a pile lands (a container fills evenly: 0)
var thing := ""                   # the table's thing that holds it, "" for a pile on the table
var deep := 0.0                   # how deep what lies in a container may lie (meters), up to how full it was written
var bed := NAN                    # the false floor a deep container is filled over ([method TableAssembly._surface_of])
var _stacks := {}                 # a cell -> [[top, id], ...] in the order they landed
var _of := {}                     # id -> {"cells": PackedInt32Array, "top": float, "at": Vector2}


## A PILE on the table at [param at] (meters), [param radius] across at most, on ground at height [param y].
static func pile(heap_name: String, at: Vector2, radius: float, y := 0.0) -> AssemblyHeap:
	var h := AssemblyHeap.new()
	h.name = heap_name
	var grown := radius * 1.3
	h.nx = int(ceil(grown * 2.0 / CELL)) + 1
	h.nz = h.nx
	h.origin = at - Vector2(grown, grown)
	h.middle = at
	h.reach = radius * 0.8
	h.ground.resize(h.nx * h.nz)
	for j in h.nz:
		for i in h.nx:
			var p := h.origin + Vector2(i, j) * CELL
			h.ground[j * h.nx + i] = y if p.distance_to(at) <= grown else NAN
	return h


## WHAT IS INSIDE A CONTAINER: [param heights], nx x nz of them from [param from] on the table, NAN where it is not inside;
## [param rim_y] how high its wall stands.
static func inside(heap_name: String, from: Vector2, cols: int, rows: int, heights: PackedFloat32Array, rim_y: float) -> AssemblyHeap:
	var h := AssemblyHeap.new()
	h.name = heap_name
	h.origin = from
	h.nx = cols
	h.nz = rows
	h.ground = heights
	h.rim = rim_y
	h.reach = 0.0
	var sum := Vector2.ZERO
	var n := 0
	for j in rows:
		for i in cols:
			if not is_nan(heights[j * cols + i]):
				sum += Vector2(i, j)
				n += 1
	h.middle = from + (sum / float(maxi(n, 1))) * CELL
	return h


## Its cells with ground under them.
func area_cells() -> int:
	var n := 0
	for v in ground:
		if not is_nan(v):
			n += 1
	return n


## Nothing in it: as it stood before anything landed.
func empty() -> void:
	_stacks = {}
	_of = {}


func _cell(x: float, z: float) -> int:
	var i := int(round((x - origin.x) / CELL))
	var j := int(round((z - origin.y) / CELL))
	if i < 0 or j < 0 or i >= nx or j >= nz:
		return -1
	return j * nx + i


## How high it stands at [param x], [param z] (meters) - NAN off it.
func height_at(x: float, z: float) -> float:
	var c := _cell(x, z)
	return NAN if c < 0 else _height(c)


func _height(c: int) -> float:
	var h := ground[c]
	if is_nan(h):
		return NAN
	var st: Variant = _stacks.get(c)
	if st != null:
		for e in st:
			h = maxf(h, float((e as Array)[0]))
	return h


## The highest it stands anywhere, what is in it counted.
func top() -> float:
	var out := -INF
	for c in _stacks:
		out = maxf(out, _height(int(c)))
	if out == -INF:
		for v in ground:
			if not is_nan(v):
				out = maxf(out, v)
	return out


## WHERE A PIECE COMES TO REST, let fall here ([param aim], within [param spread] of it, meters; the heap's own middle and reach by
## default): its pose, and it lies there from now on. [param w], [param d] its size (meters across, deep), [param tall] its body's
## height, the piece's origin the middle of its underside.
func deposit(id: int, w: float, d: float, tall: float, rng: RandomNumberGenerator, aim := Vector2.INF, spread := -1.0) -> Transform3D:
	var at := middle if aim == Vector2.INF else aim
	var r := spread if spread >= 0.0 else reach
	var face := rng.randf()
	var flip := face >= FACE_UP and face < FACE_UP + FACE_DOWN
	var on_side := face >= FACE_UP + FACE_DOWN
	# what it covers lying that way: across, along, and how tall it lies
	var a := tall if on_side else w
	var c := w if on_side else tall
	var best := {}
	for _k in TRIES:
		var p := _place_near(at, r, rng)
		var yaw := rng.randf() * TAU
		var ex := Vector2(cos(yaw), -sin(yaw))
		var ez := Vector2(sin(yaw), cos(yaw))
		var samples := _samples(p, ex, ez, a, d)
		var low := INF
		var high := -INF
		var sum := 0.0
		var n := 0
		var cells := PackedInt32Array()
		var off := false
		for s in samples:
			var cell := _cell((s as Vector2).x, (s as Vector2).y)
			var v := NAN if cell < 0 else _height(cell)
			if is_nan(v):
				off = true
				break
			low = minf(low, v)
			high = maxf(high, v)
			sum += v
			n += 1
			if not cells.has(cell):
				cells.append(cell)
		if off or n == 0:
			continue
		var rest := lerpf(sum / float(n), high, NESTLE)
		var score := rest
		if reach > 0.0:
			score += GATHER * pow(p.distance_to(middle) / reach, 2.0)
		# ...over a container's rim only when nothing else is left
		if rest + c > rim:
			score += 0.05
		if best.is_empty() or score < float(best["score"]):
			best = {"score": score, "p": p, "yaw": yaw, "rest": rest, "cells": cells, "ex": ex, "ez": ez, "low": low, "high": high}
	if best.is_empty():
		# no room that way anywhere: down the middle, flat - a heap is never short of a place
		var cell := _cell(middle.x, middle.y)
		var v: float = _height(cell) if cell >= 0 and not is_nan(_height(cell)) else 0.0
		best = {"score": v, "p": middle, "yaw": rng.randf() * TAU, "rest": v, "cells": PackedInt32Array([cell] if cell >= 0 else []),
			"ex": Vector2.RIGHT, "ez": Vector2.DOWN, "low": v, "high": v}
	var pos: Vector2 = best["p"]
	var y0 := float(best["rest"])
	var yaw := float(best["yaw"])
	# TILTED BY WHAT IT LANDED ON: the ground's fall across its two sides, up to [constant TILT_MOST]
	var ex: Vector2 = best["ex"]
	var ez: Vector2 = best["ez"]
	var fall_a := _fall(pos, ex, a)
	var fall_d := _fall(pos, ez, d)
	var tilt := Basis(Vector3.BACK, clampf(fall_a, -TILT_MOST, TILT_MOST)) * Basis(Vector3.LEFT, clampf(fall_d, -TILT_MOST, TILT_MOST))
	var lie := Basis.IDENTITY
	if flip:
		lie = Basis(Vector3.BACK, PI)
	elif on_side:
		lie = Basis(Vector3.BACK, PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0))
	var basis := Basis(Vector3.UP, yaw) * tilt * lie
	# the origin is the middle of the underside: found from the middle of the piece, which rests half its lying height up
	var mid := Vector3(pos.x, y0 + c * 0.5, pos.y)
	var origin_at := mid - basis * Vector3(0.0, tall * 0.5, 0.0)
	var top_y := y0 + c + maxf(absf(fall_a) * a, absf(fall_d) * d) * 0.5
	_land(id, best["cells"] as PackedInt32Array, top_y, pos)
	return Transform3D(basis, origin_at)


func _land(id: int, cells: PackedInt32Array, top_y: float, at: Vector2) -> void:
	for c in cells:
		if not _stacks.has(c):
			_stacks[c] = []
		(_stacks[c] as Array).append([top_y, id])
	_of[id] = {"cells": cells, "top": top_y, "at": at}


func _place_near(at: Vector2, r: float, rng: RandomNumberGenerator) -> Vector2:
	if r <= 0.0:
		# a container fills evenly: any cell it has
		for _k in 24:
			var c := rng.randi_range(0, ground.size() - 1)
			if not is_nan(ground[c]):
				return origin + Vector2(c % nx, c / nx) * CELL
		return middle
	# gathered round its middle, as things let fall are
	var a := rng.randf() * TAU
	var d := r * sqrt(-2.0 * log(maxf(rng.randf(), 1e-4))) * 0.6
	return at + Vector2(cos(a), sin(a)) * d


## Where to look under a piece at [param p]: its middle, its corners and its sides' middles.
static func _samples(p: Vector2, ex: Vector2, ez: Vector2, a: float, d: float) -> Array:
	var out: Array = []
	for i in 3:
		for j in 3:
			out.append(p + ex * a * (float(i) * 0.5 - 0.5) * 0.92 + ez * d * (float(j) * 0.5 - 0.5) * 0.92)
	return out


## How much the ground falls under a piece, along [param along], over [param span] meters (radians, its rise over run).
func _fall(p: Vector2, along: Vector2, span: float) -> float:
	var q0 := p - along * span * 0.5
	var q1 := p + along * span * 0.5
	var c0 := _cell(q0.x, q0.y)
	var c1 := _cell(q1.x, q1.y)
	if c0 < 0 or c1 < 0:
		return 0.0
	var h0 := _height(c0)
	var h1 := _height(c1)
	if is_nan(h0) or is_nan(h1):
		return 0.0
	return atan2(h1 - h0, maxf(span, 0.004))


## Whether piece [param id] lies here.
func holds(id: int) -> bool:
	return _of.has(id)


## WHAT LIES ON PIECE [param id]: each piece that landed after it in a cell it shares, each once, in the order they lie (the first
## on it first, so the last of them has nothing on it).
func on_it(id: int) -> Array:
	var seen := {}
	var out: Array = []
	var me: Variant = _of.get(id)
	if me == null:
		return out
	for c in (me as Dictionary)["cells"]:
		var st: Array = _stacks[c]
		var past := false
		for e in st:
			var other := int((e as Array)[1])
			if other == id:
				past = true
			elif past and not seen.has(other):
				seen[other] = true
				out.append(other)
	return out


## Piece [param id] taken off: what lay on it should have gone first ([method on_it]).
func take(id: int) -> void:
	var me: Variant = _of.get(id)
	if me == null:
		return
	for c in (me as Dictionary)["cells"]:
		var st: Array = _stacks[c]
		for i in range(st.size() - 1, -1, -1):
			if int((st[i] as Array)[1]) == id:
				st.remove_at(i)
		if st.is_empty():
			_stacks.erase(c)
	_of.erase(id)


## Where piece [param id] lies, on the table (Vector2.INF: not here).
func where(id: int) -> Vector2:
	var me: Variant = _of.get(id)
	return (me as Dictionary)["at"] if me != null else Vector2.INF


## THE PIECES ON TOP near [param at] (within [param within] meters), nearest first, at most [param most]: what a hand going in there
## meets first, each with nothing on it.
func on_top_near(at: Vector2, within: float, most: int) -> Array:
	var found: Array = []
	for id in _of:
		var p: Vector2 = (_of[id] as Dictionary)["at"]
		var dist := p.distance_to(at)
		if dist <= within and on_it(int(id)).is_empty():
			found.append([dist, int(id)])
	found.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var out: Array = []
	for f in found.slice(0, most):
		out.append(int((f as Array)[1]))
	return out


## Every piece lying here.
func ids() -> Array:
	return _of.keys()
