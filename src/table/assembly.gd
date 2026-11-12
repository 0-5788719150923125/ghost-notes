extends RefCounted
class_name Assembly

## Assembly - a thing built of many small parts on a lattice (next/assembly.md): bricks on studs, from what the agents write.
##
## This is the plan and the clock, never the motion. [method perform] walks the steps once for what can be said without touching a brick:
## what fits where, what could not be done, what each act comes to in words, how many of each part a stock must hold. What the pieces
## then do is real: [AssemblyBake] runs every step on real bodies in a second process ([AssemblyWorld]) and writes it down
## ([AssemblyTrack]). Nothing here says where a piece is going.
##
## The lattice: a cell is taken or it is not, a stud holds or it does not, and what it refuses it refuses in words ([method fit]).
## Pressed home, a piece is part of the model; a solver has nothing to add to that.
##
## The agent says what, the hand finds where: a step names a part and a stud; which piece of the tub it is, what is in the way, how
## high it goes and how far it rises are found when it happens. There is always a piece of the part asked for: what the steps need
## is added to the stock before anything lands ([method perform]'s dry pass).
##
## Slow by stopping, never by slowing ([method lay]): the record runs at a hand's pace on its own clock with stops in it, and a
## reader's words and silences say how long a stretch is. More time than a step needs goes into its stops. A fall always takes the
## time a fall takes.
##
## What is built is designed first ([AssemblyModel]): a table's `model` is every part in the order it goes on, and the steps say how
## someone gets there - how much at a time, what goes wrong, what comes off again. What comes off is owed again. A hand that leaves
## anything undone has it done before its last act ([constant OPS] `finish`, [method with_finish]), so the last thing on the table is
## always the whole of it.
##
## A preview needs no bodies: a puppeteer's `act` and `model`, and the set dresser's table, see where things rest by this walk alone
## ([method pose_of]).

## The lattice (meters): a stud's pitch, a plate's height, how high a stud stands, and how thick the baseplate is.
const STUD := 0.008
const PLATE := 0.0032
const STUD_H := 0.0018
const BASE_T := 0.0014
## The kinds of part: `h` its height in plates, `studs` where it has them on top (all, none, or only along its back row), `sizes` the
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
## The steps of a build, each what the hands do: `natural` seconds at an easy pace, `floor` hurried, its words an agent's.
const OPS := {
	"dig": {"label": "Dig", "natural": 7.0, "floor": 3.0,
		"blurb": "the hands really go into a heap: fingers dragged through it, a handful flipped over and falling back with a clatter, the top of it pushed aside, with stops to look at what that turned up. It is half of what a person does at a tub, it is heard, and it is worth its time",
		"fields": [["in", "the stock's name (left out: where the next piece comes from)"], ["for", "a part it is looking for, which it digs nearer as it goes on (left out: only looking)"],
			["seconds", "how long (left out: 7)"]]},
	"put": {"label": "Put", "natural": 11.0, "floor": 5.0, "brisk": [5.0, 3.2], "model": "none",
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
		"blurb": "a stretch of the model pulled apart from the top down, chunk by chunk, each chunk let fall into a stock where it comes apart with a clatter. Six seconds a chunk at an easy pace. Written with nothing else it takes the whole model and the plate is empty again",
		"fields": [["from", "[x, z] one corner of what comes down (left out: all of it)"], ["to", "[x, z] the other corner"], ["above", "the level it comes down to: what stands below it stays (left out: all the way)"],
			["into", "the stock it goes into (left out: the biggest)"]]},
	"turn": {"label": "Turn", "natural": 7.0, "floor": 4.0,
		"blurb": "the whole plate turned on the table, to see another side of it. Studs keep their numbers: x and z are the plate's own, however it is turned",
		"fields": [["by", "degrees (left out: 90)"]]},
	"build": {"label": "Build", "natural": 5.0, "floor": 3.2, "model": "only",
		"blurb": "the next parts of the model go on, in the order a hand would lay them: each found in the stock, brought over and pressed home, the hands in a rhythm with a hesitation here and there. About five seconds a piece. Anything that came off is laid again first",
		"fields": [["parts", "how many, or \"rest\" for all that are left of what it is working on (left out: 10)"], ["section", "one of the model's sections to work on (left out: whatever comes next)"], ["pace", "\"easy\": about eleven seconds a piece, each considered (left out: the rhythm)"], ["from", "the stock they come from (left out: the one with most of their color)"]]},
	"wrong": {"label": "Wrong", "natural": 9.0, "floor": 5.0, "model": "only",
		"blurb": "the next parts go on wrong, in plain view: a stud off, turned the wrong way, or the wrong color, and they stay until they are noticed. `undo` takes them off; failing that, each comes off as soon as its proper place is wanted",
		"fields": [["parts", "how many (left out: 1)"]]},
	"undo": {"label": "Undo", "natural": 7.0, "floor": 3.0, "model": "only",
		"blurb": "what went on last comes off again, the newest first, back into the stock: a mistake put right, or a stretch that was not good enough and will be done again. Whatever comes off is owed: the next `build` lays it first",
		"fields": [["parts", "how many of the last to go on (left out: whatever is on it wrongly)"]]},
	"finish": {"label": "Finish", "natural": 5.0, "floor": 3.2, "model": "unsaid", "blurb": "whatever of the model does not yet stand is built, and whatever is on it wrongly comes off", "fields": []},
	"wall": {"label": "Wall", "natural": 5.0, "floor": 3.2, "model": "none",
		"blurb": "a run of the same part along a straight line, course on course with its joints staggered, the hands in a rhythm: the shorter sizes of the same part close the ends. A long wall is many pieces and takes its time, at about five seconds each",
		"fields": [["part", "the longest piece of it: \"brick 2x4 tan\""], ["from", "[x, z] the first stud of the line"], ["to", "[x, z] the last, straight along x or along z"], ["courses", "how many, one on another (left out: 1)"], ["level", "how high the first goes (left out: on what is there)"],
			["stock", "the stock its pieces come from"]]},
	"fill": {"label": "Fill", "natural": 5.0, "floor": 3.2, "model": "none",
		"blurb": "a rectangle covered with one part, its rows staggered, the hands in a rhythm: a floor, a roof, a yard. At about five seconds a piece",
		"fields": [["part", "the largest piece of it: \"plate 2x4 gray\""], ["from", "[x, z] one corner"], ["to", "[x, z] the other"], ["level", "how high (left out: on what is there)"], ["stock", "the stock its pieces come from"]]},
}
## How often a part of the model is hesitated over, and held up and looked at first, as they go on ([method _lay_part]).
const HESITATES := 0.1
const LOOKS_FIRST := 0.05
## What those come to, on top of a part's own time.
const BUILD_MORE := 1.08
## A plate's turn looked at for what it would swing into: this many places on the way, this many along each of its sides.
const SWEEP_LOOKS := 8
const SWEEP_EDGE := 8
## How far the time of a step varies by its seed.
const VARY := Vector2(0.9, 1.2)
## A hand's limit on one chunk of what comes down, and how many pieces of what comes down it takes at once.
const CHUNK := Vector2i(2, 7)
## The most steps an act writes (a `wall` or a `fill` is one, however many pieces), and a table's stock: places, colors, pieces
## in one place and in all.
const MAX_OPS := 120
const MAX_SOURCES := 8
const MAX_COLORS := 24
const MOST_IN_SOURCE := 800
const MOST_PIECES := 1800
## How much of a stock's mixed filling stays however much a model wants of it: a tub of only what is wanted is no tub to dig in.
const FILLERS_LEAST := 0.2
## How big a baseplate may be, in studs; how big it is unless written.
const BASE_SIZES := Vector2i(8, 48)
const BASE_SIZE := 32
## Pieces it takes to cover a square meter of a heap, one deep (a mixed lot's mean footprint). For a container: pieces per cubic meter
## lying as they fall (measured), and how deep a full one is filled, over a false floor ([method TableAssembly._heap_of]): deep enough
## to be dug in.
const PER_M2 := 1900.0
const DEEP := 1.7
const PER_M3 := 70000.0
const IN_DEEP := 0.075
## How much commoner a lot's small sizes are than its big: the power its pick along a kind's sizes is drawn at.
const LOT_SMALL := 3.2
## The default colors of a mixed lot, when a table names none (a share each).
const COLORS := {"red": "#b3261e", "blue": "#1f4f9c", "yellow": "#e8b512", "white": "#ece8dc", "black": "#23252a", "gray": "#8b8d8f", "green": "#2a7a41", "tan": "#c9b185"}

