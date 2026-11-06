extends RefCounted
class_name TablePaint

## TablePaint - THE PAINTED SURFACE, played: a part of [TableWork] (next/painted_surface.md). Every part with a `skin` on the
## table, the design painted on it ([Skins], the episode's `skin.json`), and the `paint` law ([Motions]) that lays it on - a
## tool fetched from where it rests, loaded from its paint, pressed onto the surface and moved over each element as its
## program has it ([method Skins.program]), back to the paint when it runs dry, and back where it was when the act is done.
##
## A PURE FUNCTION OF SHOW TIME, as all the work is: each element is shown where its tool has been by its reveal map and the
## moments the schedule gives its strokes ([method spans]); a tool's place, the bend of its hairs, the paint on its tip and the
## give of a sponge are worked out from the time ([method pose], [method tick]) - nothing is painted frame by frame. THE PAINT
## IS COMPOSED IN 2D, an element a sprite in its order, in two small viewports of the skin's own (its color, and what its
## finish is - rough, metallic, glittering), which the part's own shader lays over it from its front (prop.gdshader).
##
## A HELD TOOL STANDS IN NOTHING (feedback 0016): it is held the way its work asks - a brush by its tip, a pad flat, a sponge flat to
## spread and by its corner to dab and to dip ([method _contact_for]) - and at every place its program keeps, found before the bake
## begins, it points the way nearest a hand's that keeps its own surface out of the surface it works on and what holds it
## ([method _cleared]), and out of the wall of the pot it dips into ([method _pot_clear]); a sponge pressed in gives back to the
## surface it is pressed on ([constant GIVE]).

## The skin's composed pictures, pixels a millimeter.
const CANVAS_PX := Skins.PX_MM
## A ACT'S OWN STEPS (seconds, at a hand's pace): fetched from where the tool rests to its work, a load from its paint, a rinse,
## a move between elements, and back where it was.
const FETCH := 2.0
const LOAD := 3.2
const RINSE := 4.0
const MOVE := 1.4
const RETURN := 2.0
## HOW FAR AN ACT'S STROKES MAY BE SLOWED (a share of a hand's pace) before what is left is rests between its elements, the
## longest one rest is (seconds), and how far they may be hurried.
const SLOW_MOST := 1.6
const REST_MOST := 4.0
const QUICK_MOST := 0.4
## The least an act that paints is hurried to, of its natural length: hardly at all - a face is never rushed (at 0.6, 856886's was
## done in 9:22 under ten minutes of words).
const LEAST := 0.85
## How far over a surface a tool's tip is held as it touches (meters) and how far into it a brush is pressed at its hardest,
## and how high it lifts on its way from where it rests (meters).
const TOUCH := 0.00025
const PRESS_INTO := 0.0006
const FETCH_LIFT := 0.08
## HOW A TOOL IS HELD over the surface: its handle out of the surface, up along it and out to the side its work is on - never
## toward the camera, where it would hide the work, and never across what it has painted (shares, then made a direction); and over
## its paint, upright and leaning toward the camera.
const HELD_OUT := 0.55
const HELD_UP := 0.35
const HELD_SIDE := 0.6
const HELD_SIDE_EDGE := 0.15
## A TRIP (to the paint, the water, the towel): how far over its place a tool comes and leaves (meters), how far across a towel it is
## wiped, and the trips there are - a dry is the towel's.
const TRIP_LIFT := 0.012
const WIPE := 0.015
## ...and over a pot's or a cup's rim it comes in and leaves at least this far (meters): from over its paint alone, a brush came in
## to the water cup through its wall and was held back on it (joker-motivation 856886, 2026-11-05).
const RIM_CLEAR := 0.01
## THE WAY BETWEEN PLACES GOES OVER WHAT STANDS IN IT ([method _lift_over]), as a carry's does ([method TableWork._clearance]): what
## stands on the table where the tools go is mapped once as they are prepared, the highest surface over each cell this wide
## (meters), this far past the places they go, and looked at as far round the tip as the tool is wide - half its width and this
## much more (meters): widened by two centimeters for every tool, the face lying back 60 degrees stood 3.5 cm over itself and every
## brush hopped between its strokes. A brush taken from the water cup to the palette went through the setting spray between them,
## 11 cm tall, and was held back on it by twenty to thirty centimeters, act after act (joker-motivation 856886).
const TOPS_CELL := 0.01
const TOPS_MARGIN := 0.08
const TOPS_BESIDE := 0.005
const TRIPS := ["load", "rinse", "dry"]
const DRY := 2.6
## WATER CLOUDS AS A BRUSH IS RINSED IN IT: each rinse takes it this far toward the color rinsed out of the brush.
const CLOUD := 0.1
## A SPRAY: how long its tool is held ready before and after, how far off the surface (millimeters), and the mist's puffs.
const SPRAY_STANDOFF := 120.0
## ...and which way from it: out of the surface, to its right, up along it (shares, then made a direction).
const SPRAY_FROM := Vector3(0.6, 0.7, 0.3)
## A SPONGE GIVES this far where it is pressed hardest (meters): pushed in that far, squashed back to the surface - it had been
## squashed off it, its pressed face 3.6 mm over the face it painted.
const GIVE := 0.003
## ...AND IS PUSHED INTO ITS PAINT this far to take it up (meters), a puff into its powder this far, held there for this share of the
## dip (the user, 2026-11-06: "the sponge barely touched the foundation case ... we should have really pushed the sponge into the
## foundation, to pick-up a lot of the dust").
## AND PRESSED, IT IS PRESSED FLAT (the user, 2026-11-06, of the 8 mm it had been pushed: "It touches at the very tip of a corner,
## and doesn't compress the sponge at all ... it didn't pick up enough foundation to equal the amount that is then applied"): the foam
## squashed back from its middle along its length had been drawn a sponge a quarter shorter, its corner on the cream. So what would go
## under its paint's surface is drawn ON it, the [constant FLAT_BAND] over it squeezed and spread out by [constant FLAT_SPREAD] of what
## it gave ([method _flat_lift], prop_common.gdshaderinc's `flat_on`) - pushed in by the end of its length ([method tool_of]'s `end`),
## DABBED into it two or three times as it is held there ([constant LOAD_EASE] between, never out of it).
const LOAD_PRESS := 0.012
const LOAD_PRESS_PAD := 0.004
const LOAD_HELD := 1.8
const LOAD_EASE := 0.35
## A BRUSH DIPS INTO ITS PAINT this far (meters), its hairs in it as it turns (feedback 0019, joker-motivation 209459: "When it dips
## into the container, it didn't touch there either" - it had been taken to a millimeter over the paint's surface and no further).
const BRUSH_DIP := 0.003
## ...AND IS NEVER STOOD OFF WHAT IT PAINTS FURTHER THAN THIS (meters, [method _cleared]): its hairs bend against what it meets.
const BRUSH_STAND_MOST := 0.0015
const FLAT_BAND := 0.008
const FLAT_SPREAD := 0.2
## HOW A SPONGE IS HELD BY ITS CORNER ([constant Skins.FLAT_MANNERS]): its middle out of the surface, up along it and out to the side
## its work is on (shares, as [constant HELD_OUT]) - nearer upright than a brush's handle; by its face, flat on the surface.
const CORNER_HELD := Vector3(0.85, 0.3, 0.3)
## A HELD TOOL STANDS IN NOTHING (feedback 0016, joker-motivation 209459: "This sponge is clipping right through the nose" - its flat
## face held at a brush's tilt stood 36 mm in the mask's nose and its board, and a sponge 5 cm across went into a pot 4.6 cm across):
## its own surface ([member tools]' `points`) is held clear of the surface it works on and what holds it, and of the pot it dips into,
## by the way it points nearest how a hand holds it there ([method _cleared], [method _pot_clear]) - tried this far from the surface's
## normal (degrees), each this many ways round it - and stood off only as far as it must.
const CLEAR_TILTS := [15.0, 30.0, 45.0, 60.0]
const CLEAR_ROUND := 12
## ...measured against the surface where it lies, every this far (meters), and this far past it all round (what holds it) - read across
## its slope, never straight down it: at 3 mm and read down it, a sponge's corner on a mask's rim or under its nose stood 9 to 17 mm in
## the cliff its cell straddled;
const CLEAR_CELL := 0.002
const CLEAR_BEYOND := 0.04
## ...the highest of it kept over blocks this many cells across, so what stands well over it is never looked at closer;
const CLEAR_BLOCK := 8
## ...and read across it no more than this much shallower than straight down (deep under a nose's tip, its slope over two millimeters made
## a point 10 mm in it read 2);
const SLOPE_MOST := 1.5
## ...what a way of holding it a radian further from how a hand holds it costs, in how far it stands off the surface (meters), and
## how far a sponge's face may stand off before its corner is tried there ([method _held_keys]);
const CLEAR_TURN := 0.006
const FLAT_MOST := 0.004
## ...and the way between two places looked at, unless they are this close (millimeters) and turned less than this (degrees) - every
## that far along it and that much of its turn, at most so many times (three along a 113 mm way had missed the nose it crossed);
const ARC_STEP := 3.0
const ARC_TURN := 4.0
const ARC_LOOKS := 40
## ...clear of the surface by this much where it is not pressed onto it (meters).
const ARC_CLEAR := 0.003
## ...looked at only this far from either key (shares of the way): nearer, the key's own clearance is what holds it.
const ARC_ENDS := 0.15
## ...a pot's wall kept this far from (meters, past the swirl of a rinse);
const CLEAR_WALL := 0.0055
## ...and the tool's surface found across each face of its box every this far (meters), at least two and at most twelve a side: a
## centimeter apart, the nose's underside stood 7 mm in a sponge's flat face between them.
const POINTS_EVERY := 0.005
## THE PAINT ON A BRUSH'S TIP: as much as it shows just loaded, what never comes out until it is rinsed, and how long it takes to
## lay most of it (seconds).
const TIP_FULL := 0.9
const TIP_LEFT := 0.35
const TIP_LASTS := 18.0
## How long a tool's hairs take to settle after its act (seconds): it is posed that long after.
const SETTLE := 0.6
## How finely a skin's surface is found (millimeters between rays), and how far its edge may face away from its front (the cosine)
## or lie under the surface beside it (meters) before it counts as past the surface ([method _surface_of]).
const SURFACE_STEP := 2.0
const EDGE_FACING := 0.35
const EDGE_CLIFF := 0.004
## The stones' size against what the design says, and how far they stand out of the surface (shares of their radius).
const STONE_OUT := 0.25

const _CANVAS := preload("res://shaders/skin_paint.gdshader")

var work: TableWork
## Every skin on the table: `{ti, name, part, holder, meshes, xform (its part into its holder's space), box (its own, meters),
## frame (millimeters), outline, shape, design, surface, canvas: [color viewport, finish viewport], items: {id: {...}}, stones,
## clear (what stands over it, [method _obstacles]), held ([method _held_keys])}`
var skins: Array = []
## Each tool a paint track works ("w3:pose"/"t1:pose" -> {tip, grip, kind, mm, tufts, sponges, node, len, x0, center, points,
## contact, contacts: {name: {tip, grip, give, bend, reach}}})
var tools := {}
## A trip's hold over its pot, found as it is first asked ([method _pot_clear]) - each its own, the bake's twin as the app's.
var _pots := {}
## The paint on each tool's tip over time: channel -> [[t, color or null], ...] in order ([method spans]).
var _loads := {}
## The programs made, kept across a puppeteer's acts written again: key -> {program, cover, when, rect}.
var _made := {}
## Which act lays each element, and which go over it again: "skin|id" -> {act, manner, tool}; and the order acts lay them.
var _layers := {}
var _dust: Array = []         # [{t, p}] a pat's puff of powder, and a sweep's
var _drawn_t := NAN
var _active: Array = []       # items whose time is now, as last found
var _creams: Array = []       # [{color, at, ti}] the paints on the table, where each is taken up from (the table's space, as it stood)
## What stands where the tools go ([method _map_tops]): the highest surface over each [constant TOPS_CELL] (-INF where none); its first
## cell's corner (the table's x, z) and how many cells across x and z. Made before the bake begins, only read after.
var _tops := PackedFloat32Array()
var _tops_at := Vector2.ZERO
var _tops_n := Vector2i.ZERO


func _init(w: TableWork) -> void:
	work = w


## A BREATH for the app's thread, in a long loop on a table built on a worker ([method TableMedium._breathe]).
func _breathe() -> void:
	if work != null and work.medium != null:
		work.medium._breathe()


## THE BAKE'S OWN ([TablePhysics]'s twin, [param w]): the same skins, tools, programs and paints, found before the bake began
## and only read on its thread - TWO THREADS SHARE NOTHING EITHER WRITES.
func twin_for(w: TableWork) -> TablePaint:
	var t := TablePaint.new(w)
	t.skins = skins
	t.tools = tools
	t._made = _made
	t._layers = _layers
	t._creams = _creams
	t._tops = _tops
	t._tops_at = _tops_at
	t._tops_n = _tops_n
	return t


func clear() -> void:
	for s in skins:
		for vp in (s as Dictionary).get("canvas", []):
			if is_instance_valid(vp):
				(vp as Node).queue_free()
		for st in (s as Dictionary).get("stone_nodes", []):
			if is_instance_valid(st):
				(st as Node).queue_free()
	skins = []
	tools = {}
	_pots = {}
	_loads = {}
	_layers = {}
	_dust = []
	_active = []
	_drawn_t = NAN


# --- what is on the table ----------------------------------------------------------------------------

## Thing [param ti]'s skins as [method Props.build] made them ([param b]'s `skins`).
func take(ti: int, b: Dictionary) -> void:
	for s in b.get("skins", []):
		var sd: Dictionary = (s as Dictionary).duplicate()
		sd["ti"] = ti
		sd["name"] = String((work.things[ti] as Dictionary)["name"])
		var box: AABB = sd["box"]
		sd["frame"] = Vector2(box.size.x, box.size.y) * 1000.0
		sd["design"] = {}
		sd["items"] = {}
		sd["canvas"] = []
		sd["stone_nodes"] = []
		sd["clear"] = {}
		sd["held"] = {}
		skins.append(sd)


## The skin a thing's name (and its part's, if it gives one) names, or -1.
func skin_named(thing: String, part := "") -> int:
	for k in skins.size():
		var s: Dictionary = skins[k]
		if String(s["name"]).to_lower() == thing.strip_edges().to_lower() and (part.is_empty() or String(s["part"]).to_lower() == part.strip_edges().to_lower()):
			return k
	return -1


## THE DESIGNS ([param doc], `skin.json` as parsed) on the skins they name - before the acts are found on the table, which
## name their elements.
func set_designs(doc: Dictionary) -> void:
	tools = {}
	_pots = {}
	for s in skins:
		var sd: Dictionary = s
		sd["design"] = {}
		for d in doc.get("designs", []):
			if not (d is Dictionary):
				continue
			var dd: Dictionary = d
			if String(dd.get("thing", "")).to_lower() == String(sd["name"]).to_lower() and (String(dd.get("part", "")).is_empty()
					or String(dd.get("part", "")).to_lower() == String(sd["part"]).to_lower()):
				sd["design"] = Skins.sanitize(dd, sd["frame"])
		if sd.get("surface") == null:
			sd["surface"] = _surface_of(sd)


