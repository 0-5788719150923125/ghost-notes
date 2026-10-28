extends RefCounted
class_name DeskLook

## DeskLook - what an episode's desk is made of and how it is lit, drawn from its seed ([DeskMedium]):
## the pad's paper, rules and binding, the ink, the pen, the desk's top and a mat on it, the lamp, and a
## few things lying about.
##
## EVERY DESK HAS A LOOK OF ITS OWN (the user, 2026-10-19: "this mode would benefit a lot from a little
## bit of variety, of color, of the table, of objects on the table, etc. We could definitely borrow from
## the cards mechanisms ... It would be very nice if the table could have a proper texture"). Every
## episode was the same brown noise under the same pad. Now the top is built as the card table's is
## ([Tables]: boards with their grain and seams, stone, lacquer, leather or baize, the relief raked by
## the lamp), a mat may lie under the pad ([constant Tables.FABRICS]), and the things on the desk are
## made as the card table's are ([Props]), each [constant THINGS] row a desk thing's shape, its sizes
## and colors drawn here. Every value is drawn from a range, each kind of choice from its own hash of
## the seed ([method _rng]), so adding a choice never moves the others.
##
## NOTHING HERE IS PAINTED (the user, 2026-10-19: "There is nowhere to set the 'Painter' on the Proof
## card; so how would the generative table and props even work there?"): a top's grain, a stone's
## veins, a mat's weave and every thing are shapes and shader patterns from the numbers drawn here. The
## card table's one surface an agent paints - a top or a layer that IS the episode's painting, and the
## reading cloth [method Tables.sanitize] lays when it is handed no layers - is never chosen, so a desk
## needs no painter and no agent (proof_check holds it).
##
## THE DESK IS LIT AS A TABLE IS (2026-10-27, the user: "some nice ambient lighting, maybe some open-flame light
## sources, which cast nice shadows ... akin to what the agents produce in True Tarot episodes ... leverage the
## Table primitives"): each desk has a MOOD ([constant MOODS]) - the lamp at night, candles, a window's daylight,
## a low sun at dusk - and the light it writes is the card table's ([Lights]: the sky's fill, the sun or the moon
## through a window, lamps out of the shot), drawn here as the set dresser would write it and built by
## [DeskLight]; the candles it puts on the desk are things like any other ([Props], a wick on the wax), their flames
## the table's. Before, every desk had one spot lamp over the same flat warm fill.
##
## WHAT IS ON THE DESK STAYS OUT OF THE PEN'S WAY AND THE PAGES': nothing on the pad or behind it (the
## turned pages lie there, [LegalPad]), nothing tall beside the pad's right edge, where the pen leans
## out as it writes and waits ([constant DeskMedium.PARK]), and nothing tall in front of it, where the
## camera looks over it ([method _placed]).

## THE THINGS a desk may have. `tall`: kept back from the pad (it would stand in the pen's or the
## camera's way); `weight`: how often it is chosen among the things lying about - none for a candle, which
## its desk's mood sets down ([constant MOODS]); `lit`: it burns.
const THINGS := {
	"mug": {"label": "a mug", "blurb": "A glazed mug, often with coffee or tea in it, its handle any way round.", "tall": true, "weight": 3.0},
	"pencil": {"label": "a pencil", "blurb": "A hexagonal pencil lying down, sharpened, an eraser in a metal band at its end.", "tall": false, "weight": 3.0},
	"pencil_cup": {"label": "a cup of pencils", "blurb": "A cup holding a few pencils, leaning.", "tall": true, "weight": 1.5},
	"eraser": {"label": "an eraser", "blurb": "A block eraser, its edges worn round.", "tall": false, "weight": 2.0},
	"books": {"label": "books", "blurb": "One to three hardbacks lying in a stack, each a little askew.", "tall": false, "weight": 2.5},
	"clips": {"label": "paper clips", "blurb": "A few bent-wire clips lying loose.", "tall": false, "weight": 1.5},
	"cards": {"label": "index cards", "blurb": "A stack of index cards or a pad of sticky notes.", "tall": false, "weight": 1.5},
	"ruler": {"label": "a ruler", "blurb": "A straight ruler of wood or steel.", "tall": false, "weight": 1.0},
	"cactus": {"label": "a cactus", "blurb": "A small ribbed cactus in a clay pot.", "tall": true, "weight": 1.0},
	"taper": {"label": "a candle", "blurb": "A taper burning in a candlestick of brass, pewter, glazed clay or turned wood, its wax dripping.", "tall": true, "weight": 0.0, "lit": true},
	"pillar": {"label": "a pillar candle", "blurb": "A thick candle burning on a small dish, one wick or a few.", "tall": true, "weight": 0.0, "lit": true},
	"tealights": {"label": "tea lights", "blurb": "Two or three tea lights burning in their tins on a saucer.", "tall": false, "weight": 0.0, "lit": true},
}
## THE DESK'S MOOD: how it is lit, each a row - `weight` how often, `lamp` the share of the desk lamp's light
## that is on (0 off), `candles` how many burn on the desk ([least, most]) and whether one of them is the KEY,
## lighting the page as the lamp would (`leads`). The rest of the light is the room's ([method _light]).
const MOODS := {
	"lamplight": {"label": "Lamplight", "blurb": "Night: the desk lamp lights the page, the room dark round it - a screen's glow, a street lamp, a fire, the moon in a window.",
		"weight": 4.0, "lamp": 1.0, "candles": [0, 1], "leads": false},
	"candlelight": {"label": "Candlelight", "blurb": "Night with the lamp off: candles on the desk light the page, their shadows moving with their flames.",
		"weight": 2.5, "lamp": 0.0, "candles": [1, 2], "leads": true},
	"daylight": {"label": "Daylight", "blurb": "Day: the sun falls through a window across the desk, the bars' shadows over it, the sky filling the room.",
		"weight": 2.0, "lamp": 0.0, "candles": [0, 0], "leads": false},
	"dusk": {"label": "Dusk", "blurb": "Evening: a low gold sun through the window, long shadows, and the lamp on.",
		"weight": 1.5, "lamp": 0.6, "candles": [0, 1], "leads": false},
}
## Where the desk's light comes from ([constant Lights.FROM]'s degrees: 270 the writer's left): the left, as for
## a right hand, whose shadow then falls away from the line.
const FROM_LEFT := Vector2(215.0, 305.0)
## WHERE A CANDLE STANDS: just beside the pad's left (meters from its middle), where the wide framing sees its
## flame and its light falls across the page from the writer's left - not back in the dark past the frame. Nearer
## than a tall thing may stand ([constant TALL_LEFT]): the camera stands over the pad, so a candle there leans out
## of the picture, away from the page, and covers none of it. A flame stands at most about 20 cm up (a taper's
## holder and wax, [method _thing]): the higher it burns the nearer the lens, and the further out of the frame.
const CANDLE_BAND := Rect2(-0.24, -0.16, 0.08, 0.24)
const CANDLE_WIDER := Rect2(-0.38, -0.3, 0.22, 0.48)
## How many things a desk has, by weight: none to five.
const FILLS := [[0, 0.5], [1, 1.0], [2, 2.0], [3, 2.0], [4, 1.2], [5, 0.5]]
## Where things may stand, meters from the pad's middle (x right, z toward the reader): the stretch
## the wide camera sees, the pad's footprint with room round it, and how far from the pad's edges a
## tall thing keeps on its left and its right (where the pen leans out).
const REACH := Rect2(-0.45, -0.34, 0.9, 0.62)
const PAD_ROOM := 0.012
const TALL_LEFT := 0.19
const TALL_RIGHT := 0.23
## A thing this high or higher is tall, whatever its row says (meters).
const TALL_H := 0.04


