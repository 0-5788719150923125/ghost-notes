extends RefCounted
class_name Drifts

## Drifts - what the wind carries: petals, leaves, seeds, keys and feathers, falling from a tree
## overhead or blowing through the scene, settling on the table and lifted off it again by a gust (the
## user, 2026-10-08: "petals could fall from that tree ... either blowing through the scene, or settling
## on the table, or getting carried-off from the table again after another gust"). The air's `drift`
## ([Effects]): its registry, made safe there, built and posed here.
##
## RARE, AND SHAKEN LOOSE BY THE WIND (the user, the same day, of a tree that shed all the time: "falling
## petals should be a rare event - because it takes days or even weeks for all of the foliage to fall"):
## now and then one comes loose in the breeze (`every`, seconds between, about), and a gust shakes a few
## more loose as it blows (`shake`). Never whole flowers - "whole flowers rarely, if ever, fall from
## trees" - only their petals.
##
## EVERYTHING IS A FUNCTION OF SHOW TIME. Each piece LIVES a planned life ([method _live]): it falls -
## drifting with the air ([method Winds.carried], in closed form), in one of its look's WAYS: flat,
## barely rocking; fluttering side to side as a falling leaf does; tumbling over and over, gliding off to
## one side; or twirling down round a small circle, tipped in to it - and a gust sets any of them
## turning over, harder the harder it blows ([method Winds.gust_run]), so nothing sails flat on the wind
## like a thrown disc (the user: "they fly like frisbies. But petals should twirl and spin ... in some
## cases. Not all"). It lands flat on the cloth, lies there shivering in the breeze, and each gust
## strong enough to beat its grip skids it across the cloth or carries it off over the edge, turning
## over as it goes. Lives are planned on dice of their own, as far as they have been asked and no
## further, so any time, asked in any order, poses every piece the same way.
##
## NEVER THROUGH A THING: a fall whose path would pass through the table's edge or anything standing on
## it is thrown again from elsewhere; a skid stops short of what it runs into. NOR THROUGH THE CARDS: the
## table says where the deck and every card lying on the cloth are at any time (its `cover`); a piece
## never comes down where one lies (one once fell through the deck and lay under it), never skids into
## one - and A CARD COMING DOWN ON ONE BLOWS IT ASIDE ([method laid]): out past the card's nearest edge,
## low over the cloth, before the card is down. A piece lies higher than a card is thick and is cupped, so
## one left under a card stood up through it (the user, 2026-10-11: a card "clipped through a leaf that
## had fallen on the table").
##
## NOR UNDER A WASH'S CARDS (the user, 2026-10-14: a petal on the table was "completely unaffected by the
## card-washing: cards are clipping through the petals ... I would expect the petal to move, possibly even
## catching on the cards, riding around on them, falling off, tumbling"): the cards a wash slides over the
## cloth are told ([method laid]'s `sweeps`, the table's [method TableShuffle.sweeps]: each card's place
## every 1/20 s), and a piece lying where one comes is not left under it. Each card it meets does one of
## three things to it, on a die of its own: SHOVES it - out the side that came against it; lets it RIDE -
## the edge slides in under it, onto the face the wash poses; or FLICKS it - a hop and a tumble, to come
## down on the cloth or on the card beyond ([method _shove]). A RIDER HAS MOMENTUM (the user, same day, of a
## petal that "keeps following the card even while it is NOT TOUCHING": it "probably needs a little bit of
## momentum, such that when the underlying card moves - the petal is shaken off of it"): the face under its
## middle changes its way by no more than it grips, and the still air holds it back as the card sweeps it
## along, so a card hauled hard or swept fast goes on without it; it slides back over the face, off the
## edge, and drops to the cloth, which stops it in a few centimeters.
##
## AND ONCE OFF, IT IS FREE (the user, again: the petals were "riding" cards around the wash, "which is
## pretty strange", and slid off them "yet remain attached to them - even though they are way out to the
## side"): a card meets a piece only pressing into it, with the side it came in by ([method _contact]) -
## the card it has just slid off, going away, never catches it again, and a side going by is not the far
## edge it once leapt to, a card's width in a step - and nothing carries it unless its middle is on the
## face. A card under it is a floor, never a wall: what slides off one card lands on the next. Rides are
## the rarer outcome and short ([constant SHOVE_ODDS], [constant RIDE_AIR]). Everything a wash does to it
## is planned whole from the cards' tracks, so any time asked poses it the same; once the wash is over it
## lies where it ended, and the gusts take it from there.
##
## A piece is real geometry - a cupped quad cut to its outline in the shader (shaders/air_drift.gdshader),
## lit by every light on the table, glowing through where the sun is behind it, casting its small
## shadow, and blurred by the lens like everything else.

const SHADER := preload("res://shaders/air_drift.gdshader")

## WHAT CAN DRIFT: its outline (the shader's `shape`), its length (mm) and the range an agent may set it
## in, its width against its length, how fast it falls through still air (m/s), how closely it follows
## the air (1 a petal, more a seed's tuft, which a breath lifts), how far it sways (meters) and how often
## (a second), how far it rocks as it flutters (radians), how fast it turns over when it tumbles, turns
## about the upright, and goes round when it twirls (radians a second), how far a gust turns it over
## (radians a meter of gust), the share of pieces falling each WAY, how deep it is cupped, how much light
## comes through it, its colors when none are given, and how readily it settles where it lands.
const LOOKS := {
	"petals": {"about": "blossom petals - cherry, apple, almond, plum - small and pale, fluttering, tumbling or twirling down", "shape": 0,
		"size": 13.0, "sizes": Vector2(6.0, 25.0), "aspect": 0.78, "fall": 0.45, "carry": 1.0, "sway": 0.05, "beat": 0.9,
		"rock": 0.6, "tumble": 7.0, "spin": 0.5, "twirl": 4.0, "whirl": 5.0,
		"ways": {"flat": 0.2, "flutter": 0.35, "tumble": 0.25, "twirl": 0.2},
		"curl": 0.35, "through": 0.55, "colors": ["#f7d9e2", "#fbe9ee", "#f1c4d2"], "settle": 0.7},
	"rose petals": {"about": "rose, peony or camellia petals - broad, curled, deep-colored, heavier, falling faster, often twirling", "shape": 1,
		"size": 35.0, "sizes": Vector2(20.0, 55.0), "aspect": 0.95, "fall": 0.7, "carry": 0.75, "sway": 0.06, "beat": 0.7,
		"rock": 0.45, "tumble": 5.0, "spin": 0.4, "twirl": 3.0, "whirl": 3.5,
		"ways": {"flat": 0.15, "flutter": 0.25, "tumble": 0.25, "twirl": 0.35},
		"curl": 0.6, "through": 0.4, "colors": ["#9e1530", "#b5203d", "#7d0f25"], "settle": 0.85},
	"leaves": {"about": "autumn leaves - gold, rust, brown, curled - rocking down side to side as a falling leaf does", "shape": 2,
		"size": 60.0, "sizes": Vector2(30.0, 120.0), "aspect": 0.6, "fall": 0.95, "carry": 0.85, "sway": 0.12, "beat": 0.55,
		"rock": 1.0, "tumble": 5.0, "spin": 0.4, "twirl": 2.5, "whirl": 3.0,
		"ways": {"flat": 0.1, "flutter": 0.55, "tumble": 0.2, "twirl": 0.15},
		"curl": 0.45, "through": 0.45, "colors": ["#c8862b", "#9b3d1c", "#d9a441", "#7a5226"], "settle": 0.8},
	"green leaves": {"about": "green leaves torn off by the wind - a summer storm, a tree being shaken", "shape": 2,
		"size": 50.0, "sizes": Vector2(25.0, 110.0), "aspect": 0.55, "fall": 1.0, "carry": 0.85, "sway": 0.1, "beat": 0.6,
		"rock": 0.9, "tumble": 6.0, "spin": 0.5, "twirl": 3.0, "whirl": 3.5,
		"ways": {"flat": 0.1, "flutter": 0.4, "tumble": 0.35, "twirl": 0.15},
		"curl": 0.25, "through": 0.6, "colors": ["#5d7f2e", "#7a9a3a", "#4a6b25"], "settle": 0.75},
	"seeds": {"about": "dandelion seeds or thistledown - white tufts floating slowly, lifted again by any breath", "shape": 3,
		"size": 14.0, "sizes": Vector2(8.0, 25.0), "aspect": 1.0, "fall": 0.14, "carry": 1.25, "sway": 0.03, "beat": 0.35,
		"rock": 0.1, "tumble": 0.0, "spin": 0.3, "twirl": 0.0, "whirl": 0.0, "ways": {"flat": 1.0},
		"curl": 0.0, "through": 0.7, "colors": ["#f6f3ec"], "settle": 0.35},
	"spinners": {"about": "maple or sycamore keys - spinning down like little rotors", "shape": 4,
		"size": 35.0, "sizes": Vector2(22.0, 50.0), "aspect": 0.38, "fall": 0.9, "carry": 0.55, "sway": 0.0, "beat": 0.5,
		"rock": 0.0, "tumble": 0.0, "spin": 14.0, "twirl": 0.0, "whirl": 0.0, "ways": {"rotor": 1.0},
		"curl": 0.1, "through": 0.5, "colors": ["#b58b4c", "#9c7a3f", "#c9a066"], "settle": 0.9},
	"feathers": {"about": "small downy feathers - drifting, rocking slowly, lifted by a breath", "shape": 5,
		"size": 40.0, "sizes": Vector2(15.0, 90.0), "aspect": 0.45, "fall": 0.3, "carry": 1.0, "sway": 0.07, "beat": 0.45,
		"rock": 0.7, "tumble": 3.0, "spin": 0.4, "twirl": 2.0, "whirl": 2.0,
		"ways": {"flat": 0.3, "flutter": 0.55, "twirl": 0.15},
		"curl": 0.25, "through": 0.5, "colors": ["#efe9e0", "#d9d2c6"], "settle": 0.6},
}
## WHERE THEY COME FROM.
const FROMS := {
	"above": "falling from overhead - a tree, a vine, a pergola's flowers - onto the table and round it",
	"wind": "blown in from the side the wind comes from, across the shot, some landing on the table on the way",
}

