extends RefCounted
class_name Assembly

## Assembly - A THING BUILT OF MANY SMALL PARTS, on a lattice (next/assembly.md): bricks on studs, from what the agents write. The
## user, 2026-11-02, of the first brick show: "the goal is to slowly build something from nothing ... we might pull a brick, try to
## fit it, put it back, try a different one. We might build some structure, then destroy it and start over" - hundreds of pieces,
## each picked up, most of them more than once, over an hour.
##
## A LOG, NEVER A BAKE. What a heap and a model look like after a step does not depend on when the step happens, so [method perform]
## walks the steps once, in order, and keeps for every piece each place it comes to rest and each move that took it there. Time is
## laid over that afterwards ([method lay]) and can be laid again every sentence of a live reading without anything being worked out
## again: only what has not begun moves, a scrub lands exactly where the same step left it, and a render and a preview agree. A
## part's pose is a lookup ([method pose_of]). A frame costs what changes (next/framework_audit.md's rule 5): the one piece in hand.
##
## NOT THE PHYSICS ([TablePhysics]): next to a heap of a thousand, a body per piece would be a thousand surface fields and a solver
## held apart by interlocking studs. The lattice answers exactly what the solver would answer roughly - a cell is taken or it is not,
## a stud holds or it does not - and what it refuses, it refuses in words ([method fit]).
##
## THE AGENT SAYS WHAT, THE HAND FINDS WHERE: a step names a part and a stud; which of the pieces in the tub it is, what has to be
## moved to get at it, how high it goes, how far it rises to clear what is in its way are found here. There is always a piece of the
## part asked for: what the steps need is added to the stock before anything lands ([method perform]'s dry pass).
##
## SLOW, BECAUSE BUILDING IS (the user: "building a model from LEGO is probably not fast ... we might stop, we might consider what to
## do next"): a step has a NATURAL time and a FLOOR it can be hurried to ([constant OPS]), and only a run of the same piece goes at a
## clip. A stretch with more time than its steps need is not played slow: the moves keep a hand's pace and the time left over falls
## between them, where a person stops to look ([method lay]). A reader writes no times: its words and silences say how long a stretch
## is, and the work fits itself under them.

## THE LATTICE (meters): a stud's pitch, a plate's height, how high a stud stands, and how thick the baseplate is.
const STUD := 0.008
const PLATE := 0.0032
const STUD_H := 0.0018
const BASE_T := 0.0014
## THE KINDS OF PART: `h` its height in plates, `studs` where it has them on top (all, none, or only along its back row), `sizes` the
## ones made ([studs across, studs deep]), `share` how common it is in a mixed lot. A size written the other way round is the same
## part turned ([method parse_part]).
const KINDS := {
	"brick": {"label": "Brick", "blurb": "the plain block, three plates tall, studs all over its top", "h": 3, "studs": "all", "share": 46,
		"sizes": [[1, 1], [1, 2], [1, 3], [1, 4], [1, 6], [1, 8], [2, 2], [2, 3], [2, 4], [2, 6], [2, 8]]},
	"plate": {"label": "Plate", "blurb": "a third of a brick's height, studs on top: a floor, a layer, a roof laid flat", "h": 1, "studs": "all", "share": 30,
		"sizes": [[1, 1], [1, 2], [1, 3], [1, 4], [1, 6], [1, 8], [2, 2], [2, 3], [2, 4], [2, 6], [2, 8], [4, 4], [4, 6], [4, 8], [6, 6], [6, 8], [8, 8]]},
	"tile": {"label": "Tile", "blurb": "as thin as a plate and smooth on top: a clean surface, and nothing holds onto it", "h": 1, "studs": "none", "share": 6,
		"sizes": [[1, 1], [1, 2], [1, 4], [2, 2], [2, 4]]},
	"slope": {"label": "Slope", "blurb": "a brick's height at its back, falling at 45 degrees to its front, studs only along its back row: a roof, a shoulder, a hull", "h": 3, "studs": "back", "share": 10,
		"sizes": [[1, 2], [1, 3], [2, 2], [2, 3], [3, 2], [4, 2]]},
	"round": {"label": "Round", "blurb": "a round brick: a column, a post, a tower", "h": 3, "studs": "all", "share": 4,
		"sizes": [[1, 1], [2, 2]]},
	"arch": {"label": "Arch", "blurb": "two bricks tall and one stud wide, standing on its two ends, open between them: a doorway, a bridge, a window", "h": 6, "studs": "all", "share": 4,
		"sizes": [[1, 4], [1, 6]]},
}
## THE STEPS OF A BUILD, each what the hands do: `natural` seconds at an easy pace, `floor` hurried, its words an agent's.
const OPS := {
	"dig": {"label": "Dig", "natural": 7.0, "floor": 3.0,
		"blurb": "the hands go into a heap and stir, moving what is on top aside, seen and heard. It is half of what a person does at a tub, and it is worth its time",
		"fields": [["in", "the stock's name (left out: where the next piece comes from)"], ["for", "a part it is looking for, which then lies on top for the next step that asks for it (left out: only looking)"],
			["seconds", "how long (left out: 7)"]]},
	"put": {"label": "Put", "natural": 11.0, "floor": 5.0, "brisk": [5.0, 3.2],
		"blurb": "a piece found in the stock, brought over, lined up over its place, lowered and pressed home with a click",
		"fields": [["part", "what it is: \"brick 2x4 red\""], ["at", "[x, z] the stud its far left corner goes on, and it comes down on whatever is there; [x, z, level] to say how high (level 0 is on the plate, in plates: a brick is 3 tall), which is how a part hangs under another"],
			["turn", "0, 90, 180 or 270 degrees about up: 0 keeps its front (a slope's low side) toward the reader, 90 to the reader's right. A size runs across, deep: \"2x4\" at 0 is 2 wide and 4 deep, at 90 is 4 wide and 2 deep"],
			["from", "the stock it comes from (left out: the one with the most of its color)"], ["pace", "\"brisk\" when the hands are in a rhythm (left out: an easy pace)"],
			["hover", "seconds it is held over its place, undecided, before it goes down"], ["first", "[[x, z], ...] other places it is held over first, being considered there"],
			["look", "seconds it is held up and turned over first, near the lens"]]},
	"try": {"label": "Try", "natural": 13.0, "floor": 7.0,
		"blurb": "a piece brought over and tried in a place, then taken away again: not this one. It need not fit: over a taken place it only comes down to what is there",
		"fields": [["part", "as `put`"], ["at", "as `put`"], ["turn", "as `put`"], ["from", "as `put`"], ["to", "where it goes after (left out: back where it came from; \"aside\": on the table beside the plate, for later)"],
			["press", "true: pressed on and pulled off again (only where it fits)"]]},
	"look": {"label": "Look", "natural": 10.0, "floor": 5.0,
		"blurb": "a piece picked up, held up near the lens and turned over slowly, then put back",
		"fields": [["part", "as `put`"], ["from", "as `put`"], ["to", "as `try`"], ["seconds", "how long it is held (left out: 6)"]]},
	"pause": {"label": "Pause", "natural": 12.0, "floor": 4.0,
		"blurb": "nothing moves: the build is being looked at. Most of building is this",
		"fields": [["seconds", "how long (left out: 12)"]]},
	"take": {"label": "Take", "natural": 7.0, "floor": 3.0,
		"blurb": "a piece pulled off the model and put away; what only it held up comes away with it in one chunk",
		"fields": [["at", "[x, z] the highest piece over that stud, or [x, z, level] the piece at that height"], ["to", "the stock it goes into, or \"aside\" (left out: where it came from)"]]},
	"wreck": {"label": "Wreck", "natural": 6.0, "floor": 3.0,
		"blurb": "a stretch of the model pulled apart from the top down, chunk by chunk, each chunk dropped into a stock with a clatter. Six seconds a chunk at an easy pace. Written with nothing else it takes the whole model and the plate is empty again",
		"fields": [["from", "[x, z] one corner of what comes down (left out: all of it)"], ["to", "[x, z] the other corner"], ["above", "the level it comes down to: what stands below it stays (left out: all the way)"],
			["into", "the stock it goes into (left out: the biggest)"]]},
	"turn": {"label": "Turn", "natural": 7.0, "floor": 4.0,
		"blurb": "the whole plate turned on the table, to see another side of it. Studs keep their numbers: x and z are the plate's own, however it is turned",
		"fields": [["by", "degrees (left out: 90)"]]},
	"wall": {"label": "Wall", "natural": 5.0, "floor": 3.2,
		"blurb": "a run of the same part along a straight line, course on course with its joints staggered, the hands in a rhythm: the shorter sizes of the same part close the ends. A long wall is many pieces and takes its time, at about five seconds each",
		"fields": [["part", "the longest piece of it: \"brick 2x4 tan\""], ["from", "[x, z] the first stud of the line"], ["to", "[x, z] the last, straight along x or along z"], ["courses", "how many, one on another (left out: 1)"], ["level", "how high the first goes (left out: on what is there)"],
			["stock", "the stock its pieces come from"]]},
	"fill": {"label": "Fill", "natural": 5.0, "floor": 3.2,
		"blurb": "a rectangle covered with one part, its rows staggered, the hands in a rhythm: a floor, a roof, a yard. At about five seconds a piece",
		"fields": [["part", "the largest piece of it: \"plate 2x4 gray\""], ["from", "[x, z] one corner"], ["to", "[x, z] the other"], ["level", "how high (left out: on what is there)"], ["stock", "the stock its pieces come from"]]},
}
## A piece's way to its place: how far over it it is held, how far over its studs the press begins, how far over what is in its way
## a piece goes (all meters), how high it lifts at most, what is ignored as too tall to go over, how many places along its way are
## looked at, and how far above a stock a chunk is let fall from.
const HOVER := 0.024
const PRESS_FROM := 0.0018
const CLEAR_OVER := 0.014
const LIFT_MOST := 0.14
const TALL := 0.22
const WAY_LOOKS := 7
const DROP_FROM := 0.05
## A plate's turn looked at for what it would swing into: this many places on the way, this many along each of its sides.
const SWEEP_LOOKS := 8
const SWEEP_EDGE := 8
## The shares of a piece's time spent going for it (its hand on its way), and how far the time of a step varies by its seed.
const REACH := 1.5
const VARY := Vector2(0.8, 1.3)
## A hand at its digging: pieces moved a second of it, the fewest and the most, how far they go (meters), and how far round the spot
## it looks when looking for nothing.
const DIG_MOVES := 1.4
const DIG_LEAST := 4
const DIG_MOST := 22
const DIG_SPREAD := 0.06
const DIG_NEAR := 0.07
## The most pieces moved aside to get at one: a piece under more than this came up through them.
const UNCOVER_MOST := 24
## How late in a step a piece moved a second time may begin that move, a share of it: later, and the first move is cut short for it.
const MOVED_AGAIN := 0.9
## A hand's limit on one chunk of what comes down, and how many pieces of what comes down it takes at once.
const CHUNK := Vector2i(2, 7)
## The most steps an act writes (a `wall` or a `fill` is one, however many pieces), and a table's stock: places, colors, pieces
## in one place and in all.
const MAX_OPS := 120
const MAX_SOURCES := 8
const MAX_COLORS := 24
const MOST_IN_SOURCE := 700
const MOST_PIECES := 1800
## How big a baseplate may be, in studs; how big it is unless written.
const BASE_SIZES := Vector2i(8, 48)
const BASE_SIZE := 32
## How many pieces it takes to cover a square meter of a heap, one deep (a mixed lot's mean footprint): how many a place is filled
## with, when its count is left out, at how many deep.
const PER_M2 := 1900.0
const DEEP := 1.7
## How much commoner a lot's small sizes are than its big: the power its pick along a kind's sizes is drawn at.
const LOT_SMALL := 2.3
## The default colors of a mixed lot, when a table names none (a share each).
const COLORS := {"red": "#b3261e", "blue": "#1f4f9c", "yellow": "#e8b512", "white": "#ece8dc", "black": "#23252a", "gray": "#8b8d8f", "green": "#2a7a41", "tan": "#c9b185"}