var spec := {}
var seed_value := 0
var world := {}                   # {base_at: Vector3, yaw: radians, heaps: {name: AssemblyHeap}, obstacles: [{box, name}], lens: Transform3D, fov: degrees}
var pieces: Array = []            # each {id, kind, w, d, color, stock, rests: [[step, in_model, xf]]}
var steps: Array = []             # each {act, do, natural, floor, and what [AssemblyBake] needs of it}
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
var _rng := RandomNumberGenerator.new()
var _act := ""
var _t0 := PackedFloat64Array()   # when in the show each step begins, INF until placed
var _t1 := PackedFloat64Array()
var _len := PackedFloat32Array()  # how many seconds of a step are moving
var _stops: Array = []            # a step's stops: [[its offset, natural seconds, least, weight]...]
var _stop_d: Array = []           # how long each of a step's stops lasts in the show
var model := {}                   # what is being built ([AssemblyModel.make]): its parts in order, or {} where it was never designed
var _part_index := {}             # where a part of the model goes -> which it is
var _stand_of := {}               # a part of the model -> the piece standing as it
var _part_of_piece := {}          # ...and back
var _off_model := {}              # a piece on the plate that is no part of the model
var _laid: Array = []             # what is on the plate, in the order it went on
var _hand: Array = []             # what a step has in hand: {id, from, to, knots: [[its offset, room]...]} ([method AssemblyBake._in_hand]), or {}
var _tau0 := PackedFloat32Array() # where a step begins on the record: NAN until it is there


# --- the words -------------------------------------------------------------------------------------

## What can be done, as a puppeteer reads it: the kinds, the steps and their fields.
static func describe(with_model := false) -> String:
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
		var goes := String(row.get("model", ""))
		if goes == "unsaid" or (goes == "none" and with_model) or (goes == "only" and not with_model):
			continue
		lines.append("- %s (%d s): %s." % [k, roundi(float(row["natural"])), String(row["blurb"])])
		for f in row["fields"]:
			lines.append("    `%s`: %s" % [String(f[0]), String(f[1])])
	if with_model:
		lines.append("In `try` and `look`, leave out `at` and it is the place of the next part the model wants; leave out `part` and it is that part (in a `try`, a near miss for it: another size, or another color).")
	return "\n".join(lines)


## What a set dresser writes of it, in words.
static func describe_stock() -> String:
	var lines := PackedStringArray()
	lines.append("`assembly`, beside `things` and `light`: what is built on this table, and where the pieces wait. {")
	lines.append("  \"colors\": {\"its name\": \"#rrggbb\", ...} - every color the pieces come in, up to %d, named as the work will name them;" % MAX_COLORS)
	lines.append("  \"base\": {\"size\": [across, deep] studs, %d to %d (left out: %d), \"color\": a color's name, \"at\": [x, z] cm where its middle stands (left out: the middle of the picture), \"turn\": degrees} - what the build grows on;" % [BASE_SIZES.x, BASE_SIZES.y, BASE_SIZE])
	lines.append("  \"stock\": [each place the pieces wait, up to %d - {\"name\": what the work calls it, and where it is: \"thing\": the name of a hollow thing you built, an open tub, box, crate or tray, and it is filled (\"fill\" 0-1, how full; left out: 0.85), or \"at\": [x, z] cm and \"radius\": cm, a loose pile on the table itself; \"count\": how many pieces at most (left out: as many as it takes), \"colors\": {a color's name: how common} (left out: all alike), \"kinds\": {a kind's name: how common} (left out: a mixed lot, as %s)}]" % [MAX_SOURCES, ", ".join(PackedStringArray(KINDS.keys()))])
	lines.append("}. Where the show has a model designed, its plate's size and color and its colors are already the model's and need not be written: say where the plate stands and where the pieces wait. The pieces are drawn for you, as real as the things are: you never make a thing for a brick. A container must be really hollow, its inside wide and open (a thing with a `lathe` or walls of `box` parts, and no lid), and it stays where it stands. What is dug in is half of what is watched: stand the stock it comes from so its open top is whole in the picture, near enough to see into, and if that leaves too little room for the plate, write a smaller plate. The plate turns: nothing stands where its corners swing, which the blueprint keeps clear. What is asked for later is added to the stock by itself, so a stock is a look and a feel: a mixed tub, a pile, a tray of one color.")
	return "\n".join(lines)


