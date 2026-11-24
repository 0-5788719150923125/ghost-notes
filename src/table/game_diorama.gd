extends RefCounted
class_name GameDiorama

## GameDiorama - the model landscape in the middle of a game's table (next/tabletop.md, "The diorama"): a board of the kind
## people build for wargames and model railways, its ground modeled from data - hills, hollows, rivers cut into it and poured
## with resin water, roads, woods of flocked trees - and on it the places of the adventure (a town, a castle, a mill), each
## a thing ([Props]) a model maker built or took from the Library. The figures walk on it ([TableGame]) and the cameras go
## down among it ([Cameras]).
##
## The spec is data (`diorama.json`, the model maker's, [DioramaTools]); everything here is a pure function of it and the seed,
## built on a worker (no tree, no globals). Units in the spec are centimeters from the board's far left corner, x across to the
## right and z toward the head of the table; built in meters, the board's middle at [constant GameBoard.MIDDLE] and its
## bottom on the table.
##
## The board is a map to the game ([method board_of]): figures stand where the spec's centimeters say, on the ground's height
## ([method height_at]), and a place's name is a point on it ([method place_at]).
##
## Gate: tests/table/game_diorama_check.gd.

## How big the board is (centimeters): what [constant GameBoard.MAP_MOST] lets lie on the table.
const SIZE := Vector2(244.0, 152.0)
## How thick the board is under its flat ground (centimeters): a river is cut into it, never through.
const BOARD_H := 2.4
## One cell of the ground's grid (centimeters).
const CELL := 1.0
## The most of each, and how big any one may be (centimeters).
const MOST := {"hills": 40, "rivers": 6, "lakes": 6, "roads": 12, "woods": 28, "places": 24, "path": 32}
const HILL_MOST := 35.0
const HOLLOW_MOST := 2.2
const TREES_MOST := 1200
## The resin's surface, under the flat ground (centimeters): what is cut deeper than it is water.
const WATER_DOWN := 0.35
## How far round a place the ground is made flat for it to stand on, past its own outline (centimeters).
const PAD := 1.5
## The ground's colors when the spec says none: flock, earth, stone, a riverbed, a road.
const GRASS := "#5e7b3c"
const EARTH := "#7a6146"
const STONE := "#6b665c"
const BED := "#3f3a2c"
const ROAD := "#a08a64"
const WATER := "#26444c"
const EDGE := "#2e2620"
const SORTS := ["leafy", "pine", "dead"]
## What the board's ground is: `land`, modeled country (flock, hills, resin water, woods), or `floor`, the inside of somewhere seen with
## its roof off - flat, plain and dry, its rooms and halls the places standing on it (the author, 2026-11-23: "instead of a focus on the
## macro, we can build a board for the micro. The inside of a building, a castle, a dungeon").
const GROUNDS := ["land", "floor"]
## A floor's color when the spec says none: worn boards and flags under lamplight.
const FLOOR := "#6f6253"
## How many times flock's grain repeats a meter.
const FLOCK_SCALE := 9.0

var spec := {}
var seed_value := 0
## The ground's heights over the flat board (centimeters), one a grid point, x fastest.
var heights := PackedFloat32Array()
var nx := 0
var nz := 0
## Each place built, by name: `{node, size, at}`.
var places := {}
var _built := {}


func _init(spec_of: Dictionary, seed_of: int) -> void:
	spec = sanitize(spec_of)
	seed_value = seed_of


# --- the spec ---------------------------------------------------------------------------------------------------------

## What the model maker may write, as it is told ([DioramaTools]).
static func describe() -> String:
	return """THE BOARD is %d x %d cm, measured from its far left corner: x across to the right (0 to %d), z toward the head of the table, where the viewer sits (0 to %d). It is as big as a model railway layout, eight feet long: work all of it, edge to edge, the far corners as worked as the middle. Everything is in centimeters at model scale: a person's figure is about 4 cm tall, a cottage about 8 cm across, a castle's keep 20-30 cm high.

- `ground`: "land" (the default) - open country, hills, woods and water between the places, its ground flat flocked grass to begin with; or "floor" - the inside of somewhere, seen with its roof off: the board is one flat, dry floor (no hills, water or woods), and every room, hall, passage and stair is a place standing on it, built of its walls (low enough to see over, with gaps for its doorways), its own floor and what is in it
- `hills` [{`at` [x, z], `radius`, `height` (up to %d; negative up to -%s is a hollow, filled with water where it is deep enough), `rough` 0-1 (rocky, stony slopes)}]
- `rivers` [{`path` [[x, z], ...] (in from one edge and out at another, or into a lake), `width` (2-12), `depth` (0.6-2)}]: cut into the ground and poured with resin water
- `lakes` [{`at`, `radius`}]
- `roads` [{`path`, `width` (1-5)}]: packed earth, the way between places
- `woods` [{`at`, `radius`, `trees` (how many), `sort` (leafy, pine or dead), `tall` (a tree's height, 4-14)}]
- `colors` {`grass`, `earth`, `stone`, `road`, `water`, `floor`}: the ground's own paint, as hex, if not the usual (`floor` is the whole board's, where `ground` is "floor")
- `places` [{`name` (as the game will call it: the mill, the bridge, the old keep), `at` [x, z], `turn` (degrees about up), `line` (what it is, in a few words), and `thing` - a model built of parts, as a prop is, its base on y = 0, its front toward +z, in centimeters at this scale; its materials in the board's own `materials`}]. A bridge stands across a river; a building on a hill sits on it: the ground is made flat under each place.""" % [int(SIZE.x), int(SIZE.y), int(SIZE.x), int(SIZE.y), int(HILL_MOST), str(HOLLOW_MOST)]