var spec := {}
var seed_value := 0
var world := {}                   # {base_at: Vector3, yaw: radians, heaps: {name: AssemblyHeap}, obstacles: [{box, name}], view: Vector3}
var pieces: Array = []            # each {id, kind, w, d, color, rests: [[step, in_model, xf]]}
var steps: Array = []             # each {act, do, natural, floor, moves: [...], sounds: [...], yaw: [a, b]}
var spans := {}                   # an act's name -> [first step, one past its last]
var problems := {}                # an act's name -> what could not be done, in words
var counts := {}                  # an act's name -> {put, try, ...}
var layers := {}                  # an act's name -> the model as it stands after it, in words
var _yaw := 0.0
var _cells := {}                  # a lattice cell's key -> a piece
var _placed := {}                 # a piece on the model -> {x, z, l, turn, kind, w, d}
var _dry := true
var _avail := {}                  # a stock -> {part's key: how many lie there}, in the dry pass
var _need := {}                   # a stock -> [part, ...]: what the steps ask for and it does not hold, in order of first use
var _fillers := {}                # a stock -> [part, ...]: what it holds to begin with
var _by_key := {}                 # a stock -> {part's key: [ids]}
var _home := {}                   # a piece -> the stock it last came out of
var _left_at := {}                # a piece -> where on its heap it was taken from
var _mtop := -INF                 # how high the model stands, -INF when it must be found again
var _rng := RandomNumberGenerator.new()
var _act := ""
var _t0 := PackedFloat64Array()
var _t1 := PackedFloat64Array()


# --- the words -------------------------------------------------------------------------------------

## What can be done, as a puppeteer reads it: the kinds, the steps and their fields.
static func describe() -> String:
	var lines := PackedStringArray()
	lines.append("PARTS (a `part` is written \"<kind> <across>x<deep> <color>\": \"brick 2x4 red\", \"slope 2x3 gray\" - the colors are the table's):")
	for k in KINDS:
		var row: Dictionary = KINDS[k]
		var sizes := PackedStringArray()
		for s in row["sizes"]:
			sizes.append("%dx%d" % [int((s as Array)[0]), int((s as Array)[1])])
		lines.append("- %s: %s. Made in %s." % [k, String(row["blurb"]), ", ".join(sizes)])
	lines.append("")
	lines.append("THE STEPS OF A BUILD (each {\"do\": its name, and its fields}), and about how long each takes at an easy pace:")
	for k in OPS:
		var row: Dictionary = OPS[k]
		lines.append("- %s (%d s): %s." % [k, roundi(float(row["natural"])), String(row["blurb"])])
		for f in row["fields"]:
			lines.append("    `%s`: %s" % [String(f[0]), String(f[1])])
	return "\n".join(lines)


## What a set dresser writes of it, in words.
static func describe_stock() -> String:
	var lines := PackedStringArray()
	lines.append("`assembly`, beside `things` and `light`: what is built on this table, and where the pieces wait. {")
	lines.append("  \"colors\": {\"its name\": \"#rrggbb\", ...} - every color the pieces come in, up to %d, named as the work will name them;" % MAX_COLORS)
	lines.append("  \"base\": {\"size\": [across, deep] studs, %d to %d (left out: %d), \"color\": a color's name, \"at\": [x, z] cm where its middle stands (left out: the middle of the picture), \"turn\": degrees} - what the build grows on;" % [BASE_SIZES.x, BASE_SIZES.y, BASE_SIZE])
	lines.append("  \"stock\": [each place the pieces wait, up to %d - {\"name\": what the work calls it, and where it is: \"thing\": the name of a hollow thing you built, an open tub, box, crate or tray, and it is filled (\"fill\" 0-1, how full; left out: 0.85), or \"at\": [x, z] cm and \"radius\": cm, a loose pile on the table itself; \"count\": how many pieces at most (left out: as many as it takes), \"colors\": {a color's name: how common} (left out: all alike), \"kinds\": {a kind's name: how common} (left out: a mixed lot, as %s)}]" % [MAX_SOURCES, ", ".join(PackedStringArray(KINDS.keys()))])
	lines.append("}. The pieces are drawn for you, as real as the things are: you never make a thing for a brick. A container must be really hollow, its inside wide and open (a thing with a `lathe` or walls of `box` parts, and no lid), and it stays where it stands. The plate turns: nothing stands where its corners swing, which the blueprint keeps clear. What is asked for later is added to the stock by itself, so a stock is a look and a feel: a mixed tub, a pile, a tray of one color.")
	return "\n".join(lines)


# --- what an agent wrote, made safe ---------------------------------------------------------------------

## THE TABLE'S `assembly`, made safe: `{}` where it has none.
static func sanitize(raw: Variant, notes: PackedStringArray = PackedStringArray()) -> Dictionary:
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return {}
	var d: Dictionary = raw
	var out := {"colors": {}, "stock": []}
	var colors: Dictionary = d.get("colors") if d.get("colors") is Dictionary else COLORS
	for k in colors:
		if (out["colors"] as Dictionary).size() >= MAX_COLORS:
			notes.append("more than %d colors: the rest left out" % MAX_COLORS)
			break
		var name := String(k).strip_edges().to_lower()
		var v: Variant = colors[k]
		if name.is_empty() or not (v is String) or not Color.html_is_valid(String(v).strip_edges()):
			notes.append("the color \"%s\" is not {name: \"#rrggbb\"}: left out" % str(k))
			continue
		(out["colors"] as Dictionary)[name] = "#" + Color.html(String(v).strip_edges()).to_html(false)
	if (out["colors"] as Dictionary).is_empty():
		out["colors"] = COLORS.duplicate()
	var names: Array = (out["colors"] as Dictionary).keys()
	var base: Dictionary = d.get("base") if d.get("base") is Dictionary else {}
	var size: Array = base.get("size") if base.get("size") is Array and (base.get("size") as Array).size() == 2 else [BASE_SIZE, BASE_SIZE]
	var b := {"size": [clampi(int(_num(size[0], BASE_SIZE)), BASE_SIZES.x, BASE_SIZES.y), clampi(int(_num(size[1], BASE_SIZE)), BASE_SIZES.x, BASE_SIZES.y)],
		"turn": _num(base.get("turn"), 0.0)}
	var bc := String(base.get("color", "")).strip_edges().to_lower() if base.get("color") is String else ""
	b["color"] = bc if names.has(bc) else ("gray" if names.has("gray") else String(names[0]))
	var at: Variant = base.get("at")
	if at is Array and (at as Array).size() == 2 and _is_num(at[0]) and _is_num(at[1]):
		b["at"] = [float(at[0]), float(at[1])]
	out["base"] = b
	var taken := {"aside": true}
	for s in (d.get("stock") if d.get("stock") is Array else []):
		if (out["stock"] as Array).size() >= MAX_SOURCES:
			notes.append("more than %d stocks: the rest left out" % MAX_SOURCES)
			break
		if not (s is Dictionary):
			continue
		var sd: Dictionary = s
		var nm := String(sd.get("name", "")).strip_edges().to_lower()
		if nm.is_empty() or taken.has(nm):
			notes.append("a stock needs a name of its own (\"%s\")" % nm)
			continue
		taken[nm] = true
		var st := {"name": nm, "colors": _shares(sd.get("colors"), names, notes, "%s's colors" % nm), "kinds": _kinds_of(sd.get("kinds"), notes, nm)}
		if sd.get("count") != null:
			st["count"] = clampi(int(_num(sd.get("count"), 0.0)), 0, MOST_IN_SOURCE)
		if sd.get("thing") is String and not String(sd["thing"]).strip_edges().is_empty():
			st["thing"] = String(sd["thing"]).strip_edges()
			st["fill"] = clampf(_num(sd.get("fill"), 0.85), 0.1, 1.0)
		elif sd.get("at") is Array and (sd["at"] as Array).size() == 2 and _is_num(sd["at"][0]) and _is_num(sd["at"][1]):
			st["at"] = [float(sd["at"][0]), float(sd["at"][1])]
			st["radius"] = clampf(_num(sd.get("radius"), 12.0), 3.0, 40.0)
		else:
			notes.append("the stock \"%s\" is neither in a `thing` nor `at` a place: left out" % nm)
			continue
		(out["stock"] as Array).append(st)
	return out


static func _is_num(v: Variant) -> bool:
	return v is float or v is int


static func _num(v: Variant, fallback: float) -> float:
	return float(v) if _is_num(v) else fallback


static func _shares(raw: Variant, names: Array, notes: PackedStringArray, what: String) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for k in raw:
			var nm := String(k).strip_edges().to_lower()
			if names.has(nm):
				out[nm] = maxf(_num(raw[k], 1.0), 0.0)
			else:
				notes.append("%s: no color is called \"%s\" (%s)" % [what, nm, ", ".join(PackedStringArray(names))])
	if out.is_empty():
		for n in names:
			out[n] = 1.0
	return out


static func _kinds_of(raw: Variant, notes: PackedStringArray, what: String) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for k in raw:
			var nm := String(k).strip_edges().to_lower()
			if KINDS.has(nm):
				out[nm] = maxf(_num(raw[k], 1.0), 0.0)
			else:
				notes.append("%s: no kind of part is called \"%s\" (%s)" % [what, nm, ", ".join(PackedStringArray(KINDS.keys()))])
	if out.is_empty():
		for k in KINDS:
			out[k] = float((KINDS[k] as Dictionary)["share"])
	return out


## A PART AS WRITTEN, "brick 2x4 red": `{kind, w, d, color, swap}` (`swap`: written the other way round from how it is made, so it is
## the same part turned 90 degrees) - `{}` with why in [param why] when it is no part. [param colors]: the table's colors by name.
static func parse_part(text: Variant, colors: Dictionary, why: Array = []) -> Dictionary:
	if not (text is String):
		why.append("a part is written \"brick 2x4 red\"")
		return {}
	var words := String(text).strip_edges().to_lower().split(" ", false)
	var kind := ""
	var size := Vector2i.ZERO
	var rest := PackedStringArray()
	for w in words:
		var word := String(w)
		if kind.is_empty() and KINDS.has(word):
			kind = word
		elif size == Vector2i.ZERO and word.contains("x") and word.get_slice("x", 0).is_valid_int() and word.get_slice("x", 1).is_valid_int():
			size = Vector2i(int(word.get_slice("x", 0)), int(word.get_slice("x", 1)))
		else:
			rest.append(word)
	if kind.is_empty() or size == Vector2i.ZERO:
		why.append("\"%s\" is not a part: write \"<kind> <across>x<deep> <color>\", the kinds %s" % [String(text), ", ".join(PackedStringArray(KINDS.keys()))])
		return {}
	var color := " ".join(rest)
	if not colors.has(color):
		why.append("\"%s\": no color is called \"%s\" (%s)" % [String(text), color, ", ".join(PackedStringArray(colors.keys()))])
		return {}
	var sizes: Array = (KINDS[kind] as Dictionary)["sizes"]
	if sizes.has([size.x, size.y]):
		return {"kind": kind, "w": size.x, "d": size.y, "color": color, "swap": false}
	if sizes.has([size.y, size.x]):
		return {"kind": kind, "w": size.y, "d": size.x, "color": color, "swap": true}
	var made := PackedStringArray()
	for s in sizes:
		made.append("%dx%d" % [int((s as Array)[0]), int((s as Array)[1])])
	why.append("\"%s\": a %s is made in %s" % [String(text), kind, ", ".join(made)])
	return {}


## THE STEPS OF AN ACT, made safe: each `{do, ...}` it could use. What could not be used is in [param notes].
static func sanitize_ops(raw: Variant, notes: PackedStringArray) -> Array:
	var out: Array = []
	for o in (raw if raw is Array else []):
		if out.size() >= MAX_OPS:
			notes.append("an act writes at most %d steps: the rest left out" % MAX_OPS)
			break
		if not (o is Dictionary):
			continue
		var d: Dictionary = o
		var kind := String(d.get("do", "")).strip_edges().to_lower()
		if not OPS.has(kind):
			notes.append("\"%s\" is not a step (the steps: %s)" % [kind, ", ".join(PackedStringArray(OPS.keys()))])
			continue
		out.append(d.duplicate(true))
		(out[out.size() - 1] as Dictionary)["do"] = kind
	return out


## How long steps [param ops] take, about, before any is worked out: `Vector2(natural, floor)` seconds. What [method perform] finds
## (how many pieces a `wall` comes to) is what is played; this is for what cannot stand a table.
static func timing(ops: Array) -> Vector2:
	var out := Vector2.ZERO
	for o in ops:
		var d: Dictionary = o
		var row: Dictionary = OPS[String(d["do"])]
		var n := Vector2(float(row["natural"]), float(row["floor"]))
		match String(d["do"]):
			"put":
				if String(d.get("pace", "")) == "brisk":
					n = Vector2(float((row["brisk"] as Array)[0]), float((row["brisk"] as Array)[1]))
				var extra := _num(d.get("hover"), 0.0) + _num(d.get("look"), 0.0) + (float((d["first"] as Array).size()) * 2.0 if d.get("first") is Array else 0.0)
				n += Vector2(extra, extra * 0.5)
			"pause", "dig", "look":
				var fallback := 6.0 if String(d["do"]) == "look" else float(row["natural"])
				var s := _num(d.get("seconds"), fallback)
				n = Vector2(s + (4.0 if String(d["do"]) == "look" else 0.0), s * 0.4)
			"wall":
				var cells := _line_cells(d)
				n *= maxf(1.0, ceilf(float(cells) / 3.0) * maxf(_num(d.get("courses"), 1.0), 1.0))
			"fill":
				n *= maxf(1.0, ceilf(float(_area_cells(d)) / 6.0))
			"wreck":
				n *= 4.0
		out += n
	return out