## THE LOOK of the desk with seed [param seed]: `paper`, `rule`, `margin`, `ink`, `binding`, `board`
## (colors); `pen` ({body, trim, metal}); `lamp` ({color, energy, at, share - of it on}); `fill` (a color);
## `mood` ([constant MOODS]) and `light` (the room's, [method Lights.sanitize]d); `top` and `layers`
## ([Tables]' spec, `materials` its materials) and `things` ([{kind, thing, materials}], not yet placed -
## [method dress] places them; the candles first).
static func of(seed: int) -> Dictionary:
	var out := {}
	var r := _rng(seed, "paper")
	var paper_kind := String(_pick(r, [["canary", 5.0], ["white", 3.0], ["pastel", 2.0]]))
	match paper_kind:
		"canary":
			out["paper"] = Color.from_hsv(r.randf_range(0.125, 0.15), r.randf_range(0.12, 0.3), r.randf_range(0.97, 1.0))
		"white":
			out["paper"] = Color.from_hsv(r.randf_range(0.1, 0.16), r.randf_range(0.0, 0.05), r.randf_range(0.96, 1.0))
		_:
			out["paper"] = Color.from_hsv(r.randf(), r.randf_range(0.08, 0.18), r.randf_range(0.95, 1.0))
	out["rule"] = Color.from_hsv(r.randf_range(0.55, 0.6), r.randf_range(0.3, 0.45), r.randf_range(0.8, 0.9), 0.85)
	out["margin"] = Color.from_hsv(fposmod(r.randf_range(-0.02, 0.02), 1.0), r.randf_range(0.45, 0.6), r.randf_range(0.8, 0.9), 0.8)
	r = _rng(seed, "ink")
	match _pick(r, [["blue-black", 4.0], ["black", 3.0], ["blue", 2.0], ["green", 0.7], ["brown", 0.7]]):
		"blue-black":
			out["ink"] = Color.from_hsv(r.randf_range(0.62, 0.66), r.randf_range(0.5, 0.7), r.randf_range(0.24, 0.32))
		"black":
			out["ink"] = Color.from_hsv(r.randf_range(0.0, 1.0), r.randf_range(0.0, 0.15), r.randf_range(0.06, 0.12))
		"blue":
			out["ink"] = Color.from_hsv(r.randf_range(0.6, 0.64), r.randf_range(0.7, 0.85), r.randf_range(0.36, 0.46))
		"green":
			out["ink"] = Color.from_hsv(r.randf_range(0.36, 0.42), r.randf_range(0.6, 0.8), r.randf_range(0.18, 0.26))
		_:
			out["ink"] = Color.from_hsv(r.randf_range(0.05, 0.08), r.randf_range(0.6, 0.8), r.randf_range(0.18, 0.26))
	r = _rng(seed, "binding")
	match _pick(r, [["red", 5.0], ["black", 2.5], ["blue", 1.5], ["green", 0.8], ["brown", 0.8]]):
		"red":
			out["binding"] = Color.from_hsv(fposmod(r.randf_range(-0.03, 0.01), 1.0), r.randf_range(0.55, 0.75), r.randf_range(0.35, 0.6))
		"black":
			out["binding"] = Color.from_hsv(r.randf(), r.randf_range(0.0, 0.1), r.randf_range(0.07, 0.14))
		"blue":
			out["binding"] = Color.from_hsv(r.randf_range(0.58, 0.66), r.randf_range(0.5, 0.7), r.randf_range(0.25, 0.45))
		"green":
			out["binding"] = Color.from_hsv(r.randf_range(0.3, 0.4), r.randf_range(0.4, 0.6), r.randf_range(0.2, 0.35))
		_:
			out["binding"] = Color.from_hsv(r.randf_range(0.06, 0.09), r.randf_range(0.5, 0.7), r.randf_range(0.2, 0.35))
	out["board"] = Color.from_hsv(r.randf_range(0.07, 0.1), r.randf_range(0.25, 0.4), r.randf_range(0.28, 0.4))
	r = _rng(seed, "pen")
	var body := Color.from_hsv(r.randf(), r.randf_range(0.3, 0.7), r.randf_range(0.08, 0.32)) if r.randf() < 0.55 \
		else Color.from_hsv(r.randf(), r.randf_range(0.0, 0.2), r.randf_range(0.04, 0.08))
	var trim := String(_pick(r, [["brass", 3.0], ["silver", 2.0], ["copper", 0.7]]))
	out["pen"] = {"body": body, "trim": {"brass": Color(0.78, 0.62, 0.32), "silver": Color(0.8, 0.8, 0.82),
		"copper": Color(0.76, 0.46, 0.33)}[trim]}
	r = _rng(seed, "lamp")
	out["lamp"] = {"color": _kelvin(r.randf_range(2700.0, 4300.0)), "energy": r.randf_range(1.3, 1.7),
		"at": Vector3(r.randf_range(-0.7, -0.42), r.randf_range(0.82, 1.1), r.randf_range(-0.42, -0.08))}
	out["fill"] = Color.from_hsv(r.randf_range(0.55, 0.65), r.randf_range(0.1, 0.25), r.randf_range(0.8, 0.95))
	r = _rng(seed, "mood")
	var weights: Array = []
	for k in MOODS:
		weights.append([k, float((MOODS[k] as Dictionary)["weight"])])
	var mood := String(_pick(r, weights))
	out["mood"] = mood
	(out["lamp"] as Dictionary)["share"] = float((MOODS[mood] as Dictionary)["lamp"])
	out["light"] = Lights.sanitize(_light(seed, mood))
	var desk := _desk(seed)
	out["top"] = desk["top"]
	out["layers"] = desk["layers"]
	out["materials"] = desk["materials"]
	out["things"] = _candles(seed, mood) + _things(seed)
	return out


