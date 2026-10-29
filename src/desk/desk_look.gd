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
## WHAT IS ON IT AND ITS LIGHT MAY BE CHOSEN (2026-10-29, the user of the Letter's desk: "It's really hard to find a
## good seed, because generating the scenes is kind of slow ... provide a multi-select bank of the standard objects
## ... Then, when we change the seed - the only thing being changed would be the placement of objects, and
## textures"): handed `picks` ([method of]: the things, the mat among them, and the mood), the seed only places them
## and draws how each looks - each from a generator of its own kind, so ticking another moves nothing about how the
## rest look. A desk handed none (a Proof's) draws them all, as before.
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
## out as it writes and waits ([constant DeskMedium.PARK]), nothing tall in front of it, where the
## camera looks over it ([method _placed]), and nothing where the pen lies before a letter's writer picks it up
## ([method pen_rest]).

## THE THINGS a desk may have. `tall`: kept back from the pad (it would stand in the pen's or the
## camera's way); `weight`: how often it is chosen among the things lying about - none for a candle, which
## its desk's mood sets down ([constant MOODS]), and none for what is only ever chosen ([method of]'s `picks`);
## `lit`: it burns; `layer`: it lies under the pad, not on the desk ([method _desk]); `face`: the material of what must be
## seen of it, kept in the frame before the rest ([method _pack]; a dog tag's bone, its chain may hang past the edge).
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
	"dog_tag": {"label": "a dog tag", "blurb": "A flat, polished steel tag cut in the shape of a dog's bone, a V-shaped bail at the middle of its edge and a long fine chain through it - dropped beside it in a heap, its clasp along it.", "tall": false, "weight": 0.0, "face": "tag"},
	"mat": {"label": "a desk mat", "blurb": "A mat of felt, wool, linen or cotton under the pad, now and then with a border.", "tall": false, "weight": 0.0, "layer": true},
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
## ...OR BESIDE ITS RIGHT (2026-10-29, the user: "I don't think I've seen a candle placed on the right side even one
## time ... The scenes look best when lighting comes from both directions"): past the stretch beside the pad's right
## edge that the pen keeps for itself as it leans out, rests, taps the desk and waits ([constant TALL_RIGHT]), at the
## frame's edge or just past it - its light across the page from the right. A desk's candles take their sides by turns
## from a seeded first ([method _candle_right]), so two light it from both.
const CANDLE_RIGHT := Rect2(0.27, -0.12, 0.08, 0.24)
const CANDLE_RIGHT_WIDER := Rect2(0.25, -0.3, 0.18, 0.48)
## How many things a desk has, by weight: none to five.
const FILLS := [[0, 0.5], [1, 1.0], [2, 2.0], [3, 2.0], [4, 1.2], [5, 0.5]]
## A tea light's tin, round (centimeters).
const TEA_TIN := 1.9
## Where things may stand, meters from the pad's middle (x right, z toward the reader): the stretch
## the wide camera sees, the pad's footprint with room round it, and how far from the pad's edges a
## tall thing keeps on its left and its right (where the pen leans out).
const REACH := Rect2(-0.45, -0.34, 0.9, 0.62)
## What the Letter's widest framing sees of the desk ([constant LetterMedium.LETTER_WIDE] through [constant
## DeskMedium.VFOV]'s narrow lens at 16:9, its corners cast onto the desk: 56 cm across at the binding, 52 at the
## frame's foot, 31 cm deep), where a thing CHOSEN for the desk lies when it can ([method _pack]) - the whole [constant
## REACH] is mostly past the frame. Close, as the pen writes, it sees about 4 cm past the pad's sides.
const SEEN := [Vector2(-0.27, -0.175), Vector2(0.27, -0.175), Vector2(0.25, 0.13), Vector2(-0.25, 0.13)]
## PACKING A CHOSEN DESK ([method _pack]): places tried for each thing, the gap kept between two things (meters), how
## far a long thing lying along the pad turns off it (radians, either way), how much a place's share out of [constant
## SEEN] weighs against its distance from the paper (meters for all of it out), and the seeded spread among the best.
const PACK_TRIES := 160
const PACK_GAP := 0.01
const PACK_SWAY := 0.2
const PACK_SEEN := 0.8
const PACK_JITTER := 0.045
## What any of a thing out of [constant SEEN] costs it beside its share (meters): the more random the choice, the more a
## little overhang had won - a dog tag's bone 7 mm past the frame's edge.
const PACK_EDGE := 0.05
## ...and BOTH SIDES OF THE PAD (2026-10-29, the user: "the pencil and dog tags and probably other objects as well are
## NEVER placed on the right ... the pencil could obviously be set alongside the pens on the right. Also on the right,
## at the bottom corner, there is NEVER anything placed there, even though there is space for it"): how often a thing
## leans to the right, what lying on its other side costs it (meters), how often a long thing lies at any angle
## rather than along the pad, and the lane kept clear beside the pad's right edge, where the pen taps the desk
## ([constant LetterMedium.TAP_SPOTS] `desk`, 2 cm out) - past it the pen's rest is kept clear as a thing is, and
## what stands keeps back to [constant TALL_RIGHT] as always (the pen leans out over it as it writes, and parks there).
const PACK_RIGHT := 0.45
const PACK_SIDE := 0.03
const PACK_ASKEW := 0.3
const TAP_LANE := 0.035
const PAD_ROOM := 0.012
const TALL_LEFT := 0.19
const TALL_RIGHT := 0.23
## A thing this high or higher is tall, whatever its row says (meters).
const TALL_H := 0.04
## WHERE THE PEN LIES ([method pen_rest]): its nib this far right of the pad's right edge and this far from the pad's
## middle toward the reader - up the pad, so less than none (meters, [least, most]), its body turned out from the pad
## by this much (degrees from straight toward the writer), and as long as [DeskMedium] builds it, nib to top. Where
## the wide framing sees it, beside the page's upper half.
const PEN_OFF := Vector2(0.024, 0.04)
const PEN_AT := Vector2(-0.125, -0.095)
const PEN_TURN := Vector2(4.0, 16.0)
const PEN_LONG := 0.155
## A PEN EACH INK (a letter's, [constant LetterScript.SWAP]): the others lie beside the first, each this much further out
## from the pad (meters), set down a little differently - this much along it and turned this much (at most, either way).
const PEN_APART := 0.026
const PEN_SHIFT := 0.012
const PEN_SWAY := 4.0
## A DOG TAG ([method _dog_tag], centimeters): the plate's thickness, the steps round each lobe of its outline, its bail's
## width and length (a V from over the plate out past its edge), its chain's links (a fine cable chain's 1.5 mm), the
## chain's length (a necklace's, 30 to 35 inches: the bone hangs to the middle of the chest), the places along it as it
## is dropped (all a strand's path may have, less its two ends: [constant Props.MAX_POINTS]) and how many times it may be
## dropped again to keep off the bone, and its clasp's radius and length.
const TAG_THICK := 0.1
const TAG_ARC := 9
const TAG_BAIL := Vector2(0.5, 0.8)
const TAG_LINK := 0.15
const TAG_LONG := Vector2(76.0, 89.0)
const TAG_DROP := 37
const TAG_DROPS := 6
const TAG_CLASP := Vector2(0.09, 0.5)