static func _line_cells(d: Dictionary) -> int:
	if not (d.get("from") is Array and d.get("to") is Array) or (d["from"] as Array).size() < 2 or (d["to"] as Array).size() < 2:
		return 1
	return absi(int(_num(d["to"][0], 0.0)) - int(_num(d["from"][0], 0.0))) + absi(int(_num(d["to"][1], 0.0)) - int(_num(d["from"][1], 0.0))) + 1


static func _area_cells(d: Dictionary) -> int:
	if not (d.get("from") is Array and d.get("to") is Array) or (d["from"] as Array).size() < 2 or (d["to"] as Array).size() < 2:
		return 1
	return (absi(int(_num(d["to"][0], 0.0)) - int(_num(d["from"][0], 0.0))) + 1) * (absi(int(_num(d["to"][1], 0.0)) - int(_num(d["from"][1], 0.0))) + 1)


# --- the lattice -------------------------------------------------------------------------------------

## How a part of [param w] x [param d] lies at [param turn] degrees: studs across (x), studs deep (z).
static func turned_size(w: int, d: int, turn: int) -> Vector2i:
	return Vector2i(d, w) if posmod(turn, 180) == 90 else Vector2i(w, d)


## A part's own cell (studs [param i], [param j], from its far left at no turn) on the lattice, the part's far left corner at
## [param x], [param z] at [param turn] degrees: turned about its middle as [method place_xf] turns it.
static func _turned_cell(i: int, j: int, w: int, d: int, turn: int, x: int, z: int) -> Vector2i:
	var lx := float(i) + 0.5 - float(w) * 0.5
	var lz := float(j) + 0.5 - float(d) * 0.5
	var a := deg_to_rad(float(turn))
	var wx := cos(a) * lx + sin(a) * lz
	var wz := -sin(a) * lx + cos(a) * lz
	var size := turned_size(w, d, turn)
	return Vector2i(x + int(round(wx + float(size.x) * 0.5 - 0.5)), z + int(round(wz + float(size.y) * 0.5 - 0.5)))


## The cells a part fills: `[[cell x, cell z, level from its bottom], ...]`. An arch stands on its ends, open between them.
static func cells_of(kind: String, w: int, d: int, turn: int, x: int, z: int, l: int) -> Array:
	var h := int((KINDS[kind] as Dictionary)["h"])
	var out: Array = []
	for j in d:
		for i in w:
			var c := _turned_cell(i, j, w, d, turn, x, z)
			var from := 0
			if kind == "arch" and j > 0 and j < d - 1:
				from = 3
			for k in range(from, h):
				out.append([c.x, c.y, l + k])
	return out


## Whether a part has a stud over its own cell [param j] deep.
static func _studded(kind: String, j: int) -> bool:
	match String((KINDS[kind] as Dictionary)["studs"]):
		"none":
			return false
		"back":
			return j == 0
	return true


static func _key(x: int, z: int, l: int) -> int:
	return (x + 128) + ((z + 128) << 9) + (l << 18)


## WHERE ON THE PLATE A PIECE GOES: its pose on the model, from the plate's middle, its origin the middle of its underside.
func place_xf(x: int, z: int, l: int, w: int, d: int, turn: int) -> Transform3D:
	var size := turned_size(w, d, turn)
	var base: Array = (spec["base"] as Dictionary)["size"]
	var cx := (float(x) + float(size.x) * 0.5 - float(base[0]) * 0.5) * STUD
	var cz := (float(z) + float(size.y) * 0.5 - float(base[1]) * 0.5) * STUD
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(turn))), Vector3(cx, BASE_T + float(l) * PLATE, cz))


## The plate's own pose at [param yaw] radians.
func base_xf(yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), world["base_at"] as Vector3)


## How high a part of that size and turn would come down, at [param x], [param z]: on whatever is highest under it (0: on the plate).
func level_for(w: int, d: int, turn: int, x: int, z: int) -> int:
	var size := turned_size(w, d, turn)
	var most := 0
	for j in size.y:
		for i in size.x:
			var cx := x + i
			var cz := z + j
			for l in range(_top_level + 1, -1, -1):
				if _cells.has(_key(cx, cz, l)):
					most = maxi(most, l + 1)
					break
	return most


var _top_level := 0


## WHETHER A PART GOES THERE, and how it holds: `{ok, why, studs}` - `why` says what is wrong, in words an agent can act on. A cell is
## taken or it is not; a part holds by at least one stud, from below or from above (a part hangs from what is over it), and the
## plate's own studs count only under the plate's own cells.
func fit(kind: String, w: int, d: int, turn: int, x: int, z: int, l: int) -> Dictionary:
	if l < 0:
		return {"ok": false, "why": "a part cannot go below the plate", "studs": 0}
	var cells := cells_of(kind, w, d, turn, x, z, l)
	for c in cells:
		var other: Variant = _cells.get(_key(int(c[0]), int(c[1]), int(c[2])))
		if other != null:
			return {"ok": false, "why": "stud [%d, %d] at level %d is taken by %s" % [int(c[0]), int(c[1]), int(c[2]), _name_of(int(other))], "studs": 0}
	var base: Array = (spec["base"] as Dictionary)["size"]
	var h := int((KINDS[kind] as Dictionary)["h"])
	var held := 0
	for j in d:
		for i in w:
			var c := _turned_cell(i, j, w, d, turn, x, z)
			var open := kind == "arch" and j > 0 and j < d - 1
			if not open:
				if l == 0:
					if c.x >= 0 and c.y >= 0 and c.x < int(base[0]) and c.y < int(base[1]):
						held += 1
				else:
					var under: Variant = _cells.get(_key(c.x, c.y, l - 1))
					if under != null and _stud_over(int(under), c.x, c.y):
						held += 1
			if _studded(kind, j) and _cells.has(_key(c.x, c.y, l + h)):
				held += 1
	if held == 0:
		var what := "on the plate" if l == 0 else "at level %d" % l
		return {"ok": false, "why": "nothing would hold it %s: no stud meets it there" % what, "studs": 0}
	return {"ok": true, "why": "", "studs": held}


## Whether piece [param id] on the model has a stud up over cell [param x], [param z].
func _stud_over(id: int, x: int, z: int) -> bool:
	var p: Dictionary = _placed[id]
	var w := int(p["w"])
	var d := int(p["d"])
	for j in d:
		for i in w:
			if _turned_cell(i, j, w, d, int(p["turn"]), int(p["x"]), int(p["z"])) == Vector2i(x, z):
				return _studded(String(p["kind"]), j)
	return false


func _name_of(id: int) -> String:
	var q: Dictionary = pieces[id]
	return "a %s %dx%d %s" % [String(q["kind"]), int(q["w"]), int(q["d"]), String(q["color"])]


## What piece [param id] on the model is joined to by a stud, each once.
func _joined(id: int) -> Array:
	var p: Dictionary = _placed[id]
	var seen := {}
	var h := int((KINDS[String(p["kind"])] as Dictionary)["h"])
	var l := int(p["l"])
	var w := int(p["w"])
	var d := int(p["d"])
	for j in d:
		for i in w:
			var c := _turned_cell(i, j, w, d, int(p["turn"]), int(p["x"]), int(p["z"]))
			var open := String(p["kind"]) == "arch" and j > 0 and j < d - 1
			if not open and l > 0:
				var under: Variant = _cells.get(_key(c.x, c.y, l - 1))
				if under != null and _stud_over(int(under), c.x, c.y):
					seen[int(under)] = true
			if _studded(String(p["kind"]), j):
				var over: Variant = _cells.get(_key(c.x, c.y, l + h))
				if over != null:
					seen[int(over)] = true
	return seen.keys()


## Whether piece [param id] on the model stands on the plate's own studs.
func _on_plate(id: int) -> bool:
	var p: Dictionary = _placed[id]
	if int(p["l"]) != 0:
		return false
	var base: Array = (spec["base"] as Dictionary)["size"]
	for c in cells_of(String(p["kind"]), int(p["w"]), int(p["d"]), int(p["turn"]), int(p["x"]), int(p["z"]), 0):
		if int(c[2]) == 0 and int(c[0]) >= 0 and int(c[1]) >= 0 and int(c[0]) < int(base[0]) and int(c[1]) < int(base[1]):
			return true
	return false


## WHAT WOULD COME AWAY with [param gone] taken off: those, and whatever nothing else then holds to the plate.
func _with_what_it_held(gone: Array) -> Array:
	var out := {}
	for g in gone:
		out[g] = true
	var kept := {}
	var open: Array = []
	for id in _placed:
		if not out.has(id) and _on_plate(int(id)):
			kept[id] = true
			open.append(id)
	while not open.is_empty():
		var id: int = open.pop_back()
		for o in _joined(id):
			if not out.has(o) and not kept.has(o):
				kept[o] = true
				open.append(o)
	for id in _placed:
		if not kept.has(id):
			out[id] = true
	return out.keys()


func _seat(id: int, kind: String, w: int, d: int, turn: int, x: int, z: int, l: int) -> void:
	_placed[id] = {"x": x, "z": z, "l": l, "turn": turn, "kind": kind, "w": w, "d": d}
	for c in cells_of(kind, w, d, turn, x, z, l):
		_cells[_key(int(c[0]), int(c[1]), int(c[2]))] = id
		_top_level = maxi(_top_level, int(c[2]))
	_mtop = -INF


func _unseat(id: int) -> void:
	var p: Dictionary = _placed[id]
	for c in cells_of(String(p["kind"]), int(p["w"]), int(p["d"]), int(p["turn"]), int(p["x"]), int(p["z"]), int(p["l"])):
		_cells.erase(_key(int(c[0]), int(c[1]), int(c[2])))
	_placed.erase(id)
	_mtop = -INF


## How high the model stands now, on the table (meters).
func _model_top() -> float:
	if _mtop != -INF:
		return _mtop
	var base_y: float = (world["base_at"] as Vector3).y
	var most := base_y + BASE_T
	for id in _placed:
		var p: Dictionary = _placed[id]
		most = maxf(most, base_y + BASE_T + float(int(p["l"]) + int((KINDS[String(p["kind"])] as Dictionary)["h"])) * PLATE + STUD_H)
	_mtop = most
	return most


## How high what is under [param x], [param z] stands (meters), for a piece [param half] meters across on its way over it: the model
## where the plate is, a heap, and a thing it does not go round - [method _way_problem] says of one too tall to go over.
func _top_at(x: float, z: float, half: float) -> float:
	var out: float = (world["base_at"] as Vector3).y
	var b: Vector3 = world["base_at"]
	var base: Array = (spec["base"] as Dictionary)["size"]
	var reach := Vector2(float(base[0]), float(base[1])).length() * STUD * 0.5 + half
	if Vector2(x - b.x, z - b.z).length() <= reach:
		out = maxf(out, _model_top())
	for k in (world.get("heaps", {}) as Dictionary):
		var v := ((world["heaps"] as Dictionary)[k] as AssemblyHeap).height_at(x, z)
		if not is_nan(v):
			out = maxf(out, v)
	for ob in world.get("obstacles", []):
		var box: AABB = (ob as Dictionary)["box"]
		if x >= box.position.x - half and x <= box.end.x + half and z >= box.position.z - half and z <= box.end.z + half and box.end.y < TALL:
			out = maxf(out, box.end.y)
	return out


# --- the walk ----------------------------------------------------------------------------------------