## [param raw] made buildable: every list bounded, every number in range, every place's thing one a prop's sanitizing can build ([method
## Props.sanitize]) - KEPT AS WRITTEN, with its materials as written: what [method Props.sanitize] makes does not survive JSON, and made
## safe again from its own output a lathe is lost, so a thing is made safe only where it is built ([method build]).
static func sanitize(raw: Dictionary) -> Dictionary:
	var out := {"name": String(raw.get("name", "")).strip_edges().left(80)}
	var ground := String(raw.get("ground", "land")).strip_edges().to_lower()
	out["ground"] = ground if GROUNDS.has(ground) else "land"
	var inside: bool = out["ground"] == "floor"
	var hills: Array = []
	for h in _list(raw, "hills"):
		var r := clampf(_num(h, "radius", 12.0), 2.0, 100.0)
		hills.append({"at": _at(h.get("at")), "radius": r, "height": clampf(_num(h, "height", 6.0), -HOLLOW_MOST, HILL_MOST), "rough": clampf(_num(h, "rough", 0.0), 0.0, 1.0)})
	out["hills"] = hills
	var rivers: Array = []
	for r in _list(raw, "rivers"):
		var path := _path(r.get("path"))
		if path.size() >= 2:
			rivers.append({"path": path, "width": clampf(_num(r, "width", 5.0), 2.0, 12.0), "depth": clampf(_num(r, "depth", 1.2), 0.6, 2.0)})
	out["rivers"] = rivers
	var lakes: Array = []
	for l in _list(raw, "lakes"):
		lakes.append({"at": _at(l.get("at")), "radius": clampf(_num(l, "radius", 8.0), 2.0, 60.0)})
	out["lakes"] = lakes
	var roads: Array = []
	for r in _list(raw, "roads"):
		var path := _path(r.get("path"))
		if path.size() >= 2:
			roads.append({"path": path, "width": clampf(_num(r, "width", 2.5), 1.0, 5.0)})
	out["roads"] = roads
	var woods: Array = []
	for w in _list(raw, "woods"):
		var sort := String(w.get("sort", "leafy"))
		woods.append({"at": _at(w.get("at")), "radius": clampf(_num(w, "radius", 10.0), 2.0, 80.0), "trees": clampi(int(_num(w, "trees", 12.0)), 1, 240),
			"sort": sort if SORTS.has(sort) else "leafy", "tall": clampf(_num(w, "tall", 7.0), 4.0, 14.0)})
	out["woods"] = woods
	# ...a floor has none of the country's: what is in a room is built in the room
	if inside:
		for k in ["hills", "rivers", "lakes", "woods"]:
			out[k] = []
	var colors := {"grass": GRASS, "earth": EARTH, "stone": STONE, "road": ROAD, "water": WATER, "floor": FLOOR}
	var given: Dictionary = raw.get("colors", {}) if raw.get("colors") is Dictionary else {}
	for k in colors:
		if Color.html_is_valid(String(given.get(k, ""))):
			colors[k] = String(given[k])
	out["colors"] = colors
	# ...each place's thing, as a prop is made safe, and the materials they use
	var things: Array = []
	var named: Array = []
	for p in _list(raw, "places"):
		var name := String(p.get("name", "")).strip_edges().left(60)
		if name.is_empty() or named.has(name.to_lower()):
			continue
		named.append(name.to_lower())
		var t: Dictionary = (p.get("thing", {}) as Dictionary).duplicate(true) if p.get("thing") is Dictionary else {}
		# ...the model's own name is what it is, generic (it may be kept and stand on other boards); matched back by the place's below
		var generic := String(t.get("name", "")).strip_edges()
		if generic.is_empty():
			generic = String(p.get("line", "")).strip_edges() if not String(p.get("line", "")).strip_edges().is_empty() else name
		t["name"] = name
		things.append({"generic": generic.left(80), "place": {"name": name, "at": _at(p.get("at")), "turn": fposmod(_num(p, "turn", 0.0), 360.0), "line": String(p.get("line", "")).left(160),
			"library": String(p.get("library", "")).left(80)}, "thing": t})
	var mats: Dictionary = (raw.get("materials", {}) as Dictionary).duplicate(true) if raw.get("materials") is Dictionary else {}
	var safe := Props.sanitize({"things": things.map(func(d: Dictionary) -> Dictionary: return d["thing"]), "materials": mats}, [])
	var buildable := {}
	for t in safe["things"]:
		buildable[String((t as Dictionary).get("name", ""))] = true
	var list: Array = []
	for d in things:
		var place: Dictionary = d["place"]
		if buildable.has(String(place["name"])):
			place["thing"] = (d["thing"] as Dictionary).duplicate(true)
			(place["thing"] as Dictionary)["name"] = String(d["generic"])
		list.append(place)
	out["places"] = list
	out["materials"] = mats
	return out