## THE LOOK of the desk with seed [param seed]: `paper`, `rule`, `margin`, `ink`, `binding`, `board`
## (colors); `pen` ({body, trim, rest - its nib and turn, [method pen_rest]}); `lamp` ({color, energy, at, share - of it on}); `fill` (a color);
## `mood` ([constant MOODS]) and `light` (the room's, [method Lights.sanitize]d); `top` and `layers`
## ([Tables]' spec, `materials` its materials) and `things` ([{kind, thing, materials}], not yet placed -
## [method dress] places them; the candles first).
##
## [param picks] is what was chosen for it ([method picks_of]): `things` (the [constant THINGS] keys on it, the mat
## among them - each once, any order) and `mood`. What it leaves out is drawn from the seed; given `things`, the look
## is `picked` ([method _chosen]).
static func of(seed: int, picks := {}) -> Dictionary:
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
	# where it lies ([method pen_rest]), on a generator of its own, so nothing else on the desk moves for it
	r = _rng(seed, "pen rest")
	out["pen"]["seed"] = seed
	out["pen"]["rest"] = {"nib": Vector2(LegalPad.W * 0.5 + r.randf_range(PEN_OFF.x, PEN_OFF.y), r.randf_range(PEN_AT.x, PEN_AT.y)),
		"turn": deg_to_rad(r.randf_range(PEN_TURN.x, PEN_TURN.y))}
	r = _rng(seed, "lamp")
	out["lamp"] = {"color": _kelvin(r.randf_range(2700.0, 4300.0)), "energy": r.randf_range(1.3, 1.7),
		"at": Vector3(r.randf_range(-0.7, -0.42), r.randf_range(0.82, 1.1), r.randf_range(-0.42, -0.08))}
	out["fill"] = Color.from_hsv(r.randf_range(0.55, 0.65), r.randf_range(0.1, 0.25), r.randf_range(0.8, 0.95))
	r = _rng(seed, "mood")
	var weights: Array = []
	for k in MOODS:
		weights.append([k, float((MOODS[k] as Dictionary)["weight"])])
	var mood := String(picks.get("mood", ""))
	if not MOODS.has(mood):
		mood = String(_pick(r, weights))
	out["mood"] = mood
	(out["lamp"] as Dictionary)["share"] = float((MOODS[mood] as Dictionary)["lamp"])
	out["light"] = Lights.sanitize(_light(seed, mood))
	var chosen: Variant = picks.get("things")
	var desk := _desk(seed, ("mat" in (chosen as Array)) if chosen is Array else null)
	out["top"] = desk["top"]
	out["layers"] = desk["layers"]
	out["materials"] = desk["materials"]
	if chosen is Array:
		out["things"] = _chosen(seed, mood, chosen)
		out["picked"] = true
	else:
		out["things"] = _candles(seed, mood) + _things(seed)
	return out


## WHAT A DOCUMENT'S `letter` CHOSE for its desk ([LetterCard]): `things` and `mood` where it carries them - [method
## of]'s `picks`.
static func picks_of(letter: Dictionary) -> Dictionary:
	var out := {}
	if letter.get("things") is Array:
		out["things"] = (letter["things"] as Array).duplicate()
	if MOODS.has(String(letter.get("mood", ""))):
		out["mood"] = String(letter["mood"])
	return out


## WHAT [param look] HAS ON IT, by [constant THINGS] key in its order - the mat among them when one lies under the pad:
## what the Letter card shows ticked for a desk it has chosen nothing for.
static func kinds(look: Dictionary) -> Array:
	var have := {}
	for t in look.get("things", []):
		have[String((t as Dictionary)["kind"])] = true
	if not (look.get("layers", []) as Array).is_empty():
		have["mat"] = true
	var out: Array = []
	for k in THINGS:
		if have.has(k):
			out.append(k)
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


