extends RefCounted
class_name Tables

## Tables - THE TABLE ITSELF, BUILT FROM A DESCRIPTION. Its TOP: an outline (a rectangle, round, an
## oval, a many-sided polygon, its rim scalloped if it likes), a thickness, the profile its edge is
## cut to (bevel, bullnose, ogee...), and what it is made of - boards of a wood, a slab of stone,
## metal, lacquer, leather, tiles, a baize, or the episode's own painting - with a pattern inlaid in
## it and a band along its edge if it has them. Over it, its LAYERS from the bottom up: a tablecloth,
## a runner, a square laid as a diamond, a mat under the cards - each a FABRIC woven in a PATTERN
## (stripes, checks, a plaid, diamonds, dots, a medallion, dyed clouds, ikat, or the painting), with
## a border along its hem and a fringe on its ends if it has them. Every surface has a RELIEF - its
## threads or grain, its figures raised or sunk, quilting, tufting, the painting's own detail - a
## height field the shaders see by slope, parallax and shade (`shaders/table_common.gdshaderinc`).
##
## Built 2026-10-06 (the user: "right now, the table is just a flat rectangular surface, with a
## texture crudely drawn onto it... give the agents the proper tools and instructions to construct
## their own table, with optional tapestries, tablecloths, runners"; and "the table would really
## benefit from some depth mapping"). As [Props] and [Effects] are: registries whose words are what
## the agent reads ([method describe]), [method sanitize] (whatever it wrote, buildable) and
## [method build]. The set dresser writes `top` and `layers` beside its things in `table.json`; a
## table with neither is the table every episode had before - a 190 x 85 cm board table, the painting
## laid on it as a 120 x 72 cm cloth ([constant DEFAULT_TOP], [method default_layers]).
##
## THE TOP HOLDS THE CARDS: the deck, the spread, the shuffle and the wash all lie within [constant
## HOLDS], and a top that would not hold it [constant EDGE] in from its edge is made larger, its
## proportions kept - a round table is at least ~1.2 m across. Things stand on the top [constant
## THING_EDGE] in from its edge ([method inside]). A layer that runs past the edge HANGS OVER IT as
## cloth does - rolled over the edge, straight down, its hem in folds ([method _drape]) - real
## geometry; the relief is not (lifting the surface would lift the cards off it, or sink them in).
##
## SPACE: a description is in centimeters, x to the reader's right and z toward the reader, from the
## middle of the reading - where the cards are dealt, [constant ORIGIN] on the table; the top's own
## middle is [constant TOP_AT] from it. Built in meters, in the table medium's own space.

## The middle of the reading on the table (x, z meters): a layer's `at` is from here.
const ORIGIN := Vector2(0.0, -0.02)
## The top's middle, from [constant ORIGIN] (meters): where the table has always stood.
const TOP_AT := Vector2(0.0, 0.04)
## Where the cards go - the deck at its side, the spread, the shuffle, the wash - from [constant
## ORIGIN] (meters): every top holds it.
const HOLDS := Rect2(-0.42, -0.33, 0.84, 0.58)
## How far inside the top's edge the cards stay, and the things (meters).
const EDGE := 0.02
## (3.5 cm: on the old table that leaves things exactly the stretch of the old cloth they had - at 4 cm
## its back edge came 0.6 mm forward, and every placement drawn after it moved)
const THING_EDGE := 0.035
## The sizes a top may be, centimeters (width, depth), and its thickness.
const TOP_MIN := Vector2(60.0, 50.0)
const TOP_MAX := Vector2(260.0, 180.0)
const THICK := Vector2(1.5, 9.0)
## The most layers, and how high each lies over the one under it (meters): all of them under
## [constant LAYERS_UNDER], where a card lying on the table rests ([constant TableMedium.CLOTH_TOP]).
const MAX_LAYERS := 4
const LAYER_FLOOR := 0.0002
const LAYER_GAP := 0.00012
const LAYERS_UNDER := 0.0006
## The most a cloth hangs below the top (meters): it reaches the floor.
const DROP_MOST := 0.7
## How finely a top's face and a layer are cut into triangles (meters), and how many rays find an
## outline's edge.
const TOP_STEP := 0.05
const LAYER_STEP := 0.025
const RAYS := 160
## The deepest relief anything may ask for, millimeters.
const RELIEF_MOST := 6.0

const SHAPES := {
	"rect": "a rectangle, `size` [width, depth]; `corner` rounds its corners (cm)",
	"round": "a circle, `size` [diameter]",
	"oval": "an ellipse, `size` [width, depth]",
	"polygon": "a regular polygon of `sides` 5-12 (8 is an octagon) in `size` [width, depth], a flat side toward the reader",
}

## THE PROFILE A TOP'S EDGE IS CUT TO - the edge is all of the table's side the camera sees: it looks
## down across the top, and its far edge stands against the room.
const EDGES := {
	"square": "cut straight down, its corner barely eased",
	"eased": "its top corner rounded over",
	"bevel": "a broad 45-degree chamfer",
	"bullnose": "a full half-round",
	"ogee": "an S-curve, the molded edge of a fine table",
	"bead": "a small round bead along the top, stepped in below it",
}

## THE FABRICS a layer is woven in, with their shader codes and their threads' depth (mm).
const FABRICS := {
	"linen": {"code": 1, "depth": 0.25, "about": "linen: a little uneven, matte"},
	"cotton": {"code": 2, "depth": 0.15, "about": "cotton: fine and plain"},
	"wool": {"code": 3, "depth": 0.35, "about": "woolen cloth, a little fuzzy: a blanket, a kilim, a tartan"},
	"felt": {"code": 4, "depth": 0.12, "about": "felt or baize: no weave, a soft fuzz"},
	"velvet": {"code": 5, "depth": 0.1, "about": "velvet: deep, darker seen straight on, its pile catching the light at the edges"},
	"silk": {"code": 6, "depth": 0.03, "about": "silk or satin: smooth, its light drawn out along the threads"},
	"brocade": {"code": 7, "depth": 0.2, "about": "brocade: the pattern's figures woven in lustrous metallic thread on a satin ground"},
	"lace": {"code": 8, "depth": 0.2, "about": "lace: a net of holes the layer under it shows through, whole along its hem"},
	"burlap": {"code": 9, "depth": 0.8, "about": "burlap or jute: coarse, open, rough"},
}

## THE PATTERNS a layer is woven in, or a top inlaid with, with their shader codes.
const PATTERNS := {
	"plain": {"code": 0, "about": "one color, the first of `colors`"},
	"stripes": {"code": 1, "about": "bands `scale` cm wide, each of `colors` in turn"},
	"checks": {"code": 2, "about": "a gingham: stripes of two colors `scale` cm wide crossing, the first where they cross"},
	"plaid": {"code": 3, "about": "a tartan: bands of `colors`, each its own width round `scale`, crossing in a twill"},
	"diamonds": {"code": 4, "about": "a harlequin of lozenges `scale` cm across, `colors` in turn - parquetry on a top"},
	"dots": {"code": 5, "about": "dots of the other `colors` on the first, `scale` cm apart"},
	"medallion": {"code": 6, "about": "a round design in the middle - rings of petals, rays and beads in `colors`, `count`-fold (4-24) - the ground beyond: a rug's, an altar cloth's, a marquetry rose's"},
	"clouds": {"code": 7, "about": "soft blots of `colors` melting into each other, `scale` cm across: batik, tie-dye, marbling"},
	"ikat": {"code": 8, "about": "stripes `scale` cm wide whose edges are feathered and stepped, as resist-dyed threads are"},
	"painting": {"code": 9, "about": "THE PAINTING (attached): the episode's own surface, laid over the whole of it"},
}

## THE RELIEF a surface has - its depth, which the low light rakes - with the shader's codes.
const RELIEFS := {
	"none": {"code": 0, "about": "flat"},
	"natural": {"code": 1, "about": "the material's own alone - a weave's threads, a wood's grain, a leather's pebble, the seams between boards and tiles; `depth` sets how deep (every surface has it unless none)"},
	"raised": {"code": 2, "about": "the pattern's figures and the border stand proud: brocade, embroidery, an embossed or carved design"},
	"sunk": {"code": 3, "about": "the figures and the border cut in: engraving, tooling, an incised or carved design"},
	"quilted": {"code": 4, "about": "stitched along a diamond lattice `scale` cm across, puffed between the stitches"},
	"tufted": {"code": 5, "about": "a button pulled down into a dimple every `scale` cm, puffed round it"},
	"painting": {"code": 6, "about": "the painting's own detail - its threads, grain, carving - as depth; `invert` true when its dark parts are what stands up"},
}