## HOW OFTEN: the seconds between one piece coming loose in the breeze and the next (about - the
## default, and the range an agent may set), and the most a gust at its strongest shakes loose.
const EVERY := Vector3(60.0, 6.0, 600.0)
const SHAKE := Vector2(1.0, 6.0)
## The most lying on the table at the start, and at once; the most drawn at once (in the air and lying),
## and drifts in one air.
const MAX_LYING := 60
const LYING_AT_ONCE := 40
const MAX_SHOWN := 160
const MAX_DRIFTS := 2
## How far past the time asked lives are planned (seconds: a life is planned whole when it starts), and
## the steps of time they are filed in.
const AHEAD := 2.0
const BIN := 10.0
## A fall: how many places on its way are looked at for a thing in it, and how many times it is thrown
## again from elsewhere before it is let be.
const PATH_LOOKS := 16
const THROWS := 8
## How far over the cloth a piece lies (meters), and how much higher each lying piece is than the one
## before it, so two never fight to be seen.
const REST_UP := 0.0018
const STACK := 0.00015
## The least and the most a gust must blow (m/s) to lift a piece at grip 0 and 1 (and at 1, none does).
const LIFT := Vector2(0.12, 1.4)
## How high a lying piece is lifted by a gust before the deck no longer stands in its way (meters: the
## deck's height and a little).
const DECK_UP := 0.04
## The share of a fall it spends turning flat before it lands (seconds).
const LANDING := 0.45
## A lift: how high it hops (meters, at most). A GUST LIFTS WHAT IT IS BLOWING ALONG, never what it is
## not moving (the user, 2026-10-14: petals "feel like UFOs taking-off. They hover straight up, then drift
## off", one "straight up, then straight back down"): a skid's hop is at most HOP_SLOPE of the distance it
## is carried (a piece that goes nowhere does not rise), and one carried off rises as it is blown, to its
## full height over about OFF_RUN meters, so it leaves along a slant and never straight up. HOW HIGH
## FOLLOWS HOW HARD (the user, same day: a petal blown along "is probably going to tumble across the
## table, not lift-off like a helicopter - BOTH should be a possibility"): the hop of a skid and the
## height of one carried off are both scaled by the gust's peak over the grip ([method _hop]), so a
## breath just past the grip slides it over the edge a few millimeters up, and a strong gust lifts it.
const HOP := 0.04
const HOP_SLOPE := 0.16
const OFF_RUN := 0.3
## BLOWN ASIDE by a card coming down on it ([method laid]): how long before the card is down it goes, and
## by when it is clear (seconds); how high it hops and how much room it leaves the card (meters), and
## how much further it may go.
const ASIDE := Vector2(0.85, 0.4)
const ASIDE_HOP := 0.012
const ASIDE_ROOM := 0.01
const ASIDE_MORE := 0.03
## A WASH'S CARDS SHOVE WHAT LIES ([method _shove]): the share of the cards that shove a piece and, with
## it, that let it ride (the rest flick it); how hard a card must be hauled for a piece riding it to slip
## (m/s each second, about: each piece its own - the most the card can change its way); how hard the
## still air holds a rider back edge on, against its weight at the speed it falls (so a fast sweep leaves
## it behind); how quickly a shoved piece slows on the cloth (its drag, a second, and its grip, m/s each
## second); how fast a card that came down on one, or a deck it is caught in, pushes it out (m/s); a
## flick's sideways speed, rise (m/s) and spin (radians a second); how fast a piece in the air comes back
## down (m/s each second) and loses its sideways way (a second: a petal does not coast with the card it
## left); and how many steps a card's 1/20 s is taken in, so a quick card is never leapt.
const SHOVE_ODDS := Vector2(0.6, 0.75)
const SLIP := Vector2(1.0, 2.5)
const RIDE_AIR := 0.5
const SHOVE_FRICTION := 10.0
const CLOTH_GRIP := 4.0
const SQUEEZE := 0.6
const FLICK_SPEED := Vector2(0.3, 0.8)
const FLICK_RISE := Vector2(0.35, 0.8)
const FLICK_SPIN := Vector2(7.0, 13.0)
const AIR_FALL := 6.0
const AIR_DRAG := 7.0
const SUBSTEPS := 2
## How high a card's face is over the cloth when the table gave no way to ask (meters: a card's thickness
## and the gap the wash leaves) - written out, so this script does not depend on the shuffle's.
const CARD_LAYER := 0.0004
## What a card's record is (floats).
const CARD_STRIDE := 8
## Further than this from the table's middle, or under the air's floor, a piece is gone (meters).
const GONE := 3.0
## The share of falls from above that come down past the table, in the room behind it.
const BEYOND := 0.3


## THE VOCABULARY, as an agent reads it: [method Effects.describe]'s lines for a drift.
static func describe() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("DRIFT: {\"name\", \"kind\": \"drift\", \"look\", \"from\", \"every\" %d-%d (seconds, about, between one piece coming loose in the breeze and the next; %d when left out), \"shake\" 0-%d (how many a gust at its strongest shakes loose; %d when left out), \"colors\" [\"#rrggbb\", ...] (each piece takes one), \"size\" (millimeters long, within the look's range), \"settle\" 0-1 (how many of those that land on the table stay there; the rest skid off with the next breath), \"grip\" 0-1 (how hard a gust must blow to lift one lying on the cloth and carry it off: 0 any breath, 1 none ever), \"lying\" 0-%d (how many already lie on the table when the reading begins)} - what the wind carries: now and then one comes loose and falls - flat, fluttering, tumbling over or twirling round - lands on the cloth (never on the deck or a card) and lies there trembling in the breeze, and a gust shakes a few more loose, sets those in the air turning over, and skids what lies across the cloth or carries it off over the edge. The light's `wind` blows them (still air when it has none). Looks, each with its size and the sizes it can be:" % [
		int(EVERY.y), int(EVERY.z), int(EVERY.x), int(SHAKE.y), int(SHAKE.x), MAX_LYING])
	for k in LOOKS:
		var d: Dictionary = LOOKS[k]
		lines.append("- %s: %s (%s mm, %s to %s)" % [k, String(d["about"]), Effects._mm(float(d["size"])), Effects._mm((d["sizes"] as Vector2).x),
			Effects._mm((d["sizes"] as Vector2).y)])
	lines.append("  from:")
	for k in FROMS:
		lines.append("  - %s: %s" % [k, String(FROMS[k])])
	lines.append("  A tree sheds over days and weeks: a piece every minute or so, and one or two with a gust, reads as a tree in blossom on a breezy day; what lies on the cloth already (`lying`) says how long it has been shedding. A piece every few seconds, and a gust shaking loose six, is a storm stripping the tree. Petals fall, never whole flowers. The cards are laid over what lies on the cloth.")
	return lines


## WHAT AN AGENT WROTE as a drift ([param d]), made safe - or `{}` when its look is not one.
static func sanitize(d: Dictionary) -> Dictionary:
	var look := String(d.get("look", "")).strip_edges().to_lower() if d.get("look") is String else ""
	if not LOOKS.has(look):
		return {}
	var base: Dictionary = LOOKS[look]
	var from := String(d.get("from", "above")).strip_edges().to_lower() if d.get("from") is String else "above"
	return {"kind": "drift", "name": Props._text(d.get("name", look), 80), "look": look, "from": from if FROMS.has(from) else "above",
		"every": Props._num(d.get("every"), EVERY.x, EVERY.y, EVERY.z),
		"shake": Props._num(d.get("shake"), SHAKE.x, 0.0, SHAKE.y),
		"colors": Effects._colors(d.get("colors", d.get("color")), base["colors"]),
		"size": Props._num(d.get("size"), float(base["size"]), (base["sizes"] as Vector2).x, (base["sizes"] as Vector2).y),
		"settle": Props._num(d.get("settle"), float(base["settle"]), 0.0, 1.0),
		"grip": Props._num(d.get("grip"), 0.5, 0.0, 1.0),
		"lying": int(Props._num(d.get("lying"), 0.0, 0.0, float(MAX_LYING)))}


## A DRIFT BUILT for [param fx] (made safe) on a host's [param stage] ([method Effects.build]: its camera,
## its `occluders` - the table first, then what stands on it - its regions, and `wind`, a [method
## Winds.plan] shared with the light, or still air) from [param salt]: its pieces drawn as one MultiMesh,
## its lives planned as they are asked for ([method at]).
static func build(fx: Dictionary, stage: Dictionary, salt: int, root: Node3D) -> Dictionary:
	var look: Dictionary = LOOKS[String(fx["look"])]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	plane.subdivide_width = 5
	plane.subdivide_depth = 5
	mm.mesh = plane
	mm.instance_count = MAX_SHOWN
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = "Drift"
	mi.multimesh = mm
	# the pieces are moved from here, anywhere in the air: their bounds would lie
	mi.custom_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("shape", int(look["shape"]))
	mat.set_shader_parameter("through", float(look["through"]))
	mi.material_override = mat
	root.add_child(mi)
	var occ: Array = stage.get("occluders", [])
	var table: AABB = occ[0] if not occ.is_empty() else AABB(Vector3(-0.6, -0.75, -0.45), Vector3(1.2, 0.75, 0.9))
	var wind: Dictionary = stage.get("wind", {}) if stage.get("wind") is Dictionary else {}
	if wind.is_empty():
		wind = Winds.plan({}, salt)
	var pop := {"fx": fx, "look": look, "mm": mm, "node": mi, "mat": mat, "salt": salt, "wind": wind, "stage": stage,
		"table": table, "things": occ.slice(1), "rest_y": table.end.y + REST_UP,
		"on_top": stage.get("on_top", Callable()), "cover": stage.get("cover", Callable()), "floor": Effects._air_floor(stage),
		"size": float(fx["size"]) * 0.001, "lift": LIFT.x + (LIFT.y - LIFT.x) * float(fx["grip"]),
		"lives": [], "bins": {}, "planned": -INF, "ongoing": [], "resting": [], "made": 0,
		# the breeze's next piece and its number, the next gust to shake some loose, and those shaken loose
		# that start past the plan
		"calm_t": 0.0, "calm_n": 0, "gust_i": 0, "pending": []}
	# THE FIRST may already be on its way down when the show begins
	var r := _dice(pop, 0, -1, "calm")
	pop["calm_t"] = -r.randf() * _fall_time(pop) + r.randf() * float(fx["every"]) * 0.5
	# WHAT ALREADY LIES on the table when the reading begins
	for j in int(fx["lying"]):
		var lv := _lying(pop, j)
		if not lv.is_empty():
			_add(pop, lv)
	return pop


## About how long a piece falls from out of the shot to the cloth (seconds).
static func _fall_time(pop: Dictionary) -> float:
	return 1.4 / maxf(float((pop["look"] as Dictionary)["fall"]), 0.05)