## THE DESK'S TOP and what lies on it, as the set dresser would write them ([Tables]): a mat under the pad when
## [param mat_chosen] says so, or now and then when it is null (nothing chosen) - its look drawn the same either way.
static func _desk(seed: int, mat_chosen: Variant = null) -> Dictionary:
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
	var drawn := r.randf() < 0.45
	if bool(mat_chosen) if mat_chosen != null else drawn:
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


## THE THINGS CHOSEN for the desk of [param seed] ([param kinds], [constant THINGS] keys; the mat is the top's, [method
## _desk]): each once, in [constant THINGS]' order, the candles first as [method dress] places them, each drawn from a
## generator of its own kind. A desk lit by candles ([constant MOODS] `leads`) and given none has a taper set down: its
## page would have no light of its own.
static func _chosen(seed: int, mood: String, kinds: Array) -> Array:
	var want := {}
	var lit := false
	for k in kinds:
		var row: Dictionary = THINGS.get(String(k), {})
		if not row.is_empty() and not bool(row.get("layer", false)):
			want[String(k)] = true
			lit = lit or bool(row.get("lit", false))
	if bool((MOODS[mood] as Dictionary)["leads"]) and not lit:
		want["taper"] = true
	var out: Array = []
	for burning in [true, false]:
		for kind in THINGS:
			if not want.has(kind) or bool((THINGS[kind] as Dictionary).get("lit", false)) != burning:
				continue
			var safe := Props.sanitize(_thing(kind, _rng(seed, "chosen " + kind)), ["#888888"])
			if not (safe["things"] as Array).is_empty():
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
			var sr := 3.8 if n == 2 else 4.6
			parts.append({"shape": "lathe", "material": "saucer", "smooth": true, "profile": [[0, 0], [sr + 0.6, 0, 0], [sr + 1.6, 0.9],
				[sr + 1.4, 1.0], [sr + 0.4, 0.4], [0, 0.4]]})
			var a0 := r.randf_range(0.0, TAU)
			# THE TINS APART (2026-10-29, the user: "the tea lights are clipping through each other"): two had stood 1.6 cm
			# either side of the middle, 3.2 apart, each 1.9 round - far enough out that no two of them meet
			var out := maxf(sr - 2.0, (TEA_TIN + 0.12) / sin(PI / float(n)))
			for k in n:
				var a := a0 + TAU * float(k) / float(n)
				var at := [cos(a) * out, 0.4, sin(a) * out]
				parts.append({"shape": "lathe", "material": "tin", "at": at, "profile": [[0, 0], [TEA_TIN, 0], [TEA_TIN, 1.6], [TEA_TIN - 0.15, 1.6],
					[TEA_TIN - 0.15, 0.15], [0, 0.15]]})
				parts.append({"shape": "lathe", "material": "wax", "at": [at[0], 0.55, at[2]], "profile": [[0, 0], [1.74, 0], [1.74, 1.0], [0, 1.0]], "wick": true})
		"dog_tag":
			parts = _dog_tag(r, mats)
	return {"things": [{"name": String((THINGS[kind] as Dictionary)["label"]), "parts": parts}], "materials": mats}


## A candle's wax: ivory or white mostly, now and then a color.
static func _wax(r: RandomNumberGenerator) -> Dictionary:
	var c: Color = _pick(r, [[Color.from_hsv(r.randf_range(0.1, 0.14), r.randf_range(0.08, 0.2), r.randf_range(0.9, 0.97)), 4.0],
		[Color(0.96, 0.95, 0.92), 2.0], [Color.from_hsv(r.randf(), r.randf_range(0.4, 0.7), r.randf_range(0.4, 0.8)), 1.0]])
	return {"kind": "wax", "color": _hex(c), "clarity": r.randf_range(0.4, 0.7)}