# --- what an agent wrote, made safe ---------------------------------------------------------------------

## The table's `assembly`, made safe: `{}` where it has none.
static func sanitize(raw: Variant, notes: PackedStringArray = PackedStringArray()) -> Dictionary:
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return {}
	var d: Dictionary = raw
	var out := {"colors": {}, "stock": []}
	var colors: Dictionary = d.get("colors") if d.get("colors") is Dictionary else COLORS
	# ...a model brings its own colors and its plate ([AssemblyModel]): the table's come after
	var designed: Dictionary = d.get("model") if d.get("model") is Dictionary and not (d.get("model") as Dictionary).is_empty() else {}
	if not designed.is_empty():
		var both: Dictionary = (designed["colors"] as Dictionary).duplicate()
		for k in colors:
			if not both.has(String(k).strip_edges().to_lower()):
				both[k] = colors[k]
		colors = both
		out["model"] = designed
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
	var base: Dictionary = (d.get("base") as Dictionary).duplicate() if d.get("base") is Dictionary else {}
	if not designed.is_empty():
		base["size"] = designed["size"]
		base["color"] = designed["base_color"]
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


## A part as written, "brick 2x4 red": `{kind, w, d, color, swap}` (`swap`: written the other way round from how it is made, so it is
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


## The steps of an act, made safe: each `{do, ...}` it could use. What could not be used is in [param notes].
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
			"build":
				# ...its hesitations ([constant HESITATES]) come on top of its rhythm
				var many := 40.0 if d.get("parts") is String else _num(d.get("parts"), 10.0)
				n *= maxf(1.0, many) * BUILD_MORE
			"wrong", "undo":
				n *= maxf(1.0, _num(d.get("parts"), 1.0))
			"finish":
				n *= _num(d.get("owed"), 0.0) * BUILD_MORE
		out += n
	return out


## The acts of [param d] as an agent wrote them, with whatever a hand leaves undone ([constant OPS] `finish`) added as the first step
## of the last act that builds, in reading order. It costs nothing where all of it stands.
## Given the [param designed] model, it says how much is owed, so whoever times the words knows what the last act takes.
static func with_finish(d: Dictionary, designed := {}) -> Dictionary:
	var acts: Array = d.get("acts") if d.get("acts") is Array else []
	var ranked: Array = []
	for i in acts.size():
		if not (acts[i] is Dictionary):
			continue
		var builds := false
		var tracks: Variant = (acts[i] as Dictionary).get("tracks")
		for t in (tracks if tracks is Array else []):
			if t is Dictionary and String((t as Dictionary).get("law", "")) == "assemble":
				builds = true
		if not builds:
			continue
		var beat := str((acts[i] as Dictionary).get("beat", ""))
		ranked.append([0 if beat == "intro" else (1000000 if beat == "close" else int(beat) if beat.is_valid_int() else 0), i])
	if ranked.is_empty():
		return d
	# ...in the order they are done: by beat, and as written within one
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	var last_at := int((ranked[ranked.size() - 1] as Array)[1])
	var finish := {}
	for t in (acts[last_at] as Dictionary)["tracks"]:
		if t is Dictionary and String((t as Dictionary).get("law", "")) == "assemble":
			var ops: Array = (t as Dictionary).get("ops") if (t as Dictionary).get("ops") is Array else []
			if ops.is_empty() or not (ops[0] is Dictionary) or String((ops[0] as Dictionary).get("do", "")) != "finish":
				ops.push_front({"do": "finish"})
			(t as Dictionary)["ops"] = ops
			finish = ops[0]
			break
	if not designed.is_empty() and not finish.is_empty():
		var script: Array = []
		for r in ranked:
			var a: Dictionary = acts[int((r as Array)[1])]
			var ops: Array = []
			for t in a["tracks"]:
				if t is Dictionary and String((t as Dictionary).get("law", "")) == "assemble":
					for op in ((t as Dictionary).get("ops", []) as Array):
						if op is Dictionary and String((op as Dictionary).get("do", "")) != "finish":
							ops.append(op)
			script.append({"name": str(a.get("name", "")), "ops": sanitize_ops(ops, PackedStringArray())})
		finish["owed"] = _owed_after(script, designed)
	return d


## How many parts of the model [param designed] do not stand once [param script] is done: the plan's own walk over a stand-in for the table, for nothing of how it goes depends on where the table's things are.
static func _owed_after(script: Array, designed: Dictionary) -> int:
	var a := Assembly.new()
	a.seed_value = 1
	a.spec = {"colors": designed["colors"], "base": {"size": designed["size"], "color": String(designed["base_color"]), "turn": 0.0}, "stock": [{"name": "stock", "colors": {}, "kinds": {"brick": 1.0}, "count": 0}], "model": designed}
	a.world = {"base_at": Vector3.ZERO, "yaw": 0.0, "heaps": {"stock": AssemblyHeap.pile("stock", Vector2(-0.5, 0.0), 0.1), "aside": AssemblyHeap.pile("aside", Vector2(0.5, 0.0), 0.05)}, "obstacles": []}
	a.perform(script)
	return (designed["parts"] as Array).size() - a._stand_of.size()


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