## THE BUILD: acts [param acts] ([{name, ops}], in the order they are done) walked twice. Once dry, to learn what the steps ask of each
## stock that it does not hold - a part asked for is always there - and once for real, the stock laid down first, with what is
## asked for soonest on top. Every piece and every move it makes come out of this, and no time does: [method lay].
func perform(acts: Array) -> void:
	_make_fillers()
	_avail = {}
	_need = {}
	for s in spec.get("stock", []):
		var nm := String((s as Dictionary)["name"])
		var have := {}
		for p in _fillers.get(nm, []):
			var k := part_key(p as Dictionary)
			have[k] = int(have.get(k, 0)) + 1
		_avail[nm] = have
		_need[nm] = []
	_avail["aside"] = {}
	_need["aside"] = []
	_dry = true
	_rng.seed = hash([seed_value, "assembly dry"])
	_walk(acts)
	_dry = false
	_rng.seed = hash([seed_value, "assembly"])
	_lay_stock()
	_walk(acts)
	_t0 = PackedFloat64Array()
	_t1 = PackedFloat64Array()
	_t0.resize(steps.size())
	_t1.resize(steps.size())
	_t0.fill(INF)
	_t1.fill(INF)


func _walk(acts: Array) -> void:
	_cells = {}
	_placed = {}
	_top_level = 0
	_mtop = -INF
	_home = {}
	_left_at = {}
	_yaw = float(world.get("yaw", 0.0))
	steps = []
	spans = {}
	problems = {}
	counts = {}
	layers = {}
	if _dry:
		pieces = []
		_by_key = {}
		for nm in _fillers:
			_by_key[nm] = {}
			for p in _fillers[nm]:
				_add_piece(p as Dictionary, String(nm))
		_by_key["aside"] = {}
	for a in acts:
		var ad: Dictionary = a
		_act = String(ad["name"])
		var k0 := steps.size()
		problems[_act] = []
		counts[_act] = {}
		for op in ad["ops"]:
			_do(op as Dictionary)
		spans[_act] = [k0, steps.size()]
		if not _dry:
			layers[_act] = model_text()


func _add_piece(p: Dictionary, stock: String) -> int:
	var id := pieces.size()
	pieces.append({"id": id, "kind": String(p["kind"]), "w": int(p["w"]), "d": int(p["d"]), "color": String(p["color"]), "rests": []})
	_file(id, stock)
	return id


func _file(id: int, stock: String) -> void:
	var k := part_key(pieces[id] as Dictionary)
	if not _by_key.has(stock):
		_by_key[stock] = {}
	if not (_by_key[stock] as Dictionary).has(k):
		(_by_key[stock] as Dictionary)[k] = []
	((_by_key[stock] as Dictionary)[k] as Array).append(id)


## What a part is, whatever piece of it: its kind, size and color.
static func part_key(p: Dictionary) -> String:
	return "%s %dx%d %s" % [String(p["kind"]), int(p["w"]), int(p["d"]), String(p["color"])]


## WHAT EACH STOCK HOLDS TO BEGIN WITH: a lot as written, by its shares of colors and kinds, sized by the place it fills unless its
## count is written.
func _make_fillers() -> void:
	_fillers = {}
	for s in spec.get("stock", []):
		var sd: Dictionary = s
		var nm := String(sd["name"])
		var heap: AssemblyHeap = (world.get("heaps", {}) as Dictionary).get(nm)
		var made: Array = []
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "assembly lot", nm])
		var n := int(sd.get("count", -1))
		if n < 0:
			var area := float(heap.area_cells()) * AssemblyHeap.CELL * AssemblyHeap.CELL if heap != null else 0.05
			n = clampi(roundi(area * PER_M2 * DEEP), 12, MOST_IN_SOURCE)
		for _i in n:
			made.append(_lot_piece(sd, rng))
		_fillers[nm] = made
	# ...and no more than a table can draw, the last places the thinnest
	var total := 0
	for nm in _fillers:
		total += (_fillers[nm] as Array).size()
	if total > MOST_PIECES:
		var keep := float(MOST_PIECES) / float(total)
		for nm in _fillers:
			_fillers[nm] = (_fillers[nm] as Array).slice(0, int(float((_fillers[nm] as Array).size()) * keep))