## THE ACTS THAT PAINT ([member TableWork.acts], found on the table): each element's program for the tool that lays it, its
## pictures and its reveal map, its sprites in its skin's canvas - and each paint act's length at a hand's pace (`_natural`,
## the least it is hurried to `_min_length`), which the schedule and the readers go by.
func prepare() -> void:
	_layers = {}
	# WHO LAYS EACH ELEMENT: the first act that paints it, in the order the reading comes to them; any later one goes over it
	for a in _in_reading_order(work.acts):
		for tr in (a as Dictionary)["tracks"]:
			var t: Dictionary = tr
			if String(t["law"]) != "paint":
				continue
			var si := int(t.get("_skin", -1))
			if si < 0:
				continue
			var tool := tool_of(String(t["_ch"]), t)
			for id in t["paint"]:
				var key := "%d|%s" % [si, String(id).to_lower()]
				if not _layers.has(key):
					var el := element(si, String(id))
					if el.is_empty():
						continue
					var manner := Skins.manner_of(el, String(tool["kind"]), String(t.get("manner", "")))
					_layers[key] = {"act": String((a as Dictionary)["name"]), "manner": manner, "mm": _width(tool, t, manner)}
	for si in skins.size():
		(skins[si] as Dictionary)["_rest"] = work._world_of((skins[si] as Dictionary)["holder"])
		_canvas(si)
	# THE PAINTS ON THE TABLE, where each is taken up from
	_creams = []
	var cream := int((Props.MATERIALS["cream"] as Dictionary)["code"])
	for ti in work.things.size():
		for m in (work.things[ti] as Dictionary)["meshes"]:
			var mi := m as MeshInstance3D
			var mat := mi.material_override as ShaderMaterial
			if mat == null or mat.get_shader_parameter("kind") == null or int(mat.get_shader_parameter("kind")) != cream:
				continue
			var box: AABB = work._world_of(mi) * mi.get_aabb()
			_creams.append({"color": mat.get_shader_parameter("color"), "at": Vector3(box.get_center().x, box.end.y + 0.001, box.get_center().z), "ti": ti})
	# ...and each act's length at a hand's pace (every program it asks made now, before the bake reads them)
	for a in work.acts:
		var natural := 0.0
		var paints := false
		for tr in (a as Dictionary)["tracks"]:
			if String((tr as Dictionary)["law"]) == "paint":
				paints = true
				natural = maxf(natural, float(_natural_of(a as Dictionary, tr as Dictionary)))
		if paints:
			(a as Dictionary)["_natural"] = natural
			(a as Dictionary)["_min_length"] = natural * LEAST
			if not bool((a as Dictionary).get("under", false)):
				(a as Dictionary)["length"] = maxf(float((a as Dictionary)["length"]), natural * LEAST)
			else:
				(a as Dictionary)["length"] = natural
	# ...and what stands where the tools go, for their ways over it
	_map_tops()
	# ...AND HOW EACH TOOL IS HELD at every place its programs keep, clear of what it works on ([method _cleared]): found here, on
	# this thread, before the bake reads them
	_hold_all()


## How wide tool [param tool] lays paint for track [param tr] in [param manner] (millimeters): the track's `size`, else its own
## ([method Skins.width_for]).
static func _width(tool: Dictionary, tr: Dictionary, manner: String) -> float:
	return float(tr["size"]) if tr.has("size") else Skins.width_for(String(tool["kind"]), float(tool["mm"]), manner)


## EVERY PAINT TRACK'S TOOL HELD CLEAR at each place of each program it goes through ([method _held_keys]), kept by its skin -
## each skin's whole map new, so what the bake reads is never written; what was found before for the same program and tool, kept.
func _hold_all() -> void:
	var fresh: Array = []
	for si in skins.size():
		_obstacles(skins[si] as Dictionary)
		fresh.append({})
	for a in work.acts:
		for tr in (a as Dictionary)["tracks"]:
			var t: Dictionary = tr
			if String(t["law"]) != "paint" or not t.has("_ch") or int(t.get("_skin", -1)) < 0:
				continue
			var si := int(t["_skin"])
			var ch := String(t["_ch"])
			var tool := tool_of(ch, t)
			var was: Dictionary = (skins[si] as Dictionary).get("held", {})
			var plan := plan_of(t, float((a as Dictionary).get("_natural", 0.0)))
			for ph in plan["phases"]:
				if not (ph as Dictionary).has("prog"):
					continue
				var prog: Dictionary = (ph as Dictionary)["prog"]
				var contact := _contact_for(tool, String(prog.get("manner", "")))
				var key := _held_key(prog, ch, contact)
				if (fresh[si] as Dictionary).has(key):
					continue
				(fresh[si] as Dictionary)[key] = was[key] if was.has(key) else _held_keys(si, prog, tool, contact)
	for si in skins.size():
		(skins[si] as Dictionary)["held"] = fresh[si]


static func _held_key(prog: Dictionary, ch: String, contact: String) -> String:
	return "%s|%s|%s" % [prog.get("id", ""), ch, contact]


## THE MAP OF WHAT STANDS WHERE THE TOOLS GO ([member _tops]): over the things every paint track names - what it paints, its tool's
## own, its pots, water and towel, every paint on the table - the highest surface over each cell, as the table was built. A thing
## an act carries off is mapped where it stands until then; the tool's own place is low.
func _map_tops() -> void:
	_tops = PackedFloat32Array()
	var tis: Array = []
	for a in work.acts:
		for tr in (a as Dictionary)["tracks"]:
			var t: Dictionary = tr
			if String(t["law"]) != "paint" or not t.has("_ch"):
				continue
			for ti in touches(t):
				if not tis.has(ti):
					tis.append(ti)
			var wi := int(t.get("_wi", -1))
			if wi >= 0 and not tis.has(int((work.works[wi] as Dictionary)["thing"])):
				tis.append(int((work.works[wi] as Dictionary)["thing"]))
	if tis.is_empty():
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for ti in tis:
		var box: AABB = work._world_rest_thing(int(ti)) * ((work.things[int(ti)] as Dictionary)["box"] as AABB)
		lo = lo.min(Vector2(box.position.x, box.position.z))
		hi = hi.max(Vector2(box.end.x, box.end.z))
	lo -= Vector2.ONE * TOPS_MARGIN
	hi += Vector2.ONE * TOPS_MARGIN
	var n := Vector2i(ceili((hi.x - lo.x) / TOPS_CELL), ceili((hi.y - lo.y) / TOPS_CELL))
	# ...every solid as it was built: the things' own and their parts'
	var meshes: Array = []
	for tj in work.things.size():
		var tm := work._mesh_of(tj)
		if tm != null:
			meshes.append([tm, Transform3D.IDENTITY, (work.things[tj] as Dictionary)["mesh_box"]])
	for wi in work.works.size():
		var tm: Variant = (work.works[wi] as Dictionary).get("mesh")
		if tm != null:
			meshes.append([tm, Transform3D.IDENTITY, (work.works[wi] as Dictionary)["mesh_box"]])
	var raw := PackedFloat32Array()
	raw.resize(n.x * n.y)
	for k in n.y:
		_breathe()
		for i in n.x:
			var c := Vector3(lo.x + (float(i) + 0.5) * TOPS_CELL, 0.0, lo.y + (float(k) + 0.5) * TOPS_CELL)
			raw[k * n.x + i] = work._top_under([c], -1, 0.0, -1, meshes)
	_tops = raw
	_tops_at = lo
	_tops_n = n


## The highest thing mapped within [param reach] (meters, level) of [param p] ([method _map_tops]), or -INF.
func _top_at(p: Vector3, reach: float) -> float:
	if _tops.is_empty():
		return -INF
	var r := ceili(reach / TOPS_CELL)
	var i0 := floori((p.x - _tops_at.x) / TOPS_CELL)
	var k0 := floori((p.z - _tops_at.y) / TOPS_CELL)
	var top := -INF
	for k in range(maxi(k0 - r, 0), mini(k0 + r, _tops_n.y - 1) + 1):
		for i in range(maxi(i0 - r, 0), mini(i0 + r, _tops_n.x - 1) + 1):
			top = maxf(top, _tops[k * _tops_n.x + i])
	return top


## How far round its tip tool [param tool] ([method tool_of]) is as wide (meters, level).
static func _reach_of(tool: Dictionary) -> float:
	return float(tool.get("mm", 6.0)) * 0.0005 + TOPS_BESIDE


## HOW HIGH A WAY FROM [param pa] TO [param pb] MUST LIFT (meters, at its highest; [param seed] its hand's) for a tool [param reach]
## wide round its tip ([method _reach_of]) to pass [constant TableWork.CLEAR_GAP] over what stands under it, looked at through its
## middle as a carry's is ([method TableWork._clearance]) - none for a way shorter than [constant TableWork.CLEAR_FROM], or nothing in it.
func _lift_over(pa: Vector3, pb: Vector3, seed: int, reach: float) -> float:
	if _tops.is_empty() or pa.distance_to(pb) < TableWork.CLEAR_FROM:
		return 0.0
	var need := 0.0
	for k in TableWork.CLEAR_SAMPLES:
		var u := lerpf(TableWork.CLEAR_SPAN.x, TableWork.CLEAR_SPAN.y, float(k) / float(TableWork.CLEAR_SAMPLES - 1))
		var shape := Hands.lift_at(u)
		if shape < TableWork.CLEAR_SHAPE:
			continue
		var p := Hands.carried(pa, pb, Vector3.ZERO, Vector3.ZERO, 0.0, u, seed)
		var top := _top_at(p, reach)
		if top > -INF:
			need = maxf(need, (top + TableWork.CLEAR_GAP - p.y) / shape)
	return minf(need, TableWork.CLEAR_MOST)