## Where on the plate a piece goes: its pose on the model, from the plate's middle, its origin the middle of its underside.
func place_xf(x: int, z: int, l: int, w: int, d: int, turn: int) -> Transform3D:
	return xf_on((spec["base"] as Dictionary)["size"], x, z, l, w, d, turn)


## ...on a plate of [param base] studs.
static func xf_on(base: Array, x: int, z: int, l: int, w: int, d: int, turn: int) -> Transform3D:
	var size := turned_size(w, d, turn)
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


## Whether a part goes there, and how it holds: `{ok, why, studs}` - `why` says what is wrong, in words an agent can act on. A cell is
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


## What would come away with [param gone] taken off: those, and whatever nothing else then holds to the plate.
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
	if not model.is_empty():
		_laid.append(id)
		var part: Variant = _part_index.get(_where_key(kind, w, d, turn, x, z, l, String((pieces[id] as Dictionary)["color"])))
		if part != null and not _stand_of.has(part):
			_stand_of[part] = id
			_part_of_piece[id] = part
		else:
			_off_model[id] = true


## Where a part goes, as a name: what it is and how it lies.
static func _where_key(kind: String, w: int, d: int, turn: int, x: int, z: int, l: int, color: String) -> String:
	return "%s %d %d %d %d %d %d %s" % [kind, w, d, posmod(turn, 360), x, z, l, color]


func _unseat(id: int) -> void:
	if not model.is_empty():
		_laid.erase(id)
		_off_model.erase(id)
		if _part_of_piece.has(id):
			_stand_of.erase(_part_of_piece[id])
			_part_of_piece.erase(id)
	var p: Dictionary = _placed[id]
	for c in cells_of(String(p["kind"]), int(p["w"]), int(p["d"]), int(p["turn"]), int(p["x"]), int(p["z"]), int(p["l"])):
		_cells.erase(_key(int(c[0]), int(c[1]), int(c[2])))
	_placed.erase(id)


# --- the walk ----------------------------------------------------------------------------------------

## The build: acts [param acts] (`[{name, ops}]`, in the order they are done) walked twice. Once dry, to learn what the steps ask of
## each stock that it does not hold, and once for real, the stock laid down first with what is asked for soonest on top. What fits,
## what is said of it and how much of each part is wanted come out of this; time and motion do not ([method lay], [AssemblyBake]).
func perform(acts: Array) -> void:
	model = spec.get("model", {}) if spec.get("model") is Dictionary else {}
	_part_index = {}
	for i in (model.get("parts", []) as Array).size():
		var q: Dictionary = model["parts"][i]
		_part_index[_where_key(String(q["kind"]), int(q["w"]), int(q["d"]), int(q["turn"]), int(q["x"]), int(q["z"]), int(q["l"]), String(q["color"]))] = i
	_make_fillers()
	_dry_pass(acts)
	# ...a stock holds what it holds, and what a model wants of it takes the place of a mixed lot's filling (a tub is never only what is wanted)
	if not model.is_empty():
		var trimmed := false
		for nm in _fillers:
			var had: Array = _fillers[nm]
			var keep := maxi(had.size() - (_need.get(nm, []) as Array).size(), ceili(float(had.size()) * FILLERS_LEAST))
			if keep < had.size():
				_fillers[nm] = had.slice(0, keep)
				trimmed = true
		if trimmed:
			_dry_pass(acts)
	_dry = false
	_rng.seed = hash([seed_value, "assembly"])
	_lay_stock()
	_walk(acts)
	_plan_times()


func _dry_pass(acts: Array) -> void:
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


func _walk(acts: Array) -> void:
	_stand_of = {}
	_part_of_piece = {}
	_off_model = {}
	_laid = []
	_cells = {}
	_placed = {}
	_top_level = 0
	_home = {}
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
			layers[_act] = progress_text() if not model.is_empty() else model_text()


func _add_piece(p: Dictionary, stock: String) -> int:
	var id := pieces.size()
	pieces.append({"id": id, "kind": String(p["kind"]), "w": int(p["w"]), "d": int(p["d"]), "color": String(p["color"]), "stock": stock, "rests": []})
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


## What each stock holds to begin with: a lot as written, by its shares of colors and kinds, sized by the place it fills unless its
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
			n = count_for(area, heap != null and not heap.thing.is_empty(), heap.deep if heap != null else 0.0)
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


## How many pieces fill a place of [param area] square meters: a pile, about two deep; a container, as deep as can be dug in, up to the [param deep] meters
## its walls let it hold: a shallow tin's are many fewer than a tub's.
static func count_for(area: float, container: bool, deep: float) -> int:
	return clampi(roundi(area * (PER_M3 * minf(IN_DEEP, deep) if container else PER_M2 * DEEP)), 12, MOST_IN_SOURCE)


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


## The stock laid down, for real: what it holds to begin with, then what the steps asked for and it did not hold, soonest on top.
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
	var st := {"act": _act, "do": what, "natural": natural * v, "floor": least}
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
		"build":
			_build(op)
		"wrong":
			_wrong(op)
		"undo":
			_undo(op)
		"finish":
			_finish(op)


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

## A piece of [param part] out of stock [param stock], for the plan: any will do, since which it really is is found when it happens
## ([method AssemblyBake._fetch]). Short in the dry pass, it is written down to be there ([member _need]).
func _piece_from(part: Dictionary, stock: String) -> int:
	var key := part_key(part)
	if not _by_key.has(stock):
		_by_key[stock] = {}
	var ids: Array = (_by_key[stock] as Dictionary).get(key, [])
	if ids.is_empty():
		if not _dry:
			return -1
		(_need[stock] as Array).append({"kind": String(part["kind"]), "w": int(part["w"]), "d": int(part["d"]), "color": String(part["color"])})
		var made := pieces.size()
		pieces.append({"id": made, "kind": String(part["kind"]), "w": int(part["w"]), "d": int(part["d"]), "color": String(part["color"]), "stock": stock, "rests": []})
		_home[made] = stock
		return made
	var id: int = ids.pop_back()
	_home[id] = stock
	if not _dry and _heap(stock) != null:
		_heap(stock).take(id)
	return id