## A DOG TAG CUT AS A DOG'S BONE (2026-10-29, the user: "Exactly like a military-issued tag might be, except that the
## tag needs to be literally dog-bone shaped"; then, of the first, a stamped steel tag with a rolled rim on a ball
## chain through a hole at its end, by their picture: "The chain is connected to the center of the bone, not to the
## side. It has sort of a V-shaped thing attached to the middle of the bone, where the chain connects. The chain itself
## is true chain: like the necklace a girl would wear ... the bone is just simple and flat ... more shiny/polished ...
## the chain needs to be much longer ... the bone hangs to roughly the middle of her chest"): a flat plate of polished
## steel ([method _bone]), a V-shaped bail clipped over the middle of its long edge, a jump ring through the bail, and a
## fine link chain through that - a necklace long enough to hang to the middle of the chest, dropped beside the bone
## ([method _dropped]), its clasp somewhere along it where it lies on the desk. The parts are laid about their middle, so the
## thing stands where it is placed ([method _pack] keeps its rectangle). Its materials go into [param mats].
static func _dog_tag(r: RandomNumberGenerator, mats: Dictionary) -> Array:
	# POLISHED: a near mirror, the metal's grain gone from it (prop.gdshader) - less polished, a nearby flame's light
	# spread across its whole face and bloomed it white
	mats["tag"] = {"kind": "metal", "color": "#d2d4d7", "polish": r.randf_range(0.9, 0.97), "wear": 0.0}
	mats["chain"] = {"kind": "metal", "color": "#cdcfd2", "polish": 0.85}
	var bone := _bone(r)
	var edge := -float(bone["bar"])
	# THE BAIL: a V, blunt where it is clipped over the plate and round at its far end, out past the edge and tipped down
	# to the desk beyond it, its jump ring at the round end
	var bail: Array = [[-TAG_BAIL.x * 0.1, TAG_BAIL.y * 0.3], [TAG_BAIL.x * 0.1, TAG_BAIL.y * 0.3]]
	for k in 9:
		var a := PI * float(k) / 8.0
		bail.append([cos(a) * TAG_BAIL.x * 0.5, -TAG_BAIL.y * 0.45 - sin(a) * TAG_BAIL.x * 0.5])
	var tip := Vector2(0.0, edge - TAG_BAIL.y * 0.45)
	# THE CHAIN, dropped ([method _dropped]): out of the ring and back to it, a necklace long - and dropped again while the
	# curve it lies along (smoothed between its places) crosses the bone, which it would cut through
	var outline := PackedVector2Array()
	for q in bone["outline"]:
		outline.append(Vector2(float(q[0]), float(q[1])))
	var long := r.randf_range(TAG_LONG.x, TAG_LONG.y)
	var path: Array = []
	var least := INF
	for _drop in TAG_DROPS:
		var tried := _dropped(r, tip, long, outline)
		var over := float(_over(tried, outline))
		if over < least:
			least = over
			path = tried
		if over == 0.0:
			break
	var chain := {"shape": "strand", "material": "chain", "kind": "chain", "thickness": TAG_LINK, "lay": "path", "path": path, "loose": 0.0}
	# EVERYTHING ABOUT ITS MIDDLE: the bone and the loops' reach
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in (bone["outline"] as Array) + path:
		lo = lo.min(Vector2(float(q[0]), float(q[1])))
		hi = hi.max(Vector2(float(q[0]), float(q[1])))
	var c := (lo + hi) * 0.5
	var at := [-c.x, 0.0, -c.y]
	var parts: Array = [
		{"shape": "extrude", "material": "tag", "points": bone["outline"], "height": TAG_THICK, "bevel": 0.015, "at": at},
		# clipped over the plate's edge, its far end tipped down onto the desk
		{"shape": "extrude", "material": "tag", "points": bail, "height": 0.05, "at": [-c.x, TAG_THICK, edge - c.y],
			"turn": [-rad_to_deg(atan2(TAG_THICK, TAG_BAIL.y * 0.7)), 0.0, 0.0]},
		{"shape": "ring", "material": "chain", "radius": 0.11, "thickness": 0.035, "at": [tip.x - c.x, 0.0, tip.y - c.y]},
		chain.merged({"at": at}),
	]
	# THE CLASP, where the chain lies on the desk nearest a seeded place along it, as the chain lies ([method
	# Props.strand_line])
	var laid := Props.sanitize({"things": [{"name": "chain", "parts": [chain]}], "materials": {"chain": mats["chain"]}}, ["#888888"])
	if not (laid["things"] as Array).is_empty():
		var line := Props.strand_line((laid["things"][0]["parts"] as Array)[0], RandomNumberGenerator.new())
		var rest := TAG_LINK * 0.005 + 1e-5
		var aim := floori(line.size() * r.randf_range(0.25, 0.75))
		var best := -1
		for i in line.size():
			if line[i].y <= rest and (best < 0 or absi(i - aim) < absi(best - aim)):
				best = i
		if best > 0 and best < line.size() - 1:
			var tan := (line[best + 1] - line[best - 1]).normalized() * TAG_CLASP.y * 0.005
			var p0 := (line[best] - tan) * 100.0
			var p1 := (line[best] + tan) * 100.0
			parts.append({"shape": "tube", "material": "chain", "radius": TAG_CLASP.x, "path": [[p0.x, p0.y, p0.z], [p1.x, p1.y, p1.z]], "at": at})
	return parts