## THE THINGS PAINT TRACK [param tr]'s TOOL GOES INTO, as it is meant to: what it paints, and the pots, the water and the towel it
## goes to (one loaded with no `from` goes to whichever paint is nearest its color: every paint on the table) - pressed onto,
## never passing through ([method TableWork._pressed_by], [method TablePhysics._painted_by]). Its `press` alone had been: the
## brushes dipped into the palette were told they passed through it, and held back on the water cup (joker-motivation 856886).
func touches(tr: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	var names := [String(tr.get("press", ""))]
	for k in ["from", "rinse", "dry"]:
		names.append(String(tr.get(k, "")).get_slice("/", 0).get_slice(".", 0))
	for nm in names:
		var ti := work._thing_named(String(nm)) if not String(nm).is_empty() else -1
		if ti >= 0 and not out.has(ti):
			out.append(ti)
	if String(tr.get("from", "")).is_empty():
		for cr in _creams:
			var ti := int((cr as Dictionary).get("ti", -1))
			if ti >= 0 and not out.has(ti):
				out.append(ti)
	return out


static func _in_reading_order(acts: Array) -> Array:
	var rank := func(b: String) -> int: return 0 if b == "intro" else (100000 if b == "close" else int(b))
	var order: Array = []
	for i in acts.size():
		order.append([rank.call(String((acts[i] as Dictionary)["beat"])), i])
	order.sort()
	return order.map(func(o: Array) -> Dictionary: return acts[int(o[1])])


## Element [param id] of skin [param si]'s design, or empty.
func element(si: int, id: String) -> Dictionary:
	for e in ((skins[si] as Dictionary)["design"] as Dictionary).get("elements", []):
		if String((e as Dictionary)["id"]).to_lower() == id.strip_edges().to_lower():
			return e
	return {}


## WHAT A PAINT TRACK [param tr] NEEDS ON THE TABLE ([method TableWork._resolve]): the skin it paints (`_skin`) and the
## elements it names there - "" when found, else why not.
func resolve(tr: Dictionary) -> String:
	var on := String(tr.get("on", ""))
	var thing := on.get_slice("/", 0)
	var part := on.get_slice("/", 1) if on.contains("/") else ""
	var si := skin_named(thing, part)
	if si < 0:
		var have := PackedStringArray()
		for s in skins:
			have.append(String((s as Dictionary)["name"]) + ("/" + String((s as Dictionary)["part"]) if not String((s as Dictionary)["part"]).is_empty() else ""))
		return "nothing called \"%s\" has a surface to paint (%s)" % [on, ", ".join(have) if not have.is_empty() else "no part on this table has a `skin`"]
	tr["_skin"] = si
	var design: Dictionary = (skins[si] as Dictionary)["design"]
	# A SURFACE WITH NO DESIGN HAS NOTHING TO PAINT, and the act is told so - it had been taken, painted nothing and pressed its
	# tool into the bare surface, and the puppeteer reading "it paints:  - 3 s" could only guess why (joker-motivation 856886)
	if (design.get("elements", []) as Array).is_empty():
		tr["paint"] = []
		return "\"%s\" has no design yet, so there is nothing on it to paint (its design is made before the acts, in `skin.json`)" % on
	var kept: Array = []
	var missing := PackedStringArray()
	for id in tr.get("paint", []):
		if element(si, String(id)).is_empty():
			missing.append(String(id))
		else:
			kept.append(String(id))
	tr["paint"] = kept
	if not missing.is_empty():
		work.notes.append("paint on \"%s\": no element called %s in its design" % [on, ", ".join(Array(missing).map(func(m: String) -> String: return "\"%s\"" % m))])
	return "" if not kept.is_empty() else "it names no element of \"%s\"'s design (%s)" % [on, ", ".join(_ids(si))]


func _ids(si: int) -> PackedStringArray:
	var out := PackedStringArray()
	for e in ((skins[si] as Dictionary)["design"] as Dictionary).get("elements", []):
		out.append(String((e as Dictionary)["id"]))
	return out


## WHAT A TOOL IS, found once for channel [param ch]: its tip and grip (its node's space, meters - its own points `tip` and
## `grip`, else found), what kind of tool it is ("brush" for a tuft, "sponge", or "tool"), how wide it works (millimeters),
## its tufts' and sponges' materials - and its own surface (`points`, its node's space) and THE WAYS IT IS HELD (`contacts`: each
## a tip, a grip it points along, how far it is pressed in where it is pressed hardest - `give` - how far its hairs reach, `bend`,
## and how far its tip is from its middle, `reach`): a brush and a pad by their tip, a sponge by its face and by its corner.
func tool_of(ch: String, tr: Dictionary) -> Dictionary:
	if tools.has(ch):
		return tools[ch]
	var node: Node3D = null
	var pts := {}
	var meshes: Array = []
	if ch.begins_with("w"):
		var wi := int(tr.get("_wi", -1))
		node = (work.works[wi] as Dictionary)["node"]
		pts = ((work.works[wi] as Dictionary)["w"] as Dictionary).get("points", {})
		meshes = node.find_children("*", "MeshInstance3D", true, false)
	else:
		var ti := int(tr.get("_ti", -1))
		node = (work.things[ti] as Dictionary)["node"]
		meshes = (work.things[ti] as Dictionary)["meshes"]
	var tufts: Array = []
	var sponges: Array = []
	var box := AABB()
	var first := true
	var inv := work._world_of(node).affine_inverse()
	var faces := PackedVector3Array()
	for m in meshes:
		var mi := m as MeshInstance3D
		var mat := mi.material_override as ShaderMaterial
		var to_node := inv * work._world_of(mi)
		var b: AABB = to_node * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
		if mi.mesh != null:
			for v in mi.mesh.get_faces():
				faces.append(to_node * v)
		if mat == null:
			continue
		if mat.has_meta("tuft"):
			tufts.append({"mat": mat, "mesh": mi, "tuft": mat.get_meta("tuft")})
		var kd: Variant = mat.get_shader_parameter("kind")
		if kd != null and int(kd) == int((Props.MATERIALS["sponge"] as Dictionary)["code"]):
			sponges.append({"mat": mat, "mesh": mi})
	var out := {"node": node, "kind": "tool", "mm": 6.0, "tufts": tufts, "sponges": sponges, "box": box, "len": 0.0}
	if not tufts.is_empty():
		var tf: Dictionary = (tufts[0] as Dictionary)["tuft"]
		out["kind"] = "brush"
		out["mm"] = float(tf["mm"])
		out["len"] = float(tf["len"])
		# its tip the tuft's, its grip back along the handle
		var to_node := inv * work._world_of((tufts[0] as Dictionary)["mesh"])
		var root: Vector3 = to_node * (tf["root"] as Vector3)
		var axis: Vector3 = (to_node.basis * (tf["axis"] as Vector3)).normalized()
		out["tip"] = root + axis * float(tf["len"])
		out["grip"] = root - axis * maxf(box.size.length() * 0.6, 0.05)
	elif not sponges.is_empty():
		out["kind"] = "sponge"
		var dims := [box.size.x, box.size.y, box.size.z]
		dims.sort()
		out["mm"] = sqrt(float(dims[1]) * float(dims[2])) * 1000.0 * 0.7
		out["tip"] = Vector3(box.get_center().x, box.position.y, box.get_center().z)
		out["grip"] = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	else:
		var dims := [box.size.x, box.size.y, box.size.z]
		var sorted := dims.duplicate()
		sorted.sort()
		var c := box.get_center()
		out["mm"] = clampf(float(dims.min()) * 1000.0, 3.0, 40.0)
		# A PAD (a puff, a pad of cotton, a stamp): pressed with its face, as wide as that face - it is far thinner one way than the others
		if float(sorted[0]) < float(sorted[1]) * 0.5 and float(sorted[1]) > float(sorted[2]) * 0.5:
			var thin := dims.find(sorted[0])
			var axis := Vector3.ZERO
			axis[thin] = box.size[thin] * 0.5
			out["mm"] = clampf(sqrt(float(sorted[1]) * float(sorted[2])) * 1000.0 * 0.7, 3.0, 60.0)
			out["tip"] = c - axis
			out["grip"] = c + axis
			out["flat"] = true
		elif box.size.y >= box.size.x and box.size.y >= box.size.z:
			out["tip"] = Vector3(c.x, box.position.y, c.z)
			out["grip"] = Vector3(c.x, box.end.y, c.z)
		elif box.size.x >= box.size.z:
			out["tip"] = Vector3(box.position.x, c.y, c.z)
			out["grip"] = Vector3(box.end.x, c.y, c.z)
		else:
			out["tip"] = Vector3(c.x, c.y, box.end.z)
			out["grip"] = Vector3(c.x, c.y, box.position.z)
	for k in pts:
		if String(k).to_lower() == "tip":
			out["tip"] = pts[k]
		elif String(k).to_lower() == "grip":
			out["grip"] = pts[k]
	if tr.has("size"):
		out["mm"] = float(tr["size"])
	# ...AND HOW IT IS HELD, its own surface clear of what it works on
	var c := box.get_center()
	var tm: TriangleMesh = TableWork._ray_mesh(faces) if not faces.is_empty() else null
	out["x0"] = work._rest.get(ch, work._world_of(node))
	out["center"] = c
	out["points"] = _surface_points(tm, box)
	var kind := String(out["kind"])
	var held := {"tip": out["tip"], "grip": out["grip"], "give": GIVE if kind == "sponge" else (PRESS_INTO if kind == "brush" else 0.0),
		"bend": float(out["len"]) if kind == "brush" else 0.001}
	out["ch"] = ch
	out["contact"] = "face" if kind == "sponge" or bool(out.get("flat", false)) else "tip"
	out["contacts"] = {String(out["contact"]): held}
	# A SPONGE'S CORNER: the point of its surface toward a corner of its box, held through its middle
	if kind == "sponge":
		var corner := box.position
		var hit := TableWork._ray(tm, corner + (corner - c).normalized() * 0.01, (c - corner).normalized()) if tm != null else {}
		(out["contacts"] as Dictionary)["corner"] = {"tip": hit["position"] if not hit.is_empty() else corner, "grip": c, "give": GIVE, "bend": 0.001}
		# ...AND THAT CORNER HELD ALONG ITS LENGTH, toward the middle of its far end: how it is dipped into its paint - its long side
		# steep and its end's corner down, as a hand dips a wedge. Through its middle, balanced on the corner, a box is as wide as it can
		# be just over it, and a pot's rim kept all but the corner out of the cream
		var long := 0 if box.size.x >= box.size.y and box.size.x >= box.size.z else (1 if box.size.y >= box.size.z else 2)
		var far := c
		far[long] = box.end[long]
		(out["contacts"] as Dictionary)["end"] = {"tip": hit["position"] if not hit.is_empty() else corner, "grip": far, "give": GIVE, "bend": 0.001}
	for nm in out["contacts"]:
		var hd: Dictionary = out["contacts"][nm]
		hd["reach"] = maxf(((hd["tip"] as Vector3) - c).dot(((hd["tip"] as Vector3) - (hd["grip"] as Vector3)).normalized()), 0.002)
	tools[ch] = out
	return out


## WHERE A TOOL'S OWN SURFACE IS (its node's space): rays straight in from across each face of its box [param box], every
## [constant POINTS_EVERY], where each meets [param tm] - a box's corners and its faces to their edges alike, which its corners alone are
## not (and rays aimed at its middle met a face's edges from the side).
static func _surface_points(tm: TriangleMesh, box: AABB) -> PackedVector3Array:
	var out := PackedVector3Array()
	if tm == null:
		return out
	var b := box.grow(0.002)
	for ax in 3:
		var u := (ax + 1) % 3
		var v := (ax + 2) % 3
		var nu := clampi(ceili(box.size[u] / POINTS_EVERY) + 1, 2, 12)
		var nv := clampi(ceili(box.size[v] / POINTS_EVERY) + 1, 2, 12)
		for side in 2:
			var into := Vector3.ZERO
			into[ax] = 1.0 if side == 0 else -1.0
			for i in nu:
				for j in nv:
					var q := b.position
					q[ax] = b.position[ax] if side == 0 else b.end[ax]
					q[u] = lerpf(box.position[u], box.end[u], float(i) / float(nu - 1))
					q[v] = lerpf(box.position[v], box.end[v], float(j) / float(nv - 1))
					var hit := TableWork._ray(tm, q, into)
					if not hit.is_empty():
						out.append(hit["position"])
	return out


## The way tool [param tool] is held named [param name] ([method tool_of]'s `contacts`), or its own way.
static func _contact(tool: Dictionary, name: String) -> Dictionary:
	var cs: Dictionary = tool.get("contacts", {})
	if cs.has(name):
		return cs[name]
	if cs.has(String(tool.get("contact", ""))):
		return cs[String(tool["contact"])]
	return {"tip": tool.get("tip", Vector3.ZERO), "grip": tool.get("grip", Vector3.UP), "give": 0.0, "bend": 0.0, "reach": 0.01}


## HOW TOOL [param tool] IS HELD for what [param manner] lays, or for trip [param trip] (load, rinse, dry, pick): a sponge flat for
## the manners that spread and onto a towel, by its corner for every other ([constant Skins.FLAT_MANNERS]), and into its paint by its
## end's corner, along its length ([method tool_of]'s `end`).
static func _contact_for(tool: Dictionary, manner: String, trip := "") -> String:
	if String(tool.get("kind", "")) != "sponge":
		return String(tool.get("contact", "tip"))
	if not trip.is_empty():
		return "face" if trip == "dry" else "end"
	return "face" if manner in Skins.FLAT_MANNERS else "corner"


## The way a hold [param h] holds its tool ("" its own).
static func _contact_of(h: Array) -> String:
	return String(h[5]) if h.size() > 5 else ""


# --- the skin's surface ------------------------------------------------------------------------------

## A SKIN'S SURFACE seen from its front, found once: a grid every [constant SURFACE_STEP] millimeters of where the surface
## is and which way it faces, in its holder's space - from rays straight in along the part's front.
func _surface_of(sd: Dictionary) -> Dictionary:
	var faces := PackedVector3Array()
	for m in sd["meshes"]:
		var mi := m as MeshInstance3D
		if mi.mesh != null:
			faces.append_array(mi.mesh.get_faces())
	var frame: Vector2 = sd["frame"]
	var nx := int(ceil(frame.x / SURFACE_STEP)) + 1
	var ny := int(ceil(frame.y / SURFACE_STEP)) + 1
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var hit := PackedByteArray()
	pos.resize(nx * ny)
	nrm.resize(nx * ny)
	hit.resize(nx * ny)
	var xf: Transform3D = sd["xform"]
	var box: AABB = sd["box"]
	var front := (xf.basis * Vector3.BACK).normalized()
	if faces.is_empty():
		return {"nx": nx, "ny": ny, "pos": pos, "nrm": nrm, "hit": hit, "front": front}
	var tm := TableWork._ray_mesh(faces)
	for j in ny:
		_breathe()
		for i in nx:
			var x := box.position.x + minf(float(i) * SURFACE_STEP * 0.001, box.size.x)
			var y := box.end.y - minf(float(j) * SURFACE_STEP * 0.001, box.size.y)
			var from := xf * Vector3(x, y, box.end.z + 0.02)
			var got := TableWork._ray(tm, from, -front)
			var k := j * nx + i
			if got.is_empty():
				# none here: the plane the front stands in, facing out
				pos[k] = xf * Vector3(x, y, box.position.z + box.size.z * 0.5)
				nrm[k] = front
				continue
			pos[k] = got["position"]
			var n: Vector3 = (got["normal"] as Vector3).normalized()
			nrm[k] = n if n.dot(front) >= 0.0 else -n
			hit[k] = 1
	# ...ITS EDGE, where it falls away sideways beside nothing, is past it too: a tool sent to a mask's rim had gone to the foot of the
	# shell's outer edge, under the face beside it, and a sponge's corner could only stand off it (feedback 0016)
	# ...and so is a lip at the foot of it (a shell's back, beside nothing, far under the face beside it)
	var edge := PackedInt32Array()
	for k in hit.size():
		if hit[k] == 0:
			continue
		var i0 := k % nx
		var j0 := k / nx
		var bare := false
		var over := -INF
		for dj in range(-2, 3):
			for di in range(-2, 3):
				var x := i0 + di
				var y := j0 + dj
				if x < 0 or y < 0 or x >= nx or y >= ny:
					continue
				if hit[y * nx + x] == 0:
					bare = true
				else:
					over = maxf(over, pos[y * nx + x].dot(front))
		if bare and (nrm[k].dot(front) < EDGE_FACING or over - pos[k].dot(front) > EDGE_CLIFF):
			edge.append(k)
	for k in edge:
		hit[k] = 0
	# OFF THE SURFACE (past a mask's rim), the nearest place on it: a tool sent there goes to the edge, never into the air
	var queue := PackedInt32Array()
	var near := PackedByteArray(hit)
	for k in hit.size():
		if hit[k] == 1:
			queue.append(k)
	var head := 0
	while head < queue.size():
		var k := queue[head]
		head += 1
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var x: int = k % nx + d[0]
			var y: int = k / nx + d[1]
			if x < 0 or y < 0 or x >= nx or y >= ny:
				continue
			var nk := y * nx + x
			if near[nk] == 0:
				near[nk] = 1
				pos[nk] = pos[k]
				nrm[nk] = nrm[k]
				queue.append(nk)
	return {"nx": nx, "ny": ny, "pos": pos, "nrm": nrm, "hit": hit, "front": front, "mesh": tm}


## WHERE (x, y) millimeters ON SKIN [param si] IS, in its holder's space: `[point, normal]`.
func at_mm(si: int, xy: Vector2) -> Array:
	var sf: Dictionary = (skins[si] as Dictionary)["surface"]
	var nx := int(sf["nx"])
	var ny := int(sf["ny"])
	var fx := clampf(xy.x / SURFACE_STEP, 0.0, float(nx - 1))
	var fy := clampf(xy.y / SURFACE_STEP, 0.0, float(ny - 1))
	var i := mini(int(fx), nx - 2)
	var j := mini(int(fy), ny - 2)
	var a := fx - float(i)
	var b := fy - float(j)
	var P: PackedVector3Array = sf["pos"]
	var N: PackedVector3Array = sf["nrm"]
	var k := j * nx + i
	var p := P[k].lerp(P[k + 1], a).lerp(P[k + nx].lerp(P[k + nx + 1], a), b)
	var n := N[k].lerp(N[k + 1], a).lerp(N[k + nx].lerp(N[k + nx + 1], a), b)
	# ...ON THE SURFACE ITSELF wherever there is one under it: the grid's corners only bound it, a face curves between them, and BY ITS
	# EDGE (a corner of the cell off it) their blend hung in front of a surface curving away - where its paint is laid all the same,
	# projected straight in along its front, and every tool painting along a mask's rim hovered over it (feedback 0019, 0021: "you can
	# tell by the shadow it casts, it's floating above the mask" - the liner 11 mm off, the flat brush 22). There it faces as it does.
	var H: PackedByteArray = sf["hit"]
	if sf.get("mesh") != null and (H[k] == 1 or H[k + 1] == 1 or H[k + nx] == 1 or H[k + nx + 1] == 1):
		var sd: Dictionary = skins[si]
		var box: AABB = sd["box"]
		var front: Vector3 = sf["front"]
		var from: Vector3 = (sd["xform"] as Transform3D) * Vector3(box.position.x + xy.x * 0.001, box.end.y - xy.y * 0.001, box.end.z + 0.02)
		var got := TableWork._ray(sf["mesh"], from, -front)
		if not got.is_empty():
			p = got["position"]
			if not (H[k] == 1 and H[k + 1] == 1 and H[k + nx] == 1 and H[k + nx + 1] == 1):
				var hn: Vector3 = got["normal"]
				n = hn if hn.dot(front) > 0.0 else -hn
	return [p, n.normalized() if n.length() > 1e-6 else sf["front"]]


## Which way skin [param si]'s surface faces at (x, y) millimeters, in its holder's space ([method at_mm]'s, with no ray).
func _normal_mm(si: int, xy: Vector2) -> Vector3:
	var sf: Dictionary = (skins[si] as Dictionary)["surface"]
	var nx := int(sf["nx"])
	var ny := int(sf["ny"])
	var fx := clampf(xy.x / SURFACE_STEP, 0.0, float(nx - 1))
	var fy := clampf(xy.y / SURFACE_STEP, 0.0, float(ny - 1))
	var i := mini(int(fx), nx - 2)
	var j := mini(int(fy), ny - 2)
	var N: PackedVector3Array = sf["nrm"]
	var k := j * nx + i
	var n := N[k].lerp(N[k + 1], fx - float(i)).lerp(N[k + nx].lerp(N[k + nx + 1], fx - float(i)), fy - float(j))
	return n.normalized() if n.length() > 1e-6 else (sf["front"] as Vector3)


## SKIN [param si]'s holder where it is at show time [param T], in the table's space.
func holder_world(si: int, T: float) -> Transform3D:
	var sd: Dictionary = skins[si]
	var ti := int(sd["ti"])
	if not sd.has("_rest"):
		sd["_rest"] = work._world_of(sd["holder"])
	return work._thing_world(ti, T) * work._world_rest_thing(ti).affine_inverse() * (sd["_rest"] as Transform3D)


# --- the canvas ---------------------------------------------------------------------------------------

## SKIN [param si]'s CANVAS: two viewports of its own - its color, and its finish - an element a sprite in each, every element
## an act lays; and the part's material told where they are.
func _canvas(si: int) -> void:
	var sd: Dictionary = skins[si]
	for vp in sd.get("canvas", []):
		if is_instance_valid(vp):
			(vp as Node).queue_free()
	for st in sd.get("stone_nodes", []):
		if is_instance_valid(st):
			(st as Node).queue_free()
	sd["canvas"] = []
	sd["items"] = {}
	sd["stone_nodes"] = []
	sd["stones"] = []
	var design: Dictionary = sd["design"]
	if (design.get("elements", []) as Array).is_empty():
		_skin_material(sd, null, null)
		return
	var frame: Vector2 = sd["frame"]
	var size := Vector2i(maxi(int(ceil(frame.x * CANVAS_PX)), 8), maxi(int(ceil(frame.y * CANVAS_PX)), 8))
	var vps: Array = []
	for k in 2:
		var vp := SubViewport.new()
		vp.name = "Skin %d %s" % [si, "color" if k == 0 else "finish"]
		vp.size = size
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
		if work._root != null:
			work._root.add_child(vp)
		vps.append(vp)
	sd["canvas"] = vps
	var outline := String(sd.get("outline", ""))
	for e in design["elements"]:
		var ed: Dictionary = e
		var lay: Dictionary = _layers.get("%d|%s" % [si, String(ed["id"]).to_lower()], {})
		if lay.is_empty():
			continue
		if String(ed["kind"]) == "stones":
			_stones_of(si, ed)
			continue
		var made := _made_for(si, ed, String(lay["manner"]), float(lay["mm"]))
		if made.is_empty() or made.get("cover") == null:
			continue
		var fin: Dictionary = Skins.FINISHES[String(ed["finish"])]
		var lods := Vector2(_lod(float(ed["soft"])), _lod(maxf(float(ed["soft"]), Skins.BLEND_SOFT)))
		var item := {"el": ed, "made": made, "sprites": [], "mats": []}
		for k in 2:
			var sp := Sprite2D.new()
			sp.centered = false
			sp.texture = made["cover_tex"]
			sp.position = (made["rect"] as Rect2).position * CANVAS_PX
			var mat := ShaderMaterial.new()
			mat.shader = _CANVAS
			mat.set_shader_parameter("cover", made["cover_tex"])
			mat.set_shader_parameter("when_map", made["when_tex"])
			mat.set_shader_parameter("paint", Color.html(String(ed["paint"])))
			mat.set_shader_parameter("finish", Color(float(fin["rough"]), float(fin["metal"]), float(fin["glitter"]), 1.0))
			mat.set_shader_parameter("finish_pass", k == 1)
			mat.set_shader_parameter("opacity", float(ed["opacity"]))
			mat.set_shader_parameter("pressed", {"stipple": 1, "pat": 2}.get(String(lay["manner"]), 0))
			mat.set_shader_parameter("lods", lods)
			mat.set_shader_parameter("swept", Skins.SWEPT if String(ed["finish"]) == "powder" else 1.0)
			mat.set_shader_parameter("mm", (made["rect"] as Rect2).size)
			# A MIST lays no color: only its sheen, which dries down
			if String(ed["kind"]) == "mist":
				mat.set_shader_parameter("color_alpha", 0.0)
				mat.set_shader_parameter("finish", Color(Skins.DEW, 0.0, 0.0, 1.0))
				mat.set_shader_parameter("dries", Skins.DEW_DRIES)
				mat.set_shader_parameter("dried", Skins.DEW_LEFT)
			mat.set_shader_parameter("span", Vector2(1e9, 1e9 + 1.0))
			mat.set_shader_parameter("blend_span", Vector2(1e9, 1e9 + 1.0))
			mat.set_shader_parameter("sweep_span", Vector2(1e9, 1e9 + 1.0))
			sp.material = mat
			(vps[k] as SubViewport).add_child(sp)
			(item["sprites"] as Array).append(sp)
			(item["mats"] as Array).append(mat)
		(sd["items"] as Dictionary)[String(ed["id"]).to_lower()] = item
	_skin_material(sd, (vps[0] as SubViewport).get_texture(), (vps[1] as SubViewport).get_texture())


## The mip level that softens an edge [param mm] millimeters.
static func _lod(mm: float) -> float:
	return log(maxf(mm * CANVAS_PX, 1.0)) / log(2.0)


## WHAT ELEMENT [param ed] OF SKIN [param si] IS, laid in [param manner] by a tool [param mm] across: its program, its pictures
## and its reveal map - made once, kept.
func _made_for(si: int, ed: Dictionary, manner: String, mm: float) -> Dictionary:
	var sd: Dictionary = skins[si]
	var key := "%s|%s|%s|%.2f|%s" % [sd["name"], hash(ed), manner, mm, sd["frame"]]
	if _made.has(key):
		return _made[key]
	var frame: Vector2 = sd["frame"]
	var outline := String(sd.get("outline", ""))
	var margin := maxf(float(ed["soft"]), Skins.BLEND_SOFT) * 1.5
	var rect := Skins.rect_of(ed, frame, margin)
	var cov1 := Skins.cover(ed, rect, Skins.WHEN_PX, outline, frame)
	var prog := Skins.program(ed, manner, mm, cov1, rect)
	# (by which its holds are kept, [method _held_keys])
	prog["id"] = key
	var out := {"program": prog, "rect": rect}
	if String(ed["kind"]) != "stones":
		var cov := Skins.cover(ed, rect, CANVAS_PX, outline, frame)
		if cov != null:
			cov.generate_mipmaps()
			out["cover"] = cov
			out["cover_tex"] = ImageTexture.create_from_image(cov)
			var wm := Skins.when_map(prog, rect)
			out["when"] = wm
			out["when_tex"] = ImageTexture.create_from_image(wm)
	if _made.size() > 400:
		_made.clear()
	_made[key] = out
	return out


## ITS STONES, things of their own on the skin's holder: each a small faceted crystal, seen once a tool has picked it up.
func _stones_of(si: int, ed: Dictionary) -> void:
	var sd: Dictionary = skins[si]
	var lay: Dictionary = _layers.get("%d|%s" % [si, String(ed["id"]).to_lower()], {})
	var made := _made_for(si, ed, "place", float(lay.get("mm", 4.0)))
	var holder: Node3D = sd["holder"]
	var m := Props.sanitize_material({"kind": "crystal", "color": String(ed["paint"]), "clarity": 0.55, "polish": 0.95, "play": "fire"}, String(ed["paint"]))
	for k in (ed["stones"] as Array).size():
		var c: Array = ed["stones"][k]
		var r := float(c[2]) * 0.001
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sd["name"], ed["id"], k])
		var g := Props._ball(Vector3(r, r * 0.7, r) * 200.0, 0.0, true, rng)
		var mi := MeshInstance3D.new()
		mi.mesh = g.placed([Transform3D.IDENTITY]).mesh()
		mi.material_override = Props.material(m, {}, r * 600.0, r * 140.0, hash([ed["id"], k]), true, true)
		mi.visible = false
		holder.add_child(mi)
		(sd["stone_nodes"] as Array).append(mi)
		var on := at_mm(si, Vector2(float(c[0]), float(c[1])))
		var n: Vector3 = on[1]
		var b := Basis(Quaternion(Vector3.UP, n)) if n.dot(Vector3.UP) > -0.999 else Basis.IDENTITY
		(sd["stones"] as Array).append({"node": mi, "el": String(ed["id"]).to_lower(), "k": k, "seat": Transform3D(b, (on[0] as Vector3) + n * r * STONE_OUT),
			"t": Vector2(INF, INF), "tool": ""})
	sd["stones_made"] = made