## A piece goes back into [param stock]: where the plan draws it, until the record says where it really landed.
func _into_stock(id: int, stock: String) -> void:
	_file(id, stock)
	_home[id] = stock
	if _dry:
		return
	var heap := _heap(stock)
	if heap == null:
		return
	var q: Dictionary = pieces[id]
	(q["rests"] as Array).append([steps.size() - 1, false, heap.deposit(id, float(q["w"]) * STUD, float(q["d"]) * STUD, _tall(String(q["kind"])), _rng)])


## Where a piece goes after it was not used: [param to] if that is a stock, else where it came from.
func _back_stock(to: Variant, from: String) -> String:
	var nm := String(to).strip_edges().to_lower() if to is String else ""
	return nm if not nm.is_empty() and _heap(nm) != null else from


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
	if int(f["studs"]) == 1 and w * d > 1 and model.is_empty():
		_problem("%s at [%d, %d] holds by a single stud (it stays, but it would swing)" % [part_key(part), x, z])
	var brisk := String(op.get("pace", "")) == "brisk" or batch
	var row: Dictionary = OPS["put"]
	var nat := float((row["brisk"] as Array)[0]) if brisk else float(row["natural"])
	var least := float((row["brisk"] as Array)[1]) if brisk else float(row["floor"])
	var hover := clampf(_num(op.get("hover"), 0.0), 0.0, 60.0)
	var look := clampf(_num(op.get("look"), 0.0), 0.0, 60.0)
	var first: Array = op.get("first") if op.get("first") is Array else []
	var extra := hover + look + float(first.size()) * 2.5
	var st := _step("put", nat + extra, least + extra * 0.3)
	var stock := _stock_for(part, op.get("from", op.get("stock")))
	var id := _piece_from(part, stock)
	if id < 0:
		_problem("%s: there is none in \"%s\"" % [part_key(part), stock])
		steps.pop_back()
		return false
	var elsewhere: Array = []
	for p in first:
		if p is Array and (p as Array).size() >= 2 and _is_num(p[0]) and _is_num(p[1]):
			elsewhere.append([int(p[0]), int(p[1]), level_for(w, d, turn, int(p[0]), int(p[1]))])
	st.merge({"key": part_key(part), "stock": stock, "slot": id, "x": x, "z": z, "l": l, "turn": turn, "w": w, "d": d, "brisk": brisk, "hover": hover, "look": look, "first": elsewhere})
	_seat(id, kind, w, d, turn, x, z, l)
	_counted("put")
	if not _dry:
		((pieces[id] as Dictionary)["rests"] as Array).append([steps.size() - 1, true, place_xf(x, z, l, w, d, turn)])
	return true


func _try(raw_op: Dictionary) -> void:
	var op := _toward_next(raw_op, true)
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
	var id := _piece_from(part, stock)
	if id < 0:
		_problem("%s: there is none in \"%s\"" % [part_key(part), stock])
		steps.pop_back()
		return
	var to := _back_stock(op.get("to"), stock)
	st.merge({"key": part_key(part), "stock": stock, "to": to, "x": x, "z": z, "l": l, "turn": turn, "w": w, "d": d, "pressed": pressed})
	_counted("try")
	_into_stock(id, to)


func _look_at(raw_op: Dictionary) -> void:
	var op := _toward_next(raw_op, false)
	var part := _part_of(op.get("part"))
	if part.is_empty():
		return
	var seconds := clampf(_num(op.get("seconds"), 6.0), 1.0, 60.0)
	var st := _step("look", seconds + 4.5, 3.8)
	var stock := _stock_for(part, op.get("from"))
	var id := _piece_from(part, stock)
	if id < 0:
		_problem("%s: there is none in \"%s\"" % [part_key(part), stock])
		steps.pop_back()
		return
	var to := _back_stock(op.get("to"), stock)
	st.merge({"key": part_key(part), "stock": stock, "to": to, "seconds": seconds})
	_counted("look")
	_into_stock(id, to)


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
	if _heap(stock) == null:
		_problem("there is no stock to dig in")
	st.merge({"stock": stock, "seconds": seconds, "part_key": part_key(part) if not part.is_empty() else ""})


# ...what is designed

## What comes next of the model: which part, or -1 when all of it stands.
func _next_part(section := -1) -> int:
	var parts: Array = model.get("parts", [])
	for i in parts.size():
		if not _stand_of.has(i) and (section < 0 or int((parts[i] as Dictionary)["section"]) == section):
			return i
	return -1


## [param op] where it says no part or no place: the next the model wants, and for a [param miss], not quite that part.
func _toward_next(op: Dictionary, miss: bool) -> Dictionary:
	if model.is_empty() or (op.get("part") != null and (op.get("at") != null or not miss)):
		return op
	var i := _next_part()
	if i < 0:
		return op
	var q: Dictionary = model["parts"][i]
	var out := op.duplicate()
	if out.get("at") == null:
		out["at"] = [int(q["x"]), int(q["z"]), int(q["l"])]
		if out.get("turn") == null:
			out["turn"] = int(q["turn"])
	if out.get("part") == null:
		out["part"] = _near_miss(q, i) if miss else part_key(q)
	return out


## Another size of the same kind, or the same part in another color.
func _near_miss(q: Dictionary, i: int) -> String:
	var hs := hash([seed_value, "miss", i])
	var sizes: Array = (KINDS[String(q["kind"])] as Dictionary)["sizes"]
	if Hands.share(hs, 1) < 0.5 and sizes.size() > 1:
		var s: Array = sizes[int(Hands.share(hs, 2) * float(sizes.size())) % sizes.size()]
		if int(s[0]) != int(q["w"]) or int(s[1]) != int(q["d"]):
			return "%s %dx%d %s" % [String(q["kind"]), int(s[0]), int(s[1]), String(q["color"])]
	var names: Array = (spec["colors"] as Dictionary).keys()
	var other := String(names[int(Hands.share(hs, 3) * float(names.size())) % names.size()])
	return "%s %dx%d %s" % [String(q["kind"]), int(q["w"]), int(q["d"]), other]