## A CHAIN AS IT WAS DROPPED (2026-10-29, the user: "a normal person doesn't loop their chain into neat little circles,
## before putting on the table. They just drop it there, chaotically. ... typically it wouldn't be a giant circle of
## chain, but more of a dense pile, or whatever"): a path [[x, z], ...] (centimeters) out of the ring at [param tip] and
## back to it, [param long] along. A walk: its heading turns as it goes, smoothly or in kinks, by drawn amounts the seed
## makes gentle or wild, and is drawn toward a heap's middle the further it strays (the heap drawn dense to loose); now
## and then a run of it is pulled out nearly straight first, and its last stretch heads back to the ring. It turns away
## from the bone ([param bone], grown) rather than cross it - the curve between two places too - what gap is left to the
## ring is spread back along it, and it is drawn again until it is as long as it should be ([constant TAG_DROP] places).
static func _dropped(r: RandomNumberGenerator, tip: Vector2, long: float, bone: PackedVector2Array) -> Array:
	var steps := TAG_DROP
	var heap := r.randf_range(0.9, 2.2)
	var wander := r.randf_range(0.45, 1.3)
	var kinks := r.randf_range(0.0, 0.3)
	var pull := r.randf_range(0.35, 0.7)
	var run := r.randi_range(2, 4) if r.randf() < 0.25 else 0
	var home := r.randi_range(4, 7)
	var away := -PI * 0.5 + r.randf_range(-0.7, 0.7)
	var turns := PackedFloat32Array()
	for k in steps:
		var hard := r.randf() < kinks
		turns.append(r.randf_range(-1.0, 1.0) * (2.4 if hard else wander))
	var clear: PackedVector2Array = Geometry2D.offset_polygon(bone, 0.3)[0]
	var middle := Vector2.ZERO
	for q in bone:
		middle += q
	middle /= float(bone.size())
	var step := long / float(steps)
	var out: Array = []
	for _fit in 4:
		var pts: Array = [tip]
		var a := away
		var curl := 0.0
		var p := tip
		# the heap's middle a pile's reach and a step off the bone, so it lies beside it rather than round it
		var mid := tip + Vector2(cos(away), sin(away)) * (step * float(run) * 0.9 + heap + step + 0.3)
		for k in steps:
			curl = lerpf(curl, turns[k], 0.6)
			a += curl * (0.12 if k < run else 1.0)
			if k >= steps - home:
				# the last stretch, back to the ring
				a = lerp_angle(a, (tip - p).angle(), 0.6)
			elif k >= run:
				var to := mid - p
				a = lerp_angle(a, to.angle(), clampf(to.length() / heap, 0.0, 1.5) * pull * 0.5)
			# AWAY FROM THE BONE: turned off it, toward the side it came from, until the step and the curve to it are clear
			var next := p + Vector2(cos(a), sin(a)) * step
			var side := 1.0 if (p - middle).cross(next - p) > 0.0 else -1.0
			for _turn in 10:
				if k >= steps - 1 or not (Geometry2D.is_point_in_polygon(next, clear) or Geometry2D.is_point_in_polygon((p + next) * 0.5, clear)):
					break
				a += 0.45 * side
				next = p + Vector2(cos(a), sin(a)) * step
			p = next
			pts.append(p)
		# HOME: the gap to the ring spread back along it, then anything left on the bone pushed off it
		var gap: Vector2 = (pts[pts.size() - 1] as Vector2) - tip
		for k in pts.size():
			pts[k] = (pts[k] as Vector2) - gap * float(k) / float(pts.size() - 1)
		for k in range(2, pts.size() - 2):
			var q: Vector2 = pts[k]
			var tries := 0
			while Geometry2D.is_point_in_polygon(q, clear) and tries < 40:
				q += (q - middle).normalized() * 0.15
				tries += 1
			pts[k] = q
		var got := 0.0
		for k in pts.size() - 1:
			got += (pts[k] as Vector2).distance_to(pts[k + 1])
		step *= long / maxf(got, 1.0)
		# its two runs side by side where they leave the ring
		out = []
		for k in pts.size():
			var q: Vector2 = pts[k]
			out.append([q.x + (0.06 if k == 0 else (-0.06 if k == pts.size() - 1 else 0.0)), q.y])
	return out


## How much of a chain laid along [param path] ([method _dropped]) lies over [param outline]: its curve's points on it, as
## Props lays it ([method Props.strand_line]).
static func _over(path: Array, outline: PackedVector2Array) -> int:
	var laid := Props.sanitize({"things": [{"name": "chain", "parts": [{"shape": "strand", "material": "m", "kind": "chain",
		"thickness": TAG_LINK, "lay": "path", "path": path, "loose": 0.0}]}], "materials": {"m": {"kind": "metal", "color": "#888888"}}}, ["#888888"])
	if (laid["things"] as Array).is_empty():
		return 0
	var n := 0
	for q in Props.strand_line((laid["things"][0]["parts"] as Array)[0], RandomNumberGenerator.new()):
		n += int(Geometry2D.is_point_in_polygon(Vector2(q.x, q.z) * 100.0, outline))
	return n


## A BONE'S OUTLINE (centimeters, its long way along x, its middle at the origin): two round lobes at each end and the
## bar between them, as the user's picture has it - the bar a little over half an end's width. `outline` [[x, z], ...]
## round it, `bar` half the bar's width (its long edges at z = +-bar).
static func _bone(r: RandomNumberGenerator) -> Dictionary:
	var length := r.randf_range(3.6, 4.4)
	var wide := length * r.randf_range(0.5, 0.56)        # across an end's two lobes
	var lobe := wide * 0.28
	var off := wide * 0.5 - lobe                         # a lobe's middle off the long axis
	var bar := wide * r.randf_range(0.26, 0.3)            # half the bar's width
	var cx := length * 0.5 - lobe
	# the upper right lobe, from the cleft between the right end's lobes round over its end to the bar's edge
	var a0 := -asin(off / lobe)
	var a1 := PI + asin(clampf((off - bar) / lobe, -1.0, 1.0))
	var arc: Array = []
	for i in TAG_ARC + 1:
		var a := lerpf(a0, a1, float(i) / float(TAG_ARC))
		arc.append(Vector2(cx, off) + Vector2(cos(a), sin(a)) * lobe)
	# the other three by mirroring it, each the way round the outline goes
	var ul: Array = []
	var ll: Array = []
	var lr: Array = []
	for q in arc:
		ul.push_front(Vector2(-(q as Vector2).x, (q as Vector2).y))
		ll.append(-(q as Vector2))
		lr.push_front(Vector2((q as Vector2).x, -(q as Vector2).y))
	# the end's two lobes share their cleft, and the last comes back to where the first began
	var outline: Array = []
	for q in arc + ul + ll.slice(1) + lr.slice(0, lr.size() - 1):
		outline.append([(q as Vector2).x, (q as Vector2).y])
	return {"outline": outline, "bar": bar}


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
	var taken := _pen_taken(look, face)
	var lit: Array = []
	var mat := _mat_rect(spec)
	if bool(look.get("picked", false)):
		_pack(look, seed, face, root, taken, mat, lit)
		return {"node": root, "lit": lit}
	for i in (look["things"] as Array).size():
		var t: Dictionary = look["things"][i]
		var made := Props.build(t["thing"], t["materials"], hash([seed, "desk thing", i]))
		var size: AABB = made["size"]
		var rad := 0.5 * Vector2(size.size.x, size.size.z).length()
		var tall := bool((THINGS[String(t["kind"])] as Dictionary)["tall"]) or size.size.y >= TALL_H
		var near := bool((THINGS[String(t["kind"])] as Dictionary).get("lit", false))
		var r := _rng(seed, "place %d" % i)
		# a candle on the right keeps out of the pen's stretch as a tall thing does
		var right := near and _candle_right(seed, lit.size())
		var at := _placed(r, rad, (tall and not near) or right, taken, (CANDLE_RIGHT if right else CANDLE_BAND) if near else REACH)
		if near and at.x == INF:
			# a candle is the light: past the frame's edge, or anywhere it fits, before none at all
			at = _placed(r, rad, right, taken, CANDLE_RIGHT_WIDER if right else CANDLE_WIDER)
			if at.x == INF:
				at = _placed(r, rad, tall, taken)
		if at.x == INF:
			(made["node"] as Node).free()
			continue
		taken.append(Vector3(at.x, at.y, rad))
		var node: Node3D = made["node"]
		node.set_meta("kind", String(t["kind"]))
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