## How a top's material looks in the top's shader ([constant Props.MATERIALS]' codes): the kinds a top
## is made of, the rest drawn as paint of their color. And their own relief's depth, mm.
const TOP_KINDS := {"wood": 7, "stone": 6, "crystal": 6, "metal": 1, "ceramic": 5, "leather": 9, "fabric": 10, "painted": 0}
const TOP_DEPTH := {"wood": 0.35, "stone": 0.3, "crystal": 0.2, "metal": 0.25, "ceramic": 0.05, "leather": 0.3,
	"fabric": 0.3, "painted": 0.1, "painting": 0.0}

## THE TABLE EVERY EPISODE HAD BEFORE: boards of a dark wood, its painting laid on it as a cloth.
const DEFAULT_TOP := {"shape": "rect", "size": [190.0, 85.0], "thickness": 5.0, "edge": "eased", "material": "the table's wood",
	"boards": {"width": 18.0, "turn": 0.0}}
const DEFAULT_WOOD := {"kind": "wood", "color": "#5c3821", "color2": "#3a2213", "polish": 0.45, "pattern": 0.55, "grain": 1.4}

const _TOP_SHADER := preload("res://shaders/table_top.gdshader")
const _TEXTILE_SHADER := preload("res://shaders/table_textile.gdshader")


## THE VOCABULARY, as the set dresser reads it.
static func describe() -> String:
	var lines := PackedStringArray()
	lines.append("THE TOP (`top`): {\"shape\", \"size\", \"corner\", \"sides\", \"scallops\", \"thickness\", \"edge\", \"material\", \"boards\", \"tiles\", \"pattern\", \"inlay\", \"relief\", \"why\"} - centimeters.")
	lines.append("- shape:")
	for k in SHAPES:
		lines.append("  - %s: %s" % [k, SHAPES[k]])
	lines.append("  `scallops` 12-48 cuts a round, oval or polygonal rim into that many scallops - a piecrust table.")
	lines.append("- size: %d to %d cm across, %d to %d deep. The cards need a stretch about %d x %d cm in the middle: a top too small to hold it is made larger, its proportions kept (a round table comes out at least %d cm across)." % [
		int(TOP_MIN.x), int(TOP_MAX.x), int(TOP_MIN.y), int(TOP_MAX.y), roundi(HOLDS.size.x * 100.0) + 4, roundi(HOLDS.size.y * 100.0) + 4,
		roundi(_least_round() * 100.0)])
	lines.append("- thickness: %d to %d cm. edge, the profile it is cut to (what the camera sees of the table's side):" % [int(THICK.x), int(THICK.y)])
	for k in EDGES:
		lines.append("  - %s: %s" % [k, EDGES[k]])
	lines.append("- material: the name of one of `materials` (wood, stone, metal, ceramic, leather, fabric for a baize, or painted lacquer - its color, color2, polish, wear, pattern and grain as for a thing), or \"painting\": the painting itself is the top, as boards or a slab it shows.")
	lines.append("- boards: {\"width\", \"turn\"} - the top made of boards that wide, running side to side (turn 0) or front to back (90), their ends staggered and their seams cut in. tiles: {\"size\", \"grout\": \"#rrggbb\"} - laid in square tiles.")
	lines.append("- pattern: inlaid in the top - marquetry, parquetry, a painted chessboard - as a layer's pattern is (below), taking the material's own grain. inlay: {\"width\", \"inset\", \"color\"} - a band of another wood, stone or metal along the edge, `inset` in from it.")
	lines.append("")
	lines.append("THE LAYERS (`layers`, from the bottom up, at most %d - or none: a bare top): each {\"name\", \"what\", \"outline\", \"size\", \"sides\", \"drop\", \"at\", \"turn\", \"fabric\", \"pattern\", \"border\", \"fringe\", \"relief\", \"sheen\"}." % MAX_LAYERS)
	lines.append("- what: a few words - a tablecloth, a runner, an altar cloth laid as a diamond, a reading mat, a tapestry. outline: rect, round, oval or polygon (with `sides`) at `size` [width, depth] - width side to side and depth front to back, before it is turned - or \"top\": the top's own outline, hanging `drop` cm over its edge all round - a tablecloth.")
	lines.append("- at [x, z]: its middle, from the middle of the reading (where the cards are dealt). turn: degrees - 0 square to the table, 45 a square laid as a diamond, 90 a runner of [200, 40] laid front to back instead of side to side. Wherever a layer runs past the top's edge it hangs over it, in folds.")
	lines.append("- fabric:")
	for k in FABRICS:
		lines.append("  - %s: %s" % [k, String((FABRICS[k] as Dictionary)["about"])])
	lines.append("- pattern: {\"kind\", \"colors\": [\"#rrggbb\", ... up to 6], \"scale\" (cm), \"turn\" (degrees), \"count\"}:")
	for k in PATTERNS:
		lines.append("  - %s: %s" % [k, String((PATTERNS[k] as Dictionary)["about"])])
	lines.append("- border: {\"width\", \"inset\", \"color\"} - a band along its hem. fringe: cm of tassels on its two ends (left and right before it is turned; a rect only). sheen 0-1: velvet's or silk's light.")
	lines.append("")
	lines.append("RELIEF - the depth of a surface, which the low light rakes. The top and every layer take `relief`: {\"kind\", \"depth\" (mm, up to %d), \"scale\" (cm), \"invert\"}:" % int(RELIEF_MOST))
	for k in RELIEFS:
		lines.append("- %s: %s" % [k, String((RELIEFS[k] as Dictionary)["about"])])
	lines.append("The relief lies below the surface: the cards and the things rest on its highest points. A millimeter reads plainly in this light; a quilt or a carving takes 2 to 4.")
	return "\n".join(lines)


## The least diameter a round top holds the cards at (meters).
static func _least_round() -> float:
	var r := 0.0
	for c in [HOLDS.position, Vector2(HOLDS.end.x, HOLDS.position.y), HOLDS.end, Vector2(HOLDS.position.x, HOLDS.end.y)]:
		r = maxf(r, ((c as Vector2) - TOP_AT).length())
	return (r + EDGE) * 2.0


# --- made safe ------------------------------------------------------------------------------------