## THE ROOM'S LIGHT for a desk of [param mood], as the set dresser writes a table's ([Lights]): the sky's fill
## and what else lights the room. Night is a dim blue sky and perhaps a lamp out of the shot or the moon in a
## window; day the sun through a window aimed across the pad, clouds passing now and then; dusk a low gold sun
## through it. Every sun and moon comes from the writer's left ([constant FROM_LEFT]).
static func _light(seed: int, mood: String) -> Dictionary:
	var r := _rng(seed, "light")
	var from := r.randf_range(FROM_LEFT.x, FROM_LEFT.y)
	var window := {"name": "the window", "kind": String(_pick(r, [["window", 5.0], ["lattice", 1.0]])),
		"at": [r.randf_range(-12.0, 12.0), r.randf_range(-15.0, 8.0)], "size": [r.randf_range(80.0, 130.0), r.randf_range(100.0, 150.0)],
		"panes": [r.randi_range(1, 3), r.randi_range(2, 4)], "bars": r.randf_range(1.5, 3.0),
		"pattern": String(_pick(r, [["grid", 2.0], ["diamonds", 1.0], ["hexes", 0.5]])), "cell": r.randf_range(9.0, 18.0)}
	var night_sky := {"color": _hex(Color.from_hsv(r.randf_range(0.58, 0.68), r.randf_range(0.2, 0.45), r.randf_range(0.35, 0.6))),
		"strength": r.randf_range(0.1, 0.25)}
	var out := {}
	match mood:
		"daylight":
			out["sky"] = {"color": _hex(Color.from_hsv(r.randf_range(0.56, 0.62), r.randf_range(0.08, 0.2), r.randf_range(0.82, 0.95))),
				"strength": r.randf_range(0.45, 0.8), "shadows": r.randf_range(0.3, 0.7)}
			out["sun"] = {"look": "sun", "from": from, "height": r.randf_range(28.0, 55.0), "strength": r.randf_range(0.6, 0.9),
				"softness": r.randf_range(0.1, 0.25)}
			out["through"] = [window]
			if r.randf() < 0.4:
				out["clouds"] = {"cover": r.randf_range(0.2, 0.5), "size": r.randf_range(0.3, 0.7), "speed": r.randf_range(0.2, 0.5)}
			if r.randf() < 0.15:
				out["birds"] = {"look": String(_pick(r, [["pigeon", 2.0], ["crow", 1.0], ["gull", 1.0], ["swallow", 1.0]])),
					"every": r.randf_range(40.0, 120.0)}
		"dusk":
			out["sky"] = {"color": _hex(Color.from_hsv(r.randf_range(0.7, 0.8), r.randf_range(0.15, 0.35), r.randf_range(0.5, 0.75))),
				"strength": r.randf_range(0.2, 0.4)}
			out["sun"] = {"look": "sun", "from": from, "height": r.randf_range(8.0, 18.0), "strength": r.randf_range(0.5, 0.8),
				"color": _hex(_kelvin(r.randf_range(2200.0, 3000.0))), "softness": r.randf_range(0.15, 0.35)}
			out["through"] = [window]
		"candlelight":
			night_sky["strength"] = r.randf_range(0.05, 0.14)
			out["sky"] = night_sky
			if r.randf() < 0.5:
				out["lamps"] = [{"name": "the room's light", "look": String(_pick(r, [["fire", 1.5], ["candles", 1.5], ["lantern", 1.0]])),
					"from": r.randf_range(0.0, 360.0), "strength": r.randf_range(0.3, 0.7)}]
		_:
			out["sky"] = night_sky
			if r.randf() < 0.6:
				out["lamps"] = [{"name": "the room's light", "look": String(_pick(r, [["screen", 1.5], ["street lamp", 1.5], ["candles", 1.2],
					["fire", 1.0], ["lantern", 0.6]])), "from": r.randf_range(0.0, 360.0), "strength": r.randf_range(0.3, 0.7)}]
			if r.randf() < 0.35:
				out["sun"] = {"look": "moon", "from": from, "height": r.randf_range(25.0, 50.0)}
				out["through"] = [window]
	return out