## A CHOSEN DESK'S THINGS PACKED IN TO THE PAPER ([method _chosen]; 2026-10-29, the user: "almost all of the objects
## placed on the table are outside of the camera's view. Could we add some pressure that would push items inward,
## closer to the paper, in a more dense fashion? ... certain items are better candidates to push outside (like
## candles, which cast light regardless of where they exist)"). The lens is narrow: the widest framing sees the stretch
## [constant SEEN], and while the pen writes the camera sees about four centimeters past the pad's sides. So each thing
## is tried at many places ([constant PACK_TRIES]), most snug against the pad, and set where it is CLOSEST TO THE PAPER
## and most IN THE WIDE FRAME - its footprint its own turned rectangle, a long thing lying along the pad, never the
## circle round it (a dog tag 5 by 8 cm had kept a disc 9.4 cm wide). Flat things first, smallest first: a small thing
## is seen only in the frame, a big one half out of it; then what stands, kept back from the pad as always
## ([constant TALL_LEFT], [constant TALL_RIGHT]); and the candles last, wherever is left nearest their bands - their light
## falls on the page from anywhere. On either side of the pad, each thing leaning to one by the seed ([constant
## PACK_RIGHT]); nothing lies on the pad or behind it, nor in the lane beside its right edge where the pen taps the desk
## ([constant TAP_LANE]), nor on the pens ([method pen_rest]), and nothing tall where the pen leans out and waits
## ([constant DeskMedium.PARK]). Each thing's tries are its own kind's ([method _rng]), so a seed moves them all. Each is added under [param root], what
## burns to [param lit] as [method dress] gives it.
static func _pack(look: Dictionary, seed: int, face: float, root: Node3D, taken: Array, mat: Rect2, lit: Array) -> void:
	var things: Array = look["things"]
	var made_all: Array = []
	var rank: Array = []
	for i in things.size():
		var t: Dictionary = things[i]
		var made := Props.build(t["thing"], t["materials"], hash([seed, "desk thing", String(t["kind"])]))
		made_all.append(made)
		var size: AABB = made["size"]
		var row: Dictionary = THINGS[String(t["kind"])]
		var band := 2.0 if bool(row.get("lit", false)) else (1.0 if bool(row["tall"]) or size.size.y >= TALL_H else 0.0)
		rank.append(band * 10.0 + size.size.x * size.size.z)
	var order: Array = range(things.size())
	order.sort_custom(func(a: int, b: int) -> bool: return float(rank[a]) < float(rank[b]))
	# what is in the way: the pens lying by the pad, then each thing as it is set down (corners, with half the gap)
	var placed: Array = []
	for j in maxi(1, int(look.get("pens", 1))):
		var pen := pen_rest(look, face, j)
		var nib := Vector2((pen["nib"] as Vector3).x, (pen["nib"] as Vector3).z)
		var top := Vector2((pen["top"] as Vector3).x, (pen["top"] as Vector3).z)
		var side := (top - nib).orthogonal().normalized() * (0.006 + PACK_GAP * 0.5)
		var along := (top - nib).normalized() * 0.006
		placed.append(PackedVector2Array([nib - along - side, top + along - side, top + along + side, nib - along + side]))
	var pad_top := -LegalPad.H * 0.5 - LegalPad.BIND_W
	var seen := PackedVector2Array(SEEN)
	var forbid := [
		# the pad and the turned pages behind it, and beside its right edge the lane where the pen taps the desk
		_box(Vector2(-LegalPad.W * 0.5 - PAD_ROOM, -9.0), Vector2(LegalPad.W * 0.5 + TAP_LANE, LegalPad.H * 0.5 + PAD_ROOM)),
	]
	var tall_forbid := forbid + [
		# a tall thing keeps back from the pad's sides and from in front of it, where the camera looks over it
		_box(Vector2(-TALL_LEFT, -9.0), Vector2(TALL_RIGHT, 9.0)),
		_box(Vector2(-9.0, LegalPad.H * 0.5 - 0.028), Vector2(9.0, 9.0)),
	]
	var candle_k := 0
	for i in order:
		var t: Dictionary = things[i]
		var made: Dictionary = made_all[i]
		var kind := String(t["kind"])
		var row: Dictionary = THINGS[kind]
		var size: AABB = made["size"]
		var burns := bool(row.get("lit", false))
		var tall := not burns and (bool(row["tall"]) or size.size.y >= TALL_H)
		var half := Vector2(size.size.x, size.size.z) * 0.5
		var mid := Vector2(size.position.x, size.position.z) + half
		var long := maxf(half.x, half.y) > 1.6 * maxf(minf(half.x, half.y), 1e-4)
		# ITS FACE, what must be seen of it ([constant THINGS] `face`; none: all of it): its rectangle in the thing's own space
		var shown := _face(t, row)
		var r := _rng(seed, "pack " + kind)
		# A CANDLE'S SIDE, by turns: on the right it keeps out of the pen's stretch as a tall thing does
		var right := burns and _candle_right(seed, candle_k)
		candle_k += int(burns)
		# the side this thing leans to: it lies on the other only when its own has no better place
		var leans_right := r.randf() < PACK_RIGHT
		var band := (CANDLE_RIGHT if right else CANDLE_BAND) if burns else Rect2()
		var best := {}
		for _try in PACK_TRIES:
			# turned: a long thing mostly along the pad's side, either end first; any other half the time square to the pad,
			# as things are set down beside a page, and half any way round
			var th := r.randf() * TAU
			if long and r.randf() >= PACK_ASKEW:
				th = (PI * 0.5 if half.x > half.y else 0.0) + r.randf_range(-PACK_SWAY, PACK_SWAY) + (PI if r.randf() < 0.5 else 0.0)
			elif not long and r.randf() < 0.5:
				th = PI * 0.5 * float(r.randi_range(0, 3)) + r.randf_range(-PACK_SWAY, PACK_SWAY)
			var reach := Vector2.ZERO
			for c in [Vector2(half.x, half.y), Vector2(half.x, -half.y)]:
				var w := _turned(c, th)
				reach = reach.max(Vector2(absf(w.x), absf(w.y)))
			# MOSTLY SNUG beside the pad, on the side it leans to more often than not (or, for what stands, as near as it may
			# come; a candle, round its band), the rest anywhere it reaches
			var at := Vector2(r.randf_range(REACH.position.x, REACH.end.x), r.randf_range(REACH.position.y, REACH.end.y))
			var on_right := r.randf() < (0.7 if leans_right else 0.3)
			if r.randf() < 0.75:
				if burns:
					var around := band.grow(0.12)
					at = Vector2(r.randf_range(around.position.x, around.end.x), r.randf_range(around.position.y, around.end.y))
				elif on_right:
					var edge := LegalPad.W * 0.5 + TAP_LANE if not tall else TALL_RIGHT
					at.x = edge + reach.x + 0.001 + pow(r.randf(), 2.0) * 0.18
				else:
					var edge := -LegalPad.W * 0.5 - PAD_ROOM if not tall else -TALL_LEFT
					at.x = edge - reach.x - 0.001 - pow(r.randf(), 2.0) * 0.18
			if at.y < pad_top - 0.3 or not REACH.has_point(at):
				continue
			var foot := PackedVector2Array()
			var bare := PackedVector2Array()
			for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				foot.append(at + _turned((half + Vector2.ONE * PACK_GAP * 0.5) * (c as Vector2), th))
				bare.append(at + _turned(half * (c as Vector2), th))
			var clear := true
			for f in tall_forbid if tall or right else forbid:
				if _overlap(bare, f):
					clear = false
					break
			for f in placed:
				if clear and _overlap(foot, f):
					clear = false
			if not clear:
				continue
			var score := r.randf() * PACK_JITTER
			if burns:
				# a candle: as near its band as is left
				score += at.distance_to(band.get_center())
			else:
				# out of the frame at all costs a step, and then by how much: wholly in it wherever there is room
				var outside := 1.0 - _area(Geometry2D.intersect_polygons(bare, seen)) / maxf(_area([bare]), 1e-8)
				if shown.size.x > 0.0:
					# a face kept in the frame first, the rest of it after: a dog tag's chain may hang past the edge, its bone not
					var seen_face := PackedVector2Array()
					for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
						seen_face.append(at + _turned(shown.get_center() - mid + shown.size * 0.5 * (c as Vector2), th))
					var rest := outside
					outside = 1.0 - _area(Geometry2D.intersect_polygons(seen_face, seen)) / maxf(_area([seen_face]), 1e-8)
					score += PACK_SEEN * 0.25 * rest
				score += _gap(bare) + PACK_SEEN * outside + (PACK_EDGE if outside > 0.01 else 0.0) \
					+ (PACK_SIDE if (at.x > 0.0) != leans_right else 0.0)
			if best.is_empty() or score < float(best["score"]):
				best = {"score": score, "at": at, "turn": th, "foot": foot, "bare": bare}
		if best.is_empty():
			print("ghost: desk - no room for %s; left off" % String(row["label"]))
			(made["node"] as Node).free()
			continue
		placed.append(best["foot"])
		var at: Vector2 = best["at"]
		var node: Node3D = made["node"]
		node.set_meta("kind", kind)
		node.set_meta("foot", best["bare"])
		node.rotation.y = float(best["turn"])
		var off := _turned(mid, float(best["turn"]))
		node.position = Vector3(at.x - off.x, face + (Tables.LAYER_FLOOR + 0.0001 if mat.has_point(at) else 0.0), at.y - off.y)
		root.add_child(node)
		if not (made["wicks"] as Array).is_empty():
			lit.append({"node": node, "wicks": made["wicks"], "glows": made["glows"], "meshes": made["meshes"]})