func _section_called(raw: Variant) -> int:
	if not (raw is String):
		return -1
	var want := String(raw).strip_edges().to_lower()
	var secs: Array = model.get("sections", [])
	for i in secs.size():
		if String((secs[i] as Dictionary)["name"]) == want:
			return i
	var names := PackedStringArray()
	for s in secs:
		names.append(String((s as Dictionary)["name"]))
	_problem("no section is called \"%s\" (%s)" % [want, ", ".join(names)])
	return -1


func _build(op: Dictionary) -> void:
	if model.is_empty():
		_problem("there is no model to build: `put` what goes on")
		return
	var sec := _section_called(op.get("section"))
	var rest: bool = op.get("parts") is String
	var want := (model["parts"] as Array).size() if rest else clampi(int(_num(op.get("parts"), 10.0)), 1, 400)
	var done := 0
	var stuck := 0
	var parts: Array = model["parts"]
	for i in parts.size():
		if done >= want:
			break
		if _stand_of.has(i) or (sec >= 0 and int((parts[i] as Dictionary)["section"]) != sec):
			continue
		if _lay_part(i, op):
			done += 1
		else:
			stuck += 1
	_counted("build", done)
	if stuck > 0:
		_problem("%d parts of it have nothing to hold on to yet: what they stand on is not there" % stuck)


## Part [param i] of the model goes on: with whatever is wrongly in its place off first, and now and then a moment's hesitation, the same each time for the same part.
func _lay_part(i: int, op: Dictionary) -> bool:
	var q: Dictionary = model["parts"][i]
	var kind := String(q["kind"])
	var w := int(q["w"])
	var d := int(q["d"])
	var turn := int(q["turn"])
	var x := int(q["x"])
	var z := int(q["z"])
	var l := int(q["l"])
	for c in cells_of(kind, w, d, turn, x, z, l):
		var there: Variant = _cells.get(_key(int(c[0]), int(c[1]), int(c[2])))
		if there == null:
			continue
		if _part_of_piece.has(int(there)):
			return false
		_bring_off(_with_what_it_held([int(there)]), null, "take")
	if not bool(fit(kind, w, d, turn, x, z, l)["ok"]):
		return false
	var hs := hash([seed_value, "hesitate", i])
	var share := Hands.share(hs, 1)
	var put := {"part": part_key(q), "at": [x, z, l], "turn": turn}
	if op.get("from") != null:
		put["from"] = op.get("from")
	if share < HESITATES:
		put["hover"] = lerpf(1.0, 3.5, Hands.share(hs, 2))
	elif share < HESITATES + LOOKS_FIRST:
		put["look"] = lerpf(2.0, 5.0, Hands.share(hs, 3))
	return _put(put, String(op.get("pace", "")) != "easy")


## The next parts go on wrong: whichever way fits, a stud off, turned, or the wrong color in the right place. They are no part of the model, and it says so.
func _wrong(op: Dictionary) -> void:
	if model.is_empty():
		_problem("there is no model to get wrong")
		return
	var want := clampi(int(_num(op.get("parts"), 1.0)), 1, 12)
	var done := 0
	var parts: Array = model["parts"]
	for i in parts.size():
		if done >= want:
			break
		if _stand_of.has(i):
			continue
		var way := _wrong_way(parts[i] as Dictionary, hash([seed_value, "wrong", i]))
		if not way.is_empty() and _put(way, false):
			done += 1
	_counted("wrong", done)
	if done < want:
		_problem("only %d of them could go on wrong: nothing near would hold them" % done)


func _wrong_way(q: Dictionary, hs: int) -> Dictionary:
	var kind := String(q["kind"])
	var w := int(q["w"])
	var d := int(q["d"])
	var turn := int(q["turn"])
	var x := int(q["x"])
	var z := int(q["z"])
	var l := int(q["l"])
	var tries: Array = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 90], [1, 1, 0], [-1, -1, 0]]
	var from := int(Hands.share(hs, 1) * float(tries.size()))
	for k in tries.size():
		var t: Array = tries[(from + k) % tries.size()]
		var turned := turn + int(t[2])
		if int(t[2]) != 0 and w == d:
			continue
		if bool(fit(kind, w, d, turned, x + int(t[0]), z + int(t[1]), l)["ok"]):
			return {"part": part_key(q), "at": [x + int(t[0]), z + int(t[1]), l], "turn": turned}
	var names: Array = (spec["colors"] as Dictionary).keys()
	for k in names.size():
		var other := String(names[(int(Hands.share(hs, 2) * float(names.size())) + k) % names.size()])
		if other != String(q["color"]) and bool(fit(kind, w, d, turn, x, z, l)["ok"]):
			return {"part": "%s %dx%d %s" % [kind, w, d, other], "at": [x, z, l], "turn": turn}
	return {}


func _undo(op: Dictionary) -> void:
	var order: Array = []
	if op.get("parts") != null:
		order = _laid.slice(maxi(_laid.size() - clampi(int(_num(op.get("parts"), 1.0)), 1, 400), 0))
	else:
		for id in _laid:
			if _off_model.has(id):
				order.append(id)
	if order.is_empty():
		_problem("there is nothing to take off")
		return
	order.reverse()
	var n := 0
	for id in order:
		if _placed.has(int(id)):
			_bring_off(_with_what_it_held([int(id)]), null, "take")
			n += 1
	_counted("undo", n)