## THE CANDLES a desk of [param mood] burns ([constant MOODS]): as many as it says, each a [constant THINGS]
## candle ([method _thing]) - `{kind, thing, materials}`, made safe, as [method _things] gives.
static func _candles(seed: int, mood: String) -> Array:
	var r := _rng(seed, "candles")
	var span: Array = (MOODS[mood] as Dictionary)["candles"]
	var out: Array = []
	for i in r.randi_range(int(span[0]), int(span[1])):
		var kind := String(_pick(r, [["taper", 3.0], ["pillar", 2.0], ["tealights", 1.0]]))
		var safe := Props.sanitize(_thing(kind, _rng(seed, "candle %d" % i)), ["#888888"])
		if not (safe["things"] as Array).is_empty():
			out.append({"kind": kind, "thing": (safe["things"] as Array)[0], "materials": safe["materials"]})
	return out


## THE DESK'S TOP and what lies on it, as the set dresser would write them ([Tables]).
static func _desk(seed: int) -> Dictionary:
	var r := _rng(seed, "top")
	var kind := String(_pick(r, [["wood", 6.5], ["painted", 1.2], ["stone", 1.2], ["leather", 0.6], ["fabric", 0.5]]))
	var mat := {"kind": kind}
	var top := {"shape": "rect", "size": [r.randf_range(150.0, 200.0), r.randf_range(110.0, 140.0)], "thickness": r.randf_range(2.5, 4.5),
		"edge": "eased", "material": "the desk"}
	match kind:
		"wood":
			var c := Color.from_hsv(r.randf_range(0.04, 0.1), r.randf_range(0.35, 0.65), r.randf_range(0.14, 0.55))
			mat["color"] = _hex(c)
			mat["color2"] = _hex(Color.from_hsv(c.h, minf(c.s + 0.08, 1.0), c.v * r.randf_range(0.5, 0.72)))
			mat["polish"] = r.randf_range(0.25, 0.7)
			mat["pattern"] = r.randf_range(0.35, 0.75)
			mat["grain"] = r.randf_range(0.9, 2.0)
			mat["wear"] = r.randf_range(0.0, 0.25)
			if r.randf() < 0.6:
				top["boards"] = {"width": r.randf_range(9.0, 22.0), "turn": 0.0 if r.randf() < 0.75 else 90.0}
		"stone":
			var light := r.randf() < 0.5
			var c := Color.from_hsv(r.randf(), r.randf_range(0.0, 0.1), r.randf_range(0.75, 0.92) if light else r.randf_range(0.12, 0.3))
			mat["color"] = _hex(c)
			mat["color2"] = _hex(c.darkened(r.randf_range(0.3, 0.5)) if light else c.lightened(r.randf_range(0.15, 0.3)))
			mat["polish"] = r.randf_range(0.2, 0.7)
			mat["pattern"] = r.randf_range(0.25, 0.6)
		"painted":
			mat["color"] = _hex(Color.from_hsv(r.randf(), r.randf_range(0.15, 0.5), r.randf_range(0.15, 0.6)))
			mat["polish"] = r.randf_range(0.3, 0.8)
			mat["wear"] = r.randf_range(0.0, 0.3)
		"leather":
			mat["color"] = _hex(Color.from_hsv(r.randf_range(0.0, 0.1) if r.randf() < 0.7 else r.randf_range(0.3, 0.42),
				r.randf_range(0.4, 0.7), r.randf_range(0.1, 0.35)))
			mat["wear"] = r.randf_range(0.1, 0.4)
		_:
			mat["color"] = _hex(Color.from_hsv(r.randf_range(0.28, 0.42) if r.randf() < 0.6 else r.randf(), r.randf_range(0.3, 0.6), r.randf_range(0.12, 0.35)))
	var layers: Array = []
	r = _rng(seed, "mat")
	if r.randf() < 0.45:
		var mc := Color.from_hsv(r.randf(), r.randf_range(0.15, 0.6), r.randf_range(0.12, 0.45))
		var lay := {"name": "the desk mat", "what": "a mat to write on", "outline": "rect",
			"size": [r.randf_range(52.0, 75.0), r.randf_range(38.0, 55.0)], "at": [r.randf_range(-3.0, 3.0), r.randf_range(-2.0, 5.0)],
			"turn": r.randf_range(-3.0, 3.0), "fabric": _pick(r, [["felt", 3.0], ["wool", 1.5], ["linen", 1.0], ["cotton", 0.8]]),
			"pattern": {"kind": "plain", "colors": [_hex(mc)]}}
		if r.randf() < 0.3:
			lay["border"] = {"width": r.randf_range(0.6, 2.0), "inset": r.randf_range(0.5, 2.5), "color": _hex(mc.lightened(r.randf_range(0.2, 0.5)))}
		layers.append(lay)
	var mats := {"the desk": Props.sanitize_material(mat, String(mat["color"]))}
	return {"top": top, "layers": layers, "materials": mats}


## THE THINGS on the desk with seed [param seed], as the set dresser would write them ([Props]): each
## `{kind, thing, materials}`, made safe.
static func _things(seed: int) -> Array:
	var r := _rng(seed, "things")
	var n := int(_pick(r, FILLS))
	var weights: Array = []
	for k in THINGS:
		if float((THINGS[k] as Dictionary)["weight"]) > 0.0:
			weights.append([k, float((THINGS[k] as Dictionary)["weight"])])
	var out: Array = []
	var had := {}
	for i in n:
		var kind := String(_pick(r, weights))
		if had.has(kind) and kind not in ["pencil", "clips"]:
			continue
		had[kind] = true
		var tr := _rng(seed, "thing %d" % i)
		var spec := _thing(kind, tr)
		var safe := Props.sanitize(spec, ["#888888"])
		if (safe["things"] as Array).is_empty():
			continue
		out.append({"kind": kind, "thing": (safe["things"] as Array)[0], "materials": safe["materials"]})
	return out