static func _list(raw: Dictionary, key: String) -> Array:
	var out: Array = []
	for v in (raw.get(key, []) if raw.get(key) is Array else []):
		if v is Dictionary and out.size() < int(MOST[key]):
			out.append(v)
	return out


static func _num(d: Dictionary, key: String, fallback: float) -> float:
	var v: Variant = d.get(key)
	return float(v) if (v is float or v is int) else fallback


static func _at(v: Variant) -> Array:
	if v is Array and (v as Array).size() >= 2 and ((v as Array)[0] is float or (v as Array)[0] is int) and ((v as Array)[1] is float or (v as Array)[1] is int):
		return [clampf(float(v[0]), 0.0, SIZE.x), clampf(float(v[1]), 0.0, SIZE.y)]
	return [SIZE.x * 0.5, SIZE.y * 0.5]


static func _path(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for p in v:
			if out.size() < int(MOST["path"]) and p is Array and (p as Array).size() >= 2:
				# ...a path may run off the board's edge, as a river does
				out.append([clampf(float(p[0]), -10.0, SIZE.x + 10.0), clampf(float(p[1]), -10.0, SIZE.y + 10.0)])
	return out


## The board as the game's map ([GameBoard]): centimeters, no grid, its places' names.
static func board_of(diorama: Dictionary) -> Dictionary:
	var names: Array = []
	for p in diorama.get("places", []):
		names.append(String((p as Dictionary).get("name", "")))
	return {"name": String(diorama.get("name", "the board")), "size": [SIZE.x, SIZE.y], "grid": false, "unit": "cm", "model": true, "places": names}


## Where the place named [param name] stands ([x, z] centimeters), or [] where no place has that name; any case, and a leading
## "the" or not.
static func place_at(diorama: Dictionary, name: String) -> Array:
	var want := _plain(name)
	for p in diorama.get("places", []):
		if _plain(String((p as Dictionary).get("name", ""))) == want:
			return (p as Dictionary)["at"]
	return []


static func _plain(s: String) -> String:
	var t := s.strip_edges().to_lower()
	return t.trim_prefix("the ").strip_edges()


## What the board is, in words, for the one running the game: its places and where each is.
static func told(diorama: Dictionary) -> String:
	var what := "the inside of somewhere, seen with its roof off" if String(diorama.get("ground", "land")) == "floor" else "the land"
	var out := PackedStringArray(["The board is a model of %s, %d x %d cm, measured from its far left corner (x across, z toward the head of the table). A person's figure is about 4 cm tall; 1 cm is about a pace and a half in the world. Its places, each a model standing on it:" % [what, int(SIZE.x), int(SIZE.y)]])
	for p in diorama.get("places", []):
		var d: Dictionary = p
		var line := (": " + String(d["line"])) if not String(d.get("line", "")).is_empty() else ""
		out.append("- %s at [%d, %d]%s" % [String(d["name"]), roundi(float(d["at"][0])), roundi(float(d["at"][1])), line])
	for r in diorama.get("rivers", []):
		out.append("- a river, from [%d, %d] to [%d, %d]" % [roundi(float(r["path"][0][0])), roundi(float(r["path"][0][1])), roundi(float(r["path"].back()[0])), roundi(float(r["path"].back()[1]))])
	for w in diorama.get("woods", []):
		out.append("- %s woods round [%d, %d]" % [String(w["sort"]), roundi(float(w["at"][0])), roundi(float(w["at"][1]))])
	return "\n".join(out)


# --- the ground -------------------------------------------------------------------------------------------------------

## The ground's height (centimeters over the flat board) at [param x], [param z] centimeters, before any place is made flat.
func _raw_height(x: float, z: float, noise: FastNoiseLite) -> float:
	var h := 0.0
	for hl in spec["hills"]:
		var d := Vector2(x, z).distance_to(Vector2(hl["at"][0], hl["at"][1]))
		var r := float(hl["radius"])
		if d < r:
			var k := 0.5 + 0.5 * cos(PI * d / r)
			var lump := 1.0 + float(hl["rough"]) * 0.35 * noise.get_noise_2d(x * 3.1, z * 3.1)
			h += float(hl["height"]) * k * k * (3.0 - 2.0 * k) * lump
	# ...a little unevenness, all of it above the flat board, so only a cut is ever water: none on a floor, which is laid flat
	if _inside():
		return h
	h += (noise.get_noise_2d(x * 0.9, z * 0.9) * 0.5 + 0.5) * 0.35
	for rv in spec["rivers"]:
		var d := _to_path(Vector2(x, z), rv["path"])
		var half := float(rv["width"]) * 0.5
		if d < half + 2.0:
			var cut := 1.0 - smoothstep(half * 0.55, half + 2.0, d)
			h = lerpf(h, -float(rv["depth"]), cut)
	for lk in spec["lakes"]:
		var d := Vector2(x, z).distance_to(Vector2(lk["at"][0], lk["at"][1]))
		var r := float(lk["radius"])
		if d < r + 2.0:
			h = lerpf(h, -1.2, 1.0 - smoothstep(r * 0.6, r + 2.0, d))
	return h


static func _to_path(p: Vector2, path: Array) -> float:
	var best := INF
	for i in path.size() - 1:
		var a := Vector2(path[i][0], path[i][1])
		var b := Vector2(path[i + 1][0], path[i + 1][1])
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


## The ground's grid of heights, each place's ground made flat for it.
func _heights(breathe: Callable) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = hash([seed_value, "diorama"])
	noise.frequency = 0.05
	nx = int(SIZE.x / CELL) + 1
	nz = int(SIZE.y / CELL) + 1
	heights.resize(nx * nz)
	for j in nz:
		for i in nx:
			heights[j * nx + i] = _raw_height(float(i) * CELL, float(j) * CELL, noise)
		if breathe.is_valid():
			breathe.call()
	for name in places:
		var pl: Dictionary = places[name]
		var at: Vector2 = pl["at"]
		var size: AABB = pl["size"]
		var reach := maxf(size.size.x, size.size.z) * 50.0 + PAD
		var level := _grid_height(at.x, at.y)
		for j in range(maxi(0, int((at.y - reach - 2.0) / CELL)), mini(nz, int((at.y + reach + 2.0) / CELL) + 1)):
			for i in range(maxi(0, int((at.x - reach - 2.0) / CELL)), mini(nx, int((at.x + reach + 2.0) / CELL) + 1)):
				var d := Vector2(float(i) * CELL, float(j) * CELL).distance_to(at)
				var k := 1.0 - smoothstep(reach, reach + 2.0, d)
				heights[j * nx + i] = lerpf(heights[j * nx + i], maxf(level, 0.0), k)
		pl["level"] = maxf(level, 0.0)


func _grid_height(x: float, z: float) -> float:
	if heights.is_empty():
		return 0.0
	var fx := clampf(x / CELL, 0.0, float(nx - 1))
	var fz := clampf(z / CELL, 0.0, float(nz - 1))
	var i := mini(int(fx), nx - 2)
	var j := mini(int(fz), nz - 2)
	var u := fx - float(i)
	var v := fz - float(j)
	var a := lerpf(heights[j * nx + i], heights[j * nx + i + 1], u)
	var b := lerpf(heights[(j + 1) * nx + i], heights[(j + 1) * nx + i + 1], u)
	return lerpf(a, b, v)


## The board's far left corner on the table (meters).
static func corner() -> Vector2:
	return GameBoard.MIDDLE - SIZE * 0.005


## Where [param at] (centimeters on the board) is on the table (meters).
static func world_of(at: Vector2) -> Vector2:
	return corner() + at * 0.01


## What stands on the ground at [param x], [param z] (meters, the table's own): the ground's top, or the water's where it is
## under it. Off the board, the table's.
func height_at(x: float, z: float) -> float:
	var at := (Vector2(x, z) - corner()) * 100.0
	if at.x < 0.0 or at.y < 0.0 or at.x > SIZE.x or at.y > SIZE.y:
		return 0.0
	return (BOARD_H + maxf(_grid_height(at.x, at.y), -WATER_DOWN)) * 0.01


# --- building -------------------------------------------------------------------------------------------------------------

## The board built: its ground, its water, its woods and its places, under one node (meters, standing on the table). Safe on a
## worker: nothing here needs the tree. [param breathe] is called now and then in its long loops.
func build(breathe := Callable()) -> Node3D:
	var root := Node3D.new()
	root.name = "Diorama"
	for p in spec["places"]:
		var d: Dictionary = p
		if not (d.get("thing") is Dictionary):
			continue
		# ...made safe here, from the thing as written (never from a sanitized one read back)
		var safe := Props.sanitize({"things": [d["thing"]], "materials": spec["materials"]}, [])
		if (safe["things"] as Array).is_empty():
			continue
		var b := Props.build((safe["things"] as Array)[0], safe["materials"], hash([seed_value, String(d["name"]), "place"]))
		places[String(d["name"])] = {"node": b["node"], "size": b["size"], "at": Vector2(d["at"][0], d["at"][1]), "turn": float(d["turn"])}
	_heights(breathe)
	root.add_child(_ground_mesh())
	if not _inside():
		root.add_child(_water_mesh())
	var woods := _woods(breathe)
	if woods != null:
		root.add_child(woods)
	for name in places:
		var pl: Dictionary = places[name]
		var n: Node3D = pl["node"]
		var w := world_of(pl["at"])
		n.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(pl["turn"]))), Vector3(w.x, (BOARD_H + float(pl.get("level", 0.0))) * 0.01, w.y))
		n.name = String(name).validate_node_name()
		root.add_child(n)
	return root