## EVERY PIECE AS IT IS at show time [param t]: `[{xf: Transform3D, color: Color, data: Color}]` - its
## place, its turn and its size, its color, and the shader's (curl, a seed of its own).
static func at(pop: Dictionary, t: float) -> Array:
	_plan_to(pop, t + AHEAD)
	var out: Array = []
	var lives: Array = pop["lives"]
	var bin: Array = (pop["bins"] as Dictionary).get(floori(t / BIN), [])
	for id in bin:
		var lv: Dictionary = lives[int(id)]
		if t < float(lv["t0"]) or t >= float(lv["end"]):
			continue
		out.append({"xf": pose(pop, lv, t), "color": lv["color"], "data": Color(float(lv["curl"]), float(lv["seed"]), 0.0, 0.0)})
		if out.size() >= MAX_SHOWN:
			break
	return out


## The pieces at [param t], drawn.
static func tick(pop: Dictionary, t: float) -> void:
	var now := at(pop, t)
	var mm: MultiMesh = pop["mm"]
	for i in now.size():
		var p: Dictionary = now[i]
		mm.set_instance_transform(i, p["xf"])
		mm.set_instance_color(i, (p["color"] as Color).srgb_to_linear())
		mm.set_instance_custom_data(i, p["data"])
	mm.visible_instance_count = now.size()


# --- the lives ---------------------------------------------------------------------------------------

## Every life that starts before [param until] planned, in the order they start, each filed in the bins
## of the times it spans: now and then one comes loose in the breeze, and each gust shakes a few loose -
## more the harder it blows - as it blows hardest.
static func _plan_to(pop: Dictionary, until: float) -> void:
	if until <= float(pop["planned"]):
		return
	var fx: Dictionary = pop["fx"]
	var pending: Array = pop["pending"]
	while float(pop["calm_t"]) < until:
		pending.append([float(pop["calm_t"]), 0, int(pop["calm_n"])])
		var r := _dice(pop, 0, int(pop["calm_n"]), "calm")
		# how long till the next: as a thing that comes loose at random does - mostly soon, now and then long
		pop["calm_t"] = float(pop["calm_t"]) + float(fx["every"]) * clampf(-log(1.0 - r.randf() * 0.98), 0.1, 4.0)
		pop["calm_n"] = int(pop["calm_n"]) + 1
	var wind: Dictionary = pop["wind"]
	var starts: PackedFloat32Array = wind["starts"]
	while int(pop["gust_i"]) < starts.size() and starts[int(pop["gust_i"])] < until:
		var g := int(pop["gust_i"])
		var r := _dice(pop, 1, g, "shake")
		var hard := clampf(float((wind["peaks"] as PackedFloat32Array)[g]) / Winds.FULL, 0.0, 1.0)
		var span := Winds.gust_span(wind, g)
		for m in floori(float(fx["shake"]) * hard * r.randf_range(0.4, 1.3) + r.randf()):
			pending.append([span.z + r.randf_range(-0.5, 0.5) * (span.z - span.x) + r.randf() * span.y * 0.3, 1 + g, m])
		pop["gust_i"] = g + 1
	pending.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var later: Array = []
	for e in pending:
		if float(e[0]) >= until:
			later.append(e)
			continue
		var lv := _live(pop, int(e[1]), int(e[2]), float(e[0]))
		if not lv.is_empty():
			_add(pop, lv)
	pop["pending"] = later
	# EVERY LIFE STILL GOING is filed into the bins it spans as far as the plan now runs
	var lives: Array = pop["lives"]
	var bins: Dictionary = pop["bins"]
	var still: Array = []
	for id in pop["ongoing"]:
		var lv: Dictionary = lives[int(id)]
		var last := floori(minf(float(lv["end"]), until) / BIN)
		for b in range(maxi(floori(maxf(float(lv["t0"]), -BIN * 4.0) / BIN), int(lv.get("filed", -1000000)) + 1), last + 1):
			if not bins.has(b):
				bins[b] = []
			(bins[b] as Array).append(id)
		lv["filed"] = last
		if float(lv["end"]) > until:
			still.append(id)
	pop["ongoing"] = still
	pop["planned"] = until


## A life kept, to be filed as the plan reaches it.
static func _add(pop: Dictionary, lv: Dictionary) -> void:
	(pop["ongoing"] as Array).append((pop["lives"] as Array).size())
	(pop["lives"] as Array).append(lv)


## The table's top at [param p] (xz): somewhere a piece can lie.
static func _on_top(pop: Dictionary, p: Vector2) -> bool:
	var f: Callable = pop["on_top"]
	if f.is_valid():
		return bool(f.call(p))
	var b: AABB = pop["table"]
	return p.x > b.position.x + 0.01 and p.x < b.end.x - 0.01 and p.y > b.position.z + 0.01 and p.y < b.end.z - 0.01


## Whether [param p] is inside something standing on the table (or the table itself, under its top).
static func _blocked(pop: Dictionary, p: Vector3) -> bool:
	var r := float(pop["size"]) * 0.5
	if p.y < float(pop["rest_y"]) - 0.003:
		var b: AABB = pop["table"]
		if p.y > b.position.y - r and _over_table(pop, Vector2(p.x, p.z)):
			return true
	for o in pop["things"]:
		if (o as AABB).grow(r).has_point(p):
			return true
	return false


## THE RNG of piece [param j] of [param k]: dice of its own.
static func _dice(pop: Dictionary, k: int, j: int, what: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(pop["salt"]), k, j, what])
	return r


## A PIECE'S OWN WAYS: its size, its color, how it falls - its WAY ([constant LOOKS]' `ways`) - and how
## it sways, rocks, turns, tumbles, twirls and is turned over by a gust.
static func _body(pop: Dictionary, r: RandomNumberGenerator) -> Dictionary:
	var look: Dictionary = pop["look"]
	var fx: Dictionary = pop["fx"]
	var colors: Array = fx["colors"]
	var size := float(pop["size"]) * r.randf_range(0.8, 1.2)
	var way := _way(look, r.randf())
	var sway := float(look["sway"]) * r.randf_range(0.6, 1.3)
	var rock := float(look["rock"]) * r.randf_range(0.7, 1.2)
	var fall := float(look["fall"]) * r.randf_range(0.8, 1.2)
	var tumble := 0.0
	var glide := Vector2.ZERO
	match way:
		"flat":
			# all but level, only a little sway
			rock *= 0.2
			sway *= 0.5
		"tumble":
			# over and over, slower down, gliding off to one side as a tumbling card does
			tumble = float(look["tumble"]) * r.randf_range(0.7, 1.3)
			rock *= 0.25
			fall *= 0.8
			glide = Vector2.from_angle(r.randf() * TAU) * r.randf_range(0.03, 0.1)
		"twirl":
			rock = 0.0
	# turned over about its length or across it, a little off either
	var over := Vector3(r.randf_range(-0.3, 0.3), 0.0, 1.0) if r.randf() < 0.5 else Vector3(1.0, 0.0, r.randf_range(-0.3, 0.3))
	var sign := 1.0 if r.randf() < 0.5 else -1.0
	return {"size": size, "color": Effects._col(String(colors[r.randi_range(0, colors.size() - 1)])), "way": way,
		"fall": fall, "c": float(look["carry"]) * r.randf_range(0.85, 1.1),
		"sway": sway, "beat": float(look["beat"]) * r.randf_range(0.8, 1.25),
		"phase": r.randf() * TAU, "sway_ax": Vector2.from_angle(r.randf() * TAU), "rock": rock,
		"tumble": tumble * sign, "over": over.normalized(), "glide": glide,
		"whirl": float(look["whirl"]) * r.randf_range(0.6, 1.4) * sign,
		"twirl": float(look["twirl"]) * r.randf_range(0.7, 1.3) * (1.0 if r.randf() < 0.5 else -1.0), "bank": r.randf_range(0.45, 0.85),
		"spin": float(look["spin"]) * r.randf_range(0.6, 1.4) * (1.0 if r.randf() < 0.5 else -1.0), "yaw": r.randf() * TAU,
		"curl": float(look["curl"]) * r.randf_range(0.6, 1.3), "seed": r.randf(), "aspect": float(look["aspect"]) * r.randf_range(0.85, 1.15),
		"flip": r.randf() < 0.35, "rest_yaw": r.randf() * TAU, "shiver_ax": Vector3(r.randf_range(-1.0, 1.0), 0.0, r.randf_range(-1.0, 1.0)).normalized(),
		"lift": float(pop["lift"]) * r.randf_range(0.8, 1.25)}


## The way of a piece of [param look] whose die is [param u]: one of its `ways`, as often as its share.
static func _way(look: Dictionary, u: float) -> String:
	var ways: Dictionary = look["ways"]
	var total := 0.0
	for w in ways:
		total += float(ways[w])
	var at := u * total
	for w in ways:
		at -= float(ways[w])
		if at < 0.0:
			return String(w)
	return String(ways.keys()[ways.size() - 1])


## What lies on the cloth at [param p] at [param t] - the deck or a card, its top's height - or -INF
## where nothing does ([method Effects.build]'s `cover`, the table's; none, nothing anywhere).
static func _cover(pop: Dictionary, p: Vector3, t: float) -> float:
	var f: Callable = pop["cover"]
	return float(f.call(Vector2(p.x, p.z), t, float(pop["size"]) * 0.5)) if f.is_valid() else -INF