## One thing of [param kind], its sizes and colors drawn from [param r] (centimeters, as [Props] reads).
static func _thing(kind: String, r: RandomNumberGenerator) -> Dictionary:
	var mats := {}
	var parts: Array = []
	match kind:
		"mug":
			var rad := r.randf_range(3.7, 4.5)
			var h := r.randf_range(8.5, 10.5)
			var wall := 0.45
			mats["glaze"] = {"kind": "ceramic", "color": _hex(Color.from_hsv(r.randf_range(0.08, 0.14), r.randf_range(0.0, 0.08), r.randf_range(0.88, 0.97))
				if r.randf() < 0.4 else Color.from_hsv(r.randf(), r.randf_range(0.3, 0.7), r.randf_range(0.3, 0.85))), "polish": r.randf_range(0.55, 0.8)}
			parts.append({"shape": "lathe", "material": "glaze", "profile": [[0, 0], [rad - 0.35, 0, 0.3], [rad, 0.5], [rad * 1.02, h, 0.2],
				[rad * 1.02 - wall, h, 0.2], [rad - wall, 0.6], [0, 0.6]]})
			parts.append({"shape": "tube", "material": "glaze", "radius": 0.45, "smooth": true, "path": [[rad - 0.3, h * 0.8, 0], [rad + 1.9, h * 0.76, 0],
				[rad + 2.5, h * 0.48, 0], [rad + 1.8, h * 0.22, 0], [rad - 0.3, h * 0.2, 0]]})
			if r.randf() < 0.7:
				var f := h * r.randf_range(0.6, 0.85)
				mats["drink"] = {"kind": "painted", "color": _hex(Color.from_hsv(r.randf_range(0.05, 0.08), r.randf_range(0.6, 0.85), r.randf_range(0.08, 0.3))), "polish": 0.9}
				parts.append({"shape": "lathe", "material": "drink", "profile": [[0, f - 0.2], [rad - wall - 0.02, f - 0.2], [rad - wall - 0.02, f], [0, f]]})
		"pencil":
			parts.append({"parts": _pencil(r, mats, r.randf_range(8.0, 17.5)), "turn": [0, 0, 90]})
		"pencil_cup":
			var rad := r.randf_range(3.6, 4.4)
			var h := r.randf_range(9.0, 11.0)
			mats["cup"] = {"kind": _pick(r, [["metal", 1.0], ["ceramic", 1.5], ["wood", 0.8]]), "color": _hex(Color.from_hsv(r.randf(), r.randf_range(0.0, 0.5), r.randf_range(0.25, 0.85)))}
			parts.append({"shape": "lathe", "material": "cup", "profile": [[0, 0], [rad, 0, 0.2], [rad, h, 0.15], [rad - 0.3, h, 0.15], [rad - 0.3, 0.5], [0, 0.5]]})
			for k in r.randi_range(3, 5):
				var a := TAU * (float(k) / 5.0 + r.randf_range(-0.06, 0.06))
				var off := r.randf_range(0.8, 1.5)
				var lean := r.randf_range(4.0, 8.0)
				parts.append({"parts": _pencil(r, mats, r.randf_range(15.0, 18.0), "pencil %d" % k), "at": [cos(a) * off, 0.5, sin(a) * off],
					"turn": [sin(a) * lean, r.randf_range(0.0, 360.0), -cos(a) * lean]})
		"eraser":
			mats["rubber"] = {"kind": "painted", "color": _hex(_pick(r, [[Color(0.93, 0.62, 0.66), 2.0], [Color(0.92, 0.92, 0.9), 2.0], [Color(0.5, 0.52, 0.55), 1.0], [Color(0.45, 0.6, 0.85), 0.6]])),
				"polish": 0.15, "wear": r.randf_range(0.1, 0.4)}
			parts.append({"shape": "box", "material": "rubber", "size": [r.randf_range(4.0, 6.0), r.randf_range(0.9, 1.3), r.randf_range(1.8, 2.4)], "round": r.randf_range(0.15, 0.35)})
		"books":
			var y := 0.0
			for k in r.randi_range(1, 3):
				var w := r.randf_range(14.0, 23.0)
				var d := r.randf_range(19.0, 27.0)
				var th := r.randf_range(1.5, 4.0)
				var cover := "cover %d" % k
				mats[cover] = {"kind": _pick(r, [["leather", 1.0], ["fabric", 1.5], ["painted", 1.0], ["paper", 0.8]]),
					"color": _hex(Color.from_hsv(r.randf(), r.randf_range(0.2, 0.65), r.randf_range(0.12, 0.6))), "wear": r.randf_range(0.0, 0.4)}
				mats["leaves"] = {"kind": "paper", "color": _hex(Color.from_hsv(r.randf_range(0.1, 0.14), r.randf_range(0.05, 0.2), r.randf_range(0.82, 0.95)))}
				var book: Array = [
					{"shape": "box", "material": cover, "size": [w, 0.25, d], "at": [0, 0, 0], "round": 0.05},
					{"shape": "box", "material": cover, "size": [w, 0.25, d], "at": [0, th - 0.25, 0], "round": 0.05},
					{"shape": "box", "material": cover, "size": [0.35, th, d], "at": [-w * 0.5 + 0.17, 0, 0], "round": 0.12},
					{"shape": "box", "material": "leaves", "size": [w - 0.6, th - 0.5, d - 0.6], "at": [0.05, 0.25, 0]},
				]
				parts.append({"parts": book, "at": [r.randf_range(-1.5, 1.5), y, r.randf_range(-1.5, 1.5)], "turn": [0, r.randf_range(-9.0, 9.0), 0]})
				y += th
		"clips":
			var coated := r.randf() < 0.35
			mats["wire"] = {"kind": "painted" if coated else "metal", "color": _hex(Color.from_hsv(r.randf(), r.randf_range(0.5, 0.8), r.randf_range(0.5, 0.85))
				if coated else Color(0.78, 0.78, 0.8)), "polish": 0.75}
			for k in r.randi_range(1, 3):
				parts.append({"parts": [{"shape": "tube", "material": "wire", "radius": 0.045, "smooth": false, "path": [[1.1, 0.05, -0.15],
					[2.95, 0.05, -0.15, 0.19], [2.95, 0.05, 0.25, 0.19], [0.1, 0.05, 0.25, 0.34], [0.1, 0.05, -0.45, 0.34], [3.45, 0.05, -0.45, 0.44],
					[3.45, 0.05, 0.45, 0.44], [1.6, 0.05, 0.45]]}], "at": [r.randf_range(-2.5, 2.5), 0, r.randf_range(-2.5, 2.5)], "turn": [0, r.randf_range(0.0, 360.0), 0]})
		"cards":
			var sticky := r.randf() < 0.45
			mats["card"] = {"kind": "paper", "color": _hex(Color.from_hsv(r.randf(), r.randf_range(0.35, 0.6), r.randf_range(0.9, 1.0))
				if sticky else Color.from_hsv(r.randf_range(0.1, 0.15), r.randf_range(0.0, 0.06), r.randf_range(0.93, 0.99)))}
			var side := r.randf_range(7.3, 7.8)
			parts.append({"shape": "box", "material": "card", "size": [side if sticky else 12.7, r.randf_range(0.6, 1.4) if sticky else r.randf_range(0.3, 1.0), side], "round": 0.03})
		"ruler":
			var steel := r.randf() < 0.4
			mats["rule"] = {"kind": "metal" if steel else "wood", "color": "#c0c2c6" if steel else _hex(Color.from_hsv(r.randf_range(0.08, 0.12), r.randf_range(0.3, 0.5), r.randf_range(0.6, 0.85))),
				"polish": 0.6 if steel else 0.4}
			parts.append({"shape": "box", "material": "rule", "size": [30.5, 0.12 if steel else 0.35, 2.6 if steel else 3.2], "round": 0.04})
		"cactus":
			var pr := r.randf_range(2.8, 3.6)
			var ph := r.randf_range(4.5, 6.0)
			mats["pot"] = {"kind": "ceramic", "color": _hex(Color.from_hsv(r.randf_range(0.03, 0.07), r.randf_range(0.45, 0.65), r.randf_range(0.5, 0.7))
				if r.randf() < 0.6 else Color.from_hsv(r.randf(), r.randf_range(0.0, 0.5), r.randf_range(0.3, 0.9))), "polish": r.randf_range(0.05, 0.6)}
			mats["soil"] = {"kind": "painted", "color": "#2e2117", "polish": 0.05}
			mats["green"] = {"kind": "plant", "color": _hex(Color.from_hsv(r.randf_range(0.25, 0.36), r.randf_range(0.45, 0.7), r.randf_range(0.25, 0.45))), "pattern": 0.3}
			parts.append({"shape": "lathe", "material": "pot", "profile": [[0, 0], [pr * 0.8, 0, 0.2], [pr, ph, 0.2], [pr - 0.35, ph, 0.15], [pr * 0.8 - 0.35, 0.5], [0, 0.5]]})
			parts.append({"shape": "lathe", "material": "soil", "profile": [[0, ph - 0.9], [pr - 0.4, ph - 0.9], [pr - 0.4, ph - 0.6], [0, ph - 0.6]]})
			var cr := r.randf_range(1.5, 2.2)
			var ch := r.randf_range(4.5, 8.0)
			parts.append({"shape": "lathe", "material": "green", "smooth": true, "at": [0, ph - 0.8, 0],
				"profile": [[0, 0], [cr * 0.85, 0], [cr, ch * 0.35], [cr * 0.9, ch * 0.75], [cr * 0.5, ch * 0.95], [0, ch]],
				"ornament": {"kind": "flutes", "count": r.randi_range(8, 14), "depth": 0.6}})
		"taper":
			var h := r.randf_range(6.0, 10.0)
			var hold := String(_pick(r, [["brass", 2.0], ["pewter", 1.2], ["clay", 1.0], ["wood", 0.8]]))
			mats["holder"] = {"kind": "metal" if hold in ["brass", "pewter"] else ("wood" if hold == "wood" else "ceramic"),
				"color": {"brass": "#b08d4a", "pewter": "#8e9094", "clay": _hex(Color.from_hsv(r.randf(), r.randf_range(0.1, 0.5), r.randf_range(0.3, 0.85))),
					"wood": _hex(Color.from_hsv(r.randf_range(0.06, 0.1), r.randf_range(0.4, 0.6), r.randf_range(0.25, 0.5)))}[hold],
				"polish": r.randf_range(0.4, 0.8)}
			var foot := r.randf_range(3.8, 5.0)
			parts.append({"shape": "lathe", "material": "holder", "smooth": true, "profile": [[0, 0], [foot, 0, 0], [foot, 0.6, 0.3],
				[foot * 0.45, 1.6], [0.8, 2.6], [0.75, h - 2.4], [1.9, h - 1.3], [2.1, h, 0], [1.25, h, 0], [1.25, h - 1.1, 0], [0, h - 1.1]]})
			mats["wax"] = _wax(r)
			# burned down some way, or new
			var wax_h := r.randf_range(10.0, 15.0) * r.randf_range(0.45, 1.0)
			parts.append({"shape": "lathe", "material": "wax", "at": [0, h - 1.1, 0], "profile": [[0, 0], [1.1, 0], [1.05, wax_h], [0, wax_h]],
				"wick": true, "drips": r.randf_range(0.0, 0.6)})
		"pillar":
			var rad := r.randf_range(3.0, 4.8)
			var h := r.randf_range(6.0, 14.0)
			mats["wax"] = _wax(r)
			mats["dish"] = {"kind": String(_pick(r, [["ceramic", 2.0], ["metal", 1.0]])),
				"color": _hex(Color.from_hsv(r.randf(), r.randf_range(0.0, 0.4), r.randf_range(0.3, 0.9))), "polish": r.randf_range(0.4, 0.8)}
			var dr := rad + r.randf_range(1.0, 2.5)
			parts.append({"shape": "lathe", "material": "dish", "profile": [[0, 0], [dr * 0.8, 0, 0.2], [dr, 0.9, 0.2], [dr - 0.3, 0.9, 0.1], [dr * 0.8 - 0.3, 0.4], [0, 0.4]]})
			var pillar := {"shape": "lathe", "material": "wax", "at": [0, 0.4, 0], "profile": [[0, 0], [rad, 0, 0.3], [rad, h, 0.4], [0, h]],
				"drips": r.randf_range(0.0, 0.5)}
			if rad > 4.2 and r.randf() < 0.5:
				pillar["wicks"] = r.randi_range(2, 3)
			else:
				pillar["wick"] = true
			parts.append(pillar)
		"tealights":
			mats["saucer"] = {"kind": String(_pick(r, [["ceramic", 2.0], ["metal", 1.0]])),
				"color": _hex(Color.from_hsv(r.randf(), r.randf_range(0.0, 0.4), r.randf_range(0.4, 0.95))), "polish": r.randf_range(0.5, 0.85)}
			mats["tin"] = {"kind": "metal", "color": "#c4c6ca", "polish": 0.7}
			mats["wax"] = _wax(r)
			var n := r.randi_range(2, 3)
			var sr := 3.6 if n == 2 else 4.6
			parts.append({"shape": "lathe", "material": "saucer", "smooth": true, "profile": [[0, 0], [sr + 0.6, 0, 0], [sr + 1.6, 0.9],
				[sr + 1.4, 1.0], [sr + 0.4, 0.4], [0, 0.4]]})
			var a0 := r.randf_range(0.0, TAU)
			for k in n:
				var a := a0 + TAU * float(k) / float(n)
				var at := [cos(a) * (sr - 2.0), 0.4, sin(a) * (sr - 2.0)]
				parts.append({"shape": "lathe", "material": "tin", "at": at, "profile": [[0, 0], [1.9, 0], [1.9, 1.6], [1.75, 1.6], [1.75, 0.15], [0, 0.15]]})
				parts.append({"shape": "lathe", "material": "wax", "at": [at[0], 0.55, at[2]], "profile": [[0, 0], [1.74, 0], [1.74, 1.0], [0, 1.0]], "wick": true})
	return {"things": [{"name": String((THINGS[kind] as Dictionary)["label"]), "parts": parts}], "materials": mats}