## THE TABLE MADE SAFE: [param top] and [param layers] as the set dresser wrote them (either may be
## missing: no `top` is [constant DEFAULT_TOP]; no `layers` is [method default_layers], `[]` a bare
## top), every key the builder reads present, every number in range, every name one it knows, and the
## top grown to hold the cards. [param materials] are the table's materials, made safe by [Props]
## (the top names one); [param palette] fills the colors left out. What had to change is said in
## [param notes], for the set dresser.
static func sanitize(top: Variant, layers: Variant, materials: Dictionary, palette: Array,
		notes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var pal: Array = palette if not palette.is_empty() else ["#3a2a20", "#c9a227", "#e8dcc0"]
	var t := _sanitize_top(top if top is Dictionary else DEFAULT_TOP, materials, pal, notes)
	var ls: Array = []
	if layers == null:
		ls = default_layers()
	elif layers is Array:
		for l in layers:
			if not (l is Dictionary):
				notes.append("a layer that was not an object {name, outline, ...} was left out")
				continue
			if ls.size() >= MAX_LAYERS:
				notes.append("only %d layers are laid: \"%s\" and any after it were left out" % [MAX_LAYERS, Props._text((l as Dictionary).get("name", ""), 60)])
				break
			ls.append(_sanitize_layer(l as Dictionary, ls.size(), pal, notes))
	else:
		ls = default_layers()
	return {"top": t, "layers": ls}


## The cloth every table had before: the painting, 120 x 72 cm, under the reading.
static func default_layers() -> Array:
	return [_sanitize_layer({"name": "the cloth", "what": "the reading cloth", "outline": "rect", "size": [120.0, 72.0],
		"fabric": "cotton", "pattern": {"kind": "painting"}}, 0, [], PackedStringArray())]


static func _sanitize_top(t: Dictionary, materials: Dictionary, pal: Array, notes: PackedStringArray) -> Dictionary:
	var shape := String(t.get("shape", "rect")).strip_edges().to_lower() if t.get("shape") is String else "rect"
	if shape in ["circle", "circular"]:
		shape = "round"
	if shape in ["rectangle", "rectangular", "square"]:
		shape = "rect"
	if shape in ["octagon", "hexagon"]:
		shape = "polygon"
	if not SHAPES.has(shape):
		notes.append("the top's shape \"%s\" is not one of %s: it is a rect" % [str(t.get("shape", "")), ", ".join(SHAPES.keys())])
		shape = "rect"
	var size := _size2(t.get("size"), Vector2(190.0, 85.0))
	if shape == "round":
		size = Vector2(size.x, size.x)
	size = size.clamp(TOP_MIN, TOP_MAX) if shape != "round" else Vector2.ONE * clampf(size.x, TOP_MIN.y, TOP_MAX.y)
	var sides := int(Props._num(t.get("sides"), 8.0 if String(t.get("shape", "")) != "hexagon" else 6.0, 5.0, 12.0))
	var out := {"shape": shape, "size": [size.x, size.y], "sides": sides,
		"corner": Props._num(t.get("corner"), 0.0, 0.0, minf(size.x, size.y) * 0.5),
		"scallops": int(Props._num(t.get("scallops"), 0.0, 0.0, 48.0)) if shape != "rect" else 0,
		"thickness": Props._num(t.get("thickness"), 4.0, THICK.x, THICK.y),
		"edge": _key(t.get("edge"), EDGES, "eased"), "why": Props._text(t.get("why", ""), 200)}
	if int(out["scallops"]) > 0 and int(out["scallops"]) < 12:
		out["scallops"] = 12
	# THE MATERIAL: one of the table's, by name - or the painting
	var mname := Props._text(t.get("material", ""), 80)
	if mname.to_lower() == "painting" or mname.to_lower() == "the painting":
		out["material"] = "painting"
		out["look"] = {"kind": "painting", "color": String(pal[0]), "color2": String(pal[0]), "polish": 0.3, "wear": 0.0,
			"pattern": 0.0, "grain": 1.0}
	elif materials.has(mname):
		out["material"] = mname
		out["look"] = (materials[mname] as Dictionary).duplicate()
	else:
		if not mname.is_empty() and mname != String(DEFAULT_TOP["material"]):
			notes.append("the top's material \"%s\" is not among the materials: it is a dark wood" % mname)
		out["material"] = String(DEFAULT_TOP["material"])
		out["look"] = Props.sanitize_material(DEFAULT_WOOD, "#5c3821")
	var kind := String((out["look"] as Dictionary).get("kind", "painted"))
	var b: Dictionary = t.get("boards", {}) if t.get("boards") is Dictionary else {}
	out["boards"] = {"width": Props._num(b.get("width"), 0.0, 0.0, 60.0), "turn": Props._num(b.get("turn"), 0.0, -180.0, 180.0)} \
		if not b.is_empty() else {"width": 0.0, "turn": 0.0}
	if float((out["boards"] as Dictionary)["width"]) > 0.0 and float((out["boards"] as Dictionary)["width"]) < 6.0:
		(out["boards"] as Dictionary)["width"] = 6.0
	var ti: Dictionary = t.get("tiles", {}) if t.get("tiles") is Dictionary else {}
	out["tiles"] = {"size": Props._num(ti.get("size"), 0.0, 0.0, 60.0), "grout": Props._color(ti.get("grout", ""), "#5a5550")}
	if float((out["tiles"] as Dictionary)["size"]) > 0.0 and float((out["tiles"] as Dictionary)["size"]) < 4.0:
		(out["tiles"] as Dictionary)["size"] = 4.0
	out["pattern"] = _sanitize_pattern(t.get("pattern"), pal, "none")
	out["inlay"] = _sanitize_band(t.get("inlay"), pal, 2.0)
	var natural := float(TOP_DEPTH.get("painting" if out["material"] == "painting" else kind, 0.1))
	if float((out["boards"] as Dictionary)["width"]) > 0.0 or float((out["tiles"] as Dictionary)["size"]) > 0.0:
		natural += 0.6
	out["relief"] = _sanitize_relief(t.get("relief"), "painting" if out["material"] == "painting" else "natural", natural)
	# THE TOP HOLDS THE CARDS: grown, its proportions kept, until every corner of where they go lies
	# EDGE inside it
	var k := 1.0
	while not holds_cards(out) and k < 4.0:
		k *= 1.03
		out["size"] = [size.x * k, size.y * k]
	if k > 1.0:
		notes.append("the top was made %d%% larger, to %d x %d cm, to hold the cards" % [roundi((k - 1.0) * 100.0),
			roundi(float(out["size"][0])), roundi(float(out["size"][1]))])
		out["grown"] = k
	return out


static func _sanitize_layer(l: Dictionary, index: int, pal: Array, notes: PackedStringArray) -> Dictionary:
	var name := Props._text(l.get("name", ""), 80)
	if name.is_empty():
		name = "layer %d" % (index + 1)
	var outline := _key(l.get("outline"), {"rect": 1, "round": 1, "oval": 1, "polygon": 1, "top": 1}, "rect")
	var size := _size2(l.get("size"), Vector2(120.0, 72.0)).clamp(Vector2(10.0, 10.0), Vector2(320.0, 260.0))
	if outline == "round":
		size = Vector2(size.x, size.x)
	var fabric := _key(l.get("fabric"), FABRICS, "cotton")
	var at := Vector2.ZERO
	if l.get("at") is Array and (l["at"] as Array).size() >= 2:
		at = Vector2(Props._num(l["at"][0], 0.0, -150.0, 150.0), Props._num(l["at"][1], 0.0, -120.0, 120.0))
	var out := {"name": name, "what": Props._text(l.get("what", ""), 100), "outline": outline, "size": [size.x, size.y],
		"sides": int(Props._num(l.get("sides"), 8.0, 5.0, 12.0)), "drop": Props._num(l.get("drop"), 20.0, 0.0, DROP_MOST * 100.0),
		"at": [at.x, at.y], "turn": Props._num(l.get("turn"), 0.0, -180.0, 180.0), "fabric": fabric,
		"pattern": _sanitize_pattern(l.get("pattern"), pal, "plain"), "border": _sanitize_band(l.get("border"), pal, 0.0),
		"fringe": Props._num(l.get("fringe"), 0.0, 0.0, 15.0) if outline == "rect" else 0.0,
		"sheen": Props._num(l.get("sheen"), 0.5, 0.0, 1.0)}
	var painted := String((out["pattern"] as Dictionary)["kind"]) == "painting"
	out["relief"] = _sanitize_relief(l.get("relief"), "painting" if painted else "natural", float((FABRICS[fabric] as Dictionary)["depth"]))
	if l.has("pattern") and String((out["pattern"] as Dictionary)["kind"]) == "plain" and l.get("pattern") is Dictionary \
			and not String((l["pattern"] as Dictionary).get("kind", "plain")).strip_edges().to_lower() in ["plain", ""]:
		notes.append("%s: the pattern \"%s\" is not one of %s - it is plain" % [name, str((l["pattern"] as Dictionary).get("kind", "")), ", ".join(PATTERNS.keys())])
	return out


## A pattern made safe - a kind it knows ([param fallback] for none), colors that are colors (the
## palette's for none), its scale, turn and count.
static func _sanitize_pattern(p: Variant, pal: Array, fallback: String) -> Dictionary:
	var d: Dictionary = p if p is Dictionary else ({"kind": p} if p is String else {})
	var kind := String(d.get("kind", fallback)).strip_edges().to_lower() if d.get("kind") is String else fallback
	if not PATTERNS.has(kind):
		kind = fallback if PATTERNS.has(fallback) else "plain"
	var colors: Array = []
	for c in (d.get("colors", []) if d.get("colors") is Array else []):
		if Props._is_color(c) and colors.size() < 6:
			colors.append(String(c).strip_edges())
	if colors.is_empty() and d.get("color") is String and Props._is_color(d["color"]):
		colors.append(String(d["color"]).strip_edges())
	if colors.is_empty():
		for i in mini(3, pal.size()):
			colors.append(Props._color(pal[i], "#808080"))
	return {"kind": kind, "colors": colors, "scale": Props._num(d.get("scale"), 8.0, 0.3, 120.0),
		"turn": Props._num(d.get("turn"), 0.0, -180.0, 180.0), "count": Props._num(d.get("count"), 8.0, 3.0, 24.0)}


static func _sanitize_band(b: Variant, pal: Array, inset: float) -> Dictionary:
	var d: Dictionary = b if b is Dictionary else {}
	return {"width": Props._num(d.get("width"), 0.0, 0.0, 30.0), "inset": Props._num(d.get("inset"), inset, 0.0, 60.0),
		"color": Props._color(d.get("color", ""), String(pal[mini(1, pal.size() - 1)]) if not pal.is_empty() else "#c9a227")}


static func _sanitize_relief(r: Variant, fallback: String, natural: float) -> Dictionary:
	var d: Dictionary = r if r is Dictionary else ({"kind": r} if r is String else {})
	var kind := _key(d.get("kind"), RELIEFS, fallback)
	var depth := natural if kind == "natural" else (0.8 if kind == "painting" else 2.0)
	return {"kind": kind, "depth": Props._num(d.get("depth"), depth, 0.0, RELIEF_MOST),
		"scale": Props._num(d.get("scale"), 6.0, 0.5, 40.0), "invert": Props._flag(d.get("invert")), "natural": natural}


static func _key(v: Variant, reg: Dictionary, fallback: String) -> String:
	var s := String(v).strip_edges().to_lower() if v is String else ""
	return s if reg.has(s) else fallback


static func _size2(v: Variant, fallback: Vector2) -> Vector2:
	if v is Array and not (v as Array).is_empty():
		var a: Array = v
		var w := Props._num(a[0], fallback.x, 1.0, 400.0)
		var d := Props._num(a[1], w, 1.0, 400.0) if a.size() >= 2 else w
		return Vector2(w, d)
	if v is float or v is int:
		return Vector2(float(v), float(v))
	return fallback


# --- outlines --------------------------------------------------------------------------------------

## A TOP'S OUTLINE as the builder and the checks read it: its shape, half its size, corner and
## scallops in meters, its middle on the table (x, z).
static func top_outline(top: Dictionary) -> Dictionary:
	var size: Array = top.get("size", [190.0, 85.0])
	var half := Vector2(float(size[0]), float(size[1])) * 0.005
	var scal := int(top.get("scallops", 0))
	return {"shape": String(top.get("shape", "rect")), "half": half, "corner": float(top.get("corner", 0.0)) * 0.01,
		"sides": int(top.get("sides", 8)), "scallops": scal, "scallop": minf(half.x, half.y) * 0.014,
		"center": ORIGIN + TOP_AT, "turn": 0.0, "grow": 0.0}


## A LAYER'S OWN OUTLINE, laid flat, on the table: "top" is the top's grown by its drop.
static func layer_outline(layer: Dictionary, top: Dictionary) -> Dictionary:
	var at: Array = layer.get("at", [0.0, 0.0])
	var center := ORIGIN + Vector2(float(at[0]), float(at[1])) * 0.01
	if String(layer.get("outline", "rect")) == "top":
		var o := top_outline(top)
		o["grow"] = float(layer.get("drop", 20.0)) * 0.01
		o["center"] = (o["center"] as Vector2) + Vector2(float(at[0]), float(at[1])) * 0.01
		o["turn"] = deg_to_rad(float(layer.get("turn", 0.0)))
		return o
	var size: Array = layer.get("size", [120.0, 72.0])
	return {"shape": String(layer.get("outline", "rect")), "half": Vector2(float(size[0]), float(size[1])) * 0.005,
		"corner": 0.004, "sides": int(layer.get("sides", 8)), "scallops": 0, "scallop": 0.0, "center": center,
		"turn": deg_to_rad(float(layer.get("turn", 0.0))), "grow": 0.0}


## A point [param p] on the table (x, z) in outline [param o]'s own unturned space.
static func to_local(o: Dictionary, p: Vector2) -> Vector2:
	return _turn2(p - (o["center"] as Vector2), -float(o["turn"]))


static func to_table(o: Dictionary, l: Vector2) -> Vector2:
	return (o["center"] as Vector2) + _turn2(l, float(o["turn"]))


## [param p] turned [param a] about the vertical, as Basis(Vector3.UP, a) turns (x, z).
static func _turn2(p: Vector2, a: float) -> Vector2:
	var c := cos(a)
	var s := sin(a)
	return Vector2(p.x * c + p.y * s, -p.x * s + p.y * c)


## HOW FAR [param p] (on the table, x z) IS OUTSIDE outline [param o] (meters; negative inside).
static func sdf(o: Dictionary, p: Vector2) -> float:
	return sdf_local(o, to_local(o, p))


static func sdf_local(o: Dictionary, l: Vector2) -> float:
	var h: Vector2 = o["half"]
	var d := 0.0
	match String(o["shape"]):
		"rect":
			var r := minf(float(o["corner"]), minf(h.x, h.y))
			var q := Vector2(absf(l.x), absf(l.y)) - (h - Vector2(r, r))
			d = Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r
		"polygon":
			var n := float(o["sides"])
			var u := l / h
			var an := PI / n
			var a := fposmod(atan2(u.x, u.y) + an, 2.0 * an) - an
			d = (u.length() * cos(a) - cos(an)) * minf(h.x, h.y)
		_:
			var k0 := (l / h).length()
			var k1 := (l / (h * h)).length()
			d = k0 * (k0 - 1.0) / k1 if k1 > 1e-9 else -minf(h.x, h.y)
	var sc := int(o.get("scallops", 0))
	if sc > 0:
		var th := atan2(l.y, l.x)
		d += float(o["scallop"]) * (1.0 - sqrt(absf(cos(th * float(sc) * 0.5))))
	return d - float(o.get("grow", 0.0))


## The way out of outline [param o] at [param p] (on the table, x z): across its edge, outward.
static func normal(o: Dictionary, p: Vector2) -> Vector2:
	return _turn2(_grad_local(o, to_local(o, p)), float(o["turn"]))


## Whether [param p] (on the table, x z) lies on [param top], [param margin] meters in from its edge.
static func inside(top: Dictionary, p: Vector2, margin := 0.0) -> bool:
	return sdf(top_outline(top), p) <= -margin


## Whether every corner of where the cards go ([constant HOLDS]) lies [constant EDGE] inside [param top].
static func holds_cards(top: Dictionary) -> bool:
	var o := top_outline(top)
	for c in [HOLDS.position, Vector2(HOLDS.end.x, HOLDS.position.y), HOLDS.end, Vector2(HOLDS.position.x, HOLDS.end.y)]:
		if sdf(o, ORIGIN + (c as Vector2)) > -EDGE:
			return false
	return true


## The outward direction of outline [param o] at local point [param l]: the slope of its distance.
static func _grad_local(o: Dictionary, l: Vector2) -> Vector2:
	var e := 0.0005
	var g := Vector2(sdf_local(o, l + Vector2(e, 0.0)) - sdf_local(o, l - Vector2(e, 0.0)),
		sdf_local(o, l + Vector2(0.0, e)) - sdf_local(o, l - Vector2(0.0, e)))
	return g.normalized() if g.length() > 1e-9 else (l.normalized() if l.length() > 1e-9 else Vector2(0.0, 1.0))


## THE OUTLINE'S EDGE as points (local, meters), going round: found along rays from its middle (every
## outline here is seen whole from its middle), with a ray at every corner so none is cut off.
static func edge_points(o: Dictionary, rays := RAYS) -> PackedVector2Array:
	var angles: Array = []
	var sc := int(o.get("scallops", 0))
	var n := maxi(rays, sc * 8)
	for i in n:
		angles.append(TAU * float(i) / float(n))
	var h: Vector2 = o["half"]
	match String(o["shape"]):
		"rect":
			var r := minf(float(o["corner"]), minf(h.x, h.y))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var c := Vector2(sx * (h.x - r), sz * (h.y - r))
					for k in 5:
						var a := atan2(sz, sx) + (float(k) - 2.0) * 0.2
						var corner := c + Vector2(cos(a), sin(a)) * r if r > 0.0 else Vector2(sx * h.x, sz * h.y)
						angles.append(fposmod(atan2(corner.y, corner.x), TAU))
		"polygon":
			var sides := int(o["sides"])
			for i in sides:
				angles.append(fposmod(PI * 0.5 + PI / float(sides) + TAU * float(i) / float(sides), TAU))
	angles.sort()
	var out := PackedVector2Array()
	var reach := (h.length() + float(o.get("grow", 0.0))) * 1.5 + 0.01
	for a in angles:
		var dir := Vector2(cos(float(a)), sin(float(a)))
		var lo := 0.0
		var hi := reach
		for i in 26:
			var mid := (lo + hi) * 0.5
			if sdf_local(o, dir * mid) > 0.0:
				hi = mid
			else:
				lo = mid
		var q := dir * lo
		if out.is_empty() or q.distance_to(out[out.size() - 1]) > 0.0008:
			out.append(q)
	if out.size() > 2 and out[0].distance_to(out[out.size() - 1]) < 0.0008:
		out.remove_at(out.size() - 1)
	return out


# --- the edge's profile -----------------------------------------------------------------------------

## How far in from the outline the edge is cut at [param t] of the way down it (0 the top's face, 1
## its underside), meters, for a top [param th] meters thick.
static func profile_inset(edge: String, t: float, th: float) -> float:
	var y := t * th
	match edge:
		"eased":
			var r := minf(0.25 * th, 0.008)
			return r - sqrt(maxf(r * r - pow(r - minf(y, r), 2.0), 0.0))
		"bevel":
			return maxf(0.45 * th - y, 0.0)
		"bullnose":
			var r := th * 0.5
			return r - sqrt(maxf(r * r - pow(y - r, 2.0), 0.0))
		"ogee":
			var s := clampf(t / 0.75, 0.0, 1.0)
			var e := 1.0 - (s * s * (3.0 - 2.0 * s))
			return 0.3 * th * e
		"bead":
			var r := 0.15 * th
			if y < 2.0 * r:
				return r - sqrt(maxf(r * r - pow(y - r, 2.0), 0.0))
			return 0.06 * th
	var e2 := 0.0015
	return e2 - sqrt(maxf(e2 * e2 - pow(e2 - minf(y, e2), 2.0), 0.0))


const _PROFILE_T := [0.0, 0.02, 0.05, 0.1, 0.16, 0.24, 0.32, 0.4, 0.45, 0.5, 0.6, 0.7, 0.75, 0.82, 0.9, 1.0]


# --- built --------------------------------------------------------------------------------------------

## THE TABLE, BUILT from [param spec] (`{top, layers}` made safe): `node` (the top and every layer, in
## the table medium's space - the top's face at y = 0), `top_mat`, `layer_mats`, `painted` (every
## material the painting is laid on, with the size it spans: [method apply_painting]) and `bounds`.
## [param seed] varies the grain, the folds, the patterns' noise.
static func build(spec: Dictionary, seed: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "Furniture"
	var top: Dictionary = spec.get("top", {})
	var o := top_outline(top)
	var painted: Array = []
	var th := float(top.get("thickness", 4.0)) * 0.01
	var edge := String(top.get("edge", "eased"))
	var top_mesh := _top_mesh(o, edge, th)
	var mi := MeshInstance3D.new()
	mi.name = "Top"
	mi.mesh = top_mesh
	mi.position = Vector3((o["center"] as Vector2).x, 0.0, (o["center"] as Vector2).y)
	var top_mat := _top_material(top, seed)
	mi.material_override = top_mat
	root.add_child(mi)
	var half: Vector2 = o["half"]
	if String(top.get("material", "")) == "painting" or String((top.get("pattern", {}) as Dictionary).get("kind", "")) == "painting":
		painted.append({"mat": top_mat, "size": half * 2.0})
	var bounds := AABB(Vector3((o["center"] as Vector2).x - half.x, -th, (o["center"] as Vector2).y - half.y), Vector3(half.x * 2.0, th, half.y * 2.0))
	var layer_mats: Array = []
	var layers: Array = spec.get("layers", [])
	for i in layers.size():
		var l: Dictionary = layers[i]
		var lo := layer_outline(l, top)
		var y := LAYER_FLOOR + LAYER_GAP * float(i)
		var lm := _layer_mesh(l, lo, o, profile_inset(edge, 0.0, th), y, i, seed)
		var node := MeshInstance3D.new()
		node.name = "Layer %d" % (i + 1)
		node.mesh = lm["mesh"]
		var mat := _layer_material(l, lo, hash([seed, i, "layer"]))
		node.material_override = mat
		root.add_child(node)
		layer_mats.append(mat)
		if String((l.get("pattern", {}) as Dictionary).get("kind", "")) == "painting":
			painted.append({"mat": mat, "size": (lo["half"] as Vector2) * 2.0 + Vector2.ONE * float(lo.get("grow", 0.0)) * 2.0})
		bounds = bounds.merge(lm["bounds"])
	return {"node": root, "top_mat": top_mat, "layer_mats": layer_mats, "painted": painted, "bounds": bounds}


## THE PAINTING laid on every surface that takes it - its pixels square there, the part of it that
## fits ([method CardTable.cloth_crop]) - or taken off ([param tex] null: the surface's own color).
## [param height]: the painting's HEIGHT MAP, when the painter made one that lines up with it
## ([method height_fit]) - the depth under the painting, shifted by [param shift] (UV) onto it - or null:
## the painting's own detail stands in.
static func apply_painting(built: Dictionary, tex: Texture2D, height: Texture2D = null, shift := Vector2.ZERO) -> void:
	for p in built.get("painted", []):
		var mat: ShaderMaterial = (p as Dictionary)["mat"]
		mat.set_shader_parameter("painting", tex)
		mat.set_shader_parameter("has_painting", 1.0 if tex != null else 0.0)
		mat.set_shader_parameter("height_map", height if tex != null else null)
		mat.set_shader_parameter("has_height", 1.0 if tex != null and height != null else 0.0)
		mat.set_shader_parameter("height_shift", shift)
		if tex != null:
			var crop := CardTable.cloth_crop(Vector2(tex.get_width(), tex.get_height()), (p as Dictionary)["size"])
			mat.set_shader_parameter("crop", Vector4(crop.position.x, crop.position.y, crop.size.x, crop.size.y))


# --- the painter's height map -----------------------------------------------------------------------

## THE PAINTING'S DEPTH, PAINTED (2026-10-07; the user: "the painter-made height map, especially, sounds
## like a novel idea - if you think it can truly work"). The painter is handed the painting and asked
## for the same surface as a gray height map (`image:height`); an image model may move, zoom or invent
## what it redraws, and a relief that does not lie under its picture is worse than none - so the map
## is MEASURED against the painting before it is used: the two images' STRUCTURE (where each changes,
## its gradient's size - blind to which way round the gray runs) at [constant FIT_W] across,
## correlated at every shift up to [constant FIT_SHIFT] pixels either way. The best is its score (1 the
## same structure, about 0 unrelated) and its shift; under [constant FIT_LEAST] it is refused.
const FIT_W := 96
const FIT_SHIFT := 4
const FIT_LEAST := 0.35
## A FLAT MAP lies under anything: a surface with no relief - a cutting mat, its grid printed on
## smooth vinyl - comes back nearly one gray, as the painter is told to draw a flat print, and its
## faint scratches correlate with nothing (0.03, measured 2026-10-08, refused and asked for again).
## A map whose lightness spans less than this (2nd to 98th percentile, at [constant FIT_W] across) is
## that answer, kept as it is: the surface lies smooth, its print not raised. The maps that lined up
## spanned 0.043 to 0.24; that cutting mat's, 0.015.
const FLAT_SPAN := 0.025


## Whether a table made safe ([param spec], `{top, layers}`) lays the painting where a height map
## would be read: a layer or a top that IS the painting, its relief its own (natural) or the painting's.
static func wants_height(spec: Dictionary) -> bool:
	var top: Dictionary = spec.get("top", {})
	if String(top.get("material", "")) == "painting" and String((top.get("relief", {}) as Dictionary).get("kind", "")) in ["natural", "painting"]:
		return true
	for l in spec.get("layers", []):
		var d: Dictionary = l
		if String((d.get("pattern", {}) as Dictionary).get("kind", "")) == "painting" \
				and String((d.get("relief", {}) as Dictionary).get("kind", "")) in ["natural", "painting"]:
			return true
	return false


## HOW WELL [param height] LIES UNDER [param painting]: `{score, shift}` - the best correlation of
## their structure over the shifts tried, and the shift that gave it (UV: where in the map a point of
## the painting is found, less where it is in the painting).
static func height_fit(painting: Image, height: Image) -> Dictionary:
	var w := FIT_W
	var h := maxi(8, roundi(float(FIT_W) * float(painting.get_height()) / float(maxi(painting.get_width(), 1))))
	var a := _structure(painting, w, h)
	var b := _structure(height, w, h)
	var best := -1.0
	var at := Vector2i.ZERO
	for dy in range(-FIT_SHIFT, FIT_SHIFT + 1):
		for dx in range(-FIT_SHIFT, FIT_SHIFT + 1):
			var sab := 0.0
			var saa := 0.0
			var sbb := 0.0
			for y in range(maxi(1, 1 - dy), mini(h - 1, h - 1 - dy)):
				var ra := y * w
				var rb := (y + dy) * w + dx
				for x in range(maxi(1, 1 - dx), mini(w - 1, w - 1 - dx)):
					var va := a[ra + x]
					var vb := b[rb + x]
					sab += va * vb
					saa += va * va
					sbb += vb * vb
			var r := sab / sqrt(maxf(saa * sbb, 1e-12))
			if r > best:
				best = r
				at = Vector2i(dx, dy)
	return {"score": best, "shift": Vector2(float(at.x) / float(w), float(at.y) / float(h))}


## HOW MUCH [param height] RISES AND FALLS: its lightness's spread, 2nd to 98th percentile, at
## [constant FIT_W] across (see [constant FLAT_SPAN]).
static func height_span(height: Image) -> float:
	var im := height.duplicate() as Image
	if im.is_compressed():
		im.decompress()
	im.clear_mipmaps()
	im.convert(Image.FORMAT_RGB8)
	var h := maxi(8, roundi(float(FIT_W) * float(im.get_height()) / float(maxi(im.get_width(), 1))))
	im.resize(FIT_W, h, Image.INTERPOLATE_LANCZOS)
	var v := PackedFloat32Array()
	for y in h:
		for x in FIT_W:
			v.append(im.get_pixel(x, y).get_luminance())
	v.sort()
	return v[int(v.size() * 0.98)] - v[int(v.size() * 0.02)]


## An image's STRUCTURE at [param w] x [param h]: the size of its lightness's gradient, softened by a
## pixel, less its mean - where it changes, not which way.
static func _structure(img: Image, w: int, h: int) -> PackedFloat32Array:
	var im := img.duplicate() as Image
	if im.is_compressed():
		im.decompress()
	im.clear_mipmaps()
	im.convert(Image.FORMAT_RGB8)
	im.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var l := PackedFloat32Array()
	l.resize(w * h)
	for y in h:
		for x in w:
			var c := im.get_pixel(x, y)
			l[y * w + x] = c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	var g := PackedFloat32Array()
	g.resize(w * h)
	var mean := 0.0
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			var gx := (l[i + 1] - l[i - 1]) * 2.0 + (l[i + 1 - w] - l[i - 1 - w]) + (l[i + 1 + w] - l[i - 1 + w])
			var gy := (l[i + w] - l[i - w]) * 2.0 + (l[i + w - 1] - l[i - w - 1]) + (l[i + w + 1] - l[i - w + 1])
			g[i] = sqrt(gx * gx + gy * gy)
			mean += g[i]
	mean /= float(maxi((w - 2) * (h - 2), 1))
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			g[y * w + x] -= mean
	return g


## The top: its face (cut into a mesh fine enough to carry its hem's distance), and its edge cut to
## the profile, ring by ring - local to its middle. UV is centimeters from the middle, UV2 (how far in
## from the edge, cm; 1 on the edge itself).
static func _top_mesh(o: Dictionary, edge: String, th: float) -> ArrayMesh:
	var g := Props.Tris.new()
	var pts := edge_points(o)
	var normals := PackedVector2Array()
	for q in pts:
		normals.append(_grad_local(o, q))
	var in0 := profile_inset(edge, 0.0, th)
	# THE FACE: the outline drawn in by the profile's start, and a grid inside it
	var ring0 := PackedVector2Array()
	for i in pts.size():
		ring0.append(pts[i] - normals[i] * in0)
	var sheet := _sheet(ring0, func(q: Vector2) -> float: return sdf_local(o, q) + in0, TOP_STEP)
	var up := Vector3.UP
	var vs: PackedVector2Array = sheet["points"]
	var idx: PackedInt32Array = sheet["tris"]
	for k in range(0, idx.size(), 3):
		var a := vs[idx[k]]
		var b := vs[idx[k + 1]]
		var c := vs[idx[k + 2]]
		g.tri(Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y), Vector3(c.x, 0.0, c.y), up, up, up, a * 100.0, b * 100.0, c * 100.0,
			Vector2(-sdf_local(o, a) * 100.0, 0.0), Vector2(-sdf_local(o, b) * 100.0, 0.0), Vector2(-sdf_local(o, c) * 100.0, 0.0))
	# THE EDGE, ring under ring down the profile
	var rings: Array = []
	var norms: Array = []
	for t in _PROFILE_T:
		var inset := profile_inset(edge, float(t), th)
		var slope := (profile_inset(edge, minf(float(t) + 0.01, 1.0), th) - profile_inset(edge, maxf(float(t) - 0.01, 0.0), th)) \
			/ maxf((minf(float(t) + 0.01, 1.0) - maxf(float(t) - 0.01, 0.0)) * th, 1e-6)
		var ring := PackedVector3Array()
		var rn := PackedVector3Array()
		for i in pts.size():
			var q := pts[i] - normals[i] * inset
			ring.append(Vector3(q.x, -float(t) * th, q.y))
			rn.append((Vector3(normals[i].x, 0.0, normals[i].y) + Vector3.UP * slope).normalized())
		rings.append(ring)
		norms.append(rn)
	var n := pts.size()
	for r in rings.size() - 1:
		var ra: PackedVector3Array = rings[r]
		var rb: PackedVector3Array = rings[r + 1]
		var na: PackedVector3Array = norms[r]
		var nb: PackedVector3Array = norms[r + 1]
		for i in n:
			var j := (i + 1) % n
			var ua := Vector2(ra[i].x, ra[i].z) * 100.0
			var ub := Vector2(ra[j].x, ra[j].z) * 100.0
			g.tri(ra[i], rb[i], rb[j], na[i], nb[i], nb[j], ua, ua, ub, Vector2(0.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 1.0))
			g.tri(ra[i], rb[j], ra[j], na[i], nb[j], na[j], ua, ub, ub, Vector2(0.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 1.0))
	return g.mesh()


## A FLAT SHEET over the outline [param ring] (local points, going round), whose inside is where
## [param dist] is negative: the ring and a grid [param step] apart inside it, cut into triangles.
## `{points: PackedVector2Array, tris: PackedInt32Array}`.
static func _sheet(ring: PackedVector2Array, dist: Callable, step: float, extra := PackedVector2Array()) -> Dictionary:
	var pts := PackedVector2Array(ring)
	pts.append_array(extra)
	# the grid keeps clear of the extra points, so no triangle is a sliver between them
	var near := {}
	for q in extra:
		near[Vector2i(floori(q.x / step), floori(q.y / step))] = true
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in ring:
		lo = lo.min(q)
		hi = hi.max(q)
	var z := lo.y + step * 0.5
	var row := 0
	while z < hi.y:
		var x := lo.x + step * (0.5 if row % 2 == 0 else 1.0)
		while x < hi.x:
			var q := Vector2(x, z)
			if float(dist.call(q)) < -step * 0.4 and not near.has(Vector2i(floori(q.x / step), floori(q.y / step))):
				pts.append(q)
			x += step
		z += step * 0.866
		row += 1
	var tris := Geometry2D.triangulate_delaunay(pts)
	var keep := PackedInt32Array()
	for k in range(0, tris.size(), 3):
		var c := (pts[tris[k]] + pts[tris[k + 1]] + pts[tris[k + 2]]) / 3.0
		if float(dist.call(c)) <= 0.0005:
			keep.append_array([tris[k], tris[k + 1], tris[k + 2]])
	return {"points": pts, "tris": keep}


## ONE LAYER: its flat sheet - and its fringe - laid on the table at [param y], every point past the
## top's edge HUNG OVER IT ([method _drape]). UV is the layer's own flat space, centimeters from its
## middle; UV2 is (how far in from its hem, cm; how far out along its fringe, cm). `{mesh, bounds}`.
static func _layer_mesh(l: Dictionary, lo: Dictionary, top_o: Dictionary, bend: float, y: float, index: int, seed: int) -> Dictionary:
	var ring := edge_points(lo)
	var gap := 0.0015 + 0.0015 * float(index)
	# WHERE IT ROLLS OVER THE EDGE it is cut finer: rows of points along the top's outline, from where
	# its face ends round the roll and a little way down - the grid alone, coarser than the roll,
	# drew the edge in steps
	var rr := maxf(0.006, bend) + gap
	var extra := PackedVector2Array()
	var rim := edge_points(top_o, RAYS * 2)
	var rim_n := PackedVector2Array()
	for q in rim:
		rim_n.append(_grad_local(top_o, q))
	# each a hair off its row: rows of points round a circle are all but co-circular, and Godot's
	# triangulation slows to seconds on them
	var jit := RandomNumberGenerator.new()
	jit.seed = hash([seed, index, "rim"])
	for s in [-bend - 0.01, -bend, -bend + rr * 0.3, -bend + rr * 0.6, -bend + rr * 0.9, -bend + rr * 1.25, -bend + rr * 1.6,
			-bend + rr * 2.2, -bend + rr * 3.2, -bend + rr * 5.0]:
		var last := Vector2(INF, INF)
		for k in rim.size():
			var w := to_table(top_o, rim[k] + rim_n[k] * float(s))
			var lq := to_local(lo, w) + Vector2(jit.randf_range(-0.0012, 0.0012), jit.randf_range(-0.0012, 0.0012))
			if sdf_local(lo, lq) < -0.004 and lq.distance_to(last) > 0.008:
				extra.append(lq)
				last = lq
	var sheet := _sheet(ring, func(q: Vector2) -> float: return sdf_local(lo, q), LAYER_STEP, extra)
	var flat: PackedVector2Array = sheet["points"]
	var tris: PackedInt32Array = sheet["tris"]
	var hem := PackedFloat32Array()
	var out := PackedFloat32Array()
	for q in flat:
		hem.append(maxf(-sdf_local(lo, q), 0.0) * 100.0)
		out.append(0.0)
	# THE FRINGE: a strip past each end, its threads drawn by the shader
	var fringe := float(l.get("fringe", 0.0)) * 0.01
	if fringe > 0.0 and String(l.get("outline", "rect")) == "rect":
		var h: Vector2 = lo["half"]
		for side in [-1.0, 1.0]:
			var base := flat.size()
			var cols := maxi(2, ceili(fringe / 0.01) + 1)
			var rows := maxi(2, ceili(h.y * 2.0 / LAYER_STEP) + 1)
			for r in rows:
				for c in cols:
					var along := fringe * float(c) / float(cols - 1)
					flat.append(Vector2(side * (h.x + along), -h.y + h.y * 2.0 * float(r) / float(rows - 1)))
					hem.append(0.0)
					out.append(maxf(along * 100.0, 0.001) if c > 0 else 0.0)
			for r in rows - 1:
				for c in cols - 1:
					var a := base + r * cols + c
					tris.append_array([a, a + 1, a + cols + 1, a, a + cols + 1, a + cols])
	# laid on the table, and hung over its edge
	var pos := PackedVector3Array()
	var rng_phase := float(hash([seed, index, "folds"]) & 0xFFFF) / 65535.0 * TAU
	for q in flat:
		pos.append(_drape(to_table(lo, q), top_o, bend, gap, y, rng_phase))
	# triangles wound so the side that faced up faces out wherever it hangs (Godot draws clockwise fronts)
	var idx := PackedInt32Array()
	for k in range(0, tris.size(), 3):
		var a := tris[k]
		var b := tris[k + 1]
		var c := tris[k + 2]
		var fa := Vector3(flat[a].x, 0.0, flat[a].y)
		var fb := Vector3(flat[b].x, 0.0, flat[b].y)
		var fc := Vector3(flat[c].x, 0.0, flat[c].y)
		if (fb - fa).cross(fc - fa).y > 0.0:
			idx.append_array([a, c, b])
		else:
			idx.append_array([a, b, c])
	var nrm := PackedVector3Array()
	nrm.resize(pos.size())
	for k in range(0, idx.size(), 3):
		var a := pos[idx[k]]
		var fn := -(pos[idx[k + 1]] - a).cross(pos[idx[k + 2]] - a)
		for m in 3:
			nrm[idx[k + m]] += fn
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var box := AABB(pos[0], Vector3.ZERO) if not pos.is_empty() else AABB()
	for i in pos.size():
		nrm[i] = nrm[i].normalized() if nrm[i].length() > 1e-12 else Vector3.UP
		uv.append(flat[i] * 100.0)
		uv2.append(Vector2(hem[i], out[i]))
		box = box.expand(pos[i])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	if not idx.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"mesh": mesh, "bounds": box}


