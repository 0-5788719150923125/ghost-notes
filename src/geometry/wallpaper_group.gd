extends RefCounted
class_name WallpaperGroup

## WallpaperGroup - the seventeen plane symmetry groups, as a table plus an enumerator.
##
## A group is a lattice kind plus a handful of generators; the full set of copies, which are mirrored, and where the cells fall on
## screen are derived.
##
## Representation: every operation is written in fractional lattice coordinates, where (u, v) means u*a1 + v*a2. There every
## point-group operation of every plane group has integer matrix entries and translation parts that are exact halves, whatever
## the lattice's angle or aspect (a 120-degree rotation is [[0,-1],[1,-1]]): no trigonometry, no epsilon comparisons. Cartesian
## transforms are recovered by conjugating with the basis matrix A = [a1 a2]: X = A M A^-1.
##
## Closure: only generators are stored, and the constructor closes the group by breadth-first composition modulo the lattice
## (translation parts taken mod 1), so whatever generators are listed the result is closed under composition and the pattern maps
## onto itself exactly. The closure terminates because the element set is bounded (order 12 point group x 4 centrings at worst);
## [constant MAX_COSETS] is a cap, not the real bound.
##
## Glides and centrings fall out: pg is a mirror carrying a half-cell translation, and its square reduces to the identity. The
## centered lattices (cm, cmm) are a rectangular lattice plus a coset with identity linear part and translation (1/2, 1/2).
##
## Handedness: reflected cosets are flagged (`flip`), because a reflected polygon comes out with reversed winding. Nothing in
## ghost's 2D path culls by winding, so this is advisory.

## Cap on the closure. The largest real plane group is p6m at order 12 and a centering can double a coset count, so 64 only
## guards against a mistyped generator spinning forever.
const MAX_COSETS := 64

## Cap on cells emitted by one [method cell_offsets] call: a badly sized lattice gets a truncated pattern rather than a frozen frame.
const MAX_CELLS := 1200

## sqrt(3)/2: the height of the hexagonal lattice's second basis vector.
const HEX_H := 0.8660254037844386

## The seventeen groups. `lattice` names the cell shape the group requires (a 4-fold rotation cannot live on a rectangle), and
## `gens` lists generators as [m00, m01, m10, m11, tu, tv] in fractional coordinates: the 2x2 matrix acting on (u, v), then a
## translation in cell fractions.
##
## Examples: `[-1, 0, 0, -1, 0, 0]` is a half turn. `[-1, 0, 0, 1, 0, 0.5]` is a mirror in u composed with half a cell along v
## (a glide, so pg has no mirror lines). `[1, 0, 0, 1, 0.5, 0.5]` is the centering translation that turns pm into cm. In the
## hexagonal lattice a1 and a2 sit at 120 degrees, so a 3-fold rotation sends a1 -> a2 and a2 -> -a1-a2.
const GROUPS := {
	"p1":   {"lattice": "oblique", "gens": []},
	"p2":   {"lattice": "oblique", "gens": [[-1, 0, 0, -1, 0.0, 0.0]]},
	"pm":   {"lattice": "rect",    "gens": [[-1, 0, 0, 1, 0.0, 0.0]]},
	"pg":   {"lattice": "rect",    "gens": [[-1, 0, 0, 1, 0.0, 0.5]]},
	"cm":   {"lattice": "rect",    "gens": [[-1, 0, 0, 1, 0.0, 0.0], [1, 0, 0, 1, 0.5, 0.5]]},
	"pmm":  {"lattice": "rect",    "gens": [[-1, 0, 0, 1, 0.0, 0.0], [1, 0, 0, -1, 0.0, 0.0]]},
	"pmg":  {"lattice": "rect",    "gens": [[-1, 0, 0, -1, 0.0, 0.0], [1, 0, 0, -1, 0.5, 0.0]]},
	"pgg":  {"lattice": "rect",    "gens": [[-1, 0, 0, -1, 0.0, 0.0], [1, 0, 0, -1, 0.5, 0.5]]},
	"cmm":  {"lattice": "rect",    "gens": [[-1, 0, 0, 1, 0.0, 0.0], [1, 0, 0, -1, 0.0, 0.0],
			[1, 0, 0, 1, 0.5, 0.5]]},
	"p4":   {"lattice": "square",  "gens": [[0, -1, 1, 0, 0.0, 0.0]]},
	"p4m":  {"lattice": "square",  "gens": [[0, -1, 1, 0, 0.0, 0.0], [-1, 0, 0, 1, 0.0, 0.0]]},
	"p4g":  {"lattice": "square",  "gens": [[0, -1, 1, 0, 0.0, 0.0], [-1, 0, 0, 1, 0.5, 0.5]]},
	"p3":   {"lattice": "hex",     "gens": [[0, -1, 1, -1, 0.0, 0.0]]},
	"p3m1": {"lattice": "hex",     "gens": [[0, -1, 1, -1, 0.0, 0.0], [1, -1, 0, -1, 0.0, 0.0]]},
	"p31m": {"lattice": "hex",     "gens": [[0, -1, 1, -1, 0.0, 0.0], [0, 1, 1, 0, 0.0, 0.0]]},
	"p6":   {"lattice": "hex",     "gens": [[1, -1, 1, 0, 0.0, 0.0]]},
	"p6m":  {"lattice": "hex",     "gens": [[1, -1, 1, 0, 0.0, 0.0], [1, -1, 0, -1, 0.0, 0.0]]},
}