## Whether the board is the inside of somewhere ([constant GROUNDS]).
func _inside() -> bool:
	return String(spec.get("ground", "land")) == "floor"


func _color(key: String) -> Color:
	return Color.from_string(String((spec["colors"] as Dictionary).get(key, "#808080")), Color.GRAY)


func _ground_mesh() -> MeshInstance3D:
	var noise := FastNoiseLite.new()
	noise.seed = hash([seed_value, "flock"])
	noise.frequency = 0.09
	var grass := _color("grass")
	var dry := grass.lerp(Color("#a59a5a"), 0.45)
	var earth := _color("earth")
	var stone := _color("stone")
	var road := _color("road")
	var floor := _color("floor")
	var inside := _inside()
	var bed := Color(BED)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c0 := corner()
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(nx * nz)
	cols.resize(nx * nz)
	for j in nz:
		for i in nx:
			var x := float(i) * CELL
			var z := float(j) * CELL
			var h := heights[j * nx + i]
			var gx := (heights[j * nx + mini(i + 1, nx - 1)] - heights[j * nx + maxi(i - 1, 0)]) / (2.0 * CELL)
			var gz := (heights[mini(j + 1, nz - 1) * nx + i] - heights[maxi(j - 1, 0) * nx + i]) / (2.0 * CELL)
			var slope := Vector2(gx, gz).length()
			var patch := noise.get_noise_2d(x, z) * 0.5 + 0.5
			var c := grass.lerp(dry, smoothstep(0.55, 0.85, patch) * 0.8 + clampf(h / HILL_MOST, 0.0, 1.0) * 0.3)
			# ...a floor is its own paint, worn a little paler where feet go and darker in the corners of the years
			if inside:
				c = floor.lerp(floor.lightened(0.12), smoothstep(0.45, 0.9, patch) * 0.6).lerp(floor.darkened(0.15), smoothstep(0.4, 0.05, patch) * 0.5)
			c = c.lerp(stone, smoothstep(0.55, 1.1, slope))
			for hl in spec["hills"]:
				if float(hl["rough"]) > 0.0 and Vector2(x, z).distance_to(Vector2(hl["at"][0], hl["at"][1])) < float(hl["radius"]) * 0.8:
					c = c.lerp(stone, float(hl["rough"]) * smoothstep(0.25, 0.6, slope + patch * 0.3))
			if h < 0.1 and not inside:
				c = c.lerp(earth, smoothstep(0.1, -0.3, h))
			if h < -WATER_DOWN:
				c = c.lerp(bed, 0.8)
			for rd in spec["roads"]:
				var d := _to_path(Vector2(x, z), rd["path"])
				var half := float(rd["width"]) * 0.5
				if d < half + 0.6 and h > -0.2:
					c = c.lerp(road, (1.0 - smoothstep(half - 0.4, half + 0.6, d)) * (0.85 + patch * 0.15))
			# ...flock is never one flat color: a fleck of light and dark in every cell
			var fleck := fposmod(sin(float(i) * 12.9898 + float(j) * 78.233) * 43758.5453, 1.0)
			c = c.darkened(0.06 * fleck) if fleck < 0.5 else c.lightened(0.05 * (fleck - 0.5))
			var w := c0 + Vector2(x, z) * 0.01
			verts[j * nx + i] = Vector3(w.x, (BOARD_H + h) * 0.01, w.y)
			cols[j * nx + i] = c
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			for k in [a, a + 1, a + nx, a + 1, a + nx + 1, a + nx]:
				st.set_color(cols[k])
				st.add_vertex(verts[k])
	# ...the board's edge, from the ground's own edge down to the table: painted as a modeler paints one
	var edge := Color(EDGE)
	var rim: Array = []
	for i in nx:
		rim.append(i)
	for j in range(1, nz):
		rim.append(j * nx + nx - 1)
	for i in range(nx - 2, -1, -1):
		rim.append((nz - 1) * nx + i)
	for j in range(nz - 2, 0, -1):
		rim.append(j * nx)
	rim.append(0)
	for k in rim.size() - 1:
		var a: Vector3 = verts[rim[k]]
		var b: Vector3 = verts[rim[k + 1]]
		var a0 := Vector3(a.x, 0.0, a.z)
		var b0 := Vector3(b.x, 0.0, b.z)
		for v in [a, b0, b, a, a0, b0]:
			st.set_color(edge)
			st.add_vertex(v)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.97
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# ...a floor is dry and plain, and catches the lamps a little: no flock on it
	if inside:
		mat.roughness = 0.82
		mesh.material_override = mat
		mesh.name = "Ground"
		return mesh
	# ...flock: a fine grain of light and dark over every color, and its own little bumps for the light to catch, seen close
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * FLOCK_SCALE
	mat.detail_enabled = true
	mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
	mat.detail_albedo = _flock_texture(false)
	mat.normal_enabled = true
	mat.normal_scale = 0.6
	mat.normal_texture = _flock_texture(true)
	mesh.material_override = mat
	mesh.name = "Ground"
	return mesh