func _lot_piece(sd: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var kind := _drawn(sd["kinds"] as Dictionary, rng)
	var sizes: Array = (KINDS[kind] as Dictionary)["sizes"]
	# ...the small sizes commoner than the big, as in any tub
	var s: Array = sizes[mini(int(pow(rng.randf(), LOT_SMALL) * float(sizes.size())), sizes.size() - 1)]
	return {"kind": kind, "w": int(s[0]), "d": int(s[1]), "color": _drawn(sd["colors"] as Dictionary, rng)}


static func _drawn(shares: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in shares:
		total += float(shares[k])
	var u := rng.randf() * maxf(total, 1e-6)
	for k in shares:
		u -= float(shares[k])
		if u <= 0.0:
			return String(k)
	return String(shares.keys()[0])


## THE STOCK LAID DOWN, for real: what it holds to begin with, then what the steps asked for and it did not hold, soonest on top.
func _lay_stock() -> void:
	pieces = []
	_by_key = {}
	var heaps: Dictionary = world.get("heaps", {})
	for k in heaps:
		(heaps[k] as AssemblyHeap).empty()
	for nm in heaps:
		_by_key[nm] = {}
		var heap: AssemblyHeap = heaps[nm]
		var all: Array = (_fillers.get(nm, []) as Array).duplicate()
		var wanted: Array = (_need.get(nm, []) as Array).duplicate()
		wanted.reverse()
		all.append_array(wanted)
		for p in all:
			var id := _add_piece(p as Dictionary, String(nm))
			var q: Dictionary = pieces[id]
			var xf := heap.deposit(id, float(q["w"]) * STUD, float(q["d"]) * STUD, _tall(String(q["kind"])), _rng)
			(q["rests"] as Array).append([-1, false, xf])


static func _tall(kind: String) -> float:
	return float((KINDS[kind] as Dictionary)["h"]) * PLATE


func _heap(nm: String) -> AssemblyHeap:
	return (world.get("heaps", {}) as Dictionary).get(nm)


## The stock named [param named], else the one holding the most of [param part]'s color.
func _stock_for(part: Dictionary, named: Variant) -> String:
	var nm := String(named).strip_edges().to_lower() if named is String else ""
	if not nm.is_empty() and ((world.get("heaps", {}) as Dictionary).has(nm)):
		return nm
	if not nm.is_empty():
		_problem("no stock is called \"%s\" (%s): it comes from another" % [nm, ", ".join(PackedStringArray((world.get("heaps", {}) as Dictionary).keys()))])
	var best := ""
	var most := -1.0
	for s in spec.get("stock", []):
		var sd: Dictionary = s
		var share := float((sd["colors"] as Dictionary).get(String(part["color"]), 0.0))
		if share > most:
			most = share
			best = String(sd["name"])
	return best if not best.is_empty() else "aside"


func _problem(what: String) -> void:
	if not _dry:
		(problems[_act] as Array).append(what)


func _counted(what: String, by := 1) -> void:
	if not _dry:
		(counts[_act] as Dictionary)[what] = int((counts[_act] as Dictionary).get(what, 0)) + by


func _variation() -> float:
	return lerpf(VARY.x, VARY.y, Hands.share(hash([seed_value, "assembly step"]), steps.size()))


func _step(what: String, natural: float, least: float) -> Dictionary:
	var v := _variation()
	var st := {"act": _act, "do": what, "natural": natural * v, "floor": least, "moves": [], "sounds": []}
	steps.append(st)
	return st


func _do(op: Dictionary) -> void:
	var what := String(op["do"])
	match what:
		"put":
			_put(op)
		"try":
			_try(op)
		"look":
			_look_at(op)
		"dig":
			_dig(op)
		"pause":
			var s := clampf(_num(op.get("seconds"), 12.0), 0.5, 300.0)
			_step("pause", s, s * 0.35)
			_counted("pause")
		"take":
			_take(op)
		"wreck":
			_wreck(op)
		"turn":
			_turn(op)
		"wall":
			_wall(op)
		"fill":
			_fill(op)


## Where [param at] (`[x, z]` or `[x, z, level]`) says a piece goes - `{x, z, l}` - or `{}`.
func _at(at: Variant) -> Dictionary:
	if not (at is Array) or (at as Array).size() < 2 or not _is_num(at[0]) or not _is_num(at[1]):
		_problem("`at` is [x, z] or [x, z, level]")
		return {}
	return {"x": int(at[0]), "z": int(at[1]), "l": int(at[2]) if (at as Array).size() > 2 and _is_num(at[2]) else -1}


func _part_of(raw: Variant) -> Dictionary:
	var why: Array = []
	var part := parse_part(raw, spec["colors"] as Dictionary, why)
	if part.is_empty() and not why.is_empty():
		_problem(String(why[0]))
	return part


static func _turn_of(raw: Variant, part: Dictionary) -> int:
	var t := posmod(int(round(_num(raw, 0.0) / 90.0)) * 90, 360)
	return posmod(t + 90, 360) if bool(part.get("swap", false)) else t


# ...the piece itself

## A PIECE OF [param part] out of stock [param stock]: the one with least on it, what lies on it moved aside in the step's own time
## (share [param until] of it) - and if there is none (asked of a stock that was given it dry and took it since), one that is laid
## there first, as a dig would find it. Off its heap, its pose in `_from`.
func _piece_from(part: Dictionary, stock: String, st: Dictionary, until: float) -> int:
	var key := part_key(part)
	if not _by_key.has(stock):
		_by_key[stock] = {}
	var ids: Array = (_by_key[stock] as Dictionary).get(key, [])
	if _dry:
		if ids.is_empty():
			(_need[stock] as Array).append({"kind": String(part["kind"]), "w": int(part["w"]), "d": int(part["d"]), "color": String(part["color"])})
			var id := pieces.size()
			pieces.append({"id": id, "kind": String(part["kind"]), "w": int(part["w"]), "d": int(part["d"]), "color": String(part["color"]), "rests": []})
			_home[id] = stock
			return id
		var id: int = ids.pop_back()
		_home[id] = stock
		return id
	var heap: AssemblyHeap = _heap(stock)
	if ids.is_empty() or heap == null:
		return -1
	var best := -1
	var least := 1 << 30
	for i in ids:
		var n := heap.on_it(int(i)).size()
		if n < least:
			least = n
			best = int(i)
			if n == 0:
				break
	ids.erase(best)
	_uncover(best, heap, st, 0.0, until)
	_left_at[best] = heap.where(best)
	heap.take(best)
	_home[best] = stock
	return best


## WHAT LIES ON PIECE [param id] moved aside, over shares [param a] to [param b] of step [param st], the topmost first - the hand's own
## digging. Each goes clear of it, so it does not land back on it.
func _uncover(id: int, heap: AssemblyHeap, st: Dictionary, a: float, b: float) -> void:
	var on: Array = heap.on_it(id)
	if on.is_empty():
		return
	var at := heap.where(id)
	var n := on.size()
	var done := 0
	while not on.is_empty() and done < UNCOVER_MOST:
		var o := int(on[on.size() - 1])
		var u0 := lerpf(a, b, float(mini(done, n - 1)) / float(n))
		var u1 := minf(lerpf(a, b, float(mini(done, n - 1) + 1) / float(n)) + (b - a) * 0.2, b)
		_nudge(o, heap, st, u0, u1, at, DIG_SPREAD * 1.6)
		done += 1
		on = heap.on_it(id)
	(st["sounds"] as Array).append({"kind": "rummage", "u": a, "u1": b, "at": _flat(at, heap.height_at(at.x, at.y)), "strength": 0.6})


## PIECE [param id] moved from where it lies to a place near [param at], over shares [param a] to [param b] of [param st]: what lies on
## it first, or it would be left on air. A piece moved twice in a step goes on from where the first left it.
func _nudge(id: int, heap: AssemblyHeap, st: Dictionary, a: float, b: float, at: Vector2, spread: float) -> void:
	var q: Dictionary = pieces[id]
	for o in heap.on_it(id):
		_nudge(int(o), heap, st, a, b, at, spread)
	var x0 := _rest_xf(id)
	heap.take(id)
	var x1 := heap.deposit(id, float(q["w"]) * STUD, float(q["d"]) * STUD, _tall(String(q["kind"])), _rng, at + _around(spread), spread * 0.4)
	var seed := hash([seed_value, id, steps.size(), "nudge"])
	var seg := {"a": a, "b": b, "x0": x0, "x1": x1, "lift": lerpf(0.012, 0.035, Hands.share(seed, 3)), "seed": seed}
	for mv in st["moves"]:
		if int((mv as Dictionary)["id"]) == id:
			var segs: Array = (mv as Dictionary)["segs"]
			var last: Dictionary = segs[segs.size() - 1]
			var start := maxf(float(seg["a"]), float(last["b"]))
			# ...INSIDE ITS STEP: laid past the end, a move is never played, and the piece snaps to where it left it as the step ends.
			# With no room after it, its first move gives up the end of its time
			if start > MOVED_AGAIN:
				last["b"] = lerpf(float(last["a"]), float(last["b"]), 0.55)
				start = float(last["b"])
			seg["a"] = start
			seg["b"] = minf(maxf(float(seg["b"]), start + 0.04), 1.0)
			segs.append(seg)
			(q["rests"] as Array).append([steps.size() - 1, false, x1])
			return
	(st["moves"] as Array).append({"id": id, "segs": [seg]})
	(q["rests"] as Array).append([steps.size() - 1, false, x1])


func _around(r: float) -> Vector2:
	var a := _rng.randf() * TAU
	return Vector2(cos(a), sin(a)) * r * _rng.randf_range(0.5, 1.0)


func _rest_xf(id: int) -> Transform3D:
	var rests: Array = (pieces[id] as Dictionary)["rests"]
	var last: Array = rests[rests.size() - 1]
	return base_xf(_yaw) * (last[2] as Transform3D) if bool(last[1]) else last[2]


static func _flat(at: Vector2, y: float) -> Vector3:
	return Vector3(at.x, 0.0 if is_nan(y) else y, at.y)


func _part_half(q: Dictionary) -> float:
	return Vector2(float(q["w"]), float(q["d"])).length() * STUD * 0.5


## ITS WAY: `{lift, rise}`, what [method Hands.carried] needs to bring something from [param a] to [param b], clear of what stands
## under its way: up first clear of what it leaves, down last among what it goes to.
func _way(a: Vector3, b: Vector3, half: float, seed: int) -> Dictionary:
	var rise := Vector2(maxf(_top_at(a.x, a.z, half) + CLEAR_OVER - a.y, 0.0), maxf(_top_at(b.x, b.z, half) + CLEAR_OVER - b.y, 0.0))
	var lift := maxf(0.02, maxf(rise.x, rise.y) * 1.15)
	for _pass in 2:
		# ...looked at only where it is going across: before that it is still rising out of what it left, and after, coming down. The way
		# worked out here as [method Hands.carried] has it, its bow aside: that finds its span again each call, and this walks every step
		var span := Hands.across(lift, rise)
		var raised := false
		for k in range(1, WAY_LOOKS):
			var lin := lerpf(span.x, span.y, float(k) / float(WAY_LOOKS))
			var p := a.lerp(b, Hands.timing((lin - span.x) / maxf(span.y - span.x, 1e-6)))
			var need := _top_at(p.x, p.z, half) + CLEAR_OVER - (p.y + lift * Hands.lift_at(lin))
			if need > 0.0:
				lift += need / maxf(Hands.lift_at(lin), 0.35)
				raised = true
		if not raised:
			break
	return {"lift": minf(lift, LIFT_MOST), "rise": rise}


## A leg of a piece's way, a share of the step by its weight.
static func _leg(weight: float, x0: Transform3D, x1: Transform3D, lift := 0.0, seed := 0, rise := Vector2.ZERO, hold := 0.0) -> Dictionary:
	return {"w": weight, "x0": x0, "x1": x1, "lift": lift, "seed": seed, "rise": rise, "hold": hold}


## THE LEGS LAID INTO STEP [param st] as piece [param id]'s way, from share [param from]: the weights made shares of what is left.
## Each leg's sound (`sound`: its kind, at its end) goes with it.
func _commit(st: Dictionary, id: int, legs: Array, from := 0.0) -> void:
	var total := 0.0
	for l in legs:
		total += float((l as Dictionary)["w"])
	var u := from
	var segs: Array = []
	for l in legs:
		var ld: Dictionary = l
		var u1 := u + (1.0 - from) * float(ld["w"]) / maxf(total, 1e-6)
		if not ld.has("wait"):
			var s := ld.duplicate()
			s["a"] = u
			s["b"] = u1
			segs.append(s)
		if ld.has("sound"):
			var snd: Dictionary = (ld["sound"] as Dictionary).duplicate()
			snd["u"] = u1 if not bool(ld.get("sound_early", false)) else u
			(st["sounds"] as Array).append(snd)
		u = u1
	(st["moves"] as Array).append({"id": id, "segs": segs})


# ...the steps

func _put(op: Dictionary, batch := false) -> bool:
	var part := _part_of(op.get("part"))
	if part.is_empty():
		return false
	var at := _at(op.get("at"))
	if at.is_empty():
		return false
	var turn := _turn_of(op.get("turn"), part)
	var w := int(part["w"])
	var d := int(part["d"])
	var x := int(at["x"])
	var z := int(at["z"])
	var kind := String(part["kind"])
	var l := int(at["l"]) if int(at["l"]) >= 0 else level_for(w, d, turn, x, z)
	var f := fit(kind, w, d, turn, x, z, l)
	if not bool(f["ok"]):
		_problem("%s at [%d, %d] could not go on: %s" % [part_key(part), x, z, String(f["why"])])
		return false
	# ...a part of one stud has only the one: nothing to say of it
	if int(f["studs"]) == 1 and w * d > 1:
		_problem("%s at [%d, %d] holds by a single stud (it stays, but it would swing)" % [part_key(part), x, z])
	var brisk := String(op.get("pace", "")) == "brisk" or batch
	var row: Dictionary = OPS["put"]
	var nat := float((row["brisk"] as Array)[0]) if brisk else float(row["natural"])
	var least := float((row["brisk"] as Array)[1]) if brisk else float(row["floor"])
	var hover := clampf(_num(op.get("hover"), 0.0), 0.0, 60.0)
	var look := clampf(_num(op.get("look"), 0.0), 0.0, 60.0)
	var first: Array = op.get("first") if op.get("first") is Array else []
	var extra := hover + look + float(first.size()) * 2.5
	var st := _step("put", nat + extra, least + extra * 0.4)
	var stock := _stock_for(part, op.get("from", op.get("stock")))
	var id := _piece_from(part, stock, st, 0.14)
	if id < 0:
		_problem("%s: there is none in \"%s\"" % [part_key(part), stock])
		steps.pop_back()
		return false
	_seat(id, kind, w, d, turn, x, z, l)
	_counted("put")
	if _dry:
		return true
	var q: Dictionary = pieces[id]
	var seat := place_xf(x, z, l, w, d, turn)
	var world_seat := base_xf(_yaw) * seat
	var x0 := _last_world(id)
	var over := Transform3D(world_seat.basis, world_seat.origin + Vector3(0.0, HOVER, 0.0))
	var near := Transform3D(world_seat.basis, world_seat.origin + Vector3(0.0, PRESS_FROM, 0.0))
	var half := _part_half(q)
	var seed := hash([seed_value, steps.size(), "put"])
	var legs: Array = [{"w": REACH, "wait": true, "sound": {"kind": "tick", "at": x0.origin, "size": half, "strength": 0.35}}]
	var here := x0
	if look > 0.0:
		var shown := _view_xf(seed)
		var way := _way(here.origin, shown.origin, half, seed)
		legs.append(_leg(2.2, here, shown, float(way["lift"]), seed, way["rise"]))
		var turned := Transform3D(shown.basis * Basis(_axis(seed), deg_to_rad(lerpf(90.0, 200.0, Hands.share(seed, 21)))), shown.origin)
		legs.append(_leg(look, shown, turned, 0.0, seed, Vector2.ZERO, 3.0))
		here = turned
	for p in first:
		if p is Array and (p as Array).size() >= 2 and _is_num(p[0]) and _is_num(p[1]):
			var other := base_xf(_yaw) * place_xf(int(p[0]), int(p[1]), level_for(w, d, turn, int(p[0]), int(p[1])), w, d, turn)
			var over_it := Transform3D(other.basis, other.origin + Vector3(0.0, HOVER, 0.0))
			var way := _way(here.origin, over_it.origin, half, seed)
			legs.append(_leg(2.0, here, over_it, float(way["lift"]), seed, way["rise"]))
			legs.append(_leg(1.4, over_it, over_it, 0.0, seed, Vector2.ZERO, 3.0))
			here = over_it
	var way := _way(here.origin, over.origin, half, seed)
	legs.append(_leg(2.6, here, over, float(way["lift"]), seed, way["rise"]))
	legs.append(_leg(1.8 + hover, over, over, 0.0, seed, Vector2.ZERO, 2.0 if not brisk else 0.6))
	legs.append(_leg(1.1, over, near, 0.0, seed))
	var press := _leg(0.28, near, world_seat, 0.0, seed)
	press["sound"] = {"kind": "click", "at": world_seat.origin, "size": half, "strength": 1.0}
	legs.append(press)
	legs.append({"w": 0.4, "wait": true})
	_commit(st, id, legs)
	(q["rests"] as Array).append([steps.size() - 1, true, seat])
	return true


func _last_world(id: int) -> Transform3D:
	return _rest_xf(id)


## Near the lens, where a piece is held up to be looked at: facing it, at an angle of its own.
func _view_xf(seed: int) -> Transform3D:
	var at: Vector3 = world.get("view", (world["base_at"] as Vector3) + Vector3(0.0, 0.16, 0.08))
	var b := Basis(Vector3.UP, TAU * Hands.share(seed, 22)) * Basis(Vector3.RIGHT, deg_to_rad(lerpf(35.0, 70.0, Hands.share(seed, 23))))
	return Transform3D(b, at + Vector3(lerpf(-0.03, 0.03, Hands.share(seed, 24)), lerpf(-0.012, 0.012, Hands.share(seed, 25)), 0.0))


static func _axis(seed: int) -> Vector3:
	return Vector3(Hands.share(seed, 26) - 0.5, Hands.share(seed, 27) - 0.5, Hands.share(seed, 28) - 0.5).normalized()


## THE WAY BACK: where a piece held over [param here] goes after it was not used - onto a stock, or `aside` - a leg down onto it, its
## sound a small clack. In [param legs]; its place on the heap in the piece's rests.
func _back_to(id: int, to: Variant, here: Transform3D, legs: Array, seed: int) -> void:
	var q: Dictionary = pieces[id]
	var stock := String(to).strip_edges().to_lower() if to is String else String(_home.get(id, ""))
	var heap := _heap(stock)
	if heap == null:
		stock = String(_home.get(id, ""))
		heap = _heap(stock)
	if heap == null:
		return
	_file(id, stock)
	_home[id] = stock
	var aim: Vector2 = _left_at.get(id, heap.middle) if _heap_of_home_is(id, stock) else heap.middle
	var x1 := heap.deposit(id, float(q["w"]) * STUD, float(q["d"]) * STUD, _tall(String(q["kind"])), _rng, aim, 0.03)
	var way := _way(here.origin, x1.origin, _part_half(q), seed)
	var back := _leg(2.4, here, x1, float(way["lift"]), seed, way["rise"])
	back["sound"] = {"kind": "clack", "at": x1.origin, "size": _part_half(q), "strength": 0.5}
	legs.append(back)
	(q["rests"] as Array).append([steps.size() - 1, false, x1])


## Whether [param stock] is the heap piece [param id] was last taken from: put back, it lands about where it lay.
func _heap_of_home_is(id: int, stock: String) -> bool:
	if not _left_at.has(id) or _heap(stock) == null:
		return false
	var at: Vector2 = _left_at[id]
	return not is_nan(_heap(stock).height_at(at.x, at.y))


## In the dry pass, what [method _back_to] would do with piece [param id]: filed where it goes.
func _dry_back(id: int, to: Variant, stock: String) -> void:
	var nm := String(to).strip_edges().to_lower() if to is String else stock
	_file(id, nm if (_need as Dictionary).has(nm) else stock)


func _try(op: Dictionary) -> void:
	var part := _part_of(op.get("part"))
	if part.is_empty():
		return
	var at := _at(op.get("at"))
	if at.is_empty():
		return
	var turn := _turn_of(op.get("turn"), part)
	var w := int(part["w"])
	var d := int(part["d"])
	var x := int(at["x"])
	var z := int(at["z"])
	var kind := String(part["kind"])
	var l := int(at["l"]) if int(at["l"]) >= 0 else level_for(w, d, turn, x, z)
	var pressed: bool = op.get("press") == true and bool(fit(kind, w, d, turn, x, z, l)["ok"])
	if op.get("press") == true and not pressed:
		_problem("%s at [%d, %d] does not fit, so it is only held there" % [part_key(part), x, z])
	var row: Dictionary = OPS["try"]
	var st := _step("try", float(row["natural"]), float(row["floor"]))
	var stock := _stock_for(part, op.get("from"))
	var id := _piece_from(part, stock, st, 0.11)
	if id < 0:
		_problem("%s: there is none in \"%s\"" % [part_key(part), stock])
		steps.pop_back()
		return
	_counted("try")
	if _dry:
		_dry_back(id, op.get("to"), stock)
		return
	var q: Dictionary = pieces[id]
	var seat := base_xf(_yaw) * place_xf(x, z, l, w, d, turn)
	var x0 := _last_world(id)
	var half := _part_half(q)
	var seed := hash([seed_value, steps.size(), "try"])
	var over := Transform3D(seat.basis, seat.origin + Vector3(0.0, HOVER, 0.0))
	var near := Transform3D(seat.basis, seat.origin + Vector3(0.0, PRESS_FROM, 0.0))
	var way := _way(x0.origin, over.origin, half, seed)
	var legs: Array = [{"w": REACH, "wait": true, "sound": {"kind": "tick", "at": x0.origin, "size": half, "strength": 0.35}}]
	legs.append(_leg(2.4, x0, over, float(way["lift"]), seed, way["rise"]))
	legs.append(_leg(1.4, over, over, 0.0, seed, Vector2.ZERO, 2.0))
	legs.append(_leg(1.0, over, near, 0.0, seed))
	if pressed:
		var on := _leg(0.3, near, seat, 0.0, seed)
		on["sound"] = {"kind": "click", "at": seat.origin, "size": half, "strength": 0.9}
		legs.append(on)
		legs.append(_leg(1.0, seat, seat, 0.0, seed))
		var off := _leg(0.5, seat, near, 0.0, seed)
		off["sound"] = {"kind": "pop", "at": seat.origin, "size": half, "strength": 0.6}
		off["sound_early"] = true
		legs.append(off)
	else:
		var tap := _leg(0.8, near, near, 0.0, seed, Vector2.ZERO, 0.8)
		tap["sound"] = {"kind": "tick", "at": seat.origin, "size": half, "strength": 0.25}
		tap["sound_early"] = true
		legs.append(tap)
	legs.append(_leg(0.8, near, over, 0.0, seed))
	legs.append(_leg(1.2, over, over, 0.0, seed, Vector2.ZERO, 2.0))
	_back_to(id, op.get("to"), over, legs, seed)
	_commit(st, id, legs)


func _look_at(op: Dictionary) -> void:
	var part := _part_of(op.get("part"))
	if part.is_empty():
		return
	var seconds := clampf(_num(op.get("seconds"), 6.0), 1.0, 60.0)
	var st := _step("look", seconds + 4.5, seconds * 0.5 + 2.5)
	var stock := _stock_for(part, op.get("from"))
	var id := _piece_from(part, stock, st, 0.08)
	if id < 0:
		_problem("%s: there is none in \"%s\"" % [part_key(part), stock])
		steps.pop_back()
		return
	_counted("look")
	if _dry:
		_dry_back(id, op.get("to"), stock)
		return
	var q: Dictionary = pieces[id]
	var x0 := _last_world(id)
	var seed := hash([seed_value, steps.size(), "look"])
	var shown := _view_xf(seed)
	var turned := Transform3D(shown.basis * Basis(_axis(seed), deg_to_rad(lerpf(120.0, 260.0, Hands.share(seed, 21)))), shown.origin)
	var way := _way(x0.origin, shown.origin, _part_half(q), seed)
	var legs: Array = [{"w": REACH, "wait": true, "sound": {"kind": "tick", "at": x0.origin, "size": _part_half(q), "strength": 0.35}}]
	legs.append(_leg(2.2, x0, shown, float(way["lift"]), seed, way["rise"]))
	legs.append(_leg(seconds, shown, turned, 0.0, seed, Vector2.ZERO, 2.5))
	_back_to(id, op.get("to"), turned, legs, seed)
	_commit(st, id, legs)


func _dig(op: Dictionary) -> void:
	var seconds := clampf(_num(op.get("seconds"), 7.0), 1.0, 120.0)
	var st := _step("dig", seconds, seconds * 0.4)
	_counted("dig")
	var part := {}
	if op.get("for") != null:
		part = _part_of(op.get("for"))
	var stock := ""
	if op.get("in") is String:
		stock = String(op["in"]).strip_edges().to_lower()
	if stock.is_empty() or _heap(stock) == null:
		stock = _stock_for(part, null) if not part.is_empty() else _biggest_stock()
	if _dry:
		return
	var heap := _heap(stock)
	if heap == null:
		_problem("there is no stock to dig in")
		return
	# THE SPOT: where what it looks for lies, or anywhere; what is on top there goes aside, a few pieces a second of it
	var spot := heap.middle + _around(minf(0.1, heap.reach if heap.reach > 0.0 else 0.09))
	var sought := -1
	if not part.is_empty():
		for i in ((_by_key.get(stock, {}) as Dictionary).get(part_key(part), []) as Array):
			if heap.holds(int(i)):
				sought = int(i)
				spot = heap.where(sought)
				break
	var n := clampi(roundi(seconds * DIG_MOVES), DIG_LEAST, DIG_MOST)
	var moved := heap.on_top_near(spot, DIG_NEAR, n)
	for m in moved.size():
		if int(moved[m]) == sought:
			continue
		var u0 := 0.05 + 0.8 * float(m) / float(maxi(moved.size(), 1))
		var u1 := minf(u0 + 0.8 / float(maxi(moved.size(), 1)) + 0.1, 1.0)
		_nudge(int(moved[m]), heap, st, u0, u1, spot, DIG_SPREAD)
	if sought >= 0:
		_uncover(sought, heap, st, 0.1, 0.9)
	(st["sounds"] as Array).append({"kind": "rummage", "u": 0.04, "u1": 0.96, "at": _flat(spot, heap.height_at(spot.x, spot.y)), "strength": 1.0})


func _biggest_stock() -> String:
	var best := ""
	var most := -1
	for s in spec.get("stock", []):
		var nm := String((s as Dictionary)["name"])
		var n := (_fillers.get(nm, []) as Array).size()
		if n > most:
			most = n
			best = nm
	return best if not best.is_empty() else "aside"


func _piece_at(x: int, z: int, l: int) -> int:
	if l >= 0:
		var there: Variant = _cells.get(_key(x, z, l))
		return int(there) if there != null else -1
	for k in range(_top_level + 1, -1, -1):
		var there: Variant = _cells.get(_key(x, z, k))
		if there != null:
			return int(there)
	return -1


func _take(op: Dictionary) -> void:
	var at := _at(op.get("at"))
	if at.is_empty():
		return
	var id := _piece_at(int(at["x"]), int(at["z"]), int(at["l"]))
	if id < 0:
		_problem("nothing stands at [%d, %d] to take" % [int(at["x"]), int(at["z"])])
		return
	_counted("take")
	var chunk := _with_what_it_held([id])
	_bring_off(chunk, op.get("to"), "take")


## THE CHUNK [param chunk] OFF THE MODEL, a step of its own: it comes up as one, is carried over the stock, and comes apart as it
## falls in - the clatter. Each piece's place in the heap is its own.
func _bring_off(chunk: Array, into: Variant, what: String) -> void:
	var row: Dictionary = OPS[what]
	var n := float(chunk.size())
	var st := _step(what, float(row["natural"]) + (n - 1.0) * 0.4, float(row["floor"]) + (n - 1.0) * 0.1)
	var stock := String(into).strip_edges().to_lower() if into is String else ""
	if stock.is_empty() or _heap(stock) == null:
		if into is String and not stock.is_empty():
			_problem("no stock is called \"%s\": it goes to another" % stock)
		stock = String(_home.get(chunk[0], ""))
		if _heap(stock) == null:
			stock = _biggest_stock()
	var was := {}
	if not _dry:
		for id in chunk:
			var p: Dictionary = _placed[int(id)]
			was[id] = base_xf(_yaw) * place_xf(int(p["x"]), int(p["z"]), int(p["l"]), int(p["w"]), int(p["d"]), int(p["turn"]))
	for id in chunk:
		_unseat(int(id))
		_home[id] = stock
		_file(int(id), stock)
	if _dry:
		return
	var heap := _heap(stock)
	if heap == null:
		_problem("there is no stock for what comes off to go into")
		return
	var seed := hash([seed_value, steps.size(), what])
	# THE CHUNK AS ONE: the same way for every piece of it, kept apart by where each began
	var box_top := -INF
	var mid := Vector3.ZERO
	for id in chunk:
		box_top = maxf(box_top, (was[id] as Transform3D).origin.y)
		mid += (was[id] as Transform3D).origin
	mid /= n
	var drop_at := Vector3(heap.middle.x + (mid.x - heap.middle.x) * 0.15, 0.0, heap.middle.y + (mid.z - heap.middle.y) * 0.15)
	drop_at.y = maxf(heap.top(), _top_at(drop_at.x, drop_at.z, 0.02)) + DROP_FROM
	var up := 0.012
	var way := _way(mid + Vector3(0.0, up, 0.0), drop_at, 0.05, seed)
	var delay_most := 0.12
	var first := true
	for id in chunk:
		var q: Dictionary = pieces[int(id)]
		var x0: Transform3D = was[id]
		var off := x0.origin - mid
		var lifted := Transform3D(x0.basis, x0.origin + Vector3(0.0, up, 0.0))
		var over := Transform3D(x0.basis, drop_at + off)
		var pop := _leg(0.5, x0, lifted, 0.0, seed)
		var carry := _leg(3.0, lifted, over, float(way["lift"]), seed, way["rise"])
		if first:
			pop["sound"] = {"kind": "pop", "at": x0.origin, "size": _part_half(q), "strength": 0.9}
			pop["sound_early"] = true
		var x1 := heap.deposit(int(id), float(q["w"]) * STUD, float(q["d"]) * STUD, _tall(String(q["kind"])), _rng,
			Vector2(over.origin.x, over.origin.z) + _around(0.035), 0.03)
		(q["rests"] as Array).append([steps.size() - 1, false, x1])
		var legs: Array = [pop, carry, {"w": 1.0, "wait": true}]
		_commit(st, int(id), legs)
		# ...LET GO, in real time: a fall takes what a fall takes, however the step is paced
		var mv: Dictionary = (st["moves"] as Array)[(st["moves"] as Array).size() - 1]
		var share := 3.5 / 4.5
		var delay := Hands.share(hash([seed, id]), 31) * delay_most
		var dy := maxf(over.origin.y - x1.origin.y, 0.005)
		var secs := sqrt(2.0 * dy / 9.81) / FALL_SHARE
		(mv["segs"] as Array).append({"a": share, "delay": delay, "secs": secs, "fall": true, "x0": over, "x1": x1, "seed": hash([seed, id, "fall"])})
		(st["sounds"] as Array).append({"kind": "clack", "u": share, "after": delay + secs * FALL_SHARE, "at": x1.origin, "size": _part_half(q), "strength": lerpf(0.55, 1.0, Hands.share(hash([seed, id]), 32))})
		first = false


## How much of a fall's time it spends falling, the rest a small bounce and settling.
const FALL_SHARE := 0.62
## ...the bounce's height, against the fall's, and the most (meters); and how many turns it tumbles falling.
const BOUNCE := 0.1
const BOUNCE_MOST := 0.012
const TUMBLE := 0.8


func _wreck(op: Dictionary) -> void:
	var region: Array = []
	var above := int(op.get("above")) if _is_num(op.get("above")) else 0
	var bounded: bool = op.get("from") is Array and op.get("to") is Array and (op["from"] as Array).size() >= 2 and (op["to"] as Array).size() >= 2
	var lo := Vector2i(int(op["from"][0]), int(op["from"][1])) if bounded else Vector2i.ZERO
	var hi := Vector2i(int(op["to"][0]), int(op["to"][1])) if bounded else Vector2i.ZERO
	if bounded:
		var a := Vector2i(mini(lo.x, hi.x), mini(lo.y, hi.y))
		var b := Vector2i(maxi(lo.x, hi.x), maxi(lo.y, hi.y))
		lo = a
		hi = b
	for id in _placed:
		var p: Dictionary = _placed[id]
		if int(p["l"]) + int((KINDS[String(p["kind"])] as Dictionary)["h"]) <= above:
			continue
		if bounded:
			var size := turned_size(int(p["w"]), int(p["d"]), int(p["turn"]))
			var px := int(p["x"])
			var pz := int(p["z"])
			if px + size.x - 1 < lo.x or px > hi.x or pz + size.y - 1 < lo.y or pz > hi.y:
				continue
		region.append(id)
	if region.is_empty():
		_problem("nothing stands there to come down")
		return
	_counted("wreck")
	var into: Variant = op.get("into")
	if into == null:
		into = _biggest_stock()
	# FROM THE TOP DOWN, A HANDFUL AT A TIME: the highest piece, and what is joined to it nearby, and what then holds to nothing
	while not region.is_empty():
		var seed_id := -1
		var high := -1
		for id in region:
			var l := int((_placed[id] as Dictionary)["l"])
			if l > high:
				high = l
				seed_id = int(id)
		# ...THE SAME HANDFUL IN BOTH PASSES: where each chunk goes is where its first piece came from, so a draw of the walk's own
		# dice, which differ, sent the dry pass's pieces to other stocks than the real one's, and a part it found was not there
		var want := CHUNK.x + hash([seed_value, steps.size(), "chunk"]) % (CHUNK.y - CHUNK.x + 1)
		var chunk := [seed_id]
		var open := [seed_id]
		# ...what is joined to it no more than a course down, as long as that does not bring away more than a hand takes
		while not open.is_empty() and chunk.size() < want:
			var at: int = open.pop_back()
			for o in _joined(at):
				if chunk.size() >= want or not region.has(o) or chunk.has(o) or int((_placed[o] as Dictionary)["l"]) < high - 3:
					continue
				var bigger: Array = chunk + [o]
				if _with_what_it_held(bigger).size() <= want:
					chunk = bigger
					open.append(o)
		var whole := _with_what_it_held(chunk)
		_bring_off(whole, into, "wreck")
		for id in whole:
			region.erase(id)


## WHAT THE PLATE WOULD SWING INTO, turned from [param y0] to [param y1] radians: a thing standing on the table or a pile, by name, "" for
## nothing. A plate turned sweeps its corners out past its sides, and its corner had gone through a tub written beside it.
func _swept_into(y0: float, y1: float) -> String:
	var b: Vector3 = world["base_at"]
	var size: Array = (spec["base"] as Dictionary)["size"]
	var half := Vector2(float(size[0]), float(size[1])) * STUD * 0.5
	for k in SWEEP_LOOKS + 1:
		var yaw := lerpf(y0, y1, float(k) / float(SWEEP_LOOKS))
		for e in SWEEP_EDGE + 1:
			var u := float(e) / float(SWEEP_EDGE) * 2.0 - 1.0
			for local in [Vector2(u * half.x, -half.y), Vector2(u * half.x, half.y), Vector2(-half.x, u * half.y), Vector2(half.x, u * half.y)]:
				var p := Vector2(b.x + cos(yaw) * local.x + sin(yaw) * local.y, b.z - sin(yaw) * local.x + cos(yaw) * local.y)
				for ob in world.get("obstacles", []):
					var box: AABB = (ob as Dictionary)["box"]
					if p.x >= box.position.x and p.x <= box.end.x and p.y >= box.position.z and p.y <= box.end.z and box.position.y < b.y + BASE_T:
						return String((ob as Dictionary)["name"])
				for nm in (world.get("heaps", {}) as Dictionary):
					var heap: AssemblyHeap = (world["heaps"] as Dictionary)[nm]
					if heap.thing.is_empty() and String(nm) != "aside" and p.distance_to(heap.middle) < heap.reach:
						return "the pile \"%s\"" % String(nm)
	return ""


func _turn(op: Dictionary) -> void:
	var by := deg_to_rad(_num(op.get("by"), 90.0))
	var hit := _swept_into(_yaw, _yaw + by)
	if not hit.is_empty():
		_problem("the plate could not turn by %d degrees: it would swing into %s" % [roundi(rad_to_deg(by)), hit])
		return
	var row: Dictionary = OPS["turn"]
	var st := _step("turn", float(row["natural"]), float(row["floor"]))
	st["yaw"] = [_yaw, _yaw + by]
	(st["sounds"] as Array).append({"kind": "slide", "u": 0.12, "u1": 0.88, "at": world["base_at"], "strength": 0.6})
	_yaw += by
	_counted("turn")


func _wall(op: Dictionary) -> void:
	var part := _part_of(op.get("part"))
	if part.is_empty() or not (op.get("from") is Array and op.get("to") is Array) or (op["from"] as Array).size() < 2 or (op["to"] as Array).size() < 2:
		_problem("a wall is {part, from: [x, z], to: [x, z]}")
		return
	var a := Vector2i(int(op["from"][0]), int(op["from"][1]))
	var b := Vector2i(int(op["to"][0]), int(op["to"][1]))
	if a.x != b.x and a.y != b.y:
		_problem("a wall runs straight along x or along z: [%d, %d] to [%d, %d] does neither" % [a.x, a.y, b.x, b.y])
		return
	var along_x := a.y == b.y
	var lo := mini(a.x, b.x) if along_x else mini(a.y, b.y)
	var length := (absi(a.x - b.x) if along_x else absi(a.y - b.y)) + 1
	var fixed := a.y if along_x else a.x
	var wide := mini(int(part["w"]), int(part["d"]))
	var longest := maxi(int(part["w"]), int(part["d"]))
	var kind := String(part["kind"])
	var lengths := _lengths_of(kind, wide, longest)
	var courses := clampi(int(_num(op.get("courses"), 1.0)), 1, 40)
	var given := int(op.get("level")) if _is_num(op.get("level")) else -1
	var h := int((KINDS[kind] as Dictionary)["h"])
	var n := 0
	for c in courses:
		var level := given + c * h if given >= 0 else -1
		if level < 0:
			# on whatever is highest under the whole course
			level = 0
			for k in length:
				var cx := lo + k if along_x else fixed
				var cz := fixed if along_x else lo + k
				for j in wide:
					level = maxi(level, level_for(1, 1, 0, cx + (0 if along_x else j), cz + (j if along_x else 0)))
		var pos := 0
		var odd := c % 2 == 1
		while pos < length:
			var left := length - pos
			var len_now := int(lengths[0])
			if odd and pos == 0:
				len_now = _nearest_length(lengths, maxi(1, longest / 2))
			for ln in lengths:
				if int(ln) <= left and (int(ln) <= len_now):
					len_now = int(ln)
					break
			if len_now > left:
				len_now = _nearest_length(lengths, left)
			if len_now > left or len_now <= 0:
				_problem("the wall's last %d studs have no %s to close them" % [left, kind])
				break
			var w_now := mini(wide, len_now)
			var d_now := maxi(wide, len_now)
			var cx := lo + pos if along_x else fixed
			var cz := fixed if along_x else lo + pos
			var name_now := "%s %dx%d %s" % [kind, w_now, d_now, String(part["color"])]
			var ok := _put({"part": name_now, "at": [cx, cz, level], "turn": 90 if along_x else 0, "from": op.get("stock")}, true)
			if ok:
				n += 1
			pos += len_now


## The lengths a part of width [param wide] is made in, no longer than [param most], longest first.
static func _lengths_of(kind: String, wide: int, most: int) -> Array:
	var out: Array = []
	for s in (KINDS[kind] as Dictionary)["sizes"]:
		var a := mini(int((s as Array)[0]), int((s as Array)[1]))
		var b := maxi(int((s as Array)[0]), int((s as Array)[1]))
		if a == wide and b <= most and not out.has(b):
			out.append(b)
	out.sort()
	out.reverse()
	return out


static func _nearest_length(lengths: Array, want: int) -> int:
	for ln in lengths:
		if int(ln) <= want:
			return int(ln)
	return int(lengths[lengths.size() - 1]) if not lengths.is_empty() else 0


func _fill(op: Dictionary) -> void:
	var part := _part_of(op.get("part"))
	if part.is_empty() or not (op.get("from") is Array and op.get("to") is Array) or (op["from"] as Array).size() < 2 or (op["to"] as Array).size() < 2:
		_problem("a fill is {part, from: [x, z], to: [x, z]}")
		return
	var x0 := mini(int(op["from"][0]), int(op["to"][0]))
	var x1 := maxi(int(op["from"][0]), int(op["to"][0]))
	var z0 := mini(int(op["from"][1]), int(op["to"][1]))
	var z1 := maxi(int(op["from"][1]), int(op["to"][1]))
	var wide := mini(int(part["w"]), int(part["d"]))
	var longest := maxi(int(part["w"]), int(part["d"]))
	var kind := String(part["kind"])
	var given := int(op.get("level")) if _is_num(op.get("level")) else -1
	var level := given
	if level < 0:
		level = 0
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				level = maxi(level, level_for(1, 1, 0, x, z))
	var row := 0
	var z := z0
	while z <= z1:
		var this_wide := mini(wide, z1 - z + 1)
		var lengths := _lengths_of(kind, this_wide, longest)
		if lengths.is_empty():
			lengths = _lengths_of(kind, 1, longest)
			this_wide = 1
		if lengths.is_empty():
			_problem("a %s is not made %d wide" % [kind, this_wide])
			break
		var x := x0
		var odd := row % 2 == 1
		while x <= x1:
			var left := x1 - x + 1
			var ln := _nearest_length(lengths, left)
			if odd and x == x0:
				ln = _nearest_length(lengths, mini(left, maxi(1, longest / 2)))
			# ...AN ODD STUD LEFT, SHORTER THAN ANY PIECE THIS WIDE: closed one row at a time with what fits, never by running past the edge
			if ln > left or ln <= 0:
				var narrow := _lengths_of(kind, 1, left)
				if narrow.is_empty():
					_problem("the fill's last %d studs have no %s to cover them" % [left, kind])
					break
				var fits := int(narrow[0])
				for j in this_wide:
					_put({"part": "%s 1x%d %s" % [kind, fits, String(part["color"])], "at": [x, z + j, level], "turn": 90 if fits > 1 else 0, "from": op.get("stock")}, true)
				x += fits
				continue
			var name_now := "%s %dx%d %s" % [kind, mini(this_wide, ln), maxi(this_wide, ln), String(part["color"])]
			_put({"part": name_now, "at": [x, z, level], "turn": 90 if ln > this_wide else 0, "from": op.get("stock")}, true)
			x += ln
		z += this_wide
		row += 1


# --- what it comes to, in words ------------------------------------------------------------------------

## THE MODEL AS IT STANDS, level by level from the plate up: a letter a cell, the first of its color's name - lower case where it is a
## low part (a plate, a tile) - seen from above, far side first, x left to right. How an agent reads what it has made.
func model_text() -> String:
	if _placed.is_empty():
		return "The plate is empty."
	var lines := PackedStringArray()
	var box_lo := Vector2i(1 << 20, 1 << 20)
	var box_hi := Vector2i(-(1 << 20), -(1 << 20))
	var by_level := {}
	for id in _placed:
		var p: Dictionary = _placed[id]
		var kind := String(p["kind"])
		for c in cells_of(kind, int(p["w"]), int(p["d"]), int(p["turn"]), int(p["x"]), int(p["z"]), int(p["l"])):
			var l := int(c[2])
			if not by_level.has(l):
				by_level[l] = {}
			var letter := String((pieces[int(id)] as Dictionary)["color"]).left(1)
			(by_level[l] as Dictionary)[Vector2i(int(c[0]), int(c[1]))] = letter.to_upper() if int((KINDS[kind] as Dictionary)["h"]) > 1 else letter
			box_lo = Vector2i(mini(box_lo.x, int(c[0])), mini(box_lo.y, int(c[1])))
			box_hi = Vector2i(maxi(box_hi.x, int(c[0])), maxi(box_hi.y, int(c[1])))
	var levels: Array = by_level.keys()
	levels.sort()
	lines.append("%d pieces, x %d to %d, z %d to %d (far to near), up to level %d:" % [_placed.size(), box_lo.x, box_hi.x, box_lo.y, box_hi.y, int(levels[levels.size() - 1])])
	for l in levels:
		lines.append("level %d:" % int(l))
		var at: Dictionary = by_level[l]
		for z in range(box_lo.y, box_hi.y + 1):
			var row := ""
			for x in range(box_lo.x, box_hi.x + 1):
				row += String(at.get(Vector2i(x, z), "."))
			lines.append("  " + row)
	return "\n".join(lines)


## WHAT ACT [param name] COMES TO: what its steps did, what they could not, how long at an easy pace, and the model as it leaves it.
func report_of(name: String) -> PackedStringArray:
	var lines := PackedStringArray()
	if not spans.has(name):
		return lines
	var span: Array = spans[name]
	var natural := 0.0
	var least := 0.0
	for k in range(int(span[0]), int(span[1])):
		natural += float((steps[k] as Dictionary)["natural"])
		least += float((steps[k] as Dictionary)["floor"])
	var did := PackedStringArray()
	var c: Dictionary = counts.get(name, {})
	for k in c:
		did.append("%s x%d" % [String(k), int(c[k])])
	lines.append("It does: %s. %d steps; about %d s at an easy pace (%d s at the quickest it can go)." % [", ".join(did) if not did.is_empty() else "nothing", int(span[1]) - int(span[0]), roundi(natural), roundi(least)])
	for p in problems.get(name, []):
		lines.append("COULD NOT: " + String(p))
	lines.append(String(layers.get(name, "")))
	return lines


func natural_of(name: String) -> float:
	var out := 0.0
	var span: Array = spans.get(name, [0, 0])
	for k in range(int(span[0]), int(span[1])):
		out += float((steps[k] as Dictionary)["natural"])
	return out


func floor_of(name: String) -> float:
	var out := 0.0
	var span: Array = spans.get(name, [0, 0])
	for k in range(int(span[0]), int(span[1])):
		out += float((steps[k] as Dictionary)["floor"])
	return out


# --- time, laid over it --------------------------------------------------------------------------------

## HOW LONG A STEP'S SHARE OF THE LEFTOVER IS, against another's: a pause takes it up as a person would, stopped to look; any other
## step a little before it, a moment between pieces.
const GAP_PAUSE := 4.0
const GAP_OTHER := 1.0

## THE ACTS PLACED IN TIME: [param runs] `[{i, t0, t1}]` as [member TableWork.runs] has them, [param names] each act's name by its `i`,
## and what has begun by [param now] kept where it is - a live reading places acts again every sentence, and a piece in the
## air must not jump. A stretch given less than its floor overruns ([member TableWork.schedule] keeps the next act behind it).
func lay(runs: Array, acts: Array, now: float) -> void:
	if steps.is_empty():
		return
	for k in steps.size():
		if _t0[k] > now:
			_t0[k] = INF
			_t1[k] = INF
	# ...IN THE ORDER THEY WERE WALKED, whatever times they were handed: a piece can only go on from where the step before left it,
	# and [method step_at] looks steps up by time
	var ordered: Array = []
	for r in runs:
		var name := String((acts[int((r as Dictionary)["i"])] as Dictionary)["name"])
		if spans.has(name):
			ordered.append([int((spans[name] as Array)[0]), int((spans[name] as Array)[1]), float((r as Dictionary)["t0"]), float((r as Dictionary)["t1"])])
	ordered.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) < int(y[0]))
	var last_end := -INF
	for o in ordered:
		var from := maxf(float(o[2]), last_end)
		last_end = _lay_act(int(o[0]), int(o[1]), from, maxf(float(o[3]), from), now)
	# ...AND IN ORDER: a step passed over before one placed (an act nobody cued) takes no time, so what the lookups search stays sorted
	var after := INF
	for k in range(steps.size() - 1, -1, -1):
		if _t0[k] == INF and after != INF:
			_t0[k] = after
			_t1[k] = after
		elif _t0[k] != INF:
			after = _t0[k]