## A POINT OF A LAYER, [param p] on the table, as the cloth lies there: flat at [param y] on the top,
## and past where the top's face ends ([param bend] in from its outline: the edge's profile) ROLLED
## OVER THE EDGE and hanging straight down, [param gap] out from it, in folds that deepen as it falls.
static func _drape(p: Vector2, top_o: Dictionary, bend: float, gap: float, y: float, phase: float) -> Vector3:
	var l := to_local(top_o, p)
	var d := sdf_local(top_o, l) + bend
	if d <= 0.0:
		return Vector3(p.x, y, p.y)
	var n := _grad_local(top_o, l)
	var q := l - n * d
	var rr := maxf(0.006, bend) + gap
	var out := 0.0
	var down := 0.0
	if d < PI * 0.5 * rr:
		out = rr * sin(d / rr)
		down = rr * (1.0 - cos(d / rr))
	else:
		out = rr
		down = rr + (d - PI * 0.5 * rr)
	down = minf(down, DROP_MOST)
	# FOLDS round the hang, as a cloth gathers: deeper the further it falls
	var round_at := atan2(q.y, q.x) * (top_o["half"] as Vector2).length()
	# - outward only: a fold swung inward put the top's edge through the cloth
	out += (0.5 + 0.5 * sin(round_at / 0.06 + phase)) * 0.012 * clampf(down / 0.25, 0.0, 1.0)
	var w := to_table(top_o, q + n * out)
	return Vector3(w.x, y - down, w.y)