## Flock's grain as a texture: bright where it is fine and loose, darker in its clumps; or the same as bumps ([param bumps]).
func _flock_texture(bumps: bool) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = hash([seed_value, "flock grain"])
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.09
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = n
	if bumps:
		tex.as_normal_map = true
		tex.bump_strength = 6.0
	else:
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.72, 0.72, 0.7))
		ramp.set_color(1, Color(1.0, 1.0, 0.98))
		tex.color_ramp = ramp
	return tex


## The resin: one flat sheet a little under the flat ground, seen only where the ground is cut deeper than it.
func _water_mesh() -> MeshInstance3D:
	var quad := PlaneMesh.new()
	quad.size = SIZE * 0.01 - Vector2(0.002, 0.002)
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.position = Vector3(GameBoard.MIDDLE.x, (BOARD_H - WATER_DOWN) * 0.01, GameBoard.MIDDLE.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color("water")
	mat.roughness = 0.06
	mat.metallic_specular = 0.8
	mat.clearcoat_enabled = true
	mat.clearcoat = 1.0
	mesh.material_override = mat
	mesh.name = "Water"
	return mesh


## Every wood's trees: a model railway's - a trunk and clumps of flock - one mesh drawn many times, each its own size, turn and shade.
func _woods(breathe: Callable) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "woods"])
	var by_sort := {}
	var count := 0
	for w in spec["woods"]:
		var d: Dictionary = w
		var list: Array = by_sort.get(String(d["sort"]), [])
		for k in int(d["trees"]):
			if count >= TREES_MOST:
				break
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * float(d["radius"])
			var at := Vector2(d["at"][0], d["at"][1]) + Vector2(cos(a), sin(a)) * r
			if at.x < 1.0 or at.y < 1.0 or at.x > SIZE.x - 1.0 or at.y > SIZE.y - 1.0:
				continue
			var h := _grid_height(at.x, at.y)
			if h < 0.0 or _on_way(at) or _under_place(at):
				continue
			var tall := float(d["tall"]) * rng.randf_range(0.75, 1.25)
			var shade := rng.randf_range(0.8, 1.15)
			list.append({"at": at, "h": h, "tall": tall, "turn": rng.randf() * TAU, "shade": shade})
			count += 1
		by_sort[String(d["sort"])] = list
		if breathe.is_valid():
			breathe.call()
	if count == 0:
		return null
	var root := Node3D.new()
	root.name = "Woods"
	for sort in by_sort:
		var list: Array = by_sort[sort]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _tree_mesh(String(sort))
		mm.instance_count = list.size()
		for k in list.size():
			var t: Dictionary = list[k]
			var w := world_of(t["at"])
			var s := float(t["tall"]) * 0.01
			mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, float(t["turn"])).scaled(Vector3.ONE * s), Vector3(w.x, (BOARD_H + float(t["h"])) * 0.01, w.y)))
			mm.set_instance_color(k, Color(float(t["shade"]), float(t["shade"]), float(t["shade"]) * 0.95))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.95
		mmi.material_override = mat
		root.add_child(mmi)
	return root