func _lay_act(k0: int, k1: int, t0: float, t1: float, now: float) -> float:
	var t := t0
	var k := k0
	while k < k1 and _t0[k] != INF and _t0[k] <= now:
		t = _t1[k]
		k += 1
	if k >= k1:
		return t
	var natural := 0.0
	var least := 0.0
	var weights := 0.0
	var w := PackedFloat32Array()
	for i in range(k, k1):
		var st: Dictionary = steps[i]
		natural += float(st["natural"])
		least += float(st["floor"])
		var g := GAP_PAUSE if String(st["do"]) == "pause" else GAP_OTHER * lerpf(0.3, 1.7, Hands.share(hash([seed_value, "gap"]), i))
		w.append(g)
		weights += g
	var left := t1 - t
	var pace := 0.0
	var spare := 0.0
	if left >= natural:
		pace = 1.0
		spare = left - natural
	elif natural > least:
		pace = clampf((left - least) / (natural - least), 0.0, 1.0)
	for i in range(k, k1):
		var st: Dictionary = steps[i]
		var d := lerpf(float(st["floor"]), float(st["natural"]), pace)
		var gap := spare * float(w[i - k]) / maxf(weights, 1e-6)
		if String(st["do"]) == "pause":
			d += gap
			gap = 0.0
		t += gap
		_t0[i] = t
		_t1[i] = t + d
		t += d
	return t