## THE PART'S OWN MATERIAL told of its skin: where its front is, and the two pictures composed for it.
func _skin_material(sd: Dictionary, color: Texture2D, finish: Texture2D) -> void:
	var xf: Transform3D = sd["xform"]
	var box: AABB = sd["box"]
	var M := xf.affine_inverse()
	var row := func(r: int) -> Vector4:
		return Vector4(M.basis.x[r], M.basis.y[r], M.basis.z[r], M.origin[r])
	var rx: Vector4 = row.call(0)
	var ry: Vector4 = row.call(1)
	var u := Vector4(rx.x, rx.y, rx.z, rx.w - box.position.x) / maxf(box.size.x, 1e-6)
	var v := Vector4(-ry.x, -ry.y, -ry.z, box.end.y - ry.w) / maxf(box.size.y, 1e-6)
	for m in sd["meshes"]:
		var mat := (m as MeshInstance3D).material_override as ShaderMaterial
		if mat == null:
			continue
		mat.set_shader_parameter("skinned", color != null)
		mat.set_shader_parameter("skin_u", u)
		mat.set_shader_parameter("skin_v", v)
		mat.set_shader_parameter("skin_side", (xf.basis * Vector3.BACK).normalized())
		if color != null:
			mat.set_shader_parameter("skin_color", color)
			mat.set_shader_parameter("skin_finish", finish)


# --- an act that paints -------------------------------------------------------------------------------

## THE PLAN OF PAINT TRACK [param tr], [param d] seconds long: its phases in seconds from its start - `{phases: [{kind (fetch,
## load, rinse, move, el, rest, back), a, b, ...}], natural}`. An element's phase carries its program and how much it is
## slowed (`k`); a load the paint it takes up and from where.
func plan_of(tr: Dictionary, d: float) -> Dictionary:
	var si := int(tr.get("_skin", -1))
	var ch := String(tr.get("_ch", ""))
	var tool := tool_of(ch, tr)
	var parts: Array = []
	var loaded := ""
	for id in tr.get("paint", []):
		var ed := element(si, String(id))
		if ed.is_empty():
			continue
		var lay: Dictionary = _layers.get("%d|%s" % [si, String(id).to_lower()], {})
		var mine: bool = not lay.is_empty() and lay.get("act") == tr.get("_act")
		var manner := String(lay.get("manner", "")) if mine else "blend"
		if String(ed["kind"]) == "stones" and not mine:
			continue
		# (the program its paint is shown by, [member _layers]'s - or its blend's)
		var made := _made_for(si, ed, manner, float(lay["mm"])) if mine else _made_for(si, ed, "blend", _width(tool, tr, "blend"))
		var prog: Dictionary = made["program"]
		var role := "paint" if mine else ("sweep" if String(ed["finish"]) == "powder" else "blend")
		var pre: Array = []
		if role == "paint" and not String(ed["kind"]) in ["stones", "smear", "mist"] and String(ed["paint"]) != loaded:
			if not loaded.is_empty() and tr.has("rinse"):
				pre.append({"kind": "rinse", "len": RINSE, "out": loaded})
				if tr.has("dry"):
					pre.append({"kind": "dry", "len": DRY})
			pre.append({"kind": "load", "len": LOAD, "paint": String(ed["paint"]), "from": String(tr.get("from", ""))})
			loaded = String(ed["paint"])
		parts.append({"el": String(ed["id"]).to_lower(), "pre": pre, "prog": prog, "role": role, "finish": String(ed["finish"])})
	# ...AND CLEANED BEFORE IT GOES BACK, where there is water for it
	var clean: Array = []
	if tr.has("rinse") and not loaded.is_empty():
		clean.append({"kind": "rinse", "len": RINSE, "out": loaded})
		if tr.has("dry"):
			clean.append({"kind": "dry", "len": DRY})
	var natural := FETCH + RETURN
	for q in clean:
		natural += float((q as Dictionary)["len"])
	var work_len := 0.0
	for p in parts:
		for q in (p as Dictionary)["pre"]:
			natural += float((q as Dictionary)["len"])
		natural += MOVE + float(((p as Dictionary)["prog"] as Dictionary)["natural"])
		work_len += float(((p as Dictionary)["prog"] as Dictionary)["natural"])
	var fixed := natural - work_len
	# SLOWED, THEN RESTED, as long as the act is; HURRIED, if it must be
	var k := 1.0
	var rest := 0.0
	var after := 0.0
	if d > natural and work_len > 0.0:
		k = minf((d - fixed) / work_len, SLOW_MOST)
		var left := d - fixed - work_len * k
		rest = minf(left / float(maxi(parts.size(), 1)), REST_MOST)
		after = maxf(left - rest * float(parts.size()), 0.0)
	elif d < natural and work_len > 0.0:
		k = maxf((d - fixed * minf(d / natural, 1.0)) / work_len, QUICK_MOST)
	var squeeze := minf(d / maxf(fixed + work_len * k + rest * float(parts.size()), 1e-3), 1.0)
	var phases: Array = []
	var clock := [0.0]            # (a lambda's own copy of a number would never move on)
	var add := func(kind: String, len: float, extra: Dictionary) -> void:
		var ph := extra.duplicate()
		ph["kind"] = kind
		ph["a"] = float(clock[0])
		ph["b"] = float(clock[0]) + len * squeeze
		phases.append(ph)
		clock[0] = float(ph["b"])
	add.call("fetch", FETCH, {})
	for i in parts.size():
		var p: Dictionary = parts[i]
		for q in p["pre"]:
			add.call(String((q as Dictionary)["kind"]), float((q as Dictionary)["len"]), q as Dictionary)
		add.call("move", MOVE, {"el": p["el"], "prog": p["prog"]})
		add.call("el", float((p["prog"] as Dictionary)["natural"]) * k, {"el": p["el"], "prog": p["prog"], "role": p["role"], "finish": p["finish"]})
		add.call("rest", rest, {"el": p["el"], "prog": p["prog"]})
	for q in clean:
		add.call(String((q as Dictionary)["kind"]), float((q as Dictionary)["len"]), q as Dictionary)
	add.call("back", RETURN, {})
	if after > 0.0:
		add.call("still", after, {})
	return {"phases": phases, "natural": natural, "d": d, "si": si}


## THE WATER A BRUSH IS RINSED IN, at [param tau] into paint track [param tr]'s act of [param d] seconds, from [param from] (as it was
## as the act began): a little toward the color each rinse takes out of the brush, as it is swished there - a pure function of time.
func cloud_at(tr: Dictionary, from: Color, tau: float, d: float) -> Color:
	var plan := plan_of(tr, d)
	var c := from
	for p in plan["phases"]:
		var pd: Dictionary = p
		if String(pd["kind"]) != "rinse" or String(pd.get("out", "")).is_empty() or tau <= float(pd["a"]):
			continue
		var w := clampf((tau - float(pd["a"])) / maxf(float(pd["b"]) - float(pd["a"]), 1e-4), 0.0, 1.0)
		var into := Hands.smooth(clampf((w - 0.4) / 0.6, 0.0, 1.0))
		c = c.lerp(Color.html(String(pd["out"])), CLOUD * into)
	return c


## The paint act [param act]'s length at a hand's pace: its longest paint track's.
func _natural_of(act: Dictionary, tr: Dictionary) -> float:
	tr["_act"] = String(act["name"])
	return float(plan_of(tr, 0.0)["natural"])


## WHERE THE TOOL IS at [param tau] seconds into its act (of [param d]): its node in the table's space - fetched from
## [param from], over its work, and back. [param x0]: its node at rest.
func pose(e: Dictionary, tr: Dictionary, tau: float, d: float, T: float, from: Transform3D, x0: Transform3D) -> Transform3D:
	var plan := _plan_entry(e, tr, d)
	var tool := tool_of(String(tr["_ch"]), tr)
	var held: Variant = _held_at(plan, tr, tau, T, from, x0)
	if held is Transform3D:
		return held
	return _node_at(held as Array, tool, x0)


## The plan of entry [param e], made once for its length.
func _plan_entry(e: Dictionary, tr: Dictionary, d: float) -> Dictionary:
	var got: Variant = e.get("_paint")
	if got is Dictionary and absf(float((got as Dictionary)["d"]) - d) < 1e-4:
		return got
	var plan := plan_of(tr, d)
	e["_paint"] = plan
	return plan


## WHERE THE TIP IS AND WHICH WAY THE TOOL POINTS at [param tau] into [param plan] - a hold, `[tip, axis, pressed (0-1), on the
## surface, how far over a pot it comes in, the way it is held ([method _contact])]` (the table's space) - or, fetched, put back or
## turned in the hand from one way of holding it to another, the node's own place (a Transform3D).
func _held_at(plan: Dictionary, tr: Dictionary, tau: float, T: float, from: Transform3D, x0: Transform3D) -> Variant:
	var phases: Array = plan["phases"]
	if phases.is_empty():
		return from
	var si := int(plan["si"])
	var i := phases.size() - 1
	for k in phases.size():
		if tau <= float((phases[k] as Dictionary)["b"]):
			i = k
			break
	var ph: Dictionary = phases[i]
	var len := maxf(float(ph["b"]) - float(ph["a"]), 1e-4)
	var s := clampf((tau - float(ph["a"])) / len, 0.0, 1.0)
	var tool := tool_of(String(tr["_ch"]), tr)
	var seed := int(tr.get("_hand", 0))
	match String(ph["kind"]):
		"fetch", "back", "still":
			# FROM WHERE IT RESTS to its first place, and back - as a carry goes, the tip arcing, the tool turning on its way
			var a := from
			var b := _node_at(_end_of(plan, tr, T, 0), tool, x0)
			if String(ph["kind"]) != "fetch":
				if String(ph["kind"]) == "still":
					return from
				a = _node_at(_end_of(plan, tr, T, i - 1), tool, x0)
				b = from
			var tip_l: Vector3 = tool["tip"]
			var pa := a * tip_l
			var pb := b * tip_l
			var lin := Hands.timing(s)
			var p := Hands.carried(pa, pb, Vector3.ZERO, Vector3.ZERO, maxf(FETCH_LIFT, _lift_over(pa, pb, seed, _reach_of(tool))), s, seed)
			var rb := Basis(Quaternion(a.basis.orthonormalized()).slerp(Quaternion(b.basis.orthonormalized()), lin))
			var basis := rb.scaled(a.basis.get_scale())
			return Transform3D(basis, p - basis * tip_l)
		"load", "rinse", "dry":
			# TO ITS PAINT, THE WATER OR THE TOWEL, from wherever it last was, and there - it leaves in what comes next
			var pot := _trip_hold(ph, T, tr)
			return _trip(_end_of(plan, tr, T, i - 1), pot, s, seed + i * 7919, String(ph["kind"]), tool)
		"move":
			return _between(_end_of(plan, tr, T, i - 1), _hold_of(_surface_hold(si, ph["prog"], 0.0, T, tr), tool), s, seed, tool)
		"rest":
			var prog: Dictionary = ph["prog"]
			var h := _hold_of(_surface_hold(si, prog, float(prog["natural"]), T, tr), tool)
			h[0] = (h[0] as Vector3) + (Hands.drift(T, seed, 1.0)[0] as Vector3)
			return h
		"el":
			var prog2: Dictionary = ph["prog"]
			return _surface_hold(si, prog2, s * float(prog2["natural"]), T, tr)
	return from