func _on_way(at: Vector2) -> bool:
	for rd in spec["roads"]:
		if _to_path(at, rd["path"]) < float(rd["width"]) * 0.5 + 0.8:
			return true
	for rv in spec["rivers"]:
		if _to_path(at, rv["path"]) < float(rv["width"]) * 0.5 + 1.0:
			return true
	return false


func _under_place(at: Vector2) -> bool:
	for name in places:
		var pl: Dictionary = places[name]
		var size: AABB = pl["size"]
		if at.distance_to(pl["at"]) < maxf(size.size.x, size.size.z) * 50.0 + PAD:
			return true
	return false


## One tree a unit tall (scaled to its height where it stands): its trunk and its crown, colored by its vertices.
static func _tree_mesh(sort: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color("#4a3a2a")
	var trunk_top := 0.45 if sort == "leafy" else (0.25 if sort == "pine" else 0.9)
	_cone(st, Vector3.ZERO, 0.045, 0.025, trunk_top, 6, bark)
	match sort:
		"pine":
			var green := Color("#2f4a2a")
			for k in 4:
				var y := 0.2 + float(k) * 0.18
				_cone(st, Vector3(0, y, 0), 0.3 - float(k) * 0.06, 0.02, 0.32, 8, green.lightened(float(k) * 0.05))
		"dead":
			for k in 4:
				var a := float(k) * 1.7
				_cone(st, Vector3(0, 0.45 + float(k) * 0.1, 0), 0.018, 0.005, 0.0, 4, bark, Vector3(cos(a) * 0.22, 0.25, sin(a) * 0.22))
		_:
			var leaf := Color("#4c6b30")
			var lumps := [[Vector3(0, 0.62, 0), 0.3], [Vector3(0.14, 0.52, 0.06), 0.22], [Vector3(-0.12, 0.55, -0.08), 0.22], [Vector3(0.02, 0.8, 0.03), 0.2]]
			for k in lumps.size():
				_lump(st, lumps[k][0], lumps[k][1], leaf.lightened(0.04 * float(k)), k)
	st.generate_normals()
	return st.commit()


## A cone (or a stick, leaning by [param lean]) from [param base], [param r0] wide there and [param r1] at its top.
static func _cone(st: SurfaceTool, base: Vector3, r0: float, r1: float, tall: float, sides: int, c: Color, lean := Vector3.ZERO) -> void:
	var top := base + (Vector3(0, tall, 0) if lean == Vector3.ZERO else lean)
	for s in sides:
		var a0 := TAU * float(s) / float(sides)
		var a1 := TAU * float(s + 1) / float(sides)
		var p0 := base + Vector3(cos(a0), 0, sin(a0)) * r0
		var p1 := base + Vector3(cos(a1), 0, sin(a1)) * r0
		var q0 := top + Vector3(cos(a0), 0, sin(a0)) * r1
		var q1 := top + Vector3(cos(a1), 0, sin(a1)) * r1
		for v in [p0, q0, p1, p1, q0, q1]:
			st.set_color(c)
			st.add_vertex(v)


## A clump of flock: a lumpy ball.
static func _lump(st: SurfaceTool, mid: Vector3, r: float, c: Color, k: int) -> void:
	var rings := 6
	var segs := 9
	var pts: Array = []
	for i in rings + 1:
		var row: Array = []
		var phi := PI * float(i) / float(rings)
		for j in segs:
			var th := TAU * float(j) / float(segs)
			var bump := 1.0 + 0.16 * sin(th * 3.0 + float(k)) * sin(phi * 2.0 + float(k) * 0.7)
			row.append(mid + Vector3(sin(phi) * cos(th), cos(phi) * 0.8, sin(phi) * sin(th)) * r * bump)
		pts.append(row)
	for i in rings:
		for j in segs:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][(j + 1) % segs]
			var cc: Vector3 = pts[i + 1][j]
			var d: Vector3 = pts[i + 1][(j + 1) % segs]
			var shade := c.darkened(0.25 * float(i) / float(rings))
			for v in [a, b, cc, b, d, cc]:
				st.set_color(shade)
				st.add_vertex(v)