## The step going at [param t], or the last begun: -1 before the first.
func step_at(t: float) -> int:
	var lo := 0
	var hi := _t0.size() - 1
	var out := -1
	while lo <= hi:
		var mid := (lo + hi) / 2
		if _t0[mid] <= t:
			out = mid
			lo = mid + 1
		else:
			hi = mid - 1
	return out


## The plate's turn at [param t].
func yaw_at(t: float, k: int) -> float:
	var y := float(world.get("yaw", 0.0))
	for i in range(mini(k, steps.size() - 1), -1, -1):
		var st: Dictionary = steps[i]
		if st.has("yaw"):
			var ends: Array = st["yaw"]
			if t >= _t1[i]:
				return float(ends[1])
			return lerpf(float(ends[0]), float(ends[1]), Hands.smooth((t - _t0[i]) / maxf(_t1[i] - _t0[i], 1e-4)))
	return y


## PIECE [param id] AT [param t], where it is in the middle of a move or at rest: the world's pose. [param k], [param yaw]: the step
## at [param t] and the plate's turn then, for what asks many pieces at one moment.
func pose_of(id: int, t: float, k := -2, yaw := NAN) -> Transform3D:
	var kk := step_at(t) if k == -2 else k
	var y := yaw_at(t, kk) if is_nan(yaw) else yaw
	if kk >= 0:
		var st: Dictionary = steps[kk]
		if t < _t1[kk]:
			for mv in st["moves"]:
				if int((mv as Dictionary)["id"]) == id:
					return move_pose(mv as Dictionary, kk, t)
	var rests: Array = (pieces[id] as Dictionary)["rests"]
	var last: Array = rests[0]
	for r in rests:
		var step := int((r as Array)[0])
		if step > kk:
			break
		if step == kk and t < _t1[kk]:
			break
		last = r
	return base_xf(y) * (last[2] as Transform3D) if bool(last[1]) else last[2]