## PIECE [param j] OF [param k] (0 the breeze's, 1 + a gust's own), its fall starting at [param t0]: where
## it starts so that it comes down where it was meant to (over the table or past it, or across the shot
## from the wind's side), and all it does after - landing, lying, skidding, carried off - planned to its
## end. `{}` when no fall clear of everything on the table is found.
static func _live(pop: Dictionary, k: int, j: int, t0: float) -> Dictionary:
	var r := _dice(pop, k, j, "drift")
	var lv := _body(pop, r)
	lv["t0"] = t0
	var wind: Dictionary = pop["wind"]
	var fx: Dictionary = pop["fx"]
	var rest_y := float(pop["rest_y"]) + STACK * float(int(pop["made"]) % 12)
	pop["made"] = int(pop["made"]) + 1
	var blown := String(fx["from"]) == "wind" and float(wind["breeze"]) > 0.05
	var stage: Dictionary = pop["stage"]
	if blown:
		# borne on the wind, it sinks slowly
		lv["fall"] = float(lv["fall"]) * 0.35
	for attempt in THROWS:
		# WHERE IT IS MEANT TO COME DOWN, and how high it starts: out of the shot above it
		var target: Vector3
		if blown:
			# a place in the shot over the table, a little above the cloth, the wind carrying it there
			target = _target(pop, r, false)
			target.y = rest_y + r.randf_range(0.03, 0.3)
		else:
			target = _target(pop, r, r.randf() < BEYOND)
			target.y = rest_y if _on_top(pop, Vector2(target.x, target.z)) else float(pop["floor"])
		var start_y := _out_above(stage, target, rest_y)
		var dur := (start_y - target.y) / float(lv["fall"])
		var t_at := t0 + dur
		if blown:
			# back along the wind from the place it crosses, until out of the shot upwind
			var back := 0.5
			while back < 20.0:
				var p := Vector3(target.x, target.y, target.z) - _xz3(Winds.carried_between(wind, t_at - back, t_at) * float(lv["c"]))
				p.y = target.y + float(lv["fall"]) * back
				var s: Variant = Effects._screen(stage, p)
				if s == null or (s as Vector2).x < -0.1 or (s as Vector2).x > 1.1 or (s as Vector2).y < -0.1 or (s as Vector2).y > 1.1:
					break
				back += 0.25
			dur = back
			t_at = t0 + dur
			start_y = target.y + float(lv["fall"]) * back
		var drift := Winds.carried_between(wind, t0, t_at) * float(lv["c"])
		lv["p0"] = Vector3(target.x - drift.x, start_y, target.z - drift.y)
		# WHERE IT REALLY GOES, falling to the cloth's height: on the top it lands; past it, on to the floor
		var land := _fall_until(pop, lv, rest_y)
		lv["t1"] = land
		if land < INF:
			lv["land"] = _fall_pos(pop, lv, land, false)
		var ok := not _hits(pop, lv, rest_y) and not _on_cards(pop, lv, rest_y)
		if ok:
			break
		if attempt == THROWS - 1:
			return {}
	# AFTER IT LANDS
	var segs: Array = []
	if float(lv["t1"]) < INF:
		var p: Vector3 = lv["land"]
		p.y = rest_y
		# only so many lie at once: past that, it does not settle
		var resting: Array = pop["resting"]
		var lying := 0
		for e in resting:
			lying += 1 if float(e) > float(lv["t1"]) else 0
		var settles := r.randf() < float(fx["settle"]) and lying < LYING_AT_ONCE
		lv["settled"] = settles
		var lift := float(lv["lift"]) if settles else LIFT.x * 0.5
		if float(fx["grip"]) >= 0.999 and settles:
			lift = INF
		lv["grip"] = lift
		segs = _after(pop, lv, p, float(lv["t1"]), lift, r)
		if settles:
			resting.append(float(segs[segs.size() - 1]["end"]) if not segs.is_empty() else Lights.HORIZON)
	else:
		lv["end"] = _gone_at(pop, lv)
	lv["segs"] = segs
	if not segs.is_empty():
		lv["end"] = float((segs[segs.size() - 1] as Dictionary)["end"])
	lv["dice"] = [k, j]
	_make_way(pop, lv)
	return lv


## A piece already lying on the table when the reading begins: on the cloth the camera sees, clear of
## what stands there. {} when no clear place is found.
static func _lying(pop: Dictionary, j: int) -> Dictionary:
	var r := _dice(pop, -1, j, "lying")
	var lv := _body(pop, r)
	var rest_y := float(pop["rest_y"]) + STACK * float(j % 12)
	for i in 24:
		var p := _target(pop, r, false)
		p.y = rest_y
		if _on_top(pop, Vector2(p.x, p.z)) and not _blocked(pop, p + Vector3(0.0, 0.002, 0.0)) and _cover(pop, p, 0.0) == -INF:
			lv["t0"] = -Lights.HORIZON
			lv["t1"] = -Lights.HORIZON
			lv["p0"] = p
			lv["land"] = p
			var lift := float(lv["lift"]) if float((pop["fx"] as Dictionary)["grip"]) < 0.999 else INF
			lv["grip"] = lift
			lv["segs"] = _after(pop, lv, p, -Lights.HORIZON, lift, r)
			lv["end"] = float((lv["segs"][(lv["segs"] as Array).size() - 1] as Dictionary)["end"])
			lv["dice"] = [-1, j]
			_make_way(pop, lv)
			return lv
	return {}


## A place a piece is meant for: on the table where the camera sees it, or, [param beyond], in the room
## past its far edge.
static func _target(pop: Dictionary, r: RandomNumberGenerator, beyond: bool) -> Vector3:
	var b: AABB = pop["table"]
	if beyond:
		return Vector3(r.randf_range(b.position.x - 0.6, b.end.x + 0.6), 0.0, r.randf_range(b.position.z - 1.4, b.position.z - 0.05))
	var seen := Rect2(Vector2(maxf(b.position.x, -0.65), maxf(b.position.z, -0.42)), Vector2.ZERO).expand(
		Vector2(minf(b.end.x, 0.65), minf(b.end.z, 0.35)))
	return Vector3(r.randf_range(seen.position.x, seen.end.x), 0.0, r.randf_range(seen.position.y, seen.end.y))


## How high over [param at] a piece starts so it is out of the shot: just above the top of the picture.
static func _out_above(stage: Dictionary, at: Vector3, low: float) -> float:
	var y := maxf(at.y, low) + 0.25
	while y < 3.0:
		var s: Variant = Effects._screen(stage, Vector3(at.x, y, at.z))
		if s == null or (s as Vector2).y < -0.08:
			break
		y += 0.08
	return y + 0.1


static func _xz3(v: Vector2) -> Vector3:
	return Vector3(v.x, 0.0, v.y)


## WHERE A FALLING PIECE IS at [param t]: carried by the air from where it started, swaying - or going
## round its small circle as it twirls, or gliding off to one side as it tumbles - sinking at its own
## pace with a little lift at the ends of each sway; [param lands] eases the lift out before it lands,
## so it comes down on the cloth at its landing time exactly.
static func _fall_pos(pop: Dictionary, lv: Dictionary, t: float, lands := true) -> Vector3:
	var dt := t - float(lv["t0"])
	var w := TAU * float(lv["beat"]) * dt + float(lv["phase"])
	var sway: Vector2
	var bob := 0.0
	if String(lv["way"]) == "twirl":
		var a0 := float(lv["phase"])
		sway = (Vector2.from_angle(a0 + float(lv["twirl"]) * dt) - Vector2.from_angle(a0)) * float(lv["sway"]) * 0.6
	else:
		sway = (lv["sway_ax"] as Vector2) * float(lv["sway"]) * (sin(w) - sin(float(lv["phase"])))
		bob = float(lv["sway"]) * 0.25 * sin(w) * sin(w)
	var xz := Vector2((lv["p0"] as Vector3).x, (lv["p0"] as Vector3).z) + Winds.carried_between(pop["wind"], float(lv["t0"]), t) * float(lv["c"]) \
		+ sway + (lv["glide"] as Vector2) * dt
	if lands and float(lv.get("t1", INF)) < INF:
		bob *= clampf((float(lv["t1"]) - t) / 0.5, 0.0, 1.0)
	return Vector3(xz.x, (lv["p0"] as Vector3).y - float(lv["fall"]) * dt + bob, xz.y)


## When a fall reaches [param y]: its time, or INF when it comes down past the table (on to the floor).
## Its descent is steady (the lift at each sway's end is eased out to land), so the time is exact.
static func _fall_until(pop: Dictionary, lv: Dictionary, y: float) -> float:
	var p0: Vector3 = lv["p0"]
	var t := float(lv["t0"]) + (p0.y - y) / float(lv["fall"])
	var at := _fall_pos(pop, lv, t, false)
	return t if _on_top(pop, Vector2(at.x, at.z)) else INF


## Whether a fall passes through the table's edge or anything standing on it.
static func _hits(pop: Dictionary, lv: Dictionary, rest_y: float) -> bool:
	var t0 := float(lv["t0"])
	var t1 := float(lv["t1"]) if float(lv["t1"]) < INF else t0 + ((lv["p0"] as Vector3).y - float(pop["floor"])) / float(lv["fall"])
	var top := rest_y
	for o in pop["things"]:
		top = maxf(top, (o as AABB).end.y)
	var lands := float(lv["t1"]) < INF
	# only the stretch low enough to meet anything is looked at - and where it lands
	var low := t0 + maxf(((lv["p0"] as Vector3).y - top - 0.02) / float(lv["fall"]), 0.0)
	var times := PackedFloat32Array()
	for i in PATH_LOOKS:
		times.append(lerpf(low, t1, float(i) / float(PATH_LOOKS - 1)))
	if not lands:
		# past the edge, all the way down the table's side - or a cloth hanging over it
		var b: AABB = pop["table"]
		var by := t0 + ((lv["p0"] as Vector3).y - rest_y) / float(lv["fall"])
		var bottom := t0 + ((lv["p0"] as Vector3).y - b.position.y) / float(lv["fall"])
		for i in PATH_LOOKS:
			times.append(lerpf(by, bottom, float(i) / float(PATH_LOOKS - 1)))
	for t in times:
		var p := _fall_pos(pop, lv, t, lands)
		if lands and t >= t1 - 1e-4:
			p.y = rest_y + 0.002
		if _blocked(pop, p):
			return true
	return false


## Whether a fall comes down where the deck or a card lies, or through the deck on its way down.
static func _on_cards(pop: Dictionary, lv: Dictionary, rest_y: float) -> bool:
	var t1 := float(lv["t1"])
	if t1 >= INF:
		return false
	if _cover(pop, lv["land"], t1) > -INF:
		return true
	for up in [0.01, 0.02, DECK_UP]:
		var t: float = t1 - float(up) / float(lv["fall"])
		var p := _fall_pos(pop, lv, t)
		if _cover(pop, p, t) >= p.y:
			return true
	return false


## When a piece that came down past the table is gone: under the air's floor, or far off.
static func _gone_at(pop: Dictionary, lv: Dictionary) -> float:
	var t := float(lv["t0"]) + ((lv["p0"] as Vector3).y - float(pop["floor"])) / float(lv["fall"])
	return minf(t, float(lv["t0"]) + 60.0)