## Which group this is, one of [constant GROUPS].
var name := "p1"
## The cell shape it lives on: "oblique", "rect", "square" or "hex".
var lattice := "oblique"
## The lattice basis, in pixels. Every copy of the pattern sits at i*a1 + j*a2.
var a1 := Vector2(1.0, 0.0)
var a2 := Vector2(0.0, 1.0)
## The point group as CARTESIAN transforms, one per coset: {"xf": Transform2D, "flip": bool}.
## Always contains the identity first. Its size is the group's order.
var cosets: Array = []

var _basis := Transform2D.IDENTITY


## The lattice basis a group would use at the given cell length, before any group is built (a caller sizes the cell from a target
## cell count first, which needs the cell's area).
static func basis_of(kind: String, cell: float, ratio := 1.0, angle_deg := 90.0) -> PackedVector2Array:
	var c := maxf(0.001, cell)
	var r := clampf(ratio, 0.1, 10.0)
	if kind == "square":
		return PackedVector2Array([Vector2(c, 0.0), Vector2(0.0, c)])
	if kind == "rect":
		return PackedVector2Array([Vector2(c, 0.0), Vector2(0.0, c * r)])
	if kind == "hex":
		return PackedVector2Array([Vector2(c, 0.0), Vector2(-0.5 * c, HEX_H * c)])
	var t := deg_to_rad(clampf(angle_deg, 25.0, 155.0))
	return PackedVector2Array([Vector2(c, 0.0), Vector2(cos(t), sin(t)) * c * r])


static func lattice_of(gname: String) -> String:
	var e: Dictionary = GROUPS.get(gname, GROUPS["p1"])
	return String(e["lattice"])


## Area of this group's cell at unit cell length, |a1 x a2| with cell = 1; multiply by cell*cell for the real area (1 for
## square, `ratio` for rectangular, sqrt(3)/2 for hexagonal, ratio*sin(angle) for oblique).
static func unit_cell_area(gname: String, ratio := 1.0, angle_deg := 90.0) -> float:
	var b := basis_of(lattice_of(gname), 1.0, ratio, angle_deg)
	return maxf(0.0001, absf(b[0].cross(b[1])))


## Build a group at a concrete cell size. [param ratio] is the second basis vector's length relative to the first (rectangular
## and oblique lattices only) and [param angle_deg] the angle between them (oblique only); both are ignored where the symmetry fixes them.
static func make(gname: String, cell: float, ratio := 1.0, angle_deg := 90.0) -> WallpaperGroup:
	var g := WallpaperGroup.new()
	g.name = gname if GROUPS.has(gname) else "p1"
	var e: Dictionary = GROUPS[g.name]
	g.lattice = String(e["lattice"])
	var b := basis_of(g.lattice, cell, ratio, angle_deg)
	g.a1 = b[0]
	g.a2 = b[1]
	g._basis = Transform2D(g.a1, g.a2, Vector2.ZERO)
	g._close(e["gens"])
	return g


## The group's order: how many copies of the motif one cell carries.
func order() -> int:
	return cosets.size()