## Where phase [param i] of [param plan] leaves the tool: an element's end over the surface, over the pot, cup or towel a trip went
## to, or - before anything - where the first phase after the fetch begins.
func _end_of(plan: Dictionary, tr: Dictionary, T: float, i: int) -> Array:
	var phases: Array = plan["phases"]
	var tool := _tool_or_none(tr)
	if i <= 0:
		for k in range(1, phases.size()):
			var pd: Dictionary = phases[k]
			if String(pd["kind"]) in TRIPS:
				return _lifted(_trip_hold(pd, T, tr))
			if pd.has("prog"):
				return _hold_of(_surface_hold(int(plan["si"]), pd["prog"], 0.0, T, tr), tool)
		return [Vector3.ZERO, Vector3.UP, 0.0, false]
	var ph: Dictionary = phases[mini(i, phases.size() - 1)]
	if String(ph["kind"]) in TRIPS:
		return _lifted(_trip_hold(ph, T, tr))
	if String(ph["kind"]) == "move":
		return _hold_of(_surface_hold(int(plan["si"]), ph["prog"], 0.0, T, tr), tool)
	if ph.has("prog"):
		return _hold_of(_surface_hold(int(plan["si"]), ph["prog"], float((ph["prog"] as Dictionary)["natural"]), T, tr), tool)
	return _end_of(plan, tr, T, i - 1)


## The node's place for a hold [param h] ([tip, axis], held its way) - turned from where it rests as [method pose] turns it.
func _node_at(h: Array, tool: Dictionary, x0: Transform3D) -> Transform3D:
	var c := _contact(tool, _contact_of(h))
	var tip_l: Vector3 = c["tip"]
	var grip_l: Vector3 = c["grip"]
	var v0 := (x0.basis * (grip_l - tip_l)).normalized()
	var A: Vector3 = (h[1] as Vector3).normalized()
	var r := Basis(Quaternion(v0, A)) if v0.dot(A) > -0.999 else Basis(Vector3.RIGHT, PI)
	return Transform3D(r, (h[0] as Vector3) - r * (x0 * tip_l)) * x0


## [param v] as a hold: a node's place ([method _held_at]) as the tip and axis of tool [param tool]'s own way of holding it.
static func _hold_of(v: Variant, tool: Dictionary) -> Array:
	if v is Array:
		return v
	var x: Transform3D = v
	var c := _contact(tool, "")
	return [x * (c["tip"] as Vector3), (x.basis * ((c["grip"] as Vector3) - (c["tip"] as Vector3))).normalized(), 0.0, false, TRIP_LIFT, ""]


## Paint track [param tr]'s tool, or none (a puff of powder placed with no tool).
func _tool_or_none(tr: Dictionary) -> Dictionary:
	var ch := String(tr.get("_ch", ""))
	return {} if ch.is_empty() else tool_of(ch, tr)


## The way hold [param h] holds tool [param tool], named: its own, or the tool's.
static func _way(tool: Dictionary, h: Array) -> String:
	var n := _contact_of(h)
	return n if not n.is_empty() else String(tool.get("contact", ""))


## The hold over trip [param ph]'s pot, cup or towel.
func _trip_hold(ph: Dictionary, T: float, tr: Dictionary) -> Array:
	return _pot_hold(String(ph["kind"]), String(ph.get("from", "")), String(ph.get("paint", "")), T, tr)


## A hold [param h] lifted clear over where it is (a trip's place, left upward - over its rim).
static func _lifted(h: Array) -> Array:
	var rise := float(h[4]) if h.size() > 4 else TRIP_LIFT
	return [(h[0] as Vector3) + Vector3.UP * rise, h[1], 0.0, false, rise, _contact_of(h)]


## WHERE THE TOOL IS at [param tau] (seconds, a hand's own pace) into program [param prog] on skin [param si]: a hold (the table's
## space), or - turned in the hand, on a trip to its paint or from its face to its corner - its node's place. [param making]: the holds
## being found for it ([method _held_keys]), in place of its skin's.
func _surface_hold(si: int, prog: Dictionary, tau: float, T: float, tr: Dictionary, making: Dictionary = {}) -> Variant:
	var keys: Array = prog["keys"]
	if keys.is_empty():
		return [Vector3.ZERO, Vector3.UP, 0.0, true]
	var tool := _tool_or_none(tr)
	var contact := _contact_for(tool, String(prog.get("manner", ""))) if not tool.is_empty() else ""
	# the key it is past (they are in order of time)
	var lo := 0
	var hi := keys.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if float((keys[mid] as Array)[0]) <= tau:
			lo = mid
		else:
			hi = mid - 1
	var k := lo
	var kb := mini(k + 1, keys.size() - 1)
	var a: Array = keys[k]
	var b: Array = keys[kb]
	var span := float(b[0]) - float(a[0])
	var s := clampf((tau - float(a[0])) / span, 0.0, 1.0) if span > 1e-5 else 1.0
	var at_a := int(a[5])
	var at_b := int(b[5])
	# HOW IT IS HELD AT EACH KEY, clear of the surface ([method _held_keys]; none found, as a hand holds it)
	var kept: Dictionary = making if not making.is_empty() else ((skins[si] as Dictionary).get("held", {}) as Dictionary).get(_held_key(prog, String(tr.get("_ch", "")), contact), {})
	var held: PackedVector4Array = kept.get("held", PackedVector4Array())
	var ways: PackedByteArray = kept.get("ways", PackedByteArray())
	var ha := held[k] if k < held.size() else Vector4.ZERO
	var hb := held[kb] if kb < held.size() else Vector4.ZERO
	var ca := "corner" if k < ways.size() and ways[k] == 1 else contact
	var cb := "corner" if kb < ways.size() and ways[kb] == 1 else contact
	var arcs: PackedFloat32Array = kept.get("arcs", PackedFloat32Array())
	var arc := arcs[k] if k < arcs.size() and kb > k else 0.0
	if at_a == 3 or at_b == 3:
		# AIMED FROM A HAND'S LENGTH OFF (a spray): over what it sprays and up from it, pointed at it
		var xy3 := Vector2(float(a[1]), float(a[2])).lerp(Vector2(float(b[1]), float(b[2])), Hands.smooth(s))
		return _spray_hold(si, xy3, float(a[3]) * 0.001, lerpf(float(a[4]), float(b[4]), s), T)
	if at_a in [1, 2] and at_b in [1, 2]:
		# A TRIP inside the element: to its paint (1) or its stones' dish (2), and back to where it goes on
		var near := _skin_hold(si, Vector2(float(a[1]), float(a[2])), float(a[3]), 0.0, T, tool, ca, ha, ha, 0.0)
		var next := _skin_hold(si, Vector2(float(b[1]), float(b[2])), float(b[3]), 0.0, T, tool, cb, hb, hb, 0.0)
		var pot := _pot_hold("load" if at_a == 1 else "pick", String(tr.get("from", "")), "", T, tr)
		if s < 0.7:
			return _trip(near, pot, s / 0.7, int(tr.get("_hand", 0)) + k * 7919, "load", tool)
		return _between(_lifted(pot), next, (s - 0.7) / 0.3, int(tr.get("_hand", 0)), tool)
	# down and up are eased as a hand eases them; along a stroke it goes steadily
	var e := Hands.smooth(s) if float(a[4]) != float(b[4]) or float(a[3]) != float(b[3]) else s
	var xy := Vector2(float(a[1]), float(a[2])).lerp(Vector2(float(b[1]), float(b[2])), e if float(a[4]) != float(b[4]) else s)
	var lift := lerpf(float(a[3]), float(b[3]), e) + arc * 1000.0 * sin(PI * s)
	var press := lerpf(float(a[4]), float(b[4]), e)
	if ca == cb:
		return _skin_hold(si, xy, lift, press, T, tool, ca, ha, hb, e)
	# ...TURNED IN THE HAND between two keys held two ways (its face, then its corner): from the one to the other where it is, eased
	# off the surface as it turns
	var x0: Transform3D = tool["x0"]
	var na := _node_at(_skin_hold(si, xy, lift, 0.0, T, tool, ca, ha, ha, 0.0), tool, x0)
	var nb := _node_at(_skin_hold(si, xy, lift, 0.0, T, tool, cb, hb, hb, 0.0), tool, x0)
	var w := Hands.smooth(s)
	var turned := Basis(Quaternion(na.basis.orthonormalized()).slerp(Quaternion(nb.basis.orthonormalized()), w)).scaled(na.basis.get_scale())
	return Transform3D(turned, na.origin.lerp(nb.origin, w))


## THE TOOL OVER (x, y) millimeters of skin [param si], lifted [param lift] millimeters, pressed [param press], held [param contact]:
## pointing as it is held clear at the keys either side ([param ha], [param hb] - each its axis in the holder's space and how far it
## must stand off, `e` of the way between), else as a hand holds it there ([method _held_axis]). A brush's hairs are pressed in
## along the surface; a sponge is pushed in along the way it points, and gives back to the surface ([method _tick_tool]).
func _skin_hold(si: int, xy: Vector2, lift: float, press: float, T: float, tool: Dictionary, contact: String, ha := Vector4.ZERO,
		hb := Vector4.ZERO, e := 0.0) -> Array:
	var on := at_mm(si, xy)
	var hw := holder_world(si, T)
	var p: Vector3 = hw * (on[0] as Vector3)
	var n: Vector3 = (hw.basis * (on[1] as Vector3)).normalized()
	var ca := Vector3(ha.x, ha.y, ha.z)
	var cb := Vector3(hb.x, hb.y, hb.z)
	var axis_l: Vector3
	var off := 0.0
	if ca.length_squared() > 0.5:
		var both := cb.length_squared() > 0.5
		axis_l = ca.slerp(cb, e) if both and ca.dot(cb) > -0.99 else ca
		off = lerpf(ha.w, hb.w if both else ha.w, e)
	else:
		axis_l = _held_axis(si, xy, on[1], tool, contact)
	var axis := (hw.basis * axis_l).normalized()
	var give := float(_contact(tool, contact).get("give", 0.0)) * press if not tool.is_empty() else 0.0
	var into := n * give if String(tool.get("kind", "")) != "sponge" else axis * give
	return [p + n * (TOUCH + lift * 0.001) + axis * off - into, axis, press, true, TRIP_LIFT, contact]


## HOW A HAND HOLDS TOOL [param tool] by [param contact] at (x, y) millimeters of skin [param si], whose surface faces [param n] there
## (the holder's space): a brush's handle out of the surface, up along it and out to the side its work is on; a sponge's corner nearer
## upright ([constant CORNER_HELD]); a face flat on it.
func _held_axis(si: int, xy: Vector2, n: Vector3, tool: Dictionary, contact: String) -> Vector3:
	if contact == "face":
		# ...FLAT ON WHAT IS UNDER ALL OF IT, never on the one point it is over (under a nose, the surface faces down)
		var r := float(tool.get("mm", 20.0)) * 0.6
		var sum := n.normalized()
		for k in 12:
			var ph := TAU * float(k) / 12.0
			sum += _normal_mm(si, xy + Vector2(cos(ph), sin(ph)) * r * (0.5 if k % 2 == 0 else 1.0))
		return sum.normalized()
	var sd: Dictionary = skins[si]
	var frame: Vector2 = sd["frame"]
	var xf: Transform3D = sd["xform"]
	var right := (xf.basis * Vector3.RIGHT).normalized()
	var up := (xf.basis * Vector3.UP).normalized()
	var side := clampf((xy.x - frame.x * 0.5) / maxf(frame.x * HELD_SIDE_EDGE, 1e-3), -1.0, 1.0)
	if contact == "corner":
		return (n * CORNER_HELD.x + up * CORNER_HELD.y + right * side * CORNER_HELD.z).normalized()
	return (n * HELD_OUT + up * HELD_UP + right * side * HELD_SIDE).normalized()


# --- held clear -----------------------------------------------------------------------------------------

## WHAT STANDS OVER SKIN [param sd] SEEN FROM ITS FRONT, found once: the highest surface of its whole thing - the surface itself and what
## holds it (a mask's board) - every [constant CLEAR_CELL], [constant CLEAR_BEYOND] past its frame all round, in its part's own frame
## (meters along its front, -INF where nothing is; between cells, read across, and over an edge the highest beside it - [method _sunk]):
## `{at: its first cell (the part's x, y), n: cells across and up, z, to_part: the table's space as the skin rests into its part's, top: the
## highest over each block of [constant CLEAR_BLOCK] cells and those beside it, bn: blocks across and up}`.
func _obstacles(sd: Dictionary) -> Dictionary:
	var got: Dictionary = sd.get("clear", {})
	if got.has("top"):
		return got
	var to_part := ((sd["_rest"] as Transform3D) * (sd["xform"] as Transform3D)).affine_inverse()
	var faces := PackedVector3Array()
	for m in (work.things[int(sd["ti"])] as Dictionary)["meshes"]:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := to_part * work._world_of(mi)
		for v in mi.mesh.get_faces():
			faces.append(xf * v)
	var box: AABB = sd["box"]
	var at := Vector2(box.position.x, box.position.y) - Vector2.ONE * CLEAR_BEYOND
	var n := Vector2i(ceili((box.size.x + CLEAR_BEYOND * 2.0) / CLEAR_CELL) + 1, ceili((box.size.y + CLEAR_BEYOND * 2.0) / CLEAR_CELL) + 1)
	var z := PackedFloat32Array()
	z.resize(n.x * n.y)
	z.fill(-INF)
	if not faces.is_empty():
		var top := -INF
		for v in faces:
			top = maxf(top, v.z)
		var tm := TableWork._ray_mesh(faces)
		for j in n.y:
			_breathe()
			for i in n.x:
				var hit := TableWork._ray(tm, Vector3(at.x + float(i) * CLEAR_CELL, at.y + float(j) * CLEAR_CELL, top + 0.01), Vector3(0.0, 0.0, -1.0))
				if not hit.is_empty():
					z[j * n.x + i] = (hit["position"] as Vector3).z
	# ...and the highest of it over each block of cells and the cells beside it, for what stands well over it
	var bn := Vector2i(ceili(float(n.x) / CLEAR_BLOCK), ceili(float(n.y) / CLEAR_BLOCK))
	var top := PackedFloat32Array()
	top.resize(bn.x * bn.y)
	top.fill(-INF)
	for j in n.y:
		for i in n.x:
			var zk := z[j * n.x + i]
			if zk == -INF:
				continue
			for bj in range(maxi((j - 1) / CLEAR_BLOCK, 0), mini((j + 1) / CLEAR_BLOCK, bn.y - 1) + 1):
				for bi in range(maxi((i - 1) / CLEAR_BLOCK, 0), mini((i + 1) / CLEAR_BLOCK, bn.x - 1) + 1):
					top[bj * bn.x + bi] = maxf(top[bj * bn.x + bi], zk)
	var out := {"at": at, "n": n, "z": z, "to_part": to_part, "top": top, "bn": bn}
	sd["clear"] = out
	return out