## WHETHER CANDLE [param k] of the desk of [param seed] stands beside the pad's right ([constant CANDLE_RIGHT]) or its left
## ([constant CANDLE_BAND]): the first's side drawn even, each after it on the other side from the last.
static func _candle_right(seed: int, k: int) -> bool:
	return (_rng(seed, "candle side").randf() < 0.5) != (k % 2 == 1)


## [param v] (x, z) turned [param th] about the vertical, as a node's `rotation.y` turns it.
static func _turned(v: Vector2, th: float) -> Vector2:
	var w := Basis(Vector3.UP, th) * Vector3(v.x, 0.0, v.y)
	return Vector2(w.x, w.z)


## An axis-aligned box from [param lo] to [param hi] as a polygon (x, z).
static func _box(lo: Vector2, hi: Vector2) -> PackedVector2Array:
	return PackedVector2Array([lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)])


## WHAT MUST BE SEEN OF [param t] (a [constant THINGS] row [param row] with a `face`: the material of its parts that must be
## in the frame): their rectangle in the thing's own space (meters, x z) - or an empty one, all of it.
static func _face(t: Dictionary, row: Dictionary) -> Rect2:
	var material := String(row.get("face", ""))
	if material.is_empty():
		return Rect2()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in (t["thing"] as Dictionary)["parts"]:
		var part: Dictionary = p
		if String(part.get("material", "")) != material or not (part.get("points") is Array):
			continue
		var at: Vector3 = part.get("at", Vector3.ZERO) if part.get("at") is Vector3 else Vector3.ZERO
		for q in part["points"]:
			var v := (Vector2(at.x, at.z) + (q as Vector2)) * 0.01
			lo = lo.min(v)
			hi = hi.max(v)
	return Rect2(lo, hi - lo) if lo.x < INF else Rect2()