## A lattice vector by integer coefficients, in pixels: the only translations that leave the pattern invariant, so a glide along
## one reads as a step rather than drift.
func lattice_vector(i: int, j: int) -> Vector2:
	return a1 * float(i) + a2 * float(j)


## Every cell origin that can put ink inside the rect [-half, half], as cartesian offsets. The lattice is walked in fractional
## coordinates (exact for a sheared cell): the rect's corners mapped through A^-1 give a fractional bounding box, a strict superset
## of what is visible for an oblique lattice, so each candidate is then tested against the rect (the caller pays one draw call
## per cell).
##
## [param margin] is how far the motif reaches past its own cell origin; include the glide excursion in it.
func cell_offsets(half: Vector2, margin: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var inv := _basis.affine_inverse()
	var umin := INF
	var umax := -INF
	var vmin := INF
	var vmax := -INF
	var corners := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	for c in corners:
		var fc: Vector2 = inv * c
		umin = minf(umin, fc.x)
		umax = maxf(umax, fc.x)
		vmin = minf(vmin, fc.y)
		vmax = maxf(vmax, fc.y)
	var pu := int(ceil(margin / maxf(1.0, a1.length()))) + 1
	var pv := int(ceil(margin / maxf(1.0, a2.length()))) + 1
	var i0 := int(floor(umin)) - pu
	var i1 := int(ceil(umax)) + pu
	var j0 := int(floor(vmin)) - pv
	var j1 := int(ceil(vmax)) + pv
	var lx := half.x + margin
	var ly := half.y + margin
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var off := a1 * float(i) + a2 * float(j)
			if absf(off.x) > lx or absf(off.y) > ly:
				continue
			out.append(off)
			if out.size() >= MAX_CELLS:
				return out
	return out


# Breadth-first closure of the generators modulo the lattice, then conjugation into cartesian space. Elements are carried as
# [m00, m01, m10, m11, tu, tv]; the translation is reduced mod 1 after every composition, which keeps the element set finite.
func _close(gens: Array) -> void:
	var identity := PackedFloat32Array([1.0, 0.0, 0.0, 1.0, 0.0, 0.0])
	var elems: Array = [identity]
	var seen := {}
	seen[_key(identity)] = true
	var head := 0
	while head < elems.size() and elems.size() < MAX_COSETS:
		var e: PackedFloat32Array = elems[head]
		head += 1
		for gi in gens.size():
			var g: Array = gens[gi]
			var c := _compose(g, e)
			var k := _key(c)
			if seen.has(k):
				continue
			seen[k] = true
			elems.append(c)
	cosets = []
	var inv := _basis.affine_inverse()
	for i in elems.size():
		var e2: PackedFloat32Array = elems[i]
		# Transform2D takes its basis as columns: the images of (1,0) and (0,1).
		var m := Transform2D(Vector2(e2[0], e2[2]), Vector2(e2[1], e2[3]), Vector2(e2[4], e2[5]))
		cosets.append({
			"xf": _basis * m * inv,
			"flip": e2[0] * e2[3] - e2[1] * e2[2] < 0.0,
		})


# g composed with e, applying e first: linear part G*E, translation part G*e.t + g.t.
func _compose(g: Array, e: PackedFloat32Array) -> PackedFloat32Array:
	var m0 := float(g[0])
	var m1 := float(g[1])
	var m2 := float(g[2])
	var m3 := float(g[3])
	return PackedFloat32Array([
		m0 * e[0] + m1 * e[2],
		m0 * e[1] + m1 * e[3],
		m2 * e[0] + m3 * e[2],
		m2 * e[1] + m3 * e[3],
		fposmod(m0 * e[4] + m1 * e[5] + float(g[4]), 1.0),
		fposmod(m2 * e[4] + m3 * e[5] + float(g[5]), 1.0),
	])


# Identity of a coset. Matrix entries are integers and translations exact halves in every one of the seventeen groups, so
# quantizing the translation to twelfths is lossless here.
func _key(e: PackedFloat32Array) -> String:
	return "%d,%d,%d,%d,%d,%d" % [
		int(round(e[0])), int(round(e[1])), int(round(e[2])), int(round(e[3])),
		int(round(e[4] * 12.0)), int(round(e[5] * 12.0))]