## HOW DEEP TOOL [param tool], held [param contact] with its tip at [param p] pointing along [param a] (the table's space, the skin as
## it rests), stands in what stands over skin [param sd] ([method _obstacles] [param g]) past what that way of holding it lets it
## (meters; clear, none over 0) - its hairs bend, a sponge gives. Past [param stop], looked at no further.
func _sunk(sd: Dictionary, g: Dictionary, tool: Dictionary, contact: String, p: Vector3, a: Vector3, stop := INF) -> float:
	var c := _contact(tool, contact)
	var tip_l: Vector3 = c["tip"]
	var grip_l: Vector3 = c["grip"]
	var x0: Transform3D = tool["x0"]
	var v0 := (x0.basis * (grip_l - tip_l)).normalized()
	var r := Basis(Quaternion(v0, a)) if v0.dot(a) > -0.999 else Basis(Vector3.RIGHT, PI)
	return _sunk_node(sd, g, tool, contact, Transform3D(r, p - r * (x0 * tip_l)) * x0, 1.0, stop)


## HOW DEEP TOOL [param tool], its node at [param x] (the table's space, the skin as it rests), stands in what stands over skin
## [param sd] ([method _obstacles] [param g]) past what holding it [param contact], pressed [param press], lets it ([method _sunk]).
func _sunk_node(sd: Dictionary, g: Dictionary, tool: Dictionary, contact: String, x: Transform3D, press: float, stop := INF, margin := 0.0) -> float:
	var c := _contact(tool, contact)
	var tip_l: Vector3 = c["tip"]
	var grip_l: Vector3 = c["grip"]
	var M := (g["to_part"] as Transform3D) * x
	# ...AS DEEP AS IT GIVES BACK: each point as far as it is squashed from the tool's middle (the whole of a pressed face, a corner's
	# tip most - [method _tick_tool]), and near its tip as far as its hairs bend and its surface is found no finer than its cells
	var near := float(c["bend"]) + CLEAR_CELL
	var give := float(c["give"]) * press
	var mid: Vector3 = tool.get("center", tip_l)
	var into := (tip_l - grip_l).normalized()
	var reach := float(c.get("reach", 0.01))
	# (what stands over it, read here inline: a few hundred points a way it is tried, dozens of ways a place)
	var at: Vector2 = g["at"]
	var n: Vector2i = g["n"]
	var Z: PackedFloat32Array = g["z"]
	var top: PackedFloat32Array = g["top"]
	var bn: Vector2i = g["bn"]
	var pts: PackedVector3Array = tool["points"]
	# (all of it placed at once; and a point over the highest of what is round it, never looked at closer)
	var qs: PackedVector3Array = M * pts
	var worst := -INF
	for idx in qs.size():
		var q := qs[idx]
		var fx := (q.x - at.x) / CLEAR_CELL
		var fy := (q.y - at.y) / CLEAR_CELL
		if fx < 0.0 or fy < 0.0 or fx > float(n.x - 1) or fy > float(n.y - 1):
			continue
		var i := mini(int(fx), n.x - 2)
		var j := mini(int(fy), n.y - 2)
		if q.z > top[(j / CLEAR_BLOCK) * bn.x + i / CLEAR_BLOCK] + margin:
			continue
		var s := pts[idx]
		var k := j * n.x + i
		var z00 := Z[k]
		var z10 := Z[k + 1]
		var z01 := Z[k + n.x]
		var z11 := Z[k + n.x + 1]
		var d := 0.0
		if z00 == -INF or z10 == -INF or z01 == -INF or z11 == -INF:
			d = maxf(maxf(z00, z10), maxf(z01, z11)) - q.z
			if is_inf(d):
				continue
		else:
			# ...ACROSS ITS SLOPE: how far under its surface's own plane there
			var u := fx - float(i)
			var v := fy - float(j)
			var gx := lerpf(z10 - z00, z11 - z01, v) / CLEAR_CELL
			var gy := lerpf(z01 - z00, z11 - z10, u) / CLEAR_CELL
			d = (lerpf(lerpf(z00, z10, u), lerpf(z01, z11, u), v) - q.z) / minf(sqrt(1.0 + gx * gx + gy * gy), SLOPE_MOST)
		d += margin - give * clampf((s - mid).dot(into) / reach, 0.0, 1.0) - maxf(near - s.distance_to(tip_l), 0.0)
		if d > worst:
			worst = d
			if worst > stop:
				return worst
	return worst


## THE WAYS A TOOL IS TRIED, held [param contact], nearest [param want] first: round each of [param about] (the surface's normal where it
## touches, and the way the whole surface faces - at a mask's rim the one faces sideways, and a hand comes from the other), itself and
## [constant CLEAR_ROUND] ways round it at each of [constant CLEAR_TILTS].
static func _ways_round(about: Array, want: Vector3, contact: String) -> Array:
	var out: Array = []
	for a in about:
		var n := (a as Vector3).normalized()
		var e1 := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
		var e2 := n.cross(e1).normalized()
		out.append([n.angle_to(want), n])
		for tilt in CLEAR_TILTS:
			var tr := deg_to_rad(float(tilt))
			for k in CLEAR_ROUND:
				var ph := TAU * float(k) / float(CLEAR_ROUND)
				var ax := (n * cos(tr) + (e1 * cos(ph) + e2 * sin(ph)) * sin(tr)).normalized()
				out.append([ax.angle_to(want), ax])
	out.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	return out


## HOW TOOL [param tool] IS HELD AT (x, y) millimeters OF SKIN [param si] by [param contact], its tip on the surface, its own surface
## in nothing: the way it points nearest how a hand holds it there ([method _held_axis]) - each other way it is tried costing its turn
## ([constant CLEAR_TURN]) and how far it must stand off the surface, back along itself, to be clear ([method _sunk]): resting on its
## edge beside a nose beats hovering flat a finger over it - `Vector4(axis (the holder's space), off (meters))`. Pressed in as far as
## it ever is.
func _cleared(si: int, xy: Vector2, tool: Dictionary, contact: String) -> Vector4:
	var sd: Dictionary = skins[si]
	var g := _obstacles(sd)
	var on := at_mm(si, xy)
	var n_l: Vector3 = (on[1] as Vector3).normalized()
	var want := _held_axis(si, xy, n_l, tool, contact)
	if tool.is_empty() or (tool.get("points", PackedVector3Array()) as PackedVector3Array).is_empty():
		return Vector4(want.x, want.y, want.z, 0.0)
	var hw: Transform3D = sd["_rest"]
	var n := (hw.basis * n_l).normalized()
	var base: Vector3 = hw * (on[0] as Vector3) + n * TOUCH
	var give := float(_contact(tool, contact)["give"])
	var sponge := String(tool["kind"]) == "sponge"
	var sunk := func(ax_l: Vector3, off: float, stop: float) -> float:
		var ax := (hw.basis * ax_l).normalized()
		return _sunk(sd, g, tool, contact, base + ax * off - (ax if sponge else n) * give, ax, stop)
	if float(sunk.call(want, 0.0, 0.0)) <= 0.0:
		return Vector4(want.x, want.y, want.z, 0.0)
	var front: Vector3 = (sd["surface"] as Dictionary)["front"]
	var best := want
	var cost := INF
	for w in _ways_round([n_l, front] if n_l.angle_to(front) > deg_to_rad(CLEAR_TILTS[0]) else [n_l], want, contact):
		var turn := float((w as Array)[0]) * CLEAR_TURN
		# (the rest are turned further: none of them can cost less)
		if turn >= cost:
			break
		var ax: Vector3 = (w as Array)[1]
		var rate := maxf(ax.dot(front), 0.3)
		var d := float(sunk.call(ax, 0.0, (cost - turn) * rate))
		if turn + maxf(d, 0.0) / rate < cost:
			cost = turn + maxf(d, 0.0) / rate
			best = ax
	# ...stood off back along itself until it is clear - A BRUSH NO FURTHER THAN ITS HAIRS GIVE: past that it painted in the air, a
	# liner 14 mm off a mask's brow at the top of each diamond (feedback 0019); its hairs bend against what it meets, as a painter's do
	var off := 0.0
	for it in 6:
		var d := float(sunk.call(best, off, INF))
		if d <= 0.0:
			break
		off += d / maxf(best.dot(front), 0.3) + 0.0003
	if String(tool["kind"]) == "brush":
		off = minf(off, BRUSH_STAND_MOST)
	return Vector4(best.x, best.y, best.z, off)


## EACH KEY OF PROGRAM [param prog] on skin [param si] held clear ([method _cleared]) by tool [param tool] held [param contact], in
## order - a key where the one before it is, as that one; a spray's, none (it is held off the surface) - `{held: [Vector4 ...], ways:
## [1 where it is held by its corner instead], arcs: [how high it is lifted on its way to the next (meters, at the middle)]}`. A SPONGE SPREADING FLAT TURNS TO ITS CORNER where its face would stand off the surface
## more than [constant FLAT_MOST] and its corner costs less (beside a nose its face had hovered a finger off it).
func _held_keys(si: int, prog: Dictionary, tool: Dictionary, contact: String) -> Dictionary:
	var out := PackedVector4Array()
	var ways := PackedByteArray()
	var last_xy := Vector2.INF
	var last := Vector4.ZERO
	var last_way := 0
	for k in prog["keys"]:
		var kk: Array = k
		_breathe()
		if int(kk[5]) == 3:
			out.append(Vector4.ZERO)
			ways.append(0)
			continue
		var xy := Vector2(float(kk[1]), float(kk[2]))
		if xy != last_xy:
			last = _cleared(si, xy, tool, contact)
			last_way = 0
			if contact == "face" and String(tool.get("kind", "")) == "sponge" and last.w > FLAT_MOST:
				var by_corner := _cleared(si, xy, tool, "corner")
				if _held_cost(si, xy, tool, "corner", by_corner) < _held_cost(si, xy, tool, contact, last):
					last = by_corner
					last_way = 1
			last_xy = xy
		out.append(last)
		ways.append(last_way)
	# ...AND LIFTED ON ITS WAY FROM ONE TO THE NEXT where it would go into the surface between them, as a hand lifts a tool between
	# presses: each stretch over the surface looked along ([constant ARC_STEP]) - a sponge's corner between two dabs either side of a
	# nose, turned from the one way to the other, went 18 mm into it with the 2.5 mm lift its program gives it
	var keys: Array = prog["keys"]
	var arcs := PackedFloat32Array()
	arcs.resize(keys.size())
	if tool.is_empty():
		return {"held": out, "ways": ways, "arcs": arcs}
	var sd: Dictionary = skins[si]
	var g := _obstacles(sd)
	var front: Vector3 = (sd["surface"] as Dictionary)["front"]
	var making := {"held": out, "ways": ways, "arcs": PackedFloat32Array()}
	var tr := {"_ch": String(tool.get("ch", "")), "_hand": 0}
	var x0: Transform3D = tool["x0"]
	for k in range(keys.size() - 1):
		var a: Array = keys[k]
		var b: Array = keys[k + 1]
		_breathe()
		if int(a[5]) != 0 or int(b[5]) != 0 or float(b[0]) - float(a[0]) < 1e-5:
			continue
		# (ALONG A STROKE, pressed the whole way - a line, a sweep's row - every pose is on the surface: lifted there it painted in the air,
		# a liner 11 mm and a flat brush 17 mm over a mask's rim; feedback 0019, 0021)
		if float(a[4]) > 0.5 and float(b[4]) > 0.5:
			continue
		var xa := Vector2(float(a[1]), float(a[2]))
		var xb := Vector2(float(b[1]), float(b[2]))
		var turn := Vector3(out[k].x, out[k].y, out[k].z).angle_to(Vector3(out[k + 1].x, out[k + 1].y, out[k + 1].z))
		# (along a stroke, a step of a few millimeters and hardly turned: the keys either side are clear, and so is the way between)
		if xa.distance_to(xb) < ARC_STEP and turn < deg_to_rad(ARC_TURN) and ways[k] == ways[k + 1]:
			continue
		var need := 0.0
		var looks := clampi(maxi(ceili(xa.distance_to(xb) / ARC_STEP), ceili(rad_to_deg(turn) / ARC_TURN)), 3, ARC_LOOKS)
		for fi in looks:
			var f := (float(fi) + 0.5) / float(looks)
			# (beside a key its own clearance holds it: the arc's lift there is next to nothing, and what it found divided by that had
			# lifted a sweep 155 mm)
			if f < ARC_ENDS or f > 1.0 - ARC_ENDS:
				continue
			# ...posed as it will be, but for the lift this finds
			var v: Variant = _surface_hold(si, prog, lerpf(float(a[0]), float(b[0]), f), 0.0, tr, making)
			var x: Transform3D = v if v is Transform3D else _node_at(v as Array, tool, x0)
			var way := _way(tool, v as Array) if v is Array else contact
			var press := float((v as Array)[2]) if v is Array else 0.0
			# ...and clear of it by a little, as a hand gives what it goes past room (read near a nose's steep side, its depth is a guess)
			var d := _sunk_node(sd, g, tool, way, x, press, INF, ARC_CLEAR * (1.0 - press))
			if d > 0.0:
				var n_l := (at_mm(si, xa.lerp(xb, f))[1] as Vector3).normalized()
				need = maxf(need, (d / maxf(n_l.dot(front), 0.3) + 0.0005) / sin(PI * f))
		arcs[k] = need
	return {"held": out, "ways": ways, "arcs": arcs}


## What holding tool [param tool] by [param contact] as [param v] ([method _cleared]) at (x, y) of skin [param si] costs: how far it
## stands off, and how far it is turned from how a hand holds it there ([constant CLEAR_TURN]).
func _held_cost(si: int, xy: Vector2, tool: Dictionary, contact: String, v: Vector4) -> float:
	var want := _held_axis(si, xy, (at_mm(si, xy)[1] as Vector3).normalized(), tool, contact)
	return v.w + Vector3(v.x, v.y, v.z).angle_to(want) * CLEAR_TURN


## A TOOL AIMED AT (x, y) millimeters of skin [param si] from [param off] meters away: out from the surface, to its right and a little up
## along it - in the picture, never between the surface and the lens - pointed at the place, its tip toward it.
func _spray_hold(si: int, xy: Vector2, off: float, press: float, T: float) -> Array:
	var on := at_mm(si, xy)
	var hw := holder_world(si, T)
	var p: Vector3 = hw * (on[0] as Vector3)
	var n: Vector3 = (hw.basis * (on[1] as Vector3)).normalized()
	var xf: Transform3D = (skins[si] as Dictionary)["xform"]
	var up := (hw.basis * (xf.basis * Vector3.UP)).normalized()
	var right := (hw.basis * (xf.basis * Vector3.RIGHT)).normalized()
	var away := (n * SPRAY_FROM.x + right * SPRAY_FROM.y + up * SPRAY_FROM.z).normalized()
	return [p + away * off, away, press, false]