## ALL IT DOES ONCE IT IS DOWN at [param p] at [param t]: it lies there until a gust blows past
## [param lift] (m/s); the gust skids it across the cloth to where the gust alone would take it - short
## of anything in the way, the deck and the cards too - or, when that is past the table's edge, carries
## it off. Under a card no gust reaches it (a card coming down on it sends it aside first: [method
## laid]). Lying, skidding, carried off: `[{kind, t, end, from, to, gust}]`.
static func _after(pop: Dictionary, lv: Dictionary, p: Vector3, t: float, lift: float, r: RandomNumberGenerator,
		lies: Dictionary = {}) -> Array:
	var wind: Dictionary = pop["wind"]
	var segs: Array = []
	var here := p
	var now := t
	var after := t
	# the way it lies as it comes down - or, blown aside, the way it already lay ([param lies])
	var flip := bool(lies.get("flip", lv["flip"]))
	var yaw := float(lies.get("yaw", lv["rest_yaw"]))
	for n in 64:
		var g := Winds.next_gust(wind, maxf(after, 0.0), lift) if lift < INF else -1
		if g < 0:
			break
		var span := Winds.gust_span(wind, g)
		# it lets go as the gust nears its height
		var go := span.x + (span.z - span.x) * 0.6
		after = span.x + 1e-3
		if _cover(pop, here, go) > -INF:
			# UNDER A CARD: the gust cannot reach it
			continue
		segs.append({"kind": "rest", "t": now, "end": go, "from": here, "flip": flip, "yaw": yaw})
		var stop := span.x + span.y
		var shift := Winds.gust_carried(wind, g, go, stop) * float(lv["c"])
		var to := here + _xz3(shift)
		# SHORT OF WHAT IS IN THE WAY: the first thing on its line stops it there
		var hit := 1.0
		for o in pop["things"]:
			var box: AABB = (o as AABB).grow(float(pop["size"]) * 0.5)
			var h: Variant = box.intersects_segment(here + Vector3(0.0, 0.004, 0.0), to + Vector3(0.0, 0.004, 0.0))
			if h != null:
				hit = minf(hit, maxf(((h as Vector3) - here).length() / maxf(shift.length(), 1e-5) - 0.05, 0.0))
		# and the deck or a card lying on its line
		for i in range(1, 9):
			var u := float(i) / 8.0
			if u >= hit:
				break
			if _cover(pop, here.lerp(to, u), lerpf(go, stop, u)) > -INF:
				hit = maxf(u - 0.125 - 0.05, 0.0)
				break
		var turn := r.randf() < 0.4
		if hit >= 1.0 and not _over_table(pop, Vector2(to.x, to.z)):
			# CARRIED OFF, over the edge and away
			var off := {"kind": "off", "t": go, "end": go + 20.0, "from": here, "flip": flip, "yaw": yaw, "gust": g, "edge": go + 20.0,
				"rise": _hop(wind, g, lift) * 2.0}
			var stopped: Variant = _off_plan(pop, lv, off)
			if stopped == null:
				segs.append(off)
				return segs
			# a thing in its way: it fetches up against it instead
			to = stopped
			hit = 1.0
		to = here.lerp(to, minf(hit, 1.0))
		# a skid that would end off the top but not clear of the table stops at the top's edge
		if not _on_top(pop, Vector2(to.x, to.z)):
			var lo := 0.0
			var hi := 1.0
			for i in 12:
				var mid := (lo + hi) * 0.5
				var m := here.lerp(to, mid)
				if _on_top(pop, Vector2(m.x, m.z)):
					lo = mid
				else:
					hi = mid
			to = here.lerp(to, lo)
		var dist := here.distance_to(to)
		if dist < 0.01:
			# the gust cannot move it (a card, a thing or the edge is right there): it lies on, and is not lifted
			segs.pop_back()
			after = span.x + 1e-3
			continue
		segs.append({"kind": "skid", "t": go, "end": stop, "from": here, "to": to, "flip": flip, "yaw": yaw, "turn": turn, "gust": g,
			"hop": minf(_hop(wind, g, lift), HOP_SLOPE * dist)})
		if turn:
			flip = not flip
		yaw += r.randf_range(-1.2, 1.2)
		here = to
		now = stop
		after = stop
	segs.append({"kind": "rest", "t": now, "end": Lights.HORIZON, "from": here, "flip": flip, "yaw": yaw})
	return segs


## How high gust [param g] lifts what lies at grip [param lift] (meters, at most): the further its peak
## is past the grip, the higher, from a sliver to [constant HOP].
static func _hop(wind: Dictionary, g: int, lift: float) -> float:
	return HOP * clampf((float((wind["peaks"] as PackedFloat32Array)[g]) - lift) / maxf(lift, 0.05), 0.15, 1.0)


## THE CARDS SET DOWN ([param lays]: the air's `lay` moments - `{t, path: [[t, Transform3D], ...]}`, each
## card as it lies from the moment it is down), whenever the schedule moves. EVERY PIECE LYING WHERE ONE
## COMES DOWN IS BLOWN ASIDE FIRST ([method _make_way]): each life is what it was planned to do, amended
## by these - the same for the same cards, asked at any time. The cards a voice has not reached yet are
## not known: a piece goes when its card is. [param sweeps] are the wash's cards sliding on the cloth
## ([method TableShuffle.sweeps]): what lies where they go is shoved by them ([method _shoved]).
static func laid(pop: Dictionary, lays: Array, sweeps: Array = []) -> void:
	var downs: Array = []
	for m in lays:
		var path: Array = (m as Dictionary).get("path", [])
		if not path.is_empty():
			downs.append({"t": float((m as Dictionary)["t"]), "xf": (path[0] as Array)[1]})
	downs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	var key := str(downs.map(func(d: Dictionary) -> String: return "%.3f/%s" % [float(d["t"]), str(d["xf"])]))
	var swept := str(sweeps.map(func(w: Dictionary) -> String: return "%.3f/%d/%d" % [float(w["t"]), int(w["frames"]), hash(w["data"])]))
	key += swept
	if key == String(pop.get("laid", "")):
		return
	pop["laid"] = key
	pop["downs"] = downs
	pop["sweeps"] = sweeps
	pop["swept"] = swept
	var lives: Array = pop["lives"]
	for lv in lives:
		_make_way(pop, lv)
	# filed again from the start: a life's end may have moved
	pop["bins"] = {}
	pop["ongoing"] = range(lives.size())
	for lv in lives:
		(lv as Dictionary).erase("filed")
	var until := float(pop["planned"])
	pop["planned"] = -INF
	_plan_to(pop, until)


## [param lv]'s life as it was planned, with every rest a card comes down on ([member laid]'s cards) cut
## short: it lies until [constant ASIDE] before the card is down, goes aside ([method _aside]) and lives
## on from there ([method _after], on dice of its own). A piece with nowhere to go stays.
static func _make_way(pop: Dictionary, lv: Dictionary) -> void:
	if not lv.has("segs"):
		return
	if not lv.has("planned"):
		lv["planned"] = {"segs": lv["segs"], "end": lv["end"]}
	var segs: Array = ((lv["planned"] as Dictionary)["segs"] as Array).duplicate()
	lv["segs"] = segs
	lv["end"] = (lv["planned"] as Dictionary)["end"]
	# THE WASH'S CARDS first: what they leave is what a card coming down then finds
	var sweeps: Array = pop.get("sweeps", [])
	if not sweeps.is_empty() and not segs.is_empty():
		_shoved(pop, lv, segs, sweeps)
		lv["end"] = float((segs[segs.size() - 1] as Dictionary)["end"])
	var downs: Array = pop.get("downs", [])
	if downs.is_empty() or segs.is_empty():
		return
	var reach := Vector2(TablePositions.CARD.x, TablePositions.CARD.y) * 0.5 + Vector2.ONE * float(pop["size"]) * 0.5
	var dice: Array = lv.get("dice", [0, 0])
	var went := 0
	var i := 0
	while i < segs.size() and went < 8:
		var s: Dictionary = segs[i]
		i += 1
		if String(s["kind"]) != "rest":
			continue
		var from: Vector3 = s["from"]
		for d in downs:
			var down := float((d as Dictionary)["t"])
			if down <= float(s["t"]) or down - ASIDE.x >= float(s["end"]):
				continue
			var xf: Transform3D = (d as Dictionary)["xf"]
			var l := xf.affine_inverse() * Vector3(from.x, xf.origin.y, from.z)
			if absf(l.x) > reach.x or absf(l.z) > reach.y:
				continue
			var r := _dice(pop, int(dice[0]), int(dice[1]), "aside %d" % went)
			var to: Variant = _aside(pop, from, xf, l, reach, down, r)
			if to == null:
				continue
			var go := maxf(float(s["t"]), down - ASIDE.x)
			var stop := maxf(go + 0.12, minf(down - ASIDE.y, go + ASIDE.x - ASIDE.y))
			var turn := r.randf() < 0.3
			var head := s.duplicate()
			head["end"] = go
			var lies := {"flip": bool(s["flip"]) != turn, "yaw": float(s["yaw"])}
			segs.resize(i - 1)
			segs.append(head)
			segs.append({"kind": "aside", "t": go, "end": stop, "from": from, "to": to, "flip": s["flip"], "yaw": s["yaw"],
				"turn": turn, "hop": ASIDE_HOP})
			segs.append_array(_after(pop, lv, to, stop, float(lv.get("grip", INF)), r, lies))
			i += 1
			went += 1
			break
	lv["end"] = float((segs[segs.size() - 1] as Dictionary)["end"])


## WHERE A PIECE AT [param from] GOES, out from under the card coming down at [param xf] ([param l] its
## place on the card, [param reach] the card's half and the piece's own): past the card's nearest edge
## and a little further, or the next nearest when that way is off the top, into a thing, or onto the
## deck or another card lying there at [param down]. Null when no way is clear.
static func _aside(pop: Dictionary, from: Vector3, xf: Transform3D, l: Vector3, reach: Vector2, down: float,
		r: RandomNumberGenerator) -> Variant:
	var sx := 1.0 if l.x >= 0.0 else -1.0
	var sz := 1.0 if l.z >= 0.0 else -1.0
	var out := Vector2(reach.x + ASIDE_ROOM + r.randf() * ASIDE_MORE, reach.y + ASIDE_ROOM + r.randf() * ASIDE_MORE)
	var ways := [[reach.x - absf(l.x), Vector3(sx * out.x, 0.0, l.z)], [reach.y - absf(l.z), Vector3(l.x, 0.0, sz * out.y)],
		[reach.x + absf(l.x), Vector3(-sx * out.x, 0.0, l.z)], [reach.y + absf(l.z), Vector3(l.x, 0.0, -sz * out.y)]]
	ways.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var up := Vector3(0.0, 0.004, 0.0)
	for w in ways:
		var world := xf * ((w as Array)[1] as Vector3)
		var to := Vector3(world.x, from.y, world.z)
		if not _on_top(pop, Vector2(to.x, to.z)) or _blocked(pop, to + up) or _cover(pop, to, down) > -INF:
			continue
		var clear := true
		for o in pop["things"]:
			if (o as AABB).grow(float(pop["size"]) * 0.5).intersects_segment(from + up, to + up) != null:
				clear = false
				break
		if clear:
			return to
	return null