## A candle's wax: ivory or white mostly, now and then a color.
static func _wax(r: RandomNumberGenerator) -> Dictionary:
	var c: Color = _pick(r, [[Color.from_hsv(r.randf_range(0.1, 0.14), r.randf_range(0.08, 0.2), r.randf_range(0.9, 0.97)), 4.0],
		[Color(0.96, 0.95, 0.92), 2.0], [Color.from_hsv(r.randf(), r.randf_range(0.4, 0.7), r.randf_range(0.4, 0.8)), 1.0]])
	return {"kind": "wax", "color": _hex(c), "clarity": r.randf_range(0.4, 0.7)}


## A pencil standing on its eraser's end, [param length] long: a painted hexagonal body, its sharpened
## wood and lead, a metal band and the eraser. Its materials go into [param mats], named after [param name].
static func _pencil(r: RandomNumberGenerator, mats: Dictionary, length: float, name := "pencil") -> Array:
	var paint := name + " paint"
	mats[paint] = {"kind": "painted", "color": _hex(Color.from_hsv(r.randf_range(0.12, 0.15), r.randf_range(0.7, 0.9), r.randf_range(0.85, 0.95))
		if r.randf() < 0.5 else Color.from_hsv(r.randf(), r.randf_range(0.3, 0.8), r.randf_range(0.15, 0.7))), "polish": 0.6}
	mats["cedar"] = {"kind": "wood", "color": "#d8b48a", "color2": "#b88c5e", "pattern": 0.3}
	mats["lead"] = {"kind": "painted", "color": "#2b2b2e", "polish": 0.5}
	mats["band"] = {"kind": "metal", "color": "#c8b070" if r.randf() < 0.6 else "#b8babd", "polish": 0.6}
	mats["rubber"] = {"kind": "painted", "color": "#e39aa0", "polish": 0.15}
	var body := length - 1.8
	return [
		{"shape": "lathe", "material": "rubber", "profile": [[0, 0], [0.34, 0, 0.15], [0.34, 0.7], [0, 0.7]]},
		{"shape": "lathe", "material": "band", "profile": [[0, 0.6], [0.38, 0.6], [0.38, 1.5], [0, 1.5]], "ornament": {"kind": "bands", "count": 3, "depth": 0.3}},
		{"shape": "lathe", "material": paint, "sides": 6, "profile": [[0, 1.5], [0.37, 1.5], [0.37, body], [0, body]]},
		{"shape": "lathe", "material": "cedar", "profile": [[0, body], [0.34, body], [0.1, length - 0.3], [0, length - 0.3]]},
		{"shape": "lathe", "material": "lead", "profile": [[0, length - 0.32], [0.1, length - 0.32], [0, length]]},
	]