## OVER ITS PAINT (a load: its pot; a rinse: the water; a pick: the stones' dish), pressed in: `[tip, axis, 1, false, how far over
## it the tool comes in and leaves, the way it is held]` - a sponge by its corner (onto a towel, flat), its own surface inside the pot's
## mouth ([method _pot_clear]), lifted where it cannot be.
func _pot_hold(kind: String, from: String, paint: String, T: float, tr: Dictionary) -> Array:
	var name := String(tr.get(kind, "")) if kind in ["rinse", "dry"] else from
	var p := _source_of(kind, name, paint, T)
	var tool := _tool_or_none(tr)
	var contact := _contact_for(tool, "", kind) if not tool.is_empty() else ""
	var axis := Vector3.UP if contact == "face" else (Vector3.UP * 0.9 + Vector3.BACK * 0.35).normalized()
	# ...COMING IN OVER ITS RIM: a cup's water lies well under it ([constant RIM_CLEAR])
	if name.is_empty() and kind == "load" and not paint.is_empty():
		var cr := _cream_near(paint)
		if not cr.is_empty() and int(cr.get("ti", -1)) >= 0:
			name = String((work.things[int(cr["ti"])] as Dictionary)["name"])
	var rise := TRIP_LIFT
	var mouth := {}
	if not name.is_empty() and not name.contains("."):
		mouth = work._mouth_of(name, T)
		if not mouth.is_empty():
			rise = maxf(rise, float((mouth["at"] as Vector3).y) + RIM_CLEAR - p.y)
	# ...AND ITS BODY INSIDE THE MOUTH as it is drawn, never through the wall - pressed flat on its paint, a load ([method _flat_lift])
	var floor_y := p.y - 0.001 if kind == "load" and not tool.is_empty() and _pressed_into(tool, contact) > 0.0 \
		and String(tool.get("kind", "")) != "brush" else NAN
	if not tool.is_empty() and not mouth.is_empty() and kind != "dry":
		var cl := _pot_clear(name, tool, contact, p, axis, mouth, floor_y)
		axis = cl["axis"]
		p += (cl["off"] as Vector3) + Vector3.UP * float(cl["lift"])
		rise = maxf(rise - float(cl["lift"]), TRIP_LIFT)
	return [p, axis, 1.0, false, rise, contact, floor_y]


## The pots' ways tried across a mouth (shares of its room, [method _pot_clear]): its middle first - as far as a corner going in
## beside the wall, the end it is the corner of lying across the mouth.
const POT_OFFS := [0.0, 0.3, 0.55, 0.75, 0.9]
const POT_OFF_ROUND := 8
## ...and its wall kept off a tool drawn pressed flat on its paint this far: its outline is its own edges, sampled along them
## ([constant CLEAR_WALL] is a rigid tool's, its points [constant POINTS_EVERY] apart).
const POT_WALL := 0.002


## HOW TOOL [param tool] IS HELD IN A POT, held [param contact] with its tip at [param p] and pushed in its [method _pressed_into]: of
## every part of it under the rim of [param mouth] AS IT IS DRAWN - what would go under the paint's surface [param floor_y] (none: NAN)
## pressed flat on it ([method _flat_lift]) - none past its wall ([constant CLEAR_WALL]). The way nearest [param want] with its tip
## nearest the mouth's middle that is ([constant POT_OFFS] across it), else the least past, lifted until what is past is over the rim -
## `{axis (the table's space), off (its tip moved across the mouth), lift (meters)}`, found once ([member _pots]).
func _pot_clear(name: String, tool: Dictionary, contact: String, p: Vector3, want: Vector3, mouth: Dictionary, floor_y := NAN) -> Dictionary:
	var key := "%s|%s|%s|%.4f" % [name, tool.get("ch", ""), contact, p.y]
	if _pots.has(key):
		return _pots[key]
	var c := _contact(tool, contact)
	var tip_l: Vector3 = c["tip"]
	var grip_l: Vector3 = c["grip"]
	var x0b: Basis = (tool["x0"] as Transform3D).basis
	var v0 := (x0b * (grip_l - tip_l)).normalized()
	var at: Vector3 = mouth["at"]
	var flat := not is_nan(floor_y)
	var r := float(mouth["r"]) - (POT_WALL if flat else CLEAR_WALL)
	var pts: PackedVector3Array = tool.get("points", PackedVector3Array())
	# (as far into its paint as it is ever pushed, [method _trip])
	var give := _pressed_into(tool, contact)
	# how far past the wall it stands, and how far under the rim what is past it is
	var past := func(ax: Vector3, off: Vector3, stop: float) -> Vector2:
		var B := (Basis(Quaternion(v0, ax)) if v0.dot(ax) > -0.999 else Basis(Vector3.RIGHT, PI)) * x0b
		var base := p + off - ax * give
		var deep := 0.0
		if flat:
			for s in pts:
				deep = maxf(deep, floor_y - (base + B * ((s as Vector3) - tip_l)).y)
		var worst := -INF
		var under := 0.0
		for s in pts:
			var q: Vector3 = base + B * ((s as Vector3) - tip_l)
			var lift := _flat_lift(q.y - floor_y, deep) if flat else 0.0
			if q.y + lift >= at.y:
				continue
			# (spread out as it is squeezed: at most that much further from the middle)
			var o := Vector2(q.x - at.x, q.z - at.z).length() + lift * FLAT_SPREAD - r
			if o > 0.0:
				under = maxf(under, at.y - q.y - lift)
			if o > worst:
				worst = o
				if worst > stop:
					break
		return Vector2(worst, under)
	var out := {"axis": want, "off": Vector3.ZERO, "lift": 0.0}
	if not pts.is_empty() and (past.call(want, Vector3.ZERO, 0.0) as Vector2).x > 0.0:
		var ways := _ways_round([Vector3.UP], want, contact)
		var best := want
		var best_off := Vector3.ZERO
		var least := INF
		var found := false
		# (held as near upright as it can be, and moved across the mouth for it - a hand moves a sponge aside before it lays it over)
		var offs: Array = []
		for share in POT_OFFS:
			for k in (1 if float(share) == 0.0 else POT_OFF_ROUND):
				var ph := TAU * float(k) / float(POT_OFF_ROUND)
				offs.append(Vector3(cos(ph), 0.0, sin(ph)) * float(share) * r)
		for w in ways:
			var ax: Vector3 = (w as Array)[1]
			for off in offs:
				var o: Vector2 = past.call(ax, off, least)
				if o.x <= 0.0:
					out = {"axis": ax, "off": off, "lift": 0.0}
					found = true
					break
				if o.x < least:
					least = o.x
					best = ax
					best_off = off
			if found:
				break
		if not found:
			out = {"axis": best, "off": best_off, "lift": (past.call(best, best_off, INF) as Vector2).y + RIM_CLEAR * 0.3}
	_pots[key] = out
	return out


## HOW FAR A POINT [param s] over the surface it is pressed onto (meters; under it, less than 0) is drawn lifted, the deepest of what
## it is part of [param deep] past it: what would go under the surface drawn ON it, the [constant FLAT_BAND] over it giving - squeezed
## hardest nearest it, and as the foam was at the band's top. prop_common.gdshaderinc's `flat_on` draws it.
static func _flat_lift(s: float, deep: float) -> float:
	if deep <= 0.0 or s >= FLAT_BAND:
		return 0.0
	var u := clampf((s + deep) / (FLAT_BAND + deep), 0.0, 1.0)
	return FLAT_BAND * pow(u, (FLAT_BAND + deep) / FLAT_BAND) - s


## The paint on the table nearest [param paint]'s color ([member _creams]), or empty.
func _cream_near(paint: String) -> Dictionary:
	var best := INF
	var got := {}
	var want := Color.html(paint)
	for cr in _creams:
		var c: Color = (cr as Dictionary)["color"]
		var dd := Vector3(c.r - want.r, c.g - want.g, c.b - want.b).length()
		if dd < best:
			best = dd
			got = cr
	return got


## WHERE A TOOL TAKES ITS PAINT: [param from] named (a thing, "thing/part", or "thing.point") - its mouth, down to what is in
## it - or the paint on the table nearest [param paint]'s color, or - none - over the middle of the table near the work.
func _source_of(kind: String, from: String, paint: String, T: float) -> Vector3:
	if not from.is_empty():
		if from.contains("."):
			return work.place_of(from, work.work_spot(), T)
		var mouth := work._mouth_of(from, T)
		if not mouth.is_empty():
			var at: Vector3 = mouth["at"]
			var y := work._surface_under(from.get_slice("/", 0), at, T)
			return Vector3(at.x, (y + 0.001) if not is_nan(y) and y < at.y else at.y - (0.02 if kind == "rinse" else 0.006), at.z)
		var ti := work._thing_named(from.get_slice("/", 0))
		if ti >= 0:
			return work.place_of(from.get_slice("/", 0) + ".top", work.work_spot(), T)
	if not paint.is_empty():
		var cr := _cream_near(paint)
		if not cr.is_empty():
			return cr["at"]
	var spot := work.work_spot()
	return spot + Vector3(0.12, 0.06, 0.05)


## A TRIP: from [param near] to [param pot], over [param s] of the way - there, then down into it and up: a load dips and turns
## once, a rinse swishes round twice, a dry presses onto the cloth and wipes across it - a sponge or a puff PUSHED INTO ITS PAINT and
## held there as it turns ([method _pressed_into]). It ends lifted over the place. A hold, or - turned in the hand on the way - its
## node's place.
func _trip(near: Array, pot: Array, s: float, seed: int, kind: String, tool: Dictionary) -> Variant:
	var go := 0.4
	var rise := float(pot[4]) if pot.size() > 4 else TRIP_LIFT
	var over: Vector3 = (pot[0] as Vector3) + Vector3.UP * rise
	if s < go:
		return _between(near, [over, pot[1], 0.0, false, rise, _contact_of(pot)], s / go, seed, tool)
	var w := (s - go) / (1.0 - go)
	var deep := _pressed_into(tool, _contact_of(pot)) if kind == "load" else 0.0
	# ...held down as it turns, where it takes up as much as it can
	var dip := clampf(sin(w * PI) * LOAD_HELD, 0.0, 1.0) if deep > 0.0 else sin(w * PI)
	# ...DABBED INTO IT two or three times (the user: "when we're dabbing from the container"), eased between, never out of it
	var pumped := deep > 0.0 and String(tool.get("kind", "")) != "brush"
	var pumps := 2 + absi(hash([seed, "pumps"])) % 2
	var press := dip * lerpf(LOAD_EASE, 1.0, pow(sin(w * PI * float(pumps)), 2.0)) if pumped else dip
	var way := Vector3.ZERO
	match kind:
		"rinse":
			way = Vector3(cos(w * TAU * 2.0), 0.0, sin(w * TAU * 2.0)) * 0.004 * dip
		"dry":
			way = Vector3(lerpf(-WIPE, WIPE, Hands.smooth(w)), 0.0, 0.0)
		_:
			# (a brush turned once in its paint; what is pressed into it pumps, and never swirls into the pot's wall)
			way = Vector3(cos(w * TAU), 0.0, sin(w * TAU)) * 0.0025 * dip if not pumped else Vector3.ZERO
	var into := Vector3.ZERO
	if deep > 0.0:
		into = (pot[1] as Vector3).normalized() * deep * press
	elif String(tool.get("kind", "")) == "sponge":
		into = (pot[1] as Vector3).normalized() * float(_contact(tool, _contact_of(pot))["give"]) * dip
	# (and where its paint's surface is, which it is drawn pressed flat on - [method _tick_tool])
	return [(pot[0] as Vector3) + Vector3.UP * (rise * (1.0 - dip)) + way - into, pot[1], press, false, rise, _contact_of(pot),
		float(pot[6]) if pot.size() > 6 and pumped else NAN]


## HOW FAR TOOL [param tool], held [param contact], is pushed into its paint to take it up (meters): a sponge its [constant LOAD_PRESS],
## squashed against it, a pad (a puff) [constant LOAD_PRESS_PAD], a brush's hairs [constant BRUSH_DIP].
static func _pressed_into(tool: Dictionary, contact: String) -> float:
	if String(tool.get("kind", "")) == "sponge":
		return LOAD_PRESS
	if String(tool.get("kind", "")) == "brush":
		return BRUSH_DIP
	if bool(tool.get("flat", false)) and _contact(tool, contact).get("tip") != null:
		return LOAD_PRESS_PAD
	return 0.0


## From hold [param a] to hold [param b], as a hand goes - lifted on its way between places apart, and over what stands between. From
## one way of holding tool [param tool] to another (a sponge's corner out of its paint, its face onto the surface) it is turned in the
## hand on the way: its node's place.
func _between(a: Array, b: Array, s: float, seed: int, tool: Dictionary) -> Variant:
	if not tool.is_empty() and _way(tool, a) != _way(tool, b):
		var x0: Transform3D = tool["x0"]
		var na := _node_at(a, tool, x0)
		var nb := _node_at(b, tool, x0)
		var c: Vector3 = tool["center"]
		var ca := na * c
		var cb := nb * c
		var lift_c := maxf(clampf(ca.distance_to(cb) * 0.25, 0.0, 0.06), _lift_over(ca, cb, seed, _reach_of(tool)))
		var q := Hands.carried(ca, cb, Vector3.ZERO, Vector3.ZERO, lift_c, s, seed)
		var rb := Basis(Quaternion(na.basis.orthonormalized()).slerp(Quaternion(nb.basis.orthonormalized()), Hands.timing(s)))
		var basis := rb.scaled(na.basis.get_scale())
		return Transform3D(basis, q - basis * c)
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var reach := _reach_of(tool) if not tool.is_empty() else TOPS_BESIDE
	var lift := maxf(clampf(pa.distance_to(pb) * 0.25, 0.0, 0.06), _lift_over(pa, pb, seed, reach))
	var p := Hands.carried(pa, pb, Vector3.ZERO, Vector3.ZERO, lift, s, seed)
	var axis := (a[1] as Vector3).slerp((b[1] as Vector3).normalized(), Hands.timing(s)) if (a[1] as Vector3).dot(b[1] as Vector3) > -0.99 else (b[1] as Vector3)
	return [p, axis, 0.0, false, TRIP_LIFT, _contact_of(b) if not _contact_of(b).is_empty() else _contact_of(a)]


# --- when everything happens --------------------------------------------------------------------------

## AFTER THE SCHEDULE: each element's moments - laid, gone over, swept - its stones', the paint on each tool's tip, and the
## puffs a pat raises - from every paint act where the schedule has put it.
func spans(entries: Array) -> void:
	_dust = []
	_loads = {}
	var spans_of := {}            # "si|id" -> {span, blend, sweep}
	for s in skins:
		for st in (s as Dictionary).get("stones", []):
			(st as Dictionary)["t"] = Vector2(INF, INF)
	for en in entries:
		var e: Dictionary = en
		var tr: Dictionary = e["track"]
		var t0 := float(e["t0"])
		var d := maxf(float(e["t1"]) - t0, 1e-3)
		var plan := _plan_entry(e, tr, d)
		var si := int(plan["si"])
		var ch := String(tr["_ch"])
		if not _loads.has(ch):
			_loads[ch] = []
		for p in plan["phases"]:
			var pd: Dictionary = p
			var a := t0 + float(pd["a"])
			var b := t0 + float(pd["b"])
			match String(pd["kind"]):
				"load":
					(_loads[ch] as Array).append([lerpf(a, b, 0.5), String(pd["paint"])])
				"rinse":
					(_loads[ch] as Array).append([lerpf(a, b, 0.5), ""])
				"el":
					var key := "%d|%s" % [si, String(pd["el"])]
					if not spans_of.has(key):
						spans_of[key] = {}
					var role := String(pd["role"])
					var sp: Dictionary = spans_of[key]
					if not sp.has(role):
						sp[role] = Vector2(a, b)
					var prog: Dictionary = pd["prog"]
					var k := (b - a) / maxf(float(prog["natural"]), 1e-3)
					for pt in prog.get("pats", PackedFloat32Array()):
						if _dust.size() < 400:
							_dust.append({"t": a + float(pt) * k, "si": si, "prog": prog, "tau": float(pt), "look": "dust"})
					for mm in prog.get("mists", []):
						if _dust.size() < 400:
							_dust.append({"t": a + float((mm as Array)[0]) * k, "si": si, "prog": prog, "tau": float((mm as Array)[0]), "look": "mist"})
					# ...and each time it goes back to its paint for more, in the middle of it
					if role == "paint":
						var keys: Array = prog["keys"]
						for q in range(1, keys.size()):
							if int((keys[q] as Array)[5]) == 1 and int((keys[q - 1] as Array)[5]) == 1:
								var paint_of: String = String(element(si, String(pd["el"])).get("paint", ""))
								if not paint_of.is_empty():
									(_loads[ch] as Array).append([a + float((keys[q] as Array)[0]) * k, paint_of])
					if role == "sweep" and _dust.size() < 400:
						var tt := a + 0.5
						while tt < b and _dust.size() < 400:
							_dust.append({"t": tt, "si": si, "prog": prog, "tau": (tt - a) / k, "look": "dust"})
							tt += 1.6
					var stones: Array = prog.get("stones", [])
					for j in stones.size():
						_stone_at(si, String(pd["el"]), j, stones[j] as Array, a, k, ch)
	for s_i in skins.size():
		var sd: Dictionary = skins[s_i]
		var order: Array = []
		for id in sd["items"]:
			var it: Dictionary = sd["items"][id]
			var sp: Dictionary = spans_of.get("%d|%s" % [s_i, id], {})
			var span: Vector2 = sp.get("paint", Vector2(1e9, 1e9 + 1.0))
			it["span"] = span
			it["blend"] = sp.get("blend", Vector2(1e9, 1e9 + 1.0))
			it["sweep"] = sp.get("sweep", Vector2(1e9, 1e9 + 1.0))
			for m in it["mats"]:
				var mat := m as ShaderMaterial
				mat.set_shader_parameter("span", span)
				mat.set_shader_parameter("blend_span", it["blend"])
				mat.set_shader_parameter("sweep_span", it["sweep"])
			order.append([span.x, id])
		# WHAT GOES ON LATER LIES OVER WHAT WENT ON BEFORE
		order.sort()
		for k in order.size():
			var it: Dictionary = sd["items"][order[k][1]]
			for sp in it["sprites"]:
				var spr := sp as Sprite2D
				if spr.get_parent() != null:
					spr.get_parent().move_child(spr, k)
	for ch in _loads:
		(_loads[ch] as Array).sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	_drawn_t = NAN