static func _top_material(top: Dictionary, seed: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _TOP_SHADER
	var look: Dictionary = top.get("look", DEFAULT_WOOD)
	var kind := String(look.get("kind", "wood"))
	var painting := String(top.get("material", "")) == "painting"
	mat.set_shader_parameter("kind", -1 if painting else int(TOP_KINDS.get(kind, 0)))
	mat.set_shader_parameter("color", Color.html(String(look.get("color", "#5c3821"))))
	mat.set_shader_parameter("color2", Color.html(String(look.get("color2", "#3a2213"))))
	mat.set_shader_parameter("polish", float(look.get("polish", 0.4)))
	mat.set_shader_parameter("wear", float(look.get("wear", 0.0)))
	mat.set_shader_parameter("figure", float(look.get("pattern", 0.5)))
	mat.set_shader_parameter("grain", float(look.get("grain", 1.2)))
	var b: Dictionary = top.get("boards", {})
	mat.set_shader_parameter("boards", float(b.get("width", 0.0)))
	mat.set_shader_parameter("board_turn", deg_to_rad(float(b.get("turn", 0.0))))
	var ti: Dictionary = top.get("tiles", {})
	mat.set_shader_parameter("tiles", float(ti.get("size", 0.0)))
	mat.set_shader_parameter("grout", Color.html(String(ti.get("grout", "#5a5550"))))
	mat.set_shader_parameter("seed", float(seed & 0xFFF) / 64.0)
	var o := top_outline(top)
	_surface(mat, top.get("pattern", {}), top.get("inlay", {}), top.get("relief", {}), (o["half"] as Vector2) * 100.0, seed, "none")
	return mat


static func _layer_material(l: Dictionary, lo: Dictionary, seed: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _TEXTILE_SHADER
	var fabric: Dictionary = FABRICS.get(String(l.get("fabric", "cotton")), FABRICS["cotton"])
	mat.set_shader_parameter("fabric", int(fabric["code"]))
	mat.set_shader_parameter("sheen", float(l.get("sheen", 0.5)))
	mat.set_shader_parameter("fringe", float(l.get("fringe", 0.0)))
	mat.set_shader_parameter("seed", float(seed & 0xFFF) / 64.0)
	var half: Vector2 = (lo["half"] as Vector2) + Vector2.ONE * float(lo.get("grow", 0.0))
	_surface(mat, l.get("pattern", {}), l.get("border", {}), l.get("relief", {}), half * 100.0, seed, "plain")
	return mat


## What the top's and a layer's shaders share (`table_common.gdshaderinc`): the pattern, the band
## along the hem, the relief, and the extent the painting spans.
static func _surface(mat: ShaderMaterial, pattern: Dictionary, band: Dictionary, relief: Dictionary, half_cm: Vector2, seed: int, none: String) -> void:
	var kind := String(pattern.get("kind", none))
	mat.set_shader_parameter("pattern", int((PATTERNS[kind] as Dictionary)["code"]) if PATTERNS.has(kind) else 0)
	var cols: Array = pattern.get("colors", [])
	var arr := PackedVector3Array()
	for i in 6:
		# IN LINEAR LIGHT: an array uniform takes its numbers as they are (no source_color conversion),
		# and sRGB numbers drawn as linear washed every pattern out to pastel
		var c := (Color.html(String(cols[i % cols.size()])) if not cols.is_empty() else Color(0.5, 0.5, 0.5)).srgb_to_linear()
		arr.append(Vector3(c.r, c.g, c.b))
	mat.set_shader_parameter("colors", arr)
	mat.set_shader_parameter("ncolors", maxi(cols.size(), 1))
	mat.set_shader_parameter("pat_scale", float(pattern.get("scale", 8.0)))
	mat.set_shader_parameter("pat_turn", deg_to_rad(float(pattern.get("turn", 0.0))))
	mat.set_shader_parameter("pat_count", float(pattern.get("count", 8.0)))
	mat.set_shader_parameter("pat_seed", float(seed & 0x3FF) / 37.0)
	mat.set_shader_parameter("half_size", half_cm)
	mat.set_shader_parameter("border", float(band.get("width", 0.0)))
	mat.set_shader_parameter("border_inset", float(band.get("inset", 0.0)))
	mat.set_shader_parameter("border_color", Color.html(String(band.get("color", "#c9a227"))))
	var rk := String(relief.get("kind", "natural"))
	mat.set_shader_parameter("relief", int((RELIEFS[rk] as Dictionary)["code"]) if RELIEFS.has(rk) else 1)
	var depth := float(relief.get("depth", 0.5))
	mat.set_shader_parameter("relief_depth", depth if rk != "natural" else 0.0)
	mat.set_shader_parameter("natural_depth", 0.0 if rk == "none" else (depth if rk == "natural" else float(relief.get("natural", 0.2))))
	mat.set_shader_parameter("relief_scale", float(relief.get("scale", 6.0)))
	mat.set_shader_parameter("relief_invert", 1.0 if bool(relief.get("invert", false)) else 0.0)


# --- what it is to the light ----------------------------------------------------------------------

## HOW LIGHT THE TABLE IS where a candle could stand: the linear luminance of whatever lies uppermost
## at the middle of each cell of [param grid] over [param rect] (on the table, x z) - a layer's
## pattern (its colors' mean; the painting's own pixels, from [param painting], a small copy of it in
## linear light), else the top's - and the dark floor past the top. Row by row. [param fallback] is a
## painted surface's color while there is no painting.
static func surface_lum(spec: Dictionary, painting: Image, rect: Rect2, grid: Vector2i, fallback: Color) -> PackedFloat32Array:
	var top: Dictionary = spec.get("top", {})
	var o := top_outline(top)
	var layers: Array = spec.get("layers", [])
	var outlines: Array = []
	for l in layers:
		outlines.append(layer_outline(l, top))
	var out := PackedFloat32Array()
	var cell := rect.size / Vector2(grid)
	for gy in grid.y:
		for gx in grid.x:
			var p := rect.position + Vector2((gx + 0.5) * cell.x, (gy + 0.5) * cell.y)
			var v := 0.02
			var found := false
			for i in range(layers.size() - 1, -1, -1):
				var lo: Dictionary = outlines[i]
				if sdf(lo, p) <= 0.0 and sdf(o, p) <= 0.0:
					v = _lum_of(layers[i]["pattern"], painting, to_local(lo, p), (lo["half"] as Vector2) + Vector2.ONE * float(lo.get("grow", 0.0)), fallback)
					found = true
					break
			if not found and sdf(o, p) <= 0.0:
				var look: Dictionary = top.get("look", DEFAULT_WOOD)
				if String(top.get("material", "")) == "painting":
					v = _lum_of({"kind": "painting"}, painting, to_local(o, p), o["half"], fallback)
				elif String((top.get("pattern", {}) as Dictionary).get("kind", "none")) in ["none", ""]:
					v = (_lin(Color.html(String(look.get("color", "#5c3821")))) * 2.0 + _lin(Color.html(String(look.get("color2", "#3a2213"))))) / 3.0
				else:
					v = _lum_of(top["pattern"], painting, to_local(o, p), o["half"], fallback)
			out.append(v)
	return out


static func _lum_of(pattern: Dictionary, painting: Image, l: Vector2, half: Vector2, fallback: Color) -> float:
	if String(pattern.get("kind", "plain")) == "painting":
		if painting == null or painting.is_empty():
			return _lin(fallback)
		var crop := CardTable.cloth_crop(Vector2(painting.get_width(), painting.get_height()), half * 2.0)
		var uv := crop.position + (l / (half * 2.0) + Vector2(0.5, 0.5)) * crop.size
		var px := Vector2i(clampi(int(uv.x * painting.get_width()), 0, painting.get_width() - 1),
			clampi(int(uv.y * painting.get_height()), 0, painting.get_height() - 1))
		var c := painting.get_pixelv(px)
		return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	var cols: Array = pattern.get("colors", [])
	if cols.is_empty():
		return 0.2
	if String(pattern.get("kind", "plain")) == "plain":
		return _lin(Color.html(String(cols[0])))
	var s := 0.0
	for c in cols:
		s += _lin(Color.html(String(c)))
	return s / float(cols.size())


static func _lin(c: Color) -> float:
	var l := c.srgb_to_linear()
	return l.r * 0.2126 + l.g * 0.7152 + l.b * 0.0722


# --- in words -------------------------------------------------------------------------------------

## THE TABLE IN A LINE, for the set dresser's answers and a later episode's history: "a round walnut
## top 120 cm across, bullnose edge; a linen tablecloth in checks; a velvet square as a diamond".
static func summary(spec: Dictionary) -> String:
	var top: Dictionary = spec.get("top", {})
	var size: Array = top.get("size", [190.0, 85.0])
	var parts := PackedStringArray()
	var mat := String(top.get("material", ""))
	var look: Dictionary = top.get("look", {})
	var made := "the painting" if mat == "painting" else ("%s (%s)" % [mat, String(look.get("kind", ""))] if not mat.is_empty() else "wood")
	var dims := ("%d cm across" % roundi(float(size[0]))) if String(top.get("shape", "")) == "round" else \
		("%d x %d cm" % [roundi(float(size[0])), roundi(float(size[1]))])
	var shape := String(top.get("shape", "rect"))
	if shape == "polygon":
		shape = "%d-sided" % int(top.get("sides", 8))
	var extra := PackedStringArray()
	if float((top.get("boards", {}) as Dictionary).get("width", 0.0)) > 0.0:
		extra.append("boards")
	if float((top.get("tiles", {}) as Dictionary).get("size", 0.0)) > 0.0:
		extra.append("tiles")
	if not String((top.get("pattern", {}) as Dictionary).get("kind", "none")) in ["none", "plain"]:
		extra.append("inlaid %s" % String((top["pattern"] as Dictionary)["kind"]))
	if float((top.get("inlay", {}) as Dictionary).get("width", 0.0)) > 0.0:
		extra.append("an inlaid band")
	if int(top.get("scallops", 0)) > 0:
		extra.append("a scalloped rim")
	parts.append("%s %s top of %s, %s, %s edge%s" % ["an" if shape.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a", shape, made, dims, String(top.get("edge", "eased")),
		(" - " + ", ".join(extra)) if not extra.is_empty() else ""])
	for l in spec.get("layers", []):
		var d: Dictionary = l
		var pat := String((d.get("pattern", {}) as Dictionary).get("kind", "plain"))
		var turn := float(d.get("turn", 0.0))
		parts.append("%s: %s %s in %s%s" % [String(d.get("name", "")), String(d.get("fabric", "")),
			("hanging %d cm over the edge" % roundi(float(d.get("drop", 0.0)))) if String(d.get("outline", "")) == "top"
				else "%s %d x %d cm" % [String(d.get("outline", "")), roundi(float((d["size"] as Array)[0])), roundi(float((d["size"] as Array)[1]))],
			pat, (", turned %d degrees" % roundi(turn)) if absf(turn) > 1.0 else ""])
	return "; ".join(parts)