## THE DESK, DRESSED: the top and what lies on it ([method Tables.build]) and every thing standing where
## [method _placed] puts it, under one node, the top's face at [param face] (the pad's frame, the pad's
## middle at x = z = 0). Built off the tree; the caller adds it. `{node, lit}`: `lit` the things that burn,
## each `{node, wicks, glows, meshes}` as [method Props.build] gives them (`wicks` in the thing's own space).
static func dress(look: Dictionary, seed: int, face: float) -> Dictionary:
	var root := Node3D.new()
	root.name = "Desk"
	var spec := Tables.sanitize(look["top"], look["layers"], look["materials"], [])
	var built := Tables.build(spec, seed)
	var furniture: Node3D = built["node"]
	# the reading's middle ([constant Tables.ORIGIN]) under the pad's
	furniture.position = Vector3(-Tables.ORIGIN.x, face, -Tables.ORIGIN.y)
	root.add_child(furniture)
	var taken: Array = []
	var lit: Array = []
	var mat := _mat_rect(spec)
	for i in (look["things"] as Array).size():
		var t: Dictionary = look["things"][i]
		var made := Props.build(t["thing"], t["materials"], hash([seed, "desk thing", i]))
		var size: AABB = made["size"]
		var rad := 0.5 * Vector2(size.size.x, size.size.z).length()
		var tall := bool((THINGS[String(t["kind"])] as Dictionary)["tall"]) or size.size.y >= TALL_H
		var near := bool((THINGS[String(t["kind"])] as Dictionary).get("lit", false))
		var r := _rng(seed, "place %d" % i)
		var at := _placed(r, rad, tall and not near, taken, CANDLE_BAND if near else REACH)
		if near and at.x == INF:
			# a candle is the light: past the frame's edge, or anywhere it fits, before none at all
			at = _placed(r, rad, false, taken, CANDLE_WIDER)
			if at.x == INF:
				at = _placed(r, rad, tall, taken)
		if at.x == INF:
			(made["node"] as Node).free()
			continue
		taken.append(Vector3(at.x, at.y, rad))
		var node: Node3D = made["node"]
		var on_mat := mat.has_point(at)
		node.position = Vector3(at.x, face + (Tables.LAYER_FLOOR + 0.0001 if on_mat else 0.0), at.y)
		node.rotation.y = _rng(seed, "turn %d" % i).randf_range(0.0, TAU)
		if String(t["kind"]) in ["pencil", "ruler"] and absf(at.x) < 0.2:
			# lying beside the pad, along it
			node.rotation.y = PI * 0.5 + _rng(seed, "turn %d" % i).randf_range(-0.35, 0.35)
		root.add_child(node)
		if not (made["wicks"] as Array).is_empty():
			lit.append({"node": node, "wicks": made["wicks"], "glows": made["glows"], "meshes": made["meshes"]})
	return {"node": root, "lit": lit}