## [param lv]'s life as it was planned, with the rest a wash's cards ([param sweeps]) come over cut short
## where the first of them touches it: it lies until then, is shoved, carried and flicked by them as long
## as the wash goes ([method _shove]), and lives on from where it leaves it ([method _after], on dice of
## its own). A piece the cards never reach is left as it was.
static func _shoved(pop: Dictionary, lv: Dictionary, segs: Array, sweeps: Array) -> void:
	# what the same cards did to this piece last time is what they do (a card told of after it
	# changes nothing here, and a run is dear)
	var swept := String(pop.get("swept", ""))
	if String(lv.get("shoved_for", "")) == swept:
		segs.clear()
		segs.append_array(lv["shoved"])
		return
	var dice: Array = lv.get("dice", [0, 0])
	var m := float(pop["size"]) * 0.5
	var went := 0
	for sw in sweeps:
		var w0 := float((sw as Dictionary)["t"])
		var hz := float((sw as Dictionary)["hz"])
		var frames := int((sw as Dictionary)["frames"])
		for i in segs.size():
			var s: Dictionary = segs[i]
			if String(s["kind"]) != "rest" or float(s["end"]) <= w0 or float(s["t"]) >= w0 + float(frames - 1) / hz:
				continue
			var from: Vector3 = s["from"]
			var a := maxi(ceili((float(s["t"]) - w0) * hz), 0)
			var b := mini(floori((minf(float(s["end"]), w0 + float(frames - 1) / hz) - w0) * hz), frames - 1)
			# a step wider than the card is, so a quick one is never missed between two frames
			var f := _touched(sw, Vector2(from.x, from.z), m + 0.01, a, b)
			if f < 0:
				continue
			f = maxi(f - 1, a)
			var r := _dice(pop, int(dice[0]), int(dice[1]), "shove %d" % went)
			var run := _shove(pop, lv, sw, s, f, r)
			var head := s.duplicate()
			head["end"] = w0 + float(f) / hz
			segs.resize(i)
			segs.append(head)
			segs.append(run["seg"])
			segs.append_array(_after(pop, lv, run["to"], float(run["end"]), float(lv.get("grip", INF)), r, run["lies"]))
			went += 1
			break
	lv["shoved_for"] = swept
	lv["shoved"] = segs.duplicate()


## The first frame of [param a]..[param b] of wash [param sw] at which a card on the cloth, or in the deck,
## has [param p] (xz) within [param m] of its edge - or -1 when none does.
static func _touched(sw: Dictionary, p: Vector2, m: float, a: int, b: int) -> int:
	var data: PackedFloat32Array = sw["data"]
	var n := int(sw["cards"])
	var half := Vector2(TablePositions.CARD.x, TablePositions.CARD.y) * 0.5 + Vector2.ONE * m
	for f in range(a, b + 1):
		for j in n:
			var o := (f * n + j) * 5
			if data[o + 3] < 0.0:
				continue
			var l := _local(p, Vector2(data[o], data[o + 1]), data[o + 2])
			if absf(l.x) <= half.x and absf(l.y) <= half.y:
				return f
	return -1


## [param p] in the frame of a card whose middle is [param c], turned [param yaw]: across it, along it.
static func _local(p: Vector2, c: Vector2, yaw: float) -> Vector2:
	var d := p - c
	return Vector2(d.x * cos(yaw) - d.y * sin(yaw), d.x * sin(yaw) + d.y * cos(yaw))


## The point [param l] of a card whose middle is [param c], turned [param yaw] - across, along - in the world.
static func _world(l: Vector2, c: Vector2, yaw: float) -> Vector2:
	return c + Vector2(cos(yaw), -sin(yaw)) * l.x + Vector2(sin(yaw), cos(yaw)) * l.y


## Every card of wash [param sw] at step [param s] (of [constant SUBSTEPS] to a frame), the frames either
## side of it blended: [constant CARD_STRIDE] floats a card - x, z, turn, spread (-1 off the cloth), place
## in the order, and the height of its face over the cloth at its middle with the slope of it across x
## and z (the table's own - [method _rest_at]).
static func _cards_at(sw: Dictionary, s: int) -> PackedFloat32Array:
	var data: PackedFloat32Array = sw["data"]
	var n := int(sw["cards"])
	var last := int(sw["frames"]) - 1
	var fa := mini(floori(float(s) / float(SUBSTEPS)), last)
	var fb := mini(fa + 1, last)
	var u := 0.0 if fa >= last else float(s % SUBSTEPS) / float(SUBSTEPS)
	var ra := _rest_at(sw, fa)
	var rb := _rest_at(sw, fb)
	var out := PackedFloat32Array()
	out.resize(n * CARD_STRIDE)
	for j in n:
		var oa := (fa * n + j) * 5
		var ob := (fb * n + j) * 5
		var o := j * CARD_STRIDE
		out[o] = lerpf(data[oa], data[ob], u)
		out[o + 1] = lerpf(data[oa + 1], data[ob + 1], u)
		out[o + 2] = lerp_angle(data[oa + 2], data[ob + 2], u)
		out[o + 3] = -1.0 if data[oa + 3] < 0.0 or data[ob + 3] < 0.0 else data[oa + 3]
		out[o + 4] = data[oa + 4]
		out[o + 5] = lerpf(ra[j * 3], rb[j * 3], u)
		out[o + 6] = lerpf(ra[j * 3 + 1], rb[j * 3 + 1], u)
		out[o + 7] = lerpf(ra[j * 3 + 2], rb[j * 3 + 2], u)
	return out


## How high each card's face is over the cloth at frame [param f] of wash [param sw], and how it slopes:
## three floats a card, asked of the table as it is needed (what the wash poses is dear) and kept. Where
## the table gave no way to ask, one thickness over the cloth and flat.
static func _rest_at(sw: Dictionary, f: int) -> PackedFloat32Array:
	var cache: Dictionary = sw.get("rest_cache", {})
	if not cache.has(f):
		var out := PackedFloat32Array()
		var ask: Variant = sw.get("rest")
		if ask is Callable and (ask as Callable).is_valid():
			out = (ask as Callable).call(f)
		else:
			out.resize(int(sw["cards"]) * 3)
			for j in int(sw["cards"]):
				out[j * 3] = CARD_LAYER
		cache[f] = out
		sw["rest_cache"] = cache
	return cache[f]


## The height of card [param j]'s face at [param p] (xz), over the cloth, of [param cards] ([method _cards_at]).
static func _face(cards: PackedFloat32Array, j: int, p: Vector2) -> float:
	var o := j * CARD_STRIDE
	return maxf(cards[o + 5] + cards[o + 6] * (p.x - cards[o]) + cards[o + 7] * (p.y - cards[o + 1]), 0.0)