## Whatever is wrong comes off, and whatever is owed goes on ([method with_finish]): the model stands whole after this, however the steps before it went.
func _finish(op: Dictionary) -> void:
	if model.is_empty():
		return
	var wrong: Array = _off_model.keys()
	wrong.reverse()
	for id in wrong:
		if _placed.has(int(id)):
			_bring_off(_with_what_it_held([int(id)]), null, "take")
	if _next_part() >= 0:
		_build({"parts": "rest", "from": op.get("from")})


## How the model stands, for whoever is staging its build: how much of it, section by section.
func progress_text() -> String:
	var parts: Array = model.get("parts", [])
	var by := {}
	for i in _stand_of:
		var sec := int((parts[int(i)] as Dictionary)["section"])
		by[sec] = int(by.get(sec, 0)) + 1
	var lines := PackedStringArray()
	lines.append("The model now stands at %d of %d parts (%d still to go, about %d minutes at the rhythm):" % [_stand_of.size(), parts.size(), parts.size() - _stand_of.size(), roundi(float(parts.size() - _stand_of.size()) * float((OPS["build"] as Dictionary)["natural"]) / 60.0)])
	var secs: Array = model.get("sections", [])
	for i in secs.size():
		lines.append("  %s: %d of %d" % [String((secs[i] as Dictionary)["name"]), int(by.get(i, 0)), int((secs[i] as Dictionary)["parts"])])
	if not _off_model.is_empty():
		lines.append("  and %d on it wrongly, which must come off." % _off_model.size())
	return "\n".join(lines)


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


## The chunk [param chunk] off the model, a step of its own: it comes up as one, is carried over the stock and let go.
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
	st.merge({"slots": chunk.duplicate(), "stock": stock})
	for id in chunk:
		_unseat(int(id))
		_into_stock(int(id), stock)


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
	# from the top down, a handful at a time: the highest piece, what is joined to it nearby, then what holds to nothing
	while not region.is_empty():
		var seed_id := -1
		var high := -1
		for id in region:
			var l := int((_placed[id] as Dictionary)["l"])
			if l > high:
				high = l
				seed_id = int(id)
		# ...the same handful in both passes: where each chunk goes is where its first piece came from, so the dry pass and the real one
		# send pieces to the same stocks
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


## What the plate would swing into, turned from [param y0] to [param y1] radians: a thing standing on the table or a pile, by name,
## "" for nothing. A plate turned sweeps its corners out past its sides.
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
	st.merge({"y0": _yaw, "y1": _yaw + by})
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
			# ...an odd stud left, shorter than any piece this wide: closed one row at a time with what fits, never by running past the edge
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

## The model as it stands, level by level from the plate up: a letter a cell, the first of its color's name (lower case for a low
## part: a plate, a tile), seen from above, far side first, x left to right. How an agent reads what it has made.
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


## What act [param name] comes to: what its steps did, what they could not, how long at an easy pace, and the model as it leaves it.
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

## How long a stop's share of the leftover is, against another's: a pause takes it up as a person would, stopped to look.
const GAP_PAUSE := 4.0
const GAP_OTHER := 1.0

## What the plan knows of a step's time, before the record has it: how long its moves take at the least, and the rest one stop as it begins.
func _plan_times() -> void:
	var n := steps.size()
	_t0 = PackedFloat64Array()
	_t1 = PackedFloat64Array()
	_t0.resize(n)
	_t1.resize(n)
	_t0.fill(INF)
	_t1.fill(INF)
	_len = PackedFloat32Array()
	_len.resize(n)
	_tau0 = PackedFloat32Array()
	_tau0.resize(n)
	_tau0.fill(NAN)
	_stops = []
	_stops.resize(n)
	_stop_d = []
	_stop_d.resize(n)
	_hand = []
	_hand.resize(n)
	_hand.fill({})
	for k in n:
		var st: Dictionary = steps[k]
		var floors := float(st["floor"])
		var natural := float(st["natural"])
		if String(st["do"]) == "pause":
			_len[k] = 0.0
			_stops[k] = [[0.0, natural, floors, GAP_PAUSE]]
		else:
			_len[k] = floors
			_stops[k] = [[0.0, maxf(natural - floors, 0.0), 0.0, GAP_OTHER]]
		_stop_d[k] = PackedFloat32Array([0.0])


## What the record says of step [param k] ([method AssemblyBake._share_stops]): it replaces what the plan guessed, and it is placed again.
func take_record(k: int, st: Dictionary) -> void:
	if k < 0 or k >= steps.size():
		return
	_len[k] = float(st["t1"]) - float(st["t0"])
	_tau0[k] = float(st["t0"])
	_stops[k] = st["stops"]
	_hand[k] = st.get("hand", {})
	var ds := PackedFloat32Array()
	ds.resize((st["stops"] as Array).size())
	_stop_d[k] = ds
	_t0[k] = INF
	_t1[k] = INF


## The acts placed in time: [param runs] `[{i, t0, t1}]` as [member TableWork.runs] has them, [param names] each act's name by its
## `i`, and what has begun by [param now] kept where it is (a live reading places acts again every sentence; a piece in the air
## must not jump). A stretch given less than its moves take overruns ([member TableWork.schedule] keeps the next act behind it).
func lay(runs: Array, acts: Array, now: float) -> void:
	if steps.is_empty():
		return
	for k in steps.size():
		if _t0[k] > now:
			_t0[k] = INF
			_t1[k] = INF
	# ...in the order they were walked, whatever times they were handed: a piece can only go on from where the step before left it,
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
	# ...and in order: a step passed over before one placed (an act nobody cued) takes no time, so what the lookups search stays sorted
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
	for i in range(k, k1):
		natural += _len[i]
		least += _len[i]
		for s in _stops[i]:
			natural += float((s as Array)[1])
			least += float((s as Array)[2])
			weights += float((s as Array)[3])
	var left := t1 - t
	var pace := 0.0
	var spare := 0.0
	if left >= natural:
		pace = 1.0
		spare = left - natural
	elif natural > least:
		pace = clampf((left - least) / (natural - least), 0.0, 1.0)
	for i in range(k, k1):
		var ds := PackedFloat32Array()
		var sum := 0.0
		for s in _stops[i]:
			var a: Array = s
			var d := lerpf(float(a[2]), float(a[1]), pace) + spare * float(a[3]) / maxf(weights, 1e-6)
			ds.append(d)
			sum += d
		_stop_d[i] = ds
		_t0[i] = t
		_t1[i] = t + _len[i] + sum
		t = _t1[i]
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