## WHERE A PIECE IS on move [param mv] of step [param k] at [param t]: its legs in the shares of the step they were laid in; a fall
## in real time from where it is let go, however the step is paced.
func move_pose(mv: Dictionary, k: int, t: float) -> Transform3D:
	var segs: Array = mv["segs"]
	var d := maxf(_t1[k] - _t0[k], 1e-4)
	var u := (t - _t0[k]) / d
	if segs.is_empty():
		return Transform3D.IDENTITY
	var first: Dictionary = segs[0]
	if u < float(first["a"]):
		return first["x0"]
	for s in segs:
		var sd: Dictionary = s
		if sd.has("fall"):
			var start := float(sd["a"]) * d + float(sd.get("delay", 0.0))
			var lin := ((t - _t0[k]) - start) / maxf(float(sd["secs"]), 1e-4)
			if lin < 0.0:
				return sd["x0"]
			return _fall_pose(sd, lin)
		if u <= float(sd["b"]):
			return seg_pose(sd, (u - float(sd["a"])) / maxf(float(sd["b"]) - float(sd["a"]), 1e-5), t)
	return (segs[segs.size() - 1] as Dictionary)["x1"]


## A STRETCH OF A HAND'S MOVE at [param lin] of it ([Hands]: minimum jerk, bowed, up clear first; held, never quite still). [param T]:
## show time, which a held thing's drift keeps.
static func seg_pose(s: Dictionary, lin: float, T: float) -> Transform3D:
	var x0: Transform3D = s["x0"]
	var x1: Transform3D = s["x1"]
	var seed := int(s.get("seed", 0))
	var p := Hands.carried(x0.origin, x1.origin, Vector3.ZERO, Vector3.ZERO, float(s.get("lift", 0.0)), lin, seed, s.get("rise", Vector2.ZERO))
	var q := Quaternion(x0.basis.orthonormalized()).slerp(Quaternion(x1.basis.orthonormalized()), Hands.smooth(lin))
	var b := Basis(q)
	var hold := float(s.get("hold", 0.0))
	if hold > 0.0:
		var dr: Array = Hands.drift(T, seed, hold * Hands.held(lin))
		p += dr[0] as Vector3
		b = (dr[1] as Basis) * b
	return Transform3D(b, p)


## A PIECE LET GO, at [param lin] of its fall: down under gravity, a small bounce where it lands, and turning over on the way into how
## it comes to lie.
static func _fall_pose(s: Dictionary, lin: float) -> Transform3D:
	var x0: Transform3D = s["x0"]
	var x1: Transform3D = s["x1"]
	if lin >= 1.0:
		return x1
	var f := FALL_SHARE
	var dy := x0.origin.y - x1.origin.y
	var p := Vector3.ZERO
	var settle := clampf(lin / (f + (1.0 - f) * 0.6), 0.0, 1.0)
	p.x = lerpf(x0.origin.x, x1.origin.x, settle)
	p.z = lerpf(x0.origin.z, x1.origin.z, settle)
	if lin < f:
		var v := lin / f
		p.y = lerpf(x0.origin.y, x1.origin.y, v * v)
	else:
		var v := (lin - f) / (1.0 - f)
		p.y = x1.origin.y + minf(absf(dy) * BOUNCE, BOUNCE_MOST) * 4.0 * v * (1.0 - v)
	var seed := int(s.get("seed", 0))
	var q := Quaternion(x0.basis.orthonormalized()).slerp(Quaternion(x1.basis.orthonormalized()), Hands.smooth(settle))
	var spin := Basis(_axis(seed), TUMBLE * TAU * (1.0 - settle) * (1.0 if Hands.share(seed, 40) < 0.5 else -1.0))
	return Transform3D(spin * Basis(q), p)


## WHAT IS HEARD between [param t0] and [param t1]: `[{t, kind, at, size, strength}]`, in the step's own time, a dig's rummage as
## many small knocks as it makes. The same moments every time they are asked for, so a render and a scrub hear the same.
func sounds_in(t0: float, t1: float) -> Array:
	var out: Array = []
	var k := step_at(t1)
	while k >= 0:
		if _t1[k] + 1.5 < t0:
			break
		var st: Dictionary = steps[k]
		var d := maxf(_t1[k] - _t0[k], 1e-4)
		for s in st["sounds"]:
			var sd: Dictionary = s
			var at_t := _t0[k] + float(sd["u"]) * d + float(sd.get("after", 0.0))
			if sd.has("u1"):
				_spread_sound(sd, k, at_t, _t0[k] + float(sd["u1"]) * d, t0, t1, out)
			elif at_t >= t0 and at_t < t1:
				out.append({"t": at_t, "kind": String(sd["kind"]), "at": sd.get("at", Vector3.ZERO), "size": float(sd.get("size", 0.02)), "strength": float(sd.get("strength", 1.0))})
		k -= 1
	return out


## HOW OFTEN a rummage knocks (a second, at its fullest), and how many at once at most, for each second of it: not in a beat.
const RUMMAGE_RATE := 16.0

## A rummage or a slide, its knocks at moments drawn from the step's seed - a rummage in bursts as a hand goes in, stirs and comes back,
## never a steady rattle. Those from [param from_t] to [param to_t] that fall within [param t0] and [param t1].
func _spread_sound(sd: Dictionary, k: int, from_t: float, to_t: float, t0: float, t1: float, out: Array) -> void:
	var a := maxf(from_t, t0)
	var b := minf(to_t, t1)
	if b <= a:
		return
	var rate := RUMMAGE_RATE * float(sd.get("strength", 1.0)) if String(sd["kind"]) == "rummage" else 6.0
	var i0 := int(floor(a * rate))
	var i1 := int(ceil(b * rate))
	for i in range(i0, i1):
		var seed := hash([seed_value, k, i])
		var when := (float(i) + Hands.share(seed, 1)) / rate
		if when < a or when >= b:
			continue
		# ...in bursts: slow waves of how busy the hand is
		var busy := 0.5 + 0.5 * sin(when * 1.7 + float(k)) * sin(when * 0.61 + 2.0 * float(k))
		if Hands.share(seed, 2) > busy * 0.9 + 0.1:
			continue
		var kind := "knock" if String(sd["kind"]) == "rummage" else "scuff"
		out.append({"t": when, "kind": kind, "at": sd.get("at", Vector3.ZERO), "size": lerpf(0.006, 0.024, Hands.share(seed, 3)), "strength": lerpf(0.25, 1.0, pow(Hands.share(seed, 4), 2.0)) * float(sd.get("strength", 1.0))})