# --- what dice meet, and what the model maker is shown ------------------------------------------------------------------

## The board as what a die bounces off: its box, as triangles (meters), as [method TableGame._solids] hands them.
static func solid() -> Dictionary:
	var c := corner()
	var lo := Vector3(c.x, 0.0, c.y)
	var hi := Vector3(c.x + SIZE.x * 0.01, BOARD_H * 0.01, c.y + SIZE.y * 0.01)
	var p := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	var quads := [[4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
	var faces := PackedVector3Array()
	for q in quads:
		for k in [0, 1, 2, 0, 2, 3]:
			faces.append(p[q[k]])
	return {"faces": faces}


## The board drawn from straight above as a plan ([param px] pixels across): the ground's colors and shading, and each place
## a dot. For the model maker's look; worked on a worker.
func plan_image(px := 780) -> Image:
	if heights.is_empty():
		for p in spec["places"]:
			if (p as Dictionary).get("thing") is Dictionary and not places.has(String(p["name"])):
				places[String(p["name"])] = {"node": null, "size": _guess_size(p["thing"]), "at": Vector2(p["at"][0], p["at"][1]), "turn": float(p["turn"])}
		_heights(Callable())
	var w := px
	var h := int(float(px) * SIZE.y / SIZE.x)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var grass := _color("grass")
	var water := _color("water")
	var road := _color("road")
	for y in h:
		for x in w:
			var cx := float(x) / float(w) * SIZE.x
			var cz := float(y) / float(h) * SIZE.y
			var ht := _grid_height(cx, cz)
			var c := grass.lerp(Color("#d8cf9a"), clampf(ht / HILL_MOST, 0.0, 1.0))
			var e := _grid_height(cx - 0.6, cz - 0.6) - ht
			c = c.lightened(clampf(e * 0.25, 0.0, 0.3)) if e > 0.0 else c.darkened(clampf(-e * 0.25, 0.0, 0.35))
			if ht < -WATER_DOWN:
				c = water
			img.set_pixel(x, y, c)
	for rd in spec["roads"]:
		_stroke(img, rd["path"], float(rd["width"]), road)
	for wd in spec["woods"]:
		_disc(img, Vector2(wd["at"][0], wd["at"][1]), float(wd["radius"]), Color("#2c4422"), 0.55)
	for p in spec["places"]:
		_disc(img, Vector2(p["at"][0], p["at"][1]), 2.4, Color("#c0392b"), 1.0)
	# ...a line every 10 cm, for measuring by
	for x in range(0, int(SIZE.x) + 1, 10):
		for y in h:
			var px_x := mini(int(float(x) / SIZE.x * float(w)), w - 1)
			img.set_pixel(px_x, y, img.get_pixel(px_x, y).darkened(0.35))
	for z in range(0, int(SIZE.y) + 1, 10):
		for x in w:
			var px_y := mini(int(float(z) / SIZE.y * float(h)), h - 1)
			img.set_pixel(x, px_y, img.get_pixel(x, px_y).darkened(0.35))
	return img


static func _guess_size(thing: Dictionary) -> AABB:
	var r := 4.0
	for p in thing.get("parts", []):
		var s: Variant = (p as Dictionary).get("size")
		if s is Array and (s as Array).size() >= 3:
			r = maxf(r, maxf(float(s[0]), float(s[2])))
		r = maxf(r, float((p as Dictionary).get("radius", 0.0)) * 2.0)
	return AABB(Vector3.ZERO, Vector3(r, r, r) * 0.01)


static func _disc(img: Image, at: Vector2, r: float, c: Color, a: float) -> void:
	var k := float(img.get_width()) / SIZE.x
	var mid := at * k
	var rp := r * k
	for y in range(maxi(0, int(mid.y - rp)), mini(img.get_height(), int(mid.y + rp) + 1)):
		for x in range(maxi(0, int(mid.x - rp)), mini(img.get_width(), int(mid.x + rp) + 1)):
			if Vector2(x, y).distance_to(mid) <= rp:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(c, a))


static func _stroke(img: Image, path: Array, width: float, c: Color) -> void:
	for i in path.size() - 1:
		var a := Vector2(path[i][0], path[i][1])
		var b := Vector2(path[i + 1][0], path[i + 1][1])
		var n := maxi(int(a.distance_to(b) / 0.8), 1)
		for s in n + 1:
			_disc(img, a.lerp(b, float(s) / float(n)), width * 0.5, c, 0.9)