## HOW A WASH'S CARDS TREAT A PIECE lying at [param seg]'s place from frame [param f0] of wash [param sw]:
## `{seg: the track, to: where it lies after, end: when, lies: {flip, yaw}}`. Stepped through the cards'
## own tracks, each step one of three: ON THE CLOTH it slides on what it was given and the cloth soon
## stops it ([method _slowed]); ON A CARD the face under its middle carries it, no harder than it grips -
## sticking, it goes where the card does and turns with it; hauled harder, it slides on the face, the
## way it was going - and once its middle is off the edge it is off, and drops (its card gathered or
## thrown, with a hop); IN THE AIR it falls as a petal does, turning, to the cloth or the highest face
## there. A CARD MEETS IT ONLY PRESSING INTO IT ([method _contact]: the side it came in by, never a side
## moving away - one it has just slid off does not catch it again) and SHOVES it out that side, lets it
## RIDE - the edge slides in under it, and nothing carries it until its middle is on the face - or FLICKS
## it ([constant SHOVE_ODDS], a die of its own for each card): a card of the deck is only ever a wall, a
## card covering what rides another's face is met as one on the cloth. It goes on until the cards are
## done and it lies still, flat and on the cloth (or three seconds past, whatever it is doing), and what
## the table's top or a thing standing on it refuses is never taken.
static func _shove(pop: Dictionary, lv: Dictionary, sw: Dictionary, seg: Dictionary, f0: int, r: RandomNumberGenerator) -> Dictionary:
	var dice: Array = lv.get("dice", [0, 0])
	var hz := float(sw["hz"]) * float(SUBSTEPS)
	var dt := 1.0 / hz
	var n := int(sw["cards"])
	var st := CARD_STRIDE
	var last := (int(sw["frames"]) - 1) * SUBSTEPS
	var start: Vector3 = seg["from"]
	var base_y := start.y
	var m := float(pop["size"]) * 0.5
	var half := Vector2(TablePositions.CARD.x, TablePositions.CARD.y) * 0.5
	var fall := float(lv["fall"])
	var hold := r.randf_range(SLIP.x, SLIP.y)
	var p := Vector2(start.x, start.z)
	var v := Vector2.ZERO
	var y := 0.0
	var vy := 0.0
	var yaw := float(seg["yaw"])
	var roll := PI if bool(seg["flip"]) else 0.0
	var spin := 0.0
	var tilt := 0.0
	var aloft := 0.0
	# 0 on the cloth, 1 on card `on` (`up` once its middle has been over the face), 2 in the air
	var mode := 0
	var on := -1
	var up := false
	var outcome := {}
	var pos := PackedVector3Array()
	var ang := PackedVector3Array()
	pos.append(start)
	ang.append(Vector3(yaw, roll, 0.0))
	var s := f0 * SUBSTEPS
	var before := _cards_at(sw, s)
	var calm := 0
	while s < last + 3 * int(hz):
		s += 1
		var cur := _cards_at(sw, mini(s, last))
		var pp := p
		# WHERE IT GOES ON ITS OWN, by what it is doing
		match mode:
			0:
				p += v * dt
				v = _slowed(v, dt)
			1:
				var o := on * st
				var c := Vector2(cur[o], cur[o + 1])
				var w := cur[o + 2]
				if cur[o + 3] < 0.5:
					# ITS CARD THROWN out from under it: tossed with a hop and a tumble, the way the card
					# went; GATHERED into the deck: off it, out the nearest side, in the air until it is clear
					# (the deck is a wall)
					mode = 2
					vy = r.randf_range(0.1, 0.3)
					v *= 0.5
					if cur[o + 3] >= 0.0:
						var l := _local(p, Vector2(before[o], before[o + 1]), before[o + 2])
						var reach := half + Vector2.ONE * m
						var gap := Vector2(reach.x - absf(l.x), reach.y - absf(l.y))
						var nl := Vector2(signf(l.x) if l.x != 0.0 else 1.0, 0.0) if gap.x < gap.y else Vector2(0.0, signf(l.y) if l.y != 0.0 else 1.0)
						var go := (maxf(minf(gap.x, gap.y), 0.0) + 0.003) * AIR_DRAG
						var speed := maxf(SQUEEZE, go / 0.95)
						vy = maxf(vy, AIR_FALL * 0.5 * -log(1.0 - go / speed) / AIR_DRAG)
						v += (Vector2(cos(w), -sin(w)) * nl.x + Vector2(sin(w), cos(w)) * nl.y) * speed
					spin = r.randf_range(FLICK_SPIN.x, FLICK_SPIN.y) * (1.0 if r.randf() < 0.5 else -1.0) * 0.6
					aloft = 0.0
				else:
					# THE FACE UNDER ITS MIDDLE CARRIES IT (the user, 2026-10-14: petals slid off the cards
					# "yet remain attached to them - even though they are way out to the side"): the way
					# the card's own point under it goes this step, changed by no more than it grips -
					# and nothing at all while it is not on the face (climbing on, the edge sliding in
					# under it)
					var lb := _local(pp, Vector2(before[o], before[o + 1]), before[o + 2])
					if minf(half.x - absf(lb.x), half.y - absf(lb.y)) >= 0.0:
						# and THE AIR it is carried through holds it back: as hard as its weight when it goes
						# as fast as it falls, but edge on ([constant RIDE_AIR]) - a card swept fast goes on
						# without it
						var drag := -v * (9.8 * RIDE_AIR * v.length() / (fall * fall))
						var need := (_world(lb, c, w) - pp) / dt - v
						if (need / dt - drag).length() <= hold:
							v += need
							yaw += wrapf(w - before[o + 2], -PI, PI)
						else:
							v += (need.normalized() * hold + drag) * dt
					else:
						v = _slowed(v, dt)
					p += v * dt
					var l := _local(p, c, w)
					var depth := minf(half.x - absf(l.x), half.y - absf(l.y))
					up = up or depth >= 0.0
					if (up and depth < 0.0) or depth < -m:
						# OFF ITS EDGE, with the way it was going: down to the cloth (or a face), which stops it
						mode = 2
						vy = 0.0
						spin = r.randf_range(FLICK_SPIN.x, FLICK_SPIN.y) * (1.0 if r.randf() < 0.5 else -1.0) * 0.3
						aloft = 0.0
			2:
				p += v * dt
				v *= exp(-AIR_DRAG * dt)
				vy = maxf(vy - AIR_FALL * dt, -fall)
				y += vy * dt
				roll += spin * dt
				aloft += dt
				tilt = 0.4 * sin(aloft * 9.0)
		# WHAT IS UNDER IT: the highest face of the cards on the cloth that hold it
		var under := _under(cur, p)
		var top := int(under.x)
		var support := under.y
		if mode == 2 and y <= support:
			# LANDED, on the card that is there - or the cloth
			spin = 0.0
			vy = 0.0
			if top >= 0:
				mode = 1
				on = top
				up = true
				y = support + 0.0003
			else:
				mode = 0
				y = 0.0
		# THE CARDS PRESSING INTO IT, as the one nearest the top is met first; a few turns to settle between two
		var touched := false
		if mode != 2 or y < support + 0.003:
			for _it in 3:
				var hit := -1
				var held := -1
				var hit_c := {}
				var held_c := {}
				for j in n:
					var sp := cur[j * st + 3]
					if sp < 0.0 or (mode == 1 and j == on):
						continue
					if mode == 1 and sp >= 0.5 and cur[j * st + 4] <= cur[on * st + 4]:
						continue
					# a card whose face is under it does not press it: it comes down on that face
					if y > _face(cur, j, p) + 0.0001:
						continue
					var k := _contact(cur, before, j, p, pp, v, m, dt)
					if k.is_empty():
						continue
					if sp < 0.5:
						if held < 0:
							held = j
							held_c = k
					elif hit < 0 or cur[j * st + 4] > cur[hit * st + 4]:
						hit = j
						hit_c = k
				# a card that is over it first, a wall of the deck after
				var wall := hit < 0 and held >= 0
				if wall:
					hit = held
					hit_c = held_c
				if hit < 0:
					break
				touched = true
				var out_w: Vector2 = hit_c["out"]
				var vc: Vector2 = hit_c["vel"]
				var kind := 0
				if not wall and not bool(hit_c["under"]):
					if not outcome.has(hit):
						var u := _dice(pop, int(dice[0]), int(dice[1]), "card %d" % hit).randf()
						outcome[hit] = 0 if u < SHOVE_ODDS.x else (1 if u < SHOVE_ODDS.y else 2)
					kind = int(outcome[hit])
				var to := p + out_w * float(hit_c["depth"])
				# never off the top, into a thing, or - shoved by a card - into the deck, which shoves back
				var refused := not _on_top(pop, to) or _blocked(pop, Vector3(to.x, base_y + 0.004, to.y)) \
					or (not wall and _in_deck(cur, to, m))
				if kind != 1 and refused and not wall:
					kind = 1
				if kind == 1 and not wall:
					# UP ONTO IT: the edge slides in under it, where it is
					mode = 1
					on = hit
					up = false
				elif kind == 2 and not wall and not refused:
					# FLICKED: out of the way with a hop, and over
					p = to
					v = out_w * r.randf_range(FLICK_SPEED.x, FLICK_SPEED.y) + vc * 0.6
					mode = 2
					vy = r.randf_range(FLICK_RISE.x, FLICK_RISE.y)
					spin = r.randf_range(FLICK_SPIN.x, FLICK_SPIN.y) * (1.0 if r.randf() < 0.5 else -1.0)
					aloft = 0.0
					break
				elif not refused:
					# SHOVED, ahead of the card's edge (off the face it rode, perhaps: then it drops)
					p = to
					v = out_w * maxf(vc.dot(out_w), 0.0)
					if bool(hit_c["under"]):
						# out from under a card no faster than SQUEEZE, however many it is under
						break
				else:
					break
		# WHAT THE TABLE'S TOP AND ITS THINGS REFUSE
		if mode != 1 and p != pp and (not _on_top(pop, p) or _blocked(pop, Vector3(p.x, base_y + 0.004, p.y))):
			p = pp
			v = Vector2.ZERO
		# OVER A FACE, IT LIES ON IT, never under it: on the cloth and pushed onto a card, or one slid in
		# under it faster than it could be met - and in the air, flicked from the cloth to a place over
		# a card, it starts from that card's face (it had hung a step at the cloth's height, under it)
		under = _under(cur, p)
		if mode == 0 and under.x >= 0.0:
			mode = 1
			on = int(under.x)
			up = true
		elif mode == 2 and under.x >= 0.0 and y < under.y + 0.0003:
			y = under.y + 0.0003
		# ITS HEIGHT AND TURN: up with the face it lies on at once, and down to where it lies by easing
		if mode != 2:
			var want := under.y + 0.0003 if under.x >= 0.0 else 0.0
			if mode == 1:
				# CLIMBING ON: the face's height comes in as its middle comes over the edge, from half its
				# own size outside it - never held up in the air beside the card
				var l := _local(p, Vector2(cur[on * st], cur[on * st + 1]), cur[on * st + 2])
				var depth := minf(half.x - absf(l.x), half.y - absf(l.y))
				want = maxf(want, (_face(cur, on, p) + 0.0003) * clampf((depth + m) / (m + 0.003), 0.0, 1.0))
			y = want if want > y else y + (want - y) * (1.0 - exp(-25.0 * dt))
			roll += (roundf(roll / PI) * PI - roll) * (1.0 - exp(-10.0 * dt))
			tilt *= exp(-12.0 * dt)
		pos.append(Vector3(p.x, base_y + y, p.y))
		ang.append(Vector3(yaw, roll, tilt))
		before = cur
		# DONE: the cards are over, and it lies still on the cloth
		if s >= last and mode == 0 and not touched and v.length() < 0.003 and absf(y) < 0.0003 \
				and absf(roll - roundf(roll / PI) * PI) < 0.02 and absf(tilt) < 0.02:
			calm += 1
			if calm > 2:
				break
		else:
			calm = 0
	# IT LIES FLAT, on the cloth, where it is
	roll = roundf(roll / PI) * PI
	pos[pos.size() - 1] = Vector3(p.x, base_y, p.y)
	ang[ang.size() - 1] = Vector3(yaw, roll, 0.0)
	var t0 := float(sw["t"]) + float(f0) / float(sw["hz"])
	var seg_out := {"kind": "shoved", "t": t0, "end": t0 + float(pos.size() - 1) / hz, "hz": hz, "pos": pos, "ang": ang,
		"from": start, "flip": bool(seg["flip"]), "yaw": float(seg["yaw"])}
	return {"seg": seg_out, "to": Vector3(p.x, base_y, p.y), "end": float(seg_out["end"]),
		"lies": {"flip": posmod(int(roundf(roll / PI)), 2) == 1, "yaw": yaw}}


## HOW CARD [param j] OF [param cur] PRESSES INTO a piece at [param p] going [param v] (at [param pp] a step
## of [param dt] ago, when the cards were [param was]), the piece inside its edge by [param m] (half its
## own size): `{out: the way it is pushed (xz), depth: how far, vel: the card's own point there (m/s),
## under: whether it was there already}` - or empty when the card is not pressing into it. The side it
## presses with is the side the piece came in by (once the side the card was going toward, which could be
## the far one: a piece leapt a card's width in a step). A card that was there already - it came down
## there, or the piece is caught in the deck it was gathered into - presses only while the piece's middle
## is under it, out the nearest side, [constant SQUEEZE] at most a second; one that is not moving into it
## (the card it has just slid off, one going by alongside) does not touch it at all.
static func _contact(cur: PackedFloat32Array, was: PackedFloat32Array, j: int, p: Vector2, pp: Vector2, v: Vector2,
		m: float, dt: float) -> Dictionary:
	var o := j * CARD_STRIDE
	var half := Vector2(TablePositions.CARD.x, TablePositions.CARD.y) * 0.5
	var reach := half + Vector2.ONE * m
	var c := Vector2(cur[o], cur[o + 1])
	var w := cur[o + 2]
	var l := _local(p, c, w)
	# a card it is already out against (shoved to its very edge) is not met again
	if minf(reach.x - absf(l.x), reach.y - absf(l.y)) <= 0.0002:
		return {}
	var cb := Vector2(was[o], was[o + 1])
	var lb := _local(pp, cb, was[o + 2])
	var vel := (_world(_local(p, cb, was[o + 2]), c, w) - p) / dt
	var sides := [Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)]
	var side := -1
	var out_by := -INF
	if was[o + 3] >= 0.0:
		for k in 4:
			var nk: Vector2 = sides[k]
			var d := lb.dot(nk) - absf(reach.dot(nk))
			if d > out_by:
				out_by = d
				side = k
	var there := side < 0 or out_by < -0.0002
	if there:
		# THERE ALREADY: the nearest way out
		side = 0
		for k in 4:
			if absf(reach.dot(sides[k])) - l.dot(sides[k]) < absf(reach.dot(sides[side])) - l.dot(sides[side]):
				side = k
	var nl: Vector2 = sides[side]
	var out := Vector2(cos(w), -sin(w)) * nl.x + Vector2(sin(w), cos(w)) * nl.y
	var depth := absf(reach.dot(nl)) - l.dot(nl)
	var under := false
	if there:
		under = minf(half.x - absf(l.x), half.y - absf(l.y)) > 0.0
		if not under and cur[o + 3] >= 0.5 and (vel - v).dot(out) <= 0.005:
			return {}
		depth = minf(depth, SQUEEZE * dt)
	return {"out": out, "depth": depth, "vel": vel, "under": under}