## Whether two convex polygons overlap: no axis of either's edges parts them.
static func _overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for poly in [a, b]:
		var p: PackedVector2Array = poly
		for i in p.size():
			var axis := (p[(i + 1) % p.size()] - p[i]).orthogonal()
			var a0 := INF
			var a1 := -INF
			for q in a:
				a0 = minf(a0, axis.dot(q))
				a1 = maxf(a1, axis.dot(q))
			var b0 := INF
			var b1 := -INF
			for q in b:
				b0 = minf(b0, axis.dot(q))
				b1 = maxf(b1, axis.dot(q))
			if a1 <= b0 or b1 <= a0:
				return false
	return true


## How far [param foot] lies from the pad's edge (meters; it never lies on it) - on the right, from the lane past it where
## the pen taps the desk ([constant TAP_LANE]), so neither side is nearer.
static func _gap(foot: PackedVector2Array) -> float:
	var pad := Rect2(-LegalPad.W * 0.5, -LegalPad.H * 0.5 - LegalPad.BIND_W, LegalPad.W + TAP_LANE - PAD_ROOM, LegalPad.H + LegalPad.BIND_W)
	var least := INF
	for q in foot:
		var d := Vector2(maxf(maxf(pad.position.x - q.x, q.x - pad.end.x), 0.0), maxf(maxf(pad.position.y - q.y, q.y - pad.end.y), 0.0))
		least = minf(least, d.length())
	return least


## The area of [param polys] together (each a polygon, as [method Geometry2D.intersect_polygons] gives them).
static func _area(polys: Array) -> float:
	var out := 0.0
	for poly in polys:
		var p: PackedVector2Array = poly
		var s := 0.0
		for i in p.size():
			s += p[i].cross(p[(i + 1) % p.size()])
		out += absf(s) * 0.5
	return out


## WHERE THE PEN LIES when nobody holds it (a letter's, before its writer picks it up - [LetterMedium]; 2026-10-28,
## the user: "it would be better if the pen started from a resting place upon the table, to the right of the
## paper"): beside the pad's right edge, its top toward the writer and turned a little out from the pad - as a right
## hand set it down, and as it picks it up again ([constant LetterMedium.LEAN]) - on the desk or on the mat there -
## `{nib, top}`, the ends of its axis on the surface under it (meters, the pad's frame, [param face] the desk's face;
## the pen's own radius is the medium's).
##
## Pen [param k] of a letter's (`look["pens"]` of them, [constant PEN_APART]): beside the first, further out.
static func pen_rest(look: Dictionary, face: float, k := 0) -> Dictionary:
	var rest: Dictionary = (look["pen"] as Dictionary)["rest"]
	var nib: Vector2 = rest["nib"]
	var turn := float(rest["turn"])
	if k > 0:
		var r := _rng(int((look["pen"] as Dictionary).get("seed", 0)), "pen %d" % k)
		nib += Vector2(PEN_APART * float(k), r.randf_range(-PEN_SHIFT, PEN_SHIFT))
		turn += deg_to_rad(r.randf_range(-PEN_SWAY, PEN_SWAY))
	var top := nib + Vector2(sin(turn), cos(turn)) * PEN_LONG
	var mat := _mat_rect(Tables.sanitize(look["top"], look["layers"], look["materials"], []))
	var y := face + (Tables.LAYER_FLOOR + 0.0001 if mat.has_point((nib + top) * 0.5) else 0.0)
	return {"nib": Vector3(nib.x, y, nib.y), "top": Vector3(top.x, y, top.y)}


## The pens' places (`look["pens"]` of them, one by default), as [method _placed] keeps things off them: `[x, z,
## reach]` along each, a pen's width apart.
static func _pen_taken(look: Dictionary, face: float) -> Array:
	var out: Array = []
	for j in maxi(1, int(look.get("pens", 1))):
		var pen := pen_rest(look, face, j)
		var n := int(ceil(PEN_LONG / 0.01))
		for k in n + 1:
			var p := (pen["nib"] as Vector3).lerp(pen["top"], float(k) / float(n))
			out.append(Vector3(p.x, p.z, 0.006))
	return out


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