## Where the desk mat lies (meters, the pad's frame), or an empty rect: no mat.
static func _mat_rect(spec: Dictionary) -> Rect2:
	for l in spec.get("layers", []):
		var at: Array = (l as Dictionary).get("at", [0.0, 0.0]) if (l as Dictionary).get("at") is Array else [0.0, 0.0]
		var size: Array = (l as Dictionary)["size"]
		var c := Vector2(float(at[0]), float(at[1])) * 0.01
		var half := Vector2(float(size[0]), float(size[1])) * 0.005
		return Rect2(c - half, half * 2.0)
	return Rect2()


## WHERE A THING STANDS (x, z meters from the pad's middle), [param rad] its reach, [param tall] whether it
## stands up, clear of the things [param taken] ([x, z, reach]), somewhere in [param within] (its middle; the
## desk's whole [constant REACH] by default, a candle's [constant CANDLE_BAND]); (INF, INF) when no place is found.
## Never on the pad nor behind it (where turned pages lie), a tall one never close beside it nor in front.
static func _placed(r: RandomNumberGenerator, rad: float, tall: bool, taken: Array, within := REACH) -> Vector2:
	var pad_x := LegalPad.W * 0.5 + PAD_ROOM + rad
	var pad_top := -LegalPad.H * 0.5 - LegalPad.BIND_W - PAD_ROOM - rad
	var pad_foot := LegalPad.H * 0.5 + PAD_ROOM + rad
	var area := within if within == REACH else within.grow(rad)
	for _try in 80:
		var p := Vector2(r.randf_range(area.position.x + rad, area.end.x - rad), r.randf_range(area.position.y + rad, area.end.y - rad))
		if absf(p.x) < pad_x and p.y < pad_foot:
			continue            # on the pad, or behind it where the turned pages lie
		if tall and (p.x > -TALL_LEFT - rad and p.x < TALL_RIGHT + rad or p.y > pad_foot - 0.04):
			continue
		if p.x > 0.0 and p.x < TALL_RIGHT + rad and p.y < 0.0:
			continue            # where the pen waits, off the pad's top right
		var clear := true
		for q in taken:
			if p.distance_to(Vector2((q as Vector3).x, (q as Vector3).y)) < rad + (q as Vector3).z + 0.012:
				clear = false
				break
		if clear and p.y > pad_top - 0.3:
			return p
	return Vector2(INF, INF)


## A random number generator of its own for each kind of choice ([param what]) on the desk of
## [param seed].
static func _rng(seed: int, what: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(["desk-look", seed, what])
	return r


## One of [param options] ([[value, weight], ...]), by weight.
static func _pick(r: RandomNumberGenerator, options: Array) -> Variant:
	var total := 0.0
	for o in options:
		total += float((o as Array)[1])
	var x := r.randf() * total
	for o in options:
		x -= float((o as Array)[1])
		if x <= 0.0:
			return (o as Array)[0]
	return (options[options.size() - 1] as Array)[0]


static func _hex(c: Color) -> String:
	return "#" + c.to_html(false)


## A lamp's color at [param k] kelvin (Tanner Helland's fit to blackbody colors).
static func _kelvin(k: float) -> Color:
	var t := k / 100.0
	var red := 1.0 if t <= 66.0 else clampf(329.698727446 * pow(t - 60.0, -0.1332047592) / 255.0, 0.0, 1.0)
	var green := clampf((99.4708025861 * log(t) - 161.1195681661) / 255.0, 0.0, 1.0) if t <= 66.0 \
		else clampf(288.1221695283 * pow(t - 60.0, -0.0755148492) / 255.0, 0.0, 1.0)
	var blue := 1.0 if t >= 66.0 else (0.0 if t <= 19.0 else clampf((138.5177312231 * log(t - 10.0) - 305.0447927307) / 255.0, 0.0, 1.0))
	return Color(red, green, blue)