## What is under a piece at [param p] (xz) among [param cards]: the card on the cloth whose face is highest
## there, and that face's height over the cloth - `(-1, 0)` when it is over the cloth.
static func _under(cards: PackedFloat32Array, p: Vector2) -> Vector2:
	var half := Vector2(TablePositions.CARD.x, TablePositions.CARD.y) * 0.5
	var top := -1
	var face := 0.0
	for j in cards.size() / CARD_STRIDE:
		var o := j * CARD_STRIDE
		if cards[o + 3] < 0.5:
			continue
		var l := _local(p, Vector2(cards[o], cards[o + 1]), cards[o + 2])
		if absf(l.x) <= half.x and absf(l.y) <= half.y:
			var f := _face(cards, j, p)
			if top < 0 or f > face:
				face = f
				top = j
	return Vector2(top, face)


## Whether a piece at [param p] would be within [param m] of a card of the deck in [param cards] (one on
## the cloth less than half spread out: the deck, or the pile it is gathered into).
static func _in_deck(cards: PackedFloat32Array, p: Vector2, m: float) -> bool:
	var reach := Vector2(TablePositions.CARD.x, TablePositions.CARD.y) * 0.5 + Vector2.ONE * m
	for j in cards.size() / CARD_STRIDE:
		var o := j * CARD_STRIDE
		if cards[o + 3] < 0.0 or cards[o + 3] >= 0.5:
			continue
		var l := _local(p, Vector2(cards[o], cards[o + 1]), cards[o + 2])
		if absf(l.x) < reach.x - 0.0002 and absf(l.y) < reach.y - 0.0002:
			return true
	return false


## A piece's way [param v] on the cloth after [param dt]: the cloth's grip ([constant CLOTH_GRIP]) and its
## drag ([constant SHOVE_FRICTION]) stop it within a few centimeters.
static func _slowed(v: Vector2, dt: float) -> Vector2:
	var sp := v.length()
	if sp <= CLOTH_GRIP * dt:
		return Vector2.ZERO
	return v * ((sp - CLOTH_GRIP * dt) / sp * exp(-SHOVE_FRICTION * dt))


## Where a piece carried off is at [param t]: carried with the air and lifted as it is blown (by how far,
## not how long - [constant OFF_RUN]), sinking again once past the table's edge.
static func _off_pos(pop: Dictionary, lv: Dictionary, s: Dictionary, t: float) -> Vector3:
	var from: Vector3 = s["from"]
	var carry := Winds.carried_between(pop["wind"], float(s["t"]), t) * float(lv["c"])
	var y := from.y + float(s["rise"]) * (1.0 - exp(-carry.length() / OFF_RUN)) - float(lv["fall"]) * maxf(t - float(s["edge"]), 0.0)
	return Vector3(from.x + carry.x, y, from.z + carry.y)


## Whether [param p] (xz) is over the table or near enough its edge that a piece sinking there would meet
## it - or a cloth hanging over it.
static func _over_table(pop: Dictionary, p: Vector2) -> bool:
	var b: AABB = pop["table"]
	var m := 0.04
	return p.x > b.position.x - m and p.x < b.end.x + m and p.y > b.position.z - m and p.y < b.end.z + m


## A piece carried off ([param s]): when it is clear of the table, and so begins to sink, and when it is
## gone - under the air's floor. Null when it gets clear; where it was last before something standing
## on the table got in its way, when it does not.
static func _off_plan(pop: Dictionary, lv: Dictionary, s: Dictionary) -> Variant:
	var t0 := float(s["t"])
	var t := t0
	var last: Vector3 = s["from"]
	while t < t0 + 20.0:
		var p := _off_pos(pop, lv, s, t)
		if not _over_table(pop, Vector2(p.x, p.z)):
			break
		if _blocked(pop, p) or (p.y < float(pop["rest_y"]) + DECK_UP and _cover(pop, p, t) >= p.y - 0.003):
			return Vector3(last.x, (s["from"] as Vector3).y, last.z)
		last = p
		t += 0.05
	s["edge"] = t
	var top := (s["from"] as Vector3).y + float(s["rise"])
	s["end"] = t + (top - float(pop["floor"])) / maxf(float(lv["fall"]), 0.05)
	return null


# --- posed ---------------------------------------------------------------------------------------------

## LIFE [param lv] POSED at [param t]: its place, its turn and its size (x across it, z along it, y the
## way its face looks).
static func pose(pop: Dictionary, lv: Dictionary, t: float) -> Transform3D:
	var size := float(lv["size"])
	var scale := Basis.from_scale(Vector3(size * float(lv["aspect"]), size, size))
	var t1 := float(lv["t1"])
	if t < t1 or t1 >= INF:
		var at := _fall_pos(pop, lv, t)
		var b := _falling_basis(pop, lv, t)
		if t1 < INF and t > t1 - LANDING:
			# TURNING FLAT as it comes down
			var e := smoothstep(t1 - LANDING, t1, t)
			b = Basis(b.get_rotation_quaternion().slerp(_lying_basis(bool(lv["flip"]), float(lv["rest_yaw"])).get_rotation_quaternion(), e))
		return Transform3D(b * scale, at)
	for s in lv["segs"]:
		var d: Dictionary = s
		if t >= float(d["end"]):
			continue
		var flat := _lying_basis(bool(d["flip"]), float(d["yaw"]))
		match String(d["kind"]):
			"rest":
				# TREMBLING IN THE BREEZE, harder as it rises
				var shiver := 0.18 * Winds.strength_at(pop["wind"], t) * sin(17.0 * t + float(lv["seed"]) * 40.0)
				return Transform3D(Basis(lv["shiver_ax"], shiver) * flat * scale, d["from"])
			"skid", "aside":
				# as far along as the gust has carried it - or, blown aside by a card, eased out and in
				var along := smoothstep(float(d["t"]), float(d["end"]), t)
				if String(d["kind"]) == "skid":
					var gw := Winds.swell_carry(pop["wind"], int(d["gust"]), t)
					var g0 := Winds.swell_carry(pop["wind"], int(d["gust"]), float(d["t"]))
					var g1 := Winds.swell_carry(pop["wind"], int(d["gust"]), float(d["end"]))
					along = clampf((gw - g0) / maxf(g1 - g0, 1e-5), 0.0, 1.0)
				var at := (d["from"] as Vector3).lerp(d["to"], along)
				at.y += float(d["hop"]) * sin(PI * along)
				var b := flat
				if bool(d["turn"]):
					var axis := Vector3((d["to"] as Vector3).z - (d["from"] as Vector3).z, 0.0, (d["from"] as Vector3).x - (d["to"] as Vector3).x)
					if axis.length() > 1e-5:
						b = Basis(axis.normalized(), PI * along) * flat
				return Transform3D(b * scale, at)
			"shoved":
				# SHOVED, RIDING AND FLICKED by a wash's cards: the planned track, a sample a step
				var at: PackedVector3Array = d["pos"]
				var an: PackedVector3Array = d["ang"]
				var f := clampf((t - float(d["t"])) * float(d["hz"]), 0.0, float(at.size() - 1))
				var i0 := int(f)
				var i1 := mini(i0 + 1, at.size() - 1)
				var w := an[i0].lerp(an[i1], f - float(i0))
				var b := Basis(Vector3.UP, w.x) * Basis(Vector3.RIGHT, w.z) * Basis(Vector3.FORWARD, w.y)
				return Transform3D(b * scale, at[i0].lerp(at[i1], f - float(i0)))
			"off":
				# TURNING OVER as the gust carries it, harder the harder it blows; a key spins as it falls
				var dt := t - float(d["t"])
				var b := flat
				if String(lv["way"]) == "rotor":
					b = Basis(Vector3.UP, float(lv["spin"]) * dt) * flat
				elif float(lv["whirl"]) != 0.0:
					var roll := float(lv["whirl"]) * Winds.gust_run(pop["wind"], float(d["t"]), t) + signf(float(lv["whirl"])) * 2.0 * dt
					b = Basis(Vector3.UP, float(lv["spin"]) * dt) * flat * Basis(lv["over"], roll)
				return Transform3D(b * scale, _off_pos(pop, lv, d, t))
	return Transform3D(Basis.from_scale(Vector3.ONE * 1e-4), Vector3(0.0, -50.0, 0.0))


## Lying flat on the cloth, face up or down, turned [param yaw] about the upright.
static func _lying_basis(flip: bool, yaw: float) -> Basis:
	return Basis(Vector3.UP, yaw) * (Basis(Vector3.FORWARD, PI) if flip else Basis.IDENTITY)


## HOW A FALLING PIECE IS TURNED at [param t], by its way: turning slowly about the upright; rocking
## with its sway (tipped toward the way it swings, as a falling leaf rocks); tumbling over and over; or
## twirling round, tipped in toward the circle it goes round. Whatever its way, a gust turns it over,
## harder the harder it blows. A seed's tuft keeps upright, its fluff to the sky; a key spins on its own.
static func _falling_basis(pop: Dictionary, lv: Dictionary, t: float) -> Basis:
	var dt := t - float(lv["t0"])
	var b := Basis(Vector3.UP, float(lv["yaw"]) + float(lv["spin"]) * dt)
	match String(lv["way"]):
		"rotor":
			# A KEY'S WING tips down from its seed as it spins
			return b * Basis(Vector3.RIGHT, 0.35)
		"twirl":
			var a := float(lv["phase"]) + float(lv["twirl"]) * dt
			b = Basis(Vector3(-sin(a), 0.0, cos(a)), float(lv["bank"])) * b
		_:
			var w := TAU * float(lv["beat"]) * dt + float(lv["phase"])
			var ax2: Vector2 = lv["sway_ax"]
			b = Basis(Vector3(-ax2.y, 0.0, ax2.x), float(lv["rock"]) * cos(w)) * b
	var roll := float(lv["tumble"]) * dt + float(lv["whirl"]) * Winds.gust_run(pop["wind"], float(lv["t0"]), t)
	if roll != 0.0:
		b = b * Basis(lv["over"], roll)
	return b