func _stone_at(si: int, el: String, j: int, st: Array, a: float, k: float, ch: String) -> void:
	for s in (skins[si] as Dictionary).get("stones", []):
		var sd: Dictionary = s
		if String(sd["el"]) == el and int(sd["k"]) == j and (sd["t"] as Vector2).x == INF:
			sd["t"] = Vector2(a + float(st[0]) * k, a + float(st[1]) * k)
			sd["tool"] = ch
			return


## THE PUFFS OF POWDER the work raises, as a cue's bursts are placed ([method TableWork.plan_cues]): `[{t, p}]`.
func dust(look := "dust") -> Array:
	var out: Array = []
	for dd in _dust:
		var d: Dictionary = dd
		if String(d.get("look", "dust")) != look:
			continue
		var h := _hold_of(_surface_hold(int(d["si"]), d["prog"], float(d["tau"]), float(d["t"]), {"_ch": "", "_hand": 0}), {})
		# ...thrown the way the tool points, at what it is sprayed on (a burst throws along its moment's up)
		var toward := -(h[1] as Vector3).normalized() if look == "mist" else Vector3.UP
		var side := toward.cross(Vector3.FORWARD if absf(toward.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		out.append({"t": float(d["t"]), "p": h[0], "basis": Basis(side, toward, side.cross(toward).normalized())})
	return out


# --- drawn --------------------------------------------------------------------------------------------

## THE PAINT AT SHOW TIME [param t] (its canvas draws every frame - two small 2D pictures: a frame that asked for one draw could be
## followed by another, in a render or a probe, before the first was ever drawn): what is laid shows where its tool has been, its stones where they are, each tool's hairs
## bent as they are pulled and pressed, its tip the color it was loaded with, a sponge given where it is pressed.
func tick(t: float, entries_of: Callable) -> void:
	var jumped := is_nan(_drawn_t) or absf(t - _drawn_t) > 0.25
	for s in skins:
		var sd: Dictionary = s
		for id in sd["items"]:
			var it: Dictionary = sd["items"][id]
			var live := _live(it, t) or (not is_nan(_drawn_t) and _live(it, _drawn_t))
			if jumped or live:
				for m in it["mats"]:
					(m as ShaderMaterial).set_shader_parameter("now", t)
		for st in sd.get("stones", []):
			_tick_stone(st as Dictionary, t)
	for ch in tools:
		_tick_tool(String(ch), t, entries_of)
	_drawn_t = t


func _live(it: Dictionary, t: float) -> bool:
	for k in ["span", "blend", "sweep"]:
		var sp: Vector2 = it.get(k, Vector2(1e9, 1e9))
		if t >= sp.x - 1.0 and t <= sp.y + 1.0:
			return true
	return false


func _tick_stone(st: Dictionary, t: float) -> void:
	var mi: MeshInstance3D = st["node"]
	var w: Vector2 = st["t"]
	if t < w.x or w.x == INF:
		mi.visible = false
		return
	mi.visible = true
	if t >= w.y:
		mi.transform = st["seat"]
		return
	# ...carried at the tool's tip
	var tool: Dictionary = tools.get(String(st["tool"]), {})
	if tool.is_empty():
		mi.transform = st["seat"]
		return
	var node: Node3D = tool["node"]
	var tip_w := work._world_of(node) * (tool["tip"] as Vector3)
	var holder := mi.get_parent() as Node3D
	mi.transform = Transform3D(Basis.IDENTITY, work._world_of(holder).affine_inverse() * tip_w)


## A TOOL'S HAIRS, TIP AND GIVE at show time [param t]: the entry of its channel that holds it now (or just let it go).
func _tick_tool(ch: String, t: float, entries_of: Callable) -> void:
	var tool: Dictionary = tools[ch]
	var ents: Array = entries_of.call(ch)
	var e: Dictionary = {}
	for en in ents:
		var ed: Dictionary = en
		if String((ed["track"] as Dictionary)["law"]) == "paint" and t >= float(ed["t0"]) and t <= float(ed["t1"]) + SETTLE:
			e = ed
	# THE PAINT ON ITS TIP: the last it took up, unless rinsed since
	var tip := Color(0, 0, 0, 0)
	var since := 0.0
	for ld in _loads.get(ch, []):
		if float(ld[0]) <= t:
			tip = Color.html(String(ld[1])) if not String(ld[1]).is_empty() else Color(0, 0, 0, 0)
			since = t - float(ld[0])
	# ...THINNER AS IT IS USED, down to what never comes out of a brush until it is rinsed
	var load := lerpf(TIP_LEFT, TIP_FULL, exp(-since / TIP_LASTS)) if tip.a > 0.0 else 0.0
	for tf in tool["tufts"]:
		var mat: ShaderMaterial = (tf as Dictionary)["mat"]
		mat.set_shader_parameter("tip_paint", Color(tip.r, tip.g, tip.b, load))
	if e.is_empty():
		for tf in tool["tufts"]:
			((tf as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("bristle_bend", Vector3.ZERO)
			((tf as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("bristle_splay", 0.0)
		for sp in tool["sponges"]:
			((sp as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("squash", Vector4.ZERO)
			((sp as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("flat_by", Vector3.ZERO)
		return
	var tr: Dictionary = e["track"]
	var t0 := float(e["t0"])
	var d := maxf(float(e["t1"]) - t0, 1e-3)
	var plan := _plan_entry(e, tr, d)
	var hold_at := func(tt: float) -> Array:
		var held: Variant = _held_at(plan, tr, clampf(tt - t0, 0.0, d), tt, e["from"], work._rest.get(ch, Transform3D.IDENTITY))
		return _hold_of(held, tool)
	var node_w := work._world_of(tool["node"])
	if not tool["tufts"].is_empty():
		var len := float(tool["len"])
		var target := func(tt: float) -> Array:
			var h0: Array = hold_at.call(tt - 0.03)
			var h1: Array = hold_at.call(tt + 0.03)
			var v := ((h1[0] as Vector3) - (h0[0] as Vector3)) / 0.06
			var press := (float(h0[2]) + float(h1[2])) * 0.5
			var axis: Vector3 = ((h0[1] as Vector3) + (h1[1] as Vector3)).normalized()
			# what pulls the hairs is the way it goes along the surface, never into it
			var n := axis.normalized()
			v -= n * v.dot(n) * 0.5
			return Bristles.target(v, press, len, axis.normalized())
		var bent: Array = Bristles.response(target, t)
		var inv := node_w.basis.inverse()
		for tf in tool["tufts"]:
			var mat: ShaderMaterial = (tf as Dictionary)["mat"]
			mat.set_shader_parameter("bristle_bend", inv * (bent[0] as Vector3))
			mat.set_shader_parameter("bristle_splay", float(bent[1]))
	for sp in tool["sponges"]:
		var mat2: ShaderMaterial = (sp as Dictionary)["mat"]
		var h: Array = hold_at.call(t)
		var into := -(h[1] as Vector3).normalized()
		var dir_m := (node_w.basis.inverse() * into).normalized()
		# ...GIVING BACK TO THE SURFACE what it was pushed into it ([method _skin_hold]): squashed from its middle that much at its tip
		var way := _contact(tool, _contact_of(h))
		# ...in its paint (a trip's hold, off the surface) pushed in deeper ([method _trip])
		var pushed := _pressed_into(tool, _contact_of(h)) if not bool(h[3]) else float(way["give"])
		var give := pushed * float(h[2]) / float(way["reach"])
		# ...PRESSED INTO ITS PAINT, drawn flat on its surface ([method _flat_lift]) - in its own space, as far as the deepest of it went
		var floor_y := float(h[6]) if h.size() > 6 else NAN
		var flat := _flat_on(node_w, floor_y, tool) if not is_nan(floor_y) else []
		mat2.set_shader_parameter("squash", Vector4(dir_m.x, dir_m.y, dir_m.z, minf(give, 0.5)) if flat.is_empty() else Vector4.ZERO)
		mat2.set_shader_parameter("squash_at", tool["center"])
		mat2.set_shader_parameter("flat_by", Vector3.ZERO if flat.is_empty() else flat[1])
		if not flat.is_empty():
			mat2.set_shader_parameter("flat_on", flat[0])
			mat2.set_shader_parameter("flat_at", flat[2])


## TOOL [param tool], its node at [param node_w], PRESSED ONTO the level surface at [param floor_y] (the table's space): in its node's
## space, `[Vector4(the surface's normal toward it, how far along that the surface is), Vector3(how far the deepest of it went past it,
## the band over it that gives, how far it spreads - [constant FLAT_BAND], [constant FLAT_SPREAD]), the deepest of it]` - empty when
## none of it is past the surface. prop_common.gdshaderinc's `flat_on`, `flat_by` and `flat_at`.
static func _flat_on(node_w: Transform3D, floor_y: float, tool: Dictionary) -> Array:
	# a point's height over it is its node's `row` (the world's up, in the node's space) - scaled as the node is
	var row := Vector3(node_w.basis.x.y, node_w.basis.y.y, node_w.basis.z.y)
	var k := row.length()
	if k < 1e-6:
		return []
	var n := row / k
	var w := (floor_y - node_w.origin.y) / k
	var deep := 0.0
	var at := Vector3.ZERO
	var pts: PackedVector3Array = tool.get("points", PackedVector3Array())
	for q in pts:
		var d := w - n.dot(q)
		if d > deep:
			deep = d
			at = q
	if deep <= 0.0:
		return []
	return [Vector4(n.x, n.y, n.z, w), Vector3(deep, FLAT_BAND / k, FLAT_SPREAD), at]


# --- telling the agents -------------------------------------------------------------------------------

## WHAT CAN BE PAINTED and what paints, as the puppeteer reads it ([method TableWork.parts_report]).
func report() -> PackedStringArray:
	var out := PackedStringArray()
	for si in skins.size():
		var sd: Dictionary = skins[si]
		var nm := String(sd["name"]) + ("/" + String(sd["part"]) if not String(sd["part"]).is_empty() else "")
		var els: Array = (sd["design"] as Dictionary).get("elements", [])
		if els.is_empty():
			out.append("- \"%s\" has a surface to paint (its front, %d x %d mm), and no design for it yet" % [nm, roundi((sd["frame"] as Vector2).x), roundi((sd["frame"] as Vector2).y)])
			continue
		out.append("- \"%s\" has a surface to paint (`paint` with `on`: \"%s\"), and its design, %d elements in the order they go on:" % [nm, nm, els.size()])
		for e in els:
			var ed: Dictionary = e
			var r := Skins.bounds(ed, sd["frame"])
			var line := "    \"%s\" (%s): a %s in %s, %s, %d x %d mm" % [ed["id"], ed["stage"] if not String(ed["stage"]).is_empty() else "-", ed["kind"],
				ed["paint"], ed["finish"], roundi(r.size.x), roundi(r.size.y)]
			for m in ["brush", "sponge", "tool"]:
				var manner := Skins.manner_of(ed, m)
				var made := _made_for(si, ed, manner, 6.0 if m == "brush" else (Skins.width_for(m, 24.0, manner) if m == "sponge" else 20.0))
				line += "; %s %ds" % [{"brush": "a 6 mm brush", "sponge": "a sponge", "tool": "a puff"}[m] if not manner in ["line", "dab", "place"] else manner, roundi(float((made["program"] as Dictionary)["natural"]))]
				if manner in ["line", "dab", "place"]:
					break
			out.append(line)
	for ti in work.things.size():
		for w in (work.things[ti] as Dictionary)["works"]:
			var wk: Dictionary = work.works[int(w)]
			if String(wk["kind"]) != "free":
				continue
			var tufted := false
			for mi in (wk["node"] as Node).find_children("*", "MeshInstance3D", true, false):
				var mat := (mi as MeshInstance3D).material_override as ShaderMaterial
				if mat != null and mat.has_meta("tuft"):
					var tf: Dictionary = mat.get_meta("tuft")
					out.append("- %s is a %s brush, %.0f mm across: it paints" % [work._part_label(int(w)), String(tf["kind"]), float(tf["mm"])])
					tufted = true
					break
			if tufted:
				continue
	return out


## WHAT AN ACT PAINTS, as `act` answers ([method TableWork.check]): each element, how long it takes at this act's pace, and
## what of each design is left unpainted by every act there is.
func said(act: Dictionary, t0: float, t1: float) -> PackedStringArray:
	var out := PackedStringArray()
	for tr in act["tracks"]:
		var t: Dictionary = tr
		if String(t["law"]) != "paint":
			continue
		var plan := plan_of(t, t1 - t0)
		var bits := PackedStringArray()
		for p in plan["phases"]:
			var pd: Dictionary = p
			if String(pd["kind"]) == "el":
				bits.append("\"%s\" %s in %.0f s" % [pd["el"], {"paint": "laid", "blend": "blended", "sweep": "swept"}.get(String(pd["role"]), ""), float(pd["b"]) - float(pd["a"])])
		var natural := float(plan["natural"])
		out.append("it paints: %s - %.0f s at a hand's own pace%s" % [", ".join(bits), natural,
			(" (hurried into %.0f s)" % (t1 - t0)) if t1 - t0 < natural * 0.95 else ""])
	return out


## WHETHER ANYTHING HERE RAISES [param look]: "dust" - a powder laid or swept, or anything patted on; "mist" - anything sprayed.
func raises(look := "dust") -> bool:
	for k in _layers:
		var si := int(String(k).get_slice("|", 0))
		var ed := element(si, String(k).get_slice("|", 1))
		var manner := String((_layers[k] as Dictionary)["manner"])
		if look == "mist" and manner == "spray":
			return true
		if look == "dust" and (manner == "pat" or String(ed.get("finish", "")) == "powder"):
			return true
	return false


## WHAT NO ACT LAYS, of every design on the table.
func unpainted() -> PackedStringArray:
	var out := PackedStringArray()
	for si in skins.size():
		for e in ((skins[si] as Dictionary)["design"] as Dictionary).get("elements", []):
			if not _layers.has("%d|%s" % [si, String((e as Dictionary)["id"]).to_lower()]):
				out.append(String((e as Dictionary)["id"]))
	return out