## How far into its own moves step [param k] is at [param t]: its stops take time and no record.
func offset_in(k: int, t: float) -> float:
	var e := t - _t0[k]
	var stops: Array = _stops[k]
	var ds: PackedFloat32Array = _stop_d[k]
	for i in stops.size():
		var o := float((stops[i] as Array)[0])
		if e <= o:
			return maxf(e, 0.0)
		var d := float(ds[i]) if i < ds.size() else 0.0
		if e <= o + d:
			return o
		e -= d
	return minf(e, _len[k])


## Where on the record [param t] falls: -1 before the first step, and NAN at a step the record does not hold yet.
func tau_at(t: float) -> float:
	var k := step_at(t)
	if k < 0:
		return -1.0
	if is_nan(_tau0[k]):
		return NAN
	return _tau0[k] + offset_in(k, t)


## What is in hand at [param t], from the grip until it is seated or let go, stops and moves alike: `{id, h, left, room, back, free,
## seed}` for [method Fingers.on] - how long it has been in hand and has to go, the room the hand has now, how far it has drawn back,
## and how long of it all its fingers have had room - or `{}`. Only the record stops: a hand holding a thing is never still. Worked
## out from the stops as they are laid, so it is the same however the show got to [param t].
func held_at(t: float) -> Dictionary:
	var k := step_at(t)
	if k < 0 or k >= _hand.size() or (_hand[k] as Dictionary).is_empty():
		return {}
	var hand: Dictionary = _hand[k]
	var from := float(hand["from"])
	var to := float(hand["to"])
	var stops: Array = _stops[k]
	var ds: PackedFloat32Array = _stop_d[k]
	var e := t - _t0[k]
	var shown_from := from
	var shown_to := to
	for i in stops.size():
		var d := float(ds[i]) if i < ds.size() else 0.0
		if float((stops[i] as Array)[0]) <= from:
			shown_from += d
		if float((stops[i] as Array)[0]) <= to:
			shown_to += d
	if e <= shown_from or e >= shown_to:
		return {}
	var knots: Array = hand["knots"]
	var o := offset_in(k, t)
	var room := room_at(knots, o)
	var back := 0.0
	var free := 0.0
	for i in range(1, knots.size()):
		if float((knots[i - 1] as Array)[1]) >= 1.0 and float((knots[i] as Array)[1]) >= 1.0:
			free += clampf(o, float((knots[i - 1] as Array)[0]), float((knots[i] as Array)[0])) - float((knots[i - 1] as Array)[0])
	var rem := e
	for i in stops.size():
		var oi := float((stops[i] as Array)[0])
		var d := float(ds[i]) if i < ds.size() else 0.0
		if rem <= oi:
			break
		var s := minf(rem - oi, d)
		if oi >= from and oi <= to:
			var r := room_at(knots, oi)
			if r >= 1.0:
				free += s
			elif r >= Fingers.BACK_FROM and r < Fingers.OVER_THINGS.x:
				free += Fingers.free_in(s, d)
				if s < d:
					back = Fingers.drawn_back(s, d)
					room = maxf(room, back)
		if s < d:
			break
		rem -= d
	return {"id": int(hand["id"]), "h": e - shown_from, "left": shown_to - e, "room": room, "back": back, "free": free, "seed": hash([seed_value, k, "fingers"])}


## The room a hand has at offset [param o] of its step, between the [param knots] the record left.
static func room_at(knots: Array, o: float) -> float:
	var last: Array = knots[0]
	if o <= float(last[0]):
		return float(last[1])
	for kn in knots:
		var a: Array = kn
		if o <= float(a[0]):
			return lerpf(float(last[1]), float(a[1]), Hands.smooth((o - float(last[0])) / maxf(float(a[0]) - float(last[0]), 1e-5)))
		last = a
	return float(last[1])


## The plate's turn at [param t], for what the plan alone knows ([member AssemblyTrack.turns] has what really happened).
func yaw_at(t: float, k: int) -> float:
	var y := float(world.get("yaw", 0.0))
	for i in range(mini(k, steps.size() - 1), -1, -1):
		var st: Dictionary = steps[i]
		if st.has("y1"):
			if t >= _t1[i]:
				return float(st["y1"])
			return lerpf(float(st["y0"]), float(st["y1"]), Hands.smooth((t - _t0[i]) / maxf(_t1[i] - _t0[i], 1e-4)))
	return y


## Where the plan has piece [param id] at [param t], with no record to say: where it last came to rest. [param k], [param yaw]: the step at
## [param t] and the plate's turn then, for what asks many pieces at one moment.
func pose_of(id: int, t: float, k := -2, yaw := NAN) -> Transform3D:
	var kk := step_at(t) if k == -2 else k
	var y := yaw_at(t, kk) if is_nan(yaw) else yaw
	var rests: Array = (pieces[id] as Dictionary)["rests"]
	if rests.is_empty():
		return Transform3D.IDENTITY
	var last: Array = rests[0]
	for r in rests:
		if int((r as Array)[0]) > kk:
			break
		last = r
	return base_xf(y) * (last[2] as Transform3D) if bool(last[1]) else last[2]


## What a record depends on, step by step: one name for each step, made from every step up to it, so what is already written can be gone on from
## and a change to an act redoes only what comes after it.
func step_names(from: int) -> PackedInt64Array:
	var out := PackedInt64Array()
	out.resize(steps.size())
	var h := from
	for k in steps.size():
		h = hash([h, var_to_str(steps[k])])
		out[k] = h & 0x7FFFFFFFFFFFFFFF
	return out
